; =====================================================================
; [Smart placement] (Improved v4)
; When you pick up a unit the game paints the map:
;   bright GREEN = hill spots (where hill units can go)
;   RED          = can't place (the enemy path, wrong terrain, around other units)
;   unpainted    = normal ground
; The macro picks the unit up, takes one picture of the game, puts the unit back,
; and chooses a spot that is allowed for that unit's type (F6: Ground / Hill / Hybrid),
; not too close to anything red, and as close to the path as possible.
; Spots taken by other players are red too, so they are skipped automatically.
; Turn off with  SmartPlacement=Off  in Settings\UnitTypes.txt.
; =====================================================================

PL_Enabled() {
    try {
        if RegExMatch(FileRead(UT_File(), "UTF-8"), "im)^\s*SmartPlacement\s*=\s*(\w+)", &m)
            return !(StrLower(m[1]) = "off" || m[1] = "0")
    }
    return true
}

PL_Log(msg) {
    AddToLog("[Placement] " msg)
    try FileAppend(FormatTime(, "MM-dd HH:mm:ss") " | " msg "`n", A_ScriptDir "\Logs\SmartPlacement.txt", "UTF-8")
}

; parts of the window that are game interface, not map (fractions of the window)
PL_Excluded(fx, fy) {
    return (fy < 0.22 || fy > 0.84 || fx < 0.05 || fx > 0.95 || (fx > 0.76 && fy > 0.25 && fy < 0.60) || (fx > 0.80 && fy > 0.72))   ; + minimap / level info (UI update)
}

; One picture of the game -> grid of cells: 0 ground, 1 red (blocked), 2 green (hill), 3 interface
PL_ReadGrid(cx, cy, cw, ch, step) {
    cols := cw // step, rows := ch // step
    cells := Buffer(cols * rows, 3)
    pToken := Gdip_Startup()
    try {
        pBmp := Gdip_BitmapFromScreen(cx "|" cy "|" cw "|" ch)
        Gdip_LockBits(pBmp, 0, 0, cw, ch, &stride, &scan, &bd)
        r := 0
        while (r < rows) {
            py := r * step + step // 2
            fy := py / ch
            c := 0
            while (c < cols) {
                px := c * step + step // 2
                k := 3
                if !PL_Excluded(px / cw, fy) {
                    argb := NumGet(scan, py * stride + px * 4, "UInt")
                    ; [Fix 11-07] AutoHotkey names ignore case: "R" was the same variable as the row counter "r",
                    ; so the red value replaced the row and NumPut below failed ("Invalid parameter(s)") - this
                    ; backup reader (used when Python isn't running) never worked
                    cr := (argb >> 16) & 255, cg := (argb >> 8) & 255, cb := argb & 255
                    if (cr >= 100 && cr - cg >= 70 && cr > cb)
                        k := 1
                    else if (cg >= 170 && cr < 120 && cb < 140)
                        k := 2
                    else
                        k := 0
                }
                NumPut("UChar", k, cells, r * cols + c)
                c += 1
            }
            r += 1
        }
        Gdip_UnlockBits(pBmp, &bd)
        Gdip_DisposeImage(pBmp)
    } catch as e {
        PL_Log("built-in map reading failed: " e.Message " (" e.What " line " e.Line ")")
    }
    Gdip_Shutdown(pToken)
    return {cols: cols, rows: rows, cells: cells, step: step}
}

; distance (in cells) from every cell to the nearest cell where isSource(kind) is true
PL_Distance(g, sourceKinds) {
    static offs := [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [-1, 1], [1, -1], [1, 1]]
    n := g.cols * g.rows
    dist := Buffer(n * 2, 0xFF)   ; 0xFFFF = far
    queue := []
    i := 0
    while (i < n) {
        if InStr(sourceKinds, NumGet(g.cells, i, "UChar")) {
            NumPut("UShort", 0, dist, i * 2)
            queue.Push(i)
        }
        i += 1
    }
    head := 1
    while (head <= queue.Length) {
        i := queue[head], head += 1
        d := NumGet(dist, i * 2, "UShort") + 1
        r := i // g.cols, c := Mod(i, g.cols)
        for o in offs {
            rr := r + o[1], cc := c + o[2]
            if (rr < 0 || cc < 0 || rr >= g.rows || cc >= g.cols)
                continue
            j := rr * g.cols + cc
            if (NumGet(dist, j * 2, "UShort") > d) {
                NumPut("UShort", d, dist, j * 2)
                queue.Push(j)
            }
        }
    }
    return dist
}

; Picks a spot for this slot's unit. Returns {x, y} in window coordinates, or 0.
PL_FindSpot(slot, avoid, mincov := 0.15) {
    static vlogged := 0
    if !WinExist(rblxID)
        return 0
    WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
    if (cw < 200 || ch < 200)
        return 0
    utype := UT_Get(slot)
    t0 := A_TickCount

    ; [Tint] picture of the map before the unit is picked up (the helper compares it with the painted one)
    MouseMove(Round(cw * 0.03), Round(ch * 0.95))
    try VH_Call(Format("cmd=base`nx={}`ny={}`nw={}`nh={}", cx, cy, cw, ch), 1000)
    ; pick the unit up so the game paints the map, with the mouse parked over the interface
    SendInput(slot)
    Sleep(150)   ; the helper itself looks again if the paint isn't showing yet

    ; [Python vision] fast path: the helper reads the whole map at full detail in a few ms
    av := ""
    for a in avoid
        av .= a.x ":" a.y ";"
    for a in PL_Placed().bad
        av .= a.x ":" a.y ";"
    pl := PL_Placed()
    own := ""
    for p in pl.list
        own .= p.x ":" p.y ";"
    r := VH_Call(Format("cmd=place`nx={}`ny={}`nw={}`nh={}`ntype={}`navoid={}`nroom={}`nplaced={}`nrange={}`nmap={}`nmincov={}", cx, cy, cw, ch, utype, av, pl.room, own, PL_Range(), PL_Map(), mincov), 2000)
    if (r && r.Has("ok")) {
        SendInput("q")
        Sleep(60)
        SendInput("q")   ; make sure the unit we picked up to see the paint is put back
        if (vlogged < 400) {
            vlogged += 1
            PL_Log("Unit " slot " (" utype ") [python]: " (r.Has("info") ? r["info"] : "") " -> " (r["ok"] = "1" ? "spot " r["x"] ", " r["y"] : "no good spot") " (" (A_TickCount - t0) " ms total, " (r.Has("ms") ? r["ms"] : "?") " ms analysis)")
        }
        return (r["ok"] = "1") ? {x: Integer(r["x"]), y: Integer(r["y"])} : 0
    }

    g := PL_ReadGrid(cx, cy, cw, ch, 8)
    SendInput("q")   ; put it back
    Sleep(100)

    ok := (utype = "Hill") ? "2" : (utype = "Ground") ? "0" : "02"
    counts := [0, 0, 0, 0]
    n := g.cols * g.rows
    i := 0
    while (i < n) {
        counts[NumGet(g.cells, i, "UChar") + 1] += 1
        i += 1
    }
    blockedKinds := (utype = "Hill") ? "013" : (utype = "Ground") ? "123" : "13"
    distBlocked := PL_Distance(g, blockedKinds)
    distRed := PL_Distance(g, "1")

    margin := 3   ; cells (~24 px) away from anything not allowed
    best := 0, bestScore := 999999
    cxm := g.cols / 2, cym := g.rows / 2
    i := 0
    while (i < n) {
        if InStr(ok, NumGet(g.cells, i, "UChar")) && NumGet(distBlocked, i * 2, "UShort") >= margin {
            r := i // g.cols, c := Mod(i, g.cols)
            x := c * g.step + g.step // 2, y := r * g.step + g.step // 2
            skip := false
            for a in avoid
                if (Abs(a.x - x) < 30 && Abs(a.y - y) < 30)
                    skip := true
            if (!skip) {
                ; close to the path first, then towards the middle of the screen, plus a little randomness
                score := NumGet(distRed, i * 2, "UShort") * 10 + (Abs(c - cxm) + Abs(r - cym)) / 4 + Random(0, 6)
                if (score < bestScore)
                    best := {x: x, y: y}, bestScore := score
            }
        }
        i += 1
    }
    static logged := 0
    if (logged < 30) {
        logged += 1
        PL_Log("Unit " slot " (" utype "): map has " counts[1] " ground, " counts[2] " red, " counts[3] " green cells -> " (best ? "spot " best.x ", " best.y : "no good spot") " (" (A_TickCount - t0) " ms)")
    }
    return best
}

; [Money check] your money above the hotbar, as a number (-1 if it can't be read)
PL_ReadMoney() {
    try {
        t := VH_OCR(330, 530, 160, 32, 3)   ; [Python vision] RapidOCR first
        if (t = "") {
            FT_GetOffset(&dx, &dy)
            r := OCR.FromRect(330 + dx, 530 + dy, 160, 32, "FirstFromAvailableLanguages", { grayscale: true, scale: 3.0 })
            t := r ? r.Text : ""
        }
        t := StrReplace(t, ",", "")
        t := RegExReplace(t, "[+\-]\s*\d+", " ")   ; drop the floating "+108" / "-550" pop-ups
        if RegExMatch(t, "(\d{1,9})", &m)
            return Integer(m[1])
    }
    return -1
}


; money read 2-3 times; only trusted when two reads agree (one bad read caused wrong waits)
PL_ReadMoneySure() {
    a := PL_ReadMoney()
    b := PL_ReadMoney()
    if (a >= 0 && PL_Close(a, b))
        return Max(a, b)
    c := PL_ReadMoney()
    if (c >= 0 && (PL_Close(a, c) || PL_Close(b, c)))
        return c
    return -1
}
PL_Close(a, b) => (a >= 0 && b >= 0 && Abs(a - b) <= Max(60, a // 20))

; placement cost per hotbar slot, learnt from how much the money drops when a unit is placed.
; A cost is only trusted once two drops agree.
PL_Costs() {
    static m := Map()
    return m
}
PL_LearnCost(slot, drop) {
    if (drop < 50 || drop > 300000)
        return
    m := PL_Costs()
    if !m.Has(slot)
        m[slot] := {seen: [], cost: 0}
    e := m[slot]
    for d in e.seen
        if (Abs(d - drop) <= Max(40, d // 10)) {
            if (e.cost != Min(d, drop))
                PL_Log("Unit " slot " costs about " Min(d, drop) " (learnt)")
            e.cost := Min(d, drop)
        }
    e.seen.Push(drop)
    if (e.seen.Length > 6)
        e.seen.RemoveAt(1)
}
PL_Cost(slot) => PL_Costs().Has(slot) ? PL_Costs()[slot].cost : 0

; after a missed placement: wait until there's enough money (known cost) or the money has grown
PL_WaitForMoney(cost := 0, maxMs := 15000) {
    start := A_TickCount
    m0 := PL_ReadMoneySure()
    if (m0 < 0) {
        Sleep(2500)
        return
    }
    target := cost > 0 ? cost : m0 + Max(300, m0 // 4)
    m := m0
    while (m < target && A_TickCount - start < maxMs) {
        Sleep(1000)
        if CheckForXp() || CheckForReturnToLobby() || CheckForNextText()
            return
        r := PL_ReadMoneySure()
        if (r >= 0)
            m := r
    }
    PL_Log("waited " Round((A_TickCount - start) / 1000, 1) " s for money (" m0 " -> " m (cost > 0 ? ", unit costs " cost : "") ")")
}


; [Smart placement v2] our own placed spots in this room (so units spread along the path)
PL_Placed() {
    global stageStartTime
    static st := {room: 0, list: [], bad: []}
    room := IsSet(stageStartTime) ? stageStartTime : 0
    if (st.room != room)
        st.room := room, st.list := [], st.bad := []
    return st
}
PL_NotePlaced(x, y) => PL_Placed().list.Push({x: x, y: y})
PL_NoteBad(spot) => PL_Placed().bad.Push(spot)   ; a spot that failed twice - no unit tries it again this room

; unit reach in pixels on the 800 x 600 Roblox window (Settings\UnitTypes.txt: Range=140)
PL_Range() {
    try {
        if RegExMatch(FileRead(UT_File(), "UTF-8"), "im)^\s*Range\s*=\s*(\d+)", &m)
            return Integer(m[1])
    }
    return 140
}


; [Smart placement v2] after a failed placement: was it just "Not enough money!"? (reads the red message, not the money)
PL_NoMoney() {
    static saved := 0
    if !WinExist(rblxID)
        return false
    WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
    saved += 1
    r := VH_Call(Format("cmd=nomoney`nx={}`ny={}`nw={}`nh={}`nsave={}", cx, cy, cw, ch, saved <= 15 ? 1 : 0), 1000)
    if !(r && r.Has("nomoney"))
        return false
    return r["nomoney"] = "1"
}


; [Max units] read the game's message in the middle of the screen ("Not enough money!", "Cannot place more than 3"...)
PL_GameMessage() {
    t := ""
    try t := VH_OCRClient(176, 419, 448, 72, 2)
    if (t = "") {
        try {
            WinGetClientPos(&dx, &dy, , , rblxID)
            r := OCR.FromRect(176 + dx, 419 + dy, 448, 72, "FirstFromAvailableLanguages", { grayscale: true, scale: 2.0 })
            t := r ? r.Text : ""
        }
    }
    return StrLower(t)
}
PL_MaxedMessage(msg) => (msg != "" && RegExMatch(msg, "more than|maximum|limit"))


; [Buildings] the map name for the placement memory (from map detection)
PL_Map() {
    try return ST_S().map
    return ""
}
; [Buildings] a spot failed for no visible reason - let the helper learn the object that's there
PL_NoteFail(spot) {
    r := VH_Call(Format("cmd=fail`nx={}`ny={}`nroom={}`nmap={}", spot.x, spot.y, PL_Placed().room, PL_Map()), 1500)
    if (r && r.Has("info"))
        PL_Log("spot " spot.x ", " spot.y " blocked - " r["info"] " (remembered for " PL_Map() ")")
}


; ---- [Good spots] spots where a unit really went down (proven by the hotbar count) are kept per map in
; Settings\GoodSpots\<map>.txt ("x,y,type,score") and tried first next time - Summer maps come back every
; hour and Dungeon rooms repeat, so after a run or two a map places almost instantly. A remembered spot
; that the count proves failed loses points and is dropped, so a changed camera can't keep it alive.
global GS_Cache := Map()
GS_File(map) => A_ScriptDir "\Settings\GoodSpots\" RegExReplace(map, "[^\w\- ()]", "_") ".txt"
GS_Load(map) {
    global GS_Cache
    if (map = "" || map = "no map found")
        return []
    if GS_Cache.Has(map)
        return GS_Cache[map]
    list := []
    try {
        for line in StrSplit(FileRead(GS_File(map), "UTF-8"), "`n", "`r") {
            p := StrSplit(Trim(line), ",")
            if (p.Length >= 4)
                list.Push({x: Integer(p[1]), y: Integer(p[2]), type: p[3], score: Integer(p[4])})
        }
    }
    GS_Cache[map] := list
    return list
}
GS_Save(map) {
    global GS_Cache
    if !GS_Cache.Has(map)
        return
    txt := ""
    for g in GS_Cache[map]
        txt .= g.x "," g.y "," g.type "," g.score "`n"
    try {
        DirCreate(A_ScriptDir "\Settings\GoodSpots")
        f := FileOpen(GS_File(map), "w", "UTF-8")
        f.Write(txt), f.Close()
    }
}
; best remembered spot for this unit that isn't taken / known bad this room, or 0
GS_Next(slot, bad) {
    global successfulCoordinates
    map := PL_Map()
    list := GS_Load(map)
    if (!list.Length)
        return 0
    utype := UT_Get(slot)
    taken := []
    for c in successfulCoordinates
        taken.Push(c)
    for c in PL_Placed().list
        taken.Push(c)
    for c in bad
        taken.Push(c)
    for c in PL_Placed().bad
        taken.Push(c)
    best := 0
    for g in list {
        if (g.score <= 0)
            continue
        if (utype != "Hybrid" && g.type != "Hybrid" && g.type != utype)
            continue
        ok := true
        for c in taken
            if (Abs(c.x - g.x) < 30 && Abs(c.y - g.y) < 30) {
                ok := false
                break
            }
        if (ok && (!best || g.score > best.score))
            best := g
    }
    if !best
        return 0
    PL_Log("Unit " slot ": trying a spot that worked before on " map " (" best.x ", " best.y ", score " best.score ")")
    return {x: best.x, y: best.y, mem: true}
}
GS_Note(x, y, slot, delta) {
    global GS_Cache
    map := PL_Map()
    if (map = "" || map = "no map found")
        return
    list := GS_Load(map)
    utype := UT_Get(slot)
    for i, g in list {
        if (Abs(g.x - x) <= 12 && Abs(g.y - y) <= 12) {
            g.score := Max(-3, Min(20, g.score + delta))
            if (g.score <= -2)
                list.RemoveAt(i)
            GS_Save(map)
            return
        }
    }
    if (delta > 0) {
        list.Push({x: x, y: y, type: utype, score: delta})
        GS_Save(map)
    }
}

; ---- [Hover check] with the unit held over the spot, look at what the game draws there before clicking.
; For now this only measures and logs (with the result of the click) so the rule can be tuned on real
; tries; it starts skipping spots once Settings\HoverSkip.txt says On.
PL_Hover(x, y) {
    if !WinExist(rblxID)
        return 0
    WinGetClientPos(&cx, &cy, &cw, &ch, rblxID)
    MouseMove(x, y)
    Sleep(70)
    r := 0
    try r := VH_Call(Format("cmd=hover`nx={}`ny={}`nw={}`nh={}`ncx={}`ncy={}", cx, cy, cw, ch, x, y), 1500)
    return (r && r.Has("ok") && r["ok"] = "1") ? r : 0
}
PL_HoverText(hv) => hv ? ("disc red " hv["dred"] " blue " hv["dblue"] ", ring red " hv["red"] " blue " hv["blue"] " (r " hv["br"] ")") : "no reading"
PL_HoverSkip(hv) {
    static on := -1
    if (on = -1) {
        on := 0
        try on := InStr(FileRead(A_ScriptDir "\Settings\HoverSkip.txt"), "On") ? 1 : 0
    }
    if (!on || !hv)
        return false
    ; tuned on 60 real tries (17 placed, 43 failed): on a usable spot the range ring is drawn blue
    ; (blue cover median ~0.19), on a blocked one it's red with almost no blue (~0.05). This rule skips
    ; 31 of the 43 failed tries and only 1 of the 17 good ones.
    ; [Retuned 11-02] the ring colour alone misjudged sandy maps (orange sand looks like the red ring), so
    ; now the spot right under the unit must also be red: skip when that disc is clearly red (>= 0.5 -
    ; no placed try ever had more than 0.43), or partly red (>= 0.2) with a red, blue-less ring.
    dr := Float(hv["dred"]), rb := Float(hv["blue"]), rr := Float(hv["red"])
    db := hv.Has("dblue") ? Float(hv["dblue"]) : 1
    ; [Retuned 11-03 on 655 real tries from the 24/7 PC: 175 placed, 480 failed] the old rule only caught
    ; 13 of the 480 failed tries. A usable spot almost always shows SOME blue (range ring / preview):
    ; no blue at all on the ring AND under the unit -> skip. Kept 173/175 placed, skips 77 more failed.
    return (dr >= 0.5) || (dr >= 0.2 && rb < 0.10 && rr >= 0.13) || (rb < 0.08 && db < 0.08)
}

