; =====================================================================
; [Improved] Helpers added for the Improved copy.
;   - text reading (OCR) for curses, shrines and the shop
;   - Settings\Improved.txt (simple key=value settings, re-read every 30s)
;   - debug screenshots in Logs\Debug
;   - frozen-screen watchdog and recovery
;   - room stats
; Functions only - no code runs at load time.
; =====================================================================

IMP_SettingsFile() {
    return A_ScriptDir "\Settings\Improved.txt"
}

IMP_Settings(name, def := "") {
    static cache := 0, loadedAt := 0
    if (!cache || A_TickCount - loadedAt > 30000) {
        cache := Map()
        loadedAt := A_TickCount
        f := IMP_SettingsFile()
        if !FileExist(f)
            IMP_WriteDefaultSettings(f)
        try {
            for line in StrSplit(FileRead(f, "UTF-8"), "`n", "`r") {
                line := Trim(line)
                if (line = "" || SubStr(line, 1, 1) = ";")
                    continue
                parts := StrSplit(line, "=", , 2)
                if (parts.Length = 2)
                    cache[Trim(parts[1])] := Trim(parts[2])
            }
        }
    }
    return cache.Has(name) ? cache[name] : def
}

IMP_WriteDefaultSettings(f) {
    txt := "
    (
; Improved macro settings. Edit, save, and the macro picks it up within 30 seconds.
; Lists are comma separated. Case does not matter.
;
; Curses to avoid. "auto" judges each curse against your loadout (Settings\Loadout.txt):
;   always avoids ones that hurt your team most, and avoids medium ones once the run already has 2+ curses.
; You can add names after auto, e.g.  auto, Wind
; Known names: Flying, Wind, Money, Health, Exploding, Shielding, Regen, Vampirism, Frenzy, Armor, Burst, Chaos, Eruption, Shopping
; Curses ticked in the menu are always avoided too.
AvoidCurses=auto
; When a cursed room's curse can't be read: Enter, Avoid, or auto (enter only if the run has fewer than 2 curses)
UnknownCurse=auto
;
; Shrines to deny. Same rules as AvoidCurses ("auto" = judged against your loadout).
AvoidShrines=auto
; When a shrine can't be read: Deny or Accept
UnknownShrine=Deny
;
; Shop: auto = buys the most useful items for your loadout first (magic damage, cost cuts, boss damage...)
;       *    = buy everything (old behaviour)
;       or list words from item names to buy only those, e.g. Archmage, Tome, Mask
ShopBuy=auto
;
; Seconds the screen may stay completely frozen before the macro works out where it is (0 = off)
FrozenScreenSec=120
; Save a screenshot to Logs\Debug when something goes wrong (1 = on, 0 = off)
DebugShots=1
    )"
    try FileAppend(txt "`n", f, "UTF-8")
}

; ---------------------------------------------------------------- loadout
; Settings\Loadout.txt: one line per hotbar slot:  SlotN=Name | max placements | Magic/Physical/Farm | hits air Yes/No/?
IMP_Loadout() {
    static cache := 0, loadedAt := 0
    if (cache && A_TickCount - loadedAt < 30000)
        return cache
    f := A_ScriptDir "\Settings\Loadout.txt"
    if !FileExist(f) {
        txt := "
        (
; Your current loadout in hotbar order (slot 1 = key 1). Change this when you change your team.
; Format:  SlotN=Name | max placements (- = no limit) | Magic, Physical or Farm | hits air: Yes, No or ?
; Max placements caps what the menu asks for, so the macro doesn't waste time trying to place a Unique unit twice.
Slot1=Dark Mage (Fallen Star) | - | Magic | Yes
Slot2=Spider (Immolation) | - | Physical | ?
Slot3=Elyssia (Abyssal) | - | Magic | ?
Slot4=Speedwagon | - | Farm | No
Slot5=Bulma | - | Farm | No
Slot6=Alucard | - | Magic | No
        )"
        try FileAppend(txt "`n", f, "UTF-8")
    }
    slots := []
    Loop 6
        slots.Push({name: "Slot " A_Index, max: 0, type: "?", air: "?"})
    try {
        for line in StrSplit(FileRead(f, "UTF-8"), "`n", "`r") {
            if !RegExMatch(Trim(line), "i)^Slot([1-6])\s*=\s*(.*)$", &m)
                continue
            p := StrSplit(m[2], "|")
            o := slots[Integer(m[1])]
            o.name := Trim(p[1])
            if (p.Length >= 2 && IsInteger(Trim(p[2])))
                o.max := Integer(Trim(p[2]))
            if (p.Length >= 3)
                o.type := Trim(p[3])
            if (p.Length >= 4)
                o.air := Trim(p[4])
        }
    }
    cache := slots
    loadedAt := A_TickCount
    return cache
}

; Placement cap for a slot from the loadout (0 = no cap)
IMP_SlotMax(slot) {
    return IMP_Loadout()[slot].max
}

IMP_SlotName(slot) {
    return IMP_Loadout()[slot].name
}

; How many placements of a kind the team has: kind = "Magic", "Physical", "Farm" or "air"
IMP_TeamCount(kind) {
    n := 0
    for i, o in IMP_Loadout() {
        try {
            want := %(GetNameForMode() "placement" i)%
            count := Integer(want.Text)
        } catch {
            count := 1
        }
        if (o.max > 0)
            count := Min(count, o.max)
        if (kind = "air" ? (o.air = "Yes") : (o.type = kind))
            n += count
    }
    return n
}

; ---------------------------------------------------------------- curses taken this run
IMP_RunCurses(action := "get", name := "") {
    static taken := []
    if (action = "reset")
        taken := []
    else if (action = "add" && name != "")
        taken.Push(name)
    return taken
}

; 0 = harmless for this team, 1 = medium, 2 = dangerous
IMP_CurseDanger(name) {
    switch IMP_Canon(name) {
        case "Frenzy", "Health", "Chaos":
            return 2   ; +50% speed / +80% HP / random curses
        case "Flying":
            return IMP_TeamCount("air") < 2 ? 2 : 1   ; few of your units can hit flying enemies
        case "Wind", "Vampirism", "Eruption", "Burst":
            return 1
        case "Armor":
            return IMP_TeamCount("Physical") > IMP_TeamCount("Magic") ? 1 : 0   ; your team is mostly magic
        default:
            return 0   ; Money, Shopping, Shielding, Regen, Exploding: small effect on big hitters
    }
}

; Returns why to avoid (text) or "" to allow. listKey = "AvoidCurses" or "AvoidShrines"
IMP_AvoidReason(name, menuList, listKey) {
    if IMP_InList(menuList, name)
        return "picked in menu"
    setting := IMP_Settings(listKey, "auto")
    if IMP_InList(StrSplit(setting, ","), name)
        return "in " listKey
    if InStr(setting, "auto") {
        d := IMP_CurseDanger(name)
        n := IMP_RunCurses().Length
        if (d >= 2)
            return "dangerous for your team"
        if (d = 1 && n >= 2)
            return "run already has " n " curses"
    }
    return ""
}

; ---------------------------------------------------------------- text reading
IMP_OCR(x1, y1, x2, y2, scale := 3.0) {
    try {
        FT_GetOffset(&dx, &dy)
        r := OCR.FromRect(x1 + dx, y1 + dy, x2 - x1, y2 - y1, "FirstFromAvailableLanguages", { grayscale: true, scale: scale })
        return r ? r.Text : ""
    } catch {
        return ""
    }
}

IMP_Short(t) {
    t := Trim(RegExReplace(t, "\s+", " "))
    return t = "" ? "(nothing)" : SubStr(t, 1, 120)
}

; Turns any spelling of a curse/shrine into one name ("Explosion" -> "Exploding", "Vamparism" -> "Vampirism")
IMP_Canon(word) {
    static keys := [
        ["vamp", "Vampirism"], ["frenz", "Frenzy"], ["armo", "Armor"], ["burst", "Burst"],
        ["chaos", "Chaos"], ["erupt", "Eruption"], ["shopp", "Shopping"], ["shield", "Shielding"],
        ["regen", "Regen"], ["explo", "Exploding"], ["flight", "Flying"], ["flying", "Flying"],
        ["wind", "Wind"], ["money", "Money"], ["health", "Health"]
    ]
    w := StrLower(word)
    for k in keys
        if InStr(w, k[1])
            return k[2]
    return ""
}

; Finds the curse/shrine name in a block of read text. Returns "" if unsure.
IMP_FindCurseName(text) {
    if (text = "")
        return ""
    if RegExMatch(text, "i)curse\s*of\s*(?:the\s*)?([a-z]+)", &m) {
        c := IMP_Canon(m[1])
        if (c != "")
            return c
    }
    if RegExMatch(text, "i)([a-z]+)\s*curse", &m) {
        c := IMP_Canon(m[1])
        if (c != "")
            return c
    }
    ; fallback: exactly one known name anywhere in the text
    found := ""
    for word in StrSplit(RegExReplace(text, "[^A-Za-z]+", " "), " ") {
        if (StrLen(word) < 4)
            continue
        c := IMP_Canon(word)
        if (c = "")
            continue
        if (found != "" && found != c)
            return ""   ; two different names - too unsure
        found := c
    }
    return found
}

IMP_InList(list, name) {
    for item in list
        if (IMP_Canon(item) != "" && IMP_Canon(item) = IMP_Canon(name))
            return true
    return false
}

IMP_ShouldAvoidCurse(name) {
    global enabledCurses
    return IMP_AvoidReason(name, enabledCurses, "AvoidCurses")
}

IMP_ShouldAvoidShrine(name) {
    global enabledShrines
    return IMP_AvoidReason(name, enabledShrines, "AvoidShrines")
}

; How useful a shop item is for this loadout (higher = buy first). 0 = not worth it. -1 = unreadable.
IMP_ShopScore(text) {
    t := StrLower(text)
    if (Trim(t) = "")
        return -1
    magic := IMP_TeamCount("Magic") > 0
    phys := IMP_TeamCount("Physical") > 0
    static table := [
        ["archmage", 100, "m"], ["tome", 80, "m"], ["mask", 75, ""], ["celestial", 70, ""],
        ["mushroom", 60, ""], ["reaper", 55, ""], ["scythe", 55, ""], ["coat", 50, "m"],
        ["genie", 45, ""], ["lamp", 45, ""], ["glacial", 45, ""], ["branch", 40, ""],
        ["bow", 35, ""], ["belt", 35, ""], ["golden fish", 30, ""], ["fish", 20, ""],
        ["maul", 15, "p"], ["cleaver", 10, "p"]
    ]
    for row in table {
        if InStr(t, row[1]) {
            if (row[3] = "m" && !magic) || (row[3] = "p" && !phys)
                return 1
            return row[2]
        }
    }
    return 25   ; unknown item - still worth a try after the known good ones
}

IMP_ShopWants(itemText) {
    buy := IMP_Settings("ShopBuy", "*")
    if (buy = "" || buy = "*")
        return true
    for w in StrSplit(buy, ",") {
        w := Trim(w)
        if (w != "" && InStr(itemText, w))
            return true
    }
    return false
}

; ---------------------------------------------------------------- debug screenshots
IMP_DebugShot(tag) {
    global offsetX, offsetY
    static last := 0
    if (IMP_Settings("DebugShots", "1") != "1" || (last && A_TickCount - last < 20000))
        return
    last := A_TickCount
    try {
        dir := A_ScriptDir "\Logs\Debug"
        DirCreate(dir)
        list := ""
        Loop Files dir "\*.bmp"
            list .= A_LoopFileFullPath "`n"
        if (list != "") {
            arr := StrSplit(Sort(RTrim(list, "`n")), "`n")
            while (arr.Length > 40)
                FileDelete(arr.RemoveAt(1))
        }
        FT_GetOffset(&dx, &dy)
        file := dir "\" FormatTime(, "yyyyMMdd_HHmmss") "_" tag ".bmp"
        FindText().SavePic(file, offsetX + dx, offsetY + dy, offsetX + dx + 830, offsetY + dy + 660, 1)
        AddToLog("[Debug] Saved screenshot: " tag)
    }
}

; ---------------------------------------------------------------- frozen-screen watchdog
IMP_ScreenSig() {
    global offsetX, offsetY
    old := A_CoordModePixel
    CoordMode("Pixel", "Screen")
    sig := ""
    try {
        FT_GetOffset(&dx, &dy)
        Loop 5 {
            row := A_Index
            Loop 6
                sig .= PixelGetColor(offsetX + dx + 60 + (A_Index - 1) * 135, offsetY + dy + 70 + (row - 1) * 115) ","
        }
    }
    CoordMode("Pixel", old)
    return sig
}

; Returns true (once) when the screen has not changed at all for FrozenScreenSec.
IMP_ScreenFrozen() {
    static lastSig := "", since := 0
    limit := IMP_Settings("FrozenScreenSec", "120")
    if !IsNumber(limit) || limit <= 0
        return false
    sig := IMP_ScreenSig()
    if (sig = "" || sig != lastSig) {
        lastSig := sig
        since := A_TickCount
        return false
    }
    if (A_TickCount - since >= limit * 1000) {
        since := A_TickCount
        return true
    }
    return false
}

; Works out which screen we are on and jumps to the right step.
IMP_Recover(fromEndScreen := false) {
    global mode
    AddToLog("[Watchdog] Screen hasn't changed for a while - checking where we are")
    IMP_DebugShot("frozen")
    if (!fromEndScreen && (CheckForXp() || CheckForReturnToLobby() || CheckForNextText())) {
        AddToLog("[Watchdog] Results screen is up - going to results")
        return NextStep(HandleStageEnd)
    }
    if (mode = "Dungeon" && DungeonMapVisible()) {
        AddToLog("[Watchdog] Room map is showing - picking a room")
        return NextStep(LookForDungeonRooms)
    }
    if FT(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText) {
        AddToLog("[Watchdog] In the lobby - starting the mode again")
        return NextStep(StartSelectedMode)
    }
    AddToLog("[Watchdog] Couldn't tell which screen this is - clicking to wake it")
    FixClick(607, 553)
}

; ---------------------------------------------------------------- stats
IMP_RoomDone(isWin) {
    static first := 0, rooms := 0, wins := 0
    rooms += 1
    wins += isWin ? 1 : 0
    if (!first) {
        first := A_TickCount
        AddToLog("[Stats] Rooms: 1 | Wins: " wins)
        return
    }
    ms := A_TickCount - first
    perHour := (rooms - 1) / (ms / 3600000)
    AddToLog(Format("[Stats] Rooms: {} | Wins: {} | {:.1f} rooms/hour | avg {} per room", rooms, wins, perHour, FormatStageTime(ms // (rooms - 1))))
}

; ---------------------------------------------------------------- upgrade learning
; Each time a unit's upgrade panel is open, read its level. The first time a slot is seen at a
; level, save the whole panel's text to Logs\UpgradeData.txt and a screenshot to Logs\Debug\Upgrades.
; This is the data for value-based upgrading (damage gained per yen spent).
IMP_LearnUpgrade(slot) {
    global offsetX, offsetY
    static seen := Map()
    if (!slot)
        return
    try {
        lvlText := IMP_OCR(170, 228, 312, 253, 4.0)
        lvl := RegExMatch(lvlText, "i)(\d+)", &m) ? m[1] : (InStr(lvlText, "max") ? "MAX" : "?")
        key := slot "|" lvl
        if (seen.Has(key) || seen.Count > 200)
            return
        seen[key] := true
        panel := IMP_OCR(15, 165, 335, 485, 2.5)
        line := FormatTime(, "yyyy-MM-dd HH:mm:ss") " | slot " slot " (" IMP_SlotName(slot) ") | level " lvl " | " RegExReplace(panel, "\s+", " ")
        FileAppend(line "`n", A_ScriptDir "\Logs\UpgradeData.txt", "UTF-8")
        dir := A_ScriptDir "\Logs\Debug\Upgrades"
        DirCreate(dir)
        file := dir "\slot" slot "_level" lvl ".bmp"
        if !FileExist(file) {
            FT_GetOffset(&dx, &dy)
            FindText().SavePic(file, offsetX + dx, offsetY + dy, offsetX + dx + 830, offsetY + dy + 660, 1)
        }
    }
}
