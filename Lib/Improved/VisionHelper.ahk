; =====================================================================
; [Python vision] Starts Lib\Improved\vision_helper.py hidden and talks to it through
; small text files in Logs\vision_ipc. It does the heavy screen work fast:
;   placement map (NumPy + OpenCV) and text reading (RapidOCR).
; If Python or its packages aren't there, everything falls back to the AutoHotkey versions.
; Turn off with  PythonVision=Off  in Settings\UnitTypes.txt (or the F6 window).
; =====================================================================

VH_S() {
    static st := {started: false, okUntil: 0, failUntil: 0, pid: 0}
    return st
}

VH_Dir() {
    return A_ScriptDir "\Logs\vision_ipc"
}

VH_Enabled() {
    try {
        if RegExMatch(FileRead(UT_File(), "UTF-8"), "im)^\s*PythonVision\s*=\s*(\w+)", &m)
            return !(StrLower(m[1]) = "off" || m[1] = "0")
    }
    return true
}

; Called once at start-up.
VH_Start() {
    st := VH_S()
    if (!VH_Enabled() || st.started)
        return
    st.started := true
    dir := VH_Dir()
    try DirCreate(dir)
    try FileDelete(dir "\ready.txt")
    try FileDelete(dir "\req_*.txt")
    try FileDelete(dir "\resp_*.txt")
    script := A_ScriptDir "\Lib\Improved\vision_helper.py"
    args := ' "' script '" ' DllCall("GetCurrentProcessId") ' "' dir '"'
    for exe in ["pyw -3", "pythonw", EnvGet("LOCALAPPDATA") "\Programs\Python\Python312\pythonw.exe", EnvGet("LOCALAPPDATA") "\Programs\Python\Python313\pythonw.exe"] {
        try {
            Run(exe . args, A_ScriptDir, "Hide", &pid)
            st.pid := pid
            AddToLog("[Vision] Starting the Python vision helper...")
            return
        }
    }
    AddToLog("[Vision] Python not found - using the built-in (slower) screen reading")
}

VH_Ready() {
    return FileExist(VH_Dir() "\ready.txt") != ""
}

; Sends one request (lines "key=value") and returns a Map of the answer, or 0.
VH_Call(lines, timeoutMs := 3000) {
    st := VH_S()
    if (!VH_Enabled() || A_TickCount < st.failUntil || !VH_Ready())
        return 0
    static n := 0
    n += 1
    id := A_TickCount "_" n
    dir := VH_Dir()
    try {
        FileAppend(lines, dir "\req_" id ".tmp", "UTF-8-RAW")
        FileMove(dir "\req_" id ".tmp", dir "\req_" id ".txt", 1)
    } catch {
        return 0
    }
    resp := dir "\resp_" id ".txt"
    start := A_TickCount
    while !FileExist(resp) {
        if (A_TickCount - start > timeoutMs) {
            ; [Softer] one slow answer (busy PC, a big picture) used to switch Python off for a whole minute -
            ; right in the middle of the lobby walk. Now it takes two slow answers in a row, and only 20 s off.
            st.slow := (st.HasOwnProp("slow") ? st.slow : 0) + 1
            try FileDelete(dir "\req_" id ".txt")
            if (st.slow >= 2) {
                st.failUntil := A_TickCount + 20000, st.slow := 0
                AddToLog("[Vision] Python helper was slow twice - using the built-in reading for 20 s")
            }
            return 0
        }
        Sleep(5)
    }
    st.slow := 0
    out := Map()
    try {
        for line in StrSplit(FileRead(resp, "UTF-8"), "`n", "`r")
            if (p := InStr(line, "="))
                out[SubStr(line, 1, p - 1)] := SubStr(line, p + 1)
        FileDelete(resp)
    }
    return out
}

; Text in a rectangle given in the macro's usual (FindText) coordinates. "" if unavailable.
VH_OCR(x1, y1, w, h, scale := 3) {
    FT_GetOffset(&dx, &dy)
    r := VH_Call(Format("cmd=ocr`nx={}`ny={}`nw={}`nh={}`nscale={}", x1 + dx, y1 + dy, w, h, scale))
    return (r && r.Has("ok") && r["ok"] = "1") ? r["text"] : ""
}


; OCR a rectangle given in CLIENT coordinates (as measured on the recording / watch pictures)
VH_OCRClient(x1, y1, w, h, scale := 3) {
    ox := 0, oy := 0
    try WinGetClientPos(&ox, &oy, , , rblxID)
    r := VH_Call(Format("cmd=ocr`nx={}`ny={}`nw={}`nh={}`nscale={}", ox + x1, oy + y1, w, h, scale))
    return (r && r.Has("ok") && r["ok"] = "1") ? r["text"] : ""
}
