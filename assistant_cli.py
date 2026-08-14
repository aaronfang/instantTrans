import argparse
import json
from pathlib import Path

from assistant_engine import run_request_file, write_desktop_result


def main() -> int:
    parser = argparse.ArgumentParser(description="instantTrans writing assistant")
    parser.add_argument("--request", required=True, help="UTF-8 JSON request file")
    parser.add_argument("--response", required=True, help="UTF-8 JSON response file")
    parser.add_argument("--desktop-dir", help="Optional AHK-friendly result directory")
    args = parser.parse_args()

    try:
        result = run_request_file(Path(args.request), Path(args.response))
        if args.desktop_dir:
            write_desktop_result(result, Path(args.desktop_dir))
        return 0 if result.get("ok") else 1
    except Exception as error:
        result = {"ok": False, "error": str(error)}
        Path(args.response).write_text(
            json.dumps(result, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        if args.desktop_dir:
            write_desktop_result(result, Path(args.desktop_dir))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
