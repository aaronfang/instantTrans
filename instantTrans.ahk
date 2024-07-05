^+]::
    ; Backup clipboard content
    clipboardBackup := ClipboardAll
    
    ; Define the path to the virtual environment and the Python script
    venvPath := A_ScriptDir . "\venv\Scripts\python.exe"
    scriptPath := A_ScriptDir . "\translate.py"
    
    ; Copy selected text
    Send, ^c
    ClipWait, 1
    if (!ErrorLevel) {
        ; Run Python script with virtual environment
        RunWait, %venvPath% %scriptPath%, , Hide

        ; Wait for the new clipboard content
        ClipWait, 1
        
        ; Paste translated text
        Send, ^v

        ; Restore clipboard content after a delay
        ; Sleep, 500
        Clipboard := clipboardBackup
    } else {
        ; Restore clipboard content immediately if no text was selected
        Clipboard := clipboardBackup
    }
return