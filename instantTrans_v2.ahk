; instantTrans - AutoHotkey v2 版本
; 鼠标选中文字后，在指针附近显示翻译 / 润色 / 回复工具条。

#Requires AutoHotkey v2.0
#SingleInstance Force

; MouseGetPos / Menu.Show / Gui.Show must use the same screen coordinate space.
CoordMode "Mouse", "Screen"
CoordMode "Menu", "Screen"
CoordMode "ToolTip", "Screen"

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

; 划词工具条状态
selectionToolbarEnabled := IniRead(configFile, "Settings", "SelectionToolbar", "1") != "0"
notificationsEnabled := IniRead(configFile, "Settings", "Notifications", "1") != "0"
selectionContext := Map()
selectionToolbarGui := 0
replyPanelGui := 0
replyPanelExtraEdit := 0
replyPanelContext := Map()
replyPanelIntent := "auto"
polishMenu := 0
replyMenu := 0
mouseDownX := 0
mouseDownY := 0
mouseDownHwnd := 0
mouseDownTick := 0
lastClickX := 0
lastClickY := 0
lastClickTick := 0
selectionOperationBusy := false
operationProcessId := 0
operationResultDir := ""
operationKind := ""
operationContext := Map()

; 读取已保存的默认服务，默认 auto
defaultService := IniRead(configFile, "Settings", "Service", "auto")
if !IsValidService(defaultService)
    defaultService := "auto"

BuildTrayMenu()
BuildActionMenus()
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
    global selectionToolbarEnabled, notificationsEnabled
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
    tray.Add("启用划词工具条", ToggleSelectionToolbar)
    if selectionToolbarEnabled
        tray.Check("启用划词工具条")
    tray.Add("显示系统通知", ToggleNotifications)
    if notificationsEnabled
        tray.Check("显示系统通知")
    tray.Add("使用方法: 鼠标拖选文字", NoOp)
    tray.Disable("使用方法: 鼠标拖选文字")
    tray.Add()
    tray.Add("退出(&X)", TrayExit)
}

ToggleSelectionToolbar(*) {
    global selectionToolbarEnabled, configFile
    selectionToolbarEnabled := !selectionToolbarEnabled
    IniWrite(selectionToolbarEnabled ? "1" : "0", configFile, "Settings", "SelectionToolbar")
    HideSelectionToolbar()
    BuildTrayMenu()
}

ToggleNotifications(*) {
    global notificationsEnabled, configFile
    notificationsEnabled := !notificationsEnabled
    IniWrite(notificationsEnabled ? "1" : "0", configFile, "Settings", "Notifications")
    BuildTrayMenu()
}

ShowSystemNotification(message, icon := 1, durationMs := 2000) {
    global notificationsEnabled
    if !notificationsEnabled
        return
    TrayTip("instantTrans", message, icon)
    SetTimer(() => TrayTip(), -durationMs)
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
        ShowSystemNotification("本地模型后台服务已启动", 1, 2000)
    } else {
        ShowSystemNotification("启动本地模型服务失败", 3, 2500)
    }
    SetTimer UpdateLocalModelStatus, -500
}

UnloadLocalModel(*) {
    ReleaseLocalModelMemory(false)
    ShowSystemNotification("已释放本地模型显存", 1, 2000)
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
        ShowSystemNotification("无法创建 Python 虚拟环境", 3, 2500)
        return false
    }

    pythonPath := GetPythonPath()
    servicePath := GetLocalServicePath()
    if !FileExist(servicePath) {
        HideSetupProgress()
        setupBusy := false
        ShowSystemNotification("未找到 local_service.py", 3, 2500)
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
        ShowSystemNotification(errMsg, 3, 4000)
        return false
    }

    RestartLocalService()
    ShowSystemNotification("本地模型已就绪", 1, 2000)
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
    ShowSystemNotification("已切换翻译服务: " . GetServiceName(serviceKey), 1, 1500)
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

BuildActionMenus() {
    global polishMenu, replyMenu
    polishMenu := Menu()
    polishMenu.Add("自然流畅", RunPolish.Bind("natural"))
    polishMenu.Add("简洁精炼", RunPolish.Bind("concise"))
    polishMenu.Add("专业正式", RunPolish.Bind("professional"))
    polishMenu.Add("亲切友好", RunPolish.Bind("friendly"))
    polishMenu.Add("更有说服力", RunPolish.Bind("persuasive"))

    replyMenu := Menu()
    replyMenu.Add("自动推荐", RunReply.Bind("auto"))
    replyMenu.Add("赞同回应", RunReply.Bind("agree"))
    replyMenu.Add("继续话题", RunReply.Bind("continue"))
    replyMenu.Add("轻松幽默", RunReply.Bind("humorous"))
    replyMenu.Add("礼貌回应", RunReply.Bind("polite"))
    replyMenu.Add("委婉拒绝", RunReply.Bind("decline"))
    replyMenu.Add("安慰共情", RunReply.Bind("empathetic"))
}

~LButton:: {
    global mouseDownX, mouseDownY, mouseDownHwnd, mouseDownTick
    MouseGetPos(&mouseDownX, &mouseDownY, &mouseDownHwnd)
    if IsInstantTransHwnd(mouseDownHwnd)
        return
    mouseDownTick := A_TickCount
}

~LButton Up:: {
    global selectionToolbarEnabled, mouseDownX, mouseDownY, mouseDownHwnd
    global lastClickX, lastClickY, lastClickTick

    if !selectionToolbarEnabled || IsInstantTransWindow()
        return

    MouseGetPos(&x, &y, &hwnd)
    if IsInstantTransHwnd(hwnd)
        return
    moved := Abs(x - mouseDownX) >= 5 || Abs(y - mouseDownY) >= 5
    doubleClicked := (A_TickCount - lastClickTick <= DllCall("GetDoubleClickTime"))
        && Abs(x - lastClickX) <= 6 && Abs(y - lastClickY) <= 6
    lastClickX := x
    lastClickY := y
    lastClickTick := A_TickCount

    if moved || doubleClicked {
        SetTimer(() => ProbeSelection(mouseDownHwnd, x, y), -120)
    } else {
        HideSelectionToolbar()
    }
}

~WheelUp::HideSelectionToolbar()
~WheelDown::HideSelectionToolbar()
~Esc::HideSelectionToolbar()

IsInstantTransWindow() {
    try {
        title := WinGetTitle("A")
        return InStr(title, "instantTrans")
    } catch {
        return false
    }
}

IsInstantTransHwnd(hwnd) {
    if !hwnd
        return false
    try {
        rootHwnd := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
        title := WinGetTitle("ahk_id " . (rootHwnd || hwnd))
        return InStr(title, "instantTrans")
    } catch {
        return false
    }
}

ProbeSelection(sourceHwnd, mouseX, mouseY) {
    global selectionToolbarEnabled, selectionOperationBusy, selectionContext
    if !selectionToolbarEnabled || selectionOperationBusy || !WinExist("ahk_id " . sourceHwnd)
        return
    if WinGetID("A") != sourceHwnd
        return
    if IsSensitiveSelectionSource(sourceHwnd)
        return

    backup := ClipboardAll()
    A_Clipboard := ""
    Send "^c"
    copied := ClipWait(0.45, true)
    text := copied ? A_Clipboard : ""
    A_Clipboard := backup

    if !copied || !Trim(text) || StrLen(text) > 12000 {
        HideSelectionToolbar()
        return
    }

    selectionContext := Map(
        "text", text,
        "hwnd", sourceHwnd,
        "focusHwnd", GetFocusedControlHwnd(sourceHwnd),
        "mouseX", mouseX,
        "mouseY", mouseY,
        "capturedAt", A_TickCount
    )
    ShowSelectionToolbar(mouseX, mouseY)
}

ShowSelectionToolbar(mouseX, mouseY) {
    global selectionToolbarGui
    HideSelectionToolbar()

    toolbarWindow := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000", "instantTrans 工具条")
    toolbarWindow.MarginX := 4
    toolbarWindow.MarginY := 4
    toolbarWindow.BackColor := "0F172A"
    toolbarWindow.SetFont("s9 cFFFFFF", "Segoe UI")
    toolbarWindow.AddButton("x4 y4 w62 h28", "⚡ 翻译").OnEvent("Click", (*) => RunSelectionOperation("translate"))
    toolbarWindow.AddButton("x68 y4 w72 h28", "✨ 润色").OnEvent("Click", (*) => RunPolish("natural"))
    toolbarWindow.AddButton("x142 y4 w24 h28", "▾").OnEvent("Click", ShowPolishMenu)
    toolbarWindow.AddButton("x168 y4 w72 h28", "💬 回复").OnEvent("Click", (*) => RunReply("auto"))
    toolbarWindow.AddButton("x242 y4 w24 h28", "▾").OnEvent("Click", ShowReplyMenu)
    selectionToolbarGui := toolbarWindow

    GetWorkAreaForPoint(mouseX, mouseY, &left, &top, &right, &bottom)
    x := mouseX + 12
    y := mouseY + 14
    if x + 274 > right
        x := Max(left + 4, mouseX - 274)
    if y + 40 > bottom
        y := Max(top + 4, mouseY - 46)
    toolbarWindow.Show("NoActivate x" . x . " y" . y . " AutoSize")
    SetTimer(HideSelectionToolbar, -9000)
}

HideSelectionToolbar(*) {
    global selectionToolbarGui
    if IsObject(selectionToolbarGui) {
        try selectionToolbarGui.Destroy()
    }
    selectionToolbarGui := 0
}

ShowPolishMenu(*) {
    global polishMenu
    SetTimer(HideSelectionToolbar, 0)
    polishMenu.Show()
}

ShowReplyMenu(*) {
    global replyMenu
    SetTimer(HideSelectionToolbar, 0)
    replyMenu.Show()
}

RunPolish(style, *) {
    RunSelectionOperation("polish", style)
}

RunReply(intent, *) {
    RunSelectionOperation("suggest_reply", intent)
}

RunSelectionOperation(operation, option := "", extraInstruction := "", contextOverride := 0) {
    global selectionContext, selectionOperationBusy, defaultService
    global operationProcessId, operationResultDir, operationKind, operationContext
    activeContext := IsObject(contextOverride) ? contextOverride : selectionContext
    if selectionOperationBusy || !activeContext.Has("text")
        return
    if operation = "translate" && defaultService = "local" && !EnsureLocalReady()
        return

    selectionOperationBusy := true
    resultDir := ""
    try {
        HideSelectionToolbar()
        label := operation = "translate" ? "翻译" : operation = "polish" ? "润色" : "生成回复"
        ToolTip(label . "中...")

        resultDir := A_Temp . "\instanttrans_" . A_TickCount . "_" . DllCall("GetCurrentProcessId")
        DirCreate(resultDir)
        requestPath := resultDir . "\request.json"
        responsePath := resultDir . "\response.json"
        request := Map(
            "operation", operation,
            "text", activeContext["text"],
            "provider", defaultService
        )
        if operation = "polish" {
            request["style"] := option
            if defaultService = "google" || defaultService = "local"
                request["provider"] := "auto"
        } else if operation = "suggest_reply" {
            request["intent"] := option
            request["extraInstruction"] := extraInstruction
            if defaultService = "google" || defaultService = "local"
                request["provider"] := "auto"
        }

        FileAppend(JsonStringify(request), requestPath, "UTF-8")
        pythonPath := GetPythonPath()
        cliPath := A_ScriptDir . "\assistant_cli.py"
        cmd := Format('"{1}" "{2}" --request "{3}" --response "{4}" --desktop-dir "{5}"',
            pythonPath, cliPath, requestPath, responsePath, resultDir)
        Run(cmd, A_ScriptDir, "Hide", &pid)
        operationProcessId := pid
        operationResultDir := resultDir
        operationKind := operation
        operationContext := activeContext.Clone()
        operationContext["option"] := option
        operationContext["extraInstruction"] := extraInstruction
        SetTimer(CheckSelectionOperation, 150)
        return
    } catch as error {
        ToolTip("操作失败: " . error.Message)
        SetTimer(() => ToolTip(), -3500)
        selectionOperationBusy := false
        if resultDir
            CleanupResultDirectory(resultDir)
    }
}

CheckSelectionOperation() {
    global selectionOperationBusy, operationProcessId, operationResultDir
    global operationKind, operationContext
    if operationProcessId && ProcessExist(operationProcessId)
        return

    SetTimer(CheckSelectionOperation, 0)
    ToolTip()
    resultDir := operationResultDir
    operation := operationKind
    context := operationContext
    try {
        statusPath := resultDir . "\status.ini"
        ok := FileExist(statusPath) ? IniRead(statusPath, "Result", "Ok", "0") = "1" : false
        if !ok {
            errorText := ReadUtf8File(resultDir . "\error.txt")
            if !errorText
                errorText := "操作失败，请检查 API Key 和网络连接"
            ToolTip(errorText)
            SetTimer(() => ToolTip(), -3500)
        } else if operation = "suggest_reply" {
            ShowReplyPanel(resultDir, context)
        } else {
            replacement := ReadUtf8File(resultDir . "\replacement.txt")
            ApplyReplacementOrCopy(
                replacement,
                context["hwnd"],
                context["focusHwnd"],
                context["capturedAt"]
            )
        }
    } catch as error {
        ToolTip("读取结果失败: " . error.Message)
        SetTimer(() => ToolTip(), -3500)
    } finally {
        selectionOperationBusy := false
        operationProcessId := 0
        operationResultDir := ""
        operationKind := ""
        operationContext := Map()
        if resultDir
            CleanupResultDirectory(resultDir)
    }
}

ApplyReplacementOrCopy(text, sourceHwnd, originalFocusHwnd, capturedAt) {
    if !text
        return
    ; Never reactivate a window after a slow model call. If the user changed
    ; context, copy-only is safer than pasting into an unrelated caret.
    if !WinExist("ahk_id " . sourceHwnd)
        || WinGetID("A") != sourceHwnd
        || A_TickCount - capturedAt > 90000
        || (originalFocusHwnd && GetFocusedControlHwnd(sourceHwnd) != originalFocusHwnd) {
        A_Clipboard := text
        ShowSystemNotification("输入位置已变化，结果已复制", 2, 2500)
        return
    }

    replaceMode := GetReplacementMode(originalFocusHwnd)
    if replaceMode = "copy" {
        A_Clipboard := text
        ShowSystemNotification("当前区域不可确认可编辑，结果已复制", 2, 2500)
        return
    }

    backup := ClipboardAll()
    A_Clipboard := text
    ClipWait(0.5)
    Send "^v"
    Sleep 300
    if replaceMode = "verified" {
        ShowSystemNotification("✓ 已替换选中文字", 1, 1800)
        A_Clipboard := backup
    } else {
        ; Chromium/Electron 等自绘输入区无法可靠验证粘贴是否生效。
        ; 保留结果在剪贴板，避免只读区域静默吞掉结果。
        ShowSystemNotification("已尝试替换；结果保留在剪贴板", 2, 2500)
    }
}

ShowReplyPanel(resultDir, context) {
    global replyPanelGui, replyPanelExtraEdit, replyPanelContext, replyPanelIntent
    if IsObject(replyPanelGui) {
        try replyPanelGui.Destroy()
    }

    replyPanelContext := context.Clone()
    replyPanelIntent := context.Has("option") ? context["option"] : "auto"
    previousInstruction := context.Has("extraInstruction") ? context["extraInstruction"] : ""
    focus := ReadUtf8File(resultDir . "\reply_focus.txt")
    replyWindow := Gui("+AlwaysOnTop +ToolWindow", "instantTrans 建议回复")
    replyWindow.SetFont("s10", "Segoe UI")
    replyWindow.MarginX := 14
    replyWindow.MarginY := 12
    replyWindow.AddText("w440 c555555", focus ? "正在回复：" . focus : "请选择一条建议回复")

    y := 42
    for index in [1, 2, 3] {
        label := ReadUtf8File(resultDir . "\reply_" . index . "_label.txt")
        text := ReadUtf8File(resultDir . "\reply_" . index . "_text.txt")
        meaning := ReadUtf8File(resultDir . "\reply_" . index . "_meaning.txt")
        if !text
            continue
        replyWindow.SetFont("s9 Bold", "Segoe UI")
        replyWindow.AddText("x14 y" . y . " w420", label ? label : "建议 " . index)
        y += 22
        replyWindow.SetFont("s10 Norm", "Segoe UI")
        replyWindow.AddEdit("x14 y" . y . " w350 r3 ReadOnly -VScroll", text)
        replyWindow.AddButton("x372 y" . y . " w70 h62", "复制").OnEvent("Click", CopyReply.Bind(text))
        y += 66
        if meaning {
            replyWindow.SetFont("s8 c666666", "Segoe UI")
            replyWindow.AddText("x14 y" . y . " w428", "中文释义：" . meaning)
            y += 34
        }
        y += 10
    }

    replyWindow.SetFont("s9 Bold c333333", "Segoe UI")
    replyWindow.AddText("x14 y" . y . " w428", "我想表达什么（可选）")
    y += 22
    replyWindow.SetFont("s10 Norm c000000", "Segoe UI")
    replyPanelExtraEdit := replyWindow.AddEdit(
        "x14 y" . y . " w340 r2",
        previousInstruction
    )
    replyWindow.AddButton("x364 y" . y . " w78 h48", "重新生成")
        .OnEvent("Click", RegenerateReplies)
    y += 62
    replyWindow.AddText(
        "x14 y" . y . " w428 c777777",
        "补充你希望回复的方向、立场或必须包含的信息。"
    )
    y += 28

    replyPanelGui := replyWindow
    replyWindow.OnEvent("Close", CloseReplyPanel)

    anchorX := context.Has("mouseX") ? context["mouseX"] : 0
    anchorY := context.Has("mouseY") ? context["mouseY"] : 0
    if !anchorX && !anchorY
        MouseGetPos(&anchorX, &anchorY)
    GetWorkAreaForPoint(anchorX, anchorY, &left, &top, &right, &bottom)

    ; Measure the actual AutoSize dimensions before clamping to the monitor.
    replyWindow.Show("Hide AutoSize")
    replyWindow.GetPos(, , &panelWidth, &panelHeight)
    panelX := Min(Max(left + 8, anchorX + 14), right - panelWidth - 8)
    panelY := anchorY + 18
    if panelY + panelHeight > bottom - 8
        panelY := Max(top + 8, anchorY - panelHeight - 14)
    replyWindow.Show("x" . panelX . " y" . panelY)
}

RegenerateReplies(*) {
    global replyPanelExtraEdit, replyPanelContext, replyPanelIntent
    if !IsObject(replyPanelExtraEdit) || !IsObject(replyPanelContext)
        return
    instruction := Trim(replyPanelExtraEdit.Value)
    CloseReplyPanel()
    RunSelectionOperation(
        "suggest_reply",
        replyPanelIntent,
        instruction,
        replyPanelContext
    )
}

CloseReplyPanel(*) {
    global replyPanelGui, replyPanelExtraEdit
    if IsObject(replyPanelGui) {
        try replyPanelGui.Destroy()
    }
    replyPanelGui := 0
    replyPanelExtraEdit := 0
}

CopyReply(text, *) {
    A_Clipboard := text
    ShowSystemNotification("建议回复已复制", 1, 1800)
}

ReadUtf8File(path) {
    return FileExist(path) ? FileRead(path, "UTF-8") : ""
}

CleanupResultDirectory(path) {
    try {
        if DirExist(path)
            DirDelete(path, true)
    }
}

GetFocusedControlHwnd(windowHwnd) {
    try {
        controlName := ControlGetFocus("ahk_id " . windowHwnd)
        return controlName ? ControlGetHwnd(controlName, "ahk_id " . windowHwnd) : 0
    } catch {
        return 0
    }
}

IsSensitiveSelectionSource(windowHwnd) {
    try {
        processName := StrLower(WinGetProcessName("ahk_id " . windowHwnd))
        for blocked in ["1password.exe", "keepass.exe", "keepassxc.exe", "bitwarden.exe",
            "credentialuibroker.exe", "logonui.exe"] {
            if processName = blocked
                return true
        }
        focused := GetFocusedControlHwnd(windowHwnd)
        if focused {
            style := ControlGetStyle(focused)
            if style & 0x20 ; ES_PASSWORD
                return true
        }
    }
    return false
}

GetReplacementMode(controlHwnd) {
    if !controlHwnd
        ; WeChat and other custom-rendered editors often expose no standard
        ; child control. Keep the source window/focus checks, attempt paste,
        ; and retain the generated result in the clipboard as a safe fallback.
        return "unverified"
    try {
        className := WinGetClass("ahk_id " . controlHwnd)
        if RegExMatch(className, "i)^(Edit|RichEdit|RICHEDIT)") {
            style := ControlGetStyle(controlHwnd)
            return style & 0x800 ? "copy" : "verified" ; ES_READONLY
        }
        if RegExMatch(className, "i)(Chrome_RenderWidgetHostHWND|Internet Explorer_Server)")
            return "unverified"
    }
    return "unverified"
}

GetWorkAreaForPoint(x, y, &left, &top, &right, &bottom) {
    count := MonitorGetCount()
    Loop count {
        MonitorGet(A_Index, &monitorLeft, &monitorTop, &monitorRight, &monitorBottom)
        if x >= monitorLeft && x < monitorRight && y >= monitorTop && y < monitorBottom {
            MonitorGetWorkArea(A_Index, &left, &top, &right, &bottom)
            return
        }
    }
    MonitorGetWorkArea(MonitorGetPrimary(), &left, &top, &right, &bottom)
}

JsonStringify(value) {
    if value is Map {
        parts := []
        for key, item in value
            parts.Push(JsonStringify(String(key)) . ":" . JsonStringify(item))
        return "{" . JoinStrings(parts, ",") . "}"
    }
    if IsNumber(value)
        return String(value)
    if value = true
        return "true"
    if value = false
        return "false"
    text := String(value)
    text := StrReplace(text, "\", "\\")
    text := StrReplace(text, '"', '\"')
    text := StrReplace(text, "`r", "\r")
    text := StrReplace(text, "`n", "\n")
    text := StrReplace(text, "`t", "\t")
    return '"' . text . '"'
}

JoinStrings(items, separator) {
    result := ""
    for index, item in items
        result .= (index > 1 ? separator : "") . item
    return result
}
