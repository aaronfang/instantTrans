@echo off
chcp 65001 >nul
setlocal

SET "project_path=%~dp0"
SET "shortcut_path=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"

echo Installing dependencies...
python -m venv venv
venv\Scripts\python.exe -m pip install --upgrade pip
venv\Scripts\python.exe -m pip install -r "%project_path%requirements.txt"

echo Creating startup shortcut...
if exist "%shortcut_path%\instantTrans.lnk" (
    del "%shortcut_path%\instantTrans.lnk"
)
mklink "%shortcut_path%\instantTrans.lnk" "%project_path%instantTrans_v2.exe"

echo Starting application...
tasklist /FI "IMAGENAME eq instantTrans_v2.exe" 2>NUL | find /I /N "instantTrans_v2.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo Program is already running
) else (
    start "" "%project_path%instantTrans_v2.exe"
)

echo.
echo ===== Installation Complete =====
echo Hotkey: Ctrl+Shift+]
echo Primary: SiliconFlow AI (set SILICONFLOW_API_KEY)
echo Fallback: Google Translate (no config needed)
echo Get API key: https://cloud.siliconflow.cn/account/ak
echo.
pause
