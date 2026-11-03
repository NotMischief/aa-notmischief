; =====================================================================
; [Design mode] lets Claude work on the interface while you watch, with no pop-ups:
;   - when any macro file changes, the macro reloads itself (only while it is STOPPED)
;   - after loading, it saves a picture of its own window to Logs\ui_preview.png
; On/off: Settings\DesignMode.txt contains On or Off.
; =====================================================================

DM_File() {
    return A_ScriptDir "\Settings\DesignMode.txt"
}

DM_On() {
    try return InStr(FileRead(DM_File(), "UTF-8"), "On") > 0
    return false
}

; newest change time of any macro code file
DM_Stamp() {
    newest := 0   ; times are numbers like 20261030194300
    Loop Files A_ScriptDir "\Lib\*.ahk", "R"
        if (Integer(A_LoopFileTimeModified) > newest)
            newest := Integer(A_LoopFileTimeModified)
    t := Integer(FileGetTime(A_ScriptDir "\Main.ahk"))
    if (t > newest)
        newest := t
    return newest
}

DM_Init() {
    static st := {stamp: ""}
    if !DM_On()
        return
    st.stamp := DM_Stamp()
    SetTimer(DM_Snapshot, -2000)          ; picture of the window once it is drawn
    SetTimer((*) => DM_Watch(st), 2000)   ; reload when Claude changes a file
    AddToLog("[Design] Design mode on - the macro reloads itself when its files change (only while stopped)")
}

DM_Watch(st) {
    if !DM_On()
        return
    now := DM_Stamp()
    if (now != st.stamp) {
        if (MacroLoopState.Active)
            return                          ; never interrupt a running macro
        Sleep(800)                          ; let the edit finish writing
        Reload()
    }
}

DM_Snapshot() {
    global aaMainUI
    try {
        hwnd := "ahk_id " aaMainUI.Hwnd
        wasMin := (WinGetMinMax(hwnd) = -1)
        if (wasMin) {                       ; a minimized window can't be photographed
            WinRestore(hwnd)
            Sleep(600)
        }
        WinGetPos(&x, &y, &w, &h, hwnd)
        pToken := Gdip_Startup()
        pBmp := Gdip_BitmapFromScreen(x "|" y "|" w "|" h)
        Gdip_SaveBitmapToFile(pBmp, A_ScriptDir "\Logs\ui_preview.png")
        Gdip_DisposeImage(pBmp)
        Gdip_Shutdown(pToken)
        FileOpen(A_ScriptDir "\Logs\ui_status.txt", "w", "UTF-8").Write("loaded " FormatTime(, "yyyy-MM-dd HH:mm:ss"))
        if (wasMin)
            WinMinimize(hwnd)
    }
}
