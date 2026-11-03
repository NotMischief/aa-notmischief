#Requires AutoHotkey v2.0

; ============================================================================
;  DetectionTester.ahk  -  [Detection tester] Debug panel tool to TEST the
;  macro's FindText patterns and ImageSearch images, and to replace (override)
;  one that no longer matches after a game update.
; ----------------------------------------------------------------------------
;  * Names come from Lib\Tools\Image.ahk (FindText: "|<...>..." strings;
;    images: .png/.jpg/.bmp paths). Image.ahk itself is never changed.
;  * Test: runs one FindText (through FT(), so the search area follows the
;    Roblox window like everywhere else) or one ImageSearch with the region and
;    tolerance you enter ("From code" fills them from where the macro uses that
;    name), shows found / not found and flashes a red box where it matched.
;    It only looks at the screen - no clicks, no keys.
;  * Override: "Save Override" stores your new pattern / image in
;    Settings\Detection\Overrides.txt (images are copied to
;    Settings\Detection\Images\) and applies it right away; it is re-applied at
;    every start. "Reset to Default" removes it. Only the pattern / image
;    changes - search areas and tolerances in the macro's code stay as they are.
;  * No overrides file = the macro uses exactly the original Image.ahk values.
;  * Quick Test (top of the Debug panel): one-click checks that look for exactly
;    what the macro looks for in a situation - lobby, unit placed, end screen /
;    game over, active cards, screen resolution - using the same patterns (incl.
;    your overrides), search areas and tolerances as the code. Read-only too.
;  Included before GUI.ahk (Main.ahk); DT_Init() runs once at GUI start-up.
; ============================================================================

global DT_Dir := A_ScriptDir "\Settings\Detection"
global DT_OverrideFile := A_ScriptDir "\Settings\Detection\Overrides.txt"
global DT_Names := Map("FindText", [], "Image", [])
global DT_Default := Map()       ; name -> original value (captured at start-up, before overrides)
global DT_Override := Map()      ; name -> saved override value
global DT_Usage := ""            ; name -> {count, region, tol} from scanning the code (built on first use)
global DT_SkipNames := Map("Discord", 1, "Minimize", 1, "Exitbutton", 1)   ; GUI icons, not detection
global DT_TypeList := "", DT_NameList := "", DT_StateText := "", DT_ValueEdit := "", DT_ResultText := ""
global DT_X1 := "", DT_Y1 := "", DT_X2 := "", DT_Y2 := "", DT_Tol1 := "", DT_Tol0 := ""
global DT_PresetList := "", DT_PresetText := ""
global DT_Presets := ["Check For Lobby", "Unit Successfully Placed", "Test Game Over / End Screen",
    "Check Active Cards", "Test screen resolution / DPI", "Custom FindText / Image (Pattern Tester below)"]

; ---- start-up ---------------------------------------------------------------

DT_Init() {
    global DT_Names, DT_Default
    try {
        src := FileRead(A_ScriptDir "\Lib\Tools\Image.ahk", "UTF-8")
    } catch {
        return
    }
    ft := [], img := []
    for line in StrSplit(src, "`n", "`r") {
        if !RegExMatch(line, '^\s*(?:global\s+)?([A-Za-z_]\w*)\s*:=\s*"([^"]*)"', &m)
            continue
        name := m[1]
        if (DT_SkipNames.Has(name) || DT_Default.Has(name))
            continue
        try {
            val := %name%                       ; runtime value (exactly what the macro uses)
        } catch {
            continue
        }
        if (SubStr(val, 1, 2) = "|<") {
            ft.Push(name)
        } else if RegExMatch(val, "i)\.(png|jpe?g|bmp)$") {
            img.Push(name)
        } else {
            continue
        }
        DT_Default[name] := val
    }
    DT_Names["FindText"] := DT_Sorted(ft)
    DT_Names["Image"] := DT_Sorted(img)
    DT_LoadOverrides()
}

DT_Sorted(arr) {
    if !arr.Length
        return arr
    text := ""
    for v in arr
        text .= v "`n"
    out := []
    for v in StrSplit(Sort(RTrim(text, "`n")), "`n")
        out.Push(v)
    return out
}

DT_LoadOverrides() {
    global DT_Override
    if !FileExist(DT_OverrideFile)
        return
    try {
        content := FileRead(DT_OverrideFile, "UTF-8")
    } catch {
        return
    }
    applied := 0
    for line in StrSplit(content, "`n", "`r") {
        if (Trim(line) = "" || SubStr(Trim(line), 1, 1) = ";")
            continue
        p := StrSplit(line, "=", , 2)
        if (p.Length < 2 || !DT_Default.Has(Trim(p[1])))
            continue
        name := Trim(p[1]), val := Trim(p[2])
        if (DT_Check(name, val) != "")
            continue
        DT_Override[name] := val
        DT_Apply(name, val)
        applied++
    }
    if applied
        AddToLog("Detection overrides active: " applied " (Debug > Detection Tester)")
}

; Sets the global pattern variable and updates the two start-up maps in Image.ahk
; (textCards, roomTexts) that copied pattern values when they were built.
DT_Apply(name, newVal) {
    oldVal := %name%
    DT_SetGlobal(name, newVal)
    for mapName in ["textCards", "roomTexts"] {
        try {
            m := %mapName%
            for k, v in m
                if (v == oldVal)
                    m[k] := newVal
        }
    }
}

DT_SetGlobal(name, value) {
    global
    %name% := value
}

DT_TypeOf(name) {
    for n in DT_Names["Image"]
        if (n = name)
            return "Image"
    return "FindText"
}

; "" = valid, otherwise the reason
DT_Check(name, val) {
    if (DT_TypeOf(name) = "FindText") {
        if !(SubStr(val, 1, 2) = "|<" && InStr(val, "$"))
            return "a FindText pattern starts with |< and contains $"
        return ""
    }
    if !RegExMatch(val, "i)\.(png|jpe?g|bmp)$")
        return "the image must be a .png, .jpg or .bmp file"
    if !FileExist(val)
        return "image file not found: " val
    return ""
}

; Accepts a whole line copied from the FindText tool (Text:="|<...>...") too.
DT_Normalize(type, val) {
    val := Trim(val)
    if (type = "FindText" && RegExMatch(val, '"(\|<[^"]*)"', &m))
        val := m[1]
    return Trim(val, " `t`r`n`"")
}

; ---- where the macro uses each name (for "From code") -------------------------

DT_ScanUsage() {
    global DT_Usage
    DT_Usage := Map()
    loop files A_ScriptDir "\Lib\*.ahk", "R" {
        if RegExMatch(A_LoopFileFullPath, "i)\\(OCR-main|AHKv2-Gdip-master|Discord-Webhook-master)\\|\\Tools\\(FindText|Image|DetectionTester)\.ahk$")
            continue
        try {
            src := FileRead(A_LoopFileFullPath, "UTF-8")
        } catch {
            continue
        }
        pos := 1
        while (pos := RegExMatch(src, "FT\(&\w+, &\w+, (\d+), (\d+), (\d+), (\d+), ([\d.]+), ([\d.]+), (\w+)\)", &m, pos)) {
            DT_AddUsage(m[7], [m[1], m[2], m[3], m[4]], [m[5], m[6]])
            pos += m.Len
        }
        pos := 1
        while (pos := RegExMatch(src, 'ImageSearch\(&\w+, &\w+, (\d+), (\d+), (\d+), (\d+), "\*(\d+) " (\w+)\)', &m, pos)) {
            DT_AddUsage(m[6], [m[1], m[2], m[3], m[4]], [m[5], 0])
            pos += m.Len
        }
    }
}

DT_AddUsage(name, region, tol) {
    if DT_Usage.Has(name) {
        DT_Usage[name].count += 1
        return
    }
    DT_Usage[name] := {count: 1, region: region, tol: tol}
}

; ---- Debug panel section -------------------------------------------------------
; Built by AA_BuildDebugPanel (Lib\GuiPanels.ahk) inside the "Detection Tester" box.

; Quick Test box (Debug panel, top): x808 y85 w550 h120
DT_BuildQuickTest(P) {
    global DT_PresetList, DT_PresetText
    t := uiTheme
    aaMainUI.SetFont("s9 norm c" t[6], "Segoe UI")
    DT_PresetList := AA_PanelAdd("DropDownList", "x822 y105 w330 r10 Choose1", DT_Presets, P)
    aaMainUI.SetFont("s9 Bold c" t[1])
    btn := AA_PanelAdd("Button", "x1158 y104 w90 h22", "Run", P)
    btn.OnEvent("Click", DT_RunPreset)
    btn := AA_PanelAdd("Button", "x1254 y104 w94 h22", "Discord Help", P)
    btn.OnEvent("Click", (*) => OpenDiscord())
    aaMainUI.SetFont("s8 norm c" t[1])
    DT_PresetText := AA_PanelAdd("Text", "x822 y133 w525 h68 c" t[1], "Pick a check and click Run. Roblox must be visible and show that screen.", P)
}

; Pattern Tester box (Debug panel, below): x808 y209 w550 h172
DT_BuildSection(P) {
    global DT_TypeList, DT_NameList, DT_StateText, DT_ValueEdit, DT_ResultText
    global DT_X1, DT_Y1, DT_X2, DT_Y2, DT_Tol1, DT_Tol0
    t := uiTheme
    aaMainUI.SetFont("s9 norm c" t[6], "Segoe UI")
    DT_TypeList := AA_PanelAdd("DropDownList", "x822 y228 w90 Choose1", ["FindText", "Image"], P)
    DT_TypeList.OnEvent("Change", (*) => DT_FillNames())
    DT_NameList := AA_PanelAdd("DropDownList", "x918 y228 w230 r20", [], P)
    DT_NameList.OnEvent("Change", (*) => DT_SelectName())

    aaMainUI.SetFont("s9 Bold c" t[1])
    DT_StateText := AA_PanelAdd("Text", "x1156 y231 w192 h18 c" t[1], "", P)
    AA_PanelAdd("Text", "x822 y259 w50 h18 c" t[1], "Region", P)
    AA_PanelAdd("Text", "x1052 y259 w30 h18 c" t[1], "Tol", P)
    aaMainUI.SetFont("s9 norm c" t[6])
    DT_X1 := AA_PanelAdd("Edit", "x874 y256 w40 h20 Number", "0", P)
    DT_Y1 := AA_PanelAdd("Edit", "x918 y256 w40 h20 Number", "0", P)
    DT_X2 := AA_PanelAdd("Edit", "x962 y256 w40 h20 Number", "816", P)
    DT_Y2 := AA_PanelAdd("Edit", "x1006 y256 w40 h20 Number", "638", P)
    DT_Tol1 := AA_PanelAdd("Edit", "x1084 y256 w40 h20", "0", P)
    DT_Tol0 := AA_PanelAdd("Edit", "x1128 y256 w40 h20", "0", P)
    aaMainUI.SetFont("s9 Bold c" t[1])
    btn := AA_PanelAdd("Button", "x1176 y255 w88 h22", "From code", P)
    btn.OnEvent("Click", (*) => DT_FillFromCode(true))
    btn := AA_PanelAdd("Button", "x1270 y255 w78 h22", "Test", P)
    btn.OnEvent("Click", DT_Test)

    aaMainUI.SetFont("s8 norm c" t[1])
    AA_PanelAdd("Text", "x822 y283 w525 h14 c" t[1], "Pattern - FindText text (paste from the FindText tool) or image file path:", P)
    aaMainUI.SetFont("s8 norm c" t[6])
    DT_ValueEdit := AA_PanelAdd("Edit", "x822 y298 w525 h34 -WantReturn", "", P)

    aaMainUI.SetFont("s9 Bold c" t[1])
    btn := AA_PanelAdd("Button", "x822 y337 w120 h22", "FindText Tool", P)
    btn.OnEvent("Click", (*) => Run(A_ScriptDir "\Lib\Tools\FindText.ahk"))
    btn := AA_PanelAdd("Button", "x948 y337 w120 h22", "Choose Image...", P)
    btn.OnEvent("Click", DT_ChooseImage)
    btn := AA_PanelAdd("Button", "x1074 y337 w130 h22", "Save Override", P)
    btn.OnEvent("Click", DT_SaveOverride)
    btn := AA_PanelAdd("Button", "x1210 y337 w138 h22", "Reset to Default", P)
    btn.OnEvent("Click", DT_ResetOverride)

    aaMainUI.SetFont("s8 norm c" t[1])
    DT_ResultText := AA_PanelAdd("Text", "x822 y362 w525 h16 c" t[1], "Pick a pattern, then Test.", P)
    DT_FillNames()
}

DT_FillNames() {
    type := DT_TypeList.Text
    DT_NameList.Delete()
    if DT_Names[type].Length
        DT_NameList.Add(DT_Names[type])
    DT_Tol0.Enabled := (type = "FindText")
    DT_ValueEdit.Value := ""
    DT_StateText.Value := DT_Names[type].Length " patterns"
    if (type = "Image") {
        DT_Tol1.Value := "15", DT_Tol0.Value := "0"
    } else {
        DT_Tol1.Value := "0", DT_Tol0.Value := "0"
    }
}

DT_SelectName() {
    name := DT_NameList.Text
    if (name = "")
        return
    DT_ValueEdit.Value := DT_Override.Has(name) ? DT_Override[name] : DT_Default[name]
    DT_StateText.Value := DT_Override.Has(name) ? "OVERRIDE active" : "default"
    DT_FillFromCode(false)
}

DT_FillFromCode(report) {
    name := DT_NameList.Text
    if (name = "")
        return
    if !IsObject(DT_Usage)
        DT_ScanUsage()
    if DT_Usage.Has(name) {
        u := DT_Usage[name]
        DT_X1.Value := u.region[1], DT_Y1.Value := u.region[2], DT_X2.Value := u.region[3], DT_Y2.Value := u.region[4]
        DT_Tol1.Value := u.tol[1], DT_Tol0.Value := u.tol[2]
        DT_ResultText.Value := "From code: first use of " name " (" u.count " use" (u.count = 1 ? "" : "s") ")."
    } else {
        DT_X1.Value := 0, DT_Y1.Value := 0, DT_X2.Value := 816, DT_Y2.Value := 638
        DT_Tol1.Value := (DT_TypeOf(name) = "Image") ? 15 : 0, DT_Tol0.Value := 0
        DT_ResultText.Value := "No search area in the code for " name " - whole Roblox window."
    }
}

; ---- test ---------------------------------------------------------------------

DT_Test(*) {
    name := DT_NameList.Text
    type := DT_TypeList.Text
    val := DT_Normalize(type, DT_ValueEdit.Value)
    if (val = "") {
        DT_ResultText.Value := "Nothing to test - pick a pattern or paste one."
        return
    }
    for c in [DT_X1, DT_Y1, DT_X2, DT_Y2] {
        if !IsInteger(c.Value) {
            DT_ResultText.Value := "Region must be four whole numbers."
            return
        }
    }
    x1 := Integer(DT_X1.Value), y1 := Integer(DT_Y1.Value), x2 := Integer(DT_X2.Value), y2 := Integer(DT_Y2.Value)
    if !(IsNumber(DT_Tol1.Value) && IsNumber(DT_Tol0.Value)) {
        DT_ResultText.Value := "Tolerance must be a number."
        return
    }
    if !WinExist(rblxID)
        DT_ResultText.Value := "Roblox window not found - testing anyway."
    start := A_TickCount
    try {
        if (type = "FindText") {
            ok := FT(&X, &Y, x1, y1, x2, y2, DT_Tol1.Value + 0, DT_Tol0.Value + 0, val)
            ms := A_TickCount - start
            if ok {
                w := 24, h := 24
                try w := ok[1].%"3"%, h := ok[1].%"4"%
                DT_Flash(ok[1].x - w // 2, ok[1].y - h // 2, w, h)
                DT_ResultText.Value := "FOUND at " X ", " Y " (" ok.Length " match" (ok.Length = 1 ? "" : "es") ") in " ms " ms."
            } else {
                DT_ResultText.Value := "NOT found in " x1 "," y1 " - " x2 "," y2 " (tolerance " DT_Tol1.Value " / " DT_Tol0.Value ", " ms " ms)."
            }
        } else {
            if !FileExist(val) {
                DT_ResultText.Value := "Image file not found: " val
                return
            }
            cx := 0, cy := 0
            try WinGetClientPos(&cx, &cy, , , rblxID)    ; region is relative to the Roblox window, like in the macro
            CoordMode("Pixel", "Screen")
            found := ImageSearch(&X, &Y, x1 + cx, y1 + cy, x2 + cx, y2 + cy, "*" Integer(DT_Tol1.Value) " " val)
            ms := A_TickCount - start
            if found {
                DT_ImageSize(val, &w, &h)
                DT_Flash(X, Y, w, h)
                DT_ResultText.Value := "FOUND at " X - cx ", " Y - cy " (Roblox window) in " ms " ms."
            } else {
                DT_ResultText.Value := "NOT found in " x1 "," y1 " - " x2 "," y2 " (variation *" Integer(DT_Tol1.Value) ", " ms " ms)."
            }
        }
    } catch as err {
        DT_ResultText.Value := "Test failed: " err.Message
    }
}

DT_ImageSize(path, &w, &h) {
    w := 24, h := 24
    try {
        hbm := LoadPicture(path)
        bm := Buffer(32, 0)
        DllCall("GetObject", "Ptr", hbm, "Int", bm.Size, "Ptr", bm)
        w := NumGet(bm, 4, "Int"), h := NumGet(bm, 8, "Int")
        DllCall("DeleteObject", "Ptr", hbm)
    }
}

; Red box on screen for 1.5 s where the match was (click-through, no focus change).
DT_Flash(x, y, w, h) {
    try {
        g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        g.BackColor := "FF0000"
        g.Show(Format("x{} y{} w{} h{} NoActivate", x, y, Max(w, 6), Max(h, 6)))
        WinSetTransparent(110, g)
        SetTimer(() => g.Destroy(), -1500)
    }
}

; ---- quick tests ----------------------------------------------------------------
; Each check uses the same pattern names, search areas, tolerances and pixel colours
; as the macro code named in its text (so a saved override is tested too).

DT_RunPreset(*) {
    preset := DT_PresetList.Text
    DT_PresetText.Value := "Running..."
    try {
        switch preset {
            case "Check For Lobby":
                DT_PresetText.Value := DT_QuickLobby()
            case "Unit Successfully Placed":
                DT_PresetText.Value := DT_QuickPlaced()
            case "Test Game Over / End Screen":
                DT_PresetText.Value := DT_QuickEndScreen()
            case "Check Active Cards":
                DT_PresetText.Value := DT_QuickCards()
            case "Test screen resolution / DPI":
                DT_PresetText.Value := DT_QuickScreen()
            default:
                DT_Test()
                DT_PresetText.Value := "Ran the Pattern Tester below with the pattern in its box - see its result line."
        }
    } catch as err {
        DT_PresetText.Value := "Check failed: " err.Message
    }
}

DT_YN(b) {
    return b ? "YES" : "no"
}

; FindText exactly like the macro: FT() with the current value of the pattern variable
DT_Find(name, x1, y1, x2, y2, e1 := 0, e0 := 0) {
    try {
        pattern := %name%
        return FT(&X, &Y, x1, y1, x2, y2, e1, e0, pattern) ? true : false
    }
    return false
}

; GameMango.ahk CheckLobby()
DT_QuickLobby() {
    area := DT_Find("AreaText", 746, 514, 789, 530)
    return "Check For Lobby - same check as CheckLobby():`n"
        . "Areas button (AreaText, 746,514 - 789,530): " DT_YN(area) "`n"
        . (area ? "=> LOBBY DETECTED - the macro would start the selected mode."
                : "=> NOT in the lobby - the macro would keep waiting (or rejoin after the Lobby failsafe).")
}

; Game\UnitPlacement.ahk UnitPlaced() / WaitForUpgradeText() - one look, no waiting.
; Matches your FindText version: UnitExistence in 171,348 - 337,447 or AtkPrio in 26,387 - 192,475,
; and not ElyssiaSummons.
DT_QuickPlaced() {
    unitMenu := DT_Find("UnitExistence", 171, 348, 337, 447)
    atkPrio := DT_Find("AtkPrio", 26, 387, 192, 475)
    eel := DT_Find("ElyssiaSummons", 14, 226, 138, 246)
    placed := (unitMenu || atkPrio) && !eel
    return "Unit Successfully Placed - same check as UnitPlaced() (place or click a unit first):`n"
        . "Unit menu (UnitExistence, 171,348 - 337,447): " DT_YN(unitMenu) "   Target priority (AtkPrio, 26,387 - 192,475): " DT_YN(atkPrio) "`n"
        . "Elyssia summon clicked (ElyssiaSummons, 14,226 - 138,246): " DT_YN(eel) "`n"
        . (placed ? "=> PLACED - the macro would count this unit as placed."
                  : "=> NOT placed - the macro would try the next spot.")
}

; GameMango.ahk MonitorStage / CheckEndAndRoute / CheckForEndGameScreens + HandleStageEnd
DT_QuickEndScreen() {
    lobbyTxt := DT_Find("LobbyText", 80, 85, 739, 224) || DT_Find("LobbyText2", 80, 85, 739, 224)
    nextTxt := DT_Find("NextText", 260, 400, 390, 450)
    xpTxt := DT_Find("XpText", 575, 145, 641, 210)
    victory := DT_Find("VictoryText", 150, 180, 350, 260) || DT_Find("VictoryText2", 319, 176, 492, 279) || DT_Find("VictoryTextApril", 363, 193, 475, 274)
    defeat := DT_Find("DefeatText", 150, 180, 350, 260) || DT_Find("DefeatText2", 319, 176, 492, 279)
    ended := lobbyTxt || nextTxt || xpTxt
    out := "Game Over / End Screen - same checks as the end-screen code:`n"
        . "Return-to-lobby text (LobbyText/2): " DT_YN(lobbyTxt) "   Next (NextText): " DT_YN(nextTxt) "   XP (XpText): " DT_YN(xpTxt) "`n"
        . "Victory text (VictoryText/2/April): " DT_YN(victory) "   Defeat text (DefeatText/2): " DT_YN(defeat) "`n"
    if !ended
        return out "=> NO end screen - the macro keeps monitoring the stage."
    return out "=> END SCREEN DETECTED - the macro would count a " (victory ? "WIN" : "LOSS")
        . (victory ? "." : (defeat ? "." : " (no victory text found, so it counts a loss)."))
}

; Game\StageEvents.ahk card pick: pick_card opens the screen, then each textCards entry
DT_QuickCards() {
    screen := DT_Find("pick_card", 293, 152, 450, 213)
    found := ""
    checked := 0
    try {
        for key, pattern in textCards {
            checked++
            try {
                if FT(&X, &Y, 209, 203, 652, 404, 0, 0, pattern)
                    found .= (found = "" ? "" : ", ") key
            }
        }
    }
    return "Check Active Cards - same checks as the card picker:`n"
        . "Card screen open (pick_card, 293,152 - 450,213): " DT_YN(screen) "`n"
        . "Cards visible (" checked " card patterns, 209,203 - 652,404): " (found = "" ? "none" : found) "`n"
        . (screen ? "=> The macro would pick by your card priority from the cards above."
                  : "=> No card screen - the macro would not pick a card now.")
}

DT_QuickScreen() {
    w := SysGet(78), h := SysGet(79)
    zoom := Round(DllCall("user32\GetDpiForSystem", "UInt") / 96 * 100)
    ok := (w = 1920 && h = 1080 && zoom = 100)
    rb := "Roblox window: not found"
    try {
        if WinExist(rblxID) {
            WinGetPos(, , &rw, &rh, rblxID)
            rb := "Roblox window: " rw "x" rh (rw = 816 && rh = 638 ? " (correct)" : " (should be 816x638 - press " F1Key ")")
        }
    }
    return "Screen resolution / DPI:`n"
        . "Screen " w "x" h ", Windows zoom " zoom "%" (ok ? " - correct." : " - needs 1920x1080 and 100% (click Discord Help).") "`n"
        . rb "`n"
        . "If you have Vanguard / Riot anti-cheat, turn it off."
}

; ---- override -----------------------------------------------------------------

DT_ChooseImage(*) {
    if (DT_TypeList.Text != "Image") {
        DT_ResultText.Value := "Switch the type to Image first."
        return
    }
    aaMainUI.Opt("-AlwaysOnTop")
    file := FileSelect(3, A_ScriptDir "\Images", "Choose the new image", "Images (*.png; *.jpg; *.jpeg; *.bmp)")
    aaMainUI.Opt("+AlwaysOnTop")
    if (file != "") {
        DT_ValueEdit.Value := file
        DT_ResultText.Value := "Image chosen - click Test, then Save Override if it is found."
    }
}

DT_SaveOverride(*) {
    global DT_Override
    name := DT_NameList.Text
    if (name = "") {
        DT_ResultText.Value := "Pick the pattern you want to replace first."
        return
    }
    type := DT_TypeOf(name)
    val := DT_Normalize(type, DT_ValueEdit.Value)
    if (val == DT_Default[name]) {
        DT_ResultText.Value := "That is the default - nothing to save (use Reset to Default to remove an override)."
        return
    }
    if (reason := DT_Check(name, val)) {
        DT_ResultText.Value := "Not saved: " reason "."
        return
    }
    if (MsgBox("Replace " name " for the whole macro with your new " (type = "Image" ? "image" : "pattern") "?`n"
        . "Search areas and tolerances in the code stay the same. Reset to Default undoes it.", "Detection Override", 0x1024) != "Yes")
        return
    try {
        if !DirExist(DT_Dir)
            DirCreate(DT_Dir)
        if (type = "Image") {           ; keep a copy, so the override survives if the original file moves
            if !DirExist(DT_Dir "\Images")
                DirCreate(DT_Dir "\Images")
            SplitPath(val, , , &ext)
            dest := DT_Dir "\Images\" name "." ext
            if (val != dest)
                FileCopy(val, dest, 1)
            val := dest
        }
        DT_Override[name] := val
        DT_WriteOverrides()
        DT_Apply(name, val)
        DT_ValueEdit.Value := val
        DT_StateText.Value := "OVERRIDE active"
        DT_ResultText.Value := "Saved - the macro now uses your " (type = "Image" ? "image" : "pattern") " for " name "."
        AddToLog("Detection override saved for " name)
    } catch as err {
        DT_ResultText.Value := "Could not save: " err.Message
    }
}

DT_ResetOverride(*) {
    global DT_Override
    name := DT_NameList.Text
    if (name = "" || !DT_Override.Has(name)) {
        DT_ResultText.Value := "No override for this pattern - it already uses the default."
        return
    }
    try {
        DT_Override.Delete(name)
        DT_WriteOverrides()
        DT_Apply(name, DT_Default[name])
        DT_ValueEdit.Value := DT_Default[name]
        DT_StateText.Value := "default"
        DT_ResultText.Value := name " is back to the original from Image.ahk."
        AddToLog("Detection override removed for " name)
    } catch as err {
        DT_ResultText.Value := "Could not reset: " err.Message
    }
}

DT_WriteOverrides() {
    text := "; Detection overrides - written by Debug > Detection Tester. Name=new value`n"
        . "; Delete a line (or this file) to go back to the original pattern from Lib\Tools\Image.ahk.`n"
    for name, val in DT_Override
        text .= name "=" val "`n"
    if FileExist(DT_OverrideFile)
        FileDelete(DT_OverrideFile)
    FileAppend(text, DT_OverrideFile, "UTF-8")
}
