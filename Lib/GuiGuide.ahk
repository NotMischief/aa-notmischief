#Requires AutoHotkey v2.0

; ============================================================================
;  GuiGuide.ahk  -  [Guide panel] the setup guide as a panel in the main window
;  (Guide button), in place of the old popup. 5 short pages with Back / Next:
;    1  your PC + Roblox window (live checks: resolution, display scale, windowed)
;    2  Roblox settings (graphics Manual + 1 bar, not Click to Move, UI navigation off)
;    3  Anime Adventures settings (upgrade UI auto-open, on the left)
;    4  starting the macro + your hotkeys
;    5  what each tab does
;  Uses the existing images in Images\ (aasettings, graphics1, Clicktomove).
;  Functions only; built hidden at start-up by GUI.ahk (AA_BuildGuidePanel).
; ============================================================================

global AA_GuidePages := []        ; controls of each page
global AA_GuidePage := 1
global AA_GuideTitle := "", AA_GuideBack := "", AA_GuideNext := ""
global AA_GuideChecks := Map()    ; page 1: name -> {value, pill}
global AA_GuideTitles := ["Your PC and the Roblox window", "Roblox settings  (Esc > Settings)",
    "Anime Adventures settings  (in-game settings menu)", "Start the macro", "What the tabs do"]

AA_BuildGuidePanel() {
    global AA_GuidePages, AA_GuideTitle, AA_GuideBack, AA_GuideNext
    t := uiTheme
    panelName := "Guide"   ; (not "P": AutoHotkey names are case-insensitive, P = p)
    img := A_ScriptDir "\Images\"
    AA_GuidePages := [[], [], [], [], []]
    ; helpers: add a control to a page (and return it)
    add(page, type, opts, txt := "") {
        c := AA_PanelAdd(type, opts, txt, panelName)
        AA_GuidePages[page].Push(c)
        return c
    }
    text(page, y, h, s, bold := false) {
        aaMainUI.SetFont("s9 " (bold ? "Bold" : "norm") " c" t[1])
        return add(page, "Text", Format("x822 y{} w525 h{} c{}", y, h, t[1]), s)
    }
    note(page, y, h, s) {
        aaMainUI.SetFont("s8 norm c9A9A9A")
        return add(page, "Text", Format("x822 y{} w525 h{} c9A9A9A", y, h), s)
    }

    aaMainUI.SetFont("s9 Bold c" t[1], "Segoe UI")
    AA_PanelAdd("GroupBox", "x808 y85 w550 h296 +Center c" t[3], "Setup Guide", panelName)
    aaMainUI.SetFont("s10 Bold c" t[3], "Segoe UI")
    AA_GuideTitle := AA_PanelAdd("Text", "x822 y106 w525 h20 c" t[3], "", panelName)

    ; ---- page 1: PC + Roblox window (live checks) ----
    rows := [["res", "Screen resolution 1920 x 1080"], ["dpi", "Windows display scale 100 %"], ["rblx", "Roblox open, in windowed mode (not fullscreen)"]]
    for i, r in rows {
        y := 134 + (i - 1) * 28
        aaMainUI.SetFont("s9 Bold c" t[1])
        add(1, "Text", Format("x822 y{} w300 h20 +0x200 c{}", y, t[1]), r[2])
        aaMainUI.SetFont("s9 norm c9A9A9A")
        valueCtrl := add(1, "Text", Format("x1126 y{} w110 h20 +0x200 c9A9A9A", y), "")
        aaMainUI.SetFont("s8 Bold cFFFFFF")
        pillCtrl := add(1, "Text", Format("x1242 y{} w106 h20 Center +0x200 cFFFFFF +Background{}", y, AA_OffColor), "")
        AA_GuideChecks[r[1]] := {value: valueCtrl, pill: pillCtrl}
    }
    note(1, 222, 70, "The macro clicks fixed spots inside the Roblox window, so the screen must be 1920 x 1080 at "
        . "100 % scale (Windows Settings > System > Display) and Roblox must be on that screen. "
        . "Press " F1Key " to snap Roblox into place and don't move or resize it while the macro runs. "
        . "Fullscreen is switched to windowed for you.")
    btn := AA_PanelAdd("Button", "x1228 y300 w120 h22", "Check again", panelName)
    btn.OnEvent("Click", (*) => AA_GuideRunChecks())
    AA_GuidePages[1].Push(btn)

    ; ---- page 2: Roblox settings ----
    text(2, 132, 18, "Graphics Mode: Manual    Graphics Quality: 1 bar (lowest)", true)
    add(2, "Picture", "x822 y153 w525 h-1", img "graphics1.png")
    text(2, 196, 18, "Movement Mode: Default (keyboard) - NOT Click to Move", true)
    add(2, "Picture", "x822 y217 w525 h-1", img "Clicktomove.png")
    note(2, 256, 16, "Change the setting shown above away from Click to Move - otherwise your character walks to where units are placed.")
    text(2, 278, 18, "UI Navigation: off", true)
    note(2, 297, 30, "If a white selection box appears around buttons, press \ (backslash) in Roblox to turn UI navigation off.")

    ; ---- page 3: Anime Adventures settings ----
    add(3, "Picture", "x822 y134 w339 h104", img "aasettings.png")
    aaMainUI.SetFont("s9 Bold c" t[1])
    add(3, "Text", Format("x1172 y146 w176 h36 c{}", t[1]), "Disable Auto-Open Upgrade UI:  OFF")
    add(3, "Text", Format("x1172 y196 w176 h36 c{}", t[1]), "Show Upgrade UI on left:  ON")
    note(3, 250, 48, "After placing a unit the macro looks at the upgrade panel on the LEFT to confirm the unit was placed "
        . "and to upgrade it - so that panel has to open by itself, on the left side.")

    ; ---- page 4: start ----
    steps := "1.  Pick the mode, map and act at the top, then press Confirm.`n"
        . "2.  Set your units in the cards: tick a slot, how many to place, upgrade priority.`n"
        . "     Placement Profiles picks which set is used (Auto Challenge runs use Challenge).`n"
        . "3.  Avoid hill-only units if you can - placement spots may not fit them.`n"
        . "4.  Rejoin Anime Adventures so the camera is reset, and stay in the lobby.`n"
        . "5.  Press " F2Key " to start."
    text(4, 132, 112, steps)
    aaMainUI.SetFont("s9 Bold c" t[3])
    add(4, "Text", Format("x822 y254 w525 h18 c{}", t[3]), "Hotkeys")
    text(4, 274, 56, F1Key " = fix the Roblox window     " F2Key " = start     " F3Key " = stop (reload)     " F4Key " = pause / resume`n"
        . "F5 = save your Fool's Hunt hotbar (in the lobby)     F6 = unit types (Ground / Hill / Hybrid)     F8 = record mode`n"
        . "Change F1-F4 in Settings > Keybinds.")

    ; ---- page 5: tabs ----
    tabs := "Custom Placement - your own unit spots per map, ON / OFF.`n"
        . "Custom Map - record your own walk for a map; the macro replays it.`n"
        . "Scheduler - queue several modes; the macro switches between them on its own.`n"
        . "Debug - test detection (lobby, unit placed, end screen, cards) and fix patterns.`n"
        . "Settings - webhook, private server, failsafes, keybinds, theme, import / export.`n"
        . "Console 'Open log' - the full log file, handy when something goes wrong."
    text(5, 132, 130, tabs)

    ; ---- navigation (all pages) ----
    AA_GuideBack := AA_PanelAdd("Button", "x822 y350 w110 h22", "< Back", panelName)
    AA_GuideBack.OnEvent("Click", (*) => AA_GuideShowPage(AA_GuidePage - 1))
    AA_GuideNext := AA_PanelAdd("Button", "x1238 y350 w110 h22", "Next >", panelName)
    AA_GuideNext.OnEvent("Click", (*) => (AA_GuidePage >= AA_GuidePages.Length ? AA_ShowPanel("") : AA_GuideShowPage(AA_GuidePage + 1)))
}

; Called by AA_ShowPanel when the Guide opens (it shows every control first).
AA_GuideOnOpen() {
    AA_GuideRunChecks()
    AA_GuideShowPage(AA_GuidePage)
}

AA_GuideShowPage(n) {
    global AA_GuidePage
    n := Max(1, Min(AA_GuidePages.Length, n))
    AA_GuidePage := n
    for i, ctrls in AA_GuidePages
        for c in ctrls
            c.Visible := (i = n)
    AA_GuideTitle.Value := n " / " AA_GuidePages.Length "   " AA_GuideTitles[n]
    AA_GuideBack.Visible := (n > 1)
    AA_GuideNext.Text := (n = AA_GuidePages.Length) ? "Done" : "Next >"
}

; Page 1 checks: same rules the macro uses at start-up (GetScreenInfoStartUp / sizeDown).
AA_GuideRunChecks() {
    w := A_ScreenWidth, h := A_ScreenHeight
    AA_GuideSet("res", w " x " h, (w = 1920 && h = 1080))
    zoom := 100
    try zoom := Round(DllCall("user32\GetDpiForSystem", "UInt") / 96 * 100)
    AA_GuideSet("dpi", zoom " %", zoom = 100)
    state := "", ok := false
    try {
        if !WinExist(rblxID)
            state := "not open"
        else if RobloxIsFullscreen()
            state := "fullscreen"
        else
            state := "windowed", ok := true
    }
    AA_GuideSet("rblx", state, ok, state = "not open" ? "OPEN IT" : "")
}

AA_GuideSet(name, value, ok, badText := "") {
    c := AA_GuideChecks[name]
    c.value.Value := value
    c.pill.Text := ok ? "OK" : (badText != "" ? badText : "CHANGE")
    c.pill.Opt("+Background" (ok ? "2E8B57" : "B03A2E"))
    c.pill.Redraw()
}
