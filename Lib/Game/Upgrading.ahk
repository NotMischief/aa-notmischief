global UP_Skipped := false   ; [Upgrade skip]
#Requires AutoHotkey v2.0

; ============================================================================
;  Upgrading.ahk  -  Unit upgrades and upgrade-level checks.
;  [Modularized] functions moved here unchanged from Lib\Functions.ahk, Lib\GameMango.ahk.
;  Loaded from Main.ahk. Contains function definitions only (no start-up code).
; ============================================================================


AttemptUpgrade() {
    global successfulCoordinates, maxedCoordinates, PriorityUpgrade, debugMessages, inChallengeMode

    if (successfulCoordinates.Length = 0) {
        return ; No units placed yet
    }

    anyToUpgrade := false
    for coord in successfulCoordinates {
        upgradeEnabled := inChallengeMode && ChallengeBox.Value ? "challengeUpgradeEnabled" coord.slot : GetNameForMode() "upgradeEnabled" coord.slot
        upgradeEnabled := %upgradeEnabled%
        if (upgradeEnabled.Value) {
            anyToUpgrade := true
            break
        }
    }
    ; [Farm done] once your ticked units (farm units) are all maxed, upgrade every placed unit between
    ; placements too - otherwise yen piled up while the rest of the team was still being placed
    allMode := false
    if (!anyToUpgrade) {
        farmDone := false
        for coord in maxedCoordinates {
            ue := inChallengeMode && ChallengeBox.Value ? "challengeUpgradeEnabled" coord.slot : GetNameForMode() "upgradeEnabled" coord.slot
            ue := %ue%
            if (ue.Value) {
                farmDone := true
                break
            }
        }
        if (!farmDone)
            return
        allMode := true
        static loggedAll := 0
        if (A_TickCount - loggedAll > 60000) {
            AddToLog("Farm units are maxed - upgrading the placed units between placements too")
            loggedAll := A_TickCount
        }
    }

    static lastUpgradeLog := 0
    if (A_TickCount - lastUpgradeLog > 30000) {   ; log at most once every 30 seconds
        AddToLog("Attempting to upgrade placed units...")
        lastUpgradeLog := A_TickCount
    }

    if (PriorityUpgrade.Value) {
        if (debugMessages) {
            AddToLog("Using priority-based upgrading")
        }

        ; Loop through priority levels (1-6) and upgrade all matching units
        for priorityNum in [1, 2, 3, 4, 5, 6] {
            upgradedThisRound := false

            for index, coord in successfulCoordinates { 
                ; Check if upgrading is enabled for this unit's slot
                upgradeEnabled := inChallengeMode && ChallengeBox.Value ? "challengeUpgradeEnabled" coord.slot : GetNameForMode() "upgradeEnabled" coord.slot
                upgradeEnabled := %upgradeEnabled%

                if (!upgradeEnabled.Value && !allMode) {
                    if (debugMessages) {
                        AddToLog("Skipping Unit " coord.slot " - Upgrading Disabled")
                    }
                    continue
                }

                ; Get the priority value for this unit's slot
                priority := inChallengeMode && ChallengeBox.Value ? "challengepriority" coord.slot : GetNameForMode() "priority" coord.slot
                priority := %priority%

                upgradeLimitEnabled := inChallengeMode && ChallengeBox.Value ? "challengeUpgradeLimitEnabled" coord.slot : GetNameForMode() "upgradeLimitEnabled" coord.slot
                upgradeLimitEnabled := %upgradeLimitEnabled%

                upgradeLimit := inChallengeMode && ChallengeBox.Value ? "challengeUpgradeLimit" coord.slot : GetNameForMode() "upgradeLimit" coord.slot
                upgradeLimit := %upgradeLimit%
                upgradeLimit := String(upgradeLimit.Text)

                
                if (priority.Text = priorityNum) {
                    if (debugMessages) {
                        AddToLog("Upgrading Unit " coord.slot " at (" coord.x ", " coord.y ")")
                    }

                    if (!upgradeLimitEnabled.Value) {
                        UpgradeUnit(coord.x, coord.y)
                    } else {
                        UpgradeUnitLimit(coord.x, coord.y, coord, index, upgradeLimit)
                    }

                    if CheckForXp() || CheckForReturnToLobby() || CheckForNextText() {
                        AddToLog("Stage ended during upgrades, proceeding to results")
                        successfulCoordinates := []
                        maxedCoordinates := []
                        return NextStep(HandleStageEnd) ; [Improved] was MonitorStage, which could miss the end screen and hang
                    }

                    if CheckForLobbyText() {
                        return NextStep(CheckLobby)
                    }

                    if MaxUpgrade() {
                        AddToLog("Max upgrade reached for Unit " coord.slot)
                        successfulCoordinates.RemoveAt(index)
                        maxedCoordinates.Push(coord)
                        if !UP_ClosePanel()   ; [UI update] new close button position
                            FixClick(325, 185)
                        continue
                    }

                    Sleep(200)
                    CheckAbility()
                    FixClick(607, 553) ; Move Click
                    CheckForCardSelection()
                    Reconnect()
                    CheckEndAndRoute()

                    upgradedThisRound := true
                }
            }

            if upgradedThisRound {
                Sleep(300) ; Add a slight delay between batches
            }
        }
    } else {
        ; Normal (non-priority) upgrading - upgrade all available units
        for index, coord in successfulCoordinates {
            ; Check if upgrading is enabled for this unit's slot
            upgradeEnabled := inChallengeMode && ChallengeBox.Value ? "challengeUpgradeEnabled" coord.slot : GetNameForMode() "upgradeEnabled" coord.slot
            upgradeEnabled := %upgradeEnabled%

            upgradeLimitEnabled := inChallengeMode && ChallengeBox.Value ? "challengeUpgradeLimitEnabled" coord.slot : GetNameForMode() "upgradeLimitEnabled" coord.slot
            upgradeLimitEnabled := %upgradeLimitEnabled%

            upgradeLimit := inChallengeMode && ChallengeBox.Value ? "challengeUpgradeLimit" coord.slot : GetNameForMode() "upgradeLimit" coord.slot
            upgradeLimit := %upgradeLimit%
            upgradeLimit := String(upgradeLimit.Text)

            if (!upgradeEnabled.Value && !allMode) {
                if (debugMessages) {
                    AddToLog("Skipping Unit " coord.slot " - Upgrading Disabled")
                }
                continue
            }

            if (debugMessages) {
                AddToLog("Upgrading Unit " coord.slot " at (" coord.x ", " coord.y ")")
            }

            if (!upgradeLimitEnabled.Value) {
                UpgradeUnit(coord.x, coord.y)
            } else {
                UpgradeUnitLimit(coord.x, coord.y, coord, index, upgradeLimit)
            }

            if CheckForXp() || CheckForReturnToLobby() || CheckForNextText() {
                AddToLog("Stage ended during upgrades, proceeding to results")
                successfulCoordinates := []
                maxedCoordinates := []
                return NextStep(HandleStageEnd) ; [Improved] was MonitorStage, which could miss the end screen and hang
            }

            if CheckForLobbyText() {
                return NextStep(CheckLobby)
            }

            if MaxUpgrade() {
                AddToLog("Max upgrade reached for Unit " coord.slot)
                successfulCoordinates.RemoveAt(index)
                maxedCoordinates.Push(coord)
                if !UP_ClosePanel()   ; [UI update] new close button position
                    FixClick(325, 185)
                continue
            }

            Sleep(200)
            CheckAbility()
            FixClick(607, 553) ; Move Click
            CheckForCardSelection()
            Reconnect()
            CheckEndAndRoute()
        }
    }
    if (debugMessages) {
        AddToLog("Upgrade attempt completed")
    }
}


SetUnitAsMaxed(coord, index) {
    global successfulCoordinates, maxedCoordinates
    AddToLog("Max upgrade reached for Unit " coord.slot)
    successfulCoordinates.RemoveAt(index)
    maxedCoordinates.Push(coord)
    if !UP_ClosePanel()   ; [UI update] new close button position
        FixClick(325, 185)
}



UpgradeUnits() {
    global successfulCoordinates, maxedCoordinates, PriorityUpgrade, inChallengeMode

    local totalUnits := Map()  ; Initialize as a local variable
    local upgradedCount := Map()  ; Initialize as a local variable

    ; Initialize counters
    for coord in successfulCoordinates {
        totalUnits[coord.slot] := (totalUnits.Has(coord.slot) ? totalUnits[coord.slot] + 1 : 1)
        upgradedCount[coord.slot] := upgradedCount.Has(coord.slot) ? upgradedCount[coord.slot] : 0
    }

    AddToLog("Initiating Unit Upgrades...")

    if (PriorityUpgrade.Value) {
        AddToLog("Using priority upgrade system")
        ; Go through each priority level (1-6)
        ; [Upgrade skip] a unit that sits on "Not enough money!" is skipped for now, the cheaper ones
        ; below it get upgraded, and the whole list is gone through again until everything is done.
        global UP_Skipped
        loop {
            UP_Skipped := false
            ; [Fix] recount every pass: units placed late (missing ones added during upgrades) were not in the
            ; counts and their slot was never visited, yet "completed" was logged with them un-upgraded
            totalUnits := Map(), before := successfulCoordinates.Length "|" maxedCoordinates.Length
            for coord in successfulCoordinates {
                totalUnits[coord.slot] := (totalUnits.Has(coord.slot) ? totalUnits[coord.slot] + 1 : 1)
                if !upgradedCount.Has(coord.slot)
                    upgradedCount[coord.slot] := 0
            }
            for priorityNum in [1, 2, 3, 4, 5, 6] {
                for slot in [1, 2, 3, 4, 5, 6] {
                    priority := inChallengeMode && ChallengeBox.Value ? "challengepriority" slot : GetNameForMode() "priority" slot
                    priority := %priority%

                    if (priority.Text = priorityNum && HasUnitsInSlot(slot, successfulCoordinates)) {
                        AddToLog("Starting upgrades for priority " priorityNum " (slot " slot ")")
                        UpgradeSlot(slot, priorityNum, totalUnits, upgradedCount)
                    }
                }
            }
            if (successfulCoordinates.Length = 0)
                break
            after := successfulCoordinates.Length "|" maxedCoordinates.Length
            if (!UP_Skipped && after = before) {
                ; nothing changed this pass - leave it to the stage monitor, which comes back here every 30 s
                AddToLog("[Upgrade] " successfulCoordinates.Length " unit(s) not maxed yet - will keep trying")
                break
            }
            AddToLog("[Upgrade] Going through the list again (" successfulCoordinates.Length " unit(s) not maxed yet)")
        }
        if (successfulCoordinates.Length = 0)
            AddToLog("Priority upgrading completed - every unit is maxed or at its limit")
    } else {
        ; Normal upgrade (no priority)
        while (successfulCoordinates.Length > 0) {
            UpgradeAllUnits(totalUnits, upgradedCount)
        }
        AddToLog("All units maxed, proceeding to monitor stage")
    }

    return NextStep(MonitorStage)
}


HasUnitsInSlot(slot, coordinates) {
    for coord in coordinates {
        if (coord.slot = slot) {
            return true
        }
    }
    return false
}


UpgradeSlot(slot, priorityNum, totalUnits, upgradedCount) {
    noMoneySince := 0
    rounds := 0, startedAt := A_TickCount
    while (true) {
        ; [Upgrade guard] a unit that never reports max / its limit (for example its panel did not open)
        ; used to keep the macro here forever with money piling up. Give up on it after a while.
        rounds += 1
        try PL_RetryPending()   ; [Budget] try the units that had no free spot again (every 30 s)
        ; [Progress] a unit is only given up on when its UPG number stopped rising (and money isn't why),
        ; not after a fixed time - the timer marked units "done" that were simply waiting for yen
        i := successfulCoordinates.Length
        while (i >= 1) {
            c := successfulCoordinates[i]
            if (c.slot = slot && UP_Stuck(c)) {
                lv := UP_Level(c)
                np := 0
                try np := UP_Prog[c.x "," c.y].nopanel
                AddToLog("[Upgrade] Unit " slot " at " c.x ", " c.y (np >= 6 ? ": no unit opens there - dropping it from the list" : " stays at " (lv >= 0 ? "UPG " lv : "an unreadable level") " - treating it as done"))
                SetUnitAsMaxed(c, i)
            }
            i -= 1
        }
        if (rounds > 400) {   ; last-resort safety only
            AddToLog("[Upgrade] Slot " slot " - too many rounds, moving on")
            return
        }
        if UP_ShortOnMoney(&noMoneySince) {
            global UP_Skipped := true
            AddToLog("[Upgrade] Slot " slot " needs more money than you have - upgrading the next units first")
            return
        }
        slotDone := true

        for index, coord in successfulCoordinates {
            if (coord.slot = slot) {
                slotDone := false

                ; If upgradeOneAtATime is true, only upgrade one unit
                if (MaxUpgradeBeforeMoving.Value) {
                    UpgradeUnitWithLimit(coord, index)

                    CheckForTerminationConditions()

                    if (MaxUpgrade()) {
                        HandleMaxUpgrade(coord, index, totalUnits, upgradedCount)
                        break
                    }

                    Sleep(200)
                    PostUpgradeChecks()

                    ; After upgrading one unit, exit the loop to prevent further upgrades
                    break
                } else {
                    ; Perform the upgrade as usual for multiple units
                    UpgradeUnitWithLimit(coord, index)

                    CheckForTerminationConditions()

                    if (MaxUpgrade()) {
                        HandleMaxUpgrade(coord, index, totalUnits, upgradedCount)
                        break
                    }

                    Sleep(200)
                    PostUpgradeChecks()
                }
            }
        }

        if (slotDone || successfulCoordinates.Length = 0) {
            AddToLog("Finished upgrades for priority " priorityNum)
            break
        }
    }
}


UpgradeAllUnits(totalUnits, upgradedCount) {
    for index, coord in successfulCoordinates {
        UpgradeUnitWithLimit(coord, index)

        Reconnect()

        CheckForTerminationConditions()

        if (MaxUpgrade()) {
            HandleMaxUpgrade(coord, index, totalUnits, upgradedCount)
            continue
        }

        Sleep(200)
        PostUpgradeChecks()
    }
}


UpgradeUnitWithLimit(coord, index) {
    global inChallengeMode
    upgradeLimitEnabled := inChallengeMode && ChallengeBox.Value ? "challengeUpgradeLimitEnabled" coord.slot : GetNameForMode() "upgradeLimitEnabled" coord.slot
    upgradeLimitEnabled := %upgradeLimitEnabled%

    upgradeLimit := inChallengeMode && ChallengeBox.Value ? "challengeUpgradeLimit" coord.slot : GetNameForMode() "upgradeLimit" coord.slot
    upgradeLimit := %upgradeLimit%
    upgradeLimit := String(upgradeLimit.Text)

    if (!upgradeLimitEnabled.Value) {
        UpgradeUnit(coord.x, coord.y)
    } else {
        UpgradeUnitLimit(coord.x, coord.y, coord, index, upgradeLimit)
    }
}


CheckForTerminationConditions() {
    global successfulCoordinates, maxedCoordinates ; [Improved] these were being cleared as locals only
    if (CheckForXp() || CheckForReturnToLobby() || CheckForNextText()) {
        AddToLog("Stage ended during upgrades, proceeding to results")
        successfulCoordinates := []
        maxedCoordinates := []
        return NextStep(HandleStageEnd) ; [Improved] was MonitorStage
    }
    Reconnect()
    if (CheckForLobbyText()) {
        return NextStep(CheckLobby)
    }
}


HandleMaxUpgrade(coord, index, totalUnits, upgradedCount) {
    ; [Fix] units placed late weren't in these counts -> "Item has no value" crashed the macro mid-match
    if !upgradedCount.Has(coord.slot)
        upgradedCount[coord.slot] := 0
    if !totalUnits.Has(coord.slot)
        totalUnits[coord.slot] := 1
    upgradedCount[coord.slot]++
    AddToLog("Max upgrade reached for Unit " coord.slot " (" upgradedCount[coord.slot] "/" totalUnits[coord.slot] ")")
    successfulCoordinates.RemoveAt(index)
    if !UP_ClosePanel()   ; [UI update] new close button position
        FixClick(325, 185)
}


PostUpgradeChecks() {
    CheckAbility()
    FixClick(607, 553) ; Move Click
    CheckForCardSelection()
    Reconnect()
    CheckEndAndRoute()
    StageGuard.Check("Stage", "stage took too long")   ; [Framework]
    if (ModeDropdown.Text = "Fool's Hunt") {
        CheckForFoolBuffs()
    }
}


MaxUpgrade() {
    Sleep 150   ; [Pace] was 500
    ; [Progress] the panel's own line decides first: "UPG [MAX]" = max, "UPG [3]" = definitely not max.
    ; (Old pictures sometimes matched on a unit that still had upgrades left.)
    if UP_PanelOpen() {
        t := ""
        try t := StrLower(VH_OCRClient(130, 230, 170, 26, 3))
        if InStr(t, "max") {
            if (CheckForElyssiaSummon())
                return false
            CheckAbility()
            return true
        }
        if RegExMatch(StrReplace(t, "o", "0"), "upg\D{0,3}\d")
            return false
    }
    ; Check for max text ([UI update] the new panel says "UPG [6] (MAX)" / "Max Upgrade")
    if (ok := FT(&X, &Y, 225, 388, 278, 412 , 0, 0, MaxText) or (ok:=FT(&X, &Y, 255, 234, 299, 250, 0, 0, MaxTextNew)) or UP_MaxByText()) {
        if (CheckForElyssiaSummon()) {
            return false
        }
        CheckAbility()
        return true
    }
    return false
}


MaxUpgraded(limit) {
    levelTexts := Map(
        1, Upgrade1,
        2, Upgrade2,
        3, Upgrade3,
        4, Upgrade4,
        5, Upgrade5,
        6, Upgrade6
    )

    if levelTexts.Has(limit) {
        level := levelTexts[limit]
        if (!level) {
            AddToLog("Error: Level " limit " is undefined or empty")
            return false
        }
        if (ok := FT(&X, &Y, 150, 200, 350, 450, 0, 0, level)) {
            return true
        }
        return false
    }
}


UpgradeUnit(x, y) {
    UP_DropHeldUnit()   ; [UI update] never upgrade while a unit is still held for placing (R would rotate it)
    if !UP_OpenUnit(x, y) {   ; [Summon] only summons answered there
        UP_NoteProgress(x, y, -1, -1)
        return
    }
    if !UP_PanelOpen() {   ; [Fix] nothing opened at this spot (the unit isn't there) - count it, don't wait
        UP_NoteProgress(x, y, -1, -1, true)
        return
    }
    ; [Speed] the level from the last visit is the "before" (one text read per visit instead of two),
    ; and R is pressed 6 times: with yen to spare a visit now buys up to 6 upgrades instead of 3
    before := UP_Level({x: x, y: y})
    if (before < 0)
        before := UP_ReadUpgLevel()
    loop 6 {
        SendInput("R")
        Sleep 40
    }
    Sleep 300
    UP_NoteProgress(x, y, before, UP_ReadUpgLevel())
}

; ---- [Progress] is a unit really being upgraded? ------------------------------------------------
; Kept per unit (by its spot): last level seen and how many tries in a row didn't raise it although
; money wasn't the problem. Used instead of a timer to decide that a unit is done.
global UP_Prog := Map()
UP_NoteProgress(x, y, before, after, noPanel := false) {
    global UP_Prog
    k := x "," y
    if !UP_Prog.Has(k)
        UP_Prog[k] := {lvl: -1, stuck: 0, unread: 0, nopanel: 0}
    p := UP_Prog[k]
    if noPanel {
        p.nopanel += 1
        return
    }
    p.nopanel := 0
    if (after >= 0)
        p.unread := 0
    else
        p.unread += 1
    if (before >= 0 && after > before) {
        p.stuck := 0
    } else if (before >= 0 && after = before) {
        short := false
        try short := InStr(PL_GameMessage(), "money") ? true : false
        if !short
            p.stuck += 1
    }
    if (after >= 0)
        p.lvl := after
}
UP_Level(coord) {
    global UP_Prog
    k := coord.x "," coord.y
    return UP_Prog.Has(k) ? UP_Prog[k].lvl : -1
}
; true when this unit clearly isn't going anywhere: same readable level 8 tries in a row (not money),
; or its panel/level couldn't be read 25 tries in a row
UP_Stuck(coord) {
    global UP_Prog
    k := coord.x "," coord.y
    if !UP_Prog.Has(k)
        return false
    p := UP_Prog[k]
    ; 8 visits without the level rising (not money), or 6 visits in a row where clicking the spot opened
    ; no panel at all (no unit there - e.g. a wrongly recovered spot; it cost 5 minutes on Strange Town)
    return (p.stuck >= 8 || p.unread >= 80 || p.nopanel >= 6)
}


UpgradeUnitLimit(x, y, coord, index, upgradeLimit) {
    UP_DropHeldUnit()
    if !UP_OpenUnit(x, y) {
        UP_NoteProgress(x, y, -1, -1)
        return
    }
    lim := CheckUpgradeLimit(upgradeLimit + 1)
    if (lim = "unknown") {
        ; [Fix] the level couldn't be read - pressing R anyway is how Dark Mage went past UPG 4.
        ; Don't upgrade a limited unit blind; it's tried again on the next visit.
        static lastLog := 0
        if (A_TickCount - lastLog > 20000) {
            AddToLog("[Upgrade] Unit " coord.slot ": couldn't read its UPG level (read: '" Trim(UP_LastLvlText) "') - not upgrading it blind")
            lastLog := A_TickCount
        }
        UP_NoteProgress(x, y, -1, -1)
        return
    }
    if lim {
        SetUnitAsMaxed(coord, index)
    } else {
        ; [Pace] the level was just read - press R up to the limit in one visit (max 4 per visit, each R is
        ; at most one level, so it can't pass the limit), instead of one level per visit
        before := UP_LastLvl
        n := (before >= 0) ? Min(4, Integer(upgradeLimit) - before) : 1
        loop Max(1, n) {
            SendInput("R")
            Sleep 60
        }
        Sleep 250
        UP_NoteProgress(x, y, before, UP_ReadUpgLevel())
    }
}


ClickUnit(x, y) {
    FixClick(x, y - 3)
    Sleep (1000)
}


CheckForUpgrade(upgradeLimit) {
    if (!MaxUpgrade()) {
        return UpgradeDetect(170, 231, 118, 22, 400, 335, upgradeLimit) ? true : false
    }
    return false
}


CheckUpgradeLimit(upgradeCap) {
    Sleep 150   ; [Pace] was 500 - the panel is already open (UP_OpenUnit waited for it)

    ; Map the upgrade cap to the corresponding MaxText variable
    upgradeTexts := [
        Upgrade0, Upgrade1, Upgrade2, Upgrade3, Upgrade4,
        Upgrade5, Upgrade6, Upgrade7, Upgrade8, Upgrade9
    ]

    if (upgradeCap < 1 || upgradeCap > upgradeTexts.Length) {
    AddToLog("Invalid upgradeCap: " upgradeCap " - skipping upgrade check")
    return
    }

    ; [UI update] the new panel shows the level as text: "UPG [4]" - read it
    lvl := UP_ReadUpgLevel()
    if (lvl >= 0) {
        if (lvl >= upgradeCap - 1)
            AddToLog("[Upgrade] Unit is at UPG " lvl " - your limit is " upgradeCap - 1)
        return lvl >= upgradeCap - 1      ; the cap passed in is your limit + 1
    }
    if UP_MaxByText()                     ; "UPG [MAX]" has no number - it's maxed
        return true
    return "unknown"   ; [Fix] the old level pictures are from before 21.0 and never match now
}


UpgradeDetect(x, y, w, h, inputX, inputY, upgradeLimit) {
    detectionCount := 0
    AddToLog("Checking for upgrade level...")

    try {
        FT_GetOffset(&ocrDX, &ocrDY) ; [Window follow] OCR area follows Roblox
        result := OCR.FromRect(x + ocrDX, y + ocrDY, w, h, "FirstFromAvailableLanguages", { grayscale: true, scale: 4.0 })

        if result {
            rawText := result.Text
            if (debugMessages) {
                AddToLog("Raw OCR Upgrade Text: " rawText)
            }

            ; Clean text to isolate "Upgrade" + number
            cleanedText := RegExReplace(rawText, ".*Upgrade\D*(\d+).*", "$1") ; Capture only the number after "Upgrade"
            cleanedText := StrReplace(cleanedText, "O", "0") ; Fix OCR mistaking 0 as O

            ; Explicitly replace "O" with "0" to ensure OCR doesn't misinterpret them
            if (cleanedText = "O") {
                cleanedText := "0"
                AddToLog(cleanedText)
            }

            if (debugMessages) {
                AddToLog("Cleaned Upgrade Number: " cleanedText)
            }

            ; Check if the cleaned text is a valid number
            if (cleanedText != "" && RegExMatch(cleanedText, "^\d+$")) {
                detectionCount++
                    
                if (detectionCount >= 1) {
                    if (cleanedText >= upgradeLimit) {
                        AddToLog("Found Upgrade Level: " cleanedText)
                        return true
                    } else {
                        return false
                    }
                }
            }
        }
    }
    AddToLog("Could not detect valid upgrade level")
    return false
}



; [Upgrade skip] true once the game has kept saying "Not enough money!" for 15 s in a row
; (needs the Python helper; without it the macro waits like before)
UP_ShortOnMoney(&since) {
    try {
        if !PL_NoMoney() {
            since := 0
            return false
        }
        ; [Fix] other red messages (e.g. about max level) looked the same - read it to be sure
        if !InStr(PL_GameMessage(), "money") {
            since := 0
            return false
        }
    } catch {
        return false
    }
    if (!since) {
        since := A_TickCount
        return false
    }
    return (A_TickCount - since > 15000)
}


; [UI update] put back a unit that is still held for placing ("Place / R Rotate / Q Cancel" mode).
; Q cancels; pressing it with nothing held does nothing.
UP_DropHeldUnit() {
    SendInput("q")
    Sleep(80)
}


; [UI update] current upgrade level from the unit panel's "UPG [n]" (or "UPG [6] (MAX)"); -1 if unreadable
UP_ReadUpgLevel() {
    ; [Fix] no panel-button check first: when that check missed, every level read came back "unreadable"
    ; and units were dropped as done. The "UPG" word itself proves the panel is there.
    ; Two readers: the quick line reader, then the full text finder on a slightly bigger box.
    global UP_LastLvlText
    loop 2 {
        t := ""
        if (A_Index = 1) {
            try t := StrLower(VH_OCRClient(130, 230, 170, 26, 3))
        } else {
            try {
                for it in SH_Items(125, 224, 190, 38, 2)
                    t .= it.t " "
            }
        }
        UP_LastLvlText := t
        ; [Fix] "l" was turned into "1", so "UPG l0]" (the bracket misread as l) became level 10
        t := StrReplace(StrReplace(t, "o", "0"), "[", " ")
        if RegExMatch(t, "u?pg\W{0,3}[l|i]?\s*(\d{1,2})\b", &m) {
            global UP_LastLvl := Integer(m[1])
            return UP_LastLvl
        }
    }
    global UP_LastLvl := -1
    return -1
}
global UP_LastLvlText := "", UP_LastLvl := -1
