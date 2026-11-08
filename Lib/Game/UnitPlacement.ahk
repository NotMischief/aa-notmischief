global PL_HoverSkipped := false  ; top - [Fix] set when the hover check refused a spot
#Requires AutoHotkey v2.0

; ============================================================================
;  UnitPlacement.ahk  -  Unit placement during a stage.
;  [Modularized] functions moved here unchanged from Lib\GameMango.ahk.
;  Loaded from Main.ahk. Contains function definitions only (no start-up code).
; ============================================================================


PlacingUnits() {
    t0 := A_TickCount
    CheckForCardSelection()
    global successfulCoordinates, maxedCoordinates, inChallengeMode
    successfulCoordinates := []
    maxedCoordinates := []
    placedCounts := Map()  
    global PL_Pending := Map()   ; [Budget] units that couldn't be placed yet: slot -> how many still wanted

    anyEnabled := false
    for slotNum in [1, 2, 3, 4, 5, 6] {
        enabled := inChallengeMode && ChallengeBox.Value ? "challengeEnabled" slotNum : GetNameForMode() "enabled" slotNum
        enabled := %enabled%
        enabled := enabled.Value
        if (enabled) {
            anyEnabled := true
            break
        }
    }

    if (!anyEnabled) {
        AddToLog("No units enabled - skipping to monitoring")
        return NextStep(MonitorStage)
    }

    if CheckForXp() || CheckForReturnToLobby() || CheckForNextText() {
        AddToLog("Stage ended during placements, proceeding to results")
        return NextStep(MonitorStage)
    }

    if CheckForLobbyText() {
        return NextStep(CheckLobby)
    }

    Reconnect()

    ; [Profile log] say which unit setup is used (a Challenge run uses the Challenge profile, not the one shown in the cards)
    if (A_TickCount - t0 > 1500)
        PL_Log("[Pace] getting ready to place took " (A_TickCount - t0) " ms")
    AddToLog("Using placement profile: " (inChallengeMode && ChallengeBox.Value ? "Challenge (Auto Challenge run)" : PlacementSelection.Text))

    placementPoints := CP_WithCustomSpots(PlacementPatternDropdown.Text = "3x3 Grid" ? GenerateMoreGridPoints(3) : PlacementPatternDropdown.Text = "Circle" ? GenerateCirclePoints() : PlacementPatternDropdown.Text = "Grid" ? GenerateGridPoints() : PlacementPatternDropdown.Text = "Spiral(WIP)" ? GenerateSpiralGridPoints() : PlacementPatternDropdown.Text = "Up and Down" ? GenerateUpandDownPoints() : GenerateRandomPoints())   ; [Custom placement] your spots first when ON
    
    ; Go through each slot
    for slotNum in [1, 2, 3, 4, 5, 6] {
        enabled := inChallengeMode && ChallengeBox.Value ? "challengeEnabled" slotNum : GetNameForMode() "enabled" slotNum
        enabled := %enabled%
        enabled := enabled.Value
        
        ; Get number of placements wanted for this slot
        placements := inChallengeMode && ChallengeBox.Value ? "challengeplacement" slotNum : GetNameForMode() "placement" slotNum
        placements := %placements%
        placements := Integer(placements.Text)
        
        ; Initialize count if not exists
        if !placedCounts.Has(slotNum)
            placedCounts[slotNum] := 0
        
        ; If enabled, place all units for this slot. Stop after two full sweeps
        ; with no successful placement so an unavailable/empty grid cannot loop forever.
        if (enabled && placements > 0) {
            AddToLog("Placing Unit " slotNum " (" placedCounts[slotNum] "/" placements ")")
            CheckForCardSelection()
            emptySweeps := 0
            budgetStart := A_TickCount, waitedStart := AF_WaitedMs   ; [Budget] time spent trying (not waiting for yen)

            ; [Smart placement] read the game's green/red placement map and pick real spots
            if PL_Enabled() {
                badSpots := []
                misses := 0, waits := 0
                retrySpot := ""
                while (placedCounts[slotNum] < placements && misses < 8 && !PL_OverBudget(budgetStart, waitedStart)) {
                    ; [Smart placement] a miss is usually "not enough money yet" - try the same spot again before picking a new one
                    placedCounts[slotNum] := Max(placedCounts[slotNum], PL_KnownCount(slotNum))   ; [Recover]
                    if (placedCounts[slotNum] >= placements)
                        break
                    SH_HandleCardsBeforePlacing()   ; [Summer] cards up -> vote first (they hide the path paint too)
                    AF_WaitAffordable(slotNum)   ; [Yen] don't try while the unit's card is greyed out
                    spot := retrySpot ? retrySpot : GS_Next(slotNum, badSpots)   ; [Good spots] proven spots first
                    if (!spot)
                        spot := PL_FindSpot(slotNum, badSpots)
                    if (!spot)
                        break
                    if (PlaceUnit(spot.x, spot.y, slotNum)) {
                        CheckForCardSelection()
                        successfulCoordinates.Push({x: spot.x, y: spot.y, slot: slotNum})
                        placedCounts[slotNum] += 1
                        misses := 0, waits := 0, retrySpot := ""
                        PL_NotePlaced(spot.x, spot.y)   ; [Smart placement v2] spread units along the path
                        budgetStart := A_TickCount, waitedStart := AF_WaitedMs   ; [Budget] a success restarts the clock
                        GS_Note(spot.x, spot.y, slotNum, 1)   ; [Good spots] remember it for this map
                        AddToLog("Placed Unit " slotNum " (" placedCounts[slotNum] "/" placements ") [smart]")
                        CheckAbility()
                        FixClick(607, 553) ; Move Click
                        AttemptUpgrade()
                    } else {
                        if SH_HandleCardsBeforePlacing() {   ; [Summer] the cards popped up over the spot - not a bad spot
                            retrySpot := spot
                            continue
                        }
                        global PL_HoverSkipped
                        if PL_HoverSkipped {   ; [Fix] the hover check saw something under the unit (often another
                            PL_HoverSkipped := false   ; player's unit) - try another spot now, don't wait for "money" there
                            misses += 1, waits := 0
                            badSpots.Push(spot), retrySpot := ""
                            continue
                        }
                        msg := PL_GameMessage()
                        if (PL_LimitHit || PL_MaxedMessage(msg)) {   ; [Max units] the game says this unit is at its limit
                            PL_Log("Unit " slotNum ": game says the limit is reached (" Trim(msg) ") - counting it as done")
                            AddToLog("Unit " slotNum " is at the game's limit - moving on")
                            placedCounts[slotNum] := placements
                            break
                        }
                        if (waits < 8 && (InStr(msg, "money") || PL_NoMoney())) {   ; max ~25 s per spot
                            ; [Smart placement v2] "Not enough money!" - the spot is fine, wait and try it again
                            waits += 1, retrySpot := spot
                            if (waits = 1 || Mod(waits, 5) = 0)
                                PL_Log("Unit " slotNum ": not enough money yet - keeping spot " spot.x ", " spot.y " (wait " waits ")")
                            Sleep(2000)
                        } else {
                            ; not money and not the limit: something is in the way (a building, a unit...)
                            ; [Buildings] remember that whole object for this room and for this map
                            misses += 1, waits := 0
                            badSpots.Push(spot), PL_NoteBad(spot), retrySpot := ""
                            if PL_TrueFail {  ; [Fix] only a try the hotbar count proved failed goes into the map memory
                                PL_NoteFail(spot)
                                if spot.HasProp("mem")
                                    GS_Note(spot.x, spot.y, slotNum, -2)
                            }
                            Sleep(300)
                        }
                    }
                    if CheckForXp() || CheckForReturnToLobby() || CheckForNextText() {
                        AddToLog("Stage ended during placements, proceeding to results")
                        return NextStep(HandleStageEnd)
                    }
                    Reconnect()
                    StageGuard.Check("Stage", "stage took too long")
                }
                if (placedCounts[slotNum] < placements)
                    PL_Log("Unit " slotNum ": smart placement placed " placedCounts[slotNum] "/" placements " - trying the normal pattern for the rest")
            }

            while (placedCounts[slotNum] < placements && !PL_OverBudget(budgetStart, waitedStart)) {
                placedInSweep := false
                ; [Path hugger 11-07] Summer: free spots right beside the enemy path first, then the fixed pattern
                sweepPoints := placementPoints
                if PL_HugOn() {
                    hug := PL_HugSpots(slotNum, PL_Placed().bad)
                    if hug.Length {
                        sweepPoints := hug.Clone()
                        for pt in placementPoints
                            sweepPoints.Push(pt)
                    }
                }

                for point in sweepPoints {
                    ; Skip coordinates already used successfully or marked maxed.
                    alreadyUsed := false
                    for coord in successfulCoordinates {
                        if (coord.x = point.x && coord.y = point.y) {
                            alreadyUsed := true
                            break
                        }
                    }
                    if (!alreadyUsed) {
                        for coord in maxedCoordinates {
                            if (coord.x = point.x && coord.y = point.y) {
                                alreadyUsed := true
                                break
                            }
                        }
                    }
                    if (alreadyUsed)
                        continue
                    placedCounts[slotNum] := Max(placedCounts[slotNum], PL_KnownCount(slotNum))   ; [Recover]
                    if (placedCounts[slotNum] >= placements || PL_OverBudget(budgetStart, waitedStart))
                        break

                    if (PlaceUnit(point.x, point.y, slotNum)) {
                        CheckForCardSelection()
                        CheckForMahoraga()
                        CheckForMahoragaAdaptation()
                        successfulCoordinates.Push({x: point.x, y: point.y, slot: slotNum})
                        placedCounts[slotNum] += 1
                        placedInSweep := true
                        GS_Note(point.x, point.y, slotNum, 1)   ; [Good spots]
                        budgetStart := A_TickCount, waitedStart := AF_WaitedMs   ; [Budget]
                        emptySweeps := 0
                        AddToLog("Placed Unit " slotNum " (" placedCounts[slotNum] "/" placements ")")
                        CheckAbility()
                        FixClick(607, 553) ; Move Click
                        AttemptUpgrade()
                        if (placedCounts[slotNum] >= placements)
                            break
                    } else if (PL_LimitHit || (placedCounts[slotNum] > 0 && PL_MaxedMessage(PL_GameMessage()))) {
                        ; [Max units] a placement wasn't noticed earlier and the game now says the limit is reached
                        AddToLog("Unit " slotNum " is at the game's limit (" placedCounts[slotNum] " counted) - moving on")
                        placedCounts[slotNum] := placements
                        break
                    } else if point.HasOwnProp("hug") {
                        PL_NoteBad({x: point.x, y: point.y})   ; [Path hugger] not offered again this stage
                    }

                    if (ModeDropdown.Text = "Fool's Hunt")
                        CheckForFoolBuffs()

                    AttemptUpgrade()

                    if CheckForXp() || CheckForReturnToLobby() || CheckForNextText() {
                        AddToLog("Stage ended during placements, proceeding to results")
                        return NextStep(MonitorStage)
                    }
                    if CheckForLobbyText()
                        return NextStep(CheckLobby)

                    Reconnect()
                    CheckEndAndRoute()
                    StageGuard.Check("Stage", "stage took too long")
                }

                if (!placedInSweep) {
                    emptySweeps += 1
                    if (emptySweeps >= 2) {
                        AddToLog("Unit " slotNum " could not be placed after 2 full sweeps - moving to next slot")
                        break
                    }
                }
                Sleep(500)
                StageGuard.Check("Stage", "stage took too long")
            }
            if (placedCounts[slotNum] < placements && !PL_LimitHit) {   ; [Budget] don't block everything on one unit
                PL_Pending[slotNum] := placements - placedCounts[slotNum]
                AddToLog("Unit " slotNum ": no free spot right now (" placedCounts[slotNum] "/" placements ") - moving on, will try again while upgrading")
            }
            CheckForCardSelection()
            CheckForMahoraga()
            CheckForMahoragaAdaptation()
        }
    }
    
    ; [Failsafe 3 Nov] not a single unit went down (e.g. a wrong walk took us away from the path): don't
    ; sit there doing zero damage - go back to spawn once per match and place from there
    total := 0
    for k, v in placedCounts
        total += v
    static spawnRetry := 0
    if (total = 0 && spawnRetry != stageStartTime) {
        spawnRetry := stageStartTime
        AddToLog("[Placement] Not a single unit went down - teleporting back to spawn and placing from there")
        try TpSpawn()
        Sleep(800)
        try Zoom()
        return NextStep(PlacingUnits)
    }
    AddToLog(total ? "All units placed to requested amounts" : "[Placement] Still no units placed - carrying on with upgrades/monitoring")
    UpgradeUnits()
}


PlaceFoolUnits() {
    placementPoints := CP_WithCustomSpots(PlacementPatternDropdown.Text = "3x3 Grid" ? GenerateMoreGridPoints(3) : PlacementPatternDropdown.Text = "Circle" ? GenerateCirclePoints() : PlacementPatternDropdown.Text = "Grid" ? GenerateGridPoints() : PlacementPatternDropdown.Text = "Spiral(WIP)" ? GenerateSpiralGridPoints() : PlacementPatternDropdown.Text = "Up and Down" ? GenerateUpandDownPoints() : GenerateRandomPoints())   ; [Custom placement] your spots first when ON
    
    ; Collect enabled slots
    enabledSlots := []
    for slotNum in [1, 2, 3, 4, 5, 6] {
        enabled := GetNameForMode() "Enabled" slotNum
        enabled := %enabled%
        enabled := enabled.Value
        if (enabled) {
            enabledSlots.Push(slotNum)
        }
    }

    if (enabledSlots.Length = 0) {
        if (debugMessages) {
            AddToLog("No units enabled - exiting")
        }
        return
    }

    ; Loop through placement points and assign them to enabled slots in order
    pointIndex := 1
    while true {
        for slotIndex, slotNum in enabledSlots {
            point := placementPoints[pointIndex]
            if PlaceUnit(point.x, point.y, slotNum) {
                successfulCoordinates.Push({x: point.x, y: point.y, slot: slotNum})
                CheckAbility()
                FixClick(607, 553) ; Move Click
            }

            if (ModeDropdown.Text = "Fool's Hunt") {
                CheckForFoolBuffs()
            }

            AttemptUpgrade()

            if CheckForXp() || CheckForReturnToLobby() || CheckForNextText() {
                AddToLog("Stage ended during placements, proceeding to results")
                return NextStep(MonitorStage)
            }

            if CheckForLobbyText() {
                return NextStep(CheckLobby)
            }

            Reconnect()
            CheckEndAndRoute()
            StageGuard.Check("Stage", "stage took too long")   ; [Framework]

            Sleep(500) ; Prevent spamming

            ; Move to the next placement point, loop back if at the end
            pointIndex++
            if (pointIndex > placementPoints.Length) {
                pointIndex := 1
            }
        }
    }
}


; ---- [Yen] is a unit affordable? ---------------------------------------------------------------
; Since 21.0 the hotbar has six cards, 58 px wide and 64 px apart, the first at x 212, y 512..570.
; A card you can't afford is drawn at half brightness: its white "Lv." text peaks at ~127 instead of 255.
; Checked on the watch pictures: at 1546 yen the 2000-yen card read 129 while the others read 250+.
; No OCR needed, so it's instant. Returns 1 = lit, 0 = greyed out, -1 = no card visible (unknown).
AF_CardState(slot) {
    if (slot < 1 || slot > 6)
        return -1
    x0 := 212 + 64 * (slot - 1)
    old := A_CoordModePixel
    CoordMode("Pixel", "Client")
    st := -1
    try {
        if PixelSearch(&px, &py, x0, 512, x0 + 40, 531, 0xFFFFFF, 50)
            st := 1
        else if PixelSearch(&px, &py, x0, 512, x0 + 40, 531, 0x7F7F7F, 14)
            st := 0
    }
    CoordMode("Pixel", old)
    return st
}

; wait (up to maxMs) while the card is greyed out; card votes and stage end still get handled
AF_WaitAffordable(slot, maxMs := 60000) {
    if (AF_CardState(slot) != 0)
        return true
    global AF_WaitedMs
    start := A_TickCount, logged := false
    while (A_TickCount - start < maxMs) {
        AF_WaitedMs += 400
        if (AF_CardState(slot) != 0) {
            if logged
                AddToLog("Unit " slot " is affordable now")
            return true
        }
        if !logged {
            AddToLog("Waiting for yen - unit " slot " is greyed out on the hotbar")
            logged := true
        }
        try CheckForCardSelection()
        if (CheckForXp() || CheckForReturnToLobby() || CheckForNextText())
            return false
        Sleep(400)
    }
    return false
}

; ---- [Budget] a unit that can't find a free spot (map cluttered, other players' units in the way) used
; to keep the macro trying for minutes while yen piled up. Each unit now gets ~40 s of real trying
; (time spent waiting for yen doesn't count); after that the macro moves on and upgrades, and tries the
; missing units again every 30 s during upgrades.
global PL_Pending := Map(), AF_WaitedMs := 0
global PL_PendFailMap := Map(), PL_PatIdx := Map()
PL_PendFails(slot) {
    global PL_PendFailMap
    if !PL_PendFailMap.Has(slot)
        PL_PendFailMap[slot] := []
    return PL_PendFailMap[slot]
}
; next point of your placement pattern that isn't taken and hasn't failed for this unit yet
PL_NextPatternPoint(slot) {
    global PL_PatIdx, successfulCoordinates
    static pts := 0, built := 0
    if (!pts || A_TickCount - built > 600000) {
        try pts := CP_WithCustomSpots(PlacementPatternDropdown.Text = "3x3 Grid" ? GenerateMoreGridPoints(3) : PlacementPatternDropdown.Text = "Circle" ? GenerateCirclePoints() : PlacementPatternDropdown.Text = "Grid" ? GenerateGridPoints() : PlacementPatternDropdown.Text = "Spiral(WIP)" ? GenerateSpiralGridPoints() : PlacementPatternDropdown.Text = "Up and Down" ? GenerateUpandDownPoints() : GenerateRandomPoints())
        built := A_TickCount
    }
    if (!pts || !pts.Length)
        return 0
    i := PL_PatIdx.Has(slot) ? PL_PatIdx[slot] : 0
    loop pts.Length {
        i := Mod(i, pts.Length) + 1
        p := pts[i]
        bad := false
        for c in successfulCoordinates
            if (Abs(c.x - p.x) < 30 && Abs(c.y - p.y) < 30) {
                bad := true
                break
            }
        if !bad
            for c in PL_PendFails(slot)
                if (Abs(c.x - p.x) < 20 && Abs(c.y - p.y) < 20) {
                    bad := true
                    break
                }
        if !bad {
            PL_PatIdx[slot] := i
            return {x: p.x, y: p.y}
        }
    }
    return 0
}
PL_OverBudget(start, waitedStart, budgetMs := 40000) {
    global AF_WaitedMs
    return (A_TickCount - start - (AF_WaitedMs - waitedStart)) > budgetMs
}
PL_RetryPending() {
    global PL_Pending, successfulCoordinates
    static last := 0
    if (!PL_Pending.Count || A_TickCount - last < 30000)
        return
    last := A_TickCount
    for slot, need in PL_Pending.Clone() {
        if (need <= 0) {
            PL_Pending.Delete(slot)
            continue
        }
        if (AF_CardState(slot) = 0)   ; can't afford it yet
            continue
        tries := 0
        loop 4 {   ; up to 4 tries per unit per round (pattern points are cheap thanks to the hover check)
            tries += 1
            spot := 0, fromPattern := false
            if (tries = 1) {
                try spot := GS_Next(slot, [])
                if (!spot)   ; [Fix] a unit that waited this long is better a bit further from the path than not placed
                    try spot := PL_FindSpot(slot, PL_PendFails(slot), 0.03)
            }
            if (!spot) {
                ; [Fix] the smart picker sees nothing - fall back to the normal placement pattern
                spot := PL_NextPatternPoint(slot), fromPattern := true
            }
            if (!spot)
                break
            if PlaceUnit(spot.x, spot.y, slot) {
                successfulCoordinates.Push({x: spot.x, y: spot.y, slot: slot})
                try PL_NotePlaced(spot.x, spot.y)
                PL_Pending[slot] := need - 1
                GS_Note(spot.x, spot.y, slot, 1)
                AddToLog("Placed missing Unit " slot " (" PL_Pending[slot] " still missing)" (fromPattern ? " - pattern spot" : ""))
                FixClick(607, 553)
                break
            } else if PL_LimitHit {
                PL_Pending.Delete(slot)
                break
            } else {
                PL_PendFails(slot).Push({x: spot.x, y: spot.y})
            }
            if (CheckForXp() || CheckForReturnToLobby() || CheckForNextText())
                return
        }
        PL_Recover(slot)
    }
}

; ---- [Recover] the hotbar count says more units of this slot are down than the macro knows about:
; the "failed" tries were really placements. Put those spots back in the unit list, so they get
; upgraded and the smart placement stops trying to put units on top of them.
global PL_FailSpots := Map(), PL_Seen := Map()
PL_KnownCount(slot) {
    global successfulCoordinates
    n := 0
    for c in successfulCoordinates
        if (c.slot = slot)
            n += 1
    return n
}
PL_Recover(slot) {
    global successfulCoordinates, PL_FailSpots, PL_Seen
    seen := PL_Seen.Has(slot) ? PL_Seen[slot] : 0
    known := PL_KnownCount(slot)
    fails := PL_FailSpots.Has(slot) ? PL_FailSpots[slot] : []
    while (known < seen && fails.Length) {
        sp := fails.Pop()
        successfulCoordinates.Push({x: sp.x, y: sp.y, slot: slot})
        known += 1
        AddToLog("Unit " slot ": hotbar shows " seen " placed - the try at " sp.x ", " sp.y " did place it (added back)")
        try PL_NotePlaced(sp.x, sp.y)
    }
    if (known >= seen)
        PL_FailSpots[slot] := []   ; in step with the game again
    return known
}
PL_NoteTryFailed(slot, x, y) {
    global PL_FailSpots
    if !PL_FailSpots.Has(slot)
        PL_FailSpots[slot] := []
    PL_FailSpots[slot].Push({x: x, y: y})
    while (PL_FailSpots[slot].Length > 6)
        PL_FailSpots[slot].RemoveAt(1)
}

; [Count] "placed/max" shown above the held unit's hotbar card (e.g. "0/3"). Returns [placed, max] or 0.
PL_SlotCount(slot) {
    if (slot < 1 || slot > 6)
        return 0
    x0 := 212 + 64 * (slot - 1)
    global PL_LastCountText
    ; two readers: the quick line reader on the label, then the full text finder on a wider box
    ; (the line reader came back empty after some placements on Cursed Festival)
    loop 2 {
        t := ""
        if (A_Index = 1) {
            try t := VH_OCRClient(x0 - 6, 501, 70, 24, 3)
        } else {
            try {
                for it in SH_Items(x0 - 18, 494, 96, 34, 2)
                    t .= it.t " "
            }
        }
        PL_LastCountText := t
        t := StrReplace(StrReplace(t, "O", "0"), "o", "0")
        if RegExMatch(t, "(\d{1,2})\s*[/|l\\]\s*(\d{1,2})", &m) {
            a := Integer(m[1]), b := Integer(m[2])
            if (b >= 1 && b <= 30 && a <= b)
                return [a, b]
        }
        ; the reader often drops the slash ("0 2 lv. 110") - take the two small numbers right before "lv"
        pre := RegExReplace(StrLower(t), "lv.*$", "")
        if RegExMatch(pre, "(?<![\d￥¥])(\d)\s+(\d)\s*$", &m) {
            a := Integer(m[1]), b := Integer(m[2])
            if (b >= 1 && b <= 9 && a <= b)
                return [a, b]
        }
    }
    return 0
}

PlaceUnit(x, y, slot := 1) {
    if (ModeDropdown.Text = "Winter Event") {
        CheckForCardSelection()
    }
    if (ModeDropdown.Text = "Fool's Hunt") {
        CheckForCardSelection()
    }

    SH_HandleCardsBeforePlacing()   ; [Summer] cards cover the map - vote first, place after
    try SH_CloseSettings()          ; [Popups] a Settings menu left open blocks the map (checked every 8 s)
    UP_ClosePanel()            ; [UI update] a panel left open would make a miss look like a placement
    AF_WaitAffordable(slot)    ; [Yen] wait until the card is lit (you can afford it)
    global PL_LimitHit, PL_TrueFail, PL_LastCountText
    PL_LimitHit := false, PL_TrueFail := false
    Sleep 50
    SendInput(slot)
    ; [Count] while a unit is held, its hotbar card shows how many are on the map ("1/3"). That count is
    ; the game's own truth - read it before and after, instead of guessing from the panel alone.
    Sleep 120
    c0 := PL_SlotCount(slot)
    if (c0) {
        global PL_Seen
        PL_Seen[slot] := c0[1]
        PL_Recover(slot)
    }
    if (c0 && c0[1] >= c0[2]) {
        SendInput("q")
        PL_LimitHit := true
        PL_Log("Unit " slot ": hotbar says " c0[1] "/" c0[2] " - already at its limit")
        return false
    }
    global PL_HoverSkipped
    PL_HoverSkipped := false
    hv := PL_Hover(x, y)        ; [Hover check] measure what the game draws under the held unit
    ; [Safety] the hover rule was tuned on Summer maps; on Sand Village (orange sand) it called almost every
    ; spot blocked and the unit never went down. After 2 skips in a row it's not trusted on this map for
    ; 10 minutes, and a skipped spot is never written into the map's blocked-spot memory.
    static skipRun := 0, hoverOffUntil := 0
    if (A_TickCount > hoverOffUntil && PL_HoverSkip(hv)) {
        skipRun += 1
        if (skipRun > (SH_On() ? 5 : 2)) {   ; [11-07] Summer: more patience (the check was tuned there)
            hoverOffUntil := A_TickCount + 600000, skipRun := 0
            PL_Log("Hover check skipped too many spots in a row - not using it on this map for 10 minutes")
        } else {
            SendInput("q")
            PL_Log("Unit " slot ": spot " x ", " y " looks blocked under the unit (" PL_HoverText(hv) ") - not clicking")
            PL_HoverSkipped := true
            return false
        }
    }
    FixClick(x, y)
    Sleep 50
    SendInput("q")
    Sleep 120
    SendInput("q")   ; [UI update] a second Q a moment later - one Q right after the click was sometimes missed

    ; [Pace] with the count known, don't wait the full placement-speed time for a panel - 0.7 s is enough,
    ; the count settles it; and when the panel did show (its X check is reliable now), skip the recount
    panel := c0 ? UnitPlacedQuick(700) : UnitPlaced()
    skipRun := 0
    if (panel && c0) {
        global HB_LastPlaced := A_TickCount, PL_Seen
        PL_Seen[slot] := c0[1] + 1
        PL_Log("hover " x "," y ": " PL_HoverText(hv) " -> PLACED")
        return true
    }
    if (c0) {
        ; check the count again: hold the unit for a moment, read, put it back (a few tries - right
        ; after a placement the panel / hotbar can still be animating)
        c1 := 0
        Loop 3 {
            Sleep(A_Index = 1 ? 150 : 300)
            SendInput(slot)
            Sleep 200
            c1 := PL_SlotCount(slot)
            SendInput("q")
            Sleep 80
            if (c1 && (c1[1] > c0[1] || A_Index >= 2))
                break
        }
        if (!c1)
            PL_Log("Unit " slot ": couldn't read the hotbar count after placing (last OCR: '" PL_LastCountText "')")
        if (c1) {
            PL_Seen[slot] := c1[1]
            if (c1[1] > c0[1]) {
                PL_Log("hover " x "," y ": " PL_HoverText(hv) " -> PLACED")
                if !panel
                    AddToLog("Unit Placed Successfully (hotbar count " c0[1] " -> " c1[1] ")")
                global HB_LastPlaced := A_TickCount
                return true
            }
            if panel
                PL_Log("Unit " slot ": a panel opened but the hotbar count stayed " c1[1] "/" c1[2] " - not counted (clicked an existing unit?)")
            if (c1[1] >= c1[2])
                PL_LimitHit := true
            if (!panel) {
                PL_NoteTryFailed(slot, x, y)
                PL_TrueFail := true
                PL_Log("hover " x "," y ": " PL_HoverText(hv) " -> FAILED")
            }
            HB_IdleCheck()
            return false
        }
    }
    if panel {
        global HB_LastPlaced := A_TickCount   ; [No-damage guard]
        Sleep 15
        return true
    }
    PL_NoteTryFailed(slot, x, y)
    HB_IdleCheck()   ; [No-damage guard] leave if nothing could be placed for 2 minutes
    return false
}


CheckForElyssiaSummon() {
    if FT(&X, &Y, 14, 226, 138, 246, 0, 0, ElyssiaSummons) {
        AddToLog("Clicked on Elyssia Eel, ignoring...")
        return true
    }
    ; [UI update] the new panel: a summon's name starts with "Abyssal" (Elyssia herself is
    ; "Elyssia (Abyssal)"), it says "UPG [0] (MAX)" and sells for 0 yen. Seen in the 14:03 picture:
    ; the macro had clicked an Abyssal Eel and took its MAX for Elyssia being maxed.
    if UP_PanelOpen() {
        nm := ""
        try nm := StrLower(VH_OCRClient(8, 228, 150, 22, 3))
        if (RegExMatch(nm, "^\W*abyssal") && !InStr(nm, "elyssia")) {
            AddToLog("Clicked a summon (" Trim(nm) "), not a unit - ignoring it")
            return true
        }
        sell := ""
        try sell := StrLower(VH_OCRClient(70, 378, 80, 22, 3))
        if RegExMatch(sell, "sell\W*0\D*$") {
            AddToLog("Clicked a summon (sells for 0), not a unit - ignoring it")
            return true
        }
    }
    return false
}

; open a placed unit's panel; when the click lands on a summon (its MAX panel would fool the upgrader),
; close it and click a little beside the spot. True when a real unit's panel is open.
UP_OpenUnit(x, y) {
    for off in [[0, -3], [0, 12], [12, 0], [-12, 0], [0, -16]] {
        FixClick(x + off[1], y + off[2])
        Sleep(off[1] = 0 && off[2] = -3 ? 500 : 400)
        t := ""
        if UP_PanelOpen()
            try t := StrLower(VH_OCRClient(130, 230, 170, 26, 3))
        if !InStr(t, "max")          ; not a MAX panel -> can't be a summon
            return true
        if !CheckForElyssiaSummon()  ; a real unit that is maxed
            return true
        UP_ClosePanel()
        Sleep(150)
    }
    return false
}


UnitPlacedQuick(ms) {
    if (WaitForUpgradeText(ms)) {
        AddToLog("Unit Placed Successfully")
        CheckAbility()
        if !UP_ClosePanel()
            FixClick(325, 185)
        return true
    }
    return false
}

UnitPlaced() {
    if (WaitForUpgradeText(PlacementSpeed())) { ; Wait up to 4.5 seconds for the upgrade text to appear
        AddToLog("Unit Placed Successfully")
        CheckAbility()
        if !UP_ClosePanel()      ; [UI update] new close button position
            FixClick(325, 185) ; Close upgrade menu
        return true
    }
    return false
}


WaitForUpgradeText(timeout := 4500) {
    sleep 100
    startTime := A_TickCount
        while (A_TickCount - startTime < timeout) {
             if UP_PanelOpen() || (ok := FT(&X, &Y, 26, 300, 200, 475, 0, 0, AtkPrio)) or (ok := FT(&X, &Y, 26, 387, 192, 475, 0, 0, AtkPrio)) or (ok := FT(&X, &Y, 300, 190, 360, 250, 0, 0, UnitExit)){
                if (CheckForElyssiaSummon()) {
                    return false
                }
                timeSaved := (A_TickCount - startTime)  ; Time saved
                if (debugMessages) {
                    AddToLog("Placement Speed: " . PlacementSpeed() . " ms")
                    AddToLog("Upgrade text found! Time saved: " . timeSaved . " ms")
                }
                return true
            }
            Sleep 50  ; Check every 100ms
        }
        if (debugMessages) {
            AddToLog("Timed out! No upgrade text found. Timeout was: " . timeout . " ms")
        }
        return false  ; Timed out, upgrade text was not found
    }



PlacementSpeed() {
    speeds := [1000, 1500, 2000, 2500, 3000, 4000, 5000, 600]  ; Array of sleep values
    speedIndex := PlaceSpeed.Value  ; Get the selected speed value

    if speedIndex is number  ; Ensure it's a number
        return speeds[speedIndex]  ; Use the value directly from the array
}



; [UI update] the redesigned unit panel (opens when a unit is placed or clicked) has a red round
; close button with a white X. In the new layout it sits at about (277, 227) in the game picture
; (the old one was near (329, 187)) - both areas are searched. The old picture checks no longer match,
; so every real placement looked like a miss ("cannot place more than 3").
global UP_PanelX := 277, UP_PanelY := 227
global PL_LimitHit := false, PL_TrueFail := false, PL_LastCountText := ""
UP_PanelOpen() {
    global UP_PanelX, UP_PanelY
    old := A_CoordModePixel
    CoordMode("Pixel", "Client")
    found := false
    try {
        ; [Fix] the close button of the new unit panel is always at about (277, 227). Red path paint and
        ; enemy health bars next to white names passed the old "red with some white nearby" test, so
        ; placements that never happened were logged as "Unit Placed Successfully". Now the white must
        ; really be the X (centre + 4 arm ends white, red between them) with the dark panel under it.
        top := 210
        Loop 5 {   ; some other white (a name, a spark) can come first - then look again further down
            if !PixelSearch(&wx, &wy, 263, top, 292, 242, 0xF4F6F5, 30)   ; first white = top-left arm of the X
                break
            for d in [[4, 4], [5, 4], [5, 5], [4, 5], [3, 4], [6, 4], [4, 3], [5, 3], [3, 3], [6, 5]] {
                cx := wx + d[1], cy := wy + d[2]
                if (cx < 272 || cx > 281 || cy < 223 || cy > 231)   ; the X is always about (276, 227)
                    continue
                if UP_XShape(cx, cy) {
                    found := true
                    UP_PanelX := cx, UP_PanelY := cy
                    break
                }
            }
            if (found || wy >= 238)
                break
            top := wy + 1
        }
    }
    CoordMode("Pixel", old)
    return found
}

UP_Px(x, y) {
    c := PixelGetColor(x, y)
    return [(c >> 16) & 255, (c >> 8) & 255, c & 255]
}
UP_White(x, y) {
    p := UP_Px(x, y)
    return (p[1] > 185 && p[2] > 185 && p[3] > 185)
}
UP_Dark(x, y) {
    p := UP_Px(x, y)
    return (p[1] + p[2] + p[3] < 220)
}
UP_Arm(cx, cy, sx, sy) {
    for dx in [4, 5, 3, 6]
        for dy in [4, 3, 5]
            if UP_White(cx + sx * dx, cy + sy * dy)
                return true
    return false
}
; the close button's white X: centre and the four arm ends are white, the middle of each side is not,
; and the panel body below-left of it is dark (checked on the watch pictures of the new panel)
UP_XShape(cx, cy) {
    if !UP_White(cx, cy)
        return false
    ; [Fix] the X is drawn a pixel smaller on some maps (Storm Hideout) - accept arm ends 3-6 px out
    if !(UP_Arm(cx, cy, -1, -1) && UP_Arm(cx, cy, 1, -1) && UP_Arm(cx, cy, -1, 1) && UP_Arm(cx, cy, 1, 1))
        return false
    if (UP_White(cx - 9, cy) || UP_White(cx + 9, cy) || UP_White(cx, cy - 8))
        return false
    return (UP_Dark(cx - 7, cy + 73) || UP_Dark(cx - 77, cy + 73))
}

UP_ClosePanel() {
    global UP_PanelX, UP_PanelY
    if UP_PanelOpen() {
        FixClick(UP_PanelX, UP_PanelY)
        Sleep(150)
        return true
    }
    return false
}

; [UI update] "UPG [6] (MAX)" / "Max Upgrade" in the panel
UP_MaxByText() {
    if !UP_PanelOpen()
        return false
    t := ""
    try t := StrLower(VH_OCRClient(140, 225, 150, 120, 2))
    return InStr(t, "max") ? true : false
}
