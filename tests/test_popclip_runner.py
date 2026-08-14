import importlib.util
import io
import os
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch


RUNNER_PATH = (
    Path(__file__).parents[1]
    / "popclip"
    / "instantTrans.popclipext"
    / "popclip_runner.py"
)
SPEC = importlib.util.spec_from_file_location("popclip_runner", RUNNER_PATH)
popclip_runner = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(popclip_runner)


class FakeRequest:
    def __init__(self, **values):
        self.__dict__.update(values)


class FakeEngine:
    result = {}
    requests = []

    def run(self, request):
        self.requests.append(request)
        return self.result


class PopClipRunnerTests(unittest.TestCase):
    def setUp(self):
        FakeEngine.requests = []

    def test_polish_returns_replacement_for_popclip_paste_result(self):
        FakeEngine.result = {"ok": True, "replacement": "Polished text"}
        environment = {
            "POPCLIP_TEXT": "rough text",
            "POPCLIP_OPTION_WRITINGPROVIDER": "deepseek",
            "POPCLIP_OPTION_POLISHSTYLE": "concise",
        }

        output = io.StringIO()
        with (
            patch.dict(os.environ, environment, clear=True),
            patch.object(
                popclip_runner,
                "_load_engine",
                return_value=(FakeRequest, FakeEngine),
            ),
            patch("sys.argv", ["popclip_runner.py", "polish"]),
            redirect_stdout(output),
        ):
            exit_code = popclip_runner.main()

        self.assertEqual(0, exit_code)
        self.assertEqual("Polished text", output.getvalue())
        self.assertEqual("rough text", FakeEngine.requests[0].text)
        self.assertEqual("deepseek", FakeEngine.requests[0].provider)
        self.assertEqual("concise", FakeEngine.requests[0].style)

    def test_suggest_reply_only_copies_the_explicitly_chosen_candidate(self):
        replies = [
            {"label": "直接", "text": "第一条"},
            {"label": "友好", "text": "第二条"},
            {"label": "简短", "text": "第三条"},
        ]
        FakeEngine.result = {"ok": True, "replies": replies}
        copied = []
        environment = {
            "POPCLIP_TEXT": "明确选中的聊天上下文",
            "POPCLIP_OPTION_REPLYINTENT": "polite",
        }

        with (
            patch.dict(os.environ, environment, clear=True),
            patch.object(
                popclip_runner,
                "_load_engine",
                return_value=(FakeRequest, FakeEngine),
            ),
            patch.object(popclip_runner, "_pick_reply", return_value="第二条"),
            patch.object(popclip_runner, "_copy_reply", side_effect=copied.append),
            patch("sys.argv", ["popclip_runner.py", "suggest_reply"]),
        ):
            exit_code = popclip_runner.main()

        self.assertEqual(0, exit_code)
        self.assertEqual(["第二条"], copied)
        self.assertEqual("明确选中的聊天上下文", FakeEngine.requests[0].text)
        self.assertEqual("polite", FakeEngine.requests[0].intent)

    def test_canceling_reply_picker_does_not_change_clipboard(self):
        FakeEngine.result = {
            "ok": True,
            "replies": [
                {"label": "一", "text": "第一条"},
                {"label": "二", "text": "第二条"},
                {"label": "三", "text": "第三条"},
            ],
        }

        with (
            patch.dict(os.environ, {"POPCLIP_TEXT": "聊天上下文"}, clear=True),
            patch.object(
                popclip_runner,
                "_load_engine",
                return_value=(FakeRequest, FakeEngine),
            ),
            patch.object(popclip_runner, "_pick_reply", return_value=None),
            patch.object(popclip_runner, "_copy_reply") as copy_reply,
            patch("sys.argv", ["popclip_runner.py", "suggest_reply"]),
        ):
            exit_code = popclip_runner.main()

        self.assertEqual(0, exit_code)
        copy_reply.assert_not_called()


if __name__ == "__main__":
    unittest.main()
