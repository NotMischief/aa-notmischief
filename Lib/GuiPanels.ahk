#Requires AutoHotkey v2.0

; ============================================================================
;  GuiPanels.ahk 


global AA_Panels := Map()      ; panel name -> controls shown only while that panel is open
global AA_ActivePanel := ""    ; "" = unit cards shown

; Unit controls of every placement profile (hidden while the panel is open)
global AA_UnitProfiles := [
    ["Enabled", "Placement", "Priority", "upgradeEnabled", "upgradeLimitEnabled", "UpgradeLimit"],
    ["ChallengeEnabled", "ChallengePlacement", "ChallengePriority", "challengeUpgradeEnabled", "challengeUpgradeLimitEnabled", "ChallengeUpgradeLimit"],
    ["ContractEnabled", "ContractPlacement", "ContractPriority", "contractUpgradeEnabled", "contractUpgradeLimitEnabled", "ContractUpgradeLimit"],
    ["DungeonEnabled", "DungeonPlacement", "DungeonPriority", "dungeonUpgradeEnabled", "dungeonUpgradeLimitEnabled", "DungeonUpgradeLimit"],
    ["RaidEnabled", "RaidPlacement", "RaidPriority", "raidUpgradeEnabled", "raidUpgradeLimitEnabled", "RaidUpgradeLimit"],
    ["EventEnabled", "EventPlacement", "EventPriority", "eventUpgradeEnabled", "eventUpgradeLimitEnabled", "EventUpgradeLimit"],
    ["SummerEnabled", "SummerPlacement", "SummerPriority", "summerUpgradeEnabled", "summerUpgradeLimitEnabled", "SummerUpgradeLimit"]
]

; ---- show / hide ---------------------------------------------------------------

AA_ToggleSettingsPanel(*) {
    AA_TogglePanel("Settings")
}

; Opens the named panel, or closes it (back to the unit cards) if it is already open.
AA_TogglePanel(name) {
    AA_ShowPanel(AA_ActivePanel = name ? "" : name)
}

; name = "" shows the unit cards again.
AA_ShowPanel(name) {
    global AA_ActivePanel
    for panelName, ctrls in AA_Panels {
        show := (panelName = name)
        for ctrl in ctrls
            ctrl.Visible := show
    }
    AA_ActivePanel := name
    AA_SetUnitCardsVisible(name = "")
    ; [Modern GUI] the open panel's button is highlighted (accent + underline) instead of reading "Back"
    try AA_SetBtnActive(settingsBtn, name = "Settings")
    try AA_SetBtnActive(CustomMovementBtn, name = "Movement")
    try AA_SetBtnActive(CustomPlacementBtn, name = "Placement")   ; [Custom placement]
    try AA_SetBtnActive(DebugButton, name = "Debug")
    try AA_SetBtnActive(SchedulerBtn, name = "Scheduler")
    try AA_SetBtnActive(EditRoute, name = "Advanced")
    try AA_SetBtnActive(guideBtn, name = "Guide")   ; [Guide panel]
    try AA_SetBtnActive(EditCardPrio, name = "Cards")   ; [Card picker]
    if (name = "Cards")
        try CardPick_OnPanelOpen()
    if (name = "Guide")
        try AA_GuideOnOpen()
    if (name = "Scheduler")
        try Sched_OnPanelOpen()
    if (name = "Placement") {
        try CP_RefreshPanel()        ; also shows the selected map's spots on Roblox
    } else {
        try CP_OverlayHide()
    }
    if (name = "Movement")
        try CM_RefreshPanel()
}

AA_SetUnitCardsVisible(visible) {
    global UnitData
    for unit in UnitData {
        for propName, ctrl in unit.OwnProps() {
            if IsObject(ctrl)
                ctrl.Visible := visible
        }
    }
    if (visible)
        ToggleMode()                  ; shows only the selected placement profile, as before
    else
        AA_HideUnitProfileControls()
}

AA_HideUnitProfileControls() {
    global AA_UnitProfiles
    loop 6 {
        i := A_Index
        for names in AA_UnitProfiles {
            for name in names {
                ctrlName := name i
                try %ctrlName%.Visible := false
            }
        }
    }
}

; Adds a control to a panel (created hidden).
; [Modern GUI] GroupBox -> card, Button -> flat button, Text / CheckBox get the card colour.
AA_PanelAdd(type, options, text := "", panel := "Settings") {
    global aaMainUI
    if (type = "GroupBox") {
        RegExMatch(options, "x(\d+)\s+y(\d+)\s+w(\d+)\s+h(\d+)", &m)
        return AA_Card(Integer(m[1]), Integer(m[2]), Integer(m[3]), Integer(m[4]), text, panel)
    }
    if (type = "Button")
        return AA_PanelPush(AA_Btn(aaMainUI, options " Hidden", text), panel)
    if ((type = "Text" || type = "CheckBox") && !InStr(options, "Background"))
        options .= " +Background" AA_CardColor
    return AA_PanelPush(aaMainUI.Add(type, options " Hidden", text), panel)
}

AA_PanelPush(ctrl, panel) {
    global AA_Panels
    if !AA_Panels.Has(panel)
        AA_Panels[panel] := []
    AA_Panels[panel].Push(ctrl)
    return ctrl
}

; ---- construction (same area as the unit cards: x808-1358, y85-381) ----------------

AA_BuildSettingsPanel() {
    LoadKeybindSettings()   ; read Settings\Keybinds.txt so the boxes show the saved keys
                            ; (GameMango.ahk loads them again and binds the hotkeys, as before)
    t := uiTheme
    aaMainUI.SetFont("s9 Bold c" t[1], "Segoe UI")

    ; Section frames - separate boxes, no overlap (x808-1358, y85-381)
    AA_PanelAdd("GroupBox", "x808 y85 w550 h66 +Center c" t[3], "Webhook Settings")
    AA_PanelAdd("GroupBox", "x808 y155 w550 h66 +Center c" t[3], "Reconnection Settings")
    AA_PanelAdd("GroupBox", "x808 y225 w190 h156 +Center c" t[3], "Keybind Settings")
    AA_PanelAdd("GroupBox", "x1003 y225 w160 h156 +Center c" t[3], "UI Navigation")
    AA_PanelAdd("GroupBox", "x1168 y225 w190 h156 +Center c" t[3], "Import/Export")

    ; --- Webhook
    global WebhookEnabledBox := AA_PanelAdd("CheckBox", "x822 y106 w150 h18 c" t[1] " Checked", "Webhook Enabled")
    WebhookEnabledBox.OnEvent("Click", AA_SaveWebhookEnabled)
    global SendActivityLogsBox := AA_PanelAdd("CheckBox", "x822 y128 w150 h18 c" t[1], "Send Process")
    AA_PanelAdd("Text", "x980 y106 w62 h18 c" t[1], "URL")
    AA_PanelAdd("Text", "x980 y129 w62 h18 c" t[1], "User ID")
    global WebhookURLBox := AA_PanelAdd("Edit", "x1044 y103 w232 h20 c" t[6])
    global DiscordUserIDBox := AA_PanelAdd("Edit", "x1044 y126 w232 h20 c" t[6])
    btn := AA_PanelAdd("Button", "x1284 y103 w64 h22", "Save")
    btn.OnEvent("Click", (*) => SaveWebhookSettings())

    ; --- Reconnection: private server + failsafe timeouts
    AA_PanelAdd("Text", "x822 y177 w145 h18 c" t[1], "Private Server Link")
    global PsLinkBox := AA_PanelAdd("Edit", "x972 y174 w220 h20 c" t[6])
    btn := AA_PanelAdd("Button", "x1198 y173 w60 h22", "Save")
    btn.OnEvent("Click", SavePsSettings)
    btn := AA_PanelAdd("Button", "x1264 y173 w84 h22", "Test Link")
    btn.OnEvent("Click", AA_TestPrivateServerLink)

    global FailsafeEnabledBox := AA_PanelAdd("CheckBox", "x822 y200 w145 h16 c" t[1] " Checked", "Enable Failsafes")
    AA_PanelAdd("Text", "x972 y201 w62 h16 c" t[1], "Load (s)")
    global FailsafeLoadBox := AA_PanelAdd("Edit", "x1036 y198 w40 h20 Number c" t[6])
    AA_PanelAdd("Text", "x1082 y201 w70 h16 c" t[1], "Entry (s)")
    global FailsafeEntranceBox := AA_PanelAdd("Edit", "x1152 y198 w40 h20 Number c" t[6])
    btn := AA_PanelAdd("Button", "x1198 y197 w60 h20", "Save")
    btn.OnEvent("Click", AA_SaveFailsafeSettings)

    ; --- Keybinds
    AA_PanelAdd("Text", "x822 y248 w122 h18 c" t[1], "Position Roblox:")
    global F1Box := AA_PanelAdd("Edit", "x948 y245 w42 h20 c" t[6], F1Key)
    AA_PanelAdd("Text", "x822 y276 w122 h18 c" t[1], "Start Macro:")
    global F2Box := AA_PanelAdd("Edit", "x948 y273 w42 h20 c" t[6], F2Key)
    AA_PanelAdd("Text", "x822 y304 w122 h18 c" t[1], "Stop Macro:")
    global F3Box := AA_PanelAdd("Edit", "x948 y301 w42 h20 c" t[6], F3Key)
    AA_PanelAdd("Text", "x822 y332 w122 h18 c" t[1], "Pause Macro:")
    global F4Box := AA_PanelAdd("Edit", "x948 y329 w42 h20 c" t[6], F4Key)
    btn := AA_PanelAdd("Button", "x873 y354 w60 h22", "Save")
    btn.OnEvent("Click", SaveKeybindSettings)

    ; --- UI navigation key
    AA_PanelAdd("Text", "x1018 y248 w135 h18 c" t[1], "Navigation Key")
    global UINavBox := AA_PanelAdd("Edit", "x1018 y272 w30 h20 c" t[6], "\")
    btn := AA_PanelAdd("Button", "x1056 y271 w64 h22", "Save")
    btn.OnEvent("Click", SaveUINavSettings)

    ; --- [Modern GUI] theme (accent colour), saved to Settings\Theme.txt, applied after a restart
    AA_PanelAdd("Text", "x1018 y306 w135 h18 c" t[1], "Theme")
    aaMainUI.SetFont("s9 norm c" t[6])
    global AA_ThemeList := AA_PanelAdd("DropDownList", "x1018 y326 w130 r6", AA_ThemeOrder)
    AA_ThemeList.Choose(AA_ThemeName())
    AA_ThemeList.OnEvent("Change", AA_SaveTheme)
    aaMainUI.SetFont("s9 Bold c" t[1])

    ; --- Import / Export
    AA_PanelAdd("Text", "x1182 y247 w165 h18 c" t[1], "Unit Configuration")
    btn := AA_PanelAdd("Button", "x1182 y268 w80 h22", "Import")
    btn.OnEvent("Click", AA_ImportUnitConfig)
    btn := AA_PanelAdd("Button", "x1268 y268 w80 h22", "Export")
    btn.OnEvent("Click", AA_ExportUnitConfig)
    AA_PanelAdd("Text", "x1182 y302 w165 h18 c" t[1], "Config Code")
    btn := AA_PanelAdd("Button", "x1182 y323 w80 h22", "Import")
    btn.OnEvent("Click", AA_ImportConfigCode)
    btn := AA_PanelAdd("Button", "x1268 y323 w80 h22", "Export")
    btn.OnEvent("Click", ExportConfigCode)
    aaMainUI.SetFont("s7 norm c" t[1])
    AA_PanelAdd("Text", "x1182 y352 w166 h26 c" t[1], "Unit import/export uses the placement profile that is shown.")
}

; ---- Advanced Settings panel ([Advanced panel] dungeon route / curses / shrines) ----------
; Replaces the three "Route Priority", "Avoided Curses", "Avoided Shrines" windows. Same
; dropdowns, same handlers (OnRouteDropDownChange, ...), same save file (DungeonConfig.ahk):
; the dropdowns go into routeDropDowns / curseDropDowns / shrineDropDowns as before.

AA_BuildAdvancedPanel() {
    global routeDropDowns, curseDropDowns, shrineDropDowns
    t := uiTheme
    P := "Advanced"
    aaMainUI.SetFont("s9 Bold c" t[1], "Segoe UI")
    AA_PanelAdd("GroupBox", "x808 y85 w178 h296", "Route Priority", P)
    AA_PanelAdd("GroupBox", "x994 y85 w178 h296", "Avoided Curses", P)
    AA_PanelAdd("GroupBox", "x1180 y85 w178 h296", "Avoided Shrines", P)
    cols := [[808, roomOptions, routeDropDowns, OnRouteDropDownChange, "Rooms in the order the macro prefers them."],
             [994, curseOptions, curseDropDowns, OnCurseDropDownChange, "Curses to avoid. None = slot not used."],
             [1180, shrineOptions, shrineDropDowns, OnShrineDropDownChange, "Shrines to reject. None = slot not used."]]
    for col in cols {
        x := col[1], opts := col[2], list := col[3], handler := col[4]
        loop opts.Length {
            y := 106 + (A_Index - 1) * 28
            aaMainUI.SetFont("s9 Bold c" t[1])
            AA_PanelAdd("Text", Format("x{} y{} w18 h20 +0x200 c{}", x + 12, y, t[1]), A_Index ".", P)
            aaMainUI.SetFont("s9 norm c" t[6])
            dd := AA_PanelAdd("DropDownList", Format("x{} y{} w134 Choose1", x + 32, y), opts, P)
            list.Push(dd)
            AttachDropDownEvent(dd, A_Index, handler)
        }
        aaMainUI.SetFont("s8 norm c" t[1])
        AA_PanelAdd("Text", Format("x{} y{} w154 h32 c{}", x + 12, 106 + opts.Length * 28 + 6, t[1]), col[5], P)
    }
}

; ---- Debug panel ([Debug panel] replaces the old Debug popup) --------------------

AA_BuildDebugPanel() {
    t := uiTheme
    P := "Debug"
    aaMainUI.SetFont("s9 Bold c" t[1], "Segoe UI")
    AA_PanelAdd("GroupBox", "x808 y85 w550 h120 +Center c" t[3], "Quick Test", P)
    AA_PanelAdd("GroupBox", "x808 y209 w550 h172 +Center c" t[3], "Pattern Tester (FindText / Image Search)", P)
    DT_BuildQuickTest(P)     ; Lib\Tools\DetectionTester.ahk - lobby, unit placed, end screen, cards, resolution
    DT_BuildSection(P)       ; Lib\Tools\DetectionTester.ahk - test / override one pattern
}

; Fills the panel from the existing settings files. Runs once at startup,
; after readInSettings(), before the window is shown.
AA_LoadPanelSettings() {
    global FW_FailsafesEnabled, FW_LoadTimeoutMs, FW_EntranceTimeoutMs
    try WebhookSettings()      ; webhook URL, Discord ID, Send Process
    try {
        if FileExist("Settings\PrivateServer.txt")
            PsLinkBox.Value := FileRead("Settings\PrivateServer.txt", "UTF-8")
        if FileExist("Settings\UINavigation.txt")
            UINavBox.Value := FileRead("Settings\UINavigation.txt", "UTF-8")
    }
    WebhookEnabledBox.Value := AA_WebhookEnabled() ? 1 : 0

    AA_LoadFrameworkOverrides()          ; Settings\Framework.txt -> FW_* globals
    FailsafeEnabledBox.Value := FW_FailsafesEnabled ? 1 : 0
    FailsafeLoadBox.Value := FW_LoadTimeoutMs // 1000
    FailsafeEntranceBox.Value := FW_EntranceTimeoutMs // 1000
}

; ============================================================================
;  [Stats] Wins / Losses / Win % box at the bottom left of the GUI.
;  Shows the same counters the result webhook uses (Wins, loss - counted in
;  GameMango.ahk when a stage ends). Display only: a 1-second timer copies the
;  numbers into the labels; it sends no input and changes no macro state.
;  Counts are for this session (they start at 0 when the script starts/reloads).
; ============================================================================

AA_BuildStatsBox() {
    ; [Modern GUI] card like Upgrade / Auto Settings next to it (below the Roblox window)
    t := uiTheme
    AA_Card(105, 642, 210, 52, "Stats")
    aaMainUI.SetFont("s9 Bold c" t[1], "Segoe UI")
    global StatsWinsText := aaMainUI.Add("Text", "x115 y658 w90 h16 +Background" AA_CardColor " c" t[1], "Wins: 0")
    global StatsLossText := aaMainUI.Add("Text", "x210 y658 w100 h16 +Background" AA_CardColor " c" t[1], "Losses: 0")
    global StatsRateText := aaMainUI.Add("Text", "x115 y676 w190 h16 +Background" AA_CardColor " c" t[1], "Win %: 0.0%")
    SetTimer(AA_UpdateStats, 1000)
}

AA_UpdateStats() {
    static last := ""
    if !AA_GuiAlive() {             ; [Fix] window closed -> stop the timer
        SetTimer(AA_UpdateStats, 0)
        return
    }
    key := Wins "|" loss
    if (key = last)
        return
    last := key
    total := Wins + loss
    try {
        StatsWinsText.Value := "Wins: " Wins
        StatsLossText.Value := "Losses: " loss
        StatsRateText.Value := "Win %: " (total ? Format("{:.1f}", Wins / total * 100) : "0.0") "%"
    }
}

