#Requires AutoHotkey v2.0

; ============================================================================
;  StageEvents.ahk  -  In-stage prompts: auto ability, Mahoraga, card selection.
;  [Modularized] functions moved here unchanged from Lib\Functions.ahk, Lib\GameMango.ahk.
;  Loaded from Main.ahk. Contains function definitions only (no start-up code).
; ============================================================================

    
    


CheckAbility() {
    global AutoAbilityBox  ; the "Auto Ability" box in the macro window
    if !AutoAbilityBox.Value
        return
    ; [UI 21.0, from the 4 Nov recording] a unit with an ability shows a purple ability box right of its
    ; panel with a sliding switch on top (centre ~318,269). Off = left half plain grey, right half dark
    ; green with "Off"; On = left half green with "On", right half grey. Cheap pixel check - no reading.
    st := AB_Toggle()
    if (st != "off")
        return
    loop 2 {
        FixClick(318, 269)
        Sleep(400)
        if (AB_Toggle() = "on") {
            AddToLog("Auto Ability switched on")
            return
        }
    }
    static lastLog := 0
    if (A_TickCount - lastLog > 30000) {
        AddToLog("[Ability] Clicked the Auto switch but it still looks off")
        lastLog := A_TickCount
    }
}

; "off" / "on" when the ability switch is on screen, "" when it isn't (no ability, or the panel is closed)
AB_Toggle() {
    old := A_CoordModePixel
    CoordMode("Pixel", "Client")
    lN := 0, lG := 0, rN := 0, rG := 0, n := 0
    try {
        y := 263
        while (y <= 275) {
            x := 0
            while (x <= 18) {
                for side in [0, 1] {
                    c := PixelGetColor((side ? 324 : 294) + x, y)
                    r := (c >> 16) & 255, g := (c >> 8) & 255, b := c & 255
                    v := (r + g + b) / 3
                    neut := (Abs(r - g) < 9 && Abs(g - b) < 9 && v >= 14 && v <= 45)
                    grn := (g >= r + 15 && g <= 120 && r < 60)
                    if side
                        rN += neut, rG += grn
                    else
                        lN += neut, lG += grn
                }
                n += 1
                x += 3
            }
            y += 3
        }
    }
    if !n {
        CoordMode("Pixel", old)
        return ""
    }
    lN /= n, lG /= n, rN /= n, rG /= n
    if (lN >= 0.6 && rG >= 0.4) {
        ; and the purple ability box must be right under it (an open chat box once looked like the switch)
        k := 0, m := 0
        try {
            y := 288
            while (y <= 340) {
                x := 294
                while (x <= 346) {
                    c := PixelGetColor(x, y)
                    r := (c >> 16) & 255, g := (c >> 8) & 255, b := c & 255
                    k += (b > 140 && r > 70 && g < 110 && b > g + 50)
                    m += 1
                    x += 4
                }
                y += 4
            }
        }
        CoordMode("Pixel", old)
        return (m && k / m >= 0.08) ? "off" : ""
    }
    CoordMode("Pixel", old)
    if (rN >= 0.35 && lG >= 0.25)
        return "on"
    return ""
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
