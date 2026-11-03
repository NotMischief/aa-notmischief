; =====================================================================
; [Unit types] Tell the macro what kind of unit is in each hotbar slot:
;   Ground = can only go on the ground, Hill = only on hills, Hybrid = either.
; F6 opens the window. Saved to Settings\UnitTypes.txt.
; The smarter placement (Improved v4) uses this to pick the right spots.
; =====================================================================

UT_File() {
    return A_ScriptDir "\Settings\UnitTypes.txt"
}

; "Ground", "Hill" or "Hybrid" for a hotbar slot (1-6). Unknown slots count as Hybrid.
UT_Get(slot) {
    try {
        if RegExMatch(FileRead(UT_File(), "UTF-8"), "im)^\s*Slot" slot "\s*=\s*(Ground|Hill|Hybrid)", &m)
            return m[1]
    }
    return "Hybrid"
}

UT_ShowWindow(*) {
    static win := 0
    global uiTheme
    if (win) {
        try win.Destroy()
        win := 0
    }
    bg := uiTheme[2], fg := uiTheme[1], accent := uiTheme[3], muted := "8C8C8C"
    types := ["Ground", "Hill", "Hybrid"]
    win := Gui("+AlwaysOnTop +ToolWindow -DPIScale", "AA NotMischef - Placement & Vision")
    win.BackColor := bg
    win.MarginX := 16, win.MarginY := 12

    win.SetFont("s13 Bold c" accent, "Segoe UI")
    win.Add("Text", "xm w340", "Placement & Vision")
    win.SetFont("s9 Norm c" muted, "Segoe UI")
    win.Add("Text", "xm y+2 w340", "F6 opens this window. Changes apply from the next unit placed.")

    ; --- unit types
    win.SetFont("s10 Bold c" fg, "Segoe UI")
    win.Add("Text", "xm y+14 w340", "Unit type per hotbar slot")
    win.Add("Progress", "xm y+4 w340 h2 Background" accent " c" accent, 100)
    win.SetFont("s10 Norm c" fg, "Segoe UI")
    boxes := []
    Loop 6 {
        col := Mod(A_Index - 1, 2), row := (A_Index - 1) // 2
        x := 16 + col * 175, y := 108 + row * 34
        win.Add("Text", Format("x{} y{} w55 h24 +0x200", x, y), "Unit " A_Index)
        cur := UT_Get(A_Index)
        dd := win.Add("DropDownList", Format("x{} y{} w95", x + 58, y), types)
        dd.Choose(cur = "Ground" ? 1 : cur = "Hill" ? 2 : 3)
        boxes.Push(dd)
    }
    win.SetFont("s9 Norm c" muted, "Segoe UI")
    win.Add("Text", "xm y+10 w340", "Ground = ground only   Hill = hills only   Hybrid = either")

    ; --- switches
    win.SetFont("s10 Bold c" fg, "Segoe UI")
    win.Add("Text", "xm y+14 w340", "Switches")
    win.Add("Progress", "xm y+4 w340 h2 Background" accent " c" accent, 100)
    win.SetFont("s10 Norm c" fg, "Segoe UI")
    smart := win.Add("CheckBox", "xm y+10 w340", "Smart placement  (read the green / red map)")
    smart.Value := PL_Enabled() ? 1 : 0
    py := win.Add("CheckBox", "xm y+8 w340", "Python vision  (fast map reading + RapidOCR)")
    py.Value := VH_Enabled() ? 1 : 0
    win.SetFont("s9 Norm c" muted, "Segoe UI")
    status := VH_Ready() ? "Python helper: running" : (VH_Enabled() ? "Python helper: not running (built-in reading is used)" : "Python helper: off")
    win.Add("Text", "xm y+6 w340", status)

    ; --- buttons
    win.SetFont("s10 Bold", "Segoe UI")
    save := win.Add("Button", "xm y+16 w160 h30 Default", "Save")
    save.OnEvent("Click", (*) => UT_Save(boxes, win, smart, py))
    rec := win.Add("Button", "x+20 yp w160 h30", "Record mode (F8)")
    rec.OnEvent("Click", (*) => (win.Hide(), RM_Toggle()))
    win.Show("AutoSize")
}

UT_Save(boxes, win, smart, py) {
    txt := "; Unit type per hotbar slot: Ground, Hill or Hybrid (F6 in the macro opens the editor)`n"
    for i, dd in boxes
        txt .= "Slot" i "=" dd.Text "`n"
    txt .= "SmartPlacement=" (smart.Value ? "On" : "Off") "`n"
    txt .= "PythonVision=" (py.Value ? "On" : "Off") "`n"
    try FileDelete(UT_File())
    FileAppend(txt, UT_File(), "UTF-8")
    AddToLog("[Settings] Saved - smart placement " (smart.Value ? "on" : "off") ", Python vision " (py.Value ? "on" : "off"))
    if (py.Value)
        VH_Start()   ; starts the helper if it isn't running yet
    win.Hide()
}

