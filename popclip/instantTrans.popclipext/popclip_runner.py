from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


REPLY_PICKER_SCRIPT = r'''
on run argv
    set picked to choose from list argv with title "instantTrans 建议回复" with prompt "请选择一条回复（只复制到剪贴板，不会自动发送）" OK button name "复制" cancel button name "取消"
    if picked is false then return "0"
    set pickedText to item 1 of picked
    repeat with itemIndex from 1 to count argv
        if item itemIndex of argv is pickedText then return itemIndex as text
    end repeat
    return "0"
end run
'''


def _load_engine() -> tuple[Any, Any]:
    project_dir = os.environ.get("INSTANTTRANS_DIR", "").strip()
    if not project_dir:
        raise RuntimeError("配置缺少 INSTANTTRANS_DIR")

    engine_path = Path(project_dir) / "assistant_engine.py"
    if not engine_path.is_file():
        raise RuntimeError(f"找不到 assistant_engine.py: {engine_path}")

    sys.path.insert(0, str(engine_path.parent))
    from assistant_engine import OperationRequest, WritingEngine

    return OperationRequest, WritingEngine


def _option(identifier: str, default: str) -> str:
    return os.environ.get(f"POPCLIP_OPTION_{identifier.upper()}", default).strip() or default


def _choice_preview(index: int, reply: dict[str, Any]) -> str:
    label = str(reply.get("label") or f"建议 {index}").strip()
    text = " ".join(str(reply.get("text") or "").split())
    meaning = " ".join(str(reply.get("meaning") or "").split())
    preview = text
    if meaning:
        preview = f"{preview}（{meaning}）"
    if len(preview) > 220:
        preview = preview[:217].rstrip() + "…"
    return f"{index}. {label} — {preview}"


def _pick_reply(replies: list[dict[str, Any]]) -> str | None:
    choices = [_choice_preview(index, reply) for index, reply in enumerate(replies, 1)]
    completed = subprocess.run(
        ["osascript", "-e", REPLY_PICKER_SCRIPT, "--", *choices],
        check=True,
        capture_output=True,
        text=True,
    )
    selected = completed.stdout.strip()
    if not selected or selected == "0":
        return None
    try:
        index = int(selected) - 1
        return str(replies[index]["text"])
    except (ValueError, IndexError, KeyError) as error:
        raise RuntimeError("无法识别选择的建议回复") from error


def _copy_reply(text: str) -> None:
    subprocess.run(["pbcopy"], input=text, check=True, text=True)
    subprocess.run(
        [
            "osascript",
            "-e",
            'display notification "建议回复已复制，请手动粘贴并确认后发送" with title "instantTrans"',
        ],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def _exit_for_error(message: str) -> int:
    print(message, file=sys.stderr)
    if "请设置环境变量" in message:
        return 2
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description="instantTrans PopClip writing bridge")
    parser.add_argument("operation", choices=("polish", "suggest_reply"))
    args = parser.parse_args()

    text = os.environ.get("POPCLIP_TEXT", "")
    if not text.strip():
        return _exit_for_error("没有选中文字")

    try:
        OperationRequest, WritingEngine = _load_engine()
        request = OperationRequest(
            operation=args.operation,
            text=text,
            style=_option("POLISHSTYLE", "natural"),
            intent=_option("REPLYINTENT", "auto"),
            provider=_option("WRITINGPROVIDER", "auto"),
        )
        result = WritingEngine().run(request)
        if not result.get("ok"):
            return _exit_for_error(str(result.get("error") or "处理失败"))

        if args.operation == "polish":
            sys.stdout.write(str(result.get("replacement") or ""))
            return 0

        replies = list(result.get("replies") or [])[:3]
        if len(replies) != 3:
            return _exit_for_error("模型没有返回 3 条可用的建议回复")
        selected = _pick_reply(replies)
        if selected is not None:
            _copy_reply(selected)
        return 0
    except Exception as error:
        return _exit_for_error(str(error))


if __name__ == "__main__":
    raise SystemExit(main())
