#Requires AutoHotkey v2.0

; ============================================================================

; ============================================================================

global SchedEntries := []
global SchedOptions := Map("enabled", "0", "finish", "Loop schedule")
global SchedState := {index: 0, runs: 0, started: 0, startedAt: "", target: ""}
global SchedFile := RegExReplace(A_ScriptDir, "i)\\Lib$") "\Settings\Schedule.txt"   ; always the macro's Settings folder
global SchedGui := "", SchedT := "", SchedBtns := Map(), SchedUI := Map()
global SchedModes := ["Story", "Legend", "Raid", "Infinity Castle", "Portal", "Contract", "Dungeon", "Cursed Womb", "Fool's Hunt", "Winter Event"]
global SchedFinishModes := ["Loop schedule", "Stop macro", "Stop + close Roblox"]
; [Scheduler team swap] per-step team (1-4) and placement profile ("config")
global SchedTeamItems := ["Keep", "Team 1", "Team 2", "Team 3", "Team 4"]
global SchedProfileFallback := ["Default", "Challenge", "Contract", "Dungeon", "Raid", "Fool's Hunt"]
global SchedPendingTeam := ""   ; team to equip in the lobby before the step's mode starts
global SchedLastTeam := ""      ; team the scheduler last equipped (skips a swap to the same team)

; ============================================================================
;  GUI  -  [Scheduler panel] a panel inside the main window (like Settings) instead of a
;  separate window. Built hidden at start-up by GUI.ahk (Sched_BuildPanel); the Scheduler
;  button opens / closes it. All scheduler logic below is unchanged.
; ============================================================================

OpenScheduler(*) {
    AA_TogglePanel("Scheduler")
}

; Called by AA_ShowPanel when the panel is opened.
Sched_OnPanelOpen() {
    Sched_RefreshUI()
    Sched_ApplyVisibility()
}

Sched_Close(*) {
    AA_ShowPanel("")
}

Sched_BuildPanel() {
    global SchedGui, SchedT, SchedUI
    Sched_Load()
    SchedT := SchedTheme()
    SchedT.input := AA_OffColor           ; "off" colour of the Use schedule switch
    SchedUI := Map()
    SchedGui := aaMainUI                  ; message boxes belong to the main window
    t := SchedT
    P := "Scheduler"
    add := (type, opts, txt := "") => AA_PanelAdd(type, opts, txt, P)

    aaMainUI.SetFont("s9 Bold c" t.text, "Segoe UI")
    add("GroupBox", "x808 y85 w550 h64", "Task Scheduler")
    add("GroupBox", "x808 y153 w326 h228", "Queue")
    add("GroupBox", "x1138 y153 w220 h228", "Add / Edit Step")

    ; ---- top card: status, use schedule, save, when finished, progress ----
    SchedUI["status"] := add("Text", "x822 y103 w316 h18 c" t.text, "")
    aaMainUI.SetFont("s8 Bold c" t.muted)
    add("Text", "x1144 y105 w70 h16 c" t.muted, "Use schedule")
    add("Text", "x822 y128 w86 h16 c" t.muted, "When finished")
    SchedUI["progressText"] := add("Text", "x1070 y128 w170 h16 Right c" t.muted, "")
    aaMainUI.SetFont("s9 Bold c" t.text)
    SchedUI["toggle"] := add("Text", "x1216 y102 w52 h20 Center +0x200 +Background" t.input " c" t.text, "OFF")
    SchedUI["toggle"].OnEvent("Click", Sched_ToggleClick)
    SchedUI["save"] := add("Button", "x1274 y101 w74 h22", "Save")
    SchedUI["save"].OnEvent("Click", Sched_SaveClick)
    Sched_AccentBtn(SchedUI["save"])
    aaMainUI.SetFont("s9 norm c" t.text)
    SchedUI["finish"] := add("DropDownList", "x910 y124 w150 r3", SchedFinishModes)
    SchedUI["finish"].OnEvent("Change", (ctrl, *) => SchedOptions["finish"] := ctrl.Text)
    try SchedUI["finish"].Choose(SchedOptions["finish"])
    catch
        SchedUI["finish"].Choose(1)
    SchedUI["progress"] := add("Progress", "x1246 y132 w102 h8 Background" AA_InputBg " c" t.accent, 0)

    ; ---- queue list ----
    aaMainUI.SetFont("s7 Bold c" t.muted)
    add("Text", "x820 y174 w20 h14 c" t.muted, "#")
    add("Text", "x840 y174 w76 h14 c" t.muted, "MODE")
    add("Text", "x916 y174 w96 h14 c" t.muted, "MAP / OPTION")
    add("Text", "x1012 y174 w56 h14 c" t.muted, "UNTIL")
    add("Text", "x1068 y174 w56 h14 c" t.muted, "TEAM/CFG")
    add("Text", "x816 y189 w310 h2 +Background" t.accent)
    aaMainUI.SetFont("s9 norm cFFFFFF")
    lv := add("ListView", "x816 y192 w310 h150 -Hdr -Multi NoSortHdr -E0x200 cFFFFFF", ["", "Mode", "Map / Option", "Until", "Team / config"])
    lv.ModifyCol(1, 24), lv.ModifyCol(2, 76), lv.ModifyCol(3, 96), lv.ModifyCol(4, 56), lv.ModifyCol(5, 54)
    lv.OnEvent("Click", Sched_OnRowClick)
    lv.OnNotify(-12, Sched_LVCustomDraw)    ; NM_CUSTOMDRAW: we paint the row text ourselves
    SchedUI["lv"] := lv
    Sched_DarkTheme(lv, "DarkMode_Explorer")   ; dark scrollbar
    Sched_LVColors(lv, "FFFFFF", AA_InputBg)
    aaMainUI.SetFont("s9 Bold c" t.text)
    btn := add("Button", "x816 y350 w98 h24", "Copy current")
    btn.OnEvent("Click", Sched_FromMain)
    btn := add("Button", "x922 y350 w98 h24", "Remove")
    btn.OnEvent("Click", Sched_Remove)
    btn := add("Button", "x1028 y350 w98 h24", "Clear all")
    btn.OnEvent("Click", Sched_Clear)

    ; ---- editor ----  [Scheduler team swap] stage + act share a row so TEAM / CONFIG fit
    aaMainUI.SetFont("s7 Bold c" t.muted)
    add("Text", "x1148 y169 w120 h12 c" t.muted, "MODE")
    SchedUI["label1"] := add("Text", "x1148 y206 w112 h12 c" t.muted, "STAGE")
    SchedUI["label2"] := add("Text", "x1264 y206 w84 h12 c" t.muted, "ACT")
    add("Text", "x1148 y243 w70 h12 c" t.muted, "TEAM")
    add("Text", "x1222 y243 w126 h12 c" t.muted, "CONFIG")
    add("Text", "x1148 y280 w120 h12 c" t.muted, "RUN UNTIL")
    aaMainUI.SetFont("s9 norm c" t.text)
    SchedUI["mode"] := add("DropDownList", "x1148 y182 w200 r12 Choose1", Sched_GetItems("ModeDropdown", SchedModes))
    SchedUI["mode"].OnEvent("Change", Sched_OnModeChange)
    SchedUI["map"] := add("DropDownList", "x1148 y219 w112 r14", [])
    SchedUI["act"] := add("DropDownList", "x1264 y219 w84 r10", [])
    Sched_DropWidth(SchedUI["map"], 180), Sched_DropWidth(SchedUI["act"], 120)
    SchedUI["team"] := add("DropDownList", "x1148 y256 w70 r5 Choose1", SchedTeamItems)
    SchedUI["profile"] := add("DropDownList", "x1222 y256 w126 r8 Choose1", Sched_ProfileItems())
    try AA_Tip(SchedUI["team"], "Team to equip in the lobby before this step starts (Keep = no swap)")
    try AA_Tip(SchedUI["profile"], "Unit placement config this step uses (Keep current = leave it as it is)")
    aaMainUI.SetFont("s8 italic c" t.muted)
    SchedUI["noopt"] := add("Text", "x1148 y206 w200 h34 c" t.muted, "Nothing else to pick for this mode - it uses your main GUI settings.")
    aaMainUI.SetFont("s9 norm c" t.text)
    SchedUI["untilType"] := add("DropDownList", "x1148 y293 w96 r3 Choose1", ["Runs", "Minutes", "Clock time"])
    SchedUI["untilType"].OnEvent("Change", Sched_OnUntilTypeChange)
    SchedUI["untilValue"] := add("Edit", "x1250 y293 w56 h22 Number Center", "10")
    hours := [], mins := []
    loop 24
        hours.Push(Format("{:02}", A_Index - 1))
    loop 12
        mins.Push(Format("{:02}", (A_Index - 1) * 5))
    SchedUI["hour"] := add("DropDownList", "x1250 y293 w46 r12 Choose7", hours)
    SchedUI["minute"] := add("DropDownList", "x1300 y293 w46 r12 Choose7", mins)
    aaMainUI.SetFont("s8 Bold c" t.text)
    SchedUI["chips"] := []
    loop 4 {
        btn := add("Button", Format("x{} y320 w47 h18", 1148 + (A_Index - 1) * 51), "")
        btn.OnEvent("Click", Sched_Chip.Bind(A_Index))
        SchedUI["chips"].Push(btn)
    }
    aaMainUI.SetFont("s9 Bold c" t.text)
    btn := add("Button", "x1148 y345 w97 h26", "+  Add")
    btn.OnEvent("Click", Sched_Add)
    Sched_AccentBtn(btn)
    btn := add("Button", "x1251 y345 w97 h26", "Update")
    btn.OnEvent("Click", Sched_Update)

    ; ---- initial state (then hide again - the panel opens via the Scheduler button) ----
    Sched_OnModeChange(SchedUI["mode"])
    Sched_ShowUntil("Runs")
    Sched_PaintToggle()
    Sched_FillList()
    Sched_RefreshUI()
    for ctrl in AA_Panels[P]
        ctrl.Visible := false
}

; Shows / hides the editor fields for the current mode and "run until" type
; (the panel shows every control when it opens, so this runs right after).
Sched_ApplyVisibility() {
    global SchedUI
    fields := Sched_ModeFields(SchedUI["mode"].Text)
    boxes := [SchedUI["map"], SchedUI["act"]], labels := [SchedUI["label1"], SchedUI["label2"]]
    for i, box in boxes {
        vis := (i <= fields.Length)
        box.Visible := vis, labels[i].Visible := vis
    }
    SchedUI["noopt"].Visible := (fields.Length = 0)
    Sched_ShowUntil(SchedUI["untilType"].Text)
}

Sched_AccentBtn(ctrl) {
    try {
        b := AA_FlatBtns[ctrl.Hwnd]
        b.bg := uiTheme[3], b.hover := AA_Shade(uiTheme[3], 24)
        AA_BtnPaint(b)
    }
}

; Shows the Use schedule switch state without saving (Sched_SetToggle saves).
Sched_PaintToggle() {
    global SchedUI, SchedT, SchedOptions
    on := SchedOptions["enabled"] = "1"
    c := SchedUI["toggle"]
    c.Text := on ? "ON" : "OFF"
    c.Opt("+Background" (on ? SchedT.accent : SchedT.input))
    c.Redraw()
}

; ---- small GUI helpers ----

SchedTheme() {
    global uiTheme
    t := {text: "F2F2F2", bg: "181818", accent: "2F81F7", panel: "242424", input: "111111", hi: "79B8FF", muted: "8C8C8C"}
    try {
        if (IsSet(uiTheme) && uiTheme.Length >= 7) {
            t.text := uiTheme[1], t.bg := uiTheme[2], t.accent := uiTheme[3]
            t.panel := uiTheme[4], t.input := uiTheme[6], t.hi := uiTheme[7]
        }
    }
    return t
}

SchedButton(g, opts, label, bg, hover, handler) {
    global SchedBtns
    b := g.Add("Text", opts " Center +0x200 Background" bg, label)
    b.OnEvent("Click", handler)
    SchedBtns[b.Hwnd] := {ctrl: b, bg: bg, hover: hover}
    return b
}

Sched_Label(g, opts, text, bg := "") {
    global SchedT
    g.SetFont("s7 cFFFFFF", "Segoe UI Semibold")
    return g.Add("Text", opts " w180 h14 Background" (bg != "" ? bg : SchedT.panel), text)
}

Sched_Cue(edit, hint) {
    try SendMessage(0x1501, true, StrPtr(hint), edit)   ; EM_SETCUEBANNER
}

; Lets a narrow dropdown open wider than itself so long map names stay readable
Sched_DropWidth(ddl, w) {
    try SendMessage(0x160, w, 0, ddl)   ; CB_SETDROPPEDWIDTH
}

; [Scheduler team swap] CONFIG choices = the main GUI's placement profiles
Sched_ProfileItems() {
    global SchedProfileFallback
    items := ["Keep current"]
    for name in Sched_GetItems("PlacementSelection", SchedProfileFallback)
        items.Push(name)
    return items
}

; Paints every row's text white (and the running step in the accent colour).
; Windows can't override this, unlike the "c" option.
Sched_LVCustomDraw(lv, lParam) {
    global SchedState, SchedT
    stage := NumGet(lParam, A_PtrSize * 3, "UInt")
    if (stage = 0x1)                  ; CDDS_PREPAINT
        return 0x20                   ; CDRF_NOTIFYITEMDRAW -> ask for each row
    if (stage = 0x10001) {            ; CDDS_ITEMPREPAINT
        offText := (A_PtrSize = 8) ? 80 : 48
        row := NumGet(lParam, (A_PtrSize = 8) ? 56 : 36, "UPtr") + 1
        hex := (row = SchedState.index) ? SchedT.hi : "FFFFFF"
        c := Integer("0x" hex)
        NumPut("UInt", ((c & 0xFF) << 16) | (c & 0xFF00) | ((c >> 16) & 0xFF), lParam, offText)   ; clrText (BGR)
        return 0                      ; CDRF_DODEFAULT
    }
    return 0
}

; Force ListView text/background colours (Windows wants BGR, not RGB)
Sched_LVColors(lv, textHex, bgHex) {
    toBGR(hex) {
        c := Integer("0x" hex)
        return ((c & 0xFF) << 16) | (c & 0xFF00) | ((c >> 16) & 0xFF)
    }
    try {
        SendMessage(0x1024, 0, toBGR(textHex), lv)   ; LVM_SETTEXTCOLOR
        SendMessage(0x1026, 0, toBGR(bgHex), lv)     ; LVM_SETTEXTBKCOLOR
        SendMessage(0x1001, 0, toBGR(bgHex), lv)     ; LVM_SETBKCOLOR
        lv.Redraw()
    }
}

Sched_DarkTheme(ctrl, theme) {
    try DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", theme, "Ptr", 0)
}

Sched_Shade(hex, amt) {
    c := Integer("0x" hex)
    r := Min(255, Max(0, ((c >> 16) & 0xFF) + amt))
    gg := Min(255, Max(0, ((c >> 8) & 0xFF) + amt))
    b := Min(255, Max(0, (c & 0xFF) + amt))
    return Format("{:02X}{:02X}{:02X}", r, gg, b)
}

Sched_OnMouseMove(wParam, lParam, msg, hwnd) {
    global SchedBtns
    static last := 0
    if (hwnd = last)
        return
    if (last && SchedBtns.Has(last)) {
        b := SchedBtns[last]
        try b.ctrl.Opt("+Background" b.bg), b.ctrl.Redraw()
    }
    last := 0
    if SchedBtns.Has(hwnd) {
        b := SchedBtns[hwnd]
        try b.ctrl.Opt("+Background" b.hover), b.ctrl.Redraw()
        last := hwnd
    }
}

Sched_OnLButtonDown(wParam, lParam, msg, hwnd) {
    global SchedGui
    if IsObject(SchedGui) && (hwnd = SchedGui.Hwnd)
        PostMessage(0xA1, 2,,, "ahk_id " SchedGui.Hwnd)   ; drag the window
}

Sched_SetToggle(on) {
    global SchedUI, SchedT, SchedOptions
    SchedOptions["enabled"] := on ? "1" : "0"
    if !SchedUI.Has("toggle")
        return
    c := SchedUI["toggle"]
    c.Text := on ? "ON" : "OFF"
    c.Opt("+Background" (on ? SchedT.accent : SchedT.input))
    c.Redraw()
    Sched_Save()   ; auto-save so F2 sees it straight away
    Sched_RefreshUI()
}

Sched_ToggleClick(*) {
    Sched_SetToggle(SchedOptions["enabled"] != "1")
}

Sched_OnUntilTypeChange(ctrl, *) {
    Sched_ShowUntil(ctrl.Text)
    switch ctrl.Text {
        case "Runs":    Sched_SetUntilNumber(10)
        case "Minutes": Sched_SetUntilNumber(60)
    }
}

Sched_ShowUntil(type) {
    global SchedUI
    isClock := (type = "Clock time")
    SchedUI["untilValue"].Visible := !isClock
    SchedUI["hour"].Visible := isClock
    SchedUI["minute"].Visible := isClock
    labels := (type = "Minutes") ? ["30m", "1h", "2h", "4h"] : ["5", "10", "25", "50"]
    for i, chip in SchedUI["chips"] {
        chip.Text := labels[i]
        chip.Visible := !isClock
    }
}

Sched_SetUntilNumber(n) {
    global SchedUI
    SchedUI["untilValue"].Value := n
}

Sched_Chip(i, *) {
    global SchedUI
    presets := (SchedUI["untilType"].Text = "Minutes") ? [30, 60, 120, 240] : [5, 10, 25, 50]
    Sched_SetUntilNumber(presets[i])
}

; What each mode needs: label + which main-GUI dropdown to copy the choices from
Sched_ModeFields(mode) {
    static stories := ["Planet Greenie", "Walled City", "Snowy Town", "Sand Village", "Navy Bay", "Fiend City", "Spirit World", "Ant Kingdom", "Magic Town", "Haunted Academy", "Magic Hills", "Space Center", "Alien Spaceship", "Fabled Kingdom", "Ruined City", "Puppet Island", "Virtual Dungeon", "Snowy Kingdom", "Dungeon Throne", "Mountain Temple", "Rain Village", "Shibuya District"]
    static legends := ["Magic Hills", "Spirit Invasion", "Space Center", "Fabled Kingdom", "Ruined City", "Virtual Dungeon", "Dungeon Throne", "Rain Village"]
    static raids := ["Ant Kingdom", "Sacred Planet", "Strange Town", "Ruined City", "Cursed Festival", "Future City (Tyrant)", "Storm Hideout", "Future City", "Nightmare Train", "Sand Village"]
    static portals := ["Alien Portal", "Puppet Portal", "Demon Leader's Portal", "Eclipse Portal", "Noble Portal", "Shibuya Portal", "Sky Portal"]
    switch mode {
        case "Story":
            return [{label: "STAGE", ctrl: "StoryDropdown", items: stories}
                  , {label: "ACT", ctrl: "StoryActDropdown", items: ["Act 1", "Act 2", "Act 3", "Act 4", "Act 5", "Act 6", "Infinity"]}]
        case "Legend":
            return [{label: "STAGE", ctrl: "LegendDropDown", items: legends}
                  , {label: "ACT", ctrl: "LegendActDropdown", items: ["Act 1", "Act 2", "Act 3", "Act 4", "Act 5", "Act 6", "Random"]}]
        case "Raid":
            return [{label: "RAID", ctrl: "RaidDropdown", items: raids}
                  , {label: "ACT", ctrl: "RaidActDropdown", items: ["Act 1", "Act 2", "Act 3", "Act 4", "Act 5"]}]
        case "Infinity Castle":
            return [{label: "DIFFICULTY", ctrl: "InfinityCastleDropdown", items: ["Normal", "Hard"]}]
        case "Portal":
            return [{label: "PORTAL", ctrl: "PortalDropdown", items: portals}
                  , {label: "JOIN TYPE", ctrl: "PortalJoinDropdown", items: ["Creating", "Joining", "Solo"]}]
        case "Contract":
            return [{label: "PAGE", ctrl: "ContractPageDropdown", items: ["Page 1", "Page 2", "Page 3", "Page 4", "Page 5", "Page 6", "Page 4-5"]}
                  , {label: "JOIN TYPE", ctrl: "ContractJoinDropdown", items: ["Creating", "Joining", "Matchmaking", "Solo"]}]
    }
    return []
}

; Items of a main-GUI dropdown (so new maps show up automatically); fallback list in preview
Sched_GetItems(ctrlName, fallback) {
    try {
        c := %ctrlName%
        items := ControlGetItems(c.Hwnd)
        if (items.Length)
            return items
    }
    return fallback
}

Sched_OnModeChange(ctrl, *) {
    global SchedUI
    fields := Sched_ModeFields(ctrl.Text)
    boxes := [SchedUI["map"], SchedUI["act"]], labels := [SchedUI["label1"], SchedUI["label2"]]
    for i, box in boxes {
        box.Delete()
        if (i <= fields.Length) {
            f := fields[i]
            box.Add(Sched_GetItems(f.ctrl, f.items))
            box.Choose(1)
            labels[i].Text := f.label
            box.Visible := true, labels[i].Visible := true
        } else {
            box.Visible := false, labels[i].Visible := false
        }
    }
    SchedUI["noopt"].Visible := (fields.Length = 0)
}

; Fill the editor with whatever is selected in the main GUI right now
Sched_FromMain(*) {
    global SchedUI, SchedGui
    try mainMode := ModeDropdown.Text
    catch
        mainMode := ""
    if (mainMode = "") {
        MsgBox("Pick a mode in the main GUI first.", "Task Scheduler", "Iconi Owner" SchedGui.Hwnd)
        return
    }
    try SchedUI["mode"].Choose(mainMode)
    Sched_OnModeChange(SchedUI["mode"])
    for i, f in Sched_ModeFields(mainMode) {
        try {
            c := %f.ctrl%
            if (c.Text != "")
                (i = 1 ? SchedUI["map"] : SchedUI["act"]).Choose(c.Text)
        }
    }
    try SchedUI["profile"].Choose(PlacementSelection.Text)   ; [Scheduler team swap] current config too
}

; ---- list + editor ----

Sched_FillList() {
    global SchedUI, SchedEntries, SchedState
    if !SchedUI.Has("lv")
        return
    lv := SchedUI["lv"]
    lv.Opt("-Redraw")
    lv.Delete()
    for i, e in SchedEntries
        lv.Add("", (i = SchedState.index ? "● " i : i), e.mode, Sched_MapText(e), Sched_UntilText(e), Sched_SetupText(e))
    lv.Opt("+Redraw")
}

Sched_OnRowClick(lv, row) {
    global SchedEntries, SchedUI
    if (row < 1 || row > SchedEntries.Length)
        return
    e := SchedEntries[row]
    try SchedUI["mode"].Choose(e.mode)
    Sched_OnModeChange(SchedUI["mode"])
    if (e.map != "")
        try SchedUI["map"].Choose(e.map)
    if (e.act != "")
        try SchedUI["act"].Choose(e.act)
    try SchedUI["untilType"].Choose(e.untilType)
    Sched_ShowUntil(e.untilType)
    if (e.untilType = "Clock time") {
        hm := StrSplit(e.untilValue, ":")
        try SchedUI["hour"].Choose(Integer(hm[1]) + 1)
        try SchedUI["minute"].Choose(Integer(hm[2]) // 5 + 1)
    } else
        Sched_SetUntilNumber(e.untilValue)
    try SchedUI["team"].Choose(e.team = "" ? 1 : "Team " e.team)        ; [Scheduler team swap]
    try SchedUI["profile"].Choose(e.profile = "" ? 1 : e.profile)
    catch
        SchedUI["profile"].Choose(1)
}

Sched_ReadEditor() {
    global SchedUI, SchedGui
    e := {mode: SchedUI["mode"].Text
        , map: SchedUI["map"].Visible ? SchedUI["map"].Text : ""
        , act: SchedUI["act"].Visible ? SchedUI["act"].Text : ""
        , untilType: SchedUI["untilType"].Text, untilValue: ""
        , team: RegExReplace(SchedUI["team"].Text, "\D")                                    ; "" = keep
        , profile: SchedUI["profile"].Value <= 1 ? "" : SchedUI["profile"].Text}         ; "" = keep current
    if (e.mode = "") {
        MsgBox("Pick a mode first.", "Task Scheduler", "Icon! Owner" SchedGui.Hwnd)
        return ""
    }
    if (e.untilType = "Clock time") {
        e.untilValue := SchedUI["hour"].Text ":" SchedUI["minute"].Text
    } else {
        e.untilValue := Trim(SchedUI["untilValue"].Value)
        if !(IsInteger(e.untilValue) && e.untilValue > 0) {
            MsgBox("Enter a number above 0.", "Task Scheduler", "Icon! Owner" SchedGui.Hwnd)
            return ""
        }
    }
    return e
}

Sched_SelectedRow() {
    global SchedUI
    return SchedUI["lv"].GetNext(0)
}

Sched_Add(*) {
    global SchedEntries, SchedUI
    if !(e := Sched_ReadEditor())
        return
    SchedEntries.Push(e)
    Sched_FillList()
    SchedUI["lv"].Modify(SchedEntries.Length, "Select Focus Vis")
    Sched_Save()
    Sched_RefreshUI()
}

Sched_Update(*) {
    global SchedEntries, SchedUI, SchedGui
    if !(row := Sched_SelectedRow()) {
        MsgBox("Click a row in the list first.", "Task Scheduler", "Iconi Owner" SchedGui.Hwnd)
        return
    }
    if !(e := Sched_ReadEditor())
        return
    SchedEntries[row] := e
    Sched_FillList()
    SchedUI["lv"].Modify(row, "Select Focus")
    Sched_Save()
    Sched_RefreshUI()
}

Sched_Remove(*) {
    global SchedEntries, SchedUI, SchedState
    if !(row := Sched_SelectedRow())
        return
    SchedEntries.RemoveAt(row)
    if (SchedState.index > SchedEntries.Length)
        SchedState.index := 0
    Sched_FillList()
    if (SchedEntries.Length)
        SchedUI["lv"].Modify(Min(row, SchedEntries.Length), "Select Focus")
    Sched_Save()
    Sched_RefreshUI()
}

Sched_Clear(*) {
    global SchedEntries, SchedState, SchedGui
    if (!SchedEntries.Length)
        return
    if (MsgBox("Remove every step from the schedule?", "Task Scheduler", "YesNo Icon? Owner" SchedGui.Hwnd) != "Yes")
        return
    SchedEntries := []
    SchedState.index := 0
    Sched_FillList()
    Sched_Save()
    Sched_RefreshUI()
}

Sched_MoveUp(*) => Sched_Move(-1)
Sched_MoveDown(*) => Sched_Move(1)

Sched_Move(dir) {
    global SchedEntries, SchedUI, SchedState
    if !(row := Sched_SelectedRow())
        return
    to := row + dir
    if (to < 1 || to > SchedEntries.Length)
        return
    tmp := SchedEntries[row], SchedEntries[row] := SchedEntries[to], SchedEntries[to] := tmp
    if (SchedState.index = row)
        SchedState.index := to
    else if (SchedState.index = to)
        SchedState.index := row
    Sched_FillList()
    SchedUI["lv"].Modify(to, "Select Focus Vis")
}

Sched_SaveClick(*) {
    global SchedUI
    Sched_Save()
    btn := SchedUI["save"]
    btn.Text := "Saved"
    SetTimer(() => btn.Text := "Save", -1200)
}

Sched_RefreshUI() {
    global SchedGui, SchedUI, SchedEntries, SchedState, SchedOptions
    if !IsObject(SchedGui) || !SchedUI.Has("status")
        return
    Sched_FillList()
    i := SchedState.index
    if (i >= 1 && i <= SchedEntries.Length) {
        e := SchedEntries[i]
        SchedUI["status"].Text := "Step " i "/" SchedEntries.Length "  ·  " Sched_Describe(e)
        p := Sched_Progress(e)
        SchedUI["progress"].Value := p.pct
        SchedUI["progressText"].Text := p.text
    } else {
        SchedUI["status"].Text := SchedOptions["enabled"] = "1"
            ? (SchedEntries.Length ? "Ready - starts with the macro" : "Add a step to get started")
            : "Scheduler is off"
        SchedUI["progress"].Value := 0
        SchedUI["progressText"].Text := SchedEntries.Length " step" (SchedEntries.Length = 1 ? "" : "s") " queued"
    }
}

Sched_Progress(e) {
    global SchedState
    switch e.untilType {
        case "Runs":
            total := Integer(e.untilValue)
            return {pct: Min(100, SchedState.runs * 100 // total), text: SchedState.runs " / " total " runs"}
        case "Minutes":
            total := Integer(e.untilValue)
            done := (A_TickCount - SchedState.started) // 60000
            return {pct: Min(100, done * 100 // total), text: done " / " total " min"}
        default:
            pct := 0
            try {
                full := DateDiff(SchedState.target, SchedState.startedAt, "Seconds")
                gone := DateDiff(A_Now, SchedState.startedAt, "Seconds")
                pct := full > 0 ? Min(100, gone * 100 // full) : 0
            }
            return {pct: pct, text: "until " e.untilValue}
    }
}

Sched_MapText(e) {
    if (e.map != "" && e.act != "")
        return e.map " · " e.act
    return e.map != "" ? e.map : e.act
}

Sched_UntilText(e) {
    switch e.untilType {
        case "Runs":    return e.untilValue " runs"
        case "Minutes": return e.untilValue " min"
        default:        return "until " e.untilValue
    }
}

Sched_Describe(e) {
    m := Sched_MapText(e)
    d := e.mode (m != "" ? "  ·  " m : "")
    if (e.team != "")                     ; [Scheduler team swap]
        d .= "  ·  Team " e.team
    if (e.profile != "")
        d .= "  ·  " e.profile " config"
    return d
}

; [Scheduler team swap] short "Team / config" column text, e.g. "T2 Chal"
Sched_SetupText(e) {
    t := (e.team != "") ? "T" e.team : ""
    if (e.profile != "")
        t .= (t != "" ? " " : "") Sched_ProfileShort(e.profile)
    return t != "" ? t : "-"
}

Sched_ProfileShort(p) {
    switch p {
        case "Default":     return "Def"
        case "Challenge":   return "Chal"
        case "Contract":    return "Cont"
        case "Dungeon":     return "Dung"
        case "Fool's Hunt": return "Fool"
    }
    return SubStr(p, 1, 4)
}

; ============================================================================
;  Save / load  (Settings\Schedule.txt)
; ============================================================================

Sched_Save() {
    global SchedEntries, SchedOptions, SchedFile
    text := "@enabled=" SchedOptions["enabled"] "`n@finish=" SchedOptions["finish"] "`n"
    for e in SchedEntries
        text .= e.mode "|" e.map "|" e.act "|" e.untilType "|" e.untilValue "|" e.team "|" e.profile "`n"
    SplitPath(SchedFile, , &dir)
    if !DirExist(dir)
        DirCreate(dir)
    f := FileOpen(SchedFile, "w", "UTF-8")
    f.Write(text)
    f.Close()
}

Sched_Load() {
    global SchedEntries, SchedOptions, SchedFile
    SchedEntries := []
    if !FileExist(SchedFile)
        return
    for line in StrSplit(FileRead(SchedFile, "UTF-8"), "`n", "`r") {
        if (line = "")
            continue
        if (SubStr(line, 1, 1) = "@") {
            kv := StrSplit(SubStr(line, 2), "=", , 2)
            if (kv.Length = 2)
                SchedOptions[kv[1]] := kv[2]
            continue
        }
        p := StrSplit(line, "|")
        if (p.Length >= 5)   ; [Scheduler team swap] fields 6/7 (team, profile) are optional - older files load as "keep"
            SchedEntries.Push({mode: p[1], map: p[2], act: p[3], untilType: p[4], untilValue: p[5]
                , team: p.Length >= 6 ? p[6] : "", profile: p.Length >= 7 ? p[7] : ""})
    }
}

; ============================================================================
;  Runtime - called by the macro
; ============================================================================

ScheduleEnabled() {
    global SchedOptions, SchedEntries
    return SchedOptions["enabled"] = "1" && SchedEntries.Length > 0
}

; Call once when the macro starts. Applies step 1 if the schedule is on.
ScheduleStart() {
    Sched_Load()
    if !ScheduleEnabled() {
        Sched_Log(!FileExist(SchedFile) ? "Schedule: no saved schedule found (" SchedFile ")"
            : SchedOptions["enabled"] != "1" ? "Schedule: off (toggle is OFF in the saved file)"
            : "Schedule: on, but no steps saved")
        return false
    }
    Sched_Begin(1)
    return true
}

; Call once at the end of every match. Returns true if it switched to a new step
; (then send the macro back to the lobby so the new mode starts).
ScheduleTick() {
    global SchedState, SchedEntries, SchedOptions
    if (!ScheduleEnabled() || SchedState.index < 1)
        return false
    if (SchedState.index > SchedEntries.Length)
        SchedState.index := 1

    SchedState.runs += 1
    e := SchedEntries[SchedState.index]
    done := false
    switch e.untilType {
        case "Runs":       done := SchedState.runs >= Integer(e.untilValue)
        case "Minutes":    done := (A_TickCount - SchedState.started) >= Integer(e.untilValue) * 60000
        case "Clock time": done := (SchedState.target != "" && A_Now >= SchedState.target)
    }
    Sched_RefreshUI()
    if !done
        return false

    nextIndex := SchedState.index + 1
    if (nextIndex > SchedEntries.Length) {
        switch SchedOptions["finish"] {
            case "Stop macro":          Sched_Stop(false)
            case "Stop + close Roblox": Sched_Stop(true)
        }
        nextIndex := 1
    }

    if (nextIndex = SchedState.index) {   ; single-step schedule looping: keep going, just reset counters
        Sched_Begin(nextIndex, false)
        return false
    }
    Sched_Begin(nextIndex)
    return true
}

Sched_Begin(i, apply := true) {
    global SchedState, SchedEntries
    e := SchedEntries[i]
    SchedState.index := i
    SchedState.runs := 0
    SchedState.started := A_TickCount
    SchedState.startedAt := A_Now
    SchedState.target := ""
    if (e.untilType = "Clock time") {
        hm := StrSplit(e.untilValue, ":")
        target := FormatTime(A_Now, "yyyyMMdd") Format("{:02}{:02}00", Integer(hm[1]), Integer(hm[2]))
        if (target <= A_Now)
            target := DateAdd(target, 1, "Days")
        SchedState.target := target
    }
    if apply
        ApplyScheduleEntry(e)
    Sched_RefreshUI()
}

Sched_Stop(closeRoblox) {
    Sched_Log("Schedule finished - stopping the macro")
    fn := "SendFinalWebhookBeforeExit"
    try %fn%()
    if closeRoblox
        try ProcessClose("RobloxPlayerBeta.exe")
    Reload()
}

; Sets the main GUI to this step's mode (same idea as SwitchActiveFarm in Portal.ahk)
ApplyScheduleEntry(e) {
    global mode, confirmClicked, SchedPendingTeam
    Sched_SetCtrl("ModeDropdown", e.mode)
    fn := "OnModeChange"
    try %fn%()
    mode := e.mode

    switch e.mode {
        case "Story":
            Sched_SetCtrl("StoryDropdown", e.map), Sched_SetCtrl("StoryActDropdown", e.act)
        case "Legend":
            Sched_SetCtrl("LegendDropDown", e.map), Sched_SetCtrl("LegendActDropdown", e.act)
        case "Raid":
            Sched_SetCtrl("RaidDropdown", e.map), Sched_SetCtrl("RaidActDropdown", e.act)
        case "Infinity Castle":
            Sched_SetCtrl("InfinityCastleDropdown", e.map != "" ? e.map : e.act)
        case "Portal":
            Sched_SetCtrl("PortalDropdown", e.map), Sched_SetCtrl("PortalJoinDropdown", e.act != "" ? e.act : "Solo")
        case "Contract":
            Sched_SetCtrl("ContractPageDropdown", e.map), Sched_SetCtrl("ContractJoinDropdown", e.act)
        case "Fool's Hunt":
            fn := "LoadFoolsConfig"
            try %fn%()
    }
    ; [Scheduler team swap] placement profile now, team swap later (in the lobby, see StartSelectedMode)
    if (e.profile != "")
        Sched_SetProfile(e.profile)
    SchedPendingTeam := e.team
    confirmClicked := true
    Sched_Log("Schedule -> " Sched_Describe(e) " (" Sched_UntilText(e) ")")
}

; [Scheduler team swap] switches the main GUI's placement profile (PlacementSelection),
; which GetNameForMode() reads to pick the unit setup. The unit cards are only
; redrawn when no panel is covering them.
Sched_SetProfile(profile) {
    global AA_ActivePanel
    Sched_SetCtrl("PlacementSelection", profile)
    if (!IsSet(AA_ActivePanel) || AA_ActivePanel = "")
        try ToggleMode()
}

; [Scheduler team swap] called by StartSelectedMode (in the lobby, before the mode starts).
; Equips the team the current step asked for, once.
Sched_RunPendingTeamSwap() {
    global SchedPendingTeam, SchedLastTeam
    if (SchedPendingTeam = "")
        return
    n := SchedPendingTeam
    SchedPendingTeam := ""
    if (n = SchedLastTeam) {
        Sched_Log("Team swap: Team " n " is already equipped")
        return
    }
    fn := "TS_SwapTeam"
    try {
        if %fn%(Integer(n))
            SchedLastTeam := n
    } catch as err {
        Sched_Log("Team swap failed: " err.Message)
    }
}

Sched_SetCtrl(name, value) {
    if (value = "")
        return
    try {
        ctrl := %name%
        ctrl.Text := value
    } catch {
        Sched_Log("Schedule: couldn't set " name " to '" value "' - check the spelling")
    }
}

Sched_Log(msg) {
    fn := "AddToLog"
    try %fn%(msg)
    catch
        OutputDebug(msg)
}

; [Scheduler panel] the stand-alone preview (running this file on its own) was removed:
; the scheduler is now a panel of the main window.
