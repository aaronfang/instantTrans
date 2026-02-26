; instantTrans - AutoHotkey v2 版本
; 快捷翻译工具，支持中英互译
; 快捷键: Ctrl+Shift+]

#Requires AutoHotkey v2.0

; 快捷键: Ctrl+Shift+]
^+]:: {
    ; 备份剪贴板内容
    clipboardBackup := ClipboardAll()
    
    ; 定义Python脚本路径
    scriptPath := A_ScriptDir . "\translate.py"
    
    ; 查找Python可执行文件
    venvPath := A_ScriptDir . "\venv\Scripts\python.exe"
    if FileExist(venvPath) {
        pythonPath := venvPath
    } else {
        ; 使用系统Python
        pythonPath := "python"
    }
    
    ; 复制选中的文字
    A_Clipboard := ""  ; 清空剪贴板
    Send "^c"
    if !ClipWait(1) {
        ; 如果没有选中文字，恢复剪贴板并退出
        A_Clipboard := clipboardBackup
        ToolTip "未选中文字"
        SetTimer () => ToolTip(), -1000
        return
    }
    
    ; 保存选中的文字
    selectedText := A_Clipboard
    
    ; 运行Python翻译脚本
    RunWait pythonPath . ' "' . scriptPath . '"', , "Hide"
    
    ; 等待翻译结果
    if !ClipWait(1) {
        A_Clipboard := clipboardBackup
        ToolTip "翻译失败"
        SetTimer () => ToolTip(), -2000
        return
    }
    
    ; 获取翻译结果（格式：翻译文本|||API名称）
    result := A_Clipboard
    
    ; 分离翻译文本和API信息
    if InStr(result, "|||") {
        parts := StrSplit(result, "|||")
        translatedText := parts[1]
        usedAPI := parts[2]
    } else {
        ; 如果没有API信息（旧版本兼容）
        translatedText := result
        usedAPI := "Unknown"
    }
    
    ; 将翻译结果放回剪贴板
    A_Clipboard := translatedText
    
    ; 粘贴翻译结果
    Send "^v"
    
    ; 显示使用的API提示（2.5秒后消失）
    ToolTip "✓ 翻译完成 (" . usedAPI . ")"
    SetTimer () => ToolTip(), -2500
    
    ; 短暂延迟后恢复原剪贴板内容
    Sleep 200
    A_Clipboard := clipboardBackup
}
