import json
import tempfile
import unittest
from pathlib import Path

from assistant_engine import (
    OperationRequest,
    WritingEngine,
    run_request_file,
    write_desktop_result,
)


class FakeProvider:
    def __init__(self, responses=None, error=None):
        self.responses = list(responses or [])
        self.error = error
        self.calls = []

    def generate(self, text, system_prompt, **options):
        self.calls.append(
            {"text": text, "system_prompt": system_prompt, "options": options}
        )
        if self.error:
            raise self.error
        return self.responses.pop(0)


class WritingEngineTests(unittest.TestCase):
    def test_translate_uses_requested_translation_adapter(self):
        engine = WritingEngine(
            providers={},
            translators={"google": lambda text: ("Hello", "Google")},
        )

        result = engine.run(
            OperationRequest(
                operation="translate",
                text="你好",
                provider="google",
            )
        )

        self.assertTrue(result["ok"])
        self.assertEqual("Hello", result["replacement"])
        self.assertEqual("Google", result["provider"])

    def test_polish_falls_back_and_returns_replacement(self):
        deepseek = FakeProvider(error=RuntimeError("unavailable"))
        siliconflow = FakeProvider(responses=["这句话表达得更加自然。"])
        engine = WritingEngine(
            providers={"deepseek": deepseek, "siliconflow": siliconflow}
        )

        result = engine.run(
            OperationRequest(
                operation="polish",
                text="这句话表达的更加自然",
                style="natural",
                provider="auto",
            )
        )

        self.assertTrue(result["ok"])
        self.assertEqual("SiliconFlow", result["provider"])
        self.assertEqual("这句话表达得更加自然。", result["replacement"])
        self.assertIn("SAME LANGUAGE", siliconflow.calls[0]["system_prompt"])

    def test_reply_generation_retries_invalid_payload_and_enforces_language(self):
        invalid = "not-json"
        valid = json.dumps(
            {
                "replyFocus": "对方在确认交付时间",
                "replies": [
                    {"label": "直接", "text": "今天下午可以完成。", "meaning": ""},
                    {"label": "友好", "text": "可以的，我下午做好就发你。", "meaning": ""},
                    {"label": "稳妥", "text": "我先确认剩余工作，下午给你。", "meaning": ""},
                ],
            },
            ensure_ascii=False,
        )
        deepseek = FakeProvider(responses=[invalid, valid])
        engine = WritingEngine(providers={"deepseek": deepseek})

        result = engine.run(
            OperationRequest(
                operation="suggest_reply",
                text="张三\n今天下午能发我吗？",
                intent="auto",
                provider="deepseek",
            )
        )

        self.assertTrue(result["ok"])
        self.assertEqual("zh", result["replyLanguage"])
        self.assertEqual(3, len(result["replies"]))
        self.assertEqual(2, len(deepseek.calls))
        self.assertIn("CRITICAL CORRECTION", deepseek.calls[1]["system_prompt"])

    def test_request_file_is_a_utf8_json_interface(self):
        provider = FakeProvider(responses=["Polished text"])
        engine = WritingEngine(providers={"deepseek": provider})

        with tempfile.TemporaryDirectory() as directory:
            request_path = Path(directory) / "request.json"
            response_path = Path(directory) / "response.json"
            request_path.write_text(
                json.dumps(
                    {
                        "operation": "polish",
                        "text": "rough text",
                        "style": "concise",
                        "provider": "deepseek",
                    },
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )

            run_request_file(request_path, response_path, engine=engine)
            response = json.loads(response_path.read_text(encoding="utf-8"))

        self.assertTrue(response["ok"])
        self.assertEqual("Polished text", response["replacement"])

    def test_desktop_result_preserves_multiline_text_without_ini_escaping(self):
        result = {
            "ok": True,
            "provider": "DeepSeek",
            "replacement": "第一行\n第二行🙂",
            "replies": [],
        }
        with tempfile.TemporaryDirectory() as directory:
            write_desktop_result(result, directory)
            root = Path(directory)

            status = (root / "status.ini").read_text(encoding="utf-16")
            replacement = (root / "replacement.txt").read_text(encoding="utf-8")

        self.assertIn("Ok=1", status)
        self.assertEqual("第一行\n第二行🙂", replacement)


if __name__ == "__main__":
    unittest.main()
