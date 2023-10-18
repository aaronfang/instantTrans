@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

SET project_path=%~dp0
SET "shortcut_path=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup" 

echo 安装依赖...
pip install --upgrade pip
pip install -r "%project_path%\requirements.txt"

echo 将快捷方式复制到启动文件夹...
if exist "%shortcut_path%" (
    echo Shortcut already exists. removing...
    del "%shortcut_path%instantTrans.lnk"
)
mklink "%shortcut_path%instantTrans.lnk" "%project_path%instantTrans.exe"

echo 启动应用程序...
rem 如果程序已经启动，那么不会再次启动

tasklist /FI "IMAGENAME eq instantTrans.exe" 2>NUL | find /I /N "instantTrans.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo Program is running
) else (
    start "" "%project_path%\instantTrans.exe"
)

:: 显示消息，下面的空行不能省略

set p=!^


!
msg %username% /w "安装完成!p!快捷键: ctrl+shift+]!p!优先使用Azure的openai的服务来翻译!p!备用Google的翻译服务!p!Azure Openai服务需要设置环境变量：!p!AZURE_API_BASE!p!AZURE_API_KEY!p!AZURE_API_VERSION!p!AZURE_DEPLOYMENT_NAME