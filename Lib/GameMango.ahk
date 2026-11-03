#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Tools\Image.ahk
; [Modularized] This file keeps the game lifecycle: hotkeys, StartMacro/TogglePause, mode starters,
;   RestartStage, monitors, end screens, lobby/load/vote checks, reconnect/rejoin, stage setup.
;   Placement/upgrades/stage events/navigation/map detection/map movement -> Lib\Game\*.ahk,
;   contracts -> Lib\Modes\Contract.ahk, shared helpers -> Lib\Tools\ and Lib\Functions\.
global macroStartTime := A_TickCount
global stageStartTime := A_TickCount
global contractPageCounter := 0
global contractSwitchPattern := 0

global adaptations := 0
global setMahoragoStyle := false

LoadKeybindSettings()  ; Load saved keybinds
Hotkey(F1Key, (*) => moveRobloxWindow())
Hotkey(F2Key, (*) => StartMacro())
Hotkey(F3Key, (*) => Reload())
Hotkey(F4Key, (*) => TogglePause())

F5:: {
    HB_Save()   ; [Hotbar check] save your correct hotbar
}

F6:: {
    UT_ShowWindow()   ; [Unit types] set Ground / Hill / Hybrid per hotbar slot
}

F7:: {
    Run (A_ScriptDir "\Lib\Tools\FindText.ahk")
}

F8:: {
    static last := 0
    if (A_TickCount - last < 1500)   ; [Fix] holding F8 auto-repeated and toggled recording 20+ times
        return
    last := A_TickCount
    RM_Toggle()   ; [Record mode] start / stop recording while you play
    KeyWait("F8")
}

F9:: {
    WM_Toggle()   ; [Watch mode] let Claude follow the game; fixes load in the lobby
}

F10:: {
    SH_RecordNow()   ; [Record walk] record your own walk for the map you're on
}


StartMacro(*) {
    try CP_OverlayHide()   ; [Custom placement] no circles on screen while the macro runs
    if (MacroLoopState.Active) {   ; [Framework] F2 while already running would start a second, interleaved loop
        AddToLog("Macro is already running - press " F3Key " to reload")
        return
    }
    if (!ScheduleStart() && !ValidateMode()){   ; schedule on → it picks the mode, no need to select one
        return
    }
    RunMacroLoop(StartSelectedMode)
} 


TogglePause(*) {
    static pausedAt := 0   ; [Framework] paused time must not count towards failsafe timeouts
    Pause -1
    if (A_IsPaused) {
        pausedAt := A_TickCount
        AddToLog("Macro Paused")
        Sleep(1000)
    } else {
        if (pausedAt) {
            TimerManager.ShiftAll(A_TickCount - pausedAt)
            pausedAt := 0
        }
        AddToLog("Macro Resumed")
        Sleep(1000)
    }
}

GetNameForMode() {
    if (PlacementSelection.Text = "Winter Event") {
        return "event"
    }
    if (PlacementSelection.Text = "Fool's Hunt") {
        return "event"
    }
    if (PlacementSelection.Text = "Summer Hunt") {   ; [Summer Hunt] its own unit settings
        return "summer"
    }
    if (PlacementSelection.Text = "Default") {
        return ""
    }
    return PlacementSelection.Text
}

ChallengeMode() {    
    AddToLog("Moving to Challenge mode")
    ChallengeMovement()

    StageGuard.Arm("Entrance", FW_EntranceTimeoutMs)   ; [Framework]
    while !(ok := FT(&X, &Y, 325, 520, 489, 587, 0, 0, ModeCancel)) {
        Reconnect() ; Added Disconnect Check
        StageGuard.Check("Entrance", "Challenge entrance not reached")   ; [Framework]
        ChallengeMovement()
    }
    NextStep(RestartStage)
}

StoryMode() {
    global StoryDropdown, StoryActDropdown
    
    ; Get current map and act
    currentStoryMap := StoryDropdown.Text
    currentStoryAct := StoryActDropdown.Text
    
    ; Execute the movement pattern
    AddToLog("Moving to position for " currentStoryMap)
    if (Random(1, 2) = 1) {
        StoryMovement()
    } else {
        OppositeStoryMovement()
    }
    
    ; Start stage
    StageGuard.Arm("Entrance", FW_EntranceTimeoutMs)   ; [Framework]
    while !(ok := FT(&X, &Y, 325, 520, 489, 587, 0, 0, ModeCancel)) {
        Reconnect() ; Added Disconnect Check
        StageGuard.Check("Entrance", "Story entrance not reached")   ; [Framework]
        if (Random(1, 2) = 1) {
            StoryMovement()
        } else {
            OppositeStoryMovement()
        }
    }
    AddToLog("Starting " currentStoryMap " - " currentStoryAct)
    
    if (StoryUINav.Value) {
        StartStory(currentStoryMap, currentStoryAct)
    } else {
        StartStoryNoUINavigation(currentStoryMap, currentStoryAct)
    }

    ; Handle play mode selection
    if (StoryActDropdown.Text != "Infinity") {
        PlayHere()  ; Always PlayHere for normal story acts
    } else {
        if (MatchMaking.Value) {
            FindMatch()
        } else {
            PlayHere()
        }
    }

    NextStep(RestartStage)
}


LegendMode() {
    global LegendDropdown, LegendActDropdown
    
    ; Get current map and act
    currentLegendMap := LegendDropdown.Text
    currentLegendAct := LegendActDropdown.Text
    
    ; Execute the movement pattern
    AddToLog("Moving to position for " currentLegendMap)
    StoryMovement()
    
    ; Start stage
    StageGuard.Arm("Entrance", FW_EntranceTimeoutMs)   ; [Framework]
    while !(ok := FT(&X, &Y, 325, 520, 489, 587, 0, 0, ModeCancel)) {
        Reconnect() ; Added Disconnect Check
        StageGuard.Check("Entrance", "Legend entrance not reached")   ; [Framework]
        StoryMovement()
    }
    AddToLog("Starting " currentLegendMap " - " currentLegendAct)
    if (StoryUINav.Value) {
        StartLegend(currentLegendMap, currentLegendAct)
    } else {
        StartLegendNoUINavigation(currentLegendMap, currentLegendAct)
    }

    ; Handle play mode selection
    if (MatchMaking.Value) {
        FindMatch()
    } else {
        PlayHere()
    }

    NextStep(RestartStage)
}

RaidMode() {
    global RaidDropdown, RaidActDropdown
    
    ; Get current map and act
    currentRaidMap := RaidDropdown.Text
    currentRaidAct := RaidActDropdown.Text
    
    ; Execute the movement pattern
    AddToLog("Moving to position for " currentRaidMap)
    RaidMovement()
    
    ; Start stage
    StageGuard.Arm("Entrance", FW_EntranceTimeoutMs)   ; [Framework]
    while !(ok := FT(&X, &Y, 325, 520, 489, 587, 0, 0, ModeCancel)) {
        Reconnect() ; Added Disconnect Check
        StageGuard.Check("Entrance", "Raid entrance not reached")   ; [Framework]
        RaidMovement()
    }
    AddToLog("Starting " currentRaidMap " - " currentRaidAct)
    if (StoryUINav.Value) {
        StartRaid(currentRaidMap, currentRaidAct)
    } else {
        StartRaidNoUINavigation(currentRaidMap, currentRaidAct)
    }
    ; Handle play mode selection
    if (MatchMaking.Value) {
        FindMatch()
    } else {
        PlayHere()
    }

    NextStep(RestartStage)
}

InfinityCastleMode() {
    global InfinityCastleDropdown
    
    ; Get current difficulty
    currentDifficulty := InfinityCastleDropdown.Text
    
    ; Execute the movement pattern
    AddToLog("Moving to position for Infinity Castle")
    InfCastleMovement()
    
    ; Start stage
    StageGuard.Arm("Entrance", FW_EntranceTimeoutMs)   ; [Framework]
    while !(ok := FT(&X, &Y, 325, 520, 489, 587, 0, 0, ModeCancel)) {
        Reconnect() ; Added Disconnect Check
        StageGuard.Check("Entrance", "Infinity Castle entrance not reached")   ; [Framework]
        InfCastleMovement()
    }
    AddToLog("Starting Infinity Castle - " currentDifficulty)

    ; Select difficulty with direct clicks
    if (currentDifficulty = "Normal") {
        FixClick(418, 375)  ; Click Easy Mode
    } else {
        FixClick(485, 375)  ; Click Hard Mode
    }
    
    ;Start Inf Castle
    if (ok := FT(&X, &Y, 325, 520, 489, 587, 0, 0, ModeCancel)) {
        ClickUntilGone(0, 0, 325, 520, 489, 587, ModeCancel, -10, -120)
    }

    NextStep(RestartStage)
}

FoolsEvent() {
    ; Execute the movement pattern
    AddToLog("Moving to position for " ModeDropdown.Text)
    if SH_On()   ; [Summer Hunt] the new panels are found by their text
        return SH_EnterHunt()
    EventMovement()
    
    ; Start stage
    StageGuard.Arm("Entrance", FW_EntranceTimeoutMs)   ; [Framework]
    while !(ok:=FT(&X, &Y, 0, 0, 800, 800, 0, 0, JoinMatchmaking)) {
        Reconnect() ; Added Disconnect Check
        StageGuard.Check("Entrance", "Fool's Hunt entrance not reached")   ; [Framework]
        SH_On() ? SummerMovement() : EventMovement()
    }

    ; Handle play mode selection
    if (MatchMaking.Value) {
        FindMatch()
    } else {
        PlayHere()
    }

    AddToLog("Starting " ModeDropdown.Text)
    NextStep(RestartStage)
}

CursedWombMode() {
    AddToLog("Moving to Cursed womb")
    CursedWombMovement()

    StageGuard.Arm("Entrance", FW_EntranceTimeoutMs)   ; [Framework]
    while !(ok := FT(&X, &Y, 445, 440, 650, 487, 0, 0, Capacity)) {
        Reconnect() ; Added Disconnect Check
        StageGuard.Check("Entrance", "Cursed Womb entrance not reached")   ; [Framework]
        if (ok := FT(&X, &Y, 434-150000, 383-150000, 434+150000, 383+150000, 0, 0, RobuxPurchaseKey)) {
            AddToLog("Found Key Purchase Attempt")
            Sleep 50000
        }
        CursedWombMovement()
    }

    FixClick(500, 190)
    for char in StrSplit("Key (Cursed Womb)") {
    Send char
    Sleep (100)
    } 
    sleep (1000)
    FixClick(215, 285)
    sleep (500)
    FixClick(345, 370)
    sleep (500)
    
    NextStep(RestartStage)
}

ContractMode() {
   Sleep(2500)
   FixClick(33, 400)
   Sleep(2500)
   HandleContractJoin()
   Sleep(2500)
   NextStep(RestartStage)
}

PortalMode() {
    HandlePortalJoin()
    Sleep(2500)
    NextStep(RestartStage)
}

DungeonMode() {
    AddToLog("Entering Dungeon Mode")
    ; [UI update] the Dungeon button moved to the left column (85,400 is now Servers) - find it by its label
    db := 0
    try db := SH_Find("^dungeon$", 0, 380, 130, 40)
    FixClick(db ? db.x : 35, db ? db.y - 10 : 397)  ; Click Dungeon mode button
    Sleep(1000)
    if (ok := FT(&X, &Y, 370, 225, 545, 300, 0.20, 0.20, DungeonDeath)) {  ;FIUXXXX
        ClickDungeonDeathContinue()
    }
    Sleep(2000)
    if (ok := FT(&X, &Y, 310, 395, 495, 440, 0.20, 0.20, EnterDungeon)) {
        FixClick(395,380)
    }
    Sleep(1000)
    ; Select dungeon route and enter
    LookForDungeonRooms()
}

CheckForReturnToLobby() {
    if (ok := FT(&X, &Y, 80, 85, 739, 224, 0, 0, LobbyText) or (ok := FT(&X, &Y, 80, 85, 739, 224, 0, 0, LobbyText2))) {
        return true
    }
    return false
}

CheckForNextText() {
    if (ok := FT(&X, &Y, 260, 400, 390, 450, 0, 0, NextText)) {
        return true
    }
    if (SH_On() && SH_EndVisible())   ; [Summer Hunt] new end screen, read by its text
        return true
    return false
}

MonitorEndScreen() {
    global mode, StoryDropdown, StoryActDropdown, ReturnLobbyBox, MatchMaking, challengeStartTime, inChallengeMode

    StageGuard.Disarm("Stage")   ; [Framework] stage is over - its timeout no longer applies
    StageGuard.Arm("EndScreen", FW_EndScreenTimeoutMs)   ; [Framework]
    Loop {
        Sleep(3000)  
        StageGuard.Check("EndScreen", "end screen not handled")   ; [Framework]
        
        FixClick(607, 553)
        FixClick(607, 553)

        if (ok := FT(&X, &Y, 300, 190, 360, 250, 0, 0, UnitExit)) {
            ClickUntilGone(0, 0, 300, 190, 360, 250, UnitExit, -4, -35)
            Sleep(1500)
        }

        CloseChat()

        if (ok := FT(&X, &Y, 260, 400, 390, 450, 0, 0, NextText)) {
            ClickUntilGone(0, 0, 260, 400, 390, 450, NextText, 0, -40)
            Sleep(1500)
        }   

        if SH_On() {   ; [Summer Hunt] Next -> Return to lobby / Replay, found by their labels
            r := SH_EndButtons()
            if (r = "lobby")
                return NextStep(CheckLobby)
            if (r = "replay")
                return NextStep(RestartStage)
        }

        ; Now handle each mode
        if (ok := FT(&X, &Y, 80, 85, 739, 224, 0, 0, LobbyText) or (ok := FT(&X, &Y, 80, 85, 739, 224, 0, 0, LobbyText2))) {
            AddToLog("Found Lobby Text - Current Mode: " (inChallengeMode ? "Challenge" : mode))
            Sleep(2000)
            if (!inChallengeMode && ScheduleTick()) {
                AddToLog("Schedule: next step, returning to lobby")
                ClickUntilGone(0, 0, 80, 85, 739, 224, LobbyText, 0, -35, LobbyText2)
                return NextStep(CheckLobby)
            }

            ; Challenge mode logic first
            if (inChallengeMode) {
                 AddToLog("Challenge completed - returning to " mode " mode")
                inChallengeMode := false
                challengeStartTime := A_TickCount
                ClickUntilGone(0, 0, 80, 85, 739, 224, LobbyText, 0, -35, LobbyText2)
                return NextStep(CheckLobby)
            }

            ; Check if it's time for challenge mode
            if (!inChallengeMode && ChallengeBox.Value) {
                timeElapsed := A_TickCount - challengeStartTime
                if (timeElapsed >= 1800000) {
                    AddToLog("30 minutes passed - switching to Challenge mode")
                    inChallengeMode := true
                    challengeStartTime := A_TickCount
                    ClickUntilGone(0, 0, 80, 85, 739, 224, LobbyText, 0, -35, LobbyText2)
                    return NextStep(CheckLobby)
                }
            }

            if (mode = "Story") {
                AddToLog("Handling Story mode end")
                if (StoryActDropdown.Text != "Infinity") {
                    if (NextLevelBox.Value && lastResult = "win") {
                        AddToLog("Next level")
                        ClickNextLevel()
                    } else {
                        AddToLog("Replay level")
                        ClickReplay()
                    }
                } else {
                    if (PortalSwap.Value && GetMapForFarming(StoryDropdown.Text) != "no map found") {
                        SwitchActiveFarm()
                        Sleep(1500)
                        ClickReturnToLobby()
                        return NextStep(CheckLobby)
                    } else if (ReturnLobbyBox.Value) {
                        AddToLog("Return to lobby")
                        ClickReturnToLobby()
                    } else {
                        AddToLog("Story Infinity replay")
                        ClickReplay()
                    }
                }
                return NextStep(RestartStage)
            }
            else if (mode = "Raid") {
                AddToLog("Handling Raid end")
                if (ReturnLobbyBox.Value) {
                    AddToLog("Return to lobby")
                    ClickReturnToLobby()
                    return NextStep(CheckLobby)
                } else {
                    AddToLog("Replay raid")
                    ClickReplay()
                    return NextStep(RestartStage)
                }
            }
            else if (mode = "Dungeon") {
                AddToLog("Handling Dungeon end")
                return NextStep(MonitorDungeonEnd)
            }
            else if (mode = "Infinity Castle") {
                AddToLog("Handling Infinity Castle end")
                if (lastResult = "win") {
                    AddToLog("Next floor")
                    ClickReplay() ; Uses the replay coords for next level
                } else {
                    AddToLog("Restart floor")
                    ClickReplay()
                }
                return NextStep(RestartStage)
            }
            else if (mode = "Cursed Womb") {
                AddToLog("Handling Cursed Womb End")
                AddToLog("Returning to lobby")
                ClickReturnToLobby()
                return NextStep(CheckLobby)
            }
            else if (mode = "Fool's Hunt" || mode = "Summer Hunt") {
                AddToLog("Handling " mode " end")
                if (ReturnLobbyBox.Value) {
                    AddToLog("Return to lobby enabled")
                    ClickReturnToLobby()
                    return NextStep(CheckLobby)
                } else {
                    AddToLog("Replaying")
                    ClickReplay()
                }
                return NextStep(RestartStage)
            }
            else if (mode = "Winter Event") {
                AddToLog("Handling Winter Event end")
                if (ReturnLobbyBox.Value) {
                    AddToLog("Return to lobby enabled")
                    ClickReturnToLobby()
                    return NextStep(CheckLobby)
                } else {
                    AddToLog("Replaying")
                    ClickReplay()
                }
                return NextStep(RestartStage)
            }
            else {
                AddToLog("Handling end case")
                if (ReturnLobbyBox.Value) {
                    AddToLog("Return to lobby enabled")
                    ClickReturnToLobby()
                    return NextStep(CheckLobby)
                } else {
                    AddToLog("Replaying")
                    ClickReplay()
                    return NextStep(RestartStage)
                }
            }
        }
        Reconnect()
    }
}


MonitorStage() {
global mode, StoryActDropdown

    lastClickTime := A_TickCount
    msLook := A_TickCount
    msUpg := A_TickCount
    
    Loop {
        Sleep(1000)
        StageGuard.Check("Stage", "stage took too long")   ; [Framework]
        
        if (mode = "Story" && StoryActDropdown.Text = "Infinity") || (mode = "Winter Event") {
            timeElapsed := A_TickCount - lastClickTime
            if (timeElapsed >= 30000) {
                AddToLog("Performing anti-AFK click")
                FixClick(607, 553)
                lastClickTime := A_TickCount
            }
        }

        if (mode = "Winter Event") {
            CheckForCardSelection()
        }

        if (mode = "Fool's Hunt" || mode = "Summer Hunt") { ; [Fixed] was "Fools Event", which never matched
            CheckForCardSelection()
        }
        if (mode = "Summer Hunt") {   ; [Damage guard] check you're not the lowest damage; leave before the end if so
            dg := ""
            try dg := DG_Tick()
            if (dg = "leave")
                return TpLobby()
        }


        CheckForMahoraga()
        CheckForMahoragaAdaptation()

        if (ok := FT(&X, &Y, 300, 190, 360, 250, 0, 0, UnitExit)) {
            ClickUntilGone(0, 0, 300, 190, 360, 250, UnitExit, -4, -35)
        }

        CloseChat() ; Close chat if open

        if CheckForXp(true) || CheckForReturnToLobby() || CheckForNextText() { ; [Improved] also catch end screens without the XP text
            NextStep(HandleStageEnd)
        }

        CheckEndAndRoute()
        Reconnect()
        try PL_RetryPending()   ; [Budget] units that had no free spot earlier - try again every 30 s
        try SH_CloseSettings()  ; [Popups] Settings menu left open over the map -> close it
        ; [Fix] units still not maxed (placed late, or short on yen before) - go back to upgrading every 30 s
        if (A_TickCount - msUpg > 30000) {
            msUpg := A_TickCount
            global successfulCoordinates
            if (successfulCoordinates.Length > 0) {
                AddToLog("[Upgrade] " successfulCoordinates.Length " unit(s) still not maxed - upgrading again")
                NextStep(UpgradeUnits)
            }
        }

        ; [Where am I] every 20 s: if the match is clearly not running any more, go where the screen is
        if (A_TickCount - msLook > 20000) {
            msLook := A_TickCount
            if !CL_BaseBarVisible() {
                w := SC_WhereSure("match|vote")
                if (w = "end" && !(CheckForXp(true) || CheckForReturnToLobby() || CheckForNextText()))
                    SC_Recover(w, "the match")
                else if (w = "lobby" || w = "dungeon_menu")
                    SC_Recover(w, "the match")
            }
        }
    }
}

PerformAntiAFK(lastClickTime) {
    if (A_TickCount - lastClickTime >= 60000) {
        AddToLog("Performing anti-AFK click")
        Loop 3 {
            FixClick(607, 553)
        }
        return A_TickCount ; Return the updated lastClickTime
    }
}

HandleStageEnd() {
    global Wins, loss, stageStartTime

    isWin := false

    stageEndTime := A_TickCount
    stageLength := FormatStageTime(stageEndTime - stageStartTime)

    if (ok := FT(&X, &Y, 300, 190, 360, 250, 0, 0, UnitExit)) {
        ClickUntilGone(0, 0, 300, 190, 360, 250, UnitExit, -4, -35)
    }

    if (ok := FT(&X, &Y, 150, 180, 350, 260, 0, 0, DefeatText) or (ok:=FT(&X, &Y, 319, 176, 492, 279, 0, 0, DefeatText2))) { ;defeat 2 is the edited version
        isWin := false
    }

    if (ok := FT(&X, &Y, 150, 180, 350, 260, 0, 0, VictoryText) or (ok:=FT(&X, &Y, 319, 176, 492, 279, 0, 0, VictoryText2)) or (ok:=FT(&X, &Y, 363, 193, 475, 274, 0, 0, VictoryTextApril))) { ;victory 2 is the edited version
        isWin := true  
    }

    if SH_On() {   ; [Summer Hunt] the new result panel is read by its text
        res := SH_Result()
        if (res != "")
            isWin := (res = "win")
    }

    if isWin {
        AddToLog("Victory detected - Stage Length: " stageLength)
        Wins += 1
    } else {
        AddToLog("Defeat detected - Stage Length: " stageLength)
        loss += 1
    }
    try DG_MatchEnd()   ; [Damage guard] lowest damage 2 matches in a row -> Dungeon for the rest of the hour

    SendInput("{Tab}") ; Open Player leaderboard
    try {   ; [Framework] a webhook failure must not end the run (Anime Guardians pattern)
        SendWebhookWithTime(isWin, stageLength)
    } catch Error as err {
        if (err is MacroNextStep || err is MacroStop)
            throw err
        AddToLog("Webhook error: " err.Message " - continuing")
    }
    SendInput("{Tab}") ; Open Player leaderboard
    Sleep (500)

    if (mode = "Portal") {
        return NextStep(HandlePortalReJoin)           
    } else if (mode = "Contract") {
        return NextStep(HandleContractEnd) 
    } else if (mode = "Dungeon") {
        return NextStep(MonitorDungeonEnd)
    } else {
        return NextStep(MonitorEndScreen) 
    }
}

Zoom() {
    MouseMove(400, 300)
    Sleep 100

    ; Zoom in smoothly
    Loop 10 {
        Send "{WheelUp}"
        Sleep 50
    }

    ; Look down
    Click
    MouseMove(400, 400)  ; Move mouse down to angle camera down
    
    ; Zoom back out smoothly
    Loop 20 {
        Send "{WheelDown}"
        Sleep 50
    }
    
    ; Move mouse back to center
    MouseMove(400, 300)
}

TpSpawn() {
    global SH_JustRecorded
    if (SH_JustRecorded && A_TickCount - SH_JustRecorded < 120000) {   ; [Record walk] you're already where your walk ends
        AddToLog("Not teleporting to spawn - you just recorded your walk")
        return
    }
    ; [UI update] find "Teleport to Spawn" by its text first
    if SH_SettingsClick("spawn", "Teleport to Spawn") {
        Sleep(300)
        FixClick(583, 150)   ; close the menu
        Sleep(300)
        return
    }
    FixClick(26, 570) ;click settings
    Sleep 300
    FixClick(400, 215)
    Sleep 300
    loop 6 {
        Sleep 150
        SendInput("{WheelDown 1}") ;scroll
    }
    Sleep 300
    if (ok := FT(&X, &Y, 215, 160, 596, 480, 0.20, 0.20, Spawn)) {
        AddToLog("Found Teleport to Spawn button")
        FixClick(X + 100, Y - 30)
    } else {
        AddToLog("Could not find Teleport button")
    }
    Sleep 300
    FixClick(583, 147)
    Sleep 300

    ;
}

TpLobby() {
    ; [UI update] find "Return / Teleport to Lobby" by its text first
    if SH_SettingsClick("lobby", "Return to Lobby") {
        Sleep(1500)
        return NextStep(CheckLobby)
    }
    Sleep(500)   ; [Other PCs] one more try by text before the old picture search (the menu may have been slow)
    if SH_SettingsClick("lobby", "Return to Lobby") {
        Sleep(1500)
        return NextStep(CheckLobby)
    }
    FixClick(26, 570) ;click settings
    Sleep 300
    FixClick(400, 215)
    Sleep 300
    loop 4 {
        Sleep 250
        SendInput("{WheelDown 1}") ;scroll
    }
    Sleep 300
    if (ok := FT(&X, &Y, 233, 424, 567, 471, 0.20, 0.20, ReturnToLobbySettings)) {
        AddToLog("Found Teleport to Lobby button")
        FixClick(X + 150, Y - 30)
    } else {
        AddToLog("Could not find Teleport button")
    }
    Sleep 300
    FixClick(525, 415)
    Sleep 600
    ; [Fix] this old fallback left the Settings menu open over the map when the button wasn't found
    if !ok {
        AddToLog("Return to Lobby not found in Settings - closing the menu (the match plays on until its end screen)")
        try SH_CloseSettings(true)
        FixClick(581, 147)   ; the menu's X, in case its title couldn't be read
        Sleep 300
    }
    return NextStep(CheckLobby)
}

CloseChat() {
    if (ok := FT(&X, &Y, 123, 50, 156, 79, 0, 0, OpenChat)) {
        AddToLog "Closing Chat"
        FixClick(138, 30) ;close chat
    }
}

BasicSetup() {
    global inChallengeMode
    ; Only check for cards if NOT in an Auto Challenge run
    if (!inChallengeMode && (IsHunt() or ModeDropdown.Text = "Winter Event")) {
        CheckForCardSelection()
    }
    SendInput("{Tab}") ; Closes Player leaderboard
    Sleep 1000
    FixClick(569, 72) ; Closes Player leaderboard
    Sleep 1000
    FixClick(569, 72) ; Closes Player leaderboard
    Sleep 300
    CloseChat()
    Sleep 300
    Zoom()
    Sleep 300
    TpSpawn()
}
    
RestartStage() {
    global adaptations, setMahoragoStyle, inChallengeMode

    adaptations := 0
    setMahoragoStyle := false

    ; Use standard map detection during Auto Challenge runs
    ; [Fix] With "Bring Unit" on, the freeze must start within a few seconds of joining.
    ; It used to wait until the map was recognised - when a loading screen wasn't
    ; recognised that took 20-50s, the freeze came too late and the units were random.
    freezeSoon := (!inChallengeMode && ModeDropdown.Text = "Fool's Hunt" && BringUnits.Value && HB_FreezeAllowed())   ; (AHK names ignore case, so this must not be called bringUnits)
    ; [Fix 3] Looking for the map takes ~5s on a slower PC (it scans for ~30 loading screens),
    ; which made the freeze late. With Bring Unit on, don't look first: wait ~1.5s, freeze,
    ; and find the map afterwards. (The rounds that keep your units froze ~2s after joining.)
    if (freezeSoon) {
        Sleep(1500)
        currentMap := "no map found"
    } else {
        ; [Summer Hunt] no loading-screen pictures for the Summer maps - the arrival banner names the map
        ; [Summer Hunt] the loading screen's TEXT is unreliable (it said "Planet Greenie (Summer)" over a
        ; Space Center picture), but its PICTURE is the real map - the Fool's Hunt loading-screen pictures match it
        currentMap := (!inChallengeMode && ModeDropdown.Text = "Fool's Hunt") ? DetectHuntMap() : SH_On() ? DetectHuntMap(20000) : DetectMapImageSearch()
    }
    CP_SetStageMap(currentMap)
    try ST_SetMap(currentMap)   ; [Polish] stats strip

    ; Only freeze client in actual Fool's Hunt runs (never during Auto Challenge)
    if (!inChallengeMode && ModeDropdown.Text = "Fool's Hunt") {
        if (BringUnits.Value && HB_FreezeAllowed()) {
            CoordMode("Mouse", "Window")
            ClickAndHoldExit()
            CoordMode("Mouse", "Client")
            Sleep(1000)
            if (currentMap = "no map found") {   ; [Fix] try again now the freeze is done
                currentMap := DetectHuntMap(15000)
                CP_SetStageMap(currentMap)
                try ST_SetMap(currentMap)
            }
        }
    }

    ; Wait for loading
    CheckLoaded()

    if (!inChallengeMode) {
        if (!IsCorrectMap(currentMap)) {
            AddToLog("Incorrect map detected, teleporting to lobby")
            return TpLobby()
        }
    }

    if (!inChallengeMode && ModeDropdown.Text = "Fool's Hunt") {   ; Fool's Hunt map skipper only
        if (MatchMaking.Value) {
            if (ShouldSkipMap(currentMap)) {
                AddToLog("Map is set to be skipped: " currentMap ", returning to lobby")
                return TpLobby()
            }
        }
    }

    ; [Lobby board] the board passed on the way to the pad names this hour's map - most reliable
    if (currentMap = "no map found" && SH_On()) {
        bm := SH_BoardNow()
        if (bm != "") {
            currentMap := bm
            AddToLog("Map from the lobby board: " bm)
            try CP_SetStageMap(currentMap)
            try ST_SetMap(currentMap)
        }
    }
    ; [Minimap] the enemy path's shape on the minimap - learnt per map, quick and works on every map
    if (currentMap = "no map found" && SH_On()) {
        mm := ""
        try mm := SH_MiniMatch()
        if (mm != "") {
            currentMap := mm
            try CP_SetStageMap(currentMap)
            try ST_SetMap(currentMap)
        }
    }
    ; [Map banner] no loading-screen match: read the map name off the arrival banner instead
    if (currentMap = "no map found" && !inChallengeMode) {
        bn := SH_MapFromBanner(6000)
        if (bn != "") {
            currentMap := bn
            AddToLog("Map from the banner: " bn)
            try CP_SetStageMap(currentMap)
            try ST_SetMap(currentMap)
        }
    }
    if (SH_On() && currentMap != "no map found") {   ; [Summer Hunt] recoloured variants use the known map's walk
        rm := SH_ResolveMap(currentMap)
        if (rm != currentMap) {
            AddToLog("Map " currentMap " plays like " rm)
            currentMap := rm
        }
    }

    ; Do initial setup and map-specific movement during vote timer
    BasicSetup()

    if (SH_On() && currentMap = "no map found") {   ; [Map prints] recognise it by its view from spawn
        pm := SH_MatchPrint()
        if (pm != "") {
            currentMap := pm
            try ST_SetMap(pm)
        } else {
            ; [Ask once] the Summer loading screens / banner often don't give the name - if you're there,
            ; type it (20 s, then it carries on by itself); the view is remembered for next time
            an := SH_AskMapName(20)
            if (an != "") {
                currentMap := SH_ResolveMap(an)
                try CP_SetStageMap(currentMap)
                try ST_SetMap(currentMap)
            }
        }
    } else if (SH_On()) {
        try SH_LearnPrint(currentMap)   ; [Map prints] known map: remember its view if not saved yet
    }
    if (SH_On() && currentMap != "no map found")
        try SH_MiniLearn(currentMap)    ; [Minimap] remember this map's path shape if not saved yet
    if (SH_On() && SH_CheckUnknownMap(currentMap))   ; [Dungeon fallback] unknown map -> leave, play Dungeon
        return TpLobby()

    if (currentMap != "no map found") {
        global SH_JustRecorded
        if (!inChallengeMode && NoMovement.Visible && NoMovement.Value) {
            AddToLog("Skipping movement...")
        } else if (SH_JustRecorded && A_TickCount - SH_JustRecorded < 120000) {
            ; [Record walk] you just walked there yourself with F10 - don't walk it a second time this round
            SH_JustRecorded := 0
            AddToLog("Movement already done (you recorded it this round)")
            Zoom()   ; same top-down view as the built-in walks
        } else if CM_HandleStageMovement(currentMap) {
            Zoom()   ; [Record walk] after your walk: zoom out and look down from above, like the built-in walks
        } else {
            HandleMapMovement(currentMap)   ; Summer maps are the hunt versions of known maps - same walks as Fool's Hunt
        }
    }

    ; Wait for game to actually start
    StartedGame()
    if (!inChallengeMode && ModeDropdown.Text = "Fool's Hunt" && BringUnits.Value && HB_FreezeAllowed())
        HB_CheckOrLeave()   ; [Hotbar check] wrong units -> back to lobby and retry
    StageGuard.Arm("Stage", FW_StageGuardApplies() ? FW_StageTimeoutMs : 0)

    CP_HandleRecording(currentMap)

    ; Use standard Challenge placement profile during Auto Challenge runs
    if (!inChallengeMode && NewPlacementMethod.Visible && NewPlacementMethod.Value && !SH_On()) {   ; [Summer Hunt] always the normal placement (unit counts + smart placement)
        PlaceFoolUnits()
    } else {
        PlacingUnits()
    }

    ; Monitor stage progress
    NextStep(MonitorStage)
}

Reconnect() {
    ;Credit: @Haie fixed by Randomdev
    ;color_home := PixelGetColor(10, 10)
    ; Optimised Retries with a loop instead of calling Reconnect() inside itself (that piled up calls while disconnected)
    loop {
    color_reconnect := PixelGetColor(430,384)
    color_reconnectVerify := PixelGetColor(489,341)
    if !(color_reconnectVerify == 0x393B3D and color_reconnect == 0xFFFFFF) ; not on the disconnect screen
        return
    ;color_home == 0x121215
        AddToLog("Disconnected! Attempting to reconnect...")
        sendDCWebhook()
        StageGuard.Arm("Reconnect", FW_ReconnectTimeoutMs)   ; [Framework]

        try {
            if (WinExist(rblxID)) { 
                WinActivate(rblxID)
            }
        } catch {
            if (debugMessages) {
                AddToLog("Error: Unable to activate Roblox window.")
            }
        }

        psLink := FileExist("Settings\PrivateServer.txt") ? FileRead("Settings\PrivateServer.txt", "UTF-8") : ""

        ; Reconnect to Ps
        if FileExist("Settings\PrivateServer.txt") && (psLink := FileRead("Settings\PrivateServer.txt", "UTF-8")) {
            AddToLog("Connecting to private server...")
            Run(psLink)
        } else {
            Run("roblox://placeID=" 8304191830)
        }

        Sleep 2000
        if WinExist(rblxID) {
            WinActivate(rblxID)
            forceRobloxSize()
            moveRobloxWindow()
            Sleep (1000)
        }
        loop {
            FixClick(490, 400)
            AddToLog("Reconnecting to Roblox...")
            Sleep 15000
            StageGuard.Check("Reconnect", "reconnect not finished", false)   ; [Framework]
            if (ok := FT(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {
                AddToLog("Reconnected Successfully!")
                return NextStep(StartSelectedMode)
            } else if (PixelGetColor(489,341) == 0x393B3D and PixelGetColor(430,384) == 0xFFFFFF) {
                break ; still disconnected -> start the reconnect again (was: Reconnect())
            }
        }
    }
}

RejoinPrivateServer() {   
    AddToLog("Attempting To Reconnect To Private Server...")

    psLink := FileExist("Settings\PrivateServer.txt") ? FileRead("Settings\PrivateServer.txt", "UTF-8") : ""

    if psLink {
        AddToLog("Connecting to private server...")
        Run(psLink)
    } else {
        Run("roblox://placeID=8304191830")  ; Public server if no PS file or empty
    }

    Sleep(5000)

    ; Loop until successfully reconnected
    StageGuard.Arm("Rejoin", FW_ReconnectTimeoutMs)   ; [Framework]
    loop {
        AddToLog("Reconnecting to Roblox...")
        StageGuard.Check("Rejoin", "rejoin not finished - relaunching", false)   ; [Framework]
        Sleep(5000)

        if WinExist(rblxID) {
            forceRobloxSize()
            Sleep(1000)
        }

        if (ok := FT(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {
            AddToLog("Reconnected Successfully!")
            return NextStep(StartSelectedMode)
        }

        Reconnect()
    }
}

CheckForXp(closeLeaderboard := false) {
    if (closeLeaderboard) {
        FixClick(564, 72)
        Sleep(1200)
    }
    ; Check for lobby text
    if (ok := FT(&X, &Y, 575, 145, 641, 210, 0, 0, XpText)) {
        if !UP_ClosePanel()   ; [UI update] new close button position
            FixClick(325, 185)
        FixClick(607, 553)
        return true
    }
    return false
}

CheckLobby() {
    StageGuard.Disarm("Stage")   ; [Framework] stage is over - its timeout no longer applies
    StageGuard.Arm("Lobby", FW_LobbyTimeoutMs)   ; [Framework]
    clStart := A_TickCount, clLook := 0
    loop {
        Sleep 1000
        StageGuard.Check("Lobby", "lobby not reached")   ; [Framework]
        if (ok := FT(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {
            break
        }
        if (CheckForEndGameScreens()) {
            return NextStep(MonitorStage)
        }
        ; [Where am I] waiting for the lobby, but we're actually in a match (or it's loading/voting) -
        ; play it instead of waiting for a lobby that won't come
        if (A_TickCount - clStart > 30000 && A_TickCount - clLook > 10000) {   ; (a teleport out takes a while)
            clLook := A_TickCount
            w := SC_WhereSure("lobby|end")
            if (w = "match" || w = "vote") {
                AddToLog("[Where am I] Waiting for the lobby but this is a match (" w ") - playing it")
                return NextStep(RestartStage)
            }
        }
        Reconnect()
    }
    Sleep(SleepTime())
    AddToLog("Returned to lobby, restarting selected mode")
    return NextStep(StartSelectedMode)
}

CheckForEndGameScreens() {
    if (CheckForXp(true) || CheckForReturnToLobby() || CheckForNextText()) {
        AddToLog("Detected end game screen when should have already returned to lobby")
        CloseChat()
        return true
    }
}

CheckForLobbyText() {
    if (ok := FT(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {
        return true
    }
    return false
}

CheckForLobby() {
    loop {
        Sleep 1000
        if (ok := FT(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {
            break
        }
        Reconnect()
    }
    AddToLog("Returned to lobby.")
    return true
}

; ---- [Where am I] read the screen and say which part of the game it shows -------------------------
; The macro's steps each wait for one particular picture. When the game skips a screen or the picture
; changed in the update, a step waited forever. These waits now also look at what is actually on screen
; and jump to the right step: lobby -> start again, Dungeon Run menu -> pick a room, match running -> go on.
SC_Where() {
    if CL_BaseBarVisible()
        return "match"
    t := ""
    try t := SH_Text(0, 0, 800, 600)
    ; [Where am I v2] the two screens look clearly different:
    ;  lobby: side buttons Store / Items / Trade / Summon / Servers, "UPD 21.0.0", Quests / Areas / Guild
    ;  match: only the Units button, a wave counter, yen under the hotbar, the "Level info" panel
    lob := 0, game := 0
    for w in ["store", "summon", "servers", "trade", "quests", "areas", "guild", "upd 2"]
        if InStr(t, w)
            lob += 1
    for re in ["wave\s*\d", "level info", "enemies remaining", "\d\s*¥", "level modifiers"]
        if RegExMatch(t, re)
            game += 1
    if RegExMatch(t, "travelling to")
        return "loading"
    if RegExMatch(t, "pick your own path|dungeon run|dungeon depth")
        return "dungeon_menu"
    ; [Fix] "Return to Lobby" alone is also in the in-match Settings menu - only an end screen has these
    if RegExMatch(t, "waves completed|total time|victory|defeat") || (InStr(t, "return to lobby") && RegExMatch(t, "replay|next"))
        return "end"
    ; still in the lobby but the matchmaking queue is running ("Finding a game...") - not a failure, the
    ; match is coming. Restarting here walked around the lobby while the game teleported us in.
    if RegExMatch(t, "finding a game|matchmaking started|in queue|leave queue|teleporting|game will begin")
        return "queue"
    if (lob >= 3 && game = 0)
        return "lobby"
    if RegExMatch(t, "starts in|vote start|change your units")
        return "vote"
    if (game >= 2 && lob <= 1)
        return "match"
    if RegExMatch(t, "upd \d|daily rewards|public server|areas")
        return "lobby"
    return ""
}

; [Slow PCs] a slow load or a lagging screen must not be mistaken for "wrong place": only act when two
; looks about 5 s apart agree (and neither is a loading screen / queue). Otherwise "" = keep waiting.
SC_WhereSure(expect := "") {
    a := SC_Where()
    if (a = "" || a = "loading" || a = "queue" || (expect != "" && RegExMatch(a, "^(" expect ")$")))
        return a      ; nothing to act on, or it's where we expected to be - no second look needed
    Sleep(5000)
    b := SC_Where()
    return (a = b) ? a : ""
}

; called from a waiting loop; jumps to the right step when the screen shows something else
SC_Recover(where, waitingFor) {
    if (where = "lobby") {
        AddToLog("[Where am I] Waiting for " waitingFor " but this is the lobby - starting again")
        return NextStep(StartSelectedMode)
    }
    if (where = "dungeon_menu") {
        AddToLog("[Where am I] Waiting for " waitingFor " but the Dungeon Run menu is open - picking the next room")
        return NextStep(LookForDungeonRooms)
    }
    if (where = "end") {
        AddToLog("[Where am I] Waiting for " waitingFor " but the match is over - handling the end screen")
        return NextStep(HandleStageEnd)
    }
}

; [UI update] the base health bar at the top is now bright green (~0x00FD04 at y 61), not 0x00EE00.
; When the vote passed before the macro looked (wave 1 already running), nothing else matched and the
; macro stood still until the load timeout. Checked on the watch picture of Sacred Planet wave 1.
CL_BaseBarVisible() {
    old := A_CoordModePixel
    CoordMode("Pixel", "Client")
    n := 0
    try {
        for x in [170, 200, 230] {
            c := PixelGetColor(x, 61)
            r := (c >> 16) & 255, g := (c >> 8) & 255, b := c & 255
            if (g > 200 && r < 70 && b < 70)
                n += 1
        }
    }
    CoordMode("Pixel", old)
    return n >= 3
}

CheckLoaded() {
    StageGuard.Arm("Load", FW_LoadTimeoutMs)   ; [Framework]
    clStart := A_TickCount, clLook := 0
    loop {
        Sleep(1000)
        StageGuard.Check("Load", "stage did not load")   ; [Framework]
        if (A_TickCount - clStart > 20000 && A_TickCount - clLook > 10000) {   ; [Where am I]
            clLook := A_TickCount
            w := SC_WhereSure("match|vote")
            if (w = "match" || w = "vote") {
                AddToLog("Successfully Loaded In (seen by the screen: " w ")")
                break
            }
            SC_Recover(w, "the stage to load")
        }
        
        ; Check for vote screen 742, 287, 832, 377
        if (ok := FT(&X, &Y, 301, 64, 503, 154, 0, 0, VoteStart) or (ok := FT(&X, &Y, 301, 64, 503, 154, 0, 0, VoteStartLaptop) or (ok := FT(&X, &Y, 0, 0, 742, 287, 832, 377, 0.10, 0.10, Units) or (ok := FT(&X, &Y, 0, 0, 1080, 1080, 0, 0, UnitManager) or PixelGetColor(320, 60) = 0x00EE00 or CL_BaseBarVisible())))) {
            AddToLog("Successfully Loaded In")
            Sleep(1000)
            break
        } 
;13, 263, 89, 334
        Reconnect()
    }
}

StartedGame() {
    StageGuard.Arm("Vote", FW_VoteTimeoutMs)   ; [Framework]
    loop {
        Sleep(400)   ; [Pace] was 1000 - every second here is a second of wave 1 without units
        StageGuard.Check("Vote", "vote screen did not close")   ; [Framework]
        if (ok := FT(&X, &Y, 301, 64, 503, 154, 0, 0, VoteStart) or (ok := FT(&X, &Y, 301, 64, 503, 154, 0, 0, VoteStartLaptop))) {
            FixClick(350, 103) ; click yes
            FixClick(350, 100)
            FixClick(350, 97)
            continue  ; Keep waiting if vote screen is still there
        }
        
        ; [Fix] the 21.0 vote panel ("Vote start: 0/1 - Yes / No", "Starts in: 20") in EVERY mode, not just
        ; Summer Hunt. The old picture never matched it, so in Dungeon the macro never pressed Yes: each room
        ; waited out the full countdown, and "Game started" was logged while the vote was still up.
        if SH_VoteVisible()
            continue

        ; If we don't see vote screen anymore the game has started
        AddToLog("Game started")
        global stageStartTime := A_TickCount
        break
    }
}

StartSelectedMode() {
    global inChallengeMode, firstStartup, challengeStartTime
    try WM_LobbyReload()   ; [Watch mode] load new fixes between matches
    try SH_FallbackSwitch()   ; [Dungeon fallback] Summer Hunt <-> Dungeon when it's time
    FixClick(400,340)
    FixClick(400,390)
    CloseChat()

    if (ChallengeBox.Value && firstStartup) {
        AddToLog("Auto Challenge enabled - starting with challenge")
        inChallengeMode := true
        firstStartup := false
        challengeStartTime := A_TickCount  ; Set initial challenge time
        ChallengeMode()
        return
    }

    if (!inChallengeMode)
        Sched_RunPendingTeamSwap()   ; [Scheduler team swap] equip the scheduled step's team while still in the lobby

    ; If we're in challenge mode, do challenge
    if (inChallengeMode) {
        AddToLog("Starting Challenge Mode")
        ChallengeMode()
        return
    }    
    else if (ModeDropdown.Text = "Story") {
        StoryMode()
    }
    else if (ModeDropdown.Text = "Legend") {
        LegendMode()
    }
    else if (ModeDropdown.Text = "Raid") {
        RaidMode()
    }
    else if (ModeDropdown.Text = "Infinity Castle") {
        InfinityCastleMode()
    }
    else if (ModeDropdown.Text = "Contract") {
        if (contractsEnabled) {
            ContractMode()
        } else {
            AddToLog("Contracts are is not currently in Anime Adventures!")
        }
    }
    else if (ModeDropdown.Text = "Fool's Hunt") {
        FoolsEvent()
    }
    else if (ModeDropdown.Text = "Summer Hunt") {   ; [Summer Hunt] same ship pad / matchmaking flow as Fool's Hunt
        FoolsEvent()
    }
    else if (ModeDropdown.Text = "Winter Event") {
        if (isWinter) {
            WinterEvent()
        } else {
            AddToLog("The Winter Event is not currently in Anime Adventures!")
        }
    }
    else if (ModeDropdown.Text = "Cursed Womb") {
        CursedWombMode()
    }
    else if (ModeDropdown.Text = "Portal") {
        PortalMode()
    }
    else if (ModeDropdown.Text = "Dungeon") {
        DungeonMode()
    }
}

ValidateMode() {
    global mode
    if (ModeDropdown.Text = "") {
        ; [Fix] the box can come up empty although a mode was picked / saved (F2 then did nothing).
        ; Put the last mode back instead of refusing to start.
        m := (IsSet(mode) && mode != "") ? mode : ""
        if (m = "") {
            try {
                if RegExMatch(FileRead(A_ScriptDir "\Settings\Configuration.txt", "UTF-8"), "m)^Mode=(.+)$", &mm)
                    m := Trim(mm[1])
            }
        }
        if (m != "") {
            try ModeDropdown.Choose(m)
            if (ModeDropdown.Text != "") {
                AddToLog("Mode box was empty - using " m " (the last mode you picked)")
                try OnModeChange()
                try OnConfirmClick()
            }
        }
    }
    if (ModeDropdown.Text = "") {
        AddToLog("Please select a gamemode before starting the macro!")
        return false
    }
    if (!confirmClicked) {
        AddToLog("Please click the confirm button before starting the macro!")
        return false
    }
    return true
}

GetNavKeys() {
    return StrSplit(FileExist("Settings\UINavigation.txt") ? FileRead("Settings\UINavigation.txt", "UTF-8") : "\,#,}", ",")
}

CheckEndAndRoute() {
    if (ok := FT(&X, &Y, 140, 130, 662, 172, 0, 0, LobbyText)) {
        AddToLog("Found end screen")
        if (mode = "Contract") {
            return NextStep(HandleContractEnd)
        } else if (mode = "Dungeon") {
            return NextStep(MonitorDungeonEnd)
        } else if (mode = "Portal") {
            return NextStep(HandlePortalReJoin)
        } else {
            return NextStep(MonitorEndScreen)
        }
    }
    return false
}

SleepTime() {
    time := [0, 5000, 10000, 15000, 20000, 25000, 30000, 35000, 40000, 45000, 50000, 55000, 60000]  ; Array of sleep values
    timeIndex := LobbySleepTimer.Value  ; Get the selected speed value

    if timeIndex is number  ; Ensure it's a number
        return time[timeIndex]  ; Use the value directly from the array
}

ClickReplay() {
    rp := 0
    try rp := SH_Find("^replay$|^retry$", 100, 60, 600, 120)   ; [UI update] by its label first
    if (rp) {
        FixClick(rp.x, rp.y)
        Sleep(500)
    }
    FixClick(480,121)
    sleep 1000
    FixClick(480,121)
    ClickUntilGone(0, 0, 0, 0, 1000, 1000, Replay, 0, -35, RetryBackup)
}

ClickNextLevel() {
    ClickUntilGone(0, 0, 0, 0, 1000, 1000, Nextlevelforstory, 0, -35)
    ClickUntilGone(0, 0, 0, 0, 1000, 1000, NextLevel, 0, -35, NextRoomInf)
    FixClick(480,121)
    sleep 1000
    FixClick(480,121)
}

ClickReturnToLobby() {
    ; [UI update] "Return to lobby" moved right (about x 312); find it by its label first
    lb := 0
    try lb := SH_Find("return to lobby|back to lobby", 100, 60, 600, 120)
    if (lb) {
        FixClick(lb.x, lb.y)
        Sleep(500)
    }
    FixClick(200,121)
    ClickUntilGone(0, 0, 80, 85, 739, 224, LobbyText, 0, -35, LobbyText2)
}

ClickStartStory() {
    ClickUntilGone(0, 0, 0, 0, 1000, 1000, StartStoryButton, 0, -35)
}

CheckForRobloxApp() {
    return FT(&X, &Y, 14, 55, 57, 115, 0, 0, RobloxApp) ? true : false
}

CheckForNotification() {
    return FT(&X, &Y, 748, 94, 778, 551, 0, 0, ExitNotification) ? true : false
}

; [Summer Hunt] Fool's Hunt and Summer Hunt play the same way (matchmaking, cards, endless waves).
; Only the Fool's Hunt "bring your units" freeze and hotbar check stay Fool's Hunt only.
IsHunt() => (ModeDropdown.Text = "Fool's Hunt" || ModeDropdown.Text = "Summer Hunt")
