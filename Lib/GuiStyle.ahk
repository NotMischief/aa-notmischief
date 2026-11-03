#Requires AutoHotkey v2.0

; ============================================================================
;  GuiStyle.ahk  -  [Modern GUI] look & feel of the main window
; ----------------------------------------------------------------------------
;  Only how the GUI looks - no gameplay, detection or setting changes.
;    * Flat buttons with hover (AA_Btn)          * active panel button highlighted
;    * Dark dropdowns / edit boxes / lists       * Segoe UI font (set in the GUI files)
;    * Cards instead of group boxes (AA_Card)    * ON/OFF switches for checkboxes
;    * Status bar (running / paused / stopped, mode, run time, W/L)
;    * Console: time in front of the newest line * tooltips on hover
;    * Theme picker (accent colour, Settings)
;    * Rounded window corners (Windows 11)
;  Never uses colour 303030: that is the see-through colour of the Roblox area.
;  Functions + globals only; GUI.ahk calls AA_StyleInit() and AA_StyleFinish().
; ============================================================================

global AA_FlatBtns := Map()        ; hwnd -> {ctrl, bg, hover, active, underline}
global AA_HoverHwnd := 0
global AA_Tips := Map()            ; hwnd -> tooltip text
global AA_TipHwnd := 0
global AA_Switches := []           ; {cb, pill, label, handler, last}
global AA_CardColor := "242424"
global AA_InputBg := "2D2D2D"
global AA_BtnBg := "363636"
global AA_OffColor := "3A3A3A"
global AA_OnGreen := "2EA043"
global AA_ThemeFile := A_ScriptDir "\Settings\Theme.txt"
global AA_ThemeOrder := ["Blue", "Geass", "Orange", "Purple", "Green", "Pink", "Red"]
global AA_Themes := Map(
    "Orange", ["E87522", "FFC074"],
    "Blue",   ["2F81F7", "79B8FF"],
    "Geass",  ["8E44FF", "E6B422"],   ; [NotMischef] royal purple borders, gold highlight
    "Purple", ["A371F7", "D2A8FF"],
    "Green",  ["2EA043", "7EE787"],
    "Pink",   ["DB61A2", "F778BA"],
    "Red",    ["DA3633", "FF7B72"])
global AA_StatusDot := "", AA_StatusText := "", AA_RunStart := 0, AA_WasRunning := false
global AA_ThemeList := ""

; ---- start-up -----------------------------------------------------------------

; Called right after uiTheme is filled (GUI.ahk): accent colour from the theme file, dark controls.
AA_StyleInit() {
    global uiTheme
    name := AA_ThemeName()
    if (name != "Blue") {   ; [NotMischef] blue is the built-in default now
        uiTheme[3] := AA_Themes[name][1]   ; borders / accent
        uiTheme[7] := AA_Themes[name][2]   ; highlight (newest console line)
    }
    try {   ; let Windows draw dropdowns, lists and scrollbars dark (Windows 10 1809+)
        hUx := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
        if !hUx
            hUx := DllCall("LoadLibrary", "Str", "uxtheme", "Ptr")
        fn := DllCall("GetProcAddress", "Ptr", hUx, "Ptr", 135, "Ptr")   ; SetPreferredAppMode
        if fn
            DllCall(fn, "Int", 2)                                        ; 2 = force dark
        fn := DllCall("GetProcAddress", "Ptr", hUx, "Ptr", 136, "Ptr")   ; FlushMenuThemes
        if fn
            DllCall(fn)
    }
}

AA_ThemeName() {
    try {
        if FileExist(AA_ThemeFile) {
            name := Trim(FileRead(AA_ThemeFile, "UTF-8"))
            if AA_Themes.Has(name)
                return name
        }
    }
    return "Blue"
}

; Called at the end of the GUI build (after settings are loaded, before Show).
AA_StyleFinish() {
    ; switches instead of checkboxes (same checkbox stays the value - only hidden)
    try AA_MakeSwitch(WebhookEnabledBox, "Settings", AA_SaveWebhookEnabled)
    try AA_MakeSwitch(SendActivityLogsBox, "Settings")
    try AA_MakeSwitch(FailsafeEnabledBox, "Settings")
    try AA_MakeSwitch(CM_PanelUseBox, "Movement", CM_SaveUseSetting)
    try AA_MakeSwitch(CP_UseBox, "Placement", CP_SaveUseSetting)   ; [Custom placement] ON / OFF
    try AA_MakeSwitch(CardPick_UseBox, "Cards", CardPick_Save)     ; [Card picker] ON / OFF
    try AA_MakeSwitch(PriorityUpgrade)
    try AA_MakeSwitch(MaxUpgradeBeforeMoving)
    try AA_MakeSwitch(AutoAbilityBox)
    try AA_MakeSwitch(ChallengeBox)

    AA_DarkInputs()
    AA_BuildStatusBar()
    for btn in [SettingsBtn, CustomMovementBtn, CustomPlacementBtn, DebugButton, SchedulerBtn, guideBtn]
        try AA_AddUnderline(btn)
    AA_AddTooltips()
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", aaMainUIHwnd, "Int", 33, "Int*", 2, "Int", 4)   ; rounded corners (Win 11)
    OnMessage(0x0200, AA_OnMouseMove)   ; WM_MOUSEMOVE: hover + tooltips
    AA_StyleTick()
    SetTimer(AA_StyleTick, 1000)
}

; ---- colours ------------------------------------------------------------------

AA_Shade(hex, amt) {
    c := Integer("0x" hex)
    r := Min(255, Max(0, ((c >> 16) & 0xFF) + amt))
    g := Min(255, Max(0, ((c >> 8) & 0xFF) + amt))
    b := Min(255, Max(0, (c & 0xFF) + amt))
    out := Format("{:02X}{:02X}{:02X}", r, g, b)
    return (out = "303030") ? "313131" : out      ; never the Roblox see-through colour
}

; ---- flat buttons -----------------------------------------------------------------

; Drop-in for gui.Add("Button", options, text): a Text control that looks like a flat button.
; Click / Visible / Text / Move work like on a button.
AA_Btn(g, options, text := "") {
    ctrl := g.Add("Text", options " +0x200 Center +Background" AA_BtnBg " c" uiTheme[1], text)
    AA_FlatBtns[ctrl.Hwnd] := {ctrl: ctrl, bg: AA_BtnBg, hover: AA_Shade(AA_BtnBg, 20), active: false, underline: ""}
    return ctrl
}

AA_BtnPaint(b, hovered := false) {
    color := b.active ? uiTheme[3] : (hovered ? b.hover : b.bg)
    try b.ctrl.Opt("+Background" color), b.ctrl.Redraw()
}

; Highlights the header button of the open panel (accent colour + underline).
AA_SetBtnActive(ctrl, on) {
    try {
        b := AA_FlatBtns[ctrl.Hwnd]
        b.active := on
        AA_BtnPaint(b)
        if IsObject(b.underline)
            b.underline.Visible := on
    }
}

AA_AddUnderline(ctrl) {
    ctrl.GetPos(&x, &y, &w, &h)
    u := aaMainUI.Add("Text", Format("x{} y{} w{} h2 Hidden +Background{}", x, y + h + 1, w, uiTheme[7]))
    AA_FlatBtns[ctrl.Hwnd].underline := u
}

; ---- hover + tooltips -------------------------------------------------------------

AA_OnMouseMove(wParam, lParam, msg, hwnd) {
    global AA_HoverHwnd, AA_TipHwnd
    global AA_FlatBtns
    if !IsSet(AA_FlatBtns)   ; the window is still being built (or a reload is under way) - nothing to hover yet
        return
    if (hwnd != AA_HoverHwnd) {
        AA_UnHover()
        if AA_FlatBtns.Has(hwnd) {
            AA_BtnPaint(AA_FlatBtns[hwnd], true)
            AA_HoverHwnd := hwnd
            SetTimer(AA_HoverWatch, 100)
        }
    }
    if (hwnd != AA_TipHwnd) {
        if AA_TipHwnd {
            ToolTip()
            AA_TipHwnd := 0
        }
        if AA_Tips.Has(hwnd) {
            AA_TipHwnd := hwnd
            SetTimer(AA_ShowTip, -600)
            SetTimer(AA_HoverWatch, 100)
        }
    }
}

AA_UnHover() {
    global AA_HoverHwnd
    if (AA_HoverHwnd && AA_FlatBtns.Has(AA_HoverHwnd))
        AA_BtnPaint(AA_FlatBtns[AA_HoverHwnd])
    AA_HoverHwnd := 0
}

; Mouse left the control (or the window) -> undo hover / hide tooltip.
AA_HoverWatch() {
    global AA_TipHwnd
    if !AA_GuiAlive() {
        SetTimer(AA_HoverWatch, 0)
        return
    }
    ctl := 0
    try MouseGetPos(, , , &ctl, 2)
    if (AA_HoverHwnd && ctl != AA_HoverHwnd)
        AA_UnHover()
    if (AA_TipHwnd && ctl != AA_TipHwnd) {
        ToolTip()
        AA_TipHwnd := 0
    }
    if (!AA_HoverHwnd && !AA_TipHwnd)
        SetTimer(AA_HoverWatch, 0)
}

AA_ShowTip() {
    if !AA_TipHwnd
        return
    ctl := 0
    try MouseGetPos(, , , &ctl, 2)
    if (ctl = AA_TipHwnd)
        ToolTip(AA_Tips[AA_TipHwnd])
}

AA_Tip(ctrl, text) {
    try AA_Tips[ctrl.Hwnd] := text
}

AA_AddTooltips() {
    try AA_Tip(SettingsBtn, "Webhook, private server, failsafes, keybinds, theme, import / export")
    try AA_Tip(CustomMovementBtn, "Record your own walk for a map and let the macro replay it")
    try AA_Tip(CustomPlacementBtn, "Your own unit placement spots per map (ON / OFF)")
    try AA_Tip(DebugButton, "Quick tests and the FindText / image pattern tester")
    try AA_Tip(SchedulerBtn, "Queue several modes - the macro switches between them on its own")
    try AA_Tip(guideBtn, "How to set up Roblox and the macro")
    try AA_Tip(placementSaveBtn, "Save all settings to Settings\Configuration.txt")
    try AA_Tip(PlacementSelection, "Which unit setup the macro uses (and shows in the cards)")
    try AA_Tip(PlacementPatternDropdown, "Shape the macro uses to try placement spots")
    try AA_Tip(PlaceSpeed, "How long the macro waits after each placement")
    try AA_Tip(LobbySleepTimer, "Wait in the lobby before starting the next run")
    try AA_Tip(MaharagaButton, "Switch between placement settings and Mahoraga settings")
    try AA_Tip(ConfirmButton, "Confirm the selected mode - needed before F2")
    try AA_Tip(AA_ThemeList, "Accent colour - applied after a restart")
    for sw in AA_Switches {
        try AA_Tip(sw.pill, "Click to switch ON / OFF")
        try AA_Tip(sw.label, "Click to switch ON / OFF")
    }
}

; ---- cards (instead of group boxes) -------------------------------------------------

; Lighter box with an accent line on top and a small title. panel = "" for the main window.
AA_Card(x, y, w, h, title, panel := "") {
    add := (type, opts, txt := "") => (panel = "" ? aaMainUI.Add(type, opts, txt) : AA_PanelPush(aaMainUI.Add(type, opts " Hidden", txt), panel))
    bg := add("Text", Format("x{} y{} w{} h{} +Background{}", x, y, w, h, AA_CardColor))
    add("Text", Format("x{} y{} w{} h2 +Background{}", x, y, w, uiTheme[3]))
    aaMainUI.SetFont("s8 Bold c" uiTheme[3], "Segoe UI")
    title := StrReplace(title, "&&", "&")
    add("Text", Format("x{} y{} w{} h13 +Background{} c{}", x + 10, y + 3, Min(w - 20, StrLen(title) * 7 + 12), AA_CardColor, uiTheme[3]), StrReplace(title, "&", "&&"))
    aaMainUI.SetFont("s9 Bold c" uiTheme[1], "Segoe UI")
    return bg
}

; ---- switches (instead of checkboxes) --------------------------------------------------

; The checkbox stays (hidden) and keeps holding the value, so every setting that reads
; .Value keeps working. panel = the panel the checkbox belongs to ("" = main window).
AA_MakeSwitch(cb, panel := "", handler := "") {
    cb.GetPos(&x, &y, &w, &h)
    text := cb.Text
    aaMainUI.SetFont("s8 Bold", "Segoe UI")
    pill := aaMainUI.Add("Text", Format("x{} y{} w30 h16 +0x200 Center +Background{} cFFFFFF", x, y, AA_OffColor), "OFF")
    aaMainUI.SetFont("s9 Bold c" uiTheme[1], "Segoe UI")
    labelW := Round(StrLen(text) * 6.8) + 4      ; sized to the text so it never covers the next control
    label := aaMainUI.Add("Text", Format("x{} y{} w{} h16 +0x200 +Background{} c{}", x + 34, y, labelW, AA_CardColor, uiTheme[1]), text)
    sw := {cb: cb, pill: pill, label: label, handler: handler, last: -1}
    pill.OnEvent("Click", AA_SwitchClick.Bind(sw))
    label.OnEvent("Click", AA_SwitchClick.Bind(sw))
    if (panel != "" && AA_Panels.Has(panel)) {
        ctrls := AA_Panels[panel]
        for i, c in ctrls {
            if (c = cb) {
                ctrls.RemoveAt(i)
                break
            }
        }
        ctrls.Push(pill), ctrls.Push(label)
        pill.Visible := label.Visible := (AA_ActivePanel = panel)
    }
    cb.Visible := false
    AA_Switches.Push(sw)
    AA_SwitchSync(sw)
}

AA_SwitchClick(sw, *) {
    sw.cb.Value := !sw.cb.Value
    AA_SwitchSync(sw)
    if IsObject(sw.handler)
        try sw.handler.Call(sw.cb)
}

AA_SwitchSync(sw) {
    try {                           ; [Fix] never fails if the window is being closed
        on := sw.cb.Value ? 1 : 0
        if (on = sw.last)
            return
        sw.last := on
        sw.pill.Text := on ? "ON" : "OFF"
        sw.pill.Opt("+Background" (on ? uiTheme[3] : AA_OffColor))
        sw.pill.Redraw()
    }
}

; ---- dark inputs ------------------------------------------------------------------

AA_DarkInputs() {
    for hwnd, ctrl in aaMainUI {
        try {
            type := ctrl.Type
            if !(type = "Edit" || type = "DDL" || type = "ComboBox" || type = "ListBox")
                continue
            try ctrl.Opt("+Background" AA_InputBg)
            try ctrl.SetFont("c" uiTheme[1])
            DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", (type = "ListBox" ? "DarkMode_Explorer" : "DarkMode_CFD"), "Ptr", 0)
        }
    }
}

; ---- status bar (title row) -------------------------------------------------------------

AA_BuildStatusBar() {
    global AA_StatusDot, AA_StatusText
    aaMainUI.SetFont("s12 Bold c9A9A9A", "Segoe UI")
    AA_StatusDot := aaMainUI.Add("Text", Format("x330 y4 w16 h20 +Background{} c9A9A9A", uiTheme[2]), "●")
    aaMainUI.SetFont("s9 Bold c" uiTheme[1], "Segoe UI")
    AA_StatusText := aaMainUI.Add("Text", Format("x348 y9 w300 h17 +Background{} c{}", uiTheme[2], uiTheme[1]), "Stopped")   ; [Custom placement] narrower: room for the new tab
}

; [Fix] true while the main window still exists (timers stop once it is closed)
AA_GuiAlive() {
    return aaMainUIHwnd && DllCall("IsWindow", "Ptr", aaMainUIHwnd)
}

AA_StyleTick() {
    global AA_RunStart, AA_WasRunning
    if !AA_GuiAlive() {             ; [Fix] window closed -> stop, instead of "The control is destroyed"
        SetTimer(AA_StyleTick, 0)
        return
    }
    for sw in AA_Switches
        AA_SwitchSync(sw)
    try CP_OverlayGuard()           ; [Custom placement] no circles on screen while the macro runs
    if !IsObject(AA_StatusText)
        return
    running := false
    try running := MacroLoopState.Active
    if (running && !AA_WasRunning)
        AA_RunStart := A_TickCount
    AA_WasRunning := running
    paused := running && A_IsPaused
    state := !running ? "Stopped" : (paused ? "Paused" : "Running")
    color := !running ? "9A9A9A" : (paused ? "E3B341" : "3FB950")
    runTime := ""
    if running {
        s := (A_TickCount - AA_RunStart) // 1000
        runTime := Format("  {:02}:{:02}:{:02}", s // 3600, Mod(s // 60, 60), Mod(s, 60))
    }
    text := state "  " AA_ModeSummary() runTime   ; wins / losses are in the Stats box
    try {
        if (AA_StatusText.Value != text)
            AA_StatusText.Value := text
        AA_StatusDot.SetFont("c" color)
    }
}

AA_ModeSummary() {
    if !confirmClicked
        return "No mode confirmed"
    try {
        if (inChallengeMode)          ; [Profile log] an Auto Challenge run, not the confirmed mode
            return "Challenge (then " ModeDropdown.Text ")"
    }
    m := ModeDropdown.Text
    try {
        switch m {
            case "Story":           return m " · " StoryDropdown.Text " " StoryActDropdown.Text
            case "Legend":          return m " · " LegendDropDown.Text " " LegendActDropdown.Text
            case "Raid":            return m " · " RaidDropdown.Text " " RaidActDropdown.Text
            case "Portal":          return m " · " PortalDropdown.Text
            case "Contract":        return m " · " ContractPageDropdown.Text
            case "Infinity Castle": return m " · " InfinityCastleDropdown.Text
        }
    }
    return m
}

; ---- theme picker (Settings panel) ----------------------------------------------------------

AA_SaveTheme(ctrl, *) {
    name := ctrl.Text
    try {
        if FileExist(AA_ThemeFile)
            FileDelete(AA_ThemeFile)
        FileAppend(name, AA_ThemeFile, "UTF-8")
    } catch as err {
        AddToLog("Could not save the theme: " err.Message)
        return
    }
    running := false
    try running := MacroLoopState.Active
    if running {
        AddToLog("Theme " name " saved - it is applied the next time the macro starts")
        return
    }
    if (MsgBox("Theme " name " saved.`nRestart the macro window now to apply it?", "Theme", 0x1024) = "Yes")
        Reload()
}
