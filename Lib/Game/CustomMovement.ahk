#Requires AutoHotkey v2.0

; ============================================================================
;  CustomMovement.ahk  -  [Custom movement] record your own walk for a map and
; ============================================================================

global CM_Dir := A_ScriptDir "\Settings\CustomMovement"
global CM_SettingFile := A_ScriptDir "\Settings\UseCustomMovement.txt"
global CM_RecordMap := ""              ; map waiting to be recorded ("" = not recording)
global CM_Rec := ""                    ; state of the recording in progress
global CM_MapList := "", CM_StatusLabel := ""   ; panel: map dropdown, status line
global CM_PanelUseBox := "", CM_RecordedList := "", CM_RecordedNames := []   ; panel: tickbox, recorded-maps list
global CM_MaxRecordMs := 5 * 60000     ; a recording stops by itself after 5 minutes
global CM_StopKey := "g"
global CM_Keys := Map("w", 1, "a", 1, "s", 1, "d", 1, "space", 1, "left", 1, "right", 1, "up", 1, "down", 1, "i", 1, "o", 1, "wheelup", 1, "wheeldown", 1)   ; + zoom (I / O keys, mouse wheel)

; Map names exactly as map detection reports them (DetectMapImageSearch / DetectHuntMap)
global CM_Maps := ["Air Craft", "Alien Spaceship", "Ant Kingdom", "Assassin Park", "Cursed Festival",
    "Dungeon Throne", "Fabled Kingdom", "Fiend City", "Future City", "Haunted Academy", "Haunted Mansion",
    "Hellish City", "Magic Hills", "Magic Town", "Mountain Temple", "Navy Bay", "Nightmare Train",
    "Planet Greenie", "Puppet Island", "Rain Village", "Ruined City", "Sacred Planet", "Sand Village",
    "Shibuya District", "Snowy Kingdom", "Snowy Town", "Space Center", "Spirit Town", "Spirit World",
    "Storm Hideout", "Strange Town", "Virtual Dungeon", "Walled City"]

; ---- settings ---------------------------------------------------------------

CM_FileFor(mapName) {
    return CM_Dir "\" RegExReplace(mapName, '[<>:"/\\|?*]', "_") ".txt"
}

CM_ReadUseSetting() {
    try {
        if FileExist(CM_SettingFile)
            return Trim(FileRead(CM_SettingFile, "UTF-8")) = "1"
    }
    return false
}

CM_UseCustomMovement() {
    try return CM_PanelUseBox.Value = 1
    return CM_ReadUseSetting()
}

; "Use custom movement for map" (Custom Map Movement panel) - saved straight away
CM_SaveUseSetting(ctrl, *) {
    val := ctrl.Value ? "1" : "0"
    try {
        if FileExist(CM_SettingFile)
            FileDelete(CM_SettingFile)
        FileAppend(val, CM_SettingFile, "UTF-8")
        AddToLog("Custom movement " (val = "1" ? "on - recorded maps use your movement" : "off - built-in movement"))
    } catch as err {
        AddToLog("Could not save the custom movement setting: " err.Message)
    }
}

; ---- panel (in the main window, same area as the unit cards) ------------------
; Built hidden at startup by GUI.ahk; the header button calls AA_TogglePanel("Movement").

CM_BuildPanel() {
    global CM_MapList, CM_StatusLabel, CM_PanelUseBox, CM_RecordedList
    t := uiTheme
    P := "Movement"
    aaMainUI.SetFont("s9 Bold c" t[1], "Segoe UI")
    AA_PanelAdd("GroupBox", "x808 y85 w550 h126 +Center c" t[3], "Record Movement", P)
    AA_PanelAdd("GroupBox", "x808 y215 w550 h166 +Center c" t[3], "Replay", P)

    ; --- record
    AA_PanelAdd("Text", "x822 y108 w40 h18 c" t[1], "Map", P)
    btn := AA_PanelAdd("Button", "x1086 y104 w90 h22", "Record", P)
    btn.OnEvent("Click", (*) => CM_StartRecording(CM_MapList.Text))
    btn := AA_PanelAdd("Button", "x1182 y104 w80 h22", "Delete", P)
    btn.OnEvent("Click", (*) => CM_DeleteRecording(CM_MapList.Text))
    CM_StatusLabel := AA_PanelAdd("Text", "x822 y135 w525 h32 c" t[1], "Pick a map.", P)
    aaMainUI.SetFont("s8 norm c" t[1])
    AA_PanelAdd("Text", "x822 y168 w525 h40 c" t[1],
        "Record: the macro goes to this map and does the normal start-up (zoom, teleport to spawn) but skips the movement - "
        . "walk to where you want to stand and press G. Story maps are selected for you (Act 1); for other maps, Confirm their mode first. "
        . "Keys: W A S D, Space, arrows.", P)
    aaMainUI.SetFont("s9 norm c" t[6])
    CM_MapList := AA_PanelAdd("DropDownList", "x866 y105 w210 r15", CM_Maps, P)
    CM_MapList.OnEvent("Change", (*) => CM_StatusLabel.Value := CM_StatusText(CM_MapList.Text))

    ; --- replay
    aaMainUI.SetFont("s9 Bold c" t[1])
    CM_PanelUseBox := AA_PanelAdd("CheckBox", "x822 y236 w300 h18 c" t[1], "Use custom movement for map", P)
    CM_PanelUseBox.OnEvent("Click", CM_SaveUseSetting)
    AA_PanelAdd("Text", "x822 y290 w200 h18 c" t[1], "Recorded maps", P)
    btn := AA_PanelAdd("Button", "x1150 y286 w95 h22", "Import", P)
    btn.OnEvent("Click", CM_ImportMovement)
    btn := AA_PanelAdd("Button", "x1253 y286 w95 h22", "Export", P)
    btn.OnEvent("Click", CM_ExportMovement)
    aaMainUI.SetFont("s8 norm c" t[1])
    AA_PanelAdd("Text", "x822 y258 w525 h28 c" t[1],
        "On: a map with a recording replays it. A map with no recording, or an empty / unreadable file, "
        . "uses the built-in (default) movement - the console says which one ran.", P)
    aaMainUI.SetFont("s9 norm c" t[6])
    CM_RecordedList := AA_PanelAdd("ListBox", "x822 y310 w525 h64", [], P)
    CM_RecordedList.OnEvent("Change", CM_OnRecordedPick)
    CM_PanelUseBox.Value := CM_ReadUseSetting() ? 1 : 0
}

; Called whenever the panel is opened, and after recording / deleting.
CM_RefreshPanel() {
    global CM_RecordedNames
    CM_RecordedNames := []
    items := []
    for mapName in CM_Maps {
        if !FileExist(CM_FileFor(mapName))
            continue
        CM_RecordedNames.Push(mapName)
        items.Push(mapName "  -  " CM_StatusText(mapName, true))
    }
    CM_RecordedList.Delete()
    if items.Length
        CM_RecordedList.Add(items)
    CM_StatusLabel.Value := CM_StatusText(CM_MapList.Text)
}

; Clicking a recorded map selects it in the Map dropdown.
CM_OnRecordedPick(ctrl, *) {
    i := ctrl.Value
    if (i < 1 || i > CM_RecordedNames.Length)
        return
    for j, mapName in CM_Maps {
        if (mapName = CM_RecordedNames[i]) {
            CM_MapList.Value := j
            break
        }
    }
    CM_StatusLabel.Value := CM_StatusText(CM_MapList.Text)
}

CM_StatusText(mapName, short := false) {
    if (mapName = "")
        return "Pick a map."
    file := CM_FileFor(mapName)
    if !FileExist(file)
        return "No recording for this map - the built-in movement is used."
    events := CM_LoadFile(mapName, &total)
    if !IsObject(events)
        return short ? "empty / unreadable - built-in movement is used" : "The recording is empty or unreadable - the built-in movement is used."
    info := events.Length " inputs, " Round(total / 1000, 1) " s, " FormatTime(FileGetTime(file), "yyyy-MM-dd HH:mm")
    return short ? info : "Recorded: " info
}

CM_DeleteRecording(mapName) {
    file := CM_FileFor(mapName)
    if (mapName = "" || !FileExist(file))
        return
    if (MsgBox("Delete the custom movement for " mapName "?`n(A copy is kept as " mapName ".txt.bak)", "Custom Map Movement", 0x1024) != "Yes")
        return
    try {
        FileMove(file, file ".bak", 1)
        AddToLog("Custom movement for " mapName " deleted - built-in movement is used again")
    } catch as err {
        AddToLog("Could not delete: " err.Message)
    }
    try CM_RefreshPanel()
}

; Record button: select the stage (Story maps) and start the macro in record mode.
CM_StartRecording(mapName) {
    global CM_RecordMap
    if (mapName = "") {
        MsgBox("Pick a map first.", "Custom Map Movement", 0x1030)
        return
    }
    if (MacroLoopState.Active) {
        MsgBox("The macro is running. Stop it (" F3Key ") first.", "Custom Map Movement", 0x1030)
        return
    }
    schedOn := false
    try {
        Sched_Load()
        schedOn := ScheduleEnabled()
    }
    if (schedOn) {
        MsgBox("The Scheduler is on - it would pick the mode itself. Turn it off first.", "Custom Map Movement", 0x1030)
        return
    }
    if !CM_PrepareMode(mapName)
        return
    CM_RecordMap := mapName
    AddToLog("Custom movement: recording armed for " mapName " - starting the macro")
    AA_ShowPanel("")          ; back to the unit cards
    StartMacro()
}

; Story maps: select Story > map > Act 1 and confirm (unless that map is already confirmed).
; Other maps: use the mode the user confirmed in the main window.
CM_PrepareMode(mapName, what := "Custom movement", title := "Custom Map Movement") {   ; [Custom placement] also used by CustomPlacement.ahk
    if CM_ListHas(StoryDropdown, mapName) {
        if (confirmClicked && ModeDropdown.Text = "Story" && StoryDropdown.Text = mapName)
            return true
        if !(CM_ChooseExact(ModeDropdown, "Story")) {
            MsgBox("Could not select Story mode.", title, 0x1030)
            return false
        }
        OnModeChange()
        CM_ChooseExact(StoryDropdown, mapName)
        OnStoryChange()
        CM_ChooseExact(StoryActDropdown, "Act 1")
        OnConfirmClick()
        AddToLog(what ": selected Story - " mapName " - Act 1 for the recording")
        return true
    }
    if (confirmClicked && ModeDropdown.Text != "") {
        AddToLog(what ": recording starts when " ModeDropdown.Text " reaches " mapName)
        return true
    }
    MsgBox(mapName " is not a Story map.`nSelect and Confirm the mode that plays it (Raid, Legend, Fool's Hunt, ...) in the main window, then click Record again.", title, 0x1040)
    return false
}

CM_ListHas(ddl, text) {
    for item in ControlGetItems(ddl)
        if (item = text)
            return true
    return false
}

CM_ChooseExact(ddl, text) {
    for i, item in ControlGetItems(ddl) {
        if (item = text) {
            ddl.Value := i
            return true
        }
    }
    return false
}

; ---- called from RestartStage (GameMango.ahk) ---------------------------------
; Returns true when this file handled the movement (recorded or replayed),
; false = RestartStage runs the built-in HandleMapMovement as before.
CM_HandleStageMovement(mapName) {
    if (CM_RecordMap != "") {
        if (mapName = CM_RecordMap) {
            CM_RecordMovement(mapName)
            return true
        }
        AddToLog("Custom movement: waiting for " CM_RecordMap " to record (this stage is " mapName ")")
        return false
    }
    if !CM_UseCustomMovement()
        return false
    ; Failsafe: no recording for this map -> built-in (hard-coded) movement
    if !FileExist(CM_FileFor(mapName)) {
        AddToLog("Custom movement: no recording for " mapName " - using the default movement")
        return false
    }
    return CM_PlayMovement(mapName)   ; false (and a console line) if the file is empty / unreadable
}

; ---- recording ------------------------------------------------------------------

CM_RecordMovement(mapName) {
    global CM_RecordMap, CM_Rec
    AddToLog("Recording - walk to the desired location, press G to stop recording")
    try WinActivate(rblxID)

    CM_Rec := {events: [], held: Map(), start: A_TickCount, done: false}
    ih := InputHook("V L0")              ; V: your keys still reach the game; L0: no text buffer
    ih.MinSendLevel := 1                 ; ignore keys the script itself sends
    ih.KeyOpt("{All}", "N")
    ih.KeyOpt("{" CM_StopKey "}", "+S")  ; G stops the recording and is not sent to the game
    ih.OnKeyDown := CM_OnKeyDown
    ih.OnKeyUp := CM_OnKeyUp
    ih.Start()

    deadline := A_TickCount + CM_MaxRecordMs
    timedOut := false
    while !CM_Rec.done {
        if (A_TickCount >= deadline) {
            timedOut := true
            break
        }
        Sleep(50)
    }
    ih.Stop()

    totalMs := A_TickCount - CM_Rec.start
    for key in CM_Rec.held                ; keys still held when G was pressed
        CM_Rec.events.Push({t: totalMs, key: key, down: false})
    CM_RecordMap := ""                    ; one-shot

    if (timedOut)
        AddToLog("Recording stopped after " CM_MaxRecordMs // 60000 " minutes")
    if (CM_Rec.events.Length = 0) {
        AddToLog("Nothing recorded - " mapName " keeps its previous movement")
    } else if CM_SaveFile(mapName, CM_Rec.events, totalMs) {
        AddToLog("Saved custom movement for " mapName ": " CM_Rec.events.Length " inputs, " Round(totalMs / 1000, 1) " s")
        if !CM_UseCustomMovement()
            AddToLog("Tick 'Use custom movement for map' to use it")
    }
    try CM_RefreshPanel()

    ; Recording session done: stop the macro instead of playing the match.
    ; (RunMacroLoop catches MacroStop and ends cleanly - Lib\Framework\MacroLoop.ahk)
    AddToLog("Custom movement recording finished - macro stopped. Press " F2Key " to start again from the lobby")
    throw MacroStop("custom movement recording finished")
}

CM_KeyName(vk, sc) {
    return StrLower(GetKeyName(Format("vk{:x}sc{:x}", vk, sc)))
}

CM_OnKeyDown(ih, vk, sc) {
    global CM_Rec
    name := CM_KeyName(vk, sc)
    if (name = CM_StopKey) {
        CM_Rec.done := true
        return
    }
    if (!CM_Keys.Has(name) || CM_Rec.held.Has(name))   ; other keys / key auto-repeat
        return
    CM_Rec.held[name] := true
    CM_Rec.events.Push({t: A_TickCount - CM_Rec.start, key: name, down: true})
}

CM_OnKeyUp(ih, vk, sc) {
    global CM_Rec
    name := CM_KeyName(vk, sc)
    if !CM_Rec.held.Has(name)
        return
    CM_Rec.held.Delete(name)
    CM_Rec.events.Push({t: A_TickCount - CM_Rec.start, key: name, down: false})
}

; ---- files ------------------------------------------------------------------

CM_SaveFile(mapName, events, totalMs, note := "recorded") {
    file := CM_FileFor(mapName)
    try {
        if !DirExist(CM_Dir)
            DirCreate(CM_Dir)
        text := "; Custom movement for " mapName " - " note " " FormatTime(, "yyyy-MM-dd HH:mm") "`n"
            . "; time_ms,key,down|up   (keys: w a s d space left right up down)`n"
        for ev in events
            text .= ev.t "," ev.key "," (ev.down ? "down" : "up") "`n"
        text .= "end," totalMs "`n"
        if FileExist(file)
            FileMove(file, file ".bak", 1)      ; previous recording kept as .bak
        FileAppend(text, file, "UTF-8")
        return true
    } catch as err {
        AddToLog("Could not save custom movement: " err.Message)
        return false
    }
}

; Returns an array of {t, key, down} or "" if the file is missing or invalid.
CM_LoadFile(mapName, &totalMs := 0) {
    totalMs := 0
    file := CM_FileFor(mapName)
    if !FileExist(file)
        return ""
    try {
        content := FileRead(file, "UTF-8")
    } catch {
        return ""
    }
    return CM_ParseText(content, mapName, &totalMs)
}

; Checks recording text line by line (same rules for files and imports).
CM_ParseText(content, mapName, &totalMs := 0) {
    totalMs := 0
    events := [], last := 0
    for line in StrSplit(content, "`n", "`r") {
        line := Trim(line)
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue
        p := StrSplit(line, ",")
        if (p.Length = 2 && p[1] = "end" && IsInteger(p[2])) {
            totalMs := Integer(p[2])
            continue
        }
        if (p.Length != 3 || !IsInteger(p[1]) || !CM_Keys.Has(StrLower(p[2])) || !(p[3] = "down" || p[3] = "up")
            || Integer(p[1]) < last || Integer(p[1]) > CM_MaxRecordMs) {
            AddToLog("Custom movement for " mapName ": unreadable line '" line "'")
            return ""
        }
        last := Integer(p[1])
        events.Push({t: last, key: StrLower(p[2]), down: p[3] = "down"})
    }
    if (totalMs < last)
        totalMs := last
    return events.Length ? events : ""
}

; ---- export / import ------------------------------------------------------------

CM_MapSpelling(name) {
    for m in CM_Maps
        if (m = name)
            return m
    return ""
}

CM_ExportMovement(*) {
    maps := []
    for m in CM_Maps
        if IsObject(CM_LoadFile(m))
            maps.Push(m)
    if !maps.Length {
        CM_StatusLabel.Value := "Nothing to export - no usable recordings yet."
        return
    }
    aaMainUI.Opt("-AlwaysOnTop")
    file := FileSelect("S16", A_ScriptDir "\Settings\CustomMovement_Export.txt", "Export custom movement", "Text Documents (*.txt)")
    aaMainUI.Opt("+AlwaysOnTop")
    if (file = "")
        return
    if !RegExMatch(file, "i)\.txt$")
        file .= ".txt"
    text := "; Anime Adventures custom movement export - " FormatTime(, "yyyy-MM-dd HH:mm") "`n"
        . "; " maps.Length " map(s). Import with Custom Movement > Import. Format per line: time_ms,key,down|up`n"
    for m in maps {
        text .= "`n[" m "]`n"
        for line in StrSplit(FileRead(CM_FileFor(m), "UTF-8"), "`n", "`r") {
            line := Trim(line)
            if (line != "" && SubStr(line, 1, 1) != ";")
                text .= line "`n"
        }
    }
    try {
        if FileExist(file)
            FileDelete(file)
        FileAppend(text, file, "UTF-8")
        CM_StatusLabel.Value := "Exported " maps.Length " recording(s) to " file
        AddToLog("Exported " maps.Length " custom movement recording(s)")
    } catch as err {
        CM_StatusLabel.Value := "Export failed: " err.Message
    }
}

CM_ImportMovement(*) {
    aaMainUI.Opt("-AlwaysOnTop")
    file := FileSelect(3, A_ScriptDir "\Settings", "Import custom movement", "Text Documents (*.txt)")
    aaMainUI.Opt("+AlwaysOnTop")
    if (file = "")
        return
    try {
        content := FileRead(file, "UTF-8")
    } catch as err {
        CM_StatusLabel.Value := "Import failed: " err.Message
        return
    }

    ; split into [Map name] sections; a file without sections is one map's recording
    sections := Map(), order := [], current := "", loose := ""
    for line in StrSplit(content, "`n", "`r") {
        t := Trim(line)
        if RegExMatch(t, "^\[(.+)\]$", &m) {
            current := Trim(m[1])
            if !sections.Has(current)
                order.Push(current)
            sections[current] := ""
            continue
        }
        if (current != "")
            sections[current] .= t "`n"
        else
            loose .= t "`n"
    }
    if !order.Length {
        target := CM_MapList.Text
        if (target = "") {
            CM_StatusLabel.Value := "This file has one recording - pick its map in the Map list first, then Import again."
            return
        }
        order.Push(target)
        sections[target] := loose
    }

    valid := [], skipped := "", replacing := 0
    for name in order {
        mapName := CM_MapSpelling(name)
        if (mapName = "") {
            skipped .= (skipped = "" ? "" : ", ") name " (unknown map)"
            continue
        }
        events := CM_ParseText(sections[name], mapName, &total)
        if !IsObject(events) {
            skipped .= (skipped = "" ? "" : ", ") mapName " (empty / unreadable)"
            continue
        }
        if FileExist(CM_FileFor(mapName))
            replacing++
        valid.Push({map: mapName, events: events, total: total})
    }
    if !valid.Length {
        CM_StatusLabel.Value := "Nothing imported" (skipped != "" ? " - skipped: " skipped : ".")
        return
    }
    names := ""
    for v in valid
        names .= (names = "" ? "" : ", ") v.map
    question := "Import " valid.Length " recording(s)?`n" names
        . (replacing ? "`n`n" replacing " will replace your current recording (kept as .bak)." : "")
        . (skipped != "" ? "`n`nSkipped: " skipped : "")
    if (MsgBox(question, "Import Custom Movement", 0x1024) != "Yes")
        return
    done := 0
    for v in valid
        if CM_SaveFile(v.map, v.events, v.total, "imported")
            done++
    CM_RefreshPanel()
    CM_StatusLabel.Value := "Imported " done " recording(s)" (skipped != "" ? " - skipped: " skipped : ".")
    AddToLog("Imported " done " custom movement recording(s)")
}

; ---- replay -----------------------------------------------------------------

CM_PlayMovement(mapName) {
    events := CM_LoadFile(mapName)
    if !IsObject(events) {
        AddToLog("Custom movement for " mapName " is empty or unreadable - using the default movement")
        return false
    }
    AddToLog("Executing custom movement for: " mapName " (" events.Length " inputs)")
    try WinActivate(rblxID)
    held := Map()
    start := A_TickCount
    try {
        for ev in events {
            wait := ev.t - (A_TickCount - start)
            if (wait > 0)
                Sleep(wait)
            if InStr(ev.key, "wheel") {         ; [Zoom] one wheel notch
                if (ev.down)
                    Send("{" ev.key "}")
                continue
            }
            SendInput("{" ev.key (ev.down ? " down" : " up") "}")
            if (ev.down)
                held[ev.key] := true
            else if held.Has(ev.key)
                held.Delete(ev.key)
        }
    } finally {
        for key in held                 ; never leave a key held down
            SendInput("{" key " up}")
    }
    return true
}
