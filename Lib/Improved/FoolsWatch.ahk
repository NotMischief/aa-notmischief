; =====================================================================
; [Fools Hunt Test] Records what happens around the client freeze so it can be fixed:
;   - screenshots before, during and after the freeze, and of the hotbar once the game starts
;   - checks during the hold whether the game is really frozen (screen stops changing)
;   - reads the hotbar (unit costs) and how colourful each slot is (greyed-out = dull)
; Everything goes to Logs\FoolsHunt\ and Logs\FoolsHunt.txt. Functions only.
; =====================================================================

FH_Log(msg) {
    AddToLog("[Freeze] " msg)
    try FileAppend(FormatTime(, "MM-dd HH:mm:ss") " | " msg "`n", A_ScriptDir "\Logs\FoolsHunt.txt", "UTF-8")
}

FH_Shot(tag) {
    global offsetX, offsetY
    try {
        dir := A_ScriptDir "\Logs\FoolsHunt"
        DirCreate(dir)
        list := ""
        Loop Files dir "\*.bmp"
            list .= A_LoopFileFullPath "`n"
        if (list != "") {
            arr := StrSplit(Sort(RTrim(list, "`n")), "`n")
            while (arr.Length > 120)
                FileDelete(arr.RemoveAt(1))
        }
        ; capture the Roblox window wherever it currently is
        if WinExist(rblxID) {
            WinGetPos(&wx, &wy, &ww, &wh, rblxID)
            FindText().SavePic(dir "\" FormatTime(, "MMdd_HHmmss") "_" tag ".bmp", wx, wy, wx + ww, wy + wh, 1)
        }
    }
}

; signature of the Roblox window: 30 pixels across it
FH_Sig() {
    old := A_CoordModePixel
    CoordMode("Pixel", "Screen")
    sig := ""
    try {
        WinGetPos(&wx, &wy, &ww, &wh, rblxID)
        Loop 5 {
            r := A_Index
            Loop 6
                sig .= PixelGetColor(wx + ww * A_Index / 7, wy + wh * r / 6) ","
        }
    }
    CoordMode("Pixel", old)
    return sig
}

; Replaces the plain Sleep(holdTime) while right-click is held. Returns how many checks saw
; the screen change (0 = the game stayed frozen the whole time).
FH_HoldAndWatch(holdTime) {
    start := A_TickCount
    last := FH_Sig()
    changes := 0, checks := 0
    nextShot := [3000, 30000, 60000, 100000]
    shotIdx := 1
    while (A_TickCount - start < holdTime) {
        Sleep(Min(2500, holdTime - (A_TickCount - start)))
        sig := FH_Sig()
        checks += 1
        if (sig != last)
            changes += 1
        last := sig
        if (shotIdx <= nextShot.Length && A_TickCount - start >= nextShot[shotIdx]) {
            FH_Shot("2_during_" Round((A_TickCount - start) / 1000) "s")
            shotIdx += 1
        }
    }
    FH_Log("Hold finished: screen changed in " changes " of " checks " checks" (changes <= 1 ? " (game was frozen)" : " (game was NOT frozen the whole time)"))
    return changes
}

; Once the match has started: read the hotbar and log it with a screenshot.
FH_HotbarReport() {
    global offsetX, offsetY
    Sleep(1500)
    FH_Shot("5_hotbar_game_started")
    try {
        FT_GetOffset(&dx, &dy)
        r := OCR.FromRect(255 + dx, 588 + dy, 305, 22, "FirstFromAvailableLanguages", { grayscale: true, scale: 3.0 })
        costs := r ? RegExReplace(r.Text, "\s+", " ") : ""
    } catch {
        costs := "(unreadable)"
    }
    ; colourfulness of each slot's icon (greyed-out slots are dull)
    old := A_CoordModePixel
    CoordMode("Pixel", "Screen")
    sats := ""
    try {
        FT_GetOffset(&dx, &dy)
        Loop 6 {
            cx := offsetX + dx + 283 + (A_Index - 1) * 50
            total := 0
            for p in [[-12, -14], [0, -14], [12, -14], [-12, -2], [0, -2], [12, -2]] {
                c := PixelGetColor(cx + p[1], offsetY + dy + 578 + p[2])
                rr := (c >> 16) & 255, gg := (c >> 8) & 255, bb := c & 255
                total += Max(rr, gg, bb) - Min(rr, gg, bb)
            }
            sats .= Round(total / 6) " "
        }
    }
    CoordMode("Pixel", old)
    FH_Log("Hotbar costs: " costs " | slot colour (higher = more colourful): " sats)
}

; FreezeTiming from Settings\FoolsHunt.txt: "early" (right after joining) or "normal" (after the map is found)
FH_Timing() {
    f := A_ScriptDir "\Settings\FoolsHunt.txt"
    if !FileExist(f)
        try FileAppend("; early = freeze right after joining the match, normal = freeze after the map is detected (original)`nFreezeTiming=early`n", f, "UTF-8")
    try {
        if RegExMatch(FileRead(f, "UTF-8"), "im)^\s*FreezeTiming\s*=\s*(\w+)", &m)
            return StrLower(m[1])
    }
    return "early"
}
