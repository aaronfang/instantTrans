import os
import pyperclip
import argparse
from deep_translator import GoogleTranslator
from openai import OpenAI

instruction = """You are an adept artificial intelligence translator, especially skilled at converting text from various languages into natural, conversational language. 
    Your goal is to ensure that the translated outcome not only accurately conveys the meaning of the original text but also sounds as if it were spoken by a native language speaker in a friendly and relaxed manner. 
    Please refrain from rigid or overly formal tones, striving instead to give the translation the feel of everyday conversation. Translate the following text between Chinese and English."""

def translate_text_google(text: str) -> str:
    """使用Google翻译 (通过deep-translator，兼容Python 3.13+)"""
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

def translate_text_siliconflow(text: str) -> str:
    """使用硅基流动API进行翻译 (国内免费API，更稳定)"""
    api_key = os.getenv("SILICONFLOW_API_KEY")
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

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--google", action="store_true", help="使用Google翻译（无需API密钥）")
    parser.add_argument("--siliconflow", action="store_true", help="使用硅基流动API（国内免费，推荐）")
    args = parser.parse_args()

    text = pyperclip.paste()
    used_api = ""

    try:
        if args.google:
            # 明确指定使用Google
            translated_text = translate_text_google(text)
            used_api = "Google"
        elif args.siliconflow:
            # 明确指定使用SiliconFlow
            translated_text = translate_text_siliconflow(text)
            used_api = "SiliconFlow"
        else:
            # 默认：优先SiliconFlow，失败时降级到Google
            try:
                translated_text = translate_text_siliconflow(text)
                used_api = "SiliconFlow"
            except Exception:
                translated_text = translate_text_google(text)
                used_api = "Google"
        
        # 将翻译结果和使用的API信息都复制到剪贴板（用特殊分隔符）
        pyperclip.copy(f"{translated_text}|||{used_api}")
        
    except Exception as e:
        # 如果所有翻译都失败，输出错误信息
        print(f"翻译失败: {e}")
        pyperclip.copy(text)  # 保持原文
