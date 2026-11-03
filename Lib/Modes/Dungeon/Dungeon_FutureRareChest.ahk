#Requires AutoHotkey v2.0

global BossRoomCompleted := false
global SaveChestsForBoss := true


LookForDungeonRooms() {
    global SaveChestsForBoss
    ; [Fix] a unit's upgrade panel left open from the last fight covers the left half of the
    ; Dungeon Run menu (seen in watch pictures) - close it before reading the rooms
    try {
        Loop 3 {
            if !UP_ClosePanel()
                break
            Sleep(200)
        }
    }
    if SaveChestsBox.Value == 1 {
        SaveChestsForBoss := true
    } else {
        SaveChestsForBoss := false
    }
    visibleRooms := 0
    unavailableRooms := 0
    cursedRooms := 0
    openingRooms := 0
    bossRooms := 0
    foundRooms := []

    roomSearchAreas := [
        ; Left Box (3 Rooms)
        {x1: 200, y1: 340, x2: 222, y2: 437, searchX1: 204, searchY1: 343, searchX2: 290, searchY2: 435, clickX: 250, clickY: 360}, ; (Entire Box: 204, 348, 290, 433)
        
        ; Right Box (3 Rooms)
        {x1: 507, y1: 340, x2: 530, y2: 437, searchX1: 514, searchY1: 343, searchX2: 600, searchY2: 435, clickX: 555, clickY: 360}, ; (Entire Box : 514, 347, 600, 433)

        ;Center Box (3/1 Roooms)
        {x1: 352, y1: 343, x2: 379, y2: 437, searchX1: 358, searchY1: 343, searchX2: 447, searchY2: 435, clickX: 400, clickY: 360}, ; Border Search : 352, 343, 379, 437 (Entire Box : 358, 346, 447, 435)

        
        ; Left / Right Box (2 Rooms)
        {x1: 275, y1: 340, x2: 300, y2: 437, searchX1: 280, searchY1: 343, searchX2: 370, searchY2: 435, clickX: 322, clickY: 360}, ; (Entire Box : 280, 346, 369, 434)

        {x1: 430, y1: 340, x2: 450, y2: 437, searchX1: 438, searchY1: 343, searchX2: 525, searchY2: 435, clickX: 477, clickY: 360} ; (Entire Box : 438, 347, 523, 435) 431, 348, 450, 438
    ]

    for index, room in roomSearchAreas {
        
        if (FT(&X, &Y, room.x1, room.y1, room.x2, room.y2, 0.20, 0.20, DungeonRoomBorder)) {
            foundRooms.Push({index: index, type: "Available", coords: room})
            if (debugMessages) {
                AddToLog("Room " index " found via FindText (Available)")
            }
            visibleRooms++
        }
        else if (FT(&X, &Y, room.x1, room.y1, room.x2, room.y2, 0.10, 0.10, DungeonRoomBorderDark)) {
            foundRooms.Push({index: index, type: "Unavailable", coords: room})
            if (debugMessages) {
                AddToLog("Room " index " found via FindText (Unavailable)")
            }
            visibleRooms++
            unavailableRooms++
        }
        else if (FT(&X, &Y, room.x1, room.y1, room.x2, room.y2, 0.10, 0.10, DungeonRoomBorderCursed)) {
            foundRooms.Push({index: index, type: "Cursed", coords: room})
            if (debugMessages) {
                AddToLog("Room " index " found via FindText (Cursed)")
            }
            visibleRooms++
            cursedRooms++
        }
        else if (FT(&X, &Y, room.x1, room.y1, room.x2, room.y2, 0.10, 0.10, DungeonRoomBorderChestOpen)) {
            foundRooms.Push({index: index, type: "Opening", coords: room})
            if (debugMessages) {
                AddToLog("Room " index " found via FindText (Opening)")
            }
            visibleRooms++
            openingRooms++
        }
      /*   else if (FT(&X, &Y, room.x1, room.y1, room.x2, room.y2, 0, 0, DungeonRoomBorderBoss)) { 
            foundRooms.Push({index: index, type: "Boss", coords: room})
            if (debugMessages) {
                AddToLog("Room " index " found via FindText (Boss)")
            }
            visibleRooms++
            bossrooms++
        }  */
        
    }

    if (debugMessages) {
        AddToLog(Format("Visible Rooms Count: {}", visibleRooms))
        AddToLog(Format("Cursed Rooms Count: {}", cursedRooms))
        AddToLog(Format("Boss Rooms Count: {}", bossRooms))
        AddToLog(Format("Unavailable Rooms Count: {}", unavailableRooms))
    }

    return SelectBestRoom(visibleRooms, foundRooms)
}

SelectBestRoom(totalrooms, foundRooms) {
    if (PrioritiseFutureRareChests.Value) {

        futurePath := CheckFutureRareChest()

        if (futurePath != "") {
            AddToLog("Prioritising Future Rare Chest: " futurePath)

            if (ClickFutureRareChestPath(futurePath, foundRooms)){
                return true
            }

            AddToLog("Future Rare Chest path unavailable / Continuing")
        }
    }
    global SpecialsJustChecked
    if (!IsSet(SpecialsJustChecked) || !SpecialsJustChecked) ; [Improved] skip if MonitorDungeonEnd just did this check
        CheckDungeonSpecials()
    SpecialsJustChecked := false
    foundRoom := false
    unsafeRooms := Map()
    bestRoomFound := false
    bestRoomIndex := -1
    ; Use foundRooms data for dynamic room coordinates
    roomDefs := []
    for index, room in foundRooms {
        roomDefs.Push({
            search: {x1: room.coords.searchX1, y1: room.coords.searchY1, x2: room.coords.searchX2, y2: room.coords.searchY2},
            click: {x : room.coords.clickX, y: room.coords.clickY},
            type: {roomType : room.type}
        })
    }

    for index, priority in routePriorityOrder {
        roomFoundForPriority := false
        bestRoomForPriority := Map() ; Use a Map to store rooms by index
    
        for i, room in roomDefs {
            if (unsafeRooms.Has(i))
                continue
    
            if (!roomTexts.Has(priority)) {
                if (debugMessages)
                    AddToLog(Format("{} room not available", priority))
                continue
            }
            if (priority = "Rare_Chest") {
                if (ImageSearch(&X, &Y, 247, 325, 561, 457, "*20 " RareChestImage)) {
                    bestRoomForPriority[i] := room
                    ; Rare chest found
                }
            } else { 
                if (ok := FT(&X, &Y, room.search.x1, room.search.y1, room.search.x2, room.search.y2, 0.20, 0.20, roomTexts.Get(priority))) {
                if (debugMessages){
                    AddToLog("Found room: " i)
                }

                ; Track the room if it matches the priority
                bestRoomForPriority[i] := room
                }   
            }
        }
    
        ; Check if there are any rooms for this priority
        if (bestRoomForPriority.Count > 0) {
            for i, room in bestRoomForPriority {
                if (!room)  ; Skip invalid entries
                    continue
                
                if (debugMessages) {
                    AddToLog(Format("Found room for priority {}: {}", priority, i))
                }
                
                ; Click logic for each valid room
                FixClick(room.click.x, room.click.y)
                Sleep (500)
                foundRoom := true
                if (room.type.roomType = "Cursed") {
                    curseResult := DetectCurse()
                    if (curseResult.curse != "no curse found") {
                        if (curseResult.skip) {
                            unsafeRooms[i] := true
                            foundRoom := false
                            bestRoomFound := false
                            FixClick(room.click.x, room.click.y)
                            Sleep(1000)
                            continue
                        }
                    }
                }
                if (room.type.roomType = "Boss" || priority = "Boss") {
                    global BossRoomCompleted := true
                    AddToLog("Boss room detected, setting BossRoomCompleted to true")
                }
                if (debugMessages) {
                    AddToLog(Format("Entering {} room", room.type.roomType))
                }
                AddToLog(Format("Entering {} room", priority))
                return CheckForEnterButton()
            }
        }
        if (!roomFoundForPriority) {
            if (debugMessages) {
                AddToLog(Format("No room found for priority: {}", priority))
            }
            continue
        }
    }

    ; Fallback logic if no room is found
    if (!foundRoom) {
        ;Check if finish dungeon text is there and close it
        AddToLog("No safe chest/hoard found, clicking default positions")
        Sleep(1000)
        ; [Improved] pick the first room that is open and not rejected, instead of always room 1
        pick := 0
        for i, room in foundRooms {
            if (unsafeRooms.Has(i) || room.type = "Unavailable")
                continue
            if (room.type = "Available" || room.type = "Opening") {
                pick := i
                break
            }
            if (!pick)
                pick := i
        }
        if (pick) {
            AddToLog("Fallback: entering room " pick " (" foundRooms[pick].type ")")
            FixClick(foundRooms[pick].coords.clickX, foundRooms[pick].coords.clickY)
            return CheckForEnterButton()
        } else {
            FixClick(400, 355)
            return CheckForEnterButton()
        }
    }
}

CheckForEnterButton() {
    global BossRoomCompleted, EnterRetries
    if (!IsSet(EnterRetries))
        EnterRetries := 0
    WaitFor("Dungeon Room Enter")
    if (CheckIfFinalRoom()) {
        BossRoomCompleted := true
        AddToLog("Final room detected, setting BossRoomCompleted to true")
    }
    ; [UI update] the room card was redesigned (green "Enter" under Depth / Difficulty) - find it by its label
    en := 0
    try en := SH_Find("^enter$", 0, 150, 800, 400)
    if (en) {
        AddToLog("Found Enter button, joining dungeon")
        EnterRetries := 0
        loop 3 {
            FixClick(en.x, en.y)
            Sleep(1200)
            if !(en := SH_Find("^enter$", 0, 150, 800, 400))
                break
        }
        Sleep(2000)
        AddToLog("Starting dungeon run")
        NextStep(RestartStage)
    } else if (ok := FT(&X, &Y, 31, 241, 801, 543, 0.20, 0.20, Enter)) {
        AddToLog("Found Enter button, joining dungeon")
        EnterRetries := 0
        ClickUntilGone(0, 0, 31, 241, 801, 543, Enter, 0, -30)
        Sleep(2000)
        ; Start dungeon run
        AddToLog("Starting dungeon run")
        NextStep(RestartStage)
    } else {
        AddToLog("Enter button not found, retrying...")
        ClickUntilGone(0, 0, 588, 107, 780, 249, DungeonRedX)
        Sleep(1500)
        if (EnterRetries < 2) { ; [Improved] try the room map again before giving up on the dungeon
            EnterRetries += 1
            AddToLog("Re-checking rooms (attempt " EnterRetries "/2)")
            return LookForDungeonRooms()
        }
        EnterRetries := 0
        ClickReturnToLobby()
        Sleep(2000)
        return NextStep(CheckLobby)
    }
}

; Function to check for special dungeon elements after replay
CheckDungeonSpecials() {
    ; [Fix] a unit's upgrade panel left open from the last fight covers the left half of the
    ; Dungeon Run menu (seen in watch pictures) - close it before reading the rooms
    try {
        Loop 3 {
            if !UP_ClosePanel()
                break
            Sleep(200)
        }
    }
    AddToLog("Checking for dungeon shop, shrine, open chest")
    
    ; Give time for special elements to appear
    Sleep(2000)
    
    foundShop := false
    foundShrine := false
    foundChest := false

    ; Check the area for shop, shrine, or chest
    Loop 5 {
        ; Check for shop
        if (!foundShop && FT(&X, &Y, 140, 200, 375, 250, 0, 0, Shop)) {
            AddToLog("Found Shop")
            Sleep(1000)
            HandleShop()
            Sleep(1000)
            foundShop := true
        }
        Sleep(1000)
        ; Check for shrine
        if (!foundShrine && FT(&X, &Y, 0, 0,700, 700, 0.3, 0, Shrine)) {
            if (DenyShrines.Value) {
                AddToLog("Found Shrine, Denying")
                ClickUntilGone(0, 0, 334, 395, 672, 483, DenyShrine, 0, -30)
            } else {
                ShrinePriority()
            }
            Sleep(1000)
            foundShrine := true
        }
        Sleep(1000)
        ; Check for Chest Opening
        if (!foundChest && IsChestScreenVisible()) {
            AddToLog("Found Chest Opening")
            HandleChestScreen()
            foundChest := true
        }
        
        ; If all elements are found, exit early
        if (foundShop && foundShrine && foundChest)
            break

        Sleep(1000)  ; Wait and check again
    }
    
    if (!foundShop && !foundShrine && !foundChest)
        AddToLog("No shop, shrine, or chest opening found")
}

HandleShop() {
    AddToLog("Handling shop - buying available items")
    
    ; Give the shop time to fully load
    Sleep(1500)

    if FT(&X, &Y, 184, 118, 623, 523, 0, 0, Fishhook){
        AddToLog("Detected Fishhook buying")
        FixClick(X+150,Y)
    }
    
    Sleep(1500)

    ; Buy item in slot 3 (bottom)
    FixClick(560, 335)
    Sleep(1000)
    
    ; Buy item in slot 2 (middle)
    FixClick(560, 280)
    Sleep(1000)
    
    ; Buy item in slot 1 (top)
    FixClick(560, 225)
    Sleep(1000)
    
    ; Click continue to close the shop
    AddToLog("Closing shop")
    FixClick(485, 410)

    ClickDungeonContinue()
    Sleep(1000)
    return true
}

IsChestScreenVisible() {
    return FT(&X, &Y, 140, 200, 375, 250, 0, 0, ChestRoom) or FT(&X, &Y, 358, 238, 604, 261, 0, 0, ChestRoomLuck)
}

IsCommonChestDone() {
    return FT(&X, &Y, 357, 265, 407, 315, 0.10, 0.10, EmptyCommonChest)
}

IsRareChestDone() {
    return FT(&X, &Y, 353, 324, 408, 379, 0.10, 0.10, EmptyRareChest)
}

HandleChestScreen() {
    global BossRoomCompleted, SaveChestsForBoss
    
    ; Determine if we should open chests now
    shouldOpenChests := BossRoomCompleted || !SaveChestsForBoss
    
    if (shouldOpenChests) {
        AddToLog("Opening all available chests")
        
        ; Process first chest position - keep clicking until exhausted
        commonChestExhausted := false
        
        while (!commonChestExhausted ) {
            ; Click first chest OPEN button
            FixClick(565, 260)
            Sleep(2000)
            
            ; Check if we're still on the chest screen
            if (!IsChestScreenVisible()) {
                ClaimChestReward()
            } else {
                AddToLog("Common chest is now empty, moving on...")
                commonChestExhausted := true
            }
        }

        ; Process rare chest position - keep clicking until exhausted
        rareChestExhausted := false
        
        while (!rareChestExhausted ) {
            ; Click first chest OPEN button
            FixClick(565, 320)
            Sleep(2000)
            
            ; Check if we're still on the chest screen
            if (!IsChestScreenVisible()) {
                ClaimChestReward()
            } else {
                AddToLog("Rare chest is now empty, moving on...")
                rareChestExhausted := true
            }
        }

        AddToLog("All chests opened")

        if (BossRoomCompleted) {
            BossRoomCompleted := false
            ClickDungeonContinue()
        } else {
            ClickDungeonContinue()
            if (CheckForFinishDungeonV2()) {
                    AddToLog("Handled dungeon completion")
                    sleep 2000
                    NextStep(StartSelectedMode)
                }
        }

        } else {
            AddToLog("Saving chests for boss room - clicking continue")
            ClickDungeonContinue()
            if (CheckForFinishDungeonV2()) {
                    AddToLog("Handled dungeon completion")
                    sleep 2000
                    NextStep(StartSelectedMode)
                }
        }
        Sleep(1000)
        Reconnect()
        return true
}

ClaimChestReward() {
    maxClicks := 40  ; Safety limit
    clicks := 0
    
    while (clicks < maxClicks) {
        ; Click to claim reward
        FixClick(607, 553)
        Sleep(1500)
        
        ; Check if chest screen has returned
        if (IsChestScreenVisible()) {
            return true
        }

        ;Check for return to lobby test
        if (CheckForReturnToLobby()) {
            if (IsChestScreenVisible()) {
                return true
            }
            if (debugMessages) {
                AddToLog("Found return to lobby text, might have max cursed tokens...")
            }
            FixClick(490, 120) ; If you have maxed cursed tokens it will close the interface
            Sleep(1500)
            return true
        }
        
        clicks++
    }
    
    AddToLog("Max clicks reached while claiming rewards")
    return false
} 

; Custom monitor for dungeon ending
MonitorDungeonEnd() {
    global mode, Wins, loss, challengeStartTime, inChallengeMode

    failed := false
    
    StageGuard.Disarm("Stage")   ; [Framework] stage is over - its timeout no longer applies
    StageGuard.Arm("EndScreen", FW_EndScreenTimeoutMs)   ; [Framework]
    Loop {
        Sleep(3000)  
        StageGuard.Check("EndScreen", "dungeon end screen not handled")   ; [Framework]
        FixClick(607, 553)  ; Move click

        ; Check for unit exit UI element
        if (ok := FT(&X, &Y, 300, 190, 360, 250, 0, 0, UnitExit)) {
            ClickUntilGone(0, 0, 300, 190, 360, 250, UnitExit, -4, -35)
        }
        
        if (ok := FT(&X, &Y, 150, 180, 350, 260, 0, 0, DefeatText) or (ok:=FT(&X, &Y, 319, 176, 492, 279, 0, 0, DefeatText2))) {
            failed := true
        }

        ; Check for next text UI element
        if (ok := FT(&X, &Y, 260, 400, 390, 450, 0, 0, NextText)) {
            ClickUntilGone(0, 0, 260, 400, 390, 450, NextText, 0, -40)
        }

        ; Check for returning to lobby
        if (ok := FT(&X, &Y, 80, 85, 739, 224, 0, 0, LobbyText) or (ok := FT(&X, &Y, 80, 85, 739, 224, 0, 0, LobbyText2))) {
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

            if (StopAfterDefeat.Value && failed) {
                AddToLog("Dungeon run failed, stopping to save lives...")
                ClickReturnToLobby()
                SendFinalWebhookBeforeExit()
                CheckForLobby()
                Sleep(2000)
                return Reload()
            } else  {
                AddToLog("Dungeon run completed, clicking replay")
            
                ; Click replay button - [UI update] the dungeon end screen shows a green "Return to lobby" and a
                ; yellow "Open Dungeon" side by side. Press Open Dungeon (found by its text), never the lobby
                ; one: leaving mid-dungeon loses the whole run. (Seen in AA Spiral 14's notes.)
                DG_ClickOpenDungeon()
                ClickUntilGone(0, 0, 0, 0, 1000, 1000, OpenDungeon, 0, -35)
                
                ; After clicking replay, check for shop/shrine/chest
                CheckDungeonSpecials()
                global SpecialsJustChecked := true ; [Improved] SelectBestRoom will not repeat it

                Sleep(2500)
    
                if (CheckForFinishDungeonV2()) {
                    AddToLog("Handled dungeon completion")
                    sleep 2000
                    return NextStep(StartSelectedMode)
                }
                
                ; Start a new dungeon run
                AddToLog("Starting next dungeon")
                try WM_ReloadAt("dungeon")   ; [Watch mode] load new fixes between rooms
                return LookForDungeonRooms()
            }
            Reconnect()
        }
    }
}

ClickDungeonContinue() {
    ClickUntilGoneFinishDungeon(0, 0, 380, 385, 615, 490, DungeonContinue, -3, -35)
}

ClickDungeonDeathContinue() {
    ClickUntilGone(0, 0, 308, 391, 494, 437, DungeonDeathContinue, -0, -30)
}

CheckIfFinalRoom() {
    if (ok := FT(&X, &Y, 434, 215, 479, 230, 0, 0, FinalRoom)) {
        return true
    }
    return false
}

DetectCurse() {
    AddToLog("Checking room for curse...")  ; Log the curse check start
    curseCheckTime := A_TickCount
    
    Loop {
        if (A_TickCount - curseCheckTime > 3000) {
            AddToLog("Could not detect curse after 3 seconds - proceeding...")
            return {curse: "no curse found", skip: false}
        }

        curseTexts := Map(
            "Flying", CurseOfFlight,
            "Wind", CurseOfWind,
            "Money", CurseOfMoney,
            "Health", CurseOfHealth,
            "Shielding", CurseOfShielding, ;done
            "Regen", CurseOfRegen,
            "Exploding", CurseofExplosion,   ; [Fix] the picker calls it "Exploding" - the old name never matched
            "Frenzy", CurseOfFrenzy,         ; [Wiki] +50% enemy speed
            "Burst", CurseOfBurst,           ; [Wiki] +100% burst trait
            "Armor", CurseOfArmor,           ; [Wiki] +100% armor trait
            "Chaos", CurseOfChaos,           ; [Wiki] all curses random
            "Vamparism", CurseOfVamparism    ; [Wiki] +3% regen
        )

        for curseName, curse in curseTexts {
            if (ok := FT(&X, &Y, 121, 168, 681, 493, 0.05, 0.05, curse)) {
                skip := ShouldSkipCurse(curseName)
                if (skip) {
                    AddToLog("Skipping because of curse: " curseName)
                } else {
                    AddToLog("Detected Curse: " curseName)
                }
                return {curse: curseName, skip: skip}
            }
        }
        Sleep 1000
    }
}

CheckForFinishDungeon() {
    ; Check for the finish dungeon popup
    if (ok := FT(&X, &Y, 240, 180, 565, 480, 0.20, 0.20, FinishDungeon) or (ok := FT(&X, &Y, 310, 395, 495, 440, 0.20, 0.20, EnterDungeon)) or (ok := FT(&X, &Y, 370, 225, 545, 300, 0.20, 0.20, DungeonDeath))) {
        
        ; Click the Finish button
        ClickUntilGone(0, 0, 240, 180, 565, 480, DungeonFinish, -3, -35)
        Sleep(1500)

        if (!dungeonDeathBroken) {
            ; Click Dungeon Death if needed
            ClickDungeonDeathContinue()
            Sleep(1500)
        }
        
        ; Click the X in the top right
        ClickUntilGone(0, 0, 640, 175, 700, 205, DungeonRedX, -3, -35)
        Sleep(1000)
        
        ; Return to lobby
        AddToLog("Returning to lobby after completing dungeon")
        ClickReturnToLobby()
        
        ; Check for lobby and restart
        return NextStep(CheckLobby)
    }
    
    return false
} 

CheckForFinishDungeonV2() {
    ; Check for the finish dungeon popup
    if (ok := FT(&X, &Y, 240, 180, 565, 480, 0.10, 0.10, FinishDungeon) or (ok := FT(&X, &Y, 310, 395, 495, 440, 0.10, 0.10, EnterDungeon)) or (ok := FT(&X, &Y, 370, 225, 545, 300, 0.10, 0.10, DungeonDeath))) {
        AddToLog("Detected dungeon finish Continuing...")
        ; Click the Finish button
        if (ok := FT(&X, &Y, 240, 180, 565, 480, 0.20, 0.20, FinishDungeon)){
            AddToLog("Detected Finish dungeon text clicking....")
            sleep 2000
            FixClick(344,251)
            sleep 1000
            FixClick(322,340)
            sleep 300
            FixClick(666, 145)
            Sleep(2000)
            if (ok := FT(&X, &Y, 126, 56, 675, 230, 0, 0, LobbyText2)) or (ok := FT(&X, &Y, 126, 56, 675, 230, 0, 0, LobbyText)){
                ClickReturnToLobby()
            }
        }

        if (ok := FT(&X, &Y, 370, 225, 545, 300, 0.20, 0.20, DungeonDeath)){
            ClickDungeonDeathContinue()
            ClickUntilGone(0, 0, 640, 175, 700, 205, DungeonRedX, -3, -35)
            Sleep(1000)
        }

        if (!dungeonDeathBroken) {
            ; Click Dungeon Death if needed
            ClickDungeonDeathContinue()
            Sleep(1500)
            ClickUntilGone(0, 0, 640, 175, 700, 205, DungeonRedX, -3, -35)
            Sleep(1000)
        }
        return true
    }
}

ClickUntilGoneFinishDungeon(x, y, searchX1, searchY1, searchX2, searchY2, textToFind, offsetX:=0, offsetY:=0, textToFind2:="") {
    waitTime := A_TickCount ; Start timer
    while (ok := FT(&X, &Y, searchX1, searchY1, searchX2, searchY2, 0, 0, textToFind) || textToFind2 && FT(&X, &Y, searchX1, searchY1, searchX2, searchY2, 0, 0, textToFind2)) {
        if ((A_TickCount - waitTime) > 300000) { ; 5-minute limit
            AddToLog("5 minute failsafe triggered, trying to open roblox...")
            return NextStep(RejoinPrivateServer)
        }
        if (offsetX != 0 || offsetY != 0) {
            FixClick(X + offsetX, Y + offsetY)  
        } else {
            FixClick(x, y) 
        }
        Sleep(1000)
        if (ok := FT(&X, &Y, 174, 102, 631, 545, 0, 0, FinishDungeonText)){
            AddToLog("Found Finish Dungeon Clicking....")
            sleep 100
            FixClick(X,Y)
        }
    }
}

ClickFinishDungeonText(){
    ;Check if finish dungeon text is there and close it
    sleep 1000
    if (ok := FT(&X, &Y, 174, 102, 631, 545, 0.10, 0.10, FinishDungeonText)){ 
            AddToLog("Found Finish Dungeon Clicking...." x " " y)
            sleep 100
            FixClick(326,260)
            return true
        }
    return false
}

ShrinePriority() {
    global enabledShrines

    ; Detect which shrine curse is currently on screen
    shrineType := ""

    if FT(&X, &Y, 327, 320, 506, 484, 0.1, 0.1, CurseOfArmor) {
        shrineType := "Armor"
    }
    else if FT(&X, &Y, 327, 320, 506, 484, 0.1, 0.1, CurseOfBurst) {
        shrineType := "Burst"
    }
    else if FT(&X, &Y, 327, 320, 506, 484, 0.1, 0.1, CurseOfChaos) {
        shrineType := "Chaos"
    }
    ;else if FT(&X, &Y, 140, 200, 375, 250, 0, 0, Vampire) {  gotta get the image of vamparism
    ;    shrineType := "Vamparism"
    ;}
    else if FT(&X, &Y, 327, 320, 506, 484, 0.1, 0.1, CurseOfFrenzy) {
        shrineType := "Frenzy"
    }

    ; No shrine detected
    if (shrineType = "") {
        AddToLog("Shrine found, but could not identify the curse. Denying...")
        ClickUntilGone(0, 0, 334, 395, 672, 483, DenyShrine, 0, -30)
        return
    }

    ; Check whether this shrine is on the reject list
    if (HasValue(enabledShrines, shrineType)) {
        AddToLog("Found avoided shrine: " shrineType " - Denying")
        ClickUntilGone(0, 0, 334, 395, 672, 483, DenyShrine, 0, -30)
    }
    else {
        AddToLog("Found shrine: " shrineType " - Accepting")
        ClickUntilGone(0, 0, 334, 395, 672, 483, ShrineAccept, 0, -30)
    }
}

CheckFutureRareChest() {
    global FutureRareChest1

    ; LEFT future room
    if (FT(&X, &Y, 150, 226, 329, 350, 0, 0, FutureRareChest1)) or (FT(&X, &Y, 150, 226, 329, 350, 0, 0, FutureRareChest2)){
        ;AddToLog("Future Rare Chest found - LEFT path")
        return "Left"
    }

    ; CENTER future room
    if (FT(&X, &Y, 329, 248, 489, 349, 0, 0, FutureRareChest1)) or (FT(&X, &Y, 329, 248, 489, 349, 0, 0, FutureRareChest2)){
        ;AddToLog("Future Rare Chest found - CENTER path")
        return "Center"
    }

    ; RIGHT future room
    if (FT(&X, &Y, 490, 242, 657, 348, 0, 0, FutureRareChest1)) or (FT(&X, &Y, 490, 242, 657, 348, 0, 0, FutureRareChest2)){
        ;AddToLog("Future Rare Chest found - RIGHT path")
        return "Right"
    }

    return ""
}

ClickFutureRareChestPath(path, foundRooms) {

    ; LEFT future path
    if (path = "Left") {
        for index, room in foundRooms {
            if (room.coords.clickX = 250 && room.coords.clickY = 360) {
                AddToLog("Taking LEFT path toward Future Rare Chest")
                FixClick(room.coords.clickX, room.coords.clickY)
                Sleep(500)
                return CheckForEnterButton()
            }
        }

        ; Left path isn't currently visible.
        AddToLog("Future Rare Chest is LEFT, but LEFT current room is not visible")
        return false
    }

    ; CENTER future path
    if (path = "Center") {
        for index, room in foundRooms {
            if (room.coords.clickX = 400 && room.coords.clickY = 360) {
                AddToLog("Taking CENTER path toward Future Rare Chest")
                FixClick(room.coords.clickX, room.coords.clickY)
                Sleep(500)
                return CheckForEnterButton()
            }
        }

        AddToLog("Future Rare Chest is CENTER, but CENTER current room is not visible")
        return false
    }

    ; RIGHT future path
    if (path = "Right") {
        for index, room in foundRooms {
            if (room.coords.clickX = 555 && room.coords.clickY = 360) {
                AddToLog("Taking RIGHT path toward Future Rare Chest")
                FixClick(room.coords.clickX, room.coords.clickY)
                Sleep(500)
                return CheckForEnterButton()
            }
        }

        AddToLog("Future Rare Chest is RIGHT, but RIGHT current room is not visible")
        return false
    }

    return false
}


; ---- [UI update] the dungeon end screen's "Open Dungeon" button -------------------------------------
DG_ClickOpenDungeon() {
    loop 3 {
        od := 0, lb := 0
        try od := SH_Find("open dungeon|open dung|^open$", 100, 60, 600, 140)
        try lb := SH_Find("return to lobby|back to lobby", 100, 60, 600, 140)
        if (od) {
            FixClick(od.x, od.y)
            AddToLog("Pressing Open Dungeon")
            Sleep(800)
            return true
        }
        if (lb) {
            ; the lobby button is there but Open Dungeon wasn't read (white on yellow can be hard to read):
            ; it sits right beside the lobby button - click to its right, never on it
            FixClick(lb.x + 170, lb.y)
            AddToLog("Pressing Open Dungeon (beside Return to lobby)")
            Sleep(800)
            return true
        }
        Sleep(600)
    }
    ClickReplay()   ; old layout / not found - the old way
    return false
}

