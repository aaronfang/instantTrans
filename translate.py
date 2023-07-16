import googletrans
import pyperclip

def translate_text(text, target_language):
    translator = googletrans.Translator()
    translation = translator.translate(text, dest=target_language)
    return translation.text

def main():
    text_to_translate = pyperclip.paste()
    translated_text = translate_text(text_to_translate, 'en')
    pyperclip.copy(translated_text)

if __name__ == "__main__":
    main()