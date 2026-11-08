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
    tries := ["pyw -3", "pythonw", EnvGet("LOCALAPPDATA") "\Programs\Python\Python312\pythonw.exe", EnvGet("LOCALAPPDATA") "\Programs\Python\Python313\pythonw.exe"]
    ; [Fix 11-05] the setup now writes down the Python it installed the packages into (Settings\Python.txt).
    ; Use that one first: "pyw -3" takes the NEWEST Python, which may have no packages (your friend's 3.15).
    try {
        own := Trim(FileRead(A_ScriptDir "\Settings\Python.txt"), " `t`r`n")
        if (own != "" && FileExist(own))
            tries.InsertAt(1, '"' own '"')
    }
    for exe in tries {
        try {
            Run(exe . args, A_ScriptDir, "Hide", &pid)
            st.pid := pid
            AddToLog("[Vision] Starting the Python vision helper...")
            SetTimer(VH_StartCheck, -30000)
            return
        }
    }
    AddToLog("[Vision] Python not found - using the built-in (slower) screen reading")
}

; [11-07] one line in the log 30 s after start-up if the helper never got ready (a friend's PC ran on the
; slow built-in reading for days without anyone noticing). Only writes to the log.
VH_StartCheck() {
    static checks := 0
    st := VH_S()
    if (VH_Ready()) {
        AddToLog("[Vision] Python helper is running")
        return
    }
    checks += 1
    ; still loading (the first start on a slow PC can take a minute) - look again in 30 s, up to 2 minutes
    if (checks < 4 && st.pid && ProcessExist(st.pid)) {
        SetTimer(VH_StartCheck, -30000)
        return
    }
    AddToLog("[Vision] The Python helper didn't start - using the slower built-in reading. Fix: close the macro, run 'Setup (first time).bat', start again (details: Logs\vision_ipc\helper.log)")
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
    VH_CheckLate(st, dir)
    ; [Slow PC] Settings\PythonWait.txt = how many times longer to wait for Python's answers (1 to 10, default 1)
    timeoutMs := Round(timeoutMs * VH_WaitFactor())
    cmdName := RegExMatch(lines, "cmd=(\w+)", &cm) ? cm[1] : "?"
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
            taken := !FileExist(dir "\req_" id ".txt")   ; Python took the job but didn't finish in time
            try FileDelete(dir "\req_" id ".txt")
            AddToLog("[Vision] Python gave no answer to '" cmdName "' within " timeoutMs " ms - "
                . (taken ? "it was still working on it" : "it was still busy with an earlier job"))
            if (taken)
                st.late := {id: id, cmd: cmdName, at: start}
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

; [Slow PC] how many times longer to wait for Python (Settings\PythonWait.txt, 1 to 10; default 1)
VH_WaitFactor() {
    static f := 0
    if (f = 0) {
        f := 1
        try {
            v := Trim(FileRead(A_ScriptDir "\Settings\PythonWait.txt"), " `t`r`n" Chr(0xFEFF))
            if (IsNumber(v) && v >= 1 && v <= 10)
                f := v + 0
        }
        if (f != 1)
            AddToLog("[Vision] Waiting " f "x longer for Python's answers (Settings\PythonWait.txt)")
    }
    return f
}

; [Slow PC] a job that timed out may still be answered later: write down how long it really took
; (so the logs show how slow Python is on this PC) and clean the answer file up.
VH_CheckLate(st, dir) {
    if (!st.HasOwnProp("late") || !IsObject(st.late))
        return
    f := dir "\resp_" st.late.id ".txt"
    if FileExist(f) {
        ms := ""
        try {
            if RegExMatch(FileRead(f, "UTF-8"), "m)^ms=(\d+)", &m)
                ms := m[1]
            FileDelete(f)
        }
        AddToLog("[Vision] (the late '" st.late.cmd "' answer came after all" (ms != "" ? " - Python took " ms " ms" : "") ")")
        st.late := 0
    } else if (A_TickCount - st.late.at > 60000) {
        st.late := 0
    }
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
