; =====================================================================
; [Record mode] (Improved v4)  -  F8 starts / stops it.
; For learning a NEW event: you play it yourself, the macro only watches.
;   - every 2 seconds, if the screen changed: saves a picture of the Roblox window
;   - reads all the text it can see on screen and writes it to record.txt
;   - writes down where you click (and which number keys you press)
; Everything goes to  Logs\Record\<date-time>\ . The macro never clicks in this mode.
; Send that folder to Claude so the event can be added to the macro.
; =====================================================================

; all state lives here (works no matter when this file is loaded)
RM_S() {
    static st := {on: false, dir: "", count: 0, sig: ""}
    return st
}

RM_Toggle(*) {
    st := RM_S()
    if (st.on) {
        st.on := false
        SetTimer(RM_Tick, 0)
        try Hotkey("~LButton", "Off")
        Loop 6
            try Hotkey("~" A_Index, "Off")
        AddToLog("[Record] Stopped - " st.count " pictures saved in Logs\Record\" RegExReplace(st.dir, ".*\\"))
        return
    }
    if (MacroLoopState.Active) {
        AddToLog("[Record] Stop the macro (" F3Key ") first - in record mode you play, the macro only watches")
        return
    }
    st.dir := A_ScriptDir "\Logs\Record\" FormatTime(, "yyyy-MM-dd_HH-mm-ss")
    DirCreate(st.dir)
    st.count := 0, st.sig := ""
    st.on := true
    RM_Write("Recording started. Window: " RM_WindowText())
    Hotkey("~LButton", RM_Click, "On")
    Loop 6
        Hotkey("~" A_Index, RM_Key, "On")
    SetTimer(RM_Tick, 2000)
    AddToLog("[Record] Recording - play normally. Press F8 again to stop.")
}

RM_WindowText() {
    try {
        WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
        return cw "x" ch
    }
    return "Roblox not found"
}

RM_Write(line) {
    st := RM_S()
    try FileAppend(FormatTime(, "HH:mm:ss") " | " line "`n", st.dir "\record.txt", "UTF-8")
}

RM_Click(*) {
    st := RM_S()
    if (!st.on || !WinActive(rblxID))
        return
    MouseGetPos(&mx, &my)   ; window coordinates, the same ones the macro clicks with
    RM_Write("CLICK " mx ", " my "  (after picture " Format("{:04}", st.count) ")")
}

RM_Key(hk) {
    st := RM_S()
    if (!st.on || !WinActive(rblxID))
        return
    RM_Write("KEY " SubStr(hk, 2))
}

RM_Tick() {
    st := RM_S()
    if (!st.on || !WinExist(rblxID))
        return
    try {
        WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
        if (cw < 100 || ch < 100)
            return
        ; skip if nothing on screen changed since the last picture
        sig := ""
        old := A_CoordModePixel
        CoordMode("Pixel", "Screen")
        Loop 4 {
            r := A_Index
            Loop 5
                sig .= PixelGetColor(cx + cw * A_Index / 6, cy + ch * r / 5) ","
        }
        CoordMode("Pixel", old)
        if (sig = st.sig)
            return
        st.sig := sig
        if (st.count >= 1500) {
            AddToLog("[Record] 1500 pictures reached - stopping")
            return RM_Toggle()
        }
        st.count += 1
        name := Format("{:04}", st.count) ".jpg"
        pToken := Gdip_Startup()
        pBmp := Gdip_BitmapFromScreen(cx "|" cy "|" cw "|" ch)
        Gdip_SaveBitmapToFile(pBmp, st.dir "\" name)   ; default quality (other values crash this Gdip version)
        Gdip_DisposeImage(pBmp)
        Gdip_Shutdown(pToken)
        text := ""
        try {
            res := OCR.FromRect(cx, cy, cw, ch, "FirstFromAvailableLanguages", { grayscale: true, scale: 1.5 })
            text := res ? RegExReplace(res.Text, "\s+", " ") : ""
        }
        RM_Write("PICTURE " name " | text: " SubStr(text, 1, 400))
    } catch as e {
        RM_Write("error: " e.Message)
    }
}
