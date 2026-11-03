; [Watch mode] F9 on/off. While on:
;  - saves a picture of the Roblox window every 4 s (Logs\Watch\latest.jpg + a rolling history)
;    and on important log lines, plus Logs\Watch\status.txt, so Claude can follow the game.
;  - when the macro's files have been changed, it reloads itself in the lobby (between matches)
;    and starts again with the same mode, so fixes go in without cutting off a round.

WM_File() => A_ScriptDir "\Settings\WatchMode.txt"
WM_Dir() => A_ScriptDir "\Logs\Watch"
WM_On() {
    try return Trim(FileRead(WM_File())) = "On"
    return false
}

WM_S() {
    static s := {baseline: 0, lastEvt: 0, n: 0}
    return s
}

WM_Toggle() {
    on := !WM_On()
    try FileDelete(WM_File())
    FileAppend(on ? "On" : "Off", WM_File())
    AddToLog("[Watch] Watch mode " (on ? "ON - Claude can follow the game and fixes load in the lobby" : "OFF"))
    if on
        WM_Snap("toggle")
}

; newest change time of the macro's code files
WM_CodeStamp() {
    newest := 0
    for pat in ["\Lib\*.ahk", "\Lib\*.py"] {   ; .py too - the Python helper restarts with the macro
        loop files A_ScriptDir pat, "R" {
            t := Integer(A_LoopFileTimeModified)
            if (t > newest)
                newest := t
        }
    }
    t := Integer(FileGetTime(A_ScriptDir "\Main.ahk", "M"))
    return t > newest ? t : newest
}

WM_Init() {
    s := WM_S()
    s.baseline := WM_CodeStamp()
    DirCreate(WM_Dir())
    SetTimer(WM_Tick, 4000)
    rf := A_ScriptDir "\Settings\WatchResume.txt"
    if FileExist(rf) {
        fresh := DateDiff(A_Now, FileGetTime(rf, "M"), "Seconds") < 300
        txt := FileRead(rf, "UTF-8")
        try FileDelete(rf)
        if fresh
            SetTimer(() => WM_Resume(txt), -5000)
    }
}

WM_Tick() {
    if !WM_On()
        return
    WM_Snap("")
    WM_Status()
}

WM_Status() {
    global Wins, loss, process1
    active := false
    try active := MacroLoopState.Active
    txt := "time=" FormatTime(, "yyyy-MM-dd HH:mm:ss") "`nrunning=" (active ? 1 : 0) "`nmode=" ModeDropdown.Text
        . "`nwins=" Wins "`nlosses=" loss "`nlast=" process1.Value "`n"
    try {
        f := FileOpen(WM_Dir() "\status.txt", "w", "UTF-8")
        f.Write(txt), f.Close()
    }
}

; called from AddToLog: picture on the lines that matter
WM_OnLog(msg) {
    if !WM_On()
        return
    s := WM_S()
    if (A_TickCount - s.lastEvt < 1500)
        return
    if RegExMatch(msg, "i)victory|defeat|placed|placement|upgrade|hotbar|wrong units|error|failed|couldn't|could not|stuck|leav|smart|python|money")
        s.lastEvt := A_TickCount, SetTimer(() => WM_Snap("evt"), -10)
}

WM_Snap(tag) {
    global rblxID
    if !WinExist(rblxID) || WinGetMinMax(rblxID) = -1
        return
    try {
        WinGetClientPos(&x, &y, &w, &h, rblxID)
        if (w < 50 || h < 50)
            return
        s := WM_S(), s.n += 1
        tok := Gdip_Startup()   ; start/stop each time like the other tools (they shut it down after use)
        pBmp := Gdip_BitmapFromScreen(x "|" y "|" w "|" h)
        Gdip_SaveBitmapToFile(pBmp, WM_Dir() "\latest.jpg")   ; default quality - other values crash this Gdip version
        name := FormatTime(, "MMdd_HHmmss") (tag != "" ? "_" tag : "") ".jpg"
        if (tag != "" || Mod(s.n, 2) = 0)   ; history: every 8 s + every event
            Gdip_SaveBitmapToFile(pBmp, WM_Dir() "\" name)
        Gdip_DisposeImage(pBmp)
        Gdip_Shutdown(tok)
        if (Mod(s.n, 25) = 0)
            WM_Trim()
    } catch as e {
        try FileAppend(FormatTime(, "HH:mm:ss") " snap failed: " e.Message " (" e.What " line " e.Line ")`n", WM_Dir() "\debug.txt")
    }
}

; keep the newest 400 history pictures
WM_Trim() {
    files := []
    loop files WM_Dir() "\0*.jpg"
        files.Push(A_LoopFileName)
    loop files WM_Dir() "\1*.jpg"
        files.Push(A_LoopFileName)
    if (files.Length <= 400)
        return
    list := ""
    for f in files
        list .= f "`n"
    list := Sort(RTrim(list, "`n"))
    for i, f in StrSplit(list, "`n")
        if (i <= files.Length - 400)
            try FileDelete(WM_Dir() "\" f)
}

; the mode / map dropdowns that get remembered over a reload
WM_Boxes() {
    m := Map()
    try m["ModeDropdown"] := ModeDropdown
    try m["StoryDropdown"] := StoryDropdown
    try m["StoryActDropdown"] := StoryActDropdown
    try m["LegendDropDown"] := LegendDropDown
    try m["LegendActDropdown"] := LegendActDropdown
    try m["RaidDropdown"] := RaidDropdown
    try m["RaidActDropdown"] := RaidActDropdown
    try m["InfinityCastleDropdown"] := InfinityCastleDropdown
    try m["PortalDropdown"] := PortalDropdown
    try m["PortalJoinDropdown"] := PortalJoinDropdown
    try m["PlacementSelection"] := PlacementSelection   ; [Fix] the unit profile (Dungeon / Summer Hunt ...) too
    return m
}

; called at the start of StartSelectedMode (we're in the lobby)
WM_LobbyReload() => WM_ReloadAt("lobby")

; step = where to carry on after the reload: "lobby" (start normally) or "dungeon" (room choice screen)
WM_ReloadAt(step) {
    if !WM_On()
        return
    if (WM_CodeStamp() <= WM_S().baseline)
        return
    out := "step=" step "`n"
    for name, box in WM_Boxes()
        try out .= name "=" box.Text "`n"
    rf := A_ScriptDir "\Settings\WatchResume.txt"
    try FileDelete(rf)
    FileAppend(out, rf, "UTF-8")
    AddToLog("[Watch] New fixes found - reloading (" step "), the macro carries on by itself")
    Sleep(1000)
    Reload()
    Sleep(5000)   ; Reload is asynchronous - don't carry on into the old code
}

WM_Resume(txt) {
    AddToLog("[Watch] Reloaded with the new fixes - starting again")
    vals := Map()
    for line in StrSplit(txt, "`n", "`r")
        if (p := InStr(line, "="))
            vals[SubStr(line, 1, p - 1)] := SubStr(line, p + 1)
    if !vals.Has("ModeDropdown") || vals["ModeDropdown"] = "" {   ; nothing to restore
        AddToLog("[Watch] No mode saved - press F2 to start")
        return
    }
    try ModeDropdown.Choose(vals["ModeDropdown"])
    try OnModeChange()
    boxes := WM_Boxes()
    for name, v in vals {
        if (name = "ModeDropdown" || v = "" || !boxes.Has(name))
            continue
        try boxes[name].Choose(v)
    }
    try OnConfirmClick()
    if !(vals.Has("PlacementSelection") && vals["PlacementSelection"] != "") {
        ; older save without the profile: use the profile named after the mode, if there is one
        for md in ["Dungeon", "Summer Hunt", "Fool's Hunt", "Raid", "Contract"]
            if (vals["ModeDropdown"] = md)
                vals["PlacementSelection"] := md
    }
    if (vals.Has("PlacementSelection") && vals["PlacementSelection"] != "") {   ; OnConfirmClick can change it - set it last
        try PlacementSelection.Choose(vals["PlacementSelection"])
        try ToggleMode()
        AddToLog("[Watch] Unit profile: " PlacementSelection.Text)
    }
    Sleep(500)
    if (vals.Has("step") && vals["step"] = "dungeon") {
        AddToLog("[Watch] Carrying on with the next dungeon room")
        try CP_OverlayHide()
        RunMacroLoop(LookForDungeonRooms)
    } else
        StartMacro()
}
