"""本地 HY-MT1.5 ONNX 模型：环境检测、加载/卸载与推理核心逻辑。"""

from __future__ import annotations

import gc
import os
import threading
import time

_LOCAL_MODEL_ID = "onnx-community/HY-MT1.5-1.8B-ONNX"
_LOCAL_REQUIRED_PACKAGES = (
    "onnxruntime",
    "transformers",
    "torch",
    "sentencepiece",
    "huggingface_hub",
)
_LOCAL_TOKENIZER_FILES = (
    "config.json",
    "generation_config.json",
    "tokenizer.json",
    "tokenizer_config.json",
    "chat_template.jinja",
)
_HF_MIRROR_ENDPOINT = "https://hf-mirror.com"

DEFAULT_SERVICE_HOST = "127.0.0.1"
DEFAULT_SERVICE_PORT = 19527
DEFAULT_IDLE_TIMEOUT_SEC = 600

_PROGRESS_OUT_PATH: str | None = None


def set_progress_out(path: str | None) -> None:
    global _PROGRESS_OUT_PATH
    _PROGRESS_OUT_PATH = path


def _report(message: str, *, pct: int = -1, step: str = "") -> None:
    if step:
        extras = f" pct={pct}" if pct >= 0 else ""
        print(f"step={step}{extras}", flush=True)
    if _PROGRESS_OUT_PATH:
        try:
            with open(_PROGRESS_OUT_PATH, "w", encoding="utf-8") as handle:
                handle.write(f"step={step}\nmessage={message}\npct={pct}\n")
        except OSError:
            pass


def get_project_model_dir() -> str:
    return os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "models",
        "HY-MT1.5-1.8B-ONNX",
    )


def get_local_model_id() -> str:
    configured = os.getenv("HY_MT_MODEL_ID", "").strip()
    if configured:
        if os.path.isdir(configured):
            return os.path.abspath(configured)
        return configured

    project_dir = get_project_model_dir()
    if os.path.isdir(project_dir) and is_local_model_cached(project_dir):
        return project_dir

    return _LOCAL_MODEL_ID


def is_local_model_path(model_id: str | None = None) -> bool:
    model_id = model_id or get_local_model_id()
    return os.path.isdir(model_id)


def get_onnx_variant_bases() -> list[str]:
    preferred = os.getenv("HY_MT_ONNX_FILE")
    if preferred:
        return [preferred.removesuffix(".onnx")]
    return ["model_q4", "model_q4f16", "model_fp16", "model"]


def get_onnx_file_candidates() -> list[str]:
    return [f"{base}.onnx" for base in get_onnx_variant_bases()]


def _files_for_onnx_variant(base: str) -> list[str]:
    return [
        *_LOCAL_TOKENIZER_FILES,
        f"onnx/{base}.onnx",
        f"onnx/{base}.onnx_data",
    ]


def _has_onnx_files(model_dir: str) -> bool:
    onnx_dir = os.path.join(model_dir, "onnx")
    if not os.path.isdir(onnx_dir):
        return False

    for base in get_onnx_variant_bases():
        onnx_path = os.path.join(onnx_dir, f"{base}.onnx")
        if not os.path.isfile(onnx_path):
            continue
        data_path = os.path.join(onnx_dir, f"{base}.onnx_data")
        if os.path.isfile(data_path):
            return True
        if base == "model":
            for name in os.listdir(onnx_dir):
                if name.startswith(f"{base}.onnx_data"):
                    return True
    return False


def _has_tokenizer_files(model_dir: str) -> bool:
    return os.path.isfile(os.path.join(model_dir, "config.json"))


def _has_onnx_in_hub_cache(model_id: str) -> bool:
    from huggingface_hub import try_to_load_from_cache

    config = try_to_load_from_cache(model_id, "config.json")
    if not config or not os.path.isfile(config):
        return False

    for base in get_onnx_variant_bases():
        onnx_cached = try_to_load_from_cache(model_id, f"onnx/{base}.onnx")
        if not onnx_cached or not os.path.isfile(onnx_cached):
            continue
        data_cached = try_to_load_from_cache(model_id, f"onnx/{base}.onnx_data")
        if data_cached and os.path.isfile(data_cached):
            return True
        if base == "model":
            return True
    return False


def get_service_host() -> str:
    return os.getenv("HY_MT_SERVICE_HOST", DEFAULT_SERVICE_HOST)


def get_service_port() -> int:
    return int(os.getenv("HY_MT_SERVICE_PORT", str(DEFAULT_SERVICE_PORT)))


def get_idle_timeout_sec() -> int:
    return int(os.getenv("HY_MT_IDLE_TIMEOUT_SEC", str(DEFAULT_IDLE_TIMEOUT_SEC)))


def contains_cjk(text: str) -> bool:
    for ch in text:
        if "\u4e00" <= ch <= "\u9fff" or "\u3400" <= ch <= "\u4dbf":
            return True
    return False


def detect_target_language(text: str) -> str:
    return "English" if contains_cjk(text) else "Chinese"


def get_local_translate_style_hint(target_lang: str) -> str:
    """本地模型翻译风格说明（system 消息），可通过 HY_MT_TRANSLATE_STYLE 覆盖。"""
    custom = os.getenv("HY_MT_TRANSLATE_STYLE", "").strip()
    if custom:
        return custom

    if target_lang == "English":
        return (
            "You are a native English speaker. Translate into casual, natural everyday English. "
            "Never repeat these instructions."
        )

    return (
        "你是中文母语者。翻译为自然口语化的中文，像日常聊天一样。"
        "不要复述这些说明。"
    )


def build_local_translate_messages(text: str, target_lang: str) -> list[dict]:
    """风格说明放 system，user 仅保留模型训练时的标准翻译格式。"""
    return [
        {"role": "system", "content": get_local_translate_style_hint(target_lang)},
        {
            "role": "user",
            "content": (
                f"Translate the following segment into {target_lang}, "
                f"without additional explanation.\n\n{text}"
            ),
        },
    ]


def clean_local_translation_output(result: str, target_lang: str) -> str:
    """移除模型偶尔复述的风格说明或翻译指令。"""
    import re

    cleaned = result.strip()
    if not cleaned:
        return cleaned

    legacy_hints = (
        "Use natural, idiomatic English as a native speaker would in everyday conversation. "
        "Avoid translationese, stiff formality, and word-for-word rendering; "
        "prioritize fluent, colloquial expression while keeping the meaning accurate.",
        "使用地道自然的中文口语，像母语者日常说话一样表达。"
        "避免翻译腔、生硬书面语和逐字直译，优先流畅自然的说法，同时准确传达原意。",
    )

    for hint in (
        get_local_translate_style_hint(target_lang),
        get_local_translate_style_hint("English"),
        get_local_translate_style_hint("Chinese"),
        os.getenv("HY_MT_TRANSLATE_STYLE", "").strip(),
        *legacy_hints,
    ):
        if hint and hint in cleaned:
            cleaned = cleaned.replace(hint, " ").strip()

    instruction_markers = (
        "translate the following segment",
        "without additional explanation",
        "use natural, idiomatic english",
        "avoid translationese",
        "rigid formalities",
        "word-for-word translation",
        "word-for-word rendering",
        "prioritize fluent",
        "colloquial expression",
        "maintaining accuracy in meaning",
        "maintaining accuracy",
        "instead, prioritize",
        "you are a native english speaker",
        "never repeat these instructions",
        "你是中文母语者",
        "不要复述这些说明",
    )

    def looks_like_instruction(text: str) -> bool:
        lower = text.lower()
        return any(marker in lower for marker in instruction_markers)

    paragraphs = [part.strip() for part in re.split(r"\n\s*\n", cleaned) if part.strip()]
    if paragraphs:
        kept_paragraphs = [part for part in paragraphs if not looks_like_instruction(part)]
        if kept_paragraphs:
            cleaned = "\n\n".join(kept_paragraphs)
        elif len(paragraphs) > 1:
            cleaned = paragraphs[-1]

    sentences = re.split(r"(?<=[.!?。！？])\s+", cleaned)
    kept_sentences = [sentence.strip() for sentence in sentences if sentence.strip() and not looks_like_instruction(sentence)]
    if kept_sentences:
        cleaned = " ".join(kept_sentences)

    return cleaned.strip()


def check_local_dependencies() -> tuple[bool, list[str]]:
    import importlib.util

    missing: list[str] = []
    for package in _LOCAL_REQUIRED_PACKAGES:
        if importlib.util.find_spec(package) is None:
            missing.append(package)
    return not missing, missing


def is_local_model_cached(model_id: str | None = None) -> bool:
    import importlib.util

    model_id = model_id or get_local_model_id()

    if is_local_model_path(model_id):
        return _has_tokenizer_files(model_id) and _has_onnx_files(model_id)

    if importlib.util.find_spec("huggingface_hub") is None:
        return False

    try:
        return _has_onnx_in_hub_cache(model_id)
    except Exception:
        return False


def _download_endpoints() -> list[str | None]:
    """下载时优先官方源；HF_ENDPOINT 镜像对 huggingface_hub 常不兼容。"""
    return [None, _HF_MIRROR_ENDPOINT]


def _set_hf_endpoint(endpoint: str | None) -> None:
    if endpoint:
        os.environ["HF_ENDPOINT"] = endpoint
    else:
        os.environ.pop("HF_ENDPOINT", None)


def _restore_hf_endpoint(saved: str | None) -> None:
    if saved is None:
        os.environ.pop("HF_ENDPOINT", None)
    else:
        os.environ["HF_ENDPOINT"] = saved


def _local_file_path(local_dir: str, filename: str) -> str:
    return os.path.join(local_dir, *filename.split("/"))


def _http_download_file(base_url: str, repo_id: str, filename: str, dest_path: str) -> None:
    import urllib.error
    import urllib.request

    url = f"{base_url.rstrip('/')}/{repo_id}/resolve/main/{filename}"
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    temp_path = f"{dest_path}.part"
    resume_from = os.path.getsize(temp_path) if os.path.isfile(temp_path) else 0
    request = urllib.request.Request(url, headers={"User-Agent": "instantTrans/1.0"})
    if resume_from:
        request.add_header("Range", f"bytes={resume_from}-")

    is_large = filename.endswith(".onnx_data") or ".onnx_data" in filename
    timeout = None if is_large else 300

    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            status = getattr(response, "status", response.getcode())
            if status not in (200, 206):
                raise RuntimeError(f"HTTP {status} 下载失败: {url}")

            total_header = response.headers.get("Content-Length")
            total = int(total_header) + resume_from if total_header else 0
            if status == 200 and resume_from:
                resume_from = 0
            downloaded = resume_from
            mode = "ab" if resume_from else "wb"

            with open(temp_path, mode) as handle:
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    handle.write(chunk)
                    downloaded += len(chunk)
                    if total:
                        pct = downloaded * 100 // total
                        print(
                            f"step=download_progress file={filename} pct={pct}",
                            flush=True,
                        )
                        if _PROGRESS_OUT_PATH:
                            overall_pct = 10 + (pct * 85 // 100)
                            _report(
                                f"正在下载 {filename} ({pct}%)",
                                pct=overall_pct,
                                step="download_progress",
                            )
    except urllib.error.HTTPError as e:
        if e.code == 416 and os.path.isfile(temp_path):
            os.replace(temp_path, dest_path)
            return
        if os.path.isfile(temp_path) and os.path.getsize(temp_path) == 0:
            os.remove(temp_path)
        raise RuntimeError(f"HTTP {e.code} 下载失败: {url}") from e

    os.replace(temp_path, dest_path)


def _download_via_hub(repo_id: str, local_dir: str, files: list[str], endpoint: str | None) -> None:
    from huggingface_hub import hf_hub_download

    _set_hf_endpoint(endpoint)
    total = len(files)
    for index, filename in enumerate(files):
        overall = 10 + (index * 85 // total)
        _report(f"正在下载 {filename} ({index + 1}/{total})", pct=overall, step="downloading_file")
        print(f"step=downloading_file file={filename}", flush=True)
        download_kwargs = {
            "repo_id": repo_id,
            "filename": filename,
            "local_dir": local_dir,
        }
        if endpoint:
            download_kwargs["endpoint"] = endpoint
        hf_hub_download(**download_kwargs)


def _download_via_http(base_url: str, repo_id: str, local_dir: str, files: list[str]) -> None:
    total = len(files)
    for index, filename in enumerate(files):
        overall = 10 + (index * 85 // total)
        _report(f"正在下载 {filename} ({index + 1}/{total})", pct=overall, step="downloading_file")
        print(f"step=downloading_file file={filename}", flush=True)
        dest_path = _local_file_path(local_dir, filename)
        if os.path.isfile(dest_path) and os.path.getsize(dest_path) > 0:
            continue
        _http_download_file(base_url, repo_id, filename, dest_path)


def download_local_model(model_id: str | None = None) -> str:
    repo_id = _LOCAL_MODEL_ID if not model_id or is_local_model_path(model_id) else model_id
    local_dir = get_project_model_dir()

    if is_local_model_path(model_id or "") and is_local_model_cached(model_id):
        return os.path.abspath(model_id)  # type: ignore[arg-type]

    if os.path.isdir(local_dir) and is_local_model_cached(local_dir):
        return local_dir

    os.makedirs(local_dir, exist_ok=True)
    variant = get_onnx_variant_bases()[0]
    files = _files_for_onnx_variant(variant)
    saved_endpoint = os.environ.get("HF_ENDPOINT")
    last_error: Exception | None = None

    strategies: list[tuple[str, str | None]] = []
    if not saved_endpoint:
        strategies.append(("hub", None))
    strategies.append(("http", "https://huggingface.co"))

    try:
        for method, base in strategies:
            label = base or "huggingface.co"
            _report(f"连接 {label} 下载模型...", pct=8, step="downloading_via")
            print(f"step=downloading_via method={method} endpoint={label}", flush=True)
            try:
                if method == "hub":
                    _download_via_hub(repo_id, local_dir, files, base)
                else:
                    _download_via_http(base, repo_id, local_dir, files)

                if not is_local_model_cached(local_dir):
                    raise RuntimeError("下载完成但模型文件不完整，请检查 onnx 文件")

                return local_dir
            except Exception as e:
                last_error = e
                print(f"step=download_failed method={method} error={e}", flush=True)
                continue
    finally:
        _restore_hf_endpoint(saved_endpoint)

    raise ValueError(
        "模型下载失败，请检查网络连接。\n"
        f"目标目录: {local_dir}\n"
        "提示: 请勿设置 HF_ENDPOINT，直接访问 huggingface.co 通常更稳定。\n"
        "手动下载命令:\n"
        "  huggingface-cli download onnx-community/HY-MT1.5-1.8B-ONNX "
        f'--local-dir "{local_dir}" '
        "--include config.json generation_config.json tokenizer.json "
        "tokenizer_config.json chat_template.jinja onnx/model_q4.onnx onnx/model_q4.onnx_data\n"
        f"错误: {last_error}"
    ) from last_error


def install_local_dependencies() -> None:
    import subprocess
    import sys

    root = os.path.dirname(os.path.abspath(__file__))
    req_file = os.path.join(root, "requirements-local.txt")
    if not os.path.isfile(req_file):
        raise FileNotFoundError(f"未找到 {req_file}")

    stop = threading.Event()

    def heartbeat() -> None:
        tick = 0
        while not stop.wait(2):
            tick += 1
            suffix = "." * (tick % 4)
            _report(
                f"正在安装 Python 依赖（torch 等，首次较慢）{suffix}",
                pct=3,
                step="installing_deps",
            )

    worker = threading.Thread(target=heartbeat, daemon=True)
    worker.start()
    try:
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install", "-r", req_file],
            cwd=root,
        )
    finally:
        stop.set()
        worker.join(timeout=0.2)


def setup_local_environment() -> None:
    """安装依赖并下载模型文件（不加载到显存）。"""
    _report("正在检查本地环境...", pct=0, step="checking")
    deps_ready, _ = check_local_dependencies()
    if not deps_ready:
        _report("正在安装 Python 依赖...", pct=2, step="installing_deps")
        install_local_dependencies()
        _report("依赖安装完成", pct=10, step="deps_installed")

    model_id = get_local_model_id()
    project_dir = get_project_model_dir()
    if not is_local_model_cached(model_id) and not is_local_model_cached(project_dir):
        _report("正在下载模型（约 1~2 GB）...", pct=10, step="downloading_model")
        download_local_model()
        _report("模型下载完成", pct=95, step="model_downloaded")

    _report("配置完成", pct=100, step="done")
    print("ok=1", flush=True)


def release_gpu_memory() -> None:
    gc.collect()
    try:
        import torch

        if torch.cuda.is_available():
            torch.cuda.empty_cache()
            torch.cuda.ipc_collect()
    except Exception:
        pass


def _model_files_dir(model_id: str) -> str:
    if os.path.isdir(model_id):
        return model_id
    from huggingface_hub import snapshot_download

    return snapshot_download(
        model_id,
        allow_patterns=[
            "config.json",
            "tokenizer.json",
            "tokenizer_config.json",
            "chat_template.jinja",
        ],
    )


def load_local_tokenizer(model_id: str):
    """加载 HY-MT tokenizer；transformers 4.x 不支持 TokenizersBackend。"""
    import json

    from transformers import AutoTokenizer, PreTrainedTokenizerFast

    try:
        return AutoTokenizer.from_pretrained(model_id, trust_remote_code=True)
    except ValueError as e:
        if "TokenizersBackend" not in str(e):
            raise

    model_dir = _model_files_dir(model_id)
    tokenizer_json = os.path.join(model_dir, "tokenizer.json")
    if not os.path.isfile(tokenizer_json):
        raise ValueError(f"未找到 tokenizer.json: {model_dir}")

    tokenizer = PreTrainedTokenizerFast(tokenizer_file=tokenizer_json)
    config_path = os.path.join(model_dir, "tokenizer_config.json")
    cfg: dict = {}
    if os.path.isfile(config_path):
        with open(config_path, encoding="utf-8") as handle:
            cfg = json.load(handle)
        if cfg.get("chat_template"):
            tokenizer.chat_template = cfg["chat_template"]
        for key in ("bos_token", "eos_token", "pad_token"):
            if cfg.get(key):
                setattr(tokenizer, key, cfg[key])

    template_path = os.path.join(model_dir, "chat_template.jinja")
    if os.path.isfile(template_path) and not getattr(tokenizer, "chat_template", None):
        with open(template_path, encoding="utf-8") as handle:
            tokenizer.chat_template = handle.read()

    return tokenizer


def _load_model_config(model_dir: str) -> dict:
    import json

    config_path = os.path.join(model_dir, "config.json")
    with open(config_path, encoding="utf-8") as handle:
        return json.load(handle)


def _resolve_onnx_model_path(model_dir: str) -> str:
    onnx_dir = os.path.join(model_dir, "onnx")
    if not os.path.isdir(onnx_dir):
        raise FileNotFoundError(f"未找到 onnx 目录: {onnx_dir}")

    for file_name in get_onnx_file_candidates():
        model_path = os.path.join(onnx_dir, file_name)
        if not os.path.isfile(model_path):
            continue
        data_path = model_path.replace(".onnx", ".onnx_data")
        if os.path.isfile(data_path) or file_name == "model.onnx":
            return model_path

    raise FileNotFoundError(f"未找到可用的 ONNX 模型文件: {onnx_dir}")


class OnnxCausalLM:
    """直接使用 onnxruntime 推理，绕过 optimum generate 的 KV cache 维度问题。"""

    def __init__(self, model_path: str, config: dict) -> None:
        import onnxruntime as ort

        providers = ["CUDAExecutionProvider", "CPUExecutionProvider"]
        try:
            self._session = ort.InferenceSession(model_path, providers=providers)
        except Exception:
            self._session = ort.InferenceSession(
                model_path,
                providers=["CPUExecutionProvider"],
            )

        self._num_layers = int(config["num_hidden_layers"])
        self._num_kv_heads = int(config["num_key_value_heads"])
        self._head_dim = int(
            config.get("head_dim")
            or config["hidden_size"] // config["num_attention_heads"]
        )
        self._eos_token_id = int(config.get("eos_token_id", 120020))

    def _empty_past(self, length: int) -> dict:
        import numpy as np

        past: dict = {}
        for layer in range(self._num_layers):
            past[f"past_key_values.{layer}.key"] = np.zeros(
                (1, self._num_kv_heads, length, self._head_dim),
                dtype=np.float32,
            )
            past[f"past_key_values.{layer}.value"] = np.zeros(
                (1, self._num_kv_heads, length, self._head_dim),
                dtype=np.float32,
            )
        return past

    def generate(
        self,
        input_ids,
        *,
        max_new_tokens: int = 512,
        eos_token_id: int | None = None,
    ):
        import numpy as np

        if hasattr(input_ids, "input_ids"):
            input_ids = input_ids["input_ids"]
        elif isinstance(input_ids, dict):
            input_ids = input_ids["input_ids"]

        if hasattr(input_ids, "detach"):
            input_ids = input_ids.detach().cpu().numpy()
        input_ids = np.asarray(input_ids)
        if input_ids.ndim == 1:
            input_ids = input_ids.reshape(1, -1)

        eos_id = eos_token_id if eos_token_id is not None else self._eos_token_id
        prompt_ids = input_ids[0].tolist()
        generated = prompt_ids.copy()
        prompt_len = len(prompt_ids)

        past_len = 0
        past = self._empty_past(past_len)

        for _ in range(max_new_tokens):
            current = np.array(
                [prompt_ids if past_len == 0 else [generated[-1]]],
                dtype=np.int64,
            )
            seq_len = current.shape[1]
            position_ids = np.arange(past_len, past_len + seq_len, dtype=np.int64).reshape(1, -1)
            attention_mask = np.ones((1, past_len + seq_len), dtype=np.int64)
            feed = {
                "input_ids": current,
                "attention_mask": attention_mask,
                "position_ids": position_ids,
                **past,
            }

            outputs = self._session.run(None, feed)
            next_token = int(np.argmax(outputs[0][0, -1]))
            if next_token == eos_id:
                break

            generated.append(next_token)
            past_len += seq_len
            past = {}
            for layer in range(self._num_layers):
                past[f"past_key_values.{layer}.key"] = outputs[1 + layer * 2]
                past[f"past_key_values.{layer}.value"] = outputs[2 + layer * 2]

        return np.array([generated], dtype=np.int64), prompt_len

    def close(self) -> None:
        self._session = None


class LocalModelManager:
    """线程安全的本地模型管理器，支持空闲卸载以释放显存。"""

    def __init__(self, idle_timeout_sec: int | None = None) -> None:
        self._lock = threading.RLock()
        self._model = None
        self._tokenizer = None
        self._loaded = False
        self._last_used = 0.0
        self._idle_timeout_sec = idle_timeout_sec or get_idle_timeout_sec()

    @property
    def loaded(self) -> bool:
        with self._lock:
            return self._loaded

    @property
    def idle_seconds(self) -> float:
        with self._lock:
            if not self._loaded or not self._last_used:
                return 0.0
            return max(0.0, time.time() - self._last_used)

    def status(self) -> dict:
        with self._lock:
            return {
                "loaded": self._loaded,
                "idle_seconds": round(self.idle_seconds, 1),
                "idle_timeout_sec": self._idle_timeout_sec,
                "model_id": get_local_model_id(),
            }

    def touch(self) -> None:
        with self._lock:
            self._last_used = time.time()

    def load(self) -> None:
        with self._lock:
            if self._loaded:
                self.touch()
                return

            try:
                import onnxruntime  # noqa: F401
            except ImportError as e:
                raise ValueError(
                    "本地模型翻译需要额外依赖，请先安装：\n"
                    "    pip install -r requirements-local.txt\n"
                    f"缺少依赖: {e}"
                ) from e

            model_id = get_local_model_id()
            model_dir = _model_files_dir(model_id)
            config = _load_model_config(model_dir)
            model_path = _resolve_onnx_model_path(model_dir)
            self._tokenizer = load_local_tokenizer(model_id)
            self._model = OnnxCausalLM(model_path, config)
            self._loaded = True
            self.touch()
            return

    def unload(self) -> bool:
        with self._lock:
            if not self._loaded:
                return False
            model = self._model
            self._model = None
            self._tokenizer = None
            self._loaded = False
            self._last_used = 0.0

        if model is not None:
            model.close()
        release_gpu_memory()
        return True

    def maybe_unload_if_idle(self) -> bool:
        with self._lock:
            if not self._loaded:
                return False
            if self.idle_seconds < self._idle_timeout_sec:
                return False
        return self.unload()

    def translate(self, text: str) -> str:
        if not self._loaded:
            self.load()

        with self._lock:
            model = self._model
            tokenizer = self._tokenizer
            self.touch()

        target_lang = detect_target_language(text)
        messages = build_local_translate_messages(text, target_lang)

        inputs = tokenizer.apply_chat_template(
            messages,
            add_generation_prompt=True,
            return_tensors="pt",
        )

        outputs, prompt_len = model.generate(inputs, max_new_tokens=512)
        result = tokenizer.decode(outputs[0][prompt_len:], skip_special_tokens=True)
        result = clean_local_translation_output(result, target_lang)
        return result.strip() if result else text


def build_local_status(
    *,
    service_running: bool = False,
    model_loaded: bool = False,
) -> dict:
    model_id = get_local_model_id()
    deps_ready, missing_deps = check_local_dependencies()
    model_cached = is_local_model_cached(model_id) if deps_ready else False

    hints: list[str] = []
    if not deps_ready:
        hints.append("依赖未安装，选择本地模型时将自动安装")
        hints.append(f"模型: {model_id}")
    elif not model_cached:
        hints.append("环境已就绪，选择本地模型时将自动下载")
        hints.append(f"模型: {model_id} (约 1~2 GB)")
    else:
        if service_running:
            if model_loaded:
                hints.append("后台服务运行中，模型已加载")
            else:
                hints.append("后台服务运行中，模型未加载（首次翻译时加载）")
        else:
            hints.append("后台服务未运行（翻译时自动启动）")
        hints.append(f"空闲 {get_idle_timeout_sec() // 60} 分钟后自动释放显存")

    return {
        "deps_ready": deps_ready,
        "model_cached": model_cached,
        "ready": deps_ready,
        "service_running": service_running,
        "model_loaded": model_loaded,
        "model_id": model_id,
        "missing_deps": missing_deps,
        "hints": hints,
    }
