"""本地模型常驻后台服务：TCP JSON 协议，空闲自动卸载模型释放显存。"""

from __future__ import annotations

import argparse
import json
import os
import socket
import subprocess
import sys
import threading
import time
from typing import Any

from local_model import (
    LocalModelManager,
    build_local_status,
    check_local_dependencies,
    get_idle_timeout_sec,
    get_service_host,
    get_service_port,
    set_progress_out,
    setup_local_environment,
)

CREATE_NO_WINDOW = 0x08000000 if os.name == "nt" else 0
IDLE_CHECK_INTERVAL_SEC = 30


class LocalModelService:
    def __init__(self) -> None:
        self._manager = LocalModelManager()
        self._stop_event = threading.Event()
        self._server_socket: socket.socket | None = None

    def handle_request(self, payload: dict[str, Any]) -> dict[str, Any]:
        action = payload.get("action", "")

        if action == "ping":
            return {"ok": True, "action": "ping"}

        if action == "status":
            status = self._manager.status()
            status.update(build_local_status(
                service_running=True,
                model_loaded=status["loaded"],
            ))
            status["ok"] = True
            return status

        if action == "translate":
            text = payload.get("text", "")
            if not isinstance(text, str) or not text.strip():
                return {"ok": False, "error": "缺少待翻译文本"}
            try:
                result = self._manager.translate(text)
                return {"ok": True, "result": result}
            except Exception as e:
                return {"ok": False, "error": str(e)}

        if action == "unload":
            unloaded = self._manager.unload()
            return {"ok": True, "unloaded": unloaded}

        if action == "shutdown":
            self._stop_event.set()
            return {"ok": True, "action": "shutdown"}

        return {"ok": False, "error": f"未知操作: {action}"}

    def _idle_monitor(self) -> None:
        while not self._stop_event.wait(IDLE_CHECK_INTERVAL_SEC):
            try:
                self._manager.maybe_unload_if_idle()
            except Exception:
                pass

    def _handle_client(self, conn: socket.socket) -> None:
        with conn:
            conn.settimeout(120)
            file_obj = conn.makefile("r", encoding="utf-8")
            line = file_obj.readline()
            if not line:
                return
            try:
                payload = json.loads(line)
            except json.JSONDecodeError:
                response = {"ok": False, "error": "无效 JSON 请求"}
            else:
                response = self.handle_request(payload)
            conn.sendall((json.dumps(response, ensure_ascii=False) + "\n").encode("utf-8"))

    def serve(self, host: str | None = None, port: int | None = None) -> None:
        host = host or get_service_host()
        port = port or get_service_port()

        monitor = threading.Thread(target=self._idle_monitor, daemon=True)
        monitor.start()

        self._server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self._server_socket.bind((host, port))
        self._server_socket.listen(5)
        self._server_socket.settimeout(1.0)

        while not self._stop_event.is_set():
            try:
                conn, _addr = self._server_socket.accept()
            except TimeoutError:
                continue
            except OSError:
                break
            threading.Thread(
                target=self._handle_client,
                args=(conn,),
                daemon=True,
            ).start()

        if self._server_socket:
            self._server_socket.close()
        self._manager.unload()

    def stop(self) -> None:
        self._stop_event.set()
        if self._server_socket:
            try:
                self._server_socket.close()
            except OSError:
                pass


def service_request(payload: dict[str, Any], timeout: float = 5.0) -> dict[str, Any]:
    host = get_service_host()
    port = get_service_port()
    data = (json.dumps(payload, ensure_ascii=False) + "\n").encode("utf-8")

    with socket.create_connection((host, port), timeout=timeout) as sock:
        sock.sendall(data)
        file_obj = sock.makefile("r", encoding="utf-8")
        line = file_obj.readline()
        if not line:
            raise ConnectionError("本地模型服务无响应")
        return json.loads(line)


def is_service_running(timeout: float = 1.0) -> bool:
    try:
        response = service_request({"action": "ping"}, timeout=timeout)
        return bool(response.get("ok"))
    except Exception:
        return False


def get_service_status(timeout: float = 2.0) -> dict[str, Any] | None:
    try:
        response = service_request({"action": "status"}, timeout=timeout)
        return response if response.get("ok") else None
    except Exception:
        return None


def start_service_process(wait_ready: bool = True, timeout: float = 30.0) -> bool:
    deps_ready, _ = check_local_dependencies()
    if not deps_ready:
        return False

    if is_service_running(timeout=0.5):
        return True

    script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "local_service.py")
    subprocess.Popen(
        [sys.executable, script_path, "--serve"],
        cwd=os.path.dirname(script_path),
        creationflags=CREATE_NO_WINDOW,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    if not wait_ready:
        return True

    deadline = time.time() + timeout
    while time.time() < deadline:
        if is_service_running(timeout=0.5):
            return True
        time.sleep(0.3)
    return False


def restart_service_process(timeout: float = 30.0) -> bool:
    try:
        service_request({"action": "shutdown"}, timeout=2.0)
    except Exception:
        pass
    time.sleep(0.5)
    return start_service_process(wait_ready=True, timeout=timeout)


def ensure_service_running(timeout: float = 30.0) -> None:
    if not start_service_process(wait_ready=True, timeout=timeout):
        raise RuntimeError("无法启动本地模型后台服务，请确认已安装 requirements-local.txt")


def translate_via_service(text: str, timeout: float = 120.0) -> str:
    ensure_service_running()
    response = service_request({"action": "translate", "text": text}, timeout=timeout)
    if response.get("ok"):
        return str(response.get("result", ""))

    error = response.get("error", "本地模型翻译失败")
    if restart_service_process():
        response = service_request({"action": "translate", "text": text}, timeout=timeout)
        if response.get("ok"):
            return str(response.get("result", ""))
        error = response.get("error", error)

    raise ValueError(error)


def print_local_status() -> None:
    running = is_service_running()
    model_loaded = False
    if running:
        status = get_service_status()
        if status:
            model_loaded = bool(status.get("loaded"))

    info = build_local_status(service_running=running, model_loaded=model_loaded)
    print(f"deps_ready={1 if info['deps_ready'] else 0}")
    print(f"model_cached={1 if info['model_cached'] else 0}")
    print(f"ready={1 if info['ready'] else 0}")
    print(f"service_running={1 if info['service_running'] else 0}")
    print(f"model_loaded={1 if info['model_loaded'] else 0}")
    print(f"model_id={info['model_id']}")
    for hint in info["hints"]:
        print(f"hint={hint}")


def main() -> None:
    parser = argparse.ArgumentParser(description="instantTrans 本地模型后台服务")
    parser.add_argument("--setup", action="store_true", help="自动安装依赖并下载模型")
    parser.add_argument("--progress-out", metavar="FILE", help="将 --setup 进度写入文件")
    parser.add_argument("--serve", action="store_true", help="启动常驻后台服务")
    parser.add_argument("--ensure", action="store_true", help="确保后台服务已启动")
    parser.add_argument("--unload", action="store_true", help="释放已加载的本地模型显存")
    parser.add_argument("--status", action="store_true", help="输出本地模型与服务状态")
    parser.add_argument("--stop", action="store_true", help="请求关闭后台服务")
    args = parser.parse_args()

    if args.status:
        print_local_status()
        return

    if args.setup:
        set_progress_out(args.progress_out)
        try:
            setup_local_environment()
            start_service_process(wait_ready=True)
            raise SystemExit(0)
        except Exception as e:
            if args.progress_out:
                set_progress_out(args.progress_out)
                try:
                    with open(args.progress_out, "w", encoding="utf-8") as handle:
                        handle.write(f"step=error\nmessage=配置失败: {e}\npct=-1\n")
                except OSError:
                    pass
            print(f"error={e}", flush=True)
            print("ok=0", flush=True)
            raise SystemExit(1) from e
        finally:
            set_progress_out(None)

    if args.ensure:
        ok = start_service_process(wait_ready=True)
        raise SystemExit(0 if ok else 1)

    if args.unload:
        try:
            response = service_request({"action": "unload"}, timeout=5.0)
            raise SystemExit(0 if response.get("ok") else 1)
        except Exception:
            raise SystemExit(1)

    if args.stop:
        try:
            service_request({"action": "shutdown"}, timeout=2.0)
        except Exception:
            pass
        return

    if args.serve:
        deps_ready, missing = check_local_dependencies()
        if not deps_ready:
            print("依赖未安装: " + ", ".join(missing), file=sys.stderr)
            raise SystemExit(1)
        LocalModelService().serve()
        return

    parser.print_help()


if __name__ == "__main__":
    main()
