import os
import openai
import pyperclip
import argparse
from googletrans import Translator

openai.api_type = "azure"
openai.api_base = os.getenv("AZURE_API_BASE")
openai.api_version = os.getenv("AZURE_API_VERSION")
openai.api_key = os.getenv("AZURE_API_KEY")

instruction = """You are an adept artificial intelligence translator, especially skilled at converting text from various languages into natural, conversational language. 
    Your goal is to ensure that the translated outcome not only accurately conveys the meaning of the original text but also sounds as if it were spoken by a native language speaker in a friendly and relaxed manner. 
    Please refrain from rigid or overly formal tones, striving instead to give the translation the feel of everyday conversation. Translate the following text between Chinese and English."""

def translate_text_google(text):
    translator = Translator(service_urls=['translate.google.com'])
    translation = translator.translate(text, dest='en')
    return translation.text

def translate_text_openai(text):
    response = openai.ChatCompletion.create(
        engine=os.getenv("AZURE_DEPLOYMENT_NAME"),
        messages = [{"role":"system","content":f"{instruction}"}, {"role": "user", "content": f"{text}"}],
        temperature=0.7,
        max_tokens=2000,
        top_p=0.95,
        frequency_penalty=0,
        presence_penalty=0,
        stop=None)
    return response.choices[0].message['content'].strip()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--google", action="store_true")
    parser.add_argument("--openai", action="store_true")
    args = parser.parse_args()

    text = pyperclip.paste()

    if args.google:
        translated_text = translate_text_google(text)
    elif args.openai:
        translated_text = translate_text_openai(text)
    else:
        try:
            translated_text = translate_text_openai(text)
        except Exception as e:
            translated_text = translate_text_google(text)

    pyperclip.copy(translated_text)
