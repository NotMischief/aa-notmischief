#Include %A_ScriptDir%\Lib\GUI.ahk
global confirmClicked := false

SavePsSettings(*) {
    AddToLog("Saving Private Server")
    
    if FileExist("Settings\PrivateServer.txt")
        FileDelete("Settings\PrivateServer.txt")
    
    FileAppend(PsLinkBox.Value, "Settings\PrivateServer.txt", "UTF-8")
}

SaveUINavSettings(*) {
    AddToLog("Saving UI Navigation Key")
    
    if FileExist("Settings\UINavigation.txt")
        FileDelete("Settings\UINavigation.txt")
    
    FileAppend(UINavBox.Value, "Settings\UINavigation.txt", "UTF-8")
}

;Opens discord Link
OpenDiscordLink() {
    return   ; [NotMischef] Discord link removed
 }
 
 ;Minimizes the UI
 minimizeUI(*){
    aaMainUI.Minimize()
 }
 
 Destroy(*){
    ; [Fix] stop the GUI timers first, so none of them touches the closed window
    try SetTimer(AA_StyleTick, 0)
    try SetTimer(AA_UpdateStats, 0)
    try SetTimer(AA_HoverWatch, 0)
    aaMainUI.Destroy()
    ExitApp
 }
 ;Login Text
 setupOutputFile() {
     content := "`n==" aaTitle "" version "==`n  Start Time: [" currentTime "]`n"
     FileAppend(content, currentOutputFile)
 }



 OnModeChange(*) {
    global mode
    selected := ModeDropdown.Text
    
    ; Hide all dropdowns first
    StoryDropdown.Visible := false
    StoryActDropdown.Visible := false
    LegendDropDown.Visible := false
    LegendActDropdown.Visible := false
    RaidDropdown.Visible := false
    RaidActDropdown.Visible := false
    InfinityCastleDropdown.Visible := false
    MatchMaking.Visible := false
    ReturnLobbyBox.Visible := false
    NextLevelBox.Visible := false   ; [Fix] was never hidden: it overlaps "Return To Lobby" (both at x900 y451), so after a Story act clicks could hit Next Level instead in other modes
    SaveChestsBox.Visible := false
    PortalDropdown.Visible := false 
    PortalJoinDropdown.Visible := false  
    ContractPageDropdown.Visible := false  
    ContractJoinDropdown.Visible := false

    ;Dungeon
    SaveChestsBox.Visible := false
    StopAfterDefeat.Visible := false
    DenyShrines.Visible := false
    EditRoute.Visible := false
    PrioritiseFutureRareChests.Visible := false   ; [Advanced panel] Advanced Settings button

    ;Portals / Infinite
    PortalSwap.Visible := false

    ;Contracts
    TeamSwap.Visible := false
    MagicTeamText.Visible := false
    MagicTeam.Visible := false
    PhysicalTeamText.Visible := false
    PhysicalTeam.Visible := false
    
    if (selected = "Story") {
        StoryDropdown.Visible := true
        StoryActDropdown.Visible := true
        mode := "Story"
    } else if (selected = "Legend") {
        LegendDropDown.Visible := true
        LegendActDropdown.Visible := true
        mode := "Legend"
    } else if (selected = "Raid") {
        RaidDropdown.Visible := true
        RaidActDropdown.Visible := true
        mode := "Raid"
    } else if (selected = "Infinity Castle") {
        InfinityCastleDropdown.Visible := true
        mode := "Infinity Castle"
    } else if (selected = "Contract") {
        ContractPageDropdown.Visible := true
        ContractJoinDropdown.Visible := true
        mode := "Contract"
        TeamSwap.Visible := true
        MagicTeamText.Visible := true
        MagicTeam.Visible := true
        PhysicalTeamText.Visible := true
        PhysicalTeam.Visible := true
        ReturnLobbyBox.Visible := true
    } else if (selected = "Portal") {
        PortalDropdown.Visible := true
        PortalJoinDropdown.Visible := true
        mode := "Portal"
        PortalSwap.Visible := true
    } else if (selected = "Dungeon") {
        AddToLog("⚠️ Dungeon is still under development! Stay tuned for updates.")
        mode := "Dungeon"
        ToggleDungeonCheckboxes()
    } else if (selected = "Cursed Womb") {
        mode := "Cursed Womb"
    } else if (selected = "Fool's Hunt") {
        mode := "Fool's Hunt"
    } else if (selected = "Summer Hunt") {
        mode := "Summer Hunt"
    } else if (selected = "Winter Event") {
        mode := "Winter Event"
        MatchMaking.Visible := true
        ReturnLobbyBox.Visible := true
    }
}

OnStoryChange(*) {
    if (StoryDropdown.Text != "") {
        StoryActDropdown.Visible := true
    } else {
        StoryActDropdown.Visible := false
    }
}

OnStoryActChange(*) {

}

OnLegendChange(*) {
    if (LegendDropDown.Text != "") {
        LegendActDropdown.Visible := true
    } else {
        LegendActDropdown.Visible := false
    }
}

OnRaidChange(*) {
    if (RaidDropdown.Text != "") {
        RaidActDropdown.Visible := true
    } else {
        RaidActDropdown.Visible := false
    }
}

OnConfirmClick(*) {
    if (ModeDropdown.Text = "") {
        AddToLog("Please select a gamemode before confirming")
        return
    }

    ; For Story mode, check if both Story and Act are selected
    if (ModeDropdown.Text = "Story") {
        if (StoryDropdown.Text = "" || StoryActDropdown.Text = "") {
            AddToLog("Please select both Story and Act before confirming")
            return
        }
        AddToLog("Selected " StoryDropdown.Text " - " StoryActDropdown.Text)
        mode := "Story"
        MatchMaking.Visible := (StoryActDropdown.Text = "Infinity")
        ReturnLobbyBox.Visible := (StoryActDropdown.Text = "Infinity")
        NextLevelBox.Visible := (StoryActDropdown.Text != "Infinity")
        PortalSwap.Visible := (StoryActDropdown.Text = "Infinity" && GetMapForFarming(StoryDropdown.Text) != "no map found")
    }
    ; For Legend mode, check if both Legend and Act are selected
    else if (ModeDropdown.Text = "Legend") {
        if (LegendDropDown.Text = "" || LegendActDropdown.Text = "") {
            AddToLog("Please select both Legend Stage and Act before confirming")
            return
        }
        mode := "Legend"
        AddToLog("Selected " LegendDropDown.Text " - " LegendActDropdown.Text)
        MatchMaking.Visible := true
        ReturnLobbyBox.Visible := true
    }
        ; For Cursed Womb, check if both Legend and Act are selected
    else if (ModeDropdown.Text = "Cursed Womb") {
        mode := "Cursed Womb"
        AddToLog("Selected " LegendDropDown.Text " - " LegendActDropdown.Text)
    }
    ; For Raid mode, check if both Raid and RaidAct are selected
    else if (ModeDropdown.Text = "Raid") {
        if (RaidDropdown.Text = "" || RaidActDropdown.Text = "") {
            AddToLog("Please select both Raid and Act before confirming")
            return
        }
        mode := "Raid"
        AddToLog("Selected " RaidDropdown.Text " - " RaidActDropdown.Text)
        MatchMaking.Visible := true
        ReturnLobbyBox.Visible := true
    }
    ; For Infinity Castle, check if mode is selected
    else if (ModeDropdown.Text = "Infinity Castle") {
    if (InfinityCastleDropdown.Text = "") {
        AddToLog("Please select an Infinity Castle difficulty before confirming")
        return
    }
    mode := "Infinity Castle"
    AddToLog("Selected Infinity Castle - " InfinityCastleDropdown.Text)
    MatchMaking.Visible := false  
    ReturnLobbyBox.Visible := false
    }
    ; For Portal, check if both Portal and Join Type are selected
    else if (ModeDropdown.Text = "Portal") {
    if (PortalDropdown.Text = "" || PortalJoinDropdown.Text = "") {
        AddToLog("Please select both Portal and Join Type before confirming")
        return
    }
    mode := "Portal"
    if (GetMapForFarming(PortalDropdown.Text) != "no map found") {
        MatchMaking.Visible := true
    }
    AddToLog("Selected " PortalDropdown.Text " - " PortalJoinDropdown.Text)
    } 
    ; For Contract mode
    else if (ModeDropdown.Text = "Contract") {
        if (ContractPageDropdown.Text = "" || ContractJoinDropdown.Text = "") {
            AddToLog("Please select both Contract Page and Join Type before confirming")
            return
        }
        mode := "Contract"
        AddToLog("Selected Contract Page " ContractPageDropdown.Text " - " ContractJoinDropdown.Text)
        MatchMaking.Visible := false
        ReturnLobbyBox.Visible := true
    }
    else if (ModeDropdown.Text = "Dungeon") {
        mode := "Dungeon"
        AddToLog("Selected Dungeon")
    }
    ; Fools Event
    else if (ModeDropdown.Text = "Fool's Hunt") {
        mode := "Fool's Hunt"
        AddToLog("Selected Fool's Hunt")
        MatchMaking.Visible := true
        ReturnLobbyBox.Visible := true
        NoMovement.Visible := true
        NewPlacementMethod.Visible := true
        EditMaps.Visible := true
        BringUnits.Visible := true
        try SummerFallbackBox.Visible := false
        try SummerTeamDDL.Visible := false, DungeonTeamDDL.Visible := false
        EditCardPrio.Visible := true
        LoadFoolsConfig()
    }
    ; [Summer Hunt]
    else if (ModeDropdown.Text = "Summer Hunt") {
        mode := "Summer Hunt"
        AddToLog("Selected Summer Hunt")
        MatchMaking.Visible := true
        ReturnLobbyBox.Visible := true
        NoMovement.Visible := true
        NewPlacementMethod.Visible := false   ; the Fool's Hunt test placement doesn't apply here
        try SummerFallbackBox.Visible := true
        try SummerTeamDDL.Visible := true, DungeonTeamDDL.Visible := true
        global SH_FallbackUntil := 0   ; you picked Summer Hunt yourself - no leftover Dungeon switch
        try SH_SaveUntil(0)
        EditMaps.Visible := true
        EditCardPrio.Visible := true
        try PlacementSelection.Choose("Summer Hunt"), ToggleMode()
    }
    ; Winter Event
    else if (ModeDropdown.Text = "Winter Event") {
        mode := "Winter Event"
        AddToLog("Selected Winter Event")
    }
    else {
        mode := ModeDropdown.Text
        AddToLog("Selected " ModeDropdown.Text " mode")
        MatchMaking.Visible := false
        ReturnLobbyBox.Visible := false
    }

    AddToLog("Don't forget to Desable Ui Navigation and Click to Move!")

    ; Hide all controls if validation passes
    ModeDropdown.Visible := false
    StoryDropdown.Visible := false
    StoryActDropdown.Visible := false
    LegendDropDown.Visible := false
    LegendActDropdown.Visible := false
    RaidDropdown.Visible := false
    RaidActDropdown.Visible := false
    InfinityCastleDropdown.Visible := false
    PortalDropdown.Visible := false
    PortalJoinDropdown.Visible := false
    ConfirmButton.Visible := false
    modeSelectionGroup.Visible := false
    ContractPageDropdown.Visible := false
    ContractJoinDropdown.Visible := false
    Hotkeytext.Visible := true
    Hotkeytext2.Visible := true
    global confirmClicked := true
}

ToggleSaveChestsForBoss(*) {
    global SaveChestsForBoss
    SaveChestsForBoss := !SaveChestsForBoss
    AddToLog("Save chests for boss room: " (SaveChestsForBoss ? "Enabled" : "Disabled"))
}

CheckForEmptyKeys() {
    AddToLog("Looking for key purchase prompt")
    if (ok:=FT(&X, &Y, 434-150000, 383-150000, 434+150000, 383+150000, 0, 0, RobuxPurchaseKey)) {
        AddToLog("Found an attempt to purchase key for robux, closing macro.")
        return
    }
}

OpenGithub() {
    ; Removed to prevent access to non testers / mists donators
}

OpenDiscord() {
    return   ; [NotMischef] Discord link removed
}

; ============================================================================
;  [Settings panel] handlers for the in-window Settings panel
;  (Lib\GuiPanels.ahk). They only open existing Adventures windows or save
;  settings - none of them starts the macro or sends input to the game.
; ============================================================================

; Settings > "Webhook Enabled": saved straight away to Settings\WebhookEnabled.txt.
; Off = no webhooks at all (results, console logs, disconnect). Missing file = on.
AA_SaveWebhookEnabled(*) {
    global AA_WebhookEnabledCache
    val := WebhookEnabledBox.Value ? "1" : "0"
    try {
        if FileExist("Settings\WebhookEnabled.txt")
            FileDelete("Settings\WebhookEnabled.txt")
        FileAppend(val, "Settings\WebhookEnabled.txt", "UTF-8")
        AA_WebhookEnabledCache := val
        AddToLog("Webhook " (val = "1" ? "enabled" : "disabled"))
    } catch as err {
        AddToLog("Could not save the webhook setting: " err.Message)
    }
}

; Settings > "Test Link": opens the link in the box exactly the way RejoinPrivateServer
; does (Run(link)), only after you confirm, and never while the macro is running.
AA_TestPrivateServerLink(*) {
    link := Trim(PsLinkBox.Value)
    if (link = "") {
        AddToLog("Enter a private server link first")
        return
    }
    if !RegExMatch(link, "i)^(https?|roblox)://") {
        AddToLog("That is not a link - it must start with https:// or roblox://")
        return
    }
    if (MacroLoopState.Active) {
        AddToLog("Stop the macro (" F3Key ") before testing the link")
        return
    }
    aaMainUI.Opt("-AlwaysOnTop")
    answer := MsgBox("This opens the link. Roblox will leave your current server and join this one.`n`nContinue?", "Test Private Server Link", 0x1024)   ; Yes/No + question icon + always on top
    aaMainUI.Opt("+AlwaysOnTop")
    if (answer != "Yes")
        return
    try {
        Run(link)
        AddToLog("Opened private server link (remember to press Save if it worked)")
    } catch as err {
        AddToLog("Could not open the link: " err.Message)
    }
}

; Settings > Config Code "Import": existing ImportConfigCode(), then the imported
; settings are loaded into the GUI (before, they only took effect after a restart).
AA_ImportConfigCode(*) {
    path := A_ScriptDir "\Settings\Configuration.txt"
    before := ""
    try before := FileExist(path) ? FileRead(path, "UTF-8") : ""
    aaMainUI.Opt("-AlwaysOnTop")
    try ImportConfigCode()
    aaMainUI.Opt("+AlwaysOnTop")
    after := ""
    try after := FileExist(path) ? FileRead(path, "UTF-8") : ""
    if (after != "" && after != before) {
        readInSettings()
        AddToLog("Imported settings loaded into the GUI")
    }
}
