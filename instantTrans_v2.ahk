; instantTrans - AutoHotkey v2 版本
; 快捷翻译工具，支持中英互译
; 快捷键: Ctrl+Shift+]
; 任务栏托盘右键菜单可选择默认翻译服务（自动 / DeepSeek / 硅基流动 / Google / 本地模型）

#Requires AutoHotkey v2.0
#SingleInstance Force

; ===================== 配置 =====================
configFile := A_ScriptDir . "\config.ini"

; 可选翻译服务（key 对应 translate.py 的命令行参数）
services := [
    ["auto",        "自动 (智能降级)"],
    ["deepseek",    "DeepSeek API"],
    ["siliconflow", "硅基流动 API"],
    ["google",      "Google 翻译"],
    ["local",       "本地模型 (HY-MT1.5)"]
]

; 本地模型状态（由 Python --check-local 更新）
localDepsReady := false
localModelCached := false
localServiceRunning := false
localModelLoaded := false
localStatusHints := []
localStatusChecked := false
lastStatusCheckTick := 0

; 读取已保存的默认服务，默认 auto
defaultService := IniRead(configFile, "Settings", "Service", "auto")
if !IsValidService(defaultService)
    defaultService := "auto"

BuildTrayMenu()
SetTimer UpdateLocalModelStatus, -100   ; 启动后后台检测
SetTimer UpdateLocalModelStatus, 30000 ; 每 30 秒刷新本地模型状态
OnExit(ReleaseLocalModelOnExit)

; ===================== 托盘菜单 =====================
TrayExit(*) {
    ExitApp()
}

BuildLocalModelSubmenu() {
    global localDepsReady, localModelCached, localServiceRunning, localModelLoaded
    global localStatusHints, localStatusChecked
    submenu := Menu()

    if !localStatusChecked {
        submenu.Add("正在检测本地环境...", NoOp)
        submenu.Disable("正在检测本地环境...")
        return submenu
    }

    for hint in localStatusHints {
        submenu.Add(hint, NoOp)
        submenu.Disable(hint)
    }
    if !localDepsReady || !localModelCached {
        if localStatusHints.Length
            submenu.Add()
        submenu.Add("配置本地模型...", (*) => PrepareLocalModel())
    } else if !localServiceRunning {
        if localStatusHints.Length
            submenu.Add()
        submenu.Add("启动本地模型服务...", EnsureLocalServiceMenu)
    } else if localModelLoaded {
        if localStatusHints.Length
            submenu.Add()
        submenu.Add("释放本地模型显存", UnloadLocalModel)
    }
    return submenu
}

BuildTrayMenu() {
    global services, defaultService, localDepsReady, localModelCached, localServiceRunning
    global localModelLoaded, localStatusHints, localStatusChecked
    tray := A_TrayMenu
    tray.Delete()

    tray.Add("instantTrans 快捷翻译", NoOp)
    tray.Disable("instantTrans 快捷翻译")
    tray.Add()

    tray.Add("翻译服务", NoOp)
    tray.Disable("翻译服务")
    for svc in services {
        key := svc[1]
        name := svc[2]
        if (key = "local" && localStatusChecked && !localDepsReady)
            displayName := name . " [待配置]"
        else
            displayName := name
        tray.Add(displayName, SelectService.Bind(key))
        if (key = defaultService) {
            try
                tray.Check(displayName)
            catch {
                ; 忽略勾选失败，避免菜单构建中断导致缺少退出项
            }
        }
    }

    tray.Add()
    tray.Add("本地模型状态", BuildLocalModelSubmenu())

    tray.Add()
    tray.Add("快捷键: Ctrl+Shift+]", NoOp)
    tray.Disable("快捷键: Ctrl+Shift+]")
    tray.Add()
    tray.Add("退出(&X)", TrayExit)
}

NoOp(*) {
}

IsValidService(key) {
    global services
    for svc in services {
        if (svc[1] = key)
            return true
    }
    return false
}

GetServiceName(key) {
    global services
    for svc in services {
        if (svc[1] = key)
            return svc[2]
    }
    return key
}

GetPythonPath() {
    venvPath := A_ScriptDir . "\venv\Scripts\python.exe"
    return FileExist(venvPath) ? venvPath : "python"
}

GetPipPath() {
    venvPip := A_ScriptDir . "\venv\Scripts\pip.exe"
    return FileExist(venvPip) ? venvPip : "pip"
}

EnsureVenv() {
    venvPython := A_ScriptDir . "\venv\Scripts\python.exe"
    if FileExist(venvPython)
        return true

    if RunWait("python -m venv venv", A_ScriptDir, "Hide") != 0
        return false

    reqFile := A_ScriptDir . "\requirements.txt"
    if FileExist(reqFile)
        RunWait('"' . A_ScriptDir . '\venv\Scripts\pip.exe" install -r requirements.txt', A_ScriptDir, "Hide")
    return FileExist(venvPython)
}

GetLocalServicePath() {
    return A_ScriptDir . "\local_service.py"
}

RunPythonHidden(scriptPath, extraArgs := "", &output := "") {
    pythonPath := GetPythonPath()
    statusFile := A_Temp . "\instanttrans_status_" . A_TickCount . ".txt"
    if FileExist(statusFile)
        FileDelete(statusFile)

    cmd := Format('"{1}" "{2}" {3} --status-out "{4}"', pythonPath, scriptPath, extraArgs, statusFile)
    exitCode := RunWait(cmd, A_ScriptDir, "Hide")
    output := FileExist(statusFile) ? FileRead(statusFile, "UTF-8") : ""
    try FileDelete(statusFile)
    return exitCode
}

EnsureLocalService() {
    pythonPath := GetPythonPath()
    servicePath := GetLocalServicePath()
    if !FileExist(servicePath)
        return false
    exitCode := RunWait('"' . pythonPath . '" "' . servicePath . '" --ensure', A_ScriptDir, "Hide")
    return exitCode = 0
}

RestartLocalService() {
    pythonPath := GetPythonPath()
    servicePath := GetLocalServicePath()
    if !FileExist(servicePath)
        return false
    RunWait('"' . pythonPath . '" "' . servicePath . '" --stop', A_ScriptDir, "Hide")
    exitCode := RunWait('"' . pythonPath . '" "' . servicePath . '" --ensure', A_ScriptDir, "Hide")
    return exitCode = 0
}

ReleaseLocalModelMemory(stopService := false) {
    pythonPath := GetPythonPath()
    servicePath := GetLocalServicePath()
    if !FileExist(servicePath)
        return
    RunWait('"' . pythonPath . '" "' . servicePath . '" --unload', A_ScriptDir, "Hide")
    if stopService
        RunWait('"' . pythonPath . '" "' . servicePath . '" --stop', A_ScriptDir, "Hide")
}

ReleaseLocalModelOnExit(*) {
    ReleaseLocalModelMemory(true)
}

EnsureLocalServiceMenu(*) {
    if EnsureLocalService() {
        TrayTip("instantTrans", "本地模型后台服务已启动", 1)
        SetTimer () => TrayTip(), -2000
    } else {
        TrayTip("instantTrans", "启动本地模型服务失败", 3)
        SetTimer () => TrayTip(), -2500
    }
    SetTimer UpdateLocalModelStatus, -500
}

UnloadLocalModel(*) {
    ReleaseLocalModelMemory(false)
    TrayTip("instantTrans", "已释放本地模型显存", 1)
    SetTimer () => TrayTip(), -2000
    SetTimer UpdateLocalModelStatus, -500
}

UpdateLocalModelStatus() {
    global localDepsReady, localModelCached, localServiceRunning, localModelLoaded
    global localStatusHints, localStatusChecked, defaultService, configFile, lastStatusCheckTick
    static lastMenuState := ""

    scriptPath := A_ScriptDir . "\translate.py"
    output := ""
    exitCode := RunPythonHidden(scriptPath, "--check-local", &output)
    if (exitCode != 0 || output = "") {
        localDepsReady := false
        localModelCached := false
        localStatusHints := ["无法检测本地模型状态", "请确认已安装 Python 与项目依赖"]
        localStatusChecked := true
        lastStatusCheckTick := A_TickCount
        RebuildTrayMenuIfChanged(&lastMenuState)
        return
    }

    depsReady := false
    modelCached := false
    serviceRunning := false
    modelLoaded := false
    hints := []
    for line in StrSplit(output, "`n", "`r") {
        line := Trim(line)
        if !line
            continue
        if RegExMatch(line, "^deps_ready=(\d+)", &m)
            depsReady := (m[1] = "1")
        else if RegExMatch(line, "^model_cached=(\d+)", &m)
            modelCached := (m[1] = "1")
        else if RegExMatch(line, "^service_running=(\d+)", &m)
            serviceRunning := (m[1] = "1")
        else if RegExMatch(line, "^model_loaded=(\d+)", &m)
            modelLoaded := (m[1] = "1")
        else if RegExMatch(line, "^hint=(.*)$", &m)
            hints.Push(m[1])
    }

    localDepsReady := depsReady
    localModelCached := modelCached
    localServiceRunning := serviceRunning
    localModelLoaded := modelLoaded
    localStatusHints := hints.Length ? hints : ["本地模型状态未知"]
    localStatusChecked := true
    lastStatusCheckTick := A_TickCount

    RebuildTrayMenuIfChanged(&lastMenuState)
}

RebuildTrayMenuIfChanged(&lastMenuState) {
    global localDepsReady, localModelCached, localServiceRunning, localModelLoaded
    global localStatusHints, localStatusChecked, defaultService
    state := defaultService . "|" . localDepsReady . "|" . localModelCached . "|" . localServiceRunning
    state .= "|" . localModelLoaded . "|" . localStatusChecked . "|" . localStatusHints.Length
    if (state = lastMenuState)
        return
    lastMenuState := state
    BuildTrayMenu()
}

; 本地模型配置进度
setupGui := ""
setupProgressText := ""
setupProgressBar := ""
setupProgressFile := ""
setupBusy := false

ShowSetupProgress(message := "正在准备...") {
    global setupGui, setupProgressText, setupProgressBar
    if setupGui {
        setupProgressText.Value := message
        return
    }
    setupGui := Gui("+AlwaysOnTop -MaximizeBox +MinimizeBox", "配置本地模型")
    setupGui.SetFont("s10", "Microsoft YaHei UI")
    setupGui.Add("Text", "w420 Center", "instantTrans 正在配置本地翻译环境")
    setupGui.Add("Text", "w420 Center cGray", "首次安装约需数分钟，请勿关闭此窗口")
    setupProgressText := setupGui.Add("Text", "w420 Center", message)
    setupProgressBar := setupGui.Add("Progress", "w420 h22", 0)
    setupProgressBar.Opt("+851")
    setupGui.Show("AutoSize Center")
}

UpdateSetupProgressBar(pct) {
    global setupProgressBar
    if !setupProgressBar
        return
    if (pct < 0) {
        setupProgressBar.Opt("+851")
    } else {
        setupProgressBar.Opt("-851")
        setupProgressBar.Value := Max(0, Min(100, pct))
    }
}

HideSetupProgress() {
    global setupGui, setupProgressText, setupProgressBar
    if setupGui
        setupGui.Destroy()
    setupGui := ""
    setupProgressText := ""
    setupProgressBar := ""
}

ParseSetupProgressFile(path, &message, &pct, &step) {
    message := "正在配置..."
    pct := -1
    step := ""
    if !FileExist(path)
        return false
    try content := FileRead(path, "UTF-8")
    catch
        return false
    for line in StrSplit(content, "`n", "`r") {
        line := Trim(line)
        if RegExMatch(line, "^message=(.*)$", &m)
            message := m[1]
        else if RegExMatch(line, "^pct=(-?\d+)$", &m)
            pct := Integer(m[1])
        else if RegExMatch(line, "^step=(.*)$", &m)
            step := m[1]
    }
    return true
}

RefreshSetupProgressDisplay() {
    global setupProgressFile
    message := ""
    pct := -1
    step := ""
    if ParseSetupProgressFile(setupProgressFile, &message, &pct, &step) {
        if message
            ShowSetupProgress(message)
        UpdateSetupProgressBar(pct)
    }
}

PrepareLocalModel(*) {
    global localDepsReady, localModelCached, localStatusChecked
    global setupProgressFile, setupBusy

    if setupBusy
        return false
    if localStatusChecked && localDepsReady && localModelCached
        return EnsureLocalService()

    setupBusy := true
    ShowSetupProgress("正在创建 Python 虚拟环境...")

    if !EnsureVenv() {
        HideSetupProgress()
        setupBusy := false
        TrayTip("instantTrans", "无法创建 Python 虚拟环境", 3)
        SetTimer () => TrayTip(), -2500
        return false
    }

    pythonPath := GetPythonPath()
    servicePath := GetLocalServicePath()
    if !FileExist(servicePath) {
        HideSetupProgress()
        setupBusy := false
        TrayTip("instantTrans", "未找到 local_service.py", 3)
        SetTimer () => TrayTip(), -2500
        return false
    }

    setupProgressFile := A_Temp . "\instanttrans_setup_" . A_TickCount . ".txt"
    if FileExist(setupProgressFile)
        FileDelete(setupProgressFile)

    ShowSetupProgress("正在启动配置...")
    cmd := Format(
        '"{1}" "{2}" --setup --progress-out "{3}"',
        pythonPath, servicePath, setupProgressFile
    )

    SetTimer RefreshSetupProgressDisplay, 400
    exitCode := RunWait(cmd, A_ScriptDir, "Hide")
    SetTimer RefreshSetupProgressDisplay, 0
    RefreshSetupProgressDisplay()

    errMsg := ""
    if (exitCode != 0) {
        message := ""
        pct := -1
        step := ""
        ParseSetupProgressFile(setupProgressFile, &message, &pct, &step)
        errMsg := (step = "error" && message) ? message : "本地模型配置失败，请检查网络后重试"
    }

    try FileDelete(setupProgressFile)
    HideSetupProgress()
    setupBusy := false
    UpdateLocalModelStatus()

    if (exitCode != 0) {
        TrayTip("instantTrans", errMsg, 3)
        SetTimer () => TrayTip(), -4000
        return false
    }

    RestartLocalService()
    TrayTip("instantTrans", "本地模型已就绪", 1)
    SetTimer () => TrayTip(), -2000
    return true
}

EnsureLocalReady() {
    global localDepsReady, localModelCached, localStatusChecked

    if !localStatusChecked
        UpdateLocalModelStatus()
    if localDepsReady && localModelCached
        return EnsureLocalService()
    return PrepareLocalModel()
}

InstallLocalDeps(*) {
    PrepareLocalModel()
}

SelectService(serviceKey, *) {
    global defaultService, configFile

    if (serviceKey = "local") {
        if !EnsureLocalReady()
            return
    }

    defaultService := serviceKey
    IniWrite(serviceKey, configFile, "Settings", "Service")
    BuildTrayMenu()
    TrayTip("instantTrans", "已切换翻译服务: " . GetServiceName(serviceKey), 1)
    SetTimer () => TrayTip(), -1500
}

GetServiceFlag(key) {
    switch key {
        case "local":       return " --local"
        case "deepseek":    return " --deepseek"
        case "siliconflow": return " --siliconflow"
        case "google":      return " --google"
        default:            return ""
    }
}

; ===================== 快捷键: Ctrl+Shift+] =====================
^+]:: {
    global defaultService

    if (defaultService = "local") {
        if !EnsureLocalReady()
            return
    }

    clipboardBackup := ClipboardAll()
    scriptPath := A_ScriptDir . "\translate.py"
    pythonPath := GetPythonPath()

    A_Clipboard := ""
    Send "^c"
    if !ClipWait(1) {
        A_Clipboard := clipboardBackup
        ToolTip "未选中文字"
        SetTimer () => ToolTip(), -1000
        return
    }

    flag := GetServiceFlag(defaultService)
    ToolTip "翻译中... (" . GetServiceName(defaultService) . ")"

    RunWait('"' . pythonPath . '" "' . scriptPath . '"' . flag, A_ScriptDir, "Hide")

    if !ClipWait(1) {
        ToolTip()
        A_Clipboard := clipboardBackup
        ToolTip "翻译失败"
        SetTimer () => ToolTip(), -2000
        return
    }

    result := A_Clipboard
    if InStr(result, "|||") {
        parts := StrSplit(result, "|||")
        translatedText := parts[1]
        usedAPI := parts[2]
    } else {
        translatedText := result
        usedAPI := "Unknown"
    }

    if (usedAPI = "ERROR" || SubStr(usedAPI, 1, 6) = "ERROR:") {
        ToolTip()
        A_Clipboard := clipboardBackup
        ToolTip "翻译失败 (本地模型)"
        SetTimer () => ToolTip(), -2500
        return
    }

    A_Clipboard := translatedText
    Send "^v"

    ToolTip "✓ 翻译完成 (" . usedAPI . ")"
    SetTimer () => ToolTip(), -2500

    Sleep 200
    A_Clipboard := clipboardBackup
}
