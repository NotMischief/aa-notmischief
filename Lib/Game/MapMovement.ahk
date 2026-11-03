#Requires AutoHotkey v2.0

; ============================================================================
;  MapMovement.ahk  -  Per-map movement after loading in (HandleMapMovement + MoveFor*).
;  [Modularized] functions moved here unchanged from Lib\Functions.ahk, Lib\GameMango.ahk.
;  Loaded from Main.ahk. Contains function definitions only (no start-up code).
; ============================================================================


HandleMapMovement(MapName) {
    AddToLog("Executing Movement for: " MapName)
    
    switch MapName {
        case "Planet Greenie":
            MoveForPlanetGreenie()
        case "Snowy Town":
            MoveForSnowyTown()
        case "Sand Village":
            MoveForSandVillage()
        case "Ant Kingdom":
            MoveForAntKingdom()
        case "Magic Town":
            MoveForMagicTown()
        case "Magic Hills":
            (IsHunt()) ? MoveForMagicHills() : MoveForMagicHill()
        case "Navy Bay":
            MoveForNavyBay()
        case "Alien Spaceship":
            MoveForAlienSpaceship()    
        case "Fiend City":
            MoveForFiendCity()
        case "Spirit World":
            MoveForSpiritWorld()
        case "Haunted Academy":
            MoveForHauntedAcademy()
        case "Space Center":
            MoveForSpaceCenter()
        case "Mountain Temple":
            MoveForMountainTemple()
        case "Cursed Festival":
            MoveForCursedFestival()
        case "Nightmare Train":
            MoveForNightmareTrain()
        case "Air Craft":
            MoveForAirCraft()
        case "Hellish City":
            MoveForHellish()
        case "Contracts":
            MoveForContracts()
        case "Winter Event":
            MoveForWinterEventNoClick()
        case "Shibuya District":
            MoveForShibuya()
        case "Sacred Planet":
            MoveForSacredPlanet()  
        case "Snowy Kingdom":
            MoveForSnowyKingdom()  
        case "Future City":
        MoveForFutureCity()
        case "Fabled Kingdom":
            MoveForFabledKingdom()  
        case "Puppet Island":
            MoveForPuppetIsland()
        case "Virtual Dungeon":
            MoveForVirtualDungeon()
        case "Dungeon Throne":
            MoveForDungeonThrone()
        case "Storm Hideout":
            MoveForStormHideout()
        case "Rain Village":
            MoveForRainVillage()
        case "Spirit Town":
            MoveForSpiritTown()
        case "Ruined City":
            MoveForRuinedCity()
        case "Strange Town":
            MoveForStrangeTown() 
        case "Future City (Tyrant)":
        MoveForFutureCity()   
    }
}


MoveForPlanetGreenie() {
    if !(IsHunt()) {
        SendInput ("{a down}")
        SendInput ("{w down}")
        Sleep (2200)
        SendInput ("{a up}")
        SendInput ("{w up}")
    }
}


MoveForAlienSpaceship() {
    if (ok := FT(&X, &Y, 0, 244, 48, 278, 0.15, 0.15, AlienSpaceshipAngle)) {
        if (IsHunt()) {
            SendInput ("{a down}")
            Sleep (700)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (500)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{a down}")
            Sleep (1300)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (1000)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
        } else {
            FixClick(73, 176, "Right")
            Sleep (2500)
        }
    } else {
        if (IsHunt()) {
            SendInput ("{w down}")
            Sleep (700)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (700)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (1500)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (1600)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
        } else {
            FixClick(658, 61, "Right")
            Sleep (2500)
        }
    }
}


MoveForSnowyTown() {
    if (IsHunt()) {
        SendInput ("{d down}")
        Sleep (3000)
        SendInput ("{d up}")
        KeyWait("d")
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (2400)
        SendInput ("{w up}")
        KeyWait("w")
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (4300)
        SendInput ("{d up}")
        KeyWait("d")
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (800)
        SendInput ("{s up}")
        KeyWait("s")
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (1000)
        SendInput ("{d up}")
        KeyWait("d")
        Sleep (1000)
    } else {
        SendInput ("{d down}")
        Sleep (3000)
        SendInput ("{d up}")
        KeyWait("d")
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (1000)
        SendInput ("{w up}")
        KeyWait("w")
        Sleep (1000)
    }
}


MoveForNavyBay() {
    if (IsHunt()) {
        SendInput ("{d down}")
        SendInput ("{w down}")
        Sleep (1000)
        SendInput ("{d up}")
        SendInput ("{w up}")
    } else {
        SendInput ("{a down}")
        SendInput ("{w down}")
        Sleep (1700)
        SendInput ("{a up}")
        SendInput ("{w up}")
    }
}


MoveForSandVillageOld() {
    Fixclick(777, 415, "Right")
    Sleep (3000)
    Fixclick(560, 555, "Right")
    Sleep (3000)
    Fixclick(125, 570, "Right")
    Sleep (3000)
    Fixclick(200, 540, "Right")
    Sleep (3000)
}


MoveForSandVillage() {
    SendInput ("{s down}")
    Sleep (700)
    SendInput ("{s up}")
    KeyWait("s")
    Sleep (1000)
    SendInput ("{d down}")
    Sleep (2700)
    SendInput ("{d up}")
    KeyWait("d")
    Sleep (1000)
    SendInput ("{s down}")
    Sleep (2400)
    SendInput ("{s up}")
    KeyWait("s")
    Sleep (1000)
    SendInput ("{a down}")
    Sleep (2400)
    SendInput ("{a up}")
    KeyWait("a")
    Sleep (1000)
    SendInput ("{s down}")
    Sleep (1800)
    SendInput ("{s up}")
    KeyWait("s")

}


MoveForFiendCity() {
    SendInput ("{s down}")
    Sleep (500)
    SendInput ("{s up}")
    Sleep (500)
    SendInput ("{a down}")
    Sleep (3800)
    SendInput ("{a up}")
    Sleep (500)
    SendInput ("{s down}")
    Sleep (2000)
    SendInput ("{s up}")
}


MoveForSpiritWorld() {
    SendInput ("{d down}")
    SendInput ("{w down}")
    Sleep(4000)
    SendInput ("{d up}")
    SendInput ("{w up}")
    KeyWait("d")
    KeyWait("w")
    Sleep(1000)
    SendInput ("{d down}")
    Sleep (1900)
    SendInput ("{d up}")
    KeyWait "d"
    Sleep (1000)
    SendInput ("{w down}")
    Sleep (2000)
    SendInput ("{w up}")
    KeyWait "w"
    Sleep (1000)
    if (IsHunt()) {
        SendInput ("{a down}")
        SendInput ("{w down}")
        Sleep(2500)
        SendInput ("{a up}")
        SendInput ("{w up}")
        KeyWait("a")
        KeyWait("w")
        Sleep(1000)
        SendInput ("{w down}")
        Sleep (500)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
    }
}


MoveForAntKingdom() {
    if (ok := FT(&X, &Y, 531, 205, 582, 251, 0.15, 0.15, AntKingdomAngle)) {
        SendInput ("{a down}") ; Move Towards Gate
        Sleep (1000)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (500)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (500)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (900)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
    
        SendInput ("{s down}") ; Move Out Of Gate
        Sleep (300)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (4000)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
    
        SendInput ("{w down}") ; Move Towards Enemy Spawn
        Sleep (1000)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (3000)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        if (IsHunt()) {
            SendInput ("{a down}")
            Sleep (1500)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
        }
    } else {
        SendInput ("{a down}")
        Sleep (500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (500)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (1400)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (800)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (3000)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (2800)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (1500)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (1500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (2000)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (1000)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (800)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
    }
}


MoveForMagicTown() {
    SendInput ("{d down}")
    Sleep (3000)
    SendInput ("{d up}")
    Sleep (1000)
    KeyWait("d")
    Sleep (1000)
    SendInput ("{s down}")
    Sleep (1200)
    SendInput ("{s up}")
    Sleep (1000)
    KeyWait("s")
    Sleep (1000)
    if (IsHunt()) {
        SendInput ("{d down}")
        Sleep (5800)
        SendInput ("{d up}")
        Sleep (1000)
        KeyWait("d")
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (700)
        SendInput ("{s up}")
        Sleep (1000)
        KeyWait("s")
        /*SendInput ("{d down}") ;Garden
        Sleep (4700)
        SendInput ("{d up}")
        Sleep (1000)
        KeyWait("d")*/
    } else {
        SendInput ("{d down}")
        Sleep (3200)
        SendInput ("{d up}")
        Sleep (1000)
        KeyWait("d")
    }
}



MoveForMagicHill() {
    if (ok := FT(&X, &Y, 518, 334, 566, 404, 0.20, 0.20, MagicHillsBench) or (ok := FT(&X, &Y, 522, 339, 557, 402, 0.20, 0.20, MagicHillLegendStageBench))) {
        SendInput ("{d down}")
        Sleep (500)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (2600)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (500)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (4000)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (1000)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (4000)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (2500)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (2800)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (1500)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
    } else {
        SendInput ("{w down}")
        Sleep (500)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (7000)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (1400)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (3500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (2800)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (3500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (1100)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
    }
}


MoveForMagicHills() {
    if (ok := FT(&X, &Y, 518, 334, 566, 404, 0.20, 0.20, MagicHillsBench) or (ok := FT(&X, &Y, 522, 339, 557, 402, 0.20, 0.20, MagicHillLegendStageBench))) {
        SendInput ("{d down}")
        Sleep (500)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (2600)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (500)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (4000)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (1000)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (4000)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (2500)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (2800)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (1900)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (2700)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (1300)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (1500)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (1000)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (700)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (800)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
    } else {
        SendInput ("{w down}")
        Sleep (500)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (7000)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (1400)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (3500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (2800)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (3500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (1500)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (2700)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (1800)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (1600)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (1800)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
    }
}


MoveForHauntedAcademy() {
    SendInput ("{d down}")
    sleep 4700
    SendInput ("{d up}")
    KeyWait "d"
    /*if (ok := FT(&X, &Y, 173, 401, 224, 437, 0.15, 0.15, HauntedAcademyAngle)) {
        if (ModeDropdown.Text = "Story") {
            AddToLog("Angle 1")
            SendInput ("{d up}")
            Sleep 100
            SendInput ("{d down}")
            Sleep 3500
            SendInput ("{d up}")
            KeyWait "d"
        } else {
            SendInput ("{w up}")
            Sleep 100
            SendInput ("{w down}")
            Sleep 6500
            SendInput ("{w up}")
            KeyWait "w"
        }
    }
    if (ok := FT(&X, &Y, 720, 124, 766, 170, 0.15, 0.15, HauntedAcademyAngle2)) {    
        if (ModeDropdown.Text = "Story") {
            SendInput ("{s up}")
            Sleep 100
            SendInput ("{s down}")
            Sleep 3500
            SendInput ("{s up}")
            KeyWait "s"
        } else {
            SendInput ("{d up}")
            Sleep 100
            SendInput ("{d down}")
            Sleep 6500
            SendInput ("{d up}")
            KeyWait "s"
        }
    }*/
}


MoveForSpaceCenter() {
    if (IsHunt()) {
         /* if (ok := FT(&X, &Y, 248, 402, 283, 438, 0.20, 0.20, SpaceCenterAngle)) {
            SendInput ("{a down}")
            Sleep (2000)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (600)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{a down}")
            Sleep (900)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{s down}")
            Sleep (2800)
            SendInput ("{s up}")
            KeyWait "s"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (500)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
            */ 
        ;} else {
            SendInput ("{d down}")
            Sleep (2000)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
            SendInput ("{s down}")
            Sleep (600)
            SendInput ("{s up}")
            KeyWait "s"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (900)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (2800)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{a down}")
            Sleep (500)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
        }
     else {
         /*if (ok := FT(&X, &Y, 248, 402, 283, 438, 0.20, 0.20, SpaceCenterAngle)) {
            SendInput ("{a down}")
            Sleep (2000)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (600)
            SendInput ("{w up}")
            KeyWait "w"
        } else {*/ 
            SendInput ("{d down}")
            Sleep (2000)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (1500)
            SendInput ("{w up}")
            KeyWait "s"
        }
    }

;}

MoveForMountainTemple() {
    if (IsHunt()) {
        if (ok := FT(&X, &Y, 667, 185, 765, 244, 0.15, 0.15, MountainTempleAngle)) {
            SendInput ("{w down}")
            Sleep (2000)
            SendInput ("{w up}")
            KeyWait "w"
        } else {
            SendInput ("{s down}")
            Sleep (2000)
            SendInput ("{s up}")
            KeyWait "s"
        }
    } else {
        SendInput ("{w down}")
        SendInput ("{d down}")
        Sleep(2000)
        SendInput ("{w up}")
        SendInput ("{d up}")
        KeyWait("w")
        KeyWait("d")
        Sleep(1000)
       /* if (ok := FT(&X, &Y, 667, 185, 765, 244, 0.15, 0.15, MountainTempleAngle)) {
            SendInput ("{w down}")
            SendInput ("{d down}")
            Sleep(2000)
            SendInput ("{w up}")
            SendInput ("{d up}")
            KeyWait("w")
            KeyWait("d")
            Sleep(1000)
        } else {
            SendInput ("{a down}")
            SendInput ("{s down}")
            Sleep(2000)
            SendInput ("{a up}")
            SendInput ("{s up}")
            KeyWait("a")
            KeyWait("s")
            Sleep(1000)
        } */
    }
}


MoveForFabledKingdom() {
    if (IsHunt()) {
        if (ok := FT(&X, &Y, 506, 248, 564, 308, 0.15, 0.15, FabledKingdomAngle)) {
            SendInput ("{s down}")
            Sleep (6000)
            SendInput ("{s up}")
            KeyWait "s"
            Sleep (1000)
            SendInput ("{a down}")
            Sleep (400)
            SendInput ("{a up}")
            KeyWait "a"
        } else {
            SendInput ("{w down}")
            Sleep (6000)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (400)
            SendInput ("{d up}")
            KeyWait "d"
        }
    }
}


MoveForFutureCity() {
    if (IsHunt()) {
        if (ok := FT(&X, &Y, 699, 526, 797, 574, 0.15, 0.15, FutureCityAngle)) {
            SendInput ("{s down}")
            Sleep (7300)
            SendInput ("{s up}")
            KeyWait "a"
            Sleep (1000)
        } else {
            SendInput ("{w down}")
            Sleep (7300)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
        }
    }
}


MoveForSnowyKingdom() {
    /*
    if (IsHunt()) {
        if (ok := FT(&X, &Y, 126, 420, 200, 452, 0.15, 0.15, SnowyKingdomAngle)) {
            SendInput ("{d down}")
            Sleep (300)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (3000)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (2800)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (2500)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (500)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
        } else {
            SendInput ("{a down}")
            Sleep (300)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{s down}")
            Sleep (3000)
            SendInput ("{s up}")
            KeyWait "s"
            Sleep (1000)
            SendInput ("{a down}")
            Sleep (2800)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{s down}")
            Sleep (2000)
            SendInput ("{s up}")
            KeyWait "s"
            Sleep (1000)
        }
    }
    */
}


MoveForPuppetIsland() {
    if (IsHunt()) {
        if (ok := FT(&X, &Y, 519, 484, 594, 559, 0.15, 0.15, PuppetIslandAngle)) {
            SendInput ("{w down}")
            Sleep (2800)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{a down}")
            Sleep (2000)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
        } else {
            SendInput ("{s down}")
            Sleep (2800)
            SendInput ("{s up}")
            KeyWait "s"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (2000)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
        }
    }
}


MoveForVirtualDungeon() {
    if (IsHunt()) {
        if (ok := FT(&X, &Y, 592, 505, 663, 571, 0.15, 0.15, VirtualDungeonAngle)) {
            SendInput ("{w down}")
            Sleep (1800)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
        } else if (ok := FT(&X, &Y, 160, 515, 228, 591, 0.15, 0.15, VirtualDungeonAngle2)) {
            SendInput ("{d down}")
            Sleep (1800)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
        } else {
            SendInput ("{a down}")
            Sleep (1800)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
        }
    }
}


MoveForStormHideout() {
    if (IsHunt()) {
        SendInput ("{a down}")
        Sleep (200)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (5000)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (1500)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{w down}")
        Sleep (200)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
    }
}


MoveForSpiritTown() {
    if (IsHunt()) { ; Old Spirit Town Angle 224, 354, 300, 419
        if (ok := FT(&X, &Y, 648, 284, 740, 336, 0.15, 0.15, SpiritTownAngle2)) {
            SendInput ("{w down}")
            Sleep (3000)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (3700)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (500)
            SendInput ("{w up}")
            KeyWait "w"
        } else {
            SendInput ("{s down}")
            Sleep (3000)
            SendInput ("{s up}")
            KeyWait "s"
            Sleep (1000)
            SendInput ("{a down}")
            Sleep (3700)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{s down}")
            Sleep (500)
            SendInput ("{s up}")
            KeyWait "s"
            Sleep (1000)
        }
    }
}


MoveForRuinedCity() {
    if (IsHunt()) { 
        if (ok := FT(&X, &Y, 37, 515, 129, 588, 0.15, 0.15, RuinedCityAngle)) {
            SendInput ("{d down}")
            Sleep (500)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (800)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (4000)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
        } else {
            SendInput ("{a down}")
            Sleep (500)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{s down}")
            Sleep (800)
            SendInput ("{s up}")
            KeyWait "s"
            Sleep (1000)
            SendInput ("{a down}")
            Sleep (4000)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
        }
    }
}


MoveForRainVillage() {
   /* if (ok := FT(&X, &Y, 16, 369, 155, 470, 0.15, 0.15, RainVillageAngle)) {
        SendInput ("{w down}")
        Sleep (2000)
        SendInput ("{w up}")
        KeyWait "w"
        Sleep (1000)
        SendInput ("{a down}")
        Sleep (500)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
    } else {
        SendInput ("{a down}")
        Sleep (2000)
        SendInput ("{a up}")
        KeyWait "a"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (500)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
    }
*/
}


MoveForDungeonThrone() {
    if (IsHunt()) {
        if (ok := FT(&X, &Y, 15, 335, 80, 461, 0.15, 0.15, DungeonThroneAngle)) {
            SendInput ("{s down}")
            Sleep (4500)
            SendInput ("{s up}")
            KeyWait "s"
            Sleep (1000)
        } else {
            SendInput ("{w down}")
            Sleep (4500)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
        }
    }
}


MoveForStrangeTown() {
    if (IsHunt() or ModeDropdown.Text = "Raid") {
        if (ok := FT(&X, &Y, 34, 483, 82, 512, 0.15, 0.15, StrangeTownAngle)) {
            /*SendInput ("{a down}") ; Move To Center Garden
            Sleep (1600)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (600)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)*/
            SendInput ("{a down}")
            Sleep (2500)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
        } else {
            SendInput ("{d down}")
            Sleep (2500)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
        }
    }
}


MoveForCursedFestival() {
    if (IsHunt()) {
        if (ok := FT(&X, &Y, 47, 213, 107, 257, 0.15, 0.15, CursedFestivalAngle)) {
            SendInput ("{d down}")
            Sleep (1800)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
            SendInput ("{s down}")
            Sleep (800)
            SendInput ("{s up}")
            KeyWait "s"
            Sleep (1000)
        } else {
            SendInput ("{a down}")
            Sleep (1800)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (800)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
        }
    } else {
         if (ok := FT(&X, &Y, 560, 285, 615, 350, 0.15, 0.15, FestivalAngle)) {
            SendInput ("{d down}")
            Sleep (1800)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
        } else {
            SendInput ("{a down}")
            Sleep (1800)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
        }
    }
}


MoveForNightmareTrain() {
    SendInput ("{a down}")
    sleep (1800)
    SendInput ("{a up}")
}


MoveForAirCraftOld() {
    SendInput ("{s down}")
    sleep (800)
    SendInput ("{s up}")
}


MoveForAirCraft() {
    if (ok := FT(&X, &Y, 535, 110, 620, 175, 0.15, 0.15, AirCraftAngle)) {
        SendInput ("{s down}")
        Sleep (800)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
        SendInput ("{d down}")
        Sleep (1000)
        SendInput ("{d up}")
        KeyWait "d"
        Sleep (1000)
        SendInput ("{s down}")
        Sleep (800)
        SendInput ("{s up}")
        KeyWait "s"
        Sleep (1000)
    } else {
        if (IsHunt()) {
            SendInput ("{w down}")
            Sleep (800)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{a down}")
            Sleep (1000)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (800)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
        } else {
            SendInput ("{w down}")
            Sleep (1000)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (1000)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (400)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (1000)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
        }
    }
}


MoveForHellishOlder() {
    Fixclick(600, 300, "Right")
    Sleep (7000)
}


MoveForHellish() {
    if (IsHunt()) {
        if (ok := FT(&X, &Y, 618, 519, 675, 573, 0.15, 0.15, HellishAngle)) {
            SendInput ("{a down}")
            Sleep (1250)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (2300)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{a down}")
            Sleep (1000)
            SendInput ("{a up}")
            KeyWait "a"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (2000)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (500)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
            SendInput ("{w down}")
            Sleep (1000)
            SendInput ("{w up}")
            KeyWait "w"
            Sleep (1000)
            SendInput ("{d down}")
            Sleep (500)
            SendInput ("{d up}")
            KeyWait "d"
            Sleep (1000)
        } else {
            SendInput("{d down}")
            Sleep(1250)
            SendInput("{d up}")
            KeyWait("d")
            Sleep(1000)
        
            SendInput("{s down}")
            Sleep(2300)
            SendInput("{s up}")
            KeyWait("s")
            Sleep(1000)
        
            SendInput("{d down}")
            Sleep(1000)
            SendInput("{d up}")
            KeyWait("d")
            Sleep(1000)
        
            SendInput("{s down}")
            Sleep(2000)
            SendInput("{s up}")
            KeyWait("s")
            Sleep(1000)
        
            SendInput("{a down}")
            Sleep(500)
            SendInput("{a up}")
            KeyWait("a")
            Sleep(1000)
        
            SendInput("{s down}")
            Sleep(1000)
            SendInput("{s up}")
            KeyWait("s")
            Sleep(1000)
        
            SendInput("{a down}")
            Sleep(500)
            SendInput("{a up}")
            KeyWait("a")
            Sleep(1000)
        }
    } else {
        if (ok := FT(&X, &Y, 370, 210, 465, 265, 0.15, 0.15, HellishAngle)) {
            SendInput ("{d down}")
            Sleep (1200)
            SendInput ("{d up}")
            KeyWait "d"
        } else {
            SendInput ("{a down}")
            Sleep (800)
            SendInput ("{a up}")
            KeyWait "a"
            sleep 500
            SendInput ("{w down}")
            Sleep (800)
            SendInput ("{w up}")
            keywait "w"
            sleep 500
            SendInput ("{d down}")
            Sleep (2400)
            SendInput ("{d up}")
            keywait "d"
            sleep 500
            SendInput ("{s down}")
            Sleep (600)
            SendInput ("{s up}")
            keywait "s"
        }
    }
}


MoveForContracts() {
    FixClick(590, 15) ; click on paths
    loop {
        if FindAndClickColor() {
            FixClick(590, 15) ; click on paths
            break
        }
        else {
            AddToLog("Color not found. Turning again.")
            SendInput ("{Left up}")
            Sleep 200
            SendInput ("{Left down}")
            Sleep 750
            SendInput ("{Left up}")
            KeyWait "Left" ; Wait for key to be fully processed
            Sleep 200
        }
    }
}


MoveForShibuya() {
    /*
    if (ok := FT(&X, &Y, 220, 190, 320, 250, 0.15, 0.15, ShibuyaAngle)) {
        SendInput ("{a down}")
        Sleep (600)
        SendInput ("{a up}")
        Sleep (500)
        SendInput ("{a down}")
        SendInput ("{w down}")
        Sleep (1500)
        SendInput ("{a up}")
        SendInput ("{w up}")
    } else {
        SendInput ("{d down}")
        Sleep(2000)
        SendInput ("{d up}")
    }
    */
   SendInput ("{a down}")
    Sleep (600)
    SendInput ("{a up}")
    Sleep (500)
    SendInput ("{a down}")
    SendInput ("{w down}")
    Sleep (1500)
    SendInput ("{a up}")
    SendInput ("{w up}")
}


MoveForSacredPlanet() {
    if (IsHunt() or ModeDropdown.Text = "Raid") {
        SendInput ("{w down}")
        Sleep (2400)
        SendInput ("{w up}")
        Sleep (1500)
        SendInput ("{a down}")
        Sleep (1000)
        SendInput ("{a up}")
        Sleep (1500)
        SendInput ("{w down}")
        Sleep (300)
        SendInput ("{w up}")
    }
}


FindAndClickSpaceCenterPath(targetColor := 0xD8FF00, searchArea := [0, 0, GetWindowCenter(rblxID).Width, GetWindowCenter(rblxID).Height]) { ;targetColor := Winter Event Color : 0x006783 / Contracts Color : 0xFAFF4D
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


FindAndClickHauntedPath(targetColor := (mode = "Story" ? 0x191622 : 0x1D1414), searchArea := (mode = "Story" ? [708, 332, 833, 365] : [558, 335, 694, 369])) {
    
    ; Extract the search area boundaries
    x1 := searchArea[1], y1 := searchArea[2], x2 := searchArea[3], y2 := searchArea[4]

    ; Perform the pixel search
    if (PixelSearch(&foundX, &foundY, x1, y1, x2, y2, targetColor, 0)) {
        ; Color found, click on the detected coordinates
        AddToLog("Color found at: X" foundX " Y" foundY)
        return true

    }
}

