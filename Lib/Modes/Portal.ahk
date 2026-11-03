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
        "Shibuya District", "Shibuya Portal"
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
    switch PortalDropdown.text{
        case "Demon Leader's Portal":
            selectedPortal := "De"
        case "Puppet Portal":
            selectedPortal := "P"
        case "Alien Portal":
            selectedPortal := "A"
        case "Noble Portal":
            selectedPortal := "N"
        case "Shibuya Portal":
            selectedPortal := "S"
        case "Eclipse Portal":
            selectedPortal := "E"
    }
    joinType := PortalJoinDropdown.Text

    FixClick(640, 70) ; Closes Player leaderboard
    Sleep(500)

    ; Click items and portals tab
    ClickItemsAndPortalsTab()

    ; Click search and type portal name
    ClickSearchAndTypePortal(selectedPortal)

    if (joinType = "Solo") {
        AddToLog("Soloing " selectedPortal)
        HandlePortalSelection()
        FixClick(400, 460)  ; Start portal
    } else if (joinType = "Creating") {
        AddToLog("Creating " selectedPortal)
        HandlePortalSelection()
        AddToLog("Waiting 15 seconds for others to join")
        Sleep(15000)
        FixClick(400, 460)  ; Start portal
    } else {
        AddToLog("Please join " selectedPortal " manually")
        Sleep(5000)
    }
}

HandlePortalSelection() {
    sleep 200
    FixClick(211, 289)  ; Click On Portal
    Sleep(1500)
    CheckForPortal(true)
    Sleep(1500)
    FixClick(250, 350) ; Click Open
    Sleep(1500)
}

ClickItemsAndPortalsTab() {
    FixClick(33, 300) ; Click items
    Sleep(1500)
    FixClick(435, 230) ; Click portals tab
    Sleep(1500)
}

ClickSearchAndTypePortal(selectedPortal) {
    FixClick(510, 190) ; Click search
    Sleep(1500)
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
    switch PortalDropdown.text{
        case "Demon Leader's Portal":
            selectedPortal := "De"
        case "Puppet Portal":
            selectedPortal := "P"
        case "Alien Portal":
            selectedPortal := "A"
        case "Noble Portal":
            selectedPortal := "N"
        case "Shibuya Portal":
            selectedPortal := "S"
        case "Eclipse Portal":
            selectedPortal := "E"
    }

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
    switch PortalDropdown.text{
        case "Demon Leader's Portal":
            selectedPortal := "De"
        case "Puppet Portal":
            selectedPortal := "P"
        case "Alien Portal":
            selectedPortal := "A"
        case "Noble Portal":
            selectedPortal := "N"
        case "Shibuya Portal":
            selectedPortal := "S"
        case "Eclipse Portal":
            selectedPortal := "E"
    }

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

        if (ok := FT(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {
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
                HandlePortalSelection()
                FixClick(400, 460)  ; Start portal
                return NextStep(RestartStage)
            } else if (joinType = "Creating") {
                AddToLog("Creating " selectedPortal)
                HandlePortalSelection()
                AddToLog("Waiting 15 seconds for others to join")
                Sleep(15000)
                FixClick(400, 460)  ; Start portal
                return NextStep(RestartStage)
            } else {
                AddToLog("Please join " selectedPortal " manually")
                Sleep(5000)
            }
        }
    }
}
    

