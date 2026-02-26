import sys
import argparse
from translate import translate_text_google, translate_text_siliconflow

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--google", action="store_true", help="使用Google翻译")
    parser.add_argument("--siliconflow", action="store_true", help="使用硅基流动API")
    parser.add_argument("--message", type=str, required=True)
    args = parser.parse_args()

    try:
        if args.google:
            translated_text = translate_text_google(args.message)
        elif args.siliconflow:
            translated_text = translate_text_siliconflow(args.message)
        else:
            # 默认：优先SiliconFlow，失败时降级到Google
            try:
                translated_text = translate_text_siliconflow(args.message)
            except Exception:
                translated_text = translate_text_google(args.message)

        print(translated_text)
    except Exception as e:
        print(f"翻译失败: {e}", file=sys.stderr)
        sys.exit(1)