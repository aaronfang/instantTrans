import argparse
from translate import translate_text_google, translate_text_openai

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--google", action="store_true")
    parser.add_argument("--openai", action="store_true")
    parser.add_argument("--message", type=str, required=True)
    args = parser.parse_args()

    if args.google:
        translated_text = translate_text_google(args.message)
    elif args.openai:
        translated_text = translate_text_openai(args.message)
    else:
        try:
            translated_text = translate_text_openai(args.message)
        except Exception as e:
            translated_text = translate_text_google(args.message)

    print(translated_text)