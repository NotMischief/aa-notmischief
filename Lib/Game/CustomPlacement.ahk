#Requires AutoHotkey v2.0

; ============================================================================
;  CustomPlacement.ahk  -  [Custom placement] your own unit placement spots per map.
; ----------------------------------------------------------------------------
; ============================================================================

global CP_Dir := A_ScriptDir "\Settings\CustomPlacements"
global CP_SettingFile := A_ScriptDir "\Settings\UseCustomPlacement.txt"
global CP_RecordMap := ""          ; map waiting to be recorded ("" = not recording)
global CP_Recording := false       ; true while you are clicking spots
global CP_StageMap := ""           ; map of the current stage (set by RestartStage)
global CP_MapList := "", CP_StatusLabel := "", CP_RecordedList := "", CP_RecordedNames := []
global CP_UseBox := ""             ; panel: "Use custom placement" (shown as an ON / OFF switch)
global CP_OverlayGuis := []        ; numbered circles on the Roblox window
global CP_MaxRecordMs := 5 * 60000 ; a recording stops by itself after 5 minutes
global CP_DotSize := 26            ; circle size in pixels

CP_FileFor(mapName) {
    return CP_Dir "\" RegExReplace(mapName, '[<>:"/\\|?*]', "_") ".txt"
}

; ---- ON / OFF setting -----------------------------------------------------------

CP_ReadUseSetting() {
    try {
        if FileExist(CP_SettingFile)
            return Trim(FileRead(CP_SettingFile, "UTF-8")) = "1"
    }
    return false
}

CP_UseCustomPlacement() {
    try return CP_UseBox.Value = 1
    return CP_ReadUseSetting()
}

; Saved straight away (like "Use custom movement for map")
CP_SaveUseSetting(ctrl, *) {
    val := ctrl.Value ? "1" : "0"
    try {
        if FileExist(CP_SettingFile)
            FileDelete(CP_SettingFile)
        FileAppend(val, CP_SettingFile, "UTF-8")
        AddToLog("Custom placement " (val = "1" ? "ON - maps with spots use them" : "OFF - your Placement Type is used"))
    } catch as err {
        AddToLog("Could not save the custom placement setting: " err.Message)
    }
}

; ---- panel (same area as the unit cards; header tab "Custom Placement") ---------

CP_BuildPanel() {
    global CP_MapList, CP_StatusLabel, CP_RecordedList, CP_UseBox
    t := uiTheme
    P := "Placement"
    aaMainUI.SetFont("s9 Bold c" t[1], "Segoe UI")
    AA_PanelAdd("GroupBox", "x808 y85 w550 h126 +Center c" t[3], "Record Placement Spots", P)
    AA_PanelAdd("GroupBox", "x808 y215 w550 h166 +Center c" t[3], "Use Spots", P)

    ; --- record
    AA_PanelAdd("Text", "x822 y108 w40 h18 c" t[1], "Map", P)
    btn := AA_PanelAdd("Button", "x1086 y104 w120 h22", "Record", P)
    btn.OnEvent("Click", (*) => CP_StartRecording(CP_MapList.Text))
    btn := AA_PanelAdd("Button", "x1212 y104 w136 h22", "Delete", P)
    btn.OnEvent("Click", (*) => CP_DeleteSpots(CP_MapList.Text))
    CP_StatusLabel := AA_PanelAdd("Text", "x822 y135 w525 h32 c" t[1], "Pick a map.", P)
    aaMainUI.SetFont("s8 norm c" t[1])
    AA_PanelAdd("Text", "x822 y168 w525 h40 c" t[1],
        "Record: the macro goes to this map (start-up + movement) and waits for the match to start. Then left-click "
        . "where units should go, in order. Backspace = undo last spot, G = save, Esc = cancel. "
        . "Story maps are selected for you (Act 1); for other maps, Confirm their mode first.", P)
    aaMainUI.SetFont("s9 norm c" t[6])
    CP_MapList := AA_PanelAdd("DropDownList", "x866 y105 w210 r15", CM_Maps, P)
    CP_MapList.OnEvent("Change", (*) => CP_RefreshPanel())

    ; --- use
    aaMainUI.SetFont("s9 Bold c" t[1])
    CP_UseBox := AA_PanelAdd("CheckBox", "x822 y236 w300 h18 c" t[1], "Use custom placement", P)
    CP_UseBox.OnEvent("Click", CP_SaveUseSetting)
    aaMainUI.SetFont("s8 norm c" t[1])
    AA_PanelAdd("Text", "x822 y258 w525 h28 c" t[1],
        "ON: units fill the map's spots in order. A map with no spots, or more units than spots, uses your "
        . "Placement Type for the rest. The selected map's spots are shown on the Roblox window while this panel is open.", P)
    aaMainUI.SetFont("s9 Bold c" t[1])
    AA_PanelAdd("Text", "x822 y290 w200 h18 c" t[1], "Maps with spots", P)
    aaMainUI.SetFont("s9 norm c" t[6])
    CP_RecordedList := AA_PanelAdd("ListBox", "x822 y310 w525 h64", [], P)
    CP_RecordedList.OnEvent("Change", CP_OnRecordedPick)
    CP_UseBox.Value := CP_ReadUseSetting() ? 1 : 0
}

; Called when the panel opens, when the map changes, and after recording / deleting.
CP_RefreshPanel() {
    global CP_RecordedNames
    CP_RecordedNames := []
    items := []
    for mapName in CM_Maps {
        if !FileExist(CP_FileFor(mapName))
            continue
        CP_RecordedNames.Push(mapName)
        items.Push(mapName "  -  " CP_StatusText(mapName, true))
    }
    CP_RecordedList.Delete()
    if items.Length
        CP_RecordedList.Add(items)
    CP_StatusLabel.Value := CP_StatusText(CP_MapList.Text)
    CP_ShowPanelOverlay()
}

CP_OnRecordedPick(ctrl, *) {
    i := ctrl.Value
    if (i < 1 || i > CP_RecordedNames.Length)
        return
    for j, mapName in CM_Maps {
        if (mapName = CP_RecordedNames[i]) {
            CP_MapList.Value := j
            break
        }
    }
    CP_StatusLabel.Value := CP_StatusText(CP_MapList.Text)
    CP_ShowPanelOverlay()
}

CP_StatusText(mapName, short := false) {
    if (mapName = "")
        return "Pick a map."
    file := CP_FileFor(mapName)
    if !FileExist(file)
        return "No spots for this map - your Placement Type is used."
    spots := CP_LoadSpots(mapName)
    if !IsObject(spots)
        return short ? "empty / unreadable" : "The spots file is empty or unreadable - your Placement Type is used."
    info := spots.Length " spot" (spots.Length = 1 ? "" : "s") ", " FormatTime(FileGetTime(file), "yyyy-MM-dd HH:mm")
    return short ? info : "Recorded: " info
}

CP_DeleteSpots(mapName) {
    file := CP_FileFor(mapName)
    if (mapName = "" || !FileExist(file))
        return
    if (MsgBox("Delete the placement spots for " mapName "?`n(A copy is kept as " mapName ".txt.bak)", "Custom Placement", 0x1024) != "Yes")
        return
    try {
        FileMove(file, file ".bak", 1)
        AddToLog("Placement spots for " mapName " deleted - your Placement Type is used for that map")
    } catch as err {
        AddToLog("Could not delete: " err.Message)
    }
    try CP_RefreshPanel()
}

; Record button: select the stage (Story maps) and start the macro in record mode.
CP_StartRecording(mapName) {
    global CP_RecordMap
    if (mapName = "") {
        MsgBox("Pick a map first.", "Custom Placement", 0x1030)
        return
    }
    if (MacroLoopState.Active) {
        MsgBox("The macro is running. Stop it (" F3Key ") first.", "Custom Placement", 0x1030)
        return
    }
    if (CM_RecordMap != "") {
        MsgBox("A movement recording is already waiting. Finish it first.", "Custom Placement", 0x1030)
        return
    }
    schedOn := false
    try {
        Sched_Load()
        schedOn := ScheduleEnabled()
    }
    if (schedOn) {
        MsgBox("The Scheduler is on - it would pick the mode itself. Turn it off first.", "Custom Placement", 0x1030)
        return
    }
    if !CM_PrepareMode(mapName, "Custom placement", "Custom Placement")
        return
    CP_RecordMap := mapName
    AddToLog("Custom placement: recording armed for " mapName " - starting the macro")
    AA_ShowPanel("")          ; back to the unit cards (also hides the overlay)
    StartMacro()
}

; ---- called from RestartStage (GameMango.ahk) ---------------------------------

CP_SetStageMap(mapName) {
    global CP_StageMap := mapName
}

; Right before unit placement. Records the spots when this is the map waiting to be
; recorded (then stops the macro); otherwise does nothing.
CP_HandleRecording(mapName) {
    if (CP_RecordMap = "")
        return
    if (mapName != CP_RecordMap) {
        AddToLog("Custom placement: waiting for " CP_RecordMap " to record (this stage is " mapName ")")
        return
    }
    CP_RecordSpots(mapName)
}

; ---- used by PlacingUnits / PlaceFoolUnits --------------------------------------
; patternPoints = the points of your Placement Type. When custom placement is ON and
; this stage's map has spots, they go first (in your order), then the pattern points.
CP_WithCustomSpots(patternPoints) {
    if !CP_UseCustomPlacement()
        return patternPoints
    pattern := PlacementPatternDropdown.Text
    mapName := CP_StageMap
    if (mapName = "" || mapName = "no map found") {
        AddToLog("Custom placement: map not detected - using " pattern)
        return patternPoints
    }
    spots := CP_LoadSpots(mapName)
    if !IsObject(spots) {
        AddToLog("Custom placement: no spots for " mapName " - using " pattern)
        return patternPoints
    }
    points := []
    for s in spots
        points.Push(s)
    for p in patternPoints
        points.Push(p)
    AddToLog("Custom placement: " spots.Length " spot" (spots.Length = 1 ? "" : "s") " for " mapName " (extra units use " pattern ")")
    return points
}

; ---- overlay: numbered circles on the Roblox window --------------------------------

; Shows the selected map's spots while the panel is open (never while the macro runs).
CP_ShowPanelOverlay() {
    CP_OverlayHide()
    if (AA_ActivePanel != "Placement" || MacroLoopState.Active)
        return
    spots := CP_LoadSpots(CP_MapList.Text)
    if IsObject(spots)
        for i, s in spots
            CP_OverlayAdd(i, s.x, s.y)
}

CP_OverlayAdd(num, x, y) {
    global CP_OverlayGuis
    try {
        if !WinExist(rblxID)
            return
        WinGetClientPos(&cx, &cy, , , rblxID)
        d := CP_DotSize
        g := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x20 +Owner" aaMainUI.Hwnd)   ; E0x20: clicks go through
        g.BackColor := uiTheme[3]
        g.MarginX := 0, g.MarginY := 0
        g.SetFont("s10 Bold cFFFFFF", "Segoe UI")
        g.Add("Text", Format("x0 y0 w{} h{} Center +0x200 +BackgroundTrans", d, d), num)
        g.Show(Format("x{} y{} w{} h{} NoActivate", cx + x - d // 2, cy + y - d // 2, d, d))
        WinSetRegion(Format("0-0 w{} h{} E", d, d), g)   ; round
        WinSetTransparent(215, g)                         ; also makes the click-through work
        CP_OverlayGuis.Push(g)
    }
}

CP_OverlayPop() {
    global CP_OverlayGuis
    if CP_OverlayGuis.Length
        try CP_OverlayGuis.Pop().Destroy()
}

CP_OverlayHide() {
    global CP_OverlayGuis
    for g in CP_OverlayGuis
        try g.Destroy()
    CP_OverlayGuis := []
}

; Called every second by the GUI timer: no circles on screen while the macro runs
; (except while you are recording spots).
CP_OverlayGuard() {
    if (CP_OverlayGuis.Length && MacroLoopState.Active && !CP_Recording)
        CP_OverlayHide()
}

; ---- recording ------------------------------------------------------------------

CP_RecordSpots(mapName) {
    global CP_RecordMap, CP_Recording
    CP_RecordMap := ""                    ; one-shot
    try WinActivate(rblxID)
    AddToLog("Placement recording - click where units should go (in order). Backspace = undo, G = save, Esc = cancel")

    spots := []
    CP_OverlayHide()
    CP_Recording := true
    ih := InputHook("V L0")              ; V: other keys still reach the game
    ih.MinSendLevel := 1                 ; ignore keys the script itself sends
    ih.KeyOpt("{g}{Escape}", "ES")       ; G / Esc end the recording and are not sent to the game
    ih.KeyOpt("{BackSpace}", "NS")       ; Backspace removes the last spot
    ih.OnKeyDown := (hook, vk, sc) => CP_UndoSpot(spots)
    ih.Start()

    wasDown := GetKeyState("LButton", "P")
    deadline := A_TickCount + CP_MaxRecordMs
    while ih.InProgress {
        if (A_TickCount >= deadline) {
            ih.Stop()
            AddToLog("Placement recording stopped after " CP_MaxRecordMs // 60000 " minutes")
            break
        }
        down := GetKeyState("LButton", "P")
        if (down && !wasDown) {
            try {
                if WinActive(rblxID) {
                    MouseGetPos(&mx, &my)            ; client coordinates, like FixClick
                    WinGetClientPos(, , &cw, &ch, rblxID)
                    if (mx >= 0 && my >= 0 && mx < cw && my < ch) {
                        spots.Push({x: mx, y: my})
                        CP_OverlayAdd(spots.Length, mx, my)
                        AddToLog("Spot " spots.Length ": " mx ", " my)
                    }
                }
            }
        }
        wasDown := down
        Sleep(15)
    }
    CP_Recording := false
    CP_OverlayHide()

    if (ih.EndReason = "EndKey" && ih.EndKey = "Escape") {
        AddToLog("Placement recording cancelled - nothing saved")
    } else if (spots.Length = 0) {
        AddToLog("No spots clicked - " mapName " keeps its previous spots")
    } else if CP_SaveSpots(mapName, spots) {
        AddToLog("Saved " spots.Length " placement spots for " mapName)
        if !CP_UseCustomPlacement()
            AddToLog("Turn on 'Use custom placement' (Custom Placement tab) to use them")
    }

    ; Recording session done: stop the macro instead of playing the match.
    AddToLog("Placement recording finished - macro stopped. Press " F2Key " to start again from the lobby")
    throw MacroStop("custom placement recording finished")
}

CP_UndoSpot(spots) {
    if !spots.Length
        return
    s := spots.Pop()
    CP_OverlayPop()
    AddToLog("Removed spot " spots.Length + 1 " (" s.x ", " s.y ")")
}

; ---- files ------------------------------------------------------------------

CP_SaveSpots(mapName, spots) {
    try {
        if !DirExist(CP_Dir)
            DirCreate(CP_Dir)
        text := "; Custom placement spots for " mapName " - one spot per line: x,y (Roblox client coordinates)`n"
        text .= "; recorded " FormatTime(, "yyyy-MM-dd HH:mm") "`n"
        for s in spots
            text .= s.x "," s.y "`n"
        file := CP_FileFor(mapName)
        if FileExist(file)
            FileMove(file, file ".bak", 1)
        FileAppend(text, file, "UTF-8")
        return true
    } catch as err {
        AddToLog("Could not save the placement spots: " err.Message)
        return false
    }
}

; Returns an array of {x, y}, or "" if the file is missing, empty or unreadable.
CP_LoadSpots(mapName) {
    if (mapName = "")
        return ""
    file := CP_FileFor(mapName)
    if !FileExist(file)
        return ""
    spots := []
    try {
        for line in StrSplit(FileRead(file, "UTF-8"), "`n", "`r") {
            line := Trim(line)
            if (line = "" || SubStr(line, 1, 1) = ";")
                continue
            if RegExMatch(line, "^(\d+)\s*,\s*(\d+)$", &m)
                spots.Push({x: Integer(m[1]), y: Integer(m[2])})
        }
    } catch {
        return ""
    }
    return spots.Length ? spots : ""
}
