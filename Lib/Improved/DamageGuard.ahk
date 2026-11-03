; [Damage guard] keeps you from being the lowest-damage player in Summer Hunt matchmaking (a protection
; against matchmaking bans). Every minute from wave 20 on it opens the player list (Tab: "People / Total
; Damage", highest first), reads everyone's damage and the wave counter, and closes it again.
;  - behind = last of 3+ players, or below MinDamage once the wave reaches AtWave
;  - while behind: every placed unit gets upgraded (not only the ticked ones) to raise damage
;  - behind at the end of 2 matches in a row: Dungeon until the Summer map changes (no early leaving)
; Settings\DamageGuard.txt (one per line):  On=1   Name=<your name in the list>   MinDamage=50M   AtWave=47

DG_S() {
    static s := {last: 0, behind: false, matchBehind: false, bad: 0, wave: 0}
    return s
}

DG_Cfg(key, def) {
    static cache := "", t := 0
    if (A_TickCount - t > 30000 || cache = "") {
        cache := ""
        try cache := FileRead(A_ScriptDir "\Settings\DamageGuard.txt", "UTF-8")
        t := A_TickCount
    }
    if RegExMatch(cache, "im)^\s*" key "\s*=\s*(.+?)\s*$", &m)
        return m[1]
    return def
}
DG_On() => DG_Cfg("On", "1") = "1"

; "0", "845", "12,345,678", "350K", "12.5M", "1.2B", "3T" -> number (0 if it can't be read)
DG_Num(t) {
    t := StrUpper(StrReplace(StrReplace(Trim(t), ",", ""), " ", ""))
    t := StrReplace(StrReplace(t, "O", "0"), "L", "1")
    if !RegExMatch(t, "^(\d+(?:\.\d+)?)([KMBT]?)$", &m)
        return -1
    mult := Map("", 1, "K", 1e3, "M", 1e6, "B", 1e9, "T", 1e12)
    return Float(m[1]) * mult[m[2]]
}
DG_Fmt(n) => n >= 1e9 ? Round(n / 1e9, 2) "B" : n >= 1e6 ? Round(n / 1e6, 1) "M" : n >= 1e3 ? Round(n / 1e3) "K" : Round(n)

DG_Wave() {
    if RegExMatch(SH_Text(150, 60, 160, 36), "i)wave\D{0,3}(\d{1,3})", &m)
        return Integer(m[1])
    return 0
}

; open the player list, read [{name, dmg}] (top = most damage), close it again
DG_ListOpen() => RegExMatch(SH_Text(555, 70, 240, 40), "people|total dama") ? true : false
DG_ReadBoard() {
    rows := []
    SendInput("{Tab}")
    Sleep(450)
    if !DG_ListOpen() {          ; it was already open and Tab just closed it - open it again
        SendInput("{Tab}")
        Sleep(450)
        if !DG_ListOpen()
            return rows
    }
    items := SH_Items(555, 70, 240, 300, 1.5)
    names := [], vals := []
    for it in items {
        if RegExMatch(it.t, "people|total|damage|level|enemies|weather|modifier|boost|reward")
            continue
        if (it.x >= 715 && DG_Num(it.t) >= 0)
            vals.Push(it)
        else if (it.x < 715 && StrLen(it.t) >= 2)
            names.Push(it)
    }
    for nm in names {
        best := 0
        for v in vals
            if (Abs(v.y - nm.y) <= 12)
                best := v
        if best
            rows.Push({name: nm.t, dmg: DG_Num(best.t), y: nm.y})
    }
    SendInput("{Tab}")           ; close it again
    Sleep(300)
    if DG_ListOpen()
        FixClick(564, 72), Sleep(200)   ; its X, top left of the list
    return rows
}

; called every second from MonitorStage in Summer Hunt
DG_Tick() {
    if (!SH_On() || !DG_On())
        return
    s := DG_S()
    if (A_TickCount - s.last < 60000)
        return
    s.last := A_TickCount
    try {
        if (SH_CardsUp() || SH_VoteVisible())
            return
    }
    wave := DG_Wave()
    if (wave > 0)
        s.wave := wave
    if (s.wave < 20)
        return
    me := StrLower(DG_Cfg("Name", ""))
    if (me = "") {
        static warned := 0
        if !warned
            AddToLog("[Damage guard] Put your in-game name in Settings\DamageGuard.txt (Name=...) to turn it on"), warned := 1
        return
    }
    rows := DG_ReadBoard()
    if (rows.Length < 2) {
        SH_Log("damage: couldn't read the player list (" rows.Length " rows)")
        return
    }
    myRank := 0, myDmg := -1, n := rows.Length
    ; the list is sorted, but sort again by the numbers read, to be safe
    sorted := []
    for r in rows
        sorted.Push(r)
    loop sorted.Length - 1 {
        loop sorted.Length - A_Index {
            i := A_Index
            if (sorted[i].dmg < sorted[i + 1].dmg)
                t := sorted[i], sorted[i] := sorted[i + 1], sorted[i + 1] := t
        }
    }
    for i, r in sorted
        if (SH_Lev(StrLower(r.name), me) <= Max(1, StrLen(me) // 4))
            myRank := i, myDmg := r.dmg
    line := ""
    for r in sorted
        line .= r.name " " DG_Fmt(r.dmg) ", "
    SH_Log("damage: wave " s.wave " - " RTrim(line, ", "))
    if (!myRank) {
        SH_Log("damage: didn't find '" me "' in the list")
        return
    }
    minDmg := DG_Num(DG_Cfg("MinDamage", "50M")), atWave := Integer(DG_Cfg("AtWave", "47"))
    last := (n >= 3 && myRank = n)
    low := (s.wave >= atWave && minDmg > 0 && myDmg < minDmg)
    was := s.behind
    s.behind := last || low
    s.matchBehind := s.behind
    if (s.behind && !was)
        AddToLog("[Damage guard] You're " (last ? "last in damage (" myRank "/" n ")" : "below " DG_Fmt(minDmg))
            . " at wave " s.wave " (" DG_Fmt(myDmg) ") - upgrading every unit to catch up")
    else if (!s.behind && was)
        AddToLog("[Damage guard] Caught up - " myRank "/" n " with " DG_Fmt(myDmg))
}

; true while behind: the upgrader then upgrades every placed unit, not only the ticked ones
DG_Boost() => SH_On() && DG_On() && DG_S().behind

; called when a match ends
DG_MatchEnd() {
    if (!SH_On() || !DG_On())
        return
    s := DG_S()
    if (s.matchBehind) {
        s.bad += 1
        SH_Log("damage: ended the match behind (" s.bad " in a row)")
    } else
        s.bad := 0
    s.behind := false, s.matchBehind := false, s.wave := 0, s.last := 0
    if (s.bad >= 2) {
        s.bad := 0
        global SH_FallbackUntil
        next := DateAdd(FormatTime(, "yyyyMMddHH") "0000", 1, "Hours")
        SH_FallbackUntil := next
        SH_SaveUntil(next)
        AddToLog("[Damage guard] Lowest damage 2 matches in a row - playing Dungeon until " FormatTime(next, "HH:mm") " to stay safe")
        SH_Log("damage: 2 bad matches -> Dungeon until " FormatTime(next, "HH:mm"))
    }
}
