@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

SET project_path=%~dp0

echo 检查VENV...
IF NOT EXIST "%project_path%\venv\" (
    echo 找不到虚拟环境。创建...
    python -m venv "%project_path%\venv"
)

echo 安装依赖...
"%project_path%\venv\Scripts\python" -m pip install --upgrade pip
"%project_path%\venv\Scripts\python" -m pip install -r "%project_path%\requirements.txt"

echo 将快捷方式复制到启动文件夹...
mklink "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\instantTrans.lnk" "%project_path%\instantTrans.exe"

echo 启动应用程序...
rem 如果程序已经启动，那么不会再次启动

tasklist /FI "IMAGENAME eq instantTrans.exe" 2>NUL | find /I /N "instantTrans.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo Program is running
) else (
    start "" "%project_path%\instantTrans.exe"
)

@REM 显示消息，下面的空行不能省略

set p=!^


!
msg %username% /w "安装完成!p!英译中: alt+shift+[!p!中译英: alt+shift+]"