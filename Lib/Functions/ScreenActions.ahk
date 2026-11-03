#Requires AutoHotkey v2.0

; ============================================================================
;  ScreenActions.ahk  -  Reusable "find on screen, then act" helpers (click until gone, colour/path finders, wait-for-text).
;  [Modularized] functions moved here unchanged from Lib\Functions.ahk, Lib\GameMango.ahk.
;  Loaded from Main.ahk. Contains function definitions only (no start-up code).
; ============================================================================


/*ClickUntilGone(x, y, searchX1, searchY1, searchX2, searchY2, textToFind, offsetX:=0, offsetY:=0, textToFind2:="") {
    while (ok := FT(&X, &Y, searchX1, searchY1, searchX2, searchY2, 0, 0, textToFind) || textToFind2 && FT(&X, &Y, searchX1, searchY1, searchX2, searchY2, 0, 0, textToFind2)) {
        
        if (offsetX != 0 || offsetY != 0) {
            FixClick(X + offsetX, Y + offsetY)  
        } else {
            FixClick(x, y) 
        }
        Sleep(1000)
    }
}*/

ClickUntilGone(x, y, searchX1, searchY1, searchX2, searchY2, textToFind, offsetX:=0, offsetY:=0, textToFind2:="") {
    waitTime := A_TickCount ; Start timer
    while (ok := FT(&X, &Y, searchX1, searchY1, searchX2, searchY2, 0, 0, textToFind) || textToFind2 && FT(&X, &Y, searchX1, searchY1, searchX2, searchY2, 0, 0, textToFind2)) {
        if ((A_TickCount - waitTime) > 300000) { ; 5-minute limit
            AddToLog("5 minute failsafe triggered, trying to open roblox...")
            return NextStep(RejoinPrivateServer)
        }
        if (offsetX != 0 || offsetY != 0) {
            FixClick(X + offsetX, Y + offsetY)  
        } else {
            FixClick(x, y) 
        }
        Sleep(1000)
    }
}


RightClickUntilGone(x, y, searchX1, searchY1, searchX2, searchY2, textToFind, offsetX:=0, offsetY:=0, textToFind2:="") {
    while (ok := FT(&X, &Y, searchX1, searchY1, searchX2, searchY2, 0, 0, textToFind) || 
           textToFind2 && FT(&X, &Y, searchX1, searchY1, searchX2, searchY2, 0, 0, textToFind2)) {

        if (offsetX != 0 || offsetY != 0) {
            FixClick(X + offsetX, Y + offsetY, "Right")  
        } else {
            FixClick(x, y, "Right") 
        }
        Sleep(1000)
    }
}


FindAndClickBeam(targetColor := 0x006783, searchArea := [0, 0, GetWindowCenter(rblxID).Width, GetWindowCenter(rblxID).Height]) {
    ; Extract the search area boundaries
    x1 := searchArea[1], y1 := searchArea[2], x2 := searchArea[3], y2 := searchArea[4]
	
    ; Perform the pixel search
    if (PixelSearch(&foundX, &foundY, x1, y1, x2, y2, targetColor, 0)) {
        ; Color found, click on the detected coordinates
		AddToLog("Beam found at X" foundX " Y" foundY)
        AddToLog("Moving towards it...")
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
	MouseMove(400, 300)
	
	PosX:= foundX-400
	PosY:= foundY-300
	
	Sleep 50
	SendInput("{space down}")
	Sleep 50
	if(PosX > 0){
		SendInput("{d down}")
		Sleep PosX*6
		SendInput("{d up}")
	}
	else {
		SendInput("{a down}")
		Sleep -PosX*6
		SendInput("{a up}")
	}	
	Sleep 50
	if(PosY > 0){
		SendInput("{s down}")
		Sleep PosY*6
		SendInput("{s up}")
	}
	else {
		SendInput("{w down}")
		Sleep -PosY*6
		SendInput("{w up}")
	}
	Sleep 50
	SendInput("{space up}")
	Sleep 50
	
		Sleep 100
        return true
    }
}


FindAndMoveToPath(targetColors := [0x32FF3D, 0xFFFF00], searchArea := [0, 0, GetWindowCenter(rblxID).Width, GetWindowCenter(rblxID).Height]) {
    ; Extract search area boundaries
    x1 := searchArea[1], y1 := searchArea[2], x2 := searchArea[3], y2 := searchArea[4]

    ; Loop through each target color
    for _, color in targetColors {
        if (PixelSearch(&foundX, &foundY, x1, y1, x2, y2, color, 0)) {
            ; Color found, log details and move
            AddToLog("Path found at X" foundX " Y" foundY " (Color: " color ")")
            AddToLog("Moving towards it...")

            ; Stop movement before adjusting
            StopAllMovement()
            
            ; Recenter mouse
            MouseMove(400, 300)
            
            ; Calculate movement direction
            PosX := foundX - 400
            PosY := foundY - 300

            ; Move towards detected position
            MoveToPosition(PosX, PosY)

            return true
        }
    }
    return false  ; No color found
}


FindAndClickColor(targetColor := (ModeDropdown.Text = "Winter Event" ? 0x006783 : 0xFAFF4D), searchArea := [0, 0, GetWindowCenter(rblxID).Width, GetWindowCenter(rblxID).Height]) { ;targetColor := Winter Event Color : 0x006783 / Contracts Color : 0xFAFF4D
    ; Extract the search area boundaries
    x1 := searchArea[1], y1 := searchArea[2], x2 := searchArea[3], y2 := searchArea[4]

    ; Perform the pixel search
    if (PixelSearch(&foundX, &foundY, x1, y1, x2, y2, targetColor, 0)) {
        ; Color found, click on the detected coordinates
        FixClick(foundX, foundY, "Right")
        AddToLog("Color found and clicked at: X" foundX " Y" foundY)
        return true

    }
}


SearchFor(Name) {
    FindTexts := Map()
    FindTexts["Dungeon Continue"] := { coords: [380, 385, 615, 490], searchTexts: [DungeonContinue] }
    FindTexts["Dungeon Room Enter"] := { coords: [120, 425, 680, 500], searchTexts: [Enter] }

    ; Check if the FindText exists in the map
    if !FindTexts.Has(Name) {
        AddToLog("Error: Couldn't find " Name "...")
        return false  ; Invalid name
    }

    coords := FindTexts[Name].coords
    searchTexts := FindTexts[Name].searchTexts
    x1 := coords[1], y1 := coords[2], x2 := coords[3], y2 := coords[4]

    ; Loop through all search texts to perform the Find Text search
    for searchText in searchTexts {
        if (FT(&X, &Y, x1, y1, x2, y2, 0.20, 0.20, searchText)) {
            return true  ; FindText found
        }
    }

    return false  ; FindText not found
}


WaitFor(Name, timeout := 5000) {
    startTime := A_TickCount  ; Get current time

    ; **Wait for the FindText to appear**
    Loop {
        if (SearchFor(Name)) {
            if (debugMessages) {
                AddToLog("✅ " Name " detected, proceeding...")
            }
            return true  ; Interface found, exit loop
        }
        if ((A_TickCount - startTime) > timeout) {
            if (debugMessages) {
                AddToLog("⚠ " Name " was not found in time.")
            }
            return false  ; Exit if timeout reached
        }
        Sleep 100  ; Fast checks for better responsiveness
    }
}

