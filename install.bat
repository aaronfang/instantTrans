@echo off
chcp 65001 >nul
setlocal EnableExtensions

SET "project_path=%~dp0"
cd /d "%project_path%"
SET "shortcut_path=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
SET "python_exe=%project_path%venv\Scripts\python.exe"
SET "pip_exe=%project_path%venv\Scripts\pip.exe"

echo ========================================
echo instantTrans 安装程序
echo ========================================
echo.

echo [1/5] 创建 Python 虚拟环境...
if exist "%python_exe%" (
    echo 虚拟环境已存在，跳过创建
) else (
    python -m venv "%project_path%venv"
    if errorlevel 1 (
        echo 错误: 无法创建虚拟环境，请确认已安装 Python 并加入 PATH
        pause
        exit /b 1
    )
)

echo [2/5] 安装在线翻译依赖...
"%python_exe%" -m pip install --upgrade pip
"%pip_exe%" install -r "%project_path%requirements.txt"
if errorlevel 1 (
    echo 错误: 在线翻译依赖安装失败
    pause
    exit /b 1
)

echo 验证在线翻译依赖...
"%python_exe%" -c "import pyperclip; import deep_translator; import openai; print('在线环境 OK')"
if errorlevel 1 (
    echo 错误: 在线翻译依赖验证失败
    pause
    exit /b 1
)

echo [3/5] 安装本地模型依赖 (HY-MT1.5 ONNX)...
"%pip_exe%" install -r "%project_path%requirements-local.txt"
if errorlevel 1 (
    echo 警告: 本地模型依赖安装失败，可稍后手动执行:
    echo   venv\Scripts\pip.exe install -r requirements-local.txt
    goto :skip_local_setup
)

echo 验证本地模型依赖...
"%python_exe%" -c "import onnxruntime, transformers, torch, sentencepiece, huggingface_hub; print('本地依赖 OK')"
if errorlevel 1 (
    echo 警告: 本地模型依赖验证失败，跳过模型下载
    goto :skip_local_setup
)

echo [4/5] 下载本地模型 (约 1~2 GB，首次可能需要数分钟)...
echo 模型将保存到: %project_path%models\HY-MT1.5-1.8B-ONNX
echo 提示: 请勿设置 HF_ENDPOINT，直接访问 huggingface.co 通常更稳定
echo.
if defined HF_ENDPOINT (
    echo 检测到 HF_ENDPOINT=%HF_ENDPOINT%，临时清除以避免下载失败
    set "HF_ENDPOINT="
)
"%python_exe%" "%project_path%local_service.py" --setup
if errorlevel 1 (
    echo.
    echo 警告: 本地模型下载/配置失败，可稍后手动重试:
    echo   cd /d "%project_path%"
    echo   venv\Scripts\python.exe local_service.py --setup
    echo.
    goto :after_local_setup
)
echo 本地模型已就绪
echo.

:after_local_setup
echo [5/5] 验证安装结果...
"%python_exe%" "%project_path%translate.py" --check-local > "%TEMP%\instanttrans_check.txt" 2>&1
findstr /C:"deps_ready=1" "%TEMP%\instanttrans_check.txt" >nul
if errorlevel 1 (
    echo 本地模型: 未完全就绪（可稍后使用托盘菜单「配置本地模型」）
) else (
    findstr /C:"model_cached=1" "%TEMP%\instanttrans_check.txt" >nul
    if errorlevel 1 (
        echo 本地模型: 依赖已就绪，模型文件待下载
    ) else (
        echo 本地模型: 完全就绪
    )
)
del "%TEMP%\instanttrans_check.txt" 2>nul
echo 在线翻译: 已就绪（Google 无需密钥；DeepSeek / 硅基流动需设置 API 密钥）
echo.

:skip_local_setup

echo 创建开机启动快捷方式...
if exist "%shortcut_path%\instantTrans.lnk" (
    del "%shortcut_path%\instantTrans.lnk"
)
if exist "%project_path%instantTrans_v2.exe" (
    mklink "%shortcut_path%\instantTrans.lnk" "%project_path%instantTrans_v2.exe" >nul 2>&1
    if errorlevel 1 (
        echo 创建启动项失败，可能需要管理员权限；请手动将 instantTrans_v2.exe 加入启动项
    )
) else if exist "%project_path%instantTrans_v2.ahk" (
    call :CreateStartupShortcut
) else (
    echo 未找到 instantTrans_v2.exe 或 instantTrans_v2.ahk，跳过启动项
)

echo 启动 instantTrans...
if exist "%project_path%instantTrans_v2.exe" (
    tasklist /FI "IMAGENAME eq instantTrans_v2.exe" 2>NUL | find /I /N "instantTrans_v2.exe">NUL
    if errorlevel 1 (
        start "" "%project_path%instantTrans_v2.exe"
    ) else (
        echo 程序已在运行
    )
) else if exist "%project_path%instantTrans_v2.ahk" (
    start "" "%project_path%instantTrans_v2.ahk"
) else (
    echo 请手动运行 instantTrans_v2.ahk
)

echo.
echo ===== 安装完成 =====
echo 快捷键: Ctrl+Shift+]
echo 翻译服务: 托盘右键可切换（自动 / DeepSeek / 硅基流动 / Google / 本地模型）
echo 本地模型: models\HY-MT1.5-1.8B-ONNX
echo 在线 API : 可选设置 SILICONFLOW_API_KEY 或 DEEPSEEK_API_KEY
echo           Google 翻译无需配置
echo 退出 AHK 时会自动释放本地模型显存
echo.
pause
exit /b 0

:CreateStartupShortcut
powershell -NoProfile -Command ^
  "$ws = New-Object -ComObject WScript.Shell;" ^
  "$s = $ws.CreateShortcut('%shortcut_path%\instantTrans.lnk');" ^
  "$ahk = (Get-Command AutoHotkey64.exe -ErrorAction SilentlyContinue).Source;" ^
  "if (-not $ahk) { $ahk = (Get-Command AutoHotkey.exe -ErrorAction SilentlyContinue).Source };" ^
  "if ($ahk) { $s.TargetPath = $ahk; $s.Arguments = '\"%project_path%instantTrans_v2.ahk\"'; $s.WorkingDirectory = '%project_path%'; $s.Save() }" ^
  "else { Write-Host '未找到 AutoHotkey，请安装 AHK v2 或编译 instantTrans_v2.exe' }"
exit /b 0
