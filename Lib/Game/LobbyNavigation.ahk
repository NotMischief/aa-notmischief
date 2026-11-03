#Requires AutoHotkey v2.0

; ============================================================================
;  LobbyNavigation.ahk  -  Walking to modes in the lobby, selecting map/act, play/matchmaking.
;  [Modularized] functions moved here unchanged from Lib\Functions.ahk, Lib\GameMango.ahk.
;  Loaded from Main.ahk. Contains function definitions only (no start-up code).
; ============================================================================


StoryMovement() {
    FixClick(85, 295)
    sleep (1000)
    SendInput ("{w down}")
    Sleep(300)
    SendInput ("{w up}")
    Sleep(300)
    SendInput ("{d down}")
    SendInput ("{w down}")
    Sleep(4500)
    SendInput ("{d up}")
    SendInput ("{w up}")
    Sleep(500)
}


EventMovement() {
    FixClick(592, 204) ; Close Matchmaking UI (Just in case)
    Sleep (200)
    FixClick(85, 295) ; Click Play
    sleep (1000)
    SendInput ("{a up}")
    Sleep 100
    SendInput ("{a down}")
    Sleep 6000
    SendInput ("{a up}")
    KeyWait "a" ; Wait for "d" to be fully processed
    Sleep 1200
}


OppositeStoryMovement() {
    FixClick(85, 295)
    Sleep(1000)
    SendInput("{s down}")
    Sleep(300)
    SendInput("{s up}")
    Sleep(300)
    SendInput("{d down}")
    SendInput("{s down}")
    Sleep(4500)
    SendInput("{d up}")
    SendInput("{s up}")
    Sleep(500)
}


ChallengeMovement() {
    FixClick(765, 475)
    Sleep (500)
    FixClick(300, 415)
    SendInput ("{a down}")
    sleep (7000)
    SendInput ("{a up}")
}


RaidMovement() {
    FixClick(765, 475) ; Click Area
    Sleep(300)
    FixClick(495, 410)
    Sleep(500)
    SendInput ("{a down}")
    Sleep(400)
    SendInput ("{a up}")
    Sleep(500)
    SendInput ("{w down}")
    Sleep(5000)
    SendInput ("{w up}")
}


InfCastleMovement() {
    FixClick(765, 475)
    Sleep (300)
    FixClick(370, 330)
    Sleep (500)
    SendInput ("{w down}")
    Sleep (500)
    SendInput ("{w up}")
    Sleep (500)
    SendInput ("{a down}")
    sleep (4000)
    SendInput ("{a up}")
    Sleep (500)
}


CursedWombMovement() {
    FixClick(85, 295)
    Sleep (500)
    SendInput ("{a down}")
    sleep (3000)
    SendInput ("{a up}")
    sleep (1000)
    SendInput ("{s down}")
    sleep (4000)
    SendInput ("{s up}")
}


StartStory(map, StoryActDropdown) {
    FixClick(640, 70) ; Closes Player leaderboard
    Sleep(500)
    navKeys := GetNavKeys()
    for key in navKeys {
        SendInput("{" key "}")
    }
    Sleep(500)

    downArrows := GetStoryDownArrows(map) ; Map selection down arrows
    Loop downArrows {
        SendInput("{Down}")
        Sleep(200)
    }

    SendInput("{Enter}") ; Select storymode
    Sleep(500)

    Loop 4 {
        SendInput("{Up}") ; Makes sure it selects act
        Sleep(200)
    }

    SendInput("{Left}") ; Go to act selection
    Sleep(1000)
    
    actArrows := GetStoryActDownArrows(StoryActDropdown) ; Act selection down arrows
    Loop actArrows {
        SendInput("{Down}")
        Sleep(200)
    }
    
    SendInput("{Enter}") ; Select Act
    Sleep(500)
    for key in navKeys {
        SendInput("{" key "}")
    }
}


StartStoryNoUINavigation(map, act) {
    AddToLog("Selecting map: " map " and act: " act)
    
    ; Closes Player leaderboard
    FixClick(640, 70)
    Sleep(500)

    if (CheckForNotification()) {
        ClickUntilGone(0, 0, 748, 94, 778, 551, ExitNotification, -3, -30)
        Sleep (1000)
    }

    ; Get Story map 
    StoryMap := GetMapData("StoryMap", map)
    
    ; Scroll if needed
    if (StoryMap.scrolls > 0) {
        AddToLog("Scrolling down " StoryMap.scrolls " for " map)
        MouseMove(700, 210)
        loop StoryMap.scrolls {
            SendInput("{WheelDown}")
            Sleep(250)
        }
    }
    Sleep(1000)
    
    ; Click on the map
    FixClick(StoryMap.x, StoryMap.y)
    Sleep(1000)
    
    ; Get act details
    StoryAct := GetMapData("StoryAct", act)
    
    ; Scroll if needed for act
    if (StoryAct.scrolls > 0) {
        AddToLog("Scrolling down " StoryAct.scrolls " times for " act)
        MouseMove(300, 240)
        loop StoryAct.scrolls {
            SendInput("{WheelDown}")
            Sleep(250)
        }
    }
    Sleep(1000)
    
    ; Click on the act
    FixClick(StoryAct.x, StoryAct.y)
    Sleep(1000)
    
    return true
}


GetMapData(type, name) {
    data := Map(
        "StoryMap", Map(
            "Planet Greenie", {x: 630, y: 250, scrolls: 0},
            "Walled City", {x: 630, y: 300, scrolls: 0},
            "Snowy Town", {x: 630, y: 350, scrolls: 0},
            "Sand Village", {x: 630, y: 400, scrolls: 0},

            "Navy Bay", {x: 630, y: 375, scrolls: 1},
            "Fiend City", {x: 630, y: 425, scrolls: 1},
            "Spirit World", {x: 630, y: 370, scrolls: 2},

            "Ant Kingdom", {x: 630, y: 420, scrolls: 2},
            "Magic Town", {x: 630, y: 375, scrolls: 3},

            "Haunted Academy", {x: 630, y: 420, scrolls: 3},
            "Magic Hills", {x: 630, y: 370, scrolls: 4},
            "Space Center", {x: 630, y: 420, scrolls: 4},

            "Alien Spaceship", {x: 630, y: 375, scrolls: 5},
            "Fabled Kingdom", {x: 630, y: 425, scrolls: 5},
            "Ruined City", {x: 630, y: 380, scrolls: 6},

            "Puppet Island", {x: 630, y: 435, scrolls: 6},
            "Virtual Dungeon", {x: 630, y: 315, scrolls: 8},

            "Snowy Kingdom", {x: 630, y: 365, scrolls: 8},
            "Dungeon Throne", {x: 630, y: 400, scrolls: 8},
            "Mountain Temple", {x: 630, y: 290, scrolls: 10},

            "Rain Village", {x: 630, y: 335, scrolls: 10},
            "Shibuya District", {x: 630, y: 385, scrolls: 10}
        ),
        "StoryAct", Map(
            "Infinity", {x: 285, y: 235, scrolls: 0},
            "Act 1", {x: 285, y: 270, scrolls: 0},
            "Act 2", {x: 285, y: 305, scrolls: 0},
            "Act 3", {x: 285, y: 340, scrolls: 0},
            "Act 4", {x: 285, y: 385, scrolls: 0},

            "Act 5", {x: 300, y: 350, scrolls: 1},
            "Act 6", {x: 300, y: 385, scrolls: 1}
        ),
        "RaidMap", Map(
            "Ant Kingdom", {x: 630, y: 250, scrolls: 0},
            "Sacred Planet", {x: 630, y: 300, scrolls: 0},
            "Strange Town", {x: 630, y: 350, scrolls: 0},
            "Ruined City", {x: 630, y: 400, scrolls: 0},
            "Cursed Festival", {x: 630, y: 325, scrolls: 1},
            "Future City (Tyrant)", {x: 630, y: 400, scrolls: 1},
            "Storm Hideout", {x: 630, y: 350, scrolls: 2},
            "Future City", {x: 630, y: 400, scrolls: 2},
            "Nightmare Train", {x: 630, y: 350, scrolls: 3},
            "Sand Village", {x: 630, y: 400, scrolls: 3},
        ),
        "RaidAct", Map(
            "Act 1", {x: 285, y: 235, scrolls: 0},
            "Act 2", {x: 285, y: 270, scrolls: 0},
            "Act 3", {x: 285, y: 305, scrolls: 0},
            "Act 4", {x: 285, y: 340, scrolls: 0},
            "Act 5", {x: 285, y: 375, scrolls: 0}
        ),
        "LegendMap", Map(
            "Magic Hills", {x: 630, y: 240, scrolls: 0},
            "Spirit Invasion", {x: 630, y: 290, scrolls: 0},
            "Space Center", {x: 630, y: 340, scrolls: 0},
            "Fabled Kingdom", {x: 630, y: 390, scrolls: 0},
            "Ruined City", {x: 630, y: 350, scrolls: 1},

            "Virtual Dungeon", {x: 630, y: 405, scrolls: 1},
            "Dungeon Throne", {x: 630, y: 440, scrolls: 1},
            "Rain Village", {x: 630, y: 405, scrolls: 2}
        ),
        "LegendAct", Map(
            "Act 1", {x: 285, y: 235, scrolls: 0},
            "Act 2", {x: 285, y: 270, scrolls: 0},
            "Act 3", {x: 285, y: 305, scrolls: 0},
            "Act 4", {x: 285, y: 340, scrolls: 0},
            "Act 5", {x: 285, y: 375, scrolls: 0},
            "Act 6", {x: 285, y: 395, scrolls: 0},
            "Random", GetRandomAct()
        )
    )

    return data.Has(type) && data[type].Has(name) ? data[type][name] : {}
}


GetRandomAct() {
    randomAct := Random(1, 3) ; Generates a random number between 1 and 3
    return {x: 285, y: 235 + (randomAct - 1) * 35, scrolls: 0}
}


StartLegend(map, LegendActDropdown) {
    
    FixClick(640, 70) ; Closes Player leaderboard
    Sleep(500)
    navKeys := GetNavKeys()
    for key in navKeys {
        SendInput("{" key "}")
    }
    Sleep(500)
    SendInput("{Down}")
    Sleep(500)
    SendInput("{Enter}") ; Opens Legend Stage

    downArrows := GetLegendDownArrows(map) ; Map selection down arrows
    Loop downArrows {
        SendInput("{Down}")
        Sleep(200)
    }
    
    SendInput("{Enter}") ; Select LegendStage
    Sleep(500)

    Loop 4 {
        SendInput("{Up}") ; Makes sure it selects act
        Sleep(200)
    }

    SendInput("{Left}") ; Go to act selection
    Sleep(1000)
    
    actArrows := GetLegendActDownArrows(LegendActDropdown) ; Act selection down arrows
    Loop actArrows {
        SendInput("{Down}")
        Sleep(200)
    }

    SendInput("{Enter}") ; Select Act
    Sleep(500)
    for key in navKeys {
        SendInput("{" key "}")
    }
}


StartLegendNoUINavigation(map, act) {
    AddToLog("Selecting map: " map " and act: " act)
    
    ; Closes Player leaderboard
    FixClick(640, 70)
    Sleep(500)

    FixClick(660, 140) ; Click Legend Stages
    Sleep(500)

    if (CheckForNotification()) {
        ClickUntilGone(0, 0, 748, 94, 778, 551, ExitNotification, -3, -30)
        Sleep (1000)
    }

    ; Get Legend Stage Map 
    LegendMap := GetMapData("LegendMap", map)
    
    ; Scroll if needed
    if (LegendMap.scrolls > 0) {
        AddToLog("Scrolling down " LegendMap.scrolls " for " map)
        MouseMove(700, 210)
        loop LegendMap.scrolls {
            SendInput("{WheelDown}")
            Sleep(250)
        }
    }
    Sleep(1000)
    
    ; Click on the map
    FixClick(LegendMap.x, LegendMap.y)
    Sleep(1000)
    
    ; Get act details
    LegendAct := GetMapData("LegendAct", act)
    
    ; Scroll if needed for act
    if (LegendAct.scrolls > 0) {
        AddToLog("Scrolling down " LegendAct.scrolls " times for " act)
        MouseMove(300, 240)
        loop LegendAct.scrolls {
            SendInput("{WheelDown}")
            Sleep(250)
        }
    }
    Sleep(1000)
    
    ; Click on the act
    FixClick(LegendAct.x, LegendAct.y)
    Sleep(1000)
    
    return true
}


StartRaid(map, RaidActDropdown) {
    FixClick(640, 70) ; Closes Player leaderboard
    Sleep(500)
    navKeys := GetNavKeys()
    for key in navKeys {
        SendInput("{" key "}")
    }
    Sleep(500)

    downArrows := GetRaidDownArrows(map) ; Map selection down arrows
    Loop downArrows {
        SendInput("{Down}")
        Sleep(200)
    }

    SendInput("{Enter}") ; Select Raid

    Loop 4 {
        SendInput("{Up}") ; Makes sure it selects act
        Sleep(200)
    }

    SendInput("{Left}") ; Go to act selection
    Sleep(500)
    
    actArrows := GetRaidActDownArrows(RaidActDropdown) ; Act selection down arrows
    Loop actArrows {
        SendInput("{Down}")
        Sleep(200)
    }
    
    SendInput("{Enter}") ; Select Act
    Sleep(300)
    for key in navKeys {
        SendInput("{" key "}")
    }
}


PlayHere() {
    FixClick(400, 435)  ; Play Here or Find Match 
    Sleep (500)
    FixClick(330, 325) ;Click Play here
    Sleep (1200)
    ClickStartStory()
    Sleep (500)
    FixClick(330, 325) ;Click Play here
}


StartRaidNoUINavigation(map, act) {
    AddToLog("Selecting map: " map " and act: " act)
    
    ; Closes Player leaderboard
    FixClick(640, 70)
    Sleep(500)

    if (CheckForNotification()) {
        ClickUntilGone(0, 0, 748, 94, 778, 551, ExitNotification, -3, -30)
        Sleep (1000)
    }

    ; Get Story map 
    RaidMap := GetMapData("RaidMap", map)
    
    ; Scroll if needed
    if (RaidMap.scrolls > 0) {
        AddToLog("Scrolling down " RaidMap.scrolls " for " map)
        MouseMove(700, 210)
        loop RaidMap.scrolls {
            SendInput("{WheelDown}")
            Sleep(250)
        }
    }
    Sleep(1000)
    
    ; Click on the map
    FixClick(RaidMap.x, RaidMap.y)
    Sleep(1000)
    
    ; Get act details
    RaidAct := GetMapData("RaidAct", act)
    
    ; Scroll if needed for act
    if (RaidAct.scrolls > 0) {
        AddToLog("Scrolling down " RaidAct.scrolls " times for " act)
        MouseMove(300, 240)
        loop RaidAct.scrolls {
            SendInput("{WheelDown}")
            Sleep(250)
        }
    }
    Sleep(1000)
    
    ; Click on the act
    FixClick(RaidAct.x, RaidAct.y)
    Sleep(1000)
    
    return true
}



FindMatch() { ;CREDITS TO @yamori_.kou
    tries := 0
    Loop {
        ; [Fix] This loop used to run forever. If the macro got here while still on a
        ; results/defeat screen it kept "solving" a captcha that wasn't there.
        StageGuard.Check("Entrance", "matchmaking took too long")
        ; [Fix] already loaded into a match (the "matchmaking successful" check was missed)
        if (FT(&X, &Y, 326, 60, 547, 173, 0, 0, VoteStart) || FT(&X, &Y, 340, 537, 468, 557, 0, 0, Yen)) {
            AddToLog("Already in a match - continuing")
            return true
        }
        if (CheckForReturnToLobby() || CheckForNextText()) {
            AddToLog("Results screen is still showing - returning to lobby before matchmaking")
            ClickReturnToLobby()
            return NextStep(CheckLobby)
        }
        tries += 1
        if (tries > 8) {
            AddToLog("Matchmaking failed 8 times in a row - checking where we are")
            return NextStep(CheckLobby)
        }
        if (ModeDropdown.Text = "Fool's Hunt") {
        EventMovement()
        }
        sleep 300
        FixClick(400, 435)  ; 1. Click the "Play Here / Find Match" button
        Sleep(300)
        FixClick(460, 330)  ; 2. Click the "Find Match" button
        Sleep(300)
        ; 3. Read the captcha numbers via OCR and type them into the input box.
        ;    If OCR fails to detect a valid 5-7 digit number, close the UI and retry.
        if (!CaptchaDetect(252, 292, 300, 50, 400, 335)) {
            AddToLog("Captcha not detected, retrying...")
            FixClick(585, 190)  ; Click the close (X) button
            Sleep(500)
            continue
        }
        FixClick(300, 385)
        Loop 100{
            if (ok := FT(&X, &Y, 0, 0, 700, 680, 0, 0, InstaMatchmakingCheck)){
                AddToLog("Matchmaking succesful - immediately searching for map.")
                return true
            }  
            sleep 50
        }
    }
}

GetStoryDownArrows(map) {
    switch map {
        case "Planet Greenie": return 2
        case "Walled City": return 3
        case "Snowy Town": return 4
        case "Sand Village": return 5
        case "Navy Bay": return 6
        case "Fiend City": return 7
        case "Spirit World": return 8
        case "Ant Kingdom": return 9
        case "Magic Town": return 10
        case "Haunted Academy": return 11
        case "Magic Hills": return 12
        case "Space Center": return 13
        case "Alien Spaceship": return 14
        case "Fabled Kingdom": return 15
        case "Ruined City": return 16
        case "Puppet Island": return 17
        case "Virtual Dungeon": return 18
        case "Snowy Kingdom": return 19
        case "Dungeon Throne": return 20
        case "Mountain Temple": return 21
        case "Rain Village": return 22
        case "Shibuya District": return 23
    }
}


GetStoryActDownArrows(StoryActDropdown) {
    switch StoryActDropdown {
        case "Infinity": return 1
        case "Act 1": return 2
        case "Act 2": return 3
        case "Act 3": return 4
        case "Act 4": return 5
        case "Act 5": return 6
        case "Act 6": return 7
    }
}





GetLegendDownArrows(map) {
    switch map {
        case "Magic Hills": return 1
        case "Space Center": return 3
        case "Fabled Kingdom": return 4
        case "Virtual Dungeon": return 6
        case "Dungeon Throne": return 7
        case "Rain Village": return 8
    }
}


GetLegendActDownArrows(LegendActDropdown) {
    switch LegendActDropdown {
        case "Act 1": return 1
        case "Act 2": return 2
        case "Act 3": return 3
        case "Random": 
            return Random(1, 3) ; Generates a random number between 1 and 3
    }
}


GetRaidDownArrows(map) {
    switch map {
        case "Ant Kingdom": return 1
        case "Sacred Planet": return 2
        case "Strange Town": return 3
        case "Ruined City": return 4
    }
}


GetRaidActDownArrows(RaidActDropdown) {
    switch RaidActDropdown {
        case "Act 1": return 1
        case "Act 2": return 2
        case "Act 3": return 3
        case "Act 4": return 4
        case "Act 5": return 5
    }
}

 
CaptchaDetect(x, y, w, h, inputX, inputY) {
    detectionCount := 0
    AddToLog("Checking for numbers...")
    Loop 10 {
        try {
            FT_GetOffset(&ocrDX, &ocrDY) ; [Window follow] OCR area follows Roblox
            result := OCR.FromRect(x + ocrDX, y + ocrDY, w, h, "FirstFromAvailableLanguages", 
                {   
                    grayscale: true,
                    scale: 2.0
                })
            
            if result {
                ; Get text before any linebreak
                number := StrSplit(result.Text, "`n")[1]
                
                ; Clean to just get numbers
                number := RegExReplace(number, "[^\d]")
                
                if (StrLen(number) >= 5 && StrLen(number) <= 7) {
                    detectionCount++
                    
                    if (detectionCount >= 1) {
                        ; Send exactly what we detected in the green text
                        FixClick(inputX, inputY)
                        Sleep(300)
                        
                        AddToLog("Sending number: " number)
                        for digit in StrSplit(number) {
                            Send(digit)
                            Sleep(120)
                        }
                        Sleep(200)
                        return true
                    }
                }
            }
        }
        Sleep(200)  
    }
    AddToLog("Could not detect valid captcha")
    return false
}

