#Requires AutoHotkey v2.0

GetMapForFarming(name) {
    farmMap := Map(
        "Eclipse Portal", "Snowy Kingdom",
        "Snowy Kingdom", "Eclipse Portal",

        "Demon Leader's Portal", "Fabled Kingdom",
        "Fabled Kingdom", "Demon Leader's Portal",

        "Noble Portal", "Mountain Temple",
        "Mountain Temple", "Noble Portal",

        "Puppet Portal", "Puppet Island",
        "Puppet Island", "Puppet Portal",

        "Shibuya Portal", "Shibuya District",
        "Shibuya District", "Shibuya Portal",

        "Sky Portal", "Sky Island",       ; [UPD 21.0] new portal
        "Sky Island", "Sky Portal"
    )
    if (farmMap.Has(name)) {
        return farmMap[name]
    } else {
        return "no map found"
    }
}

SetMapForPortalFarm(name) {
    return StoryDropdown.Text := name
}

SwitchActiveFarm() {
    global mode
    if (ModeDropdown.Text = "Story") {
        newMap := GetMapForFarming(StoryDropdown.Text)
        if (newMap != "no map found") {
            ModeDropdown.Text := "Portal"
            PortalDropdown.Text := newMap
            PortalJoinDropdown.Text := "Solo"
            mode := "Portal"
            AddToLog("Switched to " newMap)
            if (debugMessages) {
                AddToLog("Mode: " ModeDropdown.Text)
                AddToLog("Portal: " PortalDropdown.Text)
                AddToLog("Join Type: " PortalJoinDropdown.Text)
            }
        } else {
            if (debugMessages) {
                AddToLog("No valid portal mapping found for " StoryDropdown.Text)
            }
        }
    } else {
        newMap := GetMapForFarming(PortalDropdown.Text)
        if (newMap != "no map found") {
            ; [11-08] Sky Island is not in the Story list - setting it would stop the macro with an error
            try {
                StoryDropdown.Text := newMap
            } catch {
                AddToLog("[Portal] No Story map called " newMap " - can't farm more " PortalDropdown.Text "s there")
                return
            }
            ModeDropdown.Text := "Story"
            StoryActDropdown.Text := "Infinity"
            StoryDropdown.Text := newMap
            mode := "Story"
            AddToLog("Switched to " newMap " for farming portals")
            if (debugMessages) {
                AddToLog("Mode: " ModeDropdown.Text)
                AddToLog("Story Act: " StoryActDropdown.Text)
                AddToLog("Story: " StoryDropdown.Text)
            }
        } else {
            if (debugMessages) {
                AddToLog("No valid story mapping found for " PortalDropdown.Text)
            }
        }
    }
}

HandlePortalJoin() {
    selectedPortal := PT_SearchText(PortalDropdown.Text)
    joinType := PortalJoinDropdown.Text

    FixClick(640, 70) ; Closes Player leaderboard
    Sleep(500)

    ; Click items and portals tab
    ClickItemsAndPortalsTab()

    ; Click search and type portal name
    ClickSearchAndTypePortal(selectedPortal)

    if (joinType = "Solo") {
        AddToLog("Soloing " selectedPortal)
        if (HandlePortalSelection())
            PT_StartPortal()
    } else if (joinType = "Creating") {
        AddToLog("Creating " selectedPortal)
        if (HandlePortalSelection()) {
            AddToLog("Waiting 15 seconds for others to join")
            Sleep(15000)
            PT_StartPortal()
        }
    } else {
        AddToLog("Please join " selectedPortal " manually")
        Sleep(5000)
    }
}

; [UPD 21.0 11-08] clicking a portal opens a popup NEXT TO the tile with Use / Delete / View, so the buttons
; move (Use was seen from y 369 to 475). The old fixed "Open" click (250, 350) could land on Delete. Use is now
; found by its colours (PT_FindUse); if it isn't there, nothing is clicked - the inventory is closed and logged.
HandlePortalSelection() {
    Sleep(200)
    FixClick(215, 290)  ; first portal tile
    btn := 0
    start := A_TickCount
    while (A_TickCount - start < 5000) {   ; the popup draws its buttons a second or two after the info
        Sleep(400)
        if (btn := PT_FindUse())
            break
    }
    if (!btn) {
        AddToLog("[Portal] Couldn't find the Use button (no " PortalDropdown.Text " left?) - closing the inventory, nothing pressed")
        HandlePortalFallback(true)
        return false
    }
    AddToLog("[Portal] Pressing Use at " btn.x ", " btn.y)
    FixClick(btn.x, btn.y)
    Sleep(1500)
    return true
}

; After Use: the old Start spot - only if the popup is really gone (otherwise Use didn't work: close, don't click).
PT_StartPortal() {
    if (PT_FindUse()) {
        AddToLog("[Portal] The Use button is still showing - the portal didn't open. Closing the inventory")
        FixClick(660, 189)
        return false
    }
    FixClick(400, 460)  ; Start portal (same spot as before UPD 21.0 - not checked on the new screens yet)
    return true
}

ClickItemsAndPortalsTab() {
    FixClick(34, 296) ; Click items
    Sleep(1500)
    FixClick(535, 225) ; Click portals tab  [UPD 21.0: All | Skins | Relics | Charms | Artifacts | Portals | Gifts]
    Sleep(1500)
}

ClickSearchAndTypePortal(selectedPortal) {
    FixClick(490, 185) ; Click search  [UPD 21.0]
    Sleep(1500)
    SendInput("^a")             ; clear what was typed before
    Sleep(100)
    SendInput("{Backspace 15}")
    Sleep(200)
    ; Loops through every character in selectedPortal one by one
    Loop Parse, selectedPortal {
    SendInput(A_LoopField)
    Sleep(200) ; Adjust this number to change the delay in milliseconds
    }
    Sleep(200)
}

CheckForPortal(lobby := false) {
    x1 := lobby ? 211 : 257
    y1 := lobby ? 341 : 419
    x2 := lobby ? 401 : 445
    y2 := lobby ? 504 : 520
    portalText := lobby ? UsePortal : SelectPortal
    action := lobby ? "starting portal" : "restarting portal"

    if TryHandlePortal(x1, y1, x2, y2, portalText, action) {
        return
    }
    HandlePortalFallback(lobby)
}

TryHandlePortal(x1, y1, x2, y2, portalText, action) {
    if (ok := FT(&portalX, &portalY, x1, y1, x2, y2, 0, 0, portalText)) {
        AddToLog("Portal detected, " action "...")
        (portalText = SelectPortal) ? ClickSelectPortal() : ClickUsePortal()
        return true
    }
    return false
}

HandlePortalFallback(lobby := false) {
    FixClick(660, 187) ; Close Portal Interface
    SwitchActiveFarm()
    Sleep(1500)
    if (!lobby) {
        ClickReturnToLobby()
    }
    return NextStep(CheckLobby)
}

HandlePortalEnd() {
    global inChallengeMode, challengeStartTime
    selectedPortal := PT_SearchText(PortalDropdown.Text)

    Loop {
        Sleep(3000)
        FixClick(607, 553)

        HandleTextFind(300, 190, 360, 250, UnitExit, -4, -35)
        Sleep(1500)

        HandleTextFind(260, 400, 390, 450, NextText, 0, -40)
        Sleep(1500)

        if (ok := FT(&X, &Y, 80, 85, 739, 224, 0, 0, LobbyText) or (ok := FT(&X, &Y, 80, 85, 739, 224, 0, 0, LobbyText2))) {
            if (inChallengeMode) {
                CompleteChallenge()
                return
            }

            if (CheckChallengeMode()) {
                return
            }

            AddToLog("Found Lobby Text - creating/joining new portal")
            Sleep(2000)

            CreateOrJoinPortal(selectedPortal)

            if (PortalJoinDropdown.Text = "Solo") {
                sleep 1000
                FixClick(400, 460)  ; Start portal
                return NextStep(RestartStage)
            } else if (PortalJoinDropdown.Text = "Creating") {
                Sleep(5000)
            } else {
                AddToLog("Waiting for next portal")
                Sleep(5000)
            }
            return NextStep(RestartStage)
        }

        Reconnect()
        CheckEndAndRoute()
    }
}

HandleTextFind(x1, y1, x2, y2, text, offsetX, offsetY) {
    if (ok := FT(&X, &Y, x1, y1, x2, y2, 0, 0, text)) {
        ClickUntilGone(0, 0, x1, y1, x2, y2, text, offsetX, offsetY)
    }
}

CompleteChallenge() {
    global inChallengeMode, challengeStartTime
    AddToLog("Challenge completed - returning to selected mode")
    inChallengeMode := false
    challengeStartTime := A_TickCount
    Sleep(1500)
    ClickReturnToLobby()
    NextStep(CheckLobby)
}

CheckChallengeMode() {
    global inChallengeMode, challengeStartTime
    if (!inChallengeMode && ChallengeBox.Value) {
        timeElapsed := A_TickCount - challengeStartTime
        if (timeElapsed >= 1800000) {  ; 30 minutes in milliseconds
            AddToLog("30 minutes passed - switching to Challenge mode")
            inChallengeMode := true
            challengeStartTime := A_TickCount
            Sleep(1500)
            ClickReturnToLobby()
            NextStep(CheckLobby)
            return true
        }
    }
    return false
}

CreateOrJoinPortal(selectedPortal) {
    FixClick(485, 120) ; Select New Portal
    Sleep(1500)
    FixClick(510, 190) ; Click search
    Sleep(1500)
    SendInput(selectedPortal)
    Sleep(1500)
    FixClick(215, 285) ; Click On Portal
    Sleep(1500)
    CheckForPortal(false)
    Sleep(5000)
}

ClickSelectPortal() {
    ClickUntilGone(0, 0, 257, 419, 445, 520, SelectPortal, 0, -35)
}

ClickUsePortal() {
    ClickUntilGone(0, 0, 211, 341, 401, 504, UsePortal, 0, -35)
}

HandlePortalReJoin() {
    selectedPortal := PT_SearchText(PortalDropdown.Text)

    joinType := PortalJoinDropdown.Text

    StageGuard.Disarm("Stage")   ; [Framework] stage is over - its timeout no longer applies
    StageGuard.Arm("EndScreen", (joinType = "Solo" || joinType = "Creating") ? FW_EndScreenTimeoutMs : 0)   ; [Framework] manual join waits on purpose
    Loop{
        Sleep(3000)
        StageGuard.Check("EndScreen", "portal end screen not handled")   ; [Framework]
        FixClick(607, 553)

        HandleTextFind(300, 190, 360, 250, UnitExit, -4, -35)
        Sleep(1500)

        HandleTextFind(201, 196, 633, 508,  NextText,-4, -35)

        ClickReturnToLobby()

        if ((ok := FT(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) || SC_Where() = "lobby") {   ; [11-08] + lobby buttons
            if (!inChallengeMode && ScheduleTick()) {
                AddToLog("Schedule: next step")
                return NextStep(StartSelectedMode)
            }
            
            if (inChallengeMode) {
                CompleteChallenge()
                return
            }

            if (CheckChallengeMode()) {
                return
            }

            AddToLog("Found Lobby Text - creating/joining new portal")
            Sleep(2000)

            FixClick(640, 70) ; Closes Player leaderboard
            Sleep(500)

            ; Click items and portals tab
            ClickItemsAndPortalsTab()

            ; Click search and type portal name
            ClickSearchAndTypePortal(selectedPortal)

            if (joinType = "Solo") {
                AddToLog("Soloing " selectedPortal)
                if (HandlePortalSelection())
                    PT_StartPortal()
                return NextStep(RestartStage)
            } else if (joinType = "Creating") {
                AddToLog("Creating " selectedPortal)
                if (HandlePortalSelection()) {
                    AddToLog("Waiting 15 seconds for others to join")
                    Sleep(15000)
                    PT_StartPortal()
                }
                return NextStep(RestartStage)
            } else {
                AddToLog("Please join " selectedPortal " manually")
                Sleep(5000)
            }
        }
    }
}
    

; ---- [UPD 21.0] portal helpers -------------------------------------------------------------------------------
; what to type in the inventory search for each portal (whole first word - "S" now finds Shibuya AND Sky)
PT_SearchText(name) {
    switch name {
        case "Demon Leader's Portal":
            return "Demon"
        case "Puppet Portal":
            return "Puppet"
        case "Alien Portal":
            return "Alien"
        case "Noble Portal":
            return "Noble"
        case "Shibuya Portal":
            return "Shibuya"
        case "Eclipse Portal":
            return "Eclipse"
        case "Sky Portal":
            return "Sky"
    }
    return name
}

; The portal popup's Use button: a wide green bar with a red bar (Delete) right under it and a yellow bar
; (View) under that, wherever the popup opened. Returns {x, y, redTop} (the middle of Use, at least 6 px above
; Delete) or 0. Tested on 24 saved pictures: Use found in all 7 with the popup open, nothing in the other 17.
PT_FindUse() {
    pic := SH_Grab(0, 0, 799, 598)
    y := 100
    while (y <= 560) {
        x := 120
        while (x <= 700) {
            if (PT_G(SH_Px(pic, x, y)) && PT_RedBelow(pic, x, y)) {
                if (s := PT_StackAt(pic, x, y))
                    return s
            }
            x += 6
        }
        y += 3
    }
    return 0
}

PT_G(c) {
    cr := (c >> 16) & 255, cg := (c >> 8) & 255, cb := c & 255
    return (cg >= 140 && cg - cr >= 80 && cb <= 90)
}
PT_R(c) {
    cr := (c >> 16) & 255, cg := (c >> 8) & 255, cb := c & 255
    return (cr >= 140 && cg <= 70 && cb <= 70)
}
PT_Y(c) {
    cr := (c >> 16) & 255, cg := (c >> 8) & 255, cb := c & 255
    return (cr >= 200 && cg >= 130 && cb <= 90)
}
PT_Is(kind, c) => (kind = "g" ? PT_G(c) : kind = "r" ? PT_R(c) : PT_Y(c))

; quick test before the full check: any red pixel 10-34 px below
PT_RedBelow(pic, x, y) {
    d := 10
    while (d <= 34) {
        if (y + d <= 598 && PT_R(SH_Px(pic, x, y + d)))
            return true
        d += 2
    }
    return false
}

; how many pixels of this colour follow in a row (up/down: dy = -1/1, left/right: dx = -1/1)
PT_Run(pic, x, y, kind, dx, dy, maxn) {
    n := 0
    while (n < maxn) {
        px := x + dx * (n + 1), py := y + dy * (n + 1)
        if (px < 0 || px > 799 || py < 0 || py > 598 || !PT_Is(kind, SH_Px(pic, px, py)))
            break
        n += 1
    }
    return n
}

; the first bar of this colour within 12 px below yFrom: [top, bottom] or 0
PT_BarBelow(pic, x, yFrom, kind) {
    loop 12 {
        py := yFrom + A_Index
        if (py > 598)
            return 0
        if (PT_Is(kind, SH_Px(pic, x, py)))
            return [py, py + PT_Run(pic, x, py, kind, 0, 1, 40)]
    }
    return 0
}

PT_StackAt(pic, x, y) {
    gt := y - PT_Run(pic, x, y, "g", 0, -1, 40), gb := y + PT_Run(pic, x, y, "g", 0, 1, 40)
    if (gb - gt + 1 < 10 || gb - gt + 1 > 32)
        return 0
    row := gt + 3
    if (!PT_G(SH_Px(pic, x, row)))
        return 0
    bl := x - PT_Run(pic, x, row, "g", -1, 0, 200), br := x + PT_Run(pic, x, row, "g", 1, 0, 200)
    if (br - bl + 1 < 60)
        return 0
    cl := bl + 10, cr := br - 10            ; measure near the bar edges - the words sit in the middle
    rb := PT_BarBelow(pic, cl, gb, "r")
    if (!rb || rb[2] - rb[1] + 1 < 10 || rb[2] - rb[1] + 1 > 32)
        return 0
    yb := PT_BarBelow(pic, cl, rb[2], "y")
    if (!yb || yb[2] - yb[1] + 1 < 10 || yb[2] - yb[1] + 1 > 32)
        return 0
    gy := (gt + gb) // 2, ry := (rb[1] + rb[2]) // 2, yy := (yb[1] + yb[2]) // 2
    if (!(PT_G(SH_Px(pic, cr, gy)) && PT_R(SH_Px(pic, cr, ry)) && PT_Y(SH_Px(pic, cr, yy))))
        return 0                            ; the same three bars on the right edge too
    if (gy > rb[1] - 6)
        return 0                            ; never anywhere near Delete
    return {x: (bl + br) // 2, y: gy, redTop: rb[1]}
}
