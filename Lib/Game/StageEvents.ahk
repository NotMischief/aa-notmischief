#Requires AutoHotkey v2.0

; ============================================================================
;  StageEvents.ahk  -  In-stage prompts: auto ability, Mahoraga, card selection.
;  [Modularized] functions moved here unchanged from Lib\Functions.ahk, Lib\GameMango.ahk.
;  Loaded from Main.ahk. Contains function definitions only (no start-up code).
; ============================================================================

    
    


CheckAbility() {
    global AutoAbilityBox  ; Reference your checkbox
    ; Only check ability if checkbox is checked
    if (AutoAbilityBox.Value) {
        if (ok := FT(&X, &Y, 342, 253, 401, 281, 0, 0, AutoOff)) {
            FixClick(373, 237)  ; Turn ability on
            AddToLog("Auto Ability Enabled")
            return
        }
        ; [UI update] the old "Auto: Off" picture is from before 21.0 and hasn't matched since the update.
        ; Read the open unit panel instead: an "Auto" switch that says "Off" -> click the switch.
        ; (Only clicks when both words are found inside the panel area, so it can't misfire.)
        static lastRead := 0
        ; [Pace] this panel read cost ~18 s right after the first placement of a room (seen 11-02 06:50), and
        ; none of your current units shows an Auto switch - so it's off unless Settings\AbilityRead.txt = On
        static on := -1
        if (on = -1) {
            on := 0
            try on := InStr(FileRead(A_ScriptDir "\Settings\AbilityRead.txt"), "On") ? 1 : 0
        }
        if (!on)
            return
        if (A_TickCount - lastRead < 8000)   ; one panel read every 8 s at most - keeps upgrades fast
            return
        try {
            if !UP_PanelOpen()
                return
            lastRead := A_TickCount
            items := SH_Items(0, 150, 420, 300)
            autoIt := 0, offIt := 0
            for it in items {
                if RegExMatch(it.t, "auto")
                    autoIt := it
                if RegExMatch(it.t, "^off$|auto\W*off|\boff\b")
                    offIt := it
            }
            if (autoIt && offIt && Abs(autoIt.y - offIt.y) < 40 && Abs(autoIt.x - offIt.x) < 160) {
                FixClick(offIt.x, offIt.y)
                AddToLog("Auto Ability switched on (read from the panel)")
            }
        }
    }
}


CheckForMahoraga() {
    global setMahoragoStyle
    if (!setMahoragoStyle) {
        if (ok := FT(&X, &Y, 279, 517, 308, 541, 0.10, 0.10, MaharagaDefend)) {
            AddToLog("Found Mahoraga")
            ChangeMahoragaMode()
            return true
        }
    }
}


CheckForMahoragaAdaptation() {
    global adaptations, FirstAdaptation, SecondAdaptation, FinalAdaptation

    if (ok := FT(&X, &Y, 198, 394, 391, 419, 0, 0, Adaptation)) {
        adaptations += 1
        AddToLog("Mahoraga Upgrade Available")
        switch (adaptations) {
            case 1:
                ChoseMahoragaAdaptation(FirstAdaptation.Value)
            case 2:
                ChoseMahoragaAdaptation(SecondAdaptation.Value)
            case 3:
                adaptations := 0
                ChoseMahoragaAdaptation(FinalAdaptation.Value)
        }
        return true
    }
}


ChoseMahoragaAdaptation(adaption := 1) {
    switch (adaption) {
        case 1:
            FixClick(230, 410)
            AddToLog("Adapting to become hybrid...")
            return true
        case 2:
            FixClick(290, 408)
            AddToLog("Adapting to enable knockback...")
            return true
        default:
            FixClick(350, 408)
            AddToLog("Adapting to gain 100% crit with slash...")
            return true
    }
}


ChangeMahoragaMode() {
    global setMahoragoStyle

    if (!setMahoragoStyle) {
        if (MahoragoMode.Value = 3) {
            FixClick(292, 496)
            setMahoragoStyle := true
        } else if (MahoragoMode.Value = 2) {
            FixClick(292, 496)
            Sleep(1000)
            FixClick(292, 496)
            setMahoragoStyle := true
        }

    }

}


CheckForCardSelection() {
    if SH_On() {   ; [Summer Hunt] cards are read by their text
        SH_Cards()
        return
    }
    if CardPick_Active() {      
        if CardPick_ScreenVisible()
            CardPick_Pick()
            sleep 1000
        return
    }
}
