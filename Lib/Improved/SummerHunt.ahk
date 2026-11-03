global SH_JustRecorded := 0   ; [Record walk] when you last recorded a walk with F10
global SH_FallbackUntil := SH_LoadUntil()  ; [Dungeon fallback] playing Dungeon until this time (A_Now style), 0 = off
SH_LoadUntil() {   ; kept in a file so a reload (F3 / watch mode) doesn't forget to switch back
    try {
        v := Trim(FileRead(A_ScriptDir "\Settings\SummerFallbackUntil.txt"))
        if RegExMatch(v, "^\d{14}$")
            return v
    }
    return 0
}
SH_SaveUntil(v) {
    f := A_ScriptDir "\Settings\SummerFallbackUntil.txt"
    try FileDelete(f)
    if (v)
        try FileAppend(v, f)
}
; [Summer Hunt] Summer 2026 event mode. Plays like Fool's Hunt (ship pad, matchmaking, endless waves),
; but the screens were redesigned in the update, so the parts below read the screen TEXT (OCR)
; instead of matching old pictures: the start vote, the card votes and the end screen buttons.
; Screen positions are from your recording on the 800 x 600 Roblox window.

SH_On() => (ModeDropdown.Text = "Summer Hunt")

SH_Log(msg) {
    try FileAppend(FormatTime(, "MM-dd HH:mm:ss") " | " msg "`n", A_ScriptDir "\Logs\SummerHunt.txt", "UTF-8")
}

; text pieces on screen with their centre, in the macro's click coordinates
SH_Items(x, y, w, h, scale := 1) {
    ; works in CLIENT coordinates (the Roblox picture without its title bar) - the same space as
    ; FixClick and the recording pictures. (Picture-search coordinates are ~31 px lower; mixing
    ; them up made the clicks land just below the buttons.)
    items := []
    ox := 0, oy := 0
    try WinGetClientPos(&ox, &oy, , , rblxID)
    r := 0
    try r := VH_Call(Format("cmd=find`nx={}`ny={}`nw={}`nh={}`nscale={}", ox + x, oy + y, w, h, scale), 3000)
    if (r && r.Has("items")) {
        for piece in StrSplit(r["items"], ";;") {
            p := StrSplit(piece, "|")
            if (p.Length >= 3)
                items.Push({t: StrLower(p[1]), x: x + Integer(p[2]), y: y + Integer(p[3])})
        }
        return items
    }
    ; no Python helper: Windows OCR, words with positions (screen coordinates)
    try {
        res := OCR.FromRect(ox + x, oy + y, w, h, "FirstFromAvailableLanguages", { scale: 2.0 })
        for wd in res.Words {
            ; [Fix] the words come back relative to the box that was read (not to the screen) - subtracting the
            ; window position gave negative spots when Roblox wasn't in the top-left corner (board never read,
            ; captcha clicks off screen). Use them as screen positions only if they can't be box-relative.
            rx := Round(wd.x + wd.w / 2), ry := Round(wd.y + wd.h / 2)
            if (rx > w + 5 || ry > h + 5)
                items.Push({t: StrLower(wd.Text), x: rx - ox, y: ry - oy})
            else
                items.Push({t: StrLower(wd.Text), x: x + rx, y: y + ry})
        }
    }
    return items
}

; [Rows] OCR sometimes returns a title as separate words ("Assassin", "Park") - join the pieces that sit
; on the same line, left to right, so map names still match. (Idea from AA Spiral's map reader.)
SH_Rows(items) {
    rows := []
    for it in items {
        placed := false
        for r in rows {
            if (Abs(r.y - it.y) <= 8) {
                r.parts.Push(it), placed := true
                break
            }
        }
        if !placed
            rows.Push({y: it.y, parts: [it]})
    }
    out := []
    for r in rows {
        ; sort the pieces by x (few pieces - simple insertion sort)
        ps := r.parts
        i := 2
        while (i <= ps.Length) {
            j := i
            while (j > 1 && ps[j - 1].x > ps[j].x) {
                tmp := ps[j - 1], ps[j - 1] := ps[j], ps[j] := tmp
                j -= 1
            }
            i += 1
        }
        t := "", sx := 0
        for p in ps
            t .= (t = "" ? "" : " ") p.t, sx += p.x
        out.Push({t: t, x: Round(sx / ps.Length), y: r.y})
    }
    return out
}

SH_Text(x, y, w, h) {
    s := ""
    for it in SH_Items(x, y, w, h)
        s .= it.t " "
    return s
}

SH_Find(regex, x := 0, y := 0, w := 800, h := 600) {
    for it in SH_Items(x, y, w, h)
        if RegExMatch(it.t, regex)
            return it
    return 0
}

; ---- start vote ("Starts in: 53", Yes / No at the top) ------------------------------------
SH_VoteVisible() {
    t := SH_Text(250, 20, 320, 170)
    if RegExMatch(t, "starts in|vote start|change your units") {
        yes := SH_Find("^yes$", 250, 20, 320, 120)
        FixClick(yes ? yes.x : 355, yes ? yes.y : 103)
        return true
    }
    return false
}

; ---- card votes ("Choose a card..." / "The weather shifts...") ----------------------------
; Challenge cards (the ones giving +Summer Pearls) are picked first, the mildest of them; buff cards only
; when no challenge card is offered. The card most players voted for still wins (majority).
; [Cards, fast] the card panel by pixels only (instant, no OCR): the three card bodies are dark and the
; white "Vote ends in: Ns" text sits under the middle. Tested on 8 card pictures (cards and weather
; cards) and ~90 other pictures (lobby, loading, waves, dungeon) - no misses, no false alarms.
SH_CardsUp() {
    old := A_CoordModePixel
    CoordMode("Pixel", "Client")
    up := false
    try {
        d := 0
        for pt in [[224, 380], [400, 380], [577, 380], [224, 400], [400, 400], [577, 400]] {
            c := PixelGetColor(pt[1], pt[2])
            if (((c >> 16) & 255) + ((c >> 8) & 255) + (c & 255) < 150)
                d += 1
        }
        if (d >= 4)
            up := PixelSearch(&a, &b, 340, 459, 380, 474, 0xFFFFFF, 40)
                && PixelSearch(&a, &b, 381, 459, 421, 474, 0xFFFFFF, 40)
                && PixelSearch(&a, &b, 422, 459, 462, 474, 0xFFFFFF, 40)
    }
    CoordMode("Pixel", old)
    return up
}

; before placing: if the cards are up, vote and wait until they're gone (clicks under them would miss)
SH_HandleCardsBeforePlacing(maxMs := 16000) {
    if (!SH_On() || !SH_CardsUp())
        return false
    AddToLog("[Summer] Cards are up - voting before placing")
    t0 := A_TickCount
    try SH_Cards(true)
    start := A_TickCount
    while (A_TickCount - start < maxMs && SH_CardsUp()) {
        Sleep(400)
        if (A_TickCount - start > 5000)
            try SH_Cards()   ; re-vote if the first click didn't take
    }
    Sleep(200)
    global AF_WaitedMs
    try AF_WaitedMs += A_TickCount - t0   ; [Budget] time spent on cards isn't time spent failing to place
    return true
}

SH_Cards(force := false) {
    static last := 0
    if (!force && !SH_CardsUp())   ; [Speed] instant pixel check first - no text reading unless cards are up
        return false
    if (!force && A_TickCount - last < 4000)      ; [Speed] a card vote lasts ~10 s - every 4 s is plenty
        return false
    last := A_TickCount
    title := SH_Text(280, 145, 240, 36)
    if !RegExMatch(title, "choose a card|weather shifts")
        return false
    ; close a unit's upgrade panel first - it covers the left card
    if UP_ClosePanel()   ; [UI update] the panel's X is at (277, 227) now, not (329, 187)
        Sleep(300)
    xs := [144, 320, 496]
    best := 1, bestScore := -9999, desc := ""
    votes := [0, 0, 0], scores := [0, 0, 0]
    loop 3 {
        t := SH_Text(xs[A_Index], 195, 168, 200)
        scores[A_Index] := SH_CardScore(t)
        ; the vote count under the card
        v := SH_Text(xs[A_Index] + 50, 408, 70, 32)
        votes[A_Index] := RegExMatch(v, "\d+", &m) ? Integer(m[0]) : 0
        desc .= A_Index ": " SubStr(t, 1, 50) " (score " scores[A_Index] ", votes " votes[A_Index] ")  "
    }
    ; go with the majority - the card most players voted for; ties / no votes yet -> the best-scored card
    top := Max(votes[1], votes[2], votes[3])
    loop 3 {
        sc := (top > 0 && votes[A_Index] = top ? 1000 : 0) + scores[A_Index]
        if (sc > bestScore)
            best := A_Index, bestScore := sc
    }
    ; [Fix] select the card, press Vote, then CHECK it counted (the Vote button goes away / the count under
    ; our card goes up) - before, a press that landed while the button was still sliding in was never retried
    confirmed := false
    loop 3 {
        FixClick(xs[best] + 84, 300)          ; select the card
        Sleep(450)
        vb := SH_Find("^vote$", 200, 450, 400, 90)
        FixClick(vb ? vb.x : 340, vb ? vb.y : 496)   ; and press the green Vote button
        Sleep(600)
        if !SH_CardsUp() {                    ; vote over / panel closed
            confirmed := true
            break
        }
        v2 := SH_Text(xs[best] + 50, 408, 70, 32)
        nowVotes := RegExMatch(v2, "\d+", &m2) ? Integer(m2[0]) : 0
        stillBtn := SH_Find("^vote$", 200, 450, 400, 90)
        if (nowVotes > votes[best] || !stillBtn) {
            confirmed := true
            break
        }
    }
    AddToLog("[Summer] Picked card " best " of 3 and " (confirmed ? "the vote counted" : "pressed Vote (couldn't confirm it)"))
    SH_Log("cards: " desc " -> picked " best (confirmed ? " (confirmed)" : " (NOT confirmed)"))
    Sleep(300)
    return true
}

SH_CardScore(t) {
    s := 0
    if InStr(t, "pearl")
        s += 40                      ; [Your choice 11-02] challenge cards (more Summer Pearls) first -
                                     ; among them the mildest one still wins (the penalties below)
    for w, v in Map("attack", 5, "damage", 4, "cooldown", 4, "range", 3, "yen", 3, "money", 3, "cash", 3
                  , "crit", 3, "lightning rod", 5, "slow", 2, "cost", 3, "-50% lightning", 5)
        if InStr(t, w)
            s += v
    for w, v in Map("enemy health", 6, "enemy speed", 6, "speed", 2, "regen", 4, "resist", 4, "shield", 4
                  , "armor", 4, "plated", 4, "flying", 5, "soaring", 7, "updraft", 7, "explosi", 3, "curse", 5
                  , "boss", 4, "storm damage", 3)
        if InStr(t, w)
            s -= v
    return s
}

; ---- end screen ---------------------------------------------------------------------------
SH_EndVisible() {
    static last := 0
    if (A_TickCount - last < 6000)      ; [Speed] reading text is the heavy part - not every loop
        return false
    last := A_TickCount
    t := SH_Text(220, 140, 360, 110) " " SH_Text(150, 90, 500, 50)   ; result title / lobby + replay buttons
    return RegExMatch(t, "defeat|victory|waves completed|total time|return to lobby|replay") ? true : false
}

SH_Result() {
    t := SH_Text(150, 120, 500, 330)
    if InStr(t, "victory")
        return "win"
    if InStr(t, "defeat")
        return "loss"
    return ""
}

; Next -> then "Return to lobby" or "Replay". Returns "lobby", "replay" or "".
SH_EndButtons() {
    if (nx := SH_Find("^next$", 150, 300, 500, 150)) {
        FixClick(nx.x, nx.y)
        Sleep(1500)
    }
    lob := SH_Find("return to lobby|back to lobby", 100, 60, 600, 120)
    rep := SH_Find("^replay$", 100, 60, 600, 120)
    if (!lob && !rep)
        return ""
    ; [Watch mode] new fixes waiting -> go through the lobby so they load (Replay never visits the lobby)
    fixes := false
    try fixes := WM_On() && WM_CodeStamp() > WM_S().baseline
    if (fixes && lob)
        SH_Log("end: new fixes waiting - going to the lobby to load them")
    global SH_FallbackUntil
    pend := (SH_FallbackUntil && A_Now < SH_FallbackUntil)   ; Dungeon is due (no route for this map)
    if (pend && lob)
        SH_Log("end: no route for this map - going to the lobby for Dungeon")
    if (ReturnLobbyBox.Value || !rep || (fixes && lob) || (pend && lob)) {
        FixClick(lob ? lob.x : 312, lob ? lob.y : 120)
        SH_Log("end: Return to lobby")
        return "lobby"
    }
    FixClick(rep.x, rep.y)
    SH_Log("end: Replay")
    return "replay"
}

; ---- walking to the Summer Hunt pad: Play, then W and A held together, W a bit longer --------------
; Tune it in Settings\SummerWalk.txt (milliseconds):  W=6000  A=1500
SummerMovement() {
    wMs := 6000, aMs := 1500
    try {
        txt := FileRead(A_ScriptDir "\Settings\SummerWalk.txt")
        if RegExMatch(txt, "i)W\s*=\s*(\d+)", &m)
            wMs := Integer(m[1])
        if RegExMatch(txt, "i)A\s*=\s*(\d+)", &m)
            aMs := Integer(m[1])
    }
    FixClick(592, 204)   ; close the matchmaking window, just in case
    Sleep(200)
    FixClick(85, 295)    ; Play
    Sleep(1000)
    SendInput("{w up}{a up}")
    Sleep(100)
    ; [Fix] the keys are let go by timers at the exact times, so a slow board read (or saving a picture)
    ; can never stretch the walk - it used to walk on into the wall / past the pad when reads were slow.
    SendInput("{w down}{a down}")
    SetTimer(SH_UpA, -aMs)
    SetTimer(SH_UpW, -wMs)
    SH_SleepReadingBoard(Max(wMs, aMs) + 50)
    SetTimer(SH_UpA, 0), SetTimer(SH_UpW, 0)
    SendInput("{w up}{a up}")
    global SH_BoardReads, SH_BoardLast, SH_BoardPics
    if (SH_BoardNow() = "")
        SH_Log("board: not read (" SH_BoardReads " tries) - last seen: " SubStr(SH_BoardLast, 1, 300) " - pictures in Logs\BoardMiss"), SH_BoardPics := []   ; keep them
    else
        SH_BoardPicsDrop()   ; read fine - the pictures of this walk aren't needed
    SH_BoardReads := 0
    KeyWait("w"), KeyWait("a")
    Sleep(1200)
}

; [Memory] remembered placement for a map (good spots + places that failed) belongs to the view the
; walk ends in. When the walk changes, put the old memory aside (renamed, not deleted) and start fresh.
SH_ForgetSpots(m) {
    global GS_Cache
    stamp := FormatTime(, "MMdd_HHmm")
    gs := GS_File(m)
    if FileExist(gs)
        try FileMove(gs, gs ".old_" stamp, 1)
    try GS_Cache.Delete(m)
    try VH_Call("cmd=forget`nname=" m, 3000)   ; the helper keeps its own copy of the failed places
    SH_Log("memory: new walk for " m " - old placement memory put aside")
    AddToLog("[Record walk] Old placement memory for " m " set aside - it learns the new view from now on")
}

SH_UpA() => SendInput("{a up}")
SH_UpW() => SendInput("{w up}")

; ---- the big board you walk past on the way to the pad: "Summer Event / <map> / Summer Hunt / Weather"
; The match's own loading screen always says "Planet Greenie (Summer)", so this board is the reliable
; place to get the map name. It is read while walking; the walk's timing stays exact.
global SH_BoardMap := "", SH_BoardUntil := 0, SH_BoardReads := 0, SH_BoardLast := ""

SH_SleepReadingBoard(ms) {
    global SH_BoardReads
    start := A_TickCount
    cost := 500
    while (true) {
        left := ms - (A_TickCount - start)
        if (left <= 0)
            return
        if (left < cost * 1.5 + 100) {   ; not enough time for another read - just wait out the walk
            Sleep(left)
            return
        }
        t0 := A_TickCount
        try SH_ReadBoard()
        SH_BoardReads += 1
        if (SH_BoardNow() = "" && Mod(SH_BoardReads, 2) = 1 && SH_BoardReads <= 5)   ; [Board misses] keep what the camera saw
            SH_BoardPic(SH_BoardReads)
        cost := Max(150, A_TickCount - t0)
    }
}

; [Board misses] pictures taken during a walk whose board read failed, so the reason can be seen
global SH_BoardPics := []
SH_BoardPic(n) {
    global SH_BoardPics
    try {
        dir := A_ScriptDir "\Logs\BoardMiss"
        DirCreate(dir)
        list := ""
        Loop Files dir "\*.bmp"
            list .= A_LoopFileFullPath "`n"
        if (list != "") {
            arr := StrSplit(Sort(RTrim(list, "`n")), "`n")
            while (arr.Length > 30)
                FileDelete(arr.RemoveAt(1))
        }
        FT_GetOffset(&dx, &dy)
        file := dir "\" FormatTime(, "MMdd_HHmmss") "_read" n ".bmp"
        FindText().SavePic(file, offsetX + dx, offsetY + dy, offsetX + dx + 830, offsetY + dy + 660, 1)
        SH_BoardPics.Push(file)
    }
}
SH_BoardPicsDrop() {
    global SH_BoardPics
    for f in SH_BoardPics
        try FileDelete(f)
    SH_BoardPics := []
}

SH_ReadBoard() {
    global SH_BoardMap, SH_BoardUntil
    if (SH_BoardMap != "" && A_Now < SH_BoardUntil)
        return SH_BoardMap
    raw := SH_Items(0, 30, 800, 330)
    items := raw.Clone()
    for r in SH_Rows(raw)   ; also try the words of one line joined ("Assassin" + "Park")
        items.Push(r)
    global SH_BoardLast
    SH_BoardLast := ""
    for it in items
        SH_BoardLast .= it.t "@" it.x "," it.y " "
    ay := -1, ax := 0
    for it in items {
        if InStr(it.t, "summer event") {
            ay := it.y, ax := it.x
            rest := Trim(RegExReplace(it.t, ".*summer event", ""))   ; both lines read as one
            if (StrLen(rest) >= 4 && (m := SH_CanonMap(rest, true)) != "")
                return SH_SetBoard(m, items)
        }
    }
    if (ay < 0)
        return ""
    best := "", bestY := 9999
    for it in items {
        if (it.y > ay + 3 && it.y < ay + 60 && Abs(it.x - ax) < 200 && it.y < bestY) {
            t := Trim(RegExReplace(it.t, "\(summer\)|summer hunt.*", ""))
            if (StrLen(t) >= 4 && (m := SH_CanonMap(t, true)) != "")
                best := m, bestY := it.y
        }
    }
    if (best != "")
        return SH_SetBoard(best, items)
    ; [Faster / surer] the "Summer Event" title was seen but the map line under it wasn't read (13:48 miss):
    ; read just that strip again, zoomed in 2x - one small extra read while the board is in view
    zx := Max(0, ax - 160), zy := ay + 6
    for it in SH_Rows(SH_Items(zx, zy, 320, 40, 2)) {
        t := Trim(RegExReplace(it.t, "\(summer\)|summer hunt.*", ""))
        if (StrLen(t) >= 4 && (m := SH_CanonMap(t, true)) != "")
            return SH_SetBoard(m, items)
    }
    return ""
}

SH_SetBoard(m, items) {
    global SH_BoardMap, SH_BoardUntil
    ; valid until the board's "New Map" countdown runs out, else until the next full hour
    validTo := DateAdd(FormatTime(, "yyyyMMddHH") "0000", 1, "Hours")
    for it in items
        if RegExMatch(it.t, "(\d{1,2})\s*:\s*(\d{2})", &c) && InStr(it.t, ":") && Integer(c[1]) < 60 {
            if RegExMatch(it.t, "new map|^\d") {
                validTo := DateAdd(A_Now, Integer(c[1]) * 60 + Integer(c[2]) - 20, "Seconds")
                break
            }
        }
    if (SH_BoardMap != m)
        AddToLog("[Summer] Lobby board says the map is " m)
    SH_BoardMap := m, SH_BoardUntil := validTo
    SH_Log("board: " m " (valid until " FormatTime(validTo, "HH:mm:ss") ")")
    return m
}

; the map name read off the board this hour, or ""
SH_BoardNow() {
    global SH_BoardMap, SH_BoardUntil
    return (SH_BoardMap != "" && A_Now < SH_BoardUntil) ? SH_BoardMap : ""
}

; ---- getting into a match: walk to the pad, then Play Here / Find Match (+ captcha) -------------
SH_PanelVisible() => RegExMatch(SH_Text(150, 150, 500, 300), "join matchmaking|play here|find match") ? true : false

SH_EnterHunt() {
    StageGuard.Arm("Entrance", FW_EntranceTimeoutMs)
    walks := 0
    loop {
        StageGuard.Check("Entrance", "Summer Hunt pad not reached")
        if SH_PanelVisible()
            break
        if (walks >= 1) {   ; we've walked once and no panel: maybe it just needs a moment
            Sleep(1500)
            if SH_PanelVisible()
                break
        }
        Reconnect()
        SummerMovement()
        walks += 1
        if (walks > 6) {
            AddToLog("[Summer] Couldn't reach the Summer Hunt pad - check Settings\SummerWalk.txt")
            return NextStep(CheckLobby)
        }
    }
    AddToLog("[Summer] Reached the Summer Hunt pad")
    if (SH_BoardNow() = "") {
        ; [Board] we were already standing at the pad (no walk past the board) - press Play again, which
        ; puts us back at the start, and walk past the board once so the map name gets read
        AddToLog("[Summer] Didn't see the map name yet - walking past the board again")
        FixClick(592, 204)   ; close the Join window
        Sleep(400)
        SummerMovement()
        if !SH_PanelVisible() {
            Sleep(1500)
            if !SH_PanelVisible()
                SummerMovement()
        }
    }
    ; [No route -> Dungeon, decided in the lobby] the board said which map it is this hour. If there's no
    ; walk for it, don't join at all (no leaving a matchmade game) - do Dungeon until the board's timer ends.
    bm := SH_BoardNow()
    if (bm != "" && !SH_MapKnown(bm) && SH_FallbackOn()) {
        global SH_FallbackUntil, SH_BoardUntil
        SH_FallbackUntil := SH_BoardUntil
        SH_SaveUntil(SH_BoardUntil)
        AddToLog("[Summer] No route for " bm " yet - doing Dungeon until the map changes (" FormatTime(SH_BoardUntil, "HH:mm") "). Record it with F10 some time.")
        SH_Log("fallback: board says " bm " (no route) -> Dungeon until " FormatTime(SH_BoardUntil, "HH:mm:ss") ", not joining")
        try SH_NoRouteNote(bm)
        FixClick(592, 204)   ; close the Join Matchmaking window
        Sleep(500)
        return NextStep(StartSelectedMode)   ; switches to Dungeon there
    }
    if !SH_Join()
        return NextStep(CheckLobby)
    AddToLog("Starting Summer Hunt")
    NextStep(RestartStage)
}

SH_Join() {
    if (!MatchMaking.Value) {
        ph := SH_Find("play here", 150, 150, 500, 300)
        FixClick(ph ? ph.x : 334, ph ? ph.y : 310)
        SH_Log("join: Play Here")
        return true
    }
    loop 6 {
        if SH_Queued() {   ; already searching / loading / in the match - nothing to click
            SH_Log("join: already in the queue or match")
            return true
        }
        if !SH_PanelVisible() {
            SummerMovement()
            continue
        }
        fm := SH_Find("find match", 150, 150, 500, 300)
        FixClick(fm ? fm.x : 464, fm ? fm.y : 310)
        Sleep(800)
        ; the captcha panel moved a little in the update, so look over the whole middle of the screen
        code := "", cx := 400, cy := 284, sb := 0
        for it in SH_Items(120, 100, 560, 380, 1.5) {
            tt := StrReplace(StrReplace(it.t, "o", "0"), " ", "")
            if (code = "" && RegExMatch(tt, "^\d{4,8}$", &m))
                code := m[0], cx := it.x, cy := it.y
            if InStr(it.t, "submit")
                sb := it
        }
        if (code = "") {
            AddToLog("[Summer] Captcha not read - trying again")
            if SH_Queued()
                return true
            FixClick(584, 190)   ; close
            Sleep(800)
            continue
        }
        ; [Other PCs] with display scaling the text positions can come back too big - then the mouse
        ; flew off the window. Anything outside the 800x600 game picture: use the usual spots instead.
        if (cx < 120 || cx > 680 || cy < 100 || cy > 480) {
            SH_Log("join: captcha number read at " cx "," cy " (outside the game) - using the usual spot. Display scaling not 100%?")
            cx := 400, cy := 284, sb := 0
        }
        if (sb && (sb.x < 120 || sb.x > 680 || sb.y < 100 || sb.y > 520))
            sb := 0
        ; [Other PCs] clicks are relative to the ACTIVE window - if Roblox lost focus (the macro window,
        ; Discord...) the mouse went somewhere else entirely. Make sure Roblox is in front, and log where it is.
        try {
            if !WinActive(rblxID) {
                SH_Log("join: Roblox wasn't the active window (" WinGetTitle("A") ") - bringing it to the front")
                WinActivate(rblxID)
                Sleep(300)
            }
            WinGetClientPos(&wx, &wy, &ww, &wh, rblxID)
            SH_Log("join: Roblox picture at " wx "," wy " size " ww "x" wh ", screen " A_ScreenWidth "x" A_ScreenHeight ", scale " A_ScreenDPI)
        }
        Sleep(Random(900, 1800))   ; [Human pace] a person reads the number first
        FixClick(cx, cy + 54)    ; the answer box sits just under the number
        Sleep(Random(250, 500))
        for ch in StrSplit(code) {   ; [Human pace] type it digit by digit, not all at once
            SendText(ch)
            Sleep(Random(90, 230))
        }
        Sleep(Random(300, 700))
        FixClick(sb ? sb.x : cx - 98, sb ? sb.y : cy + 102)
        SH_Log("join: captcha " code)
        ; it worked if the queue shows up, or simply if the captcha box closed by itself
        start := A_TickCount
        while (A_TickCount - start < 12000) {
            Sleep(700)
            if SH_Queued()
                return true
            if !RegExMatch(SH_Text(120, 100, 560, 380), "captcha|submit|enter this text") {
                SH_Log("join: captcha box closed - matchmaking started")
                return true
            }
        }
        AddToLog("[Summer] Matchmaking didn't start - trying again")
    }
    return false
}

; searching for a game, loading into one, or already in it
SH_Queued() {
    t := SH_Text(200, 0, 600, 180) " " SH_Text(200, 400, 400, 120)   ; [Speed] top + middle-bottom only
    return RegExMatch(t, "finding a game|matchmaking started|travelling|starts in|vote start|wave \d") ? true : false
}

; ---- map name from the arrival banner ("Strange Town" / "Summer Hunt" / "Weather: Stormy") ---------
; Works for any map, even ones the macro has no loading-screen picture for.
SH_MapFromBanner(waitMs := 8000) {
    ; the map name is the big line right ABOVE "Summer Hunt" / "Weather: ..." - only trusted when one of those is there
    start := A_TickCount
    while (A_TickCount - start < waitMs) {
        items := SH_Items(0, 40, 800, 220)
        for r in SH_Rows(items.Clone())   ; also try the words of one line joined ("Assassin" + "Park")
            items.Push(r)
        anchorY := 0
        loading := false
        for it in items
            if InStr(it.t, "travelling")
                loading := true
        if (loading) {       ; the loading screen's text names the wrong map sometimes - wait for the real banner
            Sleep(700)
            continue
        }
        for it in items
            if RegExMatch(it.t, "summer hunt|weather:|fool's hunt")
                anchorY := anchorY ? Min(anchorY, it.y) : it.y
        if (anchorY) {
            ; only accept text that is (nearly) one of the 36 Summer map names - player names, titles
            ; like "[Transcended]" and menu words are ignored
            best := "", bestY := -1
            for it in items {
                t := Trim(RegExReplace(it.t, "\(summer\)", ""))
                if (it.y < anchorY - 5 && it.y > bestY && StrLen(t) >= 4 && !InStr(t, "[")) {
                    m := SH_CanonMap(t, true)
                    if (m != "")
                        best := m, bestY := it.y
                }
            }
            if (best != "")
                return best
        }
        Sleep(700)
    }
    return ""
}

; ---- F10: record your own walk for the map you're on, right now ----------------------------------
; Press F10 in a match, walk (W A S D / arrows / space), press G to finish. The macro pauses meanwhile
; and replays that walk every time it gets this map (Custom movement is switched on for you).
SH_RecordNow() {
    global CM_Rec
    m := ""
    try m := ST_S().map
    if (m = "" || m = "-" || m = "no map found" || RegExMatch(m, "\d|:"))
        m := SH_MapFromBanner(1500)
    if (m = "") {   ; the macro doesn't know this map - ask you
        ib := InputBox("The macro doesn't recognise this map.`nType its name (as on the Summer Bingo board), e.g. Sky Island:", "Record walk - which map?", "w360 h150")
        if (ib.Result != "OK" || Trim(ib.Value) = "") {
            AddToLog("[Record walk] Cancelled")
            return
        }
        m := SH_CanonMap(Trim(ib.Value))
        try ST_SetMap(m)
    }
    ; start from the same spot the replay starts from: the macro teleports to spawn before every walk
    AddToLog("[Record walk] Teleporting to spawn first...")
    try WinActivate(rblxID)
    try TpSpawn()
    Sleep(800)
    try SH_Print("save", m)   ; remember how this map looks from spawn, to recognise it next time
    AddToLog("[Record walk] Recording your walk for " m " - move now, press G when you're done")
    try WinActivate(rblxID)
    CM_Rec := {events: [], held: Map(), start: A_TickCount, done: false}
    ih := InputHook("V L0")
    ih.MinSendLevel := 1
    ih.KeyOpt("{All}", "N")
    ih.KeyOpt("{" CM_StopKey "}", "+S")
    ih.OnKeyDown := CM_OnKeyDown
    ih.OnKeyUp := CM_OnKeyUp
    ih.Start()
    ; [Zoom] mouse-wheel zooming is recorded too (the wheel still reaches the game)
    Hotkey("~WheelUp", SH_RecWheel, "On")
    Hotkey("~WheelDown", SH_RecWheel, "On")
    deadline := A_TickCount + CM_MaxRecordMs
    while (!CM_Rec.done && A_TickCount < deadline)
        Sleep(50)
    ih.Stop()
    try Hotkey("~WheelUp", "Off")
    try Hotkey("~WheelDown", "Off")
    total := A_TickCount - CM_Rec.start
    for key in CM_Rec.held
        CM_Rec.events.Push({t: total, key: key, down: false})
    if (CM_Rec.events.Length = 0) {
        AddToLog("[Record walk] Nothing recorded")
        return
    }
    if CM_SaveFile(m, CM_Rec.events, total, "recorded with F10") {
        try {
            if FileExist(CM_SettingFile)
                FileDelete(CM_SettingFile)
            FileAppend("1", CM_SettingFile, "UTF-8")
            CM_PanelUseBox.Value := 1
        }
        AddToLog("[Record walk] Saved for " m " (" CM_Rec.events.Length " key presses, " Round(total / 1000, 1) " s) - used from the next round on")
        try SH_NoRouteRemove(m)   ; [Route list] it has a route now
        try SH_ForgetSpots(m)     ; [Memory] a new walk = a new view - the old remembered spots no longer fit
        global SH_JustRecorded := A_TickCount   ; this round's movement is already done
        Zoom()                          ; and give the usual top-down view now
    }
}

SH_RecWheel(hk) {
    global CM_Rec
    try CM_Rec.events.Push({t: A_TickCount - CM_Rec.start, key: StrLower(StrReplace(hk, "~", "")), down: true})
}

; ---- in-game Settings menu: find a button by its label (the menu was redesigned in the update) ----
; Opens the gear menu, scrolls through it reading the text, clicks the row's button. All modes use this.
; [Popups] the game's Settings menu open over the map (left open, or opened by a stray click): close it.
; Cheap text check of its title; throttled unless forced.
SH_CloseSettings(force := false) {
    static last := 0
    if (!force && A_TickCount - last < 8000)
        return false
    last := A_TickCount
    if !RegExMatch(SH_Text(200, 135, 170, 40), "settings") {
        return false
    }
    xb := SH_Find("^x$", 540, 120, 80, 60)
    FixClick(xb ? xb.x : 581, xb ? xb.y : 147)   ; its red X (top right of the menu)
    Sleep(300)
    if RegExMatch(SH_Text(200, 135, 170, 40), "settings")   ; (never Esc - that opens Roblox's own menu)
        FixClick(581, 147), Sleep(300)
    AddToLog("[Popups] Closed the Settings menu that was open over the map")
    return true
}

SH_SettingsClick(regex, what) {
    FixClick(27, 572)          ; gear (bottom left)
    Sleep(700)
    if !RegExMatch(SH_Text(150, 100, 500, 120), "settings|info") {
        FixClick(26, 570)
        Sleep(700)
    }
    MouseMove(400, 330)
    seen := ""
    loop 14 {
        for it in SH_Items(200, 165, 400, 300) {
            if RegExMatch(it.t, regex) {
                FixClick(it.x, it.y)          ; the label itself
                Sleep(150)
                FixClick(525, it.y)           ; and the button on the right of that row
                AddToLog("Found " what " in Settings")
                Sleep(600)
                ; a confirmation box, if one pops up
                if (cf := SH_Find("^yes$|^confirm$|^teleport$|^ok$", 150, 150, 500, 330))
                    FixClick(cf.x, cf.y), Sleep(400)
                ; [Fix] the menu was left open after a successful click (it stayed over the map all match)
                Sleep(300)
                SH_CloseSettings(true)
                return true
            }
        }
        SendInput("{WheelDown 2}")
        Sleep(250)
    }
    AddToLog("Could not find " what " in Settings")
    FixClick(583, 150)          ; close the menu
    Sleep(300)
    return false
}

; ---- [Dungeon fallback] unknown Summer map -> do Dungeon until the map changes -----------------------
; Tick "Dungeon on unknown map" (Summer Hunt options). When the Summer map is one the macro has no walk
; for (no built-in walk and no F10 recording), it leaves to the lobby and plays Dungeon instead.
; Summer maps change every hour on the hour. A dungeon run is always finished first (leaving one early
; loses everything), then back in the lobby it tries Summer Hunt again once the hour has changed.
SH_FallbackFile() => A_ScriptDir "\Settings\SummerFallback.txt"
SH_FallbackOn() {
    try return Trim(FileRead(SH_FallbackFile())) = "1"
    return false
}
SH_FallbackSave(ctrl, *) {
    try FileDelete(SH_FallbackFile())
    FileAppend(ctrl.Value ? "1" : "0", SH_FallbackFile())
    AddToLog("[Summer] Dungeon on unknown maps: " (ctrl.Value ? "ON" : "OFF"))
}

SH_KnownWalks := ["Planet Greenie", "Snowy Town", "Sand Village", "Ant Kingdom", "Magic Town", "Magic Hills", "Navy Bay"
    , "Alien Spaceship", "Fiend City", "Spirit World", "Haunted Academy", "Space Center", "Mountain Temple", "Cursed Festival"
    , "Nightmare Train", "Air Craft", "Hellish City", "Shibuya District", "Sacred Planet", "Snowy Kingdom", "Future City"
    , "Fabled Kingdom", "Puppet Island", "Virtual Dungeon", "Dungeon Throne", "Storm Hideout", "Rain Village", "Spirit Town"
    , "Ruined City", "Strange Town"]
    ; (Assassin Park, Walled City, Haunted Mansion: no route yet - you asked for real routes, not spawn play)

; true = the macro knows how to play this map (a built-in walk or your F10 recording)
SH_MapKnown(name) {
    global SH_KnownWalks
    if (name = "" || name = "no map found")
        return false         ; not recognised at all = no walk for it -> counts as unknown
    r := SH_ResolveMap(name)
    try {
        if FileExist(CM_FileFor(r))
            return true
    }
    for m in SH_KnownWalks
        if (m = r)
            return true
    return false
}

; called on arrival in a Summer match, after the map name is known
SH_CheckUnknownMap(mapName) {
    global SH_FallbackUntil
    if (!SH_On() || SH_MapKnown(mapName))
        return false
    if (MatchMaking.Value) {
        ; [No early leaves] walking out of a matchmade game right after it starts (again and again) is the
        ; kind of thing a game punishes with matchmaking cooldowns. Normally the lobby board already kept
        ; us out of a map without a route; if we still landed on one, finish this match, then go to the
        ; lobby and do Dungeon until the map changes.
        try SoundBeep(900, 200)
        if SH_FallbackOn() {
            next := DateAdd(FormatTime(, "yyyyMMddHH") "0000", 1, "Hours")
            SH_FallbackUntil := next
            SH_SaveUntil(next)
            ; [Leave early] you'd rather not play a map without a route: leave right away - but at most twice
            ; an hour, so repeated quick quits can't pile up into a matchmaking penalty
            static leaves := []
            while (leaves.Length && A_TickCount - leaves[1] > 3600000)
                leaves.RemoveAt(1)
            if (leaves.Length < 2) {
                leaves.Push(A_TickCount)
                AddToLog("[Summer] No route for " (mapName = "no map found" ? "this map" : mapName) " - leaving now, Dungeon until " FormatTime(next, "HH:mm"))
                try SH_NoRouteNote(mapName = "no map found" ? "unknown map (" FormatTime(, "HH:mm") ")" : mapName)
                return true   ; the caller teleports to the lobby
            }
            AddToLog("[Summer] No route for " (mapName = "no map found" ? "this map" : mapName) " - finishing this match (already left twice this hour), then Dungeon until " FormatTime(next, "HH:mm"))
            if (mapName = "no map found") {
                ; [Route list] still nameless - one more look at the arrival banner, else keep a picture of
                ; the map so you can tell which one it was
                bn := ""
                try bn := SH_MapFromBanner(4000)
                if (bn != "") {
                    mapName := bn
                } else {
                    stamp := FormatTime(, "MMdd_HHmm")
                    try DirCreate(A_ScriptDir "\Settings\UnknownMaps")
                    try FileCopy(A_ScriptDir "\Logs\Watch\latest.jpg", A_ScriptDir "\Settings\UnknownMaps\" stamp ".jpg", 1)
                    mapName := "unknown map (picture: Settings\UnknownMaps\" stamp ".jpg)"
                }
            }
            try SH_NoRouteNote(mapName)
        } else {
            AddToLog("[Summer] Unknown map (" (mapName = "no map found" ? "not recognised" : mapName) ") - staying (press F10 to record a walk)")
        }
        return false
    }
    if !SH_FallbackOn() {
        ; you're here to help: stay in the match and let you record the walk
        AddToLog("[Summer] Unknown map (" (mapName = "no map found" ? "not recognised" : mapName) ") - press F10 now to record a walk for it")
        try SoundBeep(900, 200), SoundBeep(1200, 200)
        return false
    }
    ; the map changes on the next full hour
    next := DateAdd(FormatTime(, "yyyyMMddHH") "0000", 1, "Hours")
    SH_FallbackUntil := next
    SH_SaveUntil(next)
    AddToLog("[Summer] Don't know " mapName " - doing Dungeon until the map changes (" FormatTime(next, "HH:mm") ")")
    SH_Log("fallback: unknown map " mapName " -> Dungeon until " FormatTime(next, "HH:mm"))
    return true
}

; called in the lobby at the start of every run (StartSelectedMode): switch modes when it's time
SH_FallbackSwitch() {
    global SH_FallbackUntil
    if (!SH_FallbackUntil)
        return
    if (SH_On() && A_Now >= SH_FallbackUntil) {   ; that hour is already over - stay on Summer Hunt
        SH_FallbackUntil := 0, SH_SaveUntil(0)
        return
    }
    if (SH_On()) {
        SH_SetMode("Dungeon", "Dungeon")
        AddToLog("[Summer] Switched to Dungeon until " FormatTime(SH_FallbackUntil, "HH:mm"))
        return
    }
    if (ModeDropdown.Text = "Dungeon" && A_Now >= SH_FallbackUntil) {
        SH_FallbackUntil := 0
        SH_SaveUntil(0)
        ; a finished dungeon run leaves the Dungeon Run window open in the lobby - close it first,
        ; otherwise it covers the Play button the Summer Hunt walk starts with
        if RegExMatch(SH_Text(60, 80, 600, 80), "dungeon run|pick your own path|dungeon depth") {
            FixClick(668, 144)   ; its red X (top right of the window)
            Sleep(800)
        }
        SH_SetMode("Summer Hunt", "Summer Hunt")
        AddToLog("[Summer] The Summer map has changed - back to Summer Hunt")
    }
}

; [Dungeon fallback] which in-game team (Units > Teams, 1-4) each mode uses; 0 = don't change
SH_TeamFile() => A_ScriptDir "\Settings\SummerTeams.txt"
SH_Team(which) {
    try {
        if RegExMatch(FileRead(SH_TeamFile()), "im)^" which "\s*=\s*(\d)", &m)
            return Integer(m[1])
    }
    return 0
}
SH_TeamSave(*) {
    global SummerTeamDDL, DungeonTeamDDL
    try FileDelete(SH_TeamFile())
    FileAppend("Summer=" (SummerTeamDDL.Value - 1) "`nDungeon=" (DungeonTeamDDL.Value - 1) "`n", SH_TeamFile())
    AddToLog("[Summer] Teams: Summer Hunt " (SummerTeamDDL.Value > 1 ? "Team " SummerTeamDDL.Value - 1 : "unchanged")
        . ", Dungeon " (DungeonTeamDDL.Value > 1 ? "Team " DungeonTeamDDL.Value - 1 : "unchanged"))
}

SH_SetMode(m, profile) {
    team := SH_Team(m = "Dungeon" ? "Dungeon" : "Summer")
    try ApplyScheduleEntry({mode: m, map: "", act: "", profile: profile, team: team ? team : "", until: "", untilType: ""})
    catch {
        global mode, confirmClicked
        try ModeDropdown.Choose(m)
        try OnModeChange()
        mode := m, confirmClicked := true
        try PlacementSelection.Choose(profile), ToggleMode()
    }
}

; ---- map names: snap a slightly misread name (OCR typos) to the real one ---------------------------
SH_AllMaps := ["Snowy Kingdom", "Strange Town", "Space Center", "Cursed Festival", "Planet Greenie", "Adventurer Town"
    , "Virtual Dungeon", "Sky Island", "Sand Village", "Fiend City", "Spirit Town", "Otherworldly Plane", "Fabled Kingdom"
    , "Navy Bay", "Dungeon Throne", "Assassin Park", "Shibuya District", "Nightmare Train", "Hellish City", "Magic Town"
    , "Rain Village", "Puppet Island", "Walled City", "Alien Spaceship (Underwater)", "Ruined City", "Mountain Temple"
    , "Ant Kingdom", "Spirit World", "Sacred Planet", "Sky Aircraft", "Snowy Town", "Haunted Mansion", "Haunted Academy"
    , "Storm Hideout", "Future City", "Magic Hills", "Alien Spaceship", "Air Craft"]

SH_CanonMap(raw, strict := false) {
    global SH_AllMaps
    r := StrLower(Trim(raw))
    best := "", bestD := 99
    for m in SH_AllMaps {
        d := SH_Lev(r, StrLower(m))
        if (d < bestD)
            best := m, bestD := d
    }
    if (bestD <= Max(2, StrLen(r) // 5))
        return best
    if strict
        return ""
    name := ""
    for w in StrSplit(raw, " ")
        name .= StrUpper(SubStr(w, 1, 1)) SubStr(w, 2) " "
    return Trim(name)
}

SH_Lev(a, b) {   ; edit distance
    la := StrLen(a), lb := StrLen(b)
    prev := []
    loop lb + 1
        prev.Push(A_Index - 1)
    loop la {
        i := A_Index
        cur := [i]
        ca := SubStr(a, i, 1)
        loop lb {
            j := A_Index
            cost := (ca = SubStr(b, j, 1)) ? 0 : 1
            cur.Push(Min(prev[j + 1] + 1, cur[j] + 1, prev[j] + cost))
        }
        prev := cur
    }
    return prev[lb + 1]
}

; ---- recoloured map variants: "Alien Spaceship (Underwater)", "Sky Aircraft", "Planet Greenie (Summer)" ---
; are the same layouts as a known map with extra words. Match by the known name being inside the new one
; (spaces, brackets and case ignored), so the known walk / your recording is used.
SH_Squash(n) => RegExReplace(StrLower(n), "[^a-z]", "")

SH_ResolveMap(name) {
    global SH_KnownWalks
    if (name = "" || name = "no map found")
        return name
    sq := SH_Squash(name)
    ; your own recordings first (exact, then contained)
    try {
        if FileExist(CM_FileFor(name))
            return name
        loop files CM_Dir "\*.txt" {
            rec := RegExReplace(A_LoopFileName, "\.txt$", "")
            r := SH_Squash(rec)
            if (StrLen(r) >= 6 && (InStr(sq, r) || InStr(r, sq)))
                return rec
        }
    }
    best := ""
    for m in SH_KnownWalks {
        k := SH_Squash(m)
        if (k = sq)
            return m
        if (StrLen(k) >= 6 && InStr(sq, k) && StrLen(k) > StrLen(best))
            best := m
    }
    return best != "" ? best : name
}

; ---- [Map prints] recognise a map by how it looks after teleport-to-spawn --------------------------
SH_Print(mode, name := "") {
    ox := 0, oy := 0, w := 800, h := 600
    try WinGetClientPos(&ox, &oy, &w, &h, rblxID)
    r := VH_Call(Format("cmd=print`nmode={}`nname={}`nx={}`ny={}`nw={}`nh={}", mode, name, ox, oy, w, h), 3000)
    return r ? r : Map()
}
; [Ask once] beep and ask which map this is; nothing typed within the time = carry on without it
SH_AskMapName(secs := 20) {
    dir := A_ScriptDir "\Settings\MapPrints"
    try SH_Print("save", "_pending")          ; take the view now, before the question box covers it
    try SoundBeep(900, 200), SoundBeep(1200, 200)
    AddToLog("[Summer] Don't recognise this map - type its name in the box (" secs " s) or it carries on")
    ib := InputBox("The macro doesn't recognise this Summer Hunt map.`nType its name (e.g. Assassin Park) - it will remember it.`nNo answer in " secs " s = it carries on by itself.", "Which map is this?", "w380 h170 T" secs)
    try WinActivate(rblxID)
    if (ib.Result != "OK" || Trim(ib.Value) = "")
        return ""
    m := SH_CanonMap(Trim(ib.Value))
    if (m = "")
        m := Trim(ib.Value)
    try FileMove(dir "\_pending.png", dir "\" m ".png", 1)
    SH_Log("print: saved the view as " m " (you named it)")
    try SH_MiniLearn(m)
    AddToLog("[Summer] Thanks - this map is " m " (remembered for next time)")
    return m
}

; known map: save how it looks from spawn the first time, so it's recognised even without a banner
SH_LearnPrint(mapName) {
    if (mapName = "" || mapName = "no map found")
        return
    m := SH_ResolveMap(mapName)
    if FileExist(A_ScriptDir "\Settings\MapPrints\" m ".png")
        return
    SH_Print("save", m)
    SH_Log("print: learned the view of " m)
}

; ---- [Minimap] every map's enemy path has its own fixed shape on the minimap (bottom right) -------------
; Learnt once per map (when the map is known some other way), then used to recognise it - even when the
; lobby board, loading screen and banner all miss. Shapes: Settings\MiniMaps\<map>.png
SH_Mini(mode, name := "") {
    ox := 0, oy := 0
    try WinGetClientPos(&ox, &oy, , , rblxID)
    r := VH_Call(Format("cmd=mini`nmode={}`nname={}`nx={}`ny={}", mode, name, ox, oy), 3000)
    return r ? r : Map()
}
SH_MiniLearn(mapName) {
    if (mapName = "" || mapName = "no map found")
        return
    m := SH_ResolveMap(mapName)
    if FileExist(A_ScriptDir "\Settings\MiniMaps\" m ".png")
        return
    r := SH_Mini("save", m)
    if (r.Has("ok") && r["ok"] = "1")
        SH_Log("minimap: learned the shape of " m)
}
SH_MiniMatch() {
    loop 3 {   ; the minimap can take a moment to appear after loading
        r := SH_Mini("match")
        if (r.Count = 0)
            return ""      ; Python helper not available right now
        if (r.Has("name") && r["name"] != "") {
            AddToLog("Map recognised by its minimap: " r["name"])
            SH_Log("minimap: " r["info"])
            return r["name"]
        }
        if (r.Has("info"))
            SH_Log("minimap: no match - " r["info"])
        if (r.Has("ok") && r["ok"] = "1")
            return ""      ; the path was seen - it just isn't a map we know yet
        Sleep(1000)
    }
    return ""
}

SH_MatchPrint() {
    r := SH_Print("match")
    if (r.Has("name") && r["name"] != "") {
        AddToLog("Map recognised by its view: " r["name"] " (difference " r["dist"] ")")
        return r["name"]
    }
    if r.Has("nearest")
        SH_Log("print: no match (nearest " r["nearest"] ", difference " r["dist"] ")")
    return ""
}


; ---- [Route list] maps met without a route: Settings\MapsNeedingRoutes.txt ("map | times seen | last seen")
; Grows by itself; a map leaves the list as soon as you record a walk for it with F10.
SH_NoRouteFile() => A_ScriptDir "\Settings\MapsNeedingRoutes.txt"
SH_NoRouteLoad() {
    m := Map()
    try {
        for line in StrSplit(FileRead(SH_NoRouteFile(), "UTF-8"), "`n", "`r") {
            if (Trim(line) = "" || SubStr(Trim(line), 1, 1) = ";")
                continue
            p := StrSplit(line, "|")
            if (p.Length >= 3)
                m[Trim(p[1])] := {n: Integer(Trim(p[2])), last: Trim(p[3])}
        }
    }
    return m
}
SH_NoRouteSave(m) {
    txt := "; Summer Hunt maps the macro met that have no walk yet (it did Dungeon instead).`n; Record one with F10 in a match on that map - it's removed from here automatically.`n; map | times seen | last seen`n"
    for k, v in m
        txt .= k " | " v.n " | " v.last "`n"
    try {
        f := FileOpen(SH_NoRouteFile(), "w", "UTF-8")
        f.Write(txt), f.Close()
    }
}
SH_NoRouteNote(map) {
    m := SH_NoRouteLoad()
    if m.Has(map)
        m[map].n += 1, m[map].last := FormatTime(, "yyyy-MM-dd HH:mm")
    else
        m[map] := {n: 1, last: FormatTime(, "yyyy-MM-dd HH:mm")}
    SH_NoRouteSave(m)
}
SH_NoRouteRemove(map) {
    m := SH_NoRouteLoad()
    r := SH_ResolveMap(map)
    for k in [map, r]
        if m.Has(k)
            m.Delete(k)
    SH_NoRouteSave(m)
}

