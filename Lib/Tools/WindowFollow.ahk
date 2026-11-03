#Requires AutoHotkey v2.0

; ============================================================================
;  WindowFollow.ahk  -  FindText that follows Roblox
; ----------------------------------------------------------------------------
;  All FindText search areas in this macro were captured with the GUI in the
;  top-left corner of the screen and Roblox at (offsetX, offsetY) = (-5, 1).
;  FindText always works in screen coordinates, so it only worked there.
;
;  FT() is used instead of FindText(&X, &Y, ...). It shifts the search area by
;  how far the Roblox window has moved from that original spot, then shifts the
;  found X/Y back. So every existing coordinate in the macro stays the same and
;  works wherever the window is.
;
;  Clicks, PixelGetColor, PixelSearch and ImageSearch use CoordMode "Client"
;  (relative to the active window) and already followed Roblox - unchanged.
;  The Roblox window must stay the same size (sizeDown() still enforces that).
; ============================================================================

; How far the Roblox window is from where the search areas were captured.
FT_GetOffset(&dx, &dy) {
    global rblxID, offsetX, offsetY
    dx := 0, dy := 0
    try {
        if WinExist(rblxID) {
            WinGetPos(&wx, &wy,,, rblxID)
            dx := wx - offsetX   ; original spot: GUI at (0, 0) + offsetX
            dy := wy - offsetY   ; original spot: GUI at (0, 0) + offsetY
        }
    }
}

; Drop-in replacement for FindText(&X, &Y, x1, y1, x2, y2, ...)
FT(&X := "", &Y := "", x1 := 0, y1 := 0, x2 := 0, y2 := 0, args*) {
    FT_GetOffset(&dx, &dy)
    if (x1 = 0 && y1 = 0 && x2 = 0 && y2 = 0)   ; 0,0,0,0 means "whole screen" - leave it
        dx := 0, dy := 0
    ok := FindText(&X, &Y, x1 + dx, y1 + dy, x2 + dx, y2 + dy, args*)
    if (ok && IsNumber(X) && IsNumber(Y))
        X -= dx, Y -= dy
    return ok
}

; Replacement for FindText().Click(X, Y, ...) when X/Y came from FT()
FTClick(x, y, args*) {
    FT_GetOffset(&dx, &dy)
    return FindText().Click(x + dx, y + dy, args*)
}

; Put the GUI in the middle of the main screen, then Roblox follows it
CenterMacroWindow() {
    global aaMainUIHwnd
    MonitorGetWorkArea(MonitorGetPrimary(), &left, &top, &right, &bottom)
    WinGetPos(,, &w, &h, "ahk_id " aaMainUIHwnd)
    x := Max(left, left + (right - left - w) // 2)
    y := Max(top, top + (bottom - top - h) // 2)
    WinMove(x, y,,, "ahk_id " aaMainUIHwnd)
}

; Drag the GUI by clicking anywhere on its background
SetupDraggableGui() {
    OnMessage(0x0201, MacroGui_OnLButtonDown)   ; WM_LBUTTONDOWN
    OnMessage(0x0232, MacroGui_OnMoveEnd)       ; WM_EXITSIZEMOVE (finished dragging)
}

MacroGui_OnLButtonDown(wParam, lParam, msg, hwnd) {
    global aaMainUIHwnd
    if (hwnd = aaMainUIHwnd)
        PostMessage(0xA1, 2,,, "ahk_id " aaMainUIHwnd)   ; start a normal window drag
}

MacroGui_OnMoveEnd(wParam, lParam, msg, hwnd) {
    global aaMainUIHwnd
    if (hwnd = aaMainUIHwnd)
        moveRobloxWindow()   ; Roblox snaps back next to the GUI
}
