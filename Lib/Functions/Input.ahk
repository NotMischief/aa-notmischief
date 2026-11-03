#Requires AutoHotkey v2.0

; ============================================================================
;  Input.ahk  -  Mouse/keyboard input helpers shared by all modules.
;  [Modularized] functions moved here unchanged from Lib\Functions.ahk, Lib\GameMango.ahk.
;  Loaded from Main.ahk. Contains function definitions only (no start-up code).
; ============================================================================


StopAllMovement() {
    Sleep 50
    SendInput("{space up}")
    Sleep 50
    SendInput("{w up}")
    Sleep 50
    SendInput("{a up}")
    Sleep 50
    SendInput("{s up}")
    Sleep 50
    SendInput("{d up}")
    Sleep 50
}


MoveToPosition(PosX, PosY) {
    Sleep 50
    SendInput("{space down}")
    Sleep 50
    if (PosX > 0) {
        SendInput("{d down}")
        Sleep PosX * 6
        SendInput("{d up}")
    } else {
        SendInput("{a down}")
        Sleep -PosX * 6
        SendInput("{a up}")
    }    
    Sleep 50
    if (PosY > 0) {
        SendInput("{s down}")
        Sleep PosY * 6
        SendInput("{s up}")
    } else {
        SendInput("{w down}")
        Sleep -PosY * 6
        SendInput("{w up}")
    }
    Sleep 50
    SendInput("{space up}")
    Sleep 50
}



FixClick(x, y, LR := "Left") {
    MouseMove(x, y)
    MouseMove(1, 0, , "R")
    MouseClick(LR, -1, 0, , , , "R")
    Sleep(50)
}


FreezeClient(x, y, sleepTime := 1000, LR := "Left") {
    MouseMove(x, y)
    MouseMove(1, 0, , "R")
    SendEvent("{LButton down}")  ; Hold down left click
    Sleep (500)
    MouseMove(400, 300)
    MouseMove(1, 0, , "R")
    Sleep(sleepTime)
    SendEvent("{LButton up}")    ; Release
    Sleep(50)
}


FreezeClientNew(x, y, holdTime := 110000) {
    if WinExist(rblxID) {
        WinActivate(rblxID)
        Sleep(100)
    }
    CoordMode("Mouse", "Window")
    try {
        MouseMove(x, y)                     ; Move to Roblox title bar / minimize area
        Sleep(50)
        SendEvent("{RButton down}")         ; Hold right click
        Sleep(holdTime)                     ; Hold for ~2 minutes (110,000 ms)
    } finally {
        SendEvent("{RButton up}")           ; Always release right click
        Sleep(50)
        CoordMode("Mouse", "Client")
    }
}