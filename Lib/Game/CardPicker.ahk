#Requires AutoHotkey v2.0

; ============================================================================
;  CardPicker.ahk 

; ---- areas and patterns ----
global CardPick_ScreenText := CardExistance       
global CardPick_ScreenArea := [293, 152, 450, 213]  
global CardPick_SearchArea := [0, 0, 1000, 1000]   ; whole Roblox window
global CardPick_ConfirmText := ConfirmCard          ; confirm button of the selected card (Image.ahk)
global CardPick_MiddleSpot := [430, 303]            ; fallback "middle card" click
global CardPick_Err := [0, 0]                        

CardPick_DefineCards() {
    ;            name in the panel     FindText pattern
    CardPick_Add("Card 1",             "PLACEHOLDER")
    CardPick_Add("Card 2",             "PLACEHOLDER")
    CardPick_Add("Card 3",             "PLACEHOLDER")
    CardPick_Add("Card 4",             "PLACEHOLDER")
    CardPick_Add("Card 5",             "PLACEHOLDER")
    CardPick_Add("Card 6",             "PLACEHOLDER")
    CardPick_Add("Card 7",             "PLACEHOLDER")
    CardPick_Add("Card 8",             "PLACEHOLDER")
    CardPick_Add("Card 9",             "PLACEHOLDER")
    CardPick_Add("Card 10",            "PLACEHOLDER")
    CardPick_Add("Card 11",            "PLACEHOLDER")
    CardPick_Add("Card 12",            "PLACEHOLDER")
}

; ---- state ---------------------------------------------------------------------
global CardPick_Cards := Map()        ; name -> FindText pattern
global CardPick_Names := []           ; names in definition order
global CardPick_Order := []           ; your priority order (names)
global CardPick_Enabled := true
global CardPick_Fallback := 1         ; 1 middle card / 2 wait
global CardPick_FallbackItems := ["Pick the middle card", "Do nothing (wait)"]
global CardPick_File := A_ScriptDir "\Settings\CardPicker.txt"
global CardPick_List := "", CardPick_UseBox := "", CardPick_FallbackDDL := "", CardPick_StatusText := ""
global CardPick_Misses := 0           ; card screens in a row where nothing matched

CardPick_Add(name, pattern) {
    global CardPick_Cards, CardPick_Names
    if !CardPick_Cards.Has(name)
        CardPick_Names.Push(name)
    CardPick_Cards[name] := pattern
}

CardPick_HasPattern(name) {
    p := CardPick_Cards.Has(name) ? CardPick_Cards[name] : ""
    return (p != "" && !InStr(p, "PLACEHOLDER"))
}

; ---- settings (Settings\CardPicker.txt) ------------------------------------------

CardPick_Load() {
    global CardPick_Order, CardPick_Enabled, CardPick_Fallback
    CardPick_Cards.Clear(), CardPick_Names.Length := 0
    CardPick_DefineCards()
    CardPick_Order := []
    try {
        if FileExist(CardPick_File) {
            for line in StrSplit(FileRead(CardPick_File, "UTF-8"), "`n", "`r") {
                line := Trim(line)
                if (line = "")
                    continue
                if RegExMatch(line, "^@(\w+)=(.*)$", &m) {
                    if (m[1] = "enabled")
                        CardPick_Enabled := (m[2] = "1")
                    else if (m[1] = "fallback")   ; "middle" / "wait" (older files: 1-2 = middle, 3 = wait)
                        CardPick_Fallback := (m[2] = "wait" || m[2] = "3") ? 2 : 1
                    continue
                }
                p := StrSplit(line, "|")
                if (CardPick_Cards.Has(p[1]) && !CardPick_InOrder(p[1]))
                    CardPick_Order.Push(p[1])
            }
        }
    }
    for name in CardPick_Names              ; new cards (or no saved file) go to the end
        if !CardPick_InOrder(name)
            CardPick_Order.Push(name)
}

CardPick_InOrder(name) {
    for n in CardPick_Order
        if (n = name)
            return true
    return false
}

CardPick_Save(*) {
    global CardPick_Enabled, CardPick_Fallback
    try CardPick_Enabled := (CardPick_UseBox.Value = 1)
    try CardPick_Fallback := CardPick_FallbackDDL.Value
    text := "@enabled=" (CardPick_Enabled ? 1 : 0) "`n@fallback=" (CardPick_Fallback = 2 ? "wait" : "middle") "`n"
    for name in CardPick_Order
        text .= name "`n"
    try {
        f := FileOpen(CardPick_File, "w", "UTF-8")
        f.Write(text)
        f.Close()
    } catch as err {
        AddToLog("Could not save the card picker settings: " err.Message)
    }
}

; ---- panel -------------------------------------------------------------------------

CardPick_BuildPanel() {
    global CardPick_List, CardPick_UseBox, CardPick_FallbackDDL, CardPick_StatusText
    CardPick_Load()
    t := uiTheme
    panelName := "Cards"
    aaMainUI.SetFont("s9 Bold c" t[1], "Segoe UI")
    AA_PanelAdd("GroupBox", "x808 y85 w330 h296 +Center c" t[3], "Fool's Hunt Card Priority", panelName)
    AA_PanelAdd("GroupBox", "x1142 y85 w216 h296 +Center c" t[3], "Card Picker", panelName)

    ; --- priority list
    aaMainUI.SetFont("s9 norm c" t[6])
    CardPick_List := AA_PanelAdd("ListBox", "x818 y108 w220 h232", [], panelName)
    aaMainUI.SetFont("s9 Bold c" t[1])
    for i, b in [["Up", -1], ["Down", 1], ["Top", "top"], ["Bottom", "bottom"]] {
        btn := AA_PanelAdd("Button", Format("x1046 y{} w82 h24", 108 + (i - 1) * 30), b[1], panelName)
        btn.OnEvent("Click", CardPick_Move.Bind(b[2]))
    }
    aaMainUI.SetFont("s8 norm c9A9A9A")
    AA_PanelAdd("Text", "x818 y344 w310 h32 c9A9A9A",
        "Higher = picked first.", panelName)

    ; --- options
    aaMainUI.SetFont("s9 Bold c" t[1])
    CardPick_UseBox := AA_PanelAdd("CheckBox", "x1152 y110 w196 h18 c" t[1], "Use this card picker", panelName)
    CardPick_UseBox.Value := CardPick_Enabled ? 1 : 0
    CardPick_UseBox.OnEvent("Click", CardPick_Save)
    aaMainUI.SetFont("s8 Bold c9A9A9A")
    AA_PanelAdd("Text", "x1152 y140 w196 h14 c9A9A9A", "IF NO CARD MATCHES", panelName)
    aaMainUI.SetFont("s9 norm c" t[6])
    CardPick_FallbackDDL := AA_PanelAdd("DropDownList", "x1152 y156 w196 r2", CardPick_FallbackItems, panelName)
    CardPick_FallbackDDL.Value := CardPick_Fallback
    CardPick_FallbackDDL.OnEvent("Change", CardPick_Save)
    try SendMessage(0x160, 230, 0, CardPick_FallbackDDL)   ; CB_SETDROPPEDWIDTH: full text in the open list
    aaMainUI.SetFont("s9 norm c" t[1])
    CardPick_StatusText := AA_PanelAdd("Text", "x1152 y190 w196 h36 c" t[1], "", panelName)
    aaMainUI.SetFont("s9 Bold c" t[1])
    btn := AA_PanelAdd("Button", "x1152 y232 w196 h24", "Test on screen", panelName)
    btn.OnEvent("Click", (*) => CardPick_Test())
    btn := AA_PanelAdd("Button", "x1152 y262 w196 h24", "Reset order", panelName)
    btn.OnEvent("Click", CardPick_ResetOrder)
    aaMainUI.SetFont("s8 norm c9A9A9A")
    AA_PanelAdd("Text", "x1152 y292 w196 h80 c9A9A9A",
        "Test: open a card screen in game, then click Test - the console lists the cards it sees and which one it "
        . "would pick. Nothing is clicked.", panelName)
    CardPick_FillList()
}

; Called by AA_ShowPanel when the panel opens.
CardPick_OnPanelOpen() {
    CardPick_FillList()
}

CardPick_FillList(select := 0) {
    items := []
    for i, name in CardPick_Order
        items.Push(i ".  " name (CardPick_HasPattern(name) ? "" : "   - no pattern"))
    CardPick_List.Delete()
    CardPick_List.Add(items)
    if (select >= 1 && select <= items.Length)
        CardPick_List.Choose(select)
    set := 0
    for name in CardPick_Names
        set += CardPick_HasPattern(name)
    CardPick_StatusText.Value := "Patterns set: " set " / " CardPick_Names.Length
        . (set = 0 ? "`nFill them in CardPicker.ahk" : "")
}

CardPick_Move(dir, *) {
    global CardPick_Order
    i := CardPick_List.Value
    if (i < 1)
        return
    name := CardPick_Order[i]
    CardPick_Order.RemoveAt(i)
    to := (dir = "top") ? 1 : (dir = "bottom") ? CardPick_Order.Length + 1 : Max(1, Min(CardPick_Order.Length + 1, i + dir))
    CardPick_Order.InsertAt(to, name)
    CardPick_FillList(to)
    CardPick_Save()
}


CardPick_ResetOrder(*) {
    global CardPick_Order
    if (MsgBox("Put the cards back in their original order?", "Card Picker", 0x1024) != "Yes")
        return
    CardPick_Order := []
    for name in CardPick_Names
        CardPick_Order.Push(name)
    CardPick_FillList()
    CardPick_Save()
}

; ---- called from CheckForCardSelection (StageEvents.ahk) ----------------------------

; True when this picker handles the card screen (Fool's Hunt, switch ON).
CardPick_Active() {
    return CardPick_Enabled && IsHunt()
}

; The card screen is open when: your screen pattern is found (once you fill it in), or the
; Winter pick_card title is found, or - only while your screen pattern is still a placeholder -
; any of your card patterns is visible in the card area.
CardPick_ScreenVisible() {
    a := CardPick_ScreenArea
    if !InStr(CardPick_ScreenText, "PLACEHOLDER")
        if FT(&X, &Y, a[1], a[2], a[3], a[4], CardPick_Err[1], CardPick_Err[2], CardPick_ScreenText)
            return true
    if FT(&X, &Y, a[1], a[2], a[3], a[4], 0, 0, pick_card)
        return true
    if !InStr(CardPick_ScreenText, "PLACEHOLDER")    ; title set: no need to scan every card on each check
        return false
    for name in CardPick_Order
        if CardPick_Find(name, &X, &Y)
            return true
    return false
}

; Finds a card on screen. Returns true and sets X / Y when found.
CardPick_Find(name, &X, &Y) {
    if !CardPick_HasPattern(name)
        return false
    a := CardPick_SearchArea
    return FT(&X, &Y, a[1], a[2], a[3], a[4], CardPick_Err[1], CardPick_Err[2], CardPick_Cards[name])
}

; The card screen is open: pick by your order, verify, fall back if nothing matches.
CardPick_Pick() {
    global CardPick_Misses
    ; close the upgrade menu / untarget first (same as the old picker)
    if (ok := FT(&X, &Y, 300, 190, 360, 250, 0, 0, UnitExit)) {
        FixClick(329, 184)
        Sleep(100)
    }
    FixClick(59, 572)
    Sleep(100)

    loop 2 {                                         ; second round = retry if the screen stayed open
        for name in CardPick_Order {
            if CardPick_Find(name, &X, &Y) {
                CardPick_ClickCard(X, Y)
                if CardPick_WaitClosed() {
                    CardPick_Misses := 0
                    AddToLog("Picked card: " name)
                    return true
                }
                AddToLog("Card screen still open after picking " name " - trying again")
                break
            }
        }
        if !CardPick_ScreenVisible()
            return true
    }

    ; nothing matched (or the clicks didn't take)
    CardPick_Misses += 1
    if (CardPick_Fallback = 1)
        return CardPick_PickMiddle()
    if (CardPick_Misses = 1 || Mod(CardPick_Misses, 10) = 0)
        AddToLog("No card in your list found - waiting (fallback: do nothing)")
    return false
}

CardPick_PickMiddle() {
    global CardPick_Misses
    CardPick_ClickCard(CardPick_MiddleSpot[1], CardPick_MiddleSpot[2])
    if CardPick_WaitClosed() {
        AddToLog("No card in your list found - picked the middle card")
        CardPick_Misses := 0
        return true
    }
    AddToLog("No card in your list found and the middle card didn't close the screen")
    return false
}

; Same click sequence as the old picker: the card, then the confirm spot below it.
; Select the card, then click its confirm button (ConfirmCard). If the confirm button
; isn't found within ~2 s, the old confirm click (120 px below the card) is used.
CardPick_ClickCard(x, y) {
    FTClick(x, y, 0)
    MouseMove(0, 10, 2, "R")
    Click(2)
    Sleep(500)
    a := CardPick_SearchArea
    loop 8 {
        if FT(&cx, &cy, a[1], a[2], a[3], a[4], CardPick_Err[1], CardPick_Err[2], CardPick_ConfirmText) {
            sleep 600
            FixClick(cx, cy)
            return true
        }
        Sleep(200)
    }
    AddToLog("Card picker: confirm button not found - using the old confirm click")
    MouseMove(0, 120, 2, "R")
    Click(2)
    return false
}

; True once the card screen has closed (checks for ~3 s).
CardPick_WaitClosed() {
    loop 6 {
        Sleep(500)
        if !CardPick_ScreenVisible()
            return true
    }
    return false
}

; ---- Test on screen (panel) - lists what is recognised, never clicks -----------------

CardPick_Test() {
    try WinActivate(rblxID)
    Sleep(300)
    a := CardPick_ScreenArea
    screenSet := !InStr(CardPick_ScreenText, "PLACEHOLDER")
    set := 0
    for name in CardPick_Names
        set += CardPick_HasPattern(name)
    own := screenSet && FT(&X, &Y, a[1], a[2], a[3], a[4], CardPick_Err[1], CardPick_Err[2], CardPick_ScreenText)
    winter := FT(&X, &Y, a[1], a[2], a[3], a[4], 0, 0, pick_card)
    AddToLog("Card picker test: card screen - your pattern " (screenSet ? (own ? "FOUND" : "not found") : "not set (PLACEHOLDER)")
        . ", Winter pick_card " (winter ? "FOUND" : "not found"))
    if (!screenSet && set = 0)
        AddToLog("Card picker test: nothing to look for yet - press F7 (FindText tool), capture the Fool's card screen title "
            . "and each card, paste them over PLACEHOLDER in Lib\Game\CardPicker.ahk, then restart (F3)")
    else if !screenSet
        AddToLog("Card picker test: tip - also capture the card screen title into CardPick_ScreenText so the screen is found even when only unknown cards show")

    seen := [], pick := ""
    for name in CardPick_Order {
        if CardPick_Find(name, &X, &Y) {
            seen.Push(name " (" X "," Y ")")
            if (pick = "")
                pick := name
        } else if CardPick_HasPattern(name) {
            ; not in the card area - is it somewhere else in the window? (helps fixing CardPick_SearchArea)
            if FT(&X, &Y, 0, 0, 900, 700, CardPick_Err[1], CardPick_Err[2], CardPick_Cards[name])
                AddToLog("Card picker test: " name " found OUTSIDE the card area at " X "," Y " - widen CardPick_SearchArea")
        }
    }
    s := ""
    for n in seen
        s .= (s = "" ? "" : ", ") n
    AddToLog("Card picker test: cards seen in the card area: " (seen.Length ? s : "none") "  (patterns set: " set " / " CardPick_Names.Length ")")
    if (pick != "")
        AddToLog("Card picker test: would pick " pick)
    else
        AddToLog("Card picker test: no card from your list - fallback: " CardPick_FallbackItems[CardPick_Fallback])
}
