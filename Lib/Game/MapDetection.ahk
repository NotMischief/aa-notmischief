#Requires AutoHotkey v2.0

; ============================================================================
;  MapDetection.ahk  -  Detecting which map was loaded (loading-screen ImageSearch / FindText).
;  [Modularized] functions moved here unchanged from Lib\GameMango.ahk.
;  Loaded from Main.ahk. Contains function definitions only (no start-up code).
; ============================================================================


DetectMap() {
    AddToLog("Trying to determine map...")
    startTime := A_TickCount
    
    Loop {
        ; Check if we waited more than 5 minute for votestart
        if (A_TickCount - startTime > 300000) {
            if (ok := FT(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {
                AddToLog("Found in lobby - restarting selected mode")
                return NextStep(StartSelectedMode)
            }
            AddToLog("Could not detect map after 5 minutes - proceeding without movement")
            return "no map found"
        }

        ; Check for vote screen
        if (ok := FT(&X, &Y, 326, 60, 547, 173, 0, 0, VoteStart) or (ok := FT(&X, &Y, 340, 537, 468, 557, 0, 0, Yen)))  {
            AddToLog("No Map Found or Movement Unnecessary")
            UpdateMap("No Map Found") ; For Webhook
            return "no map found"
        }

        mapPatterns := Map(
            "Sacred Planet", SacredPlanet,
            "Planet Greenie", PlanetGreenie,
            "Walled City", WalledCity,
            "Snowy Town", SnowyTown,
            "Sand Village", Sand,
            "Navy Bay", Navy,
            "Fiend City", Fiend,
            "Spirit World", Spirit,
            "Ant Kingdom", Ant,
            "Magic Town", MagicTown, 
            "Magic Hills", MagicHills,
            "Haunted Academy", Academy,
            "Alien Spaceship", AlienSpaceship,
            "Space Center", SpaceCenter,

            "Fabled Kingdom", Fabled,
            "Ruined City", Ruined,
            "Puppet Island", Puppet,
            "Virtual Dungeon", Virtual,
            "Snowy Kingdom", SnowyKingdom,
            "Dungeon Throne", DungeonThrone,
            "Rain Village", RainVillage,
            "Spirit Town", SpiritTown,

            "Mountain Temple", Mount,
            "Cursed Festival", Cursed,
            "Nightmare Train", Nightmare,
            "Air Craft", AirCraft,
            "Hellish City", Hellish,
            "Contracts", ContractLoadingScreen,
            "Winter Event", Winter,
            "Shibuya District", Shibuya,

            "Storm Hideout", Storm,
        )

        for mapName, pattern in mapPatterns {
            if (ModeDropdown.Text = "Winter Event" or ModeDropdown.Text = "Contracts") {
                if (ok := FT(&X, &Y, 10, 70, 350, 205, 0, 0, pattern)) {
                    AddToLog("Detected map: " mapName)
                    UpdateMap(mapName) ; For Webhook
                    return mapName
                }
            } else {
                if (ok := FT(&X, &Y, 10, 90, 415, 160, 0, 0, pattern)) {
                    AddToLog("Detected map: " mapName)
                    UpdateMap(mapName) ; For Webhook
                    return mapName
                }
            }
        }
        
        Sleep 1000
        Reconnect()
    }
}


DetectHuntMap(maxMs := 300000) {
    AddToLog("Trying to determine map for " ModeDropdown.Text "...")
    startTime := A_TickCount
    lastBanner := 0, lastPics := 0
    
    Loop {
        ; [Banner] Summer: the arrival banner names the map for a few seconds right after loading - this wait
        ; used to run past it (20 s of loading-screen pictures), so the later banner read found nothing.
        if (SH_On() && A_TickCount - lastBanner > 900) {
            bm := ""
            try bm := SH_BannerOnce(Mod(A_TickCount // 900, 2) ? 1 : 1.5)
            lastBanner := A_TickCount
            if (bm != "") {
                AddToLog("Map from the banner: " bm)
                UpdateMap(bm)
                return bm
            }
        }
        ; [Fix] give up quickly when asked (the freeze must not wait for map recognition)
        if (maxMs < 300000 && A_TickCount - startTime > maxMs) {
            AddToLog("Loading screen not recognised within " (maxMs // 1000) "s - continuing without the map")
            return "no map found"
        }
        ; Check if we waited more than 5 minute for votestart
        if (A_TickCount - startTime > 300000) {
            if (ok := FT(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {
                AddToLog("Found in lobby - restarting selected mode")
                return NextStep(StartSelectedMode)
            }
            AddToLog("Could not detect map after 5 minutes - proceeding without movement")
            return "no map found"
        }

        ; Check for vote screen
        if (ok := FT(&X, &Y, 326, 60, 547, 173, 0, 0, VoteStart) or (ok := FT(&X, &Y, 340, 537, 468, 557, 0, 0, Yen)))  {
            AddToLog("No Map Found or Movement Unnecessary")
            UpdateMap("No Map Found") ; For Webhook
            return "no map found"
        }

        ; [Lag] the old loading-screen pictures (40 full-screen searches) rarely match since the update -
        ; in Summer only look for them about twice a second
        if (SH_On() && A_TickCount - lastPics < 500) {
            Sleep(100)
            continue
        }
        lastPics := A_TickCount

        loadingScreens := Map(
            ; Story Maps
            "Planet Greenie", [PlanetGreenieLoadingScreen],
            "Walled City", [WalledCityLoadingScreen],
            "Snowy Town", [SnowyTownLoadingScreen],  ; Example of multiple images
            "Sand Village", [SandVillageLoadingScreen],
            "Navy Bay", [NavyBayLoadingScreen],
            "Fiend City", [FiendCityLoadingScreen],
            "Spirit World", [SpiritWorldLoadingScreen],
            "Ant Kingdom", [AntKingdomLoadingScreen, AntKingdomLoadingScreen2, AntKingdomLoadingScreen3, AntKingdomRaidLoadingScreen],
            "Magic Town", [MagicTownLoadingScreen], 
            "Magic Hills", [MagicHillsLoadingScreen],
            "Haunted Academy", [HauntedAcademyLoadingScreen, CursedWombLoadingScreen],
            "Alien Spaceship", [AlienSpaceshipLoadingScreen],
            "Space Center", [SpaceCenterLoadingScreen, SpaceCenterLoadingScreen3],
            "Fabled Kingdom", [FabledKingdomLoadingScreen, FabledKingdomLoadingScreen2, FabledKingdomLoadingScreen3, FabledKingdomLoadingScreen4],
            "Ruined City", [RuinedCityLoadingScreen],
            "Puppet Island", [PuppetIslandLoadingScreen],
            "Virtual Dungeon", [VirtualDungeonLoadingScreen],
            "Snowy Kingdom", [SnowyKingdomLoadingScreen],
            "Dungeon Throne", [DungeonThroneLoadingScreen],
            "Mountain Temple", [MountainTempleLoadingScreen],
            "Rain Village", [RainVillageLoadingScreen],
            "Shibuya District", [ShibuyaDistrictLoadingScreen],
        
            ; Legend Stages
            "Spirit Town", [SpiritTownLoadingScreen],
        
            ; Raids
            "Sacred Planet", [SacredPlanetLoadingScreen],
            "Strange Town", [StrangeTownLoadingScreen],
            "Cursed Festival", [CursedFestivalLoadingScreen],
            "Storm Hideout", [StormHideoutLoadingScreen],
            "Nightmare Train", [NightmareTrainLoadingScreen],
            "Future City", [FutureCityLoadingScreen],
        
            ; Event Maps
            "Assassin Park", [AssassinParkLoadingScreen],
            "Haunted Mansion", [HauntedMansionLoadingScreen],
        
            ; Unfinished Maps
            "Air Craft", [AirCraftLoadingScreen],
            "Hellish City", [HellishCityLoadingScreen]
        )

        for mapName, patterns in loadingScreens {
            try {
                for pattern in patterns {  ; Iterate through multiple images for each map
                    if (ok := ImageSearch(&X, &Y, 0, 0, A_ScreenWidth, A_ScreenHeight, "*15 " pattern)) {
                        AddToLog("Detected Map: " mapName)
                        UpdateMap(mapName) ; For Webhook
                        return mapName
                    }
                }
            } catch {
                if (debugMessages) {
                    AddToLog("Error occurred during map detection.")
                }
            }
        }
        
        Sleep(maxMs < 300000 ? 150 : 1000)   ; [Fix] check fast when the freeze is waiting
        Reconnect()
    }
}


DetectMapImageSearch() { ;Imagesearch version
    AddToLog("Trying to determine map using Image Search")
    startTime := A_TickCount
    
    Loop {
        ; Check if we waited more than 5 minute for votestart
        if (A_TickCount - startTime > 300000) {
            if (ok := FT(&X, &Y, 746, 514, 789, 530, 0, 0, AreaText)) {
                AddToLog("Found in lobby - restarting selected mode")
                return NextStep(StartSelectedMode)
            }
            AddToLog("Could not detect map after 5 minutes - proceeding without movement")
            return "no map found"
        }

        ; Check for vote screen
        if (ok := FT(&X, &Y, 326, 60, 547, 173, 0, 0, VoteStart) or (ok := FT(&X, &Y, 340, 537, 468, 557, 0, 0, Yen)))  {
            AddToLog("No Map Found or Movement Unnecessary")
            UpdateMap("No Map Found") ; For Webhook
            return "no map found"
        }

        loadingScreens := Map(
            ; Story Maps
            "Planet Greenie", [PlanetGreenieLoadingScreen],
            "Walled City", [WalledCityLoadingScreen],
            "Snowy Town", [SnowyTownLoadingScreen],  ; Example of multiple images
            "Sand Village", [SandVillageLoadingScreen],
            "Navy Bay", [NavyBayLoadingScreen],
            "Fiend City", [FiendCityLoadingScreen],
            "Spirit World", [SpiritWorldLoadingScreen],
            "Ant Kingdom", [AntKingdomLoadingScreen, AntKingdomLoadingScreen2, AntKingdomLoadingScreen3],
            "Magic Town", [MagicTownLoadingScreen], 
            "Magic Hills", [MagicHillsLoadingScreen, MagicHillsLegendLoadingScreen, MagicHillsLegendLoadingScreenAct3, AntKingdomRaidLoadingScreen],
            "Haunted Academy", [HauntedAcademyLoadingScreen],
            "Alien Spaceship", [AlienSpaceshipLoadingScreen],
            "Space Center", [SpaceCenterLoadingScreen, SpaceCenterLoadingScreen3],
            "Fabled Kingdom", [FabledKingdomLoadingScreen, FabledKingdomLoadingScreen2, FabledKingdomLoadingScreen3, FabledKingdomLoadingScreen4],
            "Ruined City", [RuinedCityLoadingScreen],
            "Puppet Island", [PuppetIslandLoadingScreen],
            "Virtual Dungeon", [VirtualDungeonLoadingScreen],
            "Snowy Kingdom", [SnowyKingdomLoadingScreen],
            "Dungeon Throne", [DungeonThroneLoadingScreen],
            "Mountain Temple", [MountainTempleLoadingScreen],
            "Rain Village", [RainVillageLoadingScreen],
            "Shibuya District", [ShibuyaDistrictLoadingScreen],
        
            ; Legend Stages
            "Spirit Town", [SpiritTownLoadingScreen],
        
            ; Raids
            "Sacred Planet", [SacredPlanetLoadingScreen],
            "Strange Town", [StrangeTownLoadingScreen],
            "Cursed Festival", [CursedFestivalLoadingScreen],
            "Storm Hideout", [StormHideoutLoadingScreen],
            "Nightmare Train", [NightmareTrainLoadingScreen],
            "Future City", [FutureCityLoadingScreen],
        
            ; Event Maps
            "Assassin Park", [AssassinParkLoadingScreen],
            "Haunted Mansion", [HauntedMansionLoadingScreen],
        
            ; Unfinished Maps
            "Air Craft", [AirCraftLoadingScreen],
            "Hellish City", [HellishCityLoadingScreen]
        )

        for mapName, patterns in loadingScreens {
            try {
                for pattern in patterns {  ; Iterate through multiple images for each map
                    if (ok := ImageSearch(&X, &Y, 0, 0, A_ScreenWidth, A_ScreenHeight, "*10 " pattern)) {
                        AddToLog("Detected Map: " mapName)
                        UpdateMap(mapName) ; For Webhook
                        return mapName
                    }
                }
            } catch {
                if (debugMessages) {
                    AddToLog("Error occurred during map detection.")
                }
            }
        }
        
        Sleep 1000
        Reconnect()
    }
}


IsCorrectMap(mapName) {
    if (ModeDropdown.Text = "Story") {
        if (mapName = "no map found") {
            return false
        }
        return mapName = StoryDropdown.Text
    } else if (ModeDropdown.Text = "Legend") {
        return mapName = LegendDropdown.Text
    } else if (ModeDropdown.Text = "Raid") {
        if (RaidDropdown.Text = "Sacred Planet") {
            return mapName = RaidDropdown.Text
        }
        return true
    } else {
        return true
    }
}

