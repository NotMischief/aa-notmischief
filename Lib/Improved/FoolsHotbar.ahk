; =====================================================================
; [Hotbar check] Fool's Hunt "bring your own units" check.
; After the match starts it reads the unit COSTS printed on the hotbar and compares them
; with your loadout's costs (Settings\MyHotbar.txt). Your own units show all their costs;
; the glitch shows only one, random units show different ones, and no hotbar shows none.
; If it's wrong it leaves to the lobby and tries again.
;   F5 in the lobby = re-read your costs from the hotbar and save them
; Results: Logs\HotbarCheck.txt (+ a screenshot when it decides the units are wrong)
; =====================================================================

HB_File() {
    return A_ScriptDir "\Settings\MyHotbar.txt"
}

HB_Log(msg) {
    AddToLog("[Hotbar] " msg)
    try FileAppend(FormatTime(, "MM-dd HH:mm:ss") " | " msg "`n", A_ScriptDir "\Logs\HotbarCheck.txt", "UTF-8")
}

HB_Shot(tag) {
    global offsetX, offsetY
    try {
        dir := A_ScriptDir "\Logs\HotbarCheck"
        DirCreate(dir)
        n := 0
        Loop Files dir "\*.bmp"
            n += 1
        if (n > 60)
            return
        FT_GetOffset(&dx, &dy)
        FindText().SavePic(dir "\" FormatTime(, "MMdd_HHmmss") "_" tag ".bmp", offsetX + dx, offsetY + dy, offsetX + dx + 830, offsetY + dy + 660, 1)
    }
}

; raw text of the hotbar's cost labels
HB_ReadText() {
    t := VH_OCRClient(225, 541, 380, 20, 3)   ; [UI update] costs now sit just above the unit names (was y 586)
    if (t != "")
        return t
    try {
        WinGetClientPos(&dx, &dy, , , rblxID)
        r := OCR.FromRect(225 + dx, 541 + dy, 380, 20, "FirstFromAvailableLanguages", { grayscale: true, scale: 4.0 })
        return r ? r.Text : ""
    } catch as e {
        return "(error: " e.Message ")"
    }
}

; numbers found in the text, fixing common misreads (s->5, o->0, l->1)
HB_Numbers(text) {
    t := StrLower(text)
    for pair in [["s", "5"], ["o", "0"], ["l", "1"], ["i", "1"], ["|", "1"], ["z", "2"], [",", ""], [".", ""]]
        t := StrReplace(t, pair[1], pair[2])
    nums := []
    pos := 1
    while (pos := RegExMatch(t, "[1-9]\d{2,4}", &m, pos)) {
        nums.Push(m[0])
        pos += StrLen(m[0])
    }
    return nums
}

HB_Expected() {
    try {
        if RegExMatch(FileRead(HB_File(), "UTF-8"), "im)^\s*Costs\s*=\s*(.+)$", &m) {
            out := []
            for v in StrSplit(m[1], ",")
                if (Trim(v) != "")
                    out.Push(Trim(v))
            return out
        }
    }
    return []
}

; F5 in the lobby: read and save the costs
HB_Save(*) {
    nums := HB_Numbers(HB_ReadText())
    if (nums.Length < 5) {
        HB_Log("Only read " nums.Length " of your 6 costs - kept the saved ones. Try F5 again, or type them into Settings\MyHotbar.txt")
        return
    }
    line := ""
    for n in nums
        line .= n ","
    try FileDelete(HB_File())
    FileAppend("; Unit costs shown on your hotbar, left to right (edit if they change)`nCosts=" RTrim(line, ",") "`n", HB_File(), "UTF-8")
    HB_Log("Saved your hotbar costs: " RTrim(line, ","))
}

; true = your own units are loaded
HB_IsCorrect() {
    want := HB_Expected()
    if (want.Length = 0) {
        HB_Log("No saved hotbar costs - press F5 in the lobby. Not checking this round.")
        return true
    }
    need := Max(1, Ceil(want.Length / 2))   ; half of your costs must be read (the glitch shows only 1)
    seen := Map()   ; costs read in ANY of the tries (each read catches different labels)
    allText := ""
    Loop 8 {
        text := HB_ReadText()
        allText .= RegExReplace(text, "\s+", " ") " | "
        for n in HB_Numbers(text)
            for w in want
                if InStr(n, w)   ; "72000" still counts as 2000
                    seen[w] := true
        if (seen.Count >= need) {
            HB_Log("Your units are loaded (" seen.Count "/" want.Length " costs seen: " SubStr(allText, 1, 150) ")")
            return true
        }
        Sleep(400)
    }
    best := seen.Count, bestText := SubStr(allText, 1, 200)
    HB_Log("WRONG units: " best "/" want.Length " costs found (read: " RegExReplace(bestText, "\s+", " ") ")")
    HB_Shot("wrong_units")
    return false
}

; Leave the match: in-game Teleport to Lobby, or rejoin the game if that button isn't found
HB_Leave() {
    if SH_SettingsClick("lobby", "Return to Lobby") {   ; [UI update] by its text
        Sleep(1500)
        return NextStep(CheckLobby)
    }
    FixClick(26, 570) ; settings
    Sleep 400
    FixClick(400, 215)
    Sleep 300
    loop 4 {
        Sleep 250
        SendInput("{WheelDown 1}")
    }
    Sleep 400
    if (ok := FT(&X, &Y, 233, 424, 567, 471, 0.20, 0.20, ReturnToLobbySettings)) {
        AddToLog("Found Teleport to Lobby button")
        FixClick(X + 150, Y - 30)
        Sleep 300
        FixClick(525, 415)
        Sleep 300
        return NextStep(CheckLobby)
    }
    HB_Shot("lobby_button_not_found")
    HB_Log("Teleport to Lobby button not found - rejoining the game instead")
    SendInput("{Esc}")
    Sleep 500
    return NextStep(RejoinPrivateServer)
}

; Bad-map hour: the map changes every hour. After 5 wrong rounds in a row the freeze
; isn't working on this hour's map, so stop freezing (and stop checking) until the hour
; changes and play the normal random-unit mode instead of a glitched hotbar.
HB_FreezeAllowed() {
    global HB_PausedHour
    if (IsSet(HB_PausedHour) && HB_PausedHour != "") {
        if (HB_PausedHour = FormatTime(, "yyyyMMddHH"))
            return false
        HB_PausedHour := ""
        HB_Log("New hour, new map - freezing and checking your units again")
    }
    return true
}

; Called after the match starts. Leaves when the units are wrong.
HB_CheckOrLeave() {
    global HB_PausedHour
    static fails := 0
    Sleep(1500)
    if HB_IsCorrect() {
        fails := 0
        return
    }
    fails += 1
    try ST_Glitch()   ; [Polish] count it in the stats strip
    if (fails >= 5) {
        fails := 0
        HB_PausedHour := FormatTime(, "yyyyMMddHH")
        HB_Log("Wrong units 5 times in a row - this hour's map doesn't work with the freeze. Playing without freezing until the map changes (next hour).")
        HB_Leave()   ; leave this glitched round; the next one is a normal random-unit round
        return
    }
    HB_Log("Going back to the lobby to try again (attempt " fails ")")
    return HB_Leave()
}

; [No-damage guard] Fool's Hunt matchmaking can ban players who do little/no damage.
; If a match has been running 2 minutes and not a single unit could be placed,
; leave instead of sitting there with 0 damage.
HB_IdleCheck() {
    global HB_LastPlaced, stageStartTime
    if (ModeDropdown.Text != "Fool's Hunt" || !IsSet(stageStartTime) || !stageStartTime)
        return
    placedThisMatch := IsSet(HB_LastPlaced) && HB_LastPlaced > stageStartTime
    if (!placedThisMatch && A_TickCount - stageStartTime > 120000) {
        HB_Log("No unit could be placed for 2 minutes - leaving so the round doesn't count as 0 damage")
        HB_Shot("nothing_placed")
        return HB_Leave()
    }
}
