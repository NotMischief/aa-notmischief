; [Polish] Small live stats card right of "Save Config".
; Runtime only counts while the macro is running (F2). Rooms = wins + losses.

ST_S() {
    static s := {ctl: Map(), all: [], shown: true, runMs: 0, lastTick: 0, glitches: 0, map: "-"}
    return s
}

ST_Glitch() => ST_S().glitches += 1
ST_SetMap(name) {
    if (name != "" && name != "no map found")
        ST_S().map := name
}

ST_Build(gui) {
    global uiTheme
    s := ST_S()
    s.ctl := Map(), s.all := [], s.shown := true   ; fresh controls if the window is built again
    ; a small card in the empty space right of "Save Config"
    x0 := 905, y0 := 447, w := 448, h := 44
    for r in [[x0, y0, w, 1], [x0, y0 + h, w, 1], [x0, y0, 1, h], [x0 + w - 1, y0, 1, h + 1]]
        s.all.Push(gui.Add("Text", "x" r[1] " y" r[2] " w" r[3] " h" r[4] " +Background" uiTheme[3]))
    gui.SetFont("Bold s8 c" uiTheme[3], "Segoe UI")
    s.all.Push(gui.Add("Text", "x" (x0 + 8) " y" (y0 + 4) " w60 h14 +BackgroundTrans", "LIVE"))
    rows := [[["time", "Time", 110], ["rooms", "Rooms", 140], ["wl", "W / L", 110]],
             [["map", "Map", 250], ["glitch", "Hotbar glitches", 110]]]
    for i, row in rows {
        x := x0 + 52, y := y0 + 4 + (i - 1) * 19
        for cell in row {
            gui.SetFont("Bold s9 c" uiTheme[3], "Segoe UI")
            lbl := gui.Add("Text", "x" x " y" y " h17 +BackgroundTrans", cell[2])
            lbl.GetPos(, , &lw), s.all.Push(lbl)
            gui.SetFont("norm s9 c" uiTheme[1], "Segoe UI")
            s.ctl[cell[1]] := gui.Add("Text", "x" (x + lw + 5) " y" y " w" (cell[3] - lw - 5) " h17 +BackgroundTrans", "-")
            s.all.Push(s.ctl[cell[1]])
            x += cell[3] + 8
        }
    }
    gui.SetFont("norm s11 c" uiTheme[1], "Segoe UI")
    ST_Tick()
    SetTimer(ST_Tick, 1000)
}

ST_Tick() {
    try ST_Update()
    catch   ; the window was closed or rebuilt - stop updating instead of showing an error
        SetTimer(ST_Tick, 0)
}

ST_Update() {
    global Wins, loss, SaveChestsBox, MatchMaking, ReturnLobbyBox
    s := ST_S()
    now := A_TickCount
    active := false
    try active := MacroLoopState.Active
    if (active && s.lastTick)
        s.runMs += now - s.lastTick
    s.lastTick := now
    ; the Dungeon options use the same space - step aside while they are showing
    want := true
    try want := !SaveChestsBox.Visible
    try want := want && !MatchMaking.Visible && !ReturnLobbyBox.Visible   ; Fool's / Summer Hunt options use this space too
    if (want != s.shown) {
        s.shown := want
        for c in s.all
            c.Visible := want
    }
    t := s.runMs // 1000
    rooms := Wins + loss
    perHour := s.runMs > 60000 ? Round(rooms / (s.runMs / 3600000), 1) : 0
    ST_Set("time", Format("{}:{:02}:{:02}", t // 3600, Mod(t // 60, 60), Mod(t, 60)))
    ST_Set("rooms", rooms " (" perHour "/hr)")
    ST_Set("wl", Wins " / " loss)
    ST_Set("map", s.map)
    ST_Set("glitch", s.glitches)
}

ST_Set(key, val) {
    c := ST_S().ctl[key]
    if (c.Text != String(val))   ; only redraw when it changes (no flicker)
        c.Text := val
}
