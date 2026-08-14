# Project Guide

## Purpose

`instantTrans` is a cross-platform selected-text assistant. Windows uses
AutoHotkey for global selection capture and Python for translation, polishing,
and suggested replies. macOS uses a PopClip extension.

## Run and verify

- Windows development entry point:

```powershell
& "C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" .\instantTrans_v2.ahk
```

- Python regression tests:

```powershell
python -m unittest discover -s tests -v
python -m py_compile assistant_engine.py assistant_cli.py translate.py
```

- AutoHotkey compile check:

```powershell
& "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" /in .\instantTrans_v2.ahk /out "$env:TEMP\instantTrans-check.exe" /base "C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" /silent verbose
```

## Stack and structure

- `instantTrans_v2.ahk`: Windows tray menu, mouse selection detection, floating
  toolbar, clipboard-safe replacement, and reply window.
- `assistant_engine.py`: unified translate/polish/suggest-reply interface.
- `assistant_cli.py`: UTF-8 JSON file bridge used by AutoHotkey.
- `translate.py`: translation providers and legacy CLI.
- `local_model.py` / `local_service.py`: optional HY-MT local translation.
- `popclip/`: macOS integration.
- `tests/`: dependency-free Python unit tests.

## Conventions

- AutoHotkey identifiers are case-insensitive; never name a local variable
  `gui`, because it shadows the built-in `Gui` constructor.
- Only explicitly selected conversation text may be sent for reply generation.
- Never auto-send a generated reply.
- Preserve the user's clipboard when replacement is verified; for custom
  editors such as WeChat, retain the generated result in the clipboard.
- API keys remain in environment variables and must not enter the repository.

## Current state

- Windows supports a mouse-near toolbar for translation, polishing, and
  context-aware suggested replies.
- Polishing and replies require DeepSeek or SiliconFlow.
- The checked-in historical `.exe` files are ignored build artifacts; source
  changes require rebuilding before release.
