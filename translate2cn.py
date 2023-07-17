import pyperclip
from googletrans import Translator

def translate_text(text):
    translator = Translator(service_urls=['translate.google.com'])
    translation = translator.translate(text, dest='zh-CN')
    return translation.text

def main():
    text = pyperclip.paste()
    translated_text = translate_text(text)
    pyperclip.copy(translated_text)

if __name__ == "__main__":
    main()