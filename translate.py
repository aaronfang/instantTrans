import os
import argparse

instruction = """You are an adept artificial intelligence translator, especially skilled at converting text from various languages into natural, conversational language. 
    Your goal is to ensure that the translated outcome not only accurately conveys the meaning of the original text but also sounds as if it were spoken by a native language speaker in a friendly and relaxed manner. 
    Please refrain from rigid or overly formal tones, striving instead to give the translation the feel of everyday conversation. Translate the following text between Chinese and English."""

def check_local_model_status() -> dict:
    """返回本地模型环境与后台服务状态，供 AHK 托盘菜单展示"""
    from local_service import get_service_status, is_service_running
    from local_model import build_local_status

    running = is_service_running()
    model_loaded = False
    if running:
        status = get_service_status()
        if status:
            model_loaded = bool(status.get("loaded"))
    return build_local_status(service_running=running, model_loaded=model_loaded)

def _print_local_status() -> None:
    from local_service import print_local_status

    print_local_status()

def translate_text_local(text: str) -> str:
    """通过常驻后台服务使用本地 HY-MT1.5-ONNX 模型翻译"""
    from local_service import translate_via_service

    return translate_via_service(text)

def translate_text_google(text: str) -> str:
    """使用Google翻译 (通过deep-translator，兼容Python 3.13+)"""
    from deep_translator import GoogleTranslator

    # 自动检测语言并翻译为英文或中文
    try:
        # 先尝试翻译为英文
        result = GoogleTranslator(source='auto', target='en').translate(text)
        # 如果原文已经是英文，翻译为中文
        if result == text or text.strip().isascii():
            result = GoogleTranslator(source='auto', target='zh-CN').translate(text)
        return result if result else text
    except Exception:
        # 如果翻译为英文失败，尝试翻译为中文
        result = GoogleTranslator(source='auto', target='zh-CN').translate(text)
        return result if result else text

def _get_windows_user_env(name: str) -> str | None:
    if os.name != "nt":
        return None
    try:
        import winreg

        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as key:
            value, _ = winreg.QueryValueEx(key, name)
            return value or None
    except OSError:
        return None

def _get_deepseek_api_key() -> str | None:
    return os.getenv("DEEPSEEK_API_KEY") or _get_windows_user_env("DEEPSEEK_API_KEY")

def _get_siliconflow_api_key() -> str | None:
    return os.getenv("SILICONFLOW_API_KEY") or _get_windows_user_env("SILICONFLOW_API_KEY")

def translate_text_deepseek(text: str) -> str:
    """使用 DeepSeek API 进行翻译"""
    from openai import OpenAI

    api_key = _get_deepseek_api_key()
    if not api_key:
        raise ValueError(
            "请设置环境变量 DEEPSEEK_API_KEY\n"
            "获取地址: https://platform.deepseek.com/api_keys"
        )

    try:
        client = OpenAI(
            api_key=api_key,
            base_url="https://api.deepseek.com"
        )

        chat_completion = client.chat.completions.create(
            messages=[
                {"role": "system", "content": instruction},
                {"role": "user", "content": text}
            ],
            model="deepseek-chat",
            temperature=0.7,
            max_tokens=2000,
            timeout=15
        )
        content = chat_completion.choices[0].message.content
        return content.strip() if content else ""

    except Exception as e:
        if "401" in str(e) or "403" in str(e):
            raise ValueError(
                f"DeepSeek API 密钥无效。请访问 https://platform.deepseek.com/api_keys 重新生成\n错误: {e}"
            )
        raise

def translate_text_siliconflow(text: str) -> str:
    """使用硅基流动API进行翻译 (国内免费API，更稳定)"""
    from openai import OpenAI

    api_key = _get_siliconflow_api_key()
    if not api_key:
        raise ValueError("请设置环境变量 SILICONFLOW_API_KEY\n获取地址: https://cloud.siliconflow.cn/account/ak")
    
    try:
        client = OpenAI(
            api_key=api_key,
            base_url="https://api.siliconflow.cn/v1"
        )
        
        # 尝试多个模型
        models = [
            "Qwen/Qwen2.5-7B-Instruct",
            "Qwen/Qwen2.5-14B-Instruct",
            "deepseek-ai/DeepSeek-V2.5"
        ]
        
        last_error = None
        for model in models:
            try:
                chat_completion = client.chat.completions.create(
                    messages=[
                        {"role": "system", "content": instruction},
                        {"role": "user", "content": text}
                    ],
                    model=model,
                    temperature=0.7,
                    max_tokens=2000,
                    timeout=10
                )
                content = chat_completion.choices[0].message.content
                return content.strip() if content else ""
            except Exception as e:
                last_error = e
                if "model" in str(e).lower() or "404" in str(e):
                    continue
                else:
                    raise
        
        raise ValueError(f"所有硅基流动模型均不可用。错误: {last_error}")
    
    except Exception as e:
        if "401" in str(e) or "403" in str(e):
            raise ValueError(f"硅基流动API密钥无效。请访问 https://cloud.siliconflow.cn/account/ak 重新生成\n错误: {e}")
        raise

def translate_text_auto(text: str) -> tuple[str, str]:
    """自动降级：DeepSeek -> SiliconFlow -> Google -> Local"""
    last_error: Exception | None = None
    for used_api, translate_fn in (
        ("DeepSeek", translate_text_deepseek),
        ("SiliconFlow", translate_text_siliconflow),
        ("Google", translate_text_google),
        ("Local", translate_text_local),
    ):
        try:
            return translate_fn(text), used_api
        except Exception as e:
            last_error = e
    raise last_error or RuntimeError("所有翻译方案均不可用")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-local", action="store_true", help="检查本地模型环境与缓存状态")
    parser.add_argument("--status-out", type=str, help="将 --check-local 结果写入指定文件")
    parser.add_argument("--local", action="store_true", help="使用本地HY-MT1.5模型（离线，无需API密钥）")
    parser.add_argument("--google", action="store_true", help="使用Google翻译（无需API密钥）")
    parser.add_argument("--deepseek", action="store_true", help="使用DeepSeek API（推荐）")
    parser.add_argument("--siliconflow", action="store_true", help="使用硅基流动API（国内免费）")
    args = parser.parse_args()

    if args.check_local:
        if args.status_out:
            import sys
            from io import StringIO

            buffer = StringIO()
            stdout = sys.stdout
            try:
                sys.stdout = buffer
                _print_local_status()
            finally:
                sys.stdout = stdout
            with open(args.status_out, "w", encoding="utf-8") as handle:
                handle.write(buffer.getvalue())
        else:
            _print_local_status()
        raise SystemExit(0)

    import pyperclip

    text = pyperclip.paste()
    used_api = ""

    try:
        if args.local:
            translated_text = translate_text_local(text)
            used_api = "Local"
        elif args.google:
            translated_text = translate_text_google(text)
            used_api = "Google"
        elif args.deepseek:
            translated_text = translate_text_deepseek(text)
            used_api = "DeepSeek"
        elif args.siliconflow:
            translated_text = translate_text_siliconflow(text)
            used_api = "SiliconFlow"
        else:
            translated_text, used_api = translate_text_auto(text)
        
        # 将翻译结果和使用的API信息都复制到剪贴板（用特殊分隔符）
        pyperclip.copy(f"{translated_text}|||{used_api}")
        
    except Exception as e:
        # 如果所有翻译都失败，输出错误信息
        print(f"翻译失败: {e}")
        pyperclip.copy(f"{text}|||ERROR:{e}")
