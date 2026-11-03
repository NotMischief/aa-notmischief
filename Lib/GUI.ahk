#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\Lib\Tools\Image.ahk
#Include %A_ScriptDir%\Lib\GuiEvents.ahk
#Include %A_ScriptDir%\Lib\GuiStyle.ahk    ; [Modern GUI] flat buttons, cards, switches, status bar, theme (functions only)
#Include %A_ScriptDir%\Lib\GuiPanels.ahk   ; [Settings panel] in-window Settings panel (functions only)
#Include %A_ScriptDir%\Lib\GuiGuide.ahk    ; [Guide panel] setup guide panel (functions only)
#Include UpdateChecker.ahk

;Update Checker
global repoOwner := ""
global repoName := "anime-adventures"
global currentVersion := ""

; Basic Application Info
global aaTitle := "AA NotMischef "
global version := "v" . currentVersion
global rblxID := "ahk_exe RobloxPlayerBeta.exe"
;Coordinate and Positioning Variables
global targetWidth := 816
global targetHeight := 638
global offsetX := -5
global offsetY := 1
global WM_SIZING := 0x0214
global WM_SIZE := 0x0005
global centerX := 408
global centerY := 320
global successfulCoordinates := []
global maxedCoordinates := []
;Hotkeys
global F1Key := "F1"
global F2Key := "F2"
global F3Key := "F3"
global F4Key := "F4"
;Statistics Tracking
global Wins := 0
global loss := 0
global mode := ""
global StartTime := A_TickCount
global currentTime := GetCurrentTime()
;Auto Challenge
global challengeStartTime := A_TickCount
global inChallengeMode := false
global firstStartup := true
;Gui creation
global uiBorders := []
global uiBackgrounds := []
global uiTheme := []
global UnitData := []
global aaMainUI := Gui("+AlwaysOnTop -Caption")
global lastlog := ""
global aaMainUIHwnd := aaMainUI.Hwnd
;Theme colors
uiTheme.Push("F2F2F2")  ; Header color
uiTheme.Push("181818")  ; Background color
uiTheme.Push("2F81F7")  ; Border color (blue)
uiTheme.Push("242424")  ; Accent color
uiTheme.Push("303030")  ; Trans color
uiTheme.Push("111111")  ; Textbox color
uiTheme.Push("79B8FF")  ; Highlight (light blue)
AA_StyleInit()   ; [Modern GUI] accent colour from Settings\Theme.txt + dark dropdowns / lists
;Logs/Save settings
global currentOutputFile := A_ScriptDir "\Logs\LogFile.txt"
; [Optimised] keep the log from growing forever: over 5 MB -> moved to LogFile_old.txt on startup
try {
    if (FileExist(currentOutputFile) && FileGetSize(currentOutputFile) > 5 * 1024 * 1024)
        FileMove(currentOutputFile, A_ScriptDir "\Logs\LogFile_old.txt", 1)
}
global WebhookURLFile := "Settings\WebhookURL.txt"
global DiscordUserIDFile := "Settings\DiscordUSERID.txt"
global SendActivityLogsFile := "Settings\SendActivityLogs.txt"

;Custom Pictures
GithubImage := "Images\github-logo.png"
DiscordImage := "Images\another_discord.png"
WheelImage:= "Images\wheel.png"

if !DirExist(A_ScriptDir "\Logs") {
    DirCreate(A_ScriptDir "\Logs")
}
if !DirExist(A_ScriptDir "\Settings") {
    DirCreate(A_ScriptDir "\Settings")
}

setupOutputFile()

;------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------
aaMainUI.BackColor := uiTheme[2]
global Webhookdiverter := aaMainUI.Add("Edit", "x0 y0 w1 h1 +Hidden", "") ; diversion
uiBorders.Push(aaMainUI.Add("Text", "x0 y0 w1364 h1 +Background" uiTheme[3]))  ;Top line
uiBorders.Push(aaMainUI.Add("Text", "x0 y0 w1 h697 +Background" uiTheme[3]))   ;Left line
uiBorders.Push(aaMainUI.Add("Text", "x1363 y0 w1 h630 +Background" uiTheme[3])) ;Right line
uiBorders.Push(aaMainUI.Add("Text", "x1363 y0 w1 h697 +Background" uiTheme[3])) ;Second Right line
uiBackgrounds.Push(aaMainUI.Add("Text", "x3 y3 w1360 h27 +Background" uiTheme[2])) ;Title Top
uiBorders.Push(aaMainUI.Add("Text", "x0 y30 w1363 h1 +Background" uiTheme[3])) ;Title bottom
uiBorders.Push(aaMainUI.Add("Text", "x803 y443 w560 h1 +Background" uiTheme[3])) ;Placement bottom
uiBorders.Push(aaMainUI.Add("Text", "x803 y527 w560 h1 +Background" uiTheme[3])) ;Process bottom
uiBorders.Push(aaMainUI.Add("Text", "x802 y30 w1 h667 +Background" uiTheme[3])) ;Roblox Right
uiBorders.Push(aaMainUI.Add("Text", "x0 y697 w1364 h1 +Background" uiTheme[3], "")) ;Roblox second bottom

global robloxHolder := aaMainUI.Add("Text", "x3 y33 w797 h597 +Background" uiTheme[5], "") ;Roblox window box
global exitButton := aaMainUI.Add("Picture", "x1330 y1 w32 h32 +BackgroundTrans", Exitbutton) ;Exit image
exitButton.OnEvent("Click", (*) => Destroy()) ;Exit button
global minimizeButton := aaMainUI.Add("Picture", "x1300 y3 w27 h27 +Background" uiTheme[2], Minimize) ;Minimize gui
minimizeButton.OnEvent("Click", (*) => minimizeUI()) ;Minimize gui
aaMainUI.SetFont("Bold s16 c" uiTheme[1], "Segoe UI") ;Font
global windowTitle := aaMainUI.Add("Text", "x10 y3 w1200 h29 +BackgroundTrans", aaTitle "" . "v1" ) ;Title

aaMainUI.Add("Text", "x805 y497 w558 h25 +Center +BackgroundTrans c" uiTheme[3], "Process") ;Process header in the accent colour
uiBorders.Push(aaMainUI.Add("Text", "x803 y499 w560 h1 +Background" uiTheme[3])) ;Process Top
aaMainUI.SetFont("s8 Bold underline c" uiTheme[7], "Segoe UI")   ; [Modern GUI] open the full log file
global OpenLogLink := aaMainUI.Add("Text", "x1290 y505 w62 h16 +BackgroundTrans c" uiTheme[7], "Open log")
OpenLogLink.OnEvent("Click", (*) => Run(currentOutputFile))
aaMainUI.SetFont("norm s11 c" uiTheme[1]) ;Font
global process1 := aaMainUI.Add("Text", "x810 y536 w538 h18 +BackgroundTrans c" uiTheme[7], "") ;Processes
global process2 := aaMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "Based on the AA macro by RandomDev")
global process3 := aaMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "") 
global process4 := aaMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "") 
global process5 := aaMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "") 
global process6 := aaMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "") 
global process7 := aaMainUI.Add("Text", "xp yp+22 w538 h18 +BackgroundTrans", "") 
WinSetTransColor(uiTheme[5], aaMainUI) ;Roblox window box

;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS
; [Settings panel] The Settings popup (ShowSettingsGUI) was replaced by an in-window panel
; (Lib\GuiPanels.ahk): same controls and save functions, shown in place of the unit cards.

; [Debug panel] The Debug popup (OpenDebug) and the screen-check popup (GetScreenInfo) were
; replaced by the Debug panel in Lib\GuiPanels.ahk (AA_BuildDebugPanel); the screen check is now
; the "Test screen resolution / DPI" Quick Test in Lib\Tools\DetectionTester.ahk.

GetScreenInfoStartUp() {
    screenWidth := SysGet(78)  ; Get screen width
    screenHeight := SysGet(79) ; Get screen height
    dpi := DllCall("user32\GetDpiForSystem", "UInt")  ; Get system DPI
    zoom := Round(dpi / 96 * 100)  ; Calculate Zoom %
     if (screenWidth = 1920 && screenHeight = 1080 && zoom = 100) {

    } else {
        AddToLog("Your resolution or zoom is different from what the script needs!")
        AddToLog("please set to 1920x1080 and 100% zoom")
    }
}

OpenGuide(*) {   ; [Guide panel] the guide is now a panel in the main window (Lib\GuiGuide.ahk)
    AA_TogglePanel("Guide")
}

aaMainUI.SetFont("s9 Bold c" uiTheme[1])

;DEBUG                                                              
global DebugButton := AA_Btn(aaMainUI, "x1000 y5 w90 h20", "Debug")
DebugButton.OnEvent("Click", (*) => AA_TogglePanel("Debug"))   ; [Debug panel] in-window panel, like Settings

global guideBtn := AA_Btn(aaMainUI, "x1100 y5 w90 h20", "Guide")
guideBtn.OnEvent("Click", OpenGuide)

global settingsBtn := AA_Btn(aaMainUI, "x1200 y5 w90 h20", "Settings")
settingsBtn.OnEvent("Click", AA_ToggleSettingsPanel)   ; [Settings panel] click again to go back to the units

; [Custom movement] record / replay your own walk per map (Lib\Game\CustomMovement.ahk)
; [Custom placement] own tab, left of Custom Map (Lib\Game\CustomPlacement.ahk)
global CustomPlacementBtn := AA_Btn(aaMainUI, "x665 y5 w120 h20", "Custom Placement")
CustomPlacementBtn.OnEvent("Click", (*) => AA_TogglePanel("Placement"))   ; panel built by CP_BuildPanel
global CustomMovementBtn := AA_Btn(aaMainUI, "x795 y5 w95 h20", "Custom Map")
CustomMovementBtn.OnEvent("Click", (*) => AA_TogglePanel("Movement"))   ; panel built by CM_BuildPanel

global SchedulerBtn := AA_Btn(aaMainUI, "x900 y5 w90 h20", "Scheduler")
SchedulerBtn.OnEvent("Click", OpenScheduler)

global MaharagaButton := aaMainUI.Add("Picture", "x1308 y30 w55 h55 +BackgroundTrans cffffff", WheelImage)
MaharagaButton.OnEvent("Click", (*) => ToggleSettingsVisibility())

placementSaveBtn := AA_Btn(aaMainUI, "x807 y471 w80 h20", "Save")
placementSaveBtn.OnEvent("Click", SaveSettings)

aaMainUI.SetFont("s9")

;Normal Options
global NextLevelBox := aaMainUI.Add("Checkbox", "x900 y451 cffffff Checked", "Next Level")
global ReturnLobbyBox := aaMainUI.Add("Checkbox", "x900 y451 cffffff Checked", "Return To Lobby")
global MatchMaking := aaMainUI.Add("Checkbox", "x900 y476 cffffff Hidden Checked", "Matchmaking") ; Old : x1035 y451
;Contract Options
global TeamSwap := aaMainUI.Add("CheckBox", "x900 y476 cffffff", "Team Swap")
PhysicalTeamText := aaMainUI.Add("Text", "x1135 y451 w115 h20 +Center", "Physical Team")
global PhysicalTeam := aaMainUI.Add("DropDownList", "x1170 y471 w45 h180 Choose1 +Center", ["1", "2", "3", "4", "5", "6"])
MagicTeamText := aaMainUI.Add("Text", "x1250 y451 w80 h20 +Center", "Magic Team")
global MagicTeam := aaMainUI.Add("DropDownList", "x1270 y471 w45 h180 Choose1 +Center", ["1", "2", "3", "4", "5", "6"])
; Dungeon Options
SaveChestsBox := aaMainUI.Add("CheckBox", "x900 y451 cffffff Checked", "Save Chests For Rukia")
StopAfterDefeat := aaMainUI.Add("CheckBox", "x900 y476 cffffff Checked", "Stop Upon Defeat") ;x1005 y451
DenyShrines := aaMainUI.Add("CheckBox", "x1075 y451 cffffff Checked", "Reject Shrines")
PrioritiseFutureRareChests := aaMainUI.Add("CheckBox", "x1210 y451 cffffff Checked", "RareChest Path")
; [Advanced panel] one button instead of Edit Route / Edit Curses / Edit Shrine:
; route, curses and shrines are now one panel in the main window (AA_BuildAdvancedPanel)
global EditRoute := AA_Btn(aaMainUI, "x1050 y470 w150 h25", "Advanced Settings")
EditRoute.OnEvent("Click", (*) => AA_TogglePanel("Advanced"))
;April Fools Event Option
NewPlacementMethod := aaMainUI.Add("CheckBox", "x1050 y451 cffffff Checked", "Test Unit Method")
global SummerFallbackBox := aaMainUI.Add("CheckBox", "x1050 y451 cffffff Hidden", "Dungeon on unknown map")   ; [Dungeon fallback]
SummerFallbackBox.Value := SH_FallbackOn()
SummerFallbackBox.OnEvent("Click", SH_FallbackSave)
global SummerTeamDDL := aaMainUI.Add("DropDownList", "x1200 y448 w78 h200 Hidden", ["Sum: -", "Sum: T1", "Sum: T2", "Sum: T3", "Sum: T4"])
global DungeonTeamDDL := aaMainUI.Add("DropDownList", "x1282 y448 w80 h200 Hidden", ["Dun: -", "Dun: T1", "Dun: T2", "Dun: T3", "Dun: T4"])
SummerTeamDDL.Choose(SH_Team("Summer") + 1), DungeonTeamDDL.Choose(SH_Team("Dungeon") + 1)
SummerTeamDDL.OnEvent("Change", SH_TeamSave), DungeonTeamDDL.OnEvent("Change", SH_TeamSave)
NoMovement := aaMainUI.Add("CheckBox", "x1050 y476 cffffff", "No Movement")
BringUnits := aaMainUI.Add("CheckBox", "x1200 y451 cffffff Checked", "Freeze Game/Bring Unit")
EditMaps := AA_Btn(aaMainUI, "x1200 y470 w78 h25", "Edit Maps")
EditMaps.OnEvent("Click", (*) => OpenMapSkipPriorityPicker())
EditCardPrio := AA_Btn(aaMainUI, "x1282 y470 w80 h25", "Card Prio")
EditCardPrio.OnEvent("Click", (*) => AA_TogglePanel("Cards"))   ; [Card picker] panel (Lib\Game\CardPicker.ahk)
;Misc Options
global MiscSettings := "" ;aaMainUI.Add("GroupBox", "x180 y630 w135 h60 +Center c" uiTheme[1], "Misc. Settings")
global StoryUINav := aaMainUI.Add("Checkbox", "x2000 y650 c" uiTheme[1], "UI Navigation")
;Upgrade Option Testing
; [Modern GUI] cards below the Roblox window (Stats 105-315, Upgrade 335-575, Auto 595-795);
; the checkboxes become ON/OFF switches in AA_StyleFinish (same controls, same values)
global UpgradeSettings := AA_Card(335, 642, 240, 52, "Upgrade Settings")
global PriorityUpgrade := aaMainUI.Add("CheckBox", "x345 y658 cffffff +Background" AA_CardColor, "Priority Upgrade")
global MaxUpgradeBeforeMoving := aaMainUI.Add("CheckBox", "x345 y676 cffffff +Background" AA_CardColor, "Upgrade units one at a time")
;Auto Settings
global AutoSettings := AA_Card(595, 642, 200, 52, "Auto Settings")
global AutoAbilityBox := aaMainUI.Add("CheckBox", "x605 y658 cffffff Checked +Background" AA_CardColor, "Auto Ability")
global ChallengeBox := aaMainUI.Add("CheckBox", "x605 y676 cffffff +Background" AA_CardColor, "Auto Challenge")
;Portal Settings
global PortalSwap := aaMainUI.Add("CheckBox", "x1050 y451 cffffff", "Rotate Portals / Infinite")
;Mahoraga Settings
FirstAdaptationText := aaMainUI.Add("Text", "x830 y390 w130 h20 +Center", "First Adaptation")
global FirstAdaptation := aaMainUI.Add("DropDownList", "x845 y410 w100 h180 Choose1", ["Divine Wings", "Heavenly Force", "Adapted Slash"])

SecondAdaptationText := aaMainUI.Add("Text", "x960 y390 w130 h20 +Center", "Second Adaptation")
global SecondAdaptation := aaMainUI.Add("DropDownList", "x975 w100 y410 h180 Choose2", ["Divine Wings", "Heavenly Force", "Adapted Slash"])

FinalAdaptationText := aaMainUI.Add("Text", "x1090 y390 w130 h20 +Center", "Final Adaptation")
global FinalAdaptation := aaMainUI.Add("DropDownList", "x1105 y410 w100 h180 Choose3", ["Divine Wings", "Heavenly Force", "Adapted Slash"])

MahoragoModeText := aaMainUI.Add("Text", "x1220 y390 w130 h20 +Center", "Attack Style")
global MahoragoMode := aaMainUI.Add("DropDownList", "x1235 y410 w100 h180 Choose1", ["Defend", "Boss", "Attack"])

; General Settings
PlacementSelectionText := aaMainUI.Add("Text", "x812 y390 w130 h20", "Placement Profiles")
PlacementSelection := aaMainUI.Add("DropDownList", "x825 y410 w100 h180 Choose1 +Center", ["Default", "Challenge", "Contract", "Dungeon", "Raid", "Fool's Hunt", "Summer Hunt"])

PlacementPatternText := aaMainUI.Add("Text", "x960 y390 w115 h20", "Placement Type")
global PlacementPatternDropdown := aaMainUI.Add("DropDownList", "x962 y410 w100 h180 Choose2 +Center", ["Circle", "Grid", "3x3 Grid", "Spiral(WIP)", "Up and Down", "Random"])

PlaceSpeedText := aaMainUI.Add("Text", "x1090 y390 w115 h20", "Placement Speed")
global PlaceSpeed := aaMainUI.Add("DropDownList", "x1095 y410 w100 h180 Choose1 +Center", ["Super Fast (1s)", "Fast (1.5s)", "Default (2s)", "Slow (2.5s)", "Very Slow (3s)", "Toaster (4s)", "Gameboy (5s)", "Blitz"])

LobbySleepText := aaMainUI.Add("Text", "x1220 y390 w130 h20 +Center", "Lobby Sleep Timer")
global LobbySleepTimer := aaMainUI.Add("DropDownList", "x1235 y410 w100 h180 Choose1", ["No Delay", "5 Seconds", "10 Seconds", "15 Seconds", "20 Seconds", "25 Seconds", "30 Seconds", "35 Seconds", "40 Seconds", "45 Seconds", "50 Seconds", "55 Seconds", "60 Seconds"])

placementSaveText := aaMainUI.Add("Text", "x807 y451 w80 h20", "Save Config")
; [Polish] settings labels in the accent colour
for _hdr in [PlacementSelectionText, PlacementPatternText, PlaceSpeedText, LobbySleepText, placementSaveText, FinalAdaptationText, MahoragoModeText]
    try _hdr.SetFont("Bold c" uiTheme[3])

Hotkeytext := aaMainUI.Add("Text", "x807 y35 w500 h30", "Below are the default hotkey settings ")
Hotkeytext2 := aaMainUI.Add("Text", "x807 y50 w500 h30", "F1:Fix Roblox Window|F2:Start Macro|F3:Stop Macro|F4:Pause Macro|F5:Save Hotbar (in lobby)|F6:Unit Types|F8:Record|F9:Watch|F10:Record walk")
GithubButton := aaMainUI.Add("Picture", "x30 y640 w40 h40 +BackgroundTrans cffffff Hidden", GithubImage)
DiscordButton := aaMainUI.Add("Picture", "x30 y645 w60 h34 +BackgroundTrans cffffff Hidden", DiscordImage)   ; [NotMischef] Discord button removed

GithubButton.OnEvent("Click", (*) => OpenGithub())

;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS;--------------SETTINGS
;--------------MODE SELECT;--------------MODE SELECT;--------------MODE SELECT;--------------MODE SELECT;--------------MODE SELECT;--------------MODE SELECT
aaMainUI.SetFont("Bold s10 c" uiTheme[3])   ; [Polish] section header in the accent colour
global modeSelectionGroup := aaMainUI.Add("GroupBox", "x808 y38 w500 h45 Background" uiTheme[2], "Mode Select")
aaMainUI.SetFont("s10 c" uiTheme[6])
global ModeDropdown := aaMainUI.Add("DropDownList", "x818 y53 w140 h180 Choose0 +Center", ["Story", "Dungeon", "Legend", "Raid", "Portal", "Infinity Castle", "Cursed Womb", "Fool's Hunt", "Summer Hunt"])
global StoryDropdown := aaMainUI.Add("DropDownList", "x968 y53 w150 h180 Choose0 +Center", ["Planet Greenie", "Walled City", "Snowy Town", "Sand Village", "Navy Bay", "Fiend City", "Spirit World", "Ant Kingdom", "Magic Town", "Haunted Academy", "Magic Hills", "Space Center", "Alien Spaceship", "Fabled Kingdom", "Ruined City", "Puppet Island", "Virtual Dungeon", "Snowy Kingdom", "Dungeon Throne", "Mountain Temple", "Rain Village", "Shibuya District"])
global StoryActDropdown := aaMainUI.Add("DropDownList", "x1128 y53 w80 h180 Choose0 +Center", ["Act 1", "Act 2", "Act 3", "Act 4", "Act 5", "Act 6", "Infinity"])
global LegendDropDown := aaMainUI.Add("DropDownlist", "x968 y53 w150 h180 Choose0 +Center", ["Magic Hills", "Spirit Invasion", "Space Center", "Fabled Kingdom", "Ruined City", "Virtual Dungeon", "Dungeon Throne", "Rain Village"] )
global LegendActDropdown := aaMainUI.Add("DropDownList", "x1128 y53 w80 h180 Choose0 +Center", ["Act 1", "Act 2", "Act 3", "Act 4", "Act 5", "Act 6", "Random"])
global RaidDropdown := aaMainUI.Add("DropDownList", "x968 y53 w150 h180 Choose0 +Center", ["Ant Kingdom", "Sacred Planet", "Strange Town", "Ruined City", "Cursed Festival", "Future City (Tyrant)", "Storm Hideout", "Future City", "Nightmare Train", "Sand Village"])
global RaidActDropdown := aaMainUI.Add("DropDownList", "x1128 y53 w80 h180 Choose0 +Center", ["Act 1", "Act 2", "Act 3", "Act 4", "Act 5"])
global InfinityCastleDropdown := aaMainUI.Add("DropDownList", "x968 y53 w80 h180 Choose0 +Center", ["Normal", "Hard"])
global PortalDropdown := aaMainUI.Add("DropDownList", "x968 y53 w150 h180 Choose0 +Center", ["Alien Portal", "Puppet Portal", "Demon Leader's Portal", "Eclipse Portal", "Noble Portal", "Shibuya Portal"])
global PortalJoinDropdown := aaMainUI.Add("DropDownList", "x1128 y53 w80 h180 Choose0 +Center", ["Creating", "Joining", "Solo"])
global ContractPageDropdown := aaMainUI.Add("DropDownList", "x968 y53 w80 h180 Choose0 +Center", ["Page 1", "Page 2","Page 3","Page 4","Page 5","Page 6", "Page 4-5"])
global ContractJoinDropdown := aaMainUI.Add("DropDownList", "x1057 y53 w120 h180 Choose0 +Center", ["Creating", "Joining","Matchmaking", "Solo"])
global ConfirmButton := AA_Btn(aaMainUI, "x1218 y53 w80 h25", "Confirm")

StoryDropdown.Visible := false
StoryActDropdown.Visible := false
LegendDropDown.Visible := false
LegendActDropdown.Visible := false
RaidDropdown.Visible := false
RaidActDropdown.Visible := false
InfinityCastleDropdown.Visible := false
ContractPageDropdown.Visible := false
ContractJoinDropdown.Visible := false
PortalDropdown.Visible := false
PortalJoinDropdown.Visible := false
MatchMaking.Visible := false
ReturnLobbyBox.Visible := false
NextLevelBox.Visible := false
Hotkeytext.Visible := false
Hotkeytext2.Visible := false

; Hide adaptation settings
FirstAdaptationText.Visible := false
FirstAdaptation.Visible := false
SecondAdaptationText.Visible := false
SecondAdaptation.Visible := false
FinalAdaptationText.Visible := false
FinalAdaptation.Visible := false
MahoragoModeText.Visible := false
MahoragoMode.Visible := false

;Dungeons
SaveChestsBox.Visible := false
StopAfterDefeat.Visible := false
DenyShrines.Visible := false
EditRoute.Visible := false
PrioritiseFutureRareChests.Visible := false

;April Fools Event
NewPlacementMethod.Visible := false
NoMovement.Visible := false
EditMaps.Visible := false
BringUnits.Visible := false
EditCardPrio.Visible := false

;Portal Farming
PortalSwap.Visible := false

;Contracts
TeamSwap.Visible := false
MagicTeamText.Visible := false
MagicTeam.Visible := false
PhysicalTeamText.Visible := false
PhysicalTeam.Visible := false

ModeDropdown.OnEvent("Change", OnModeChange)
StoryDropdown.OnEvent("Change", OnStoryChange)
StoryActDropdown.OnEvent("Change", OnStoryActChange)
LegendDropDown.OnEvent("Change", OnLegendChange)
RaidDropdown.OnEvent("Change", OnRaidChange)
ConfirmButton.OnEvent("Click", OnConfirmClick)
SaveChestsBox.OnEvent("Click", ToggleSaveChestsForBoss)
;------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI------MAIN UI
;------UNIT CONFIGURATION------UNIT CONFIGURATION------UNIT CONFIGURATION/------UNIT CONFIGURATION/------UNIT CONFIGURATION/------UNIT CONFIGURATION/

; ---- 3 x 2 unit cards -------------------------------------------------------
global UnitCardW := 179, UnitCardH := 147
global UnitCardX := [808, 993, 1178]      ; 3 columns
global UnitCardY := [85, 235]             ; 2 rows

UnitCardPos(index, &x, &y) {
    x := UnitCardX[Mod(index - 1, 3) + 1]
    y := UnitCardY[(index - 1) // 3 + 1]
}

AddUnitCard(aaMainUI, index, x, y) {
    unit := {}
    w := UnitCardW, h := UnitCardH

    unit.Background   := aaMainUI.Add("Text", Format("x{} y{} w{} h{} +Background{}", x, y, w, h, uiTheme[4]))
    unit.BorderTop    := aaMainUI.Add("Text", Format("x{} y{} w{} h2 +Background{}", x, y, w, uiTheme[3]))
    unit.BorderBottom := aaMainUI.Add("Text", Format("x{} y{} w{} h2 +Background{}", x, y + h - 2, w, uiTheme[3]))
    unit.BorderLeft   := aaMainUI.Add("Text", Format("x{} y{} w2 h{} +Background{}", x, y, h, uiTheme[3]))
    unit.BorderRight  := aaMainUI.Add("Text", Format("x{} y{} w2 h{} +Background{}", x + w - 2, y, h, uiTheme[3]))
    unit.Divider      := aaMainUI.Add("Text", Format("x{} y{} w{} h1 +Background{}", x + 8, y + 28, w - 16, uiTheme[3]))

    aaMainUI.SetFont("s11 Bold c" uiTheme[1])
    unit.Title := aaMainUI.Add("Text", Format("x{} y{} w{} h22 +BackgroundTrans", x + 30, y + 5, w - 40), "Unit " index)

    aaMainUI.SetFont("s9 c" uiTheme[1])
    unit.PlacementText := aaMainUI.Add("Text", Format("x{} y{} w95 h20 +BackgroundTrans", x + 10, y + 36), "Placement")
    unit.PriorityText  := aaMainUI.Add("Text", Format("x{} y{} w95 h20 +BackgroundTrans", x + 10, y + 62), "UPG Priority")
    unit.UpgradeText   := aaMainUI.Add("Text", Format("x{} y{} w120 h20 +BackgroundTrans", x + 10, y + 88), "Place && Upgrade")
    unit.LimitText     := aaMainUI.Add("Text", Format("x{} y{} w80 h20 +BackgroundTrans", x + 10, y + 114), "Upg. Limit")

    UnitData.Push(unit)
    return unit
}

; Moves every profile's unit controls (Default, Challenge, Contract, Dungeon, Raid, Event)
; into its card. The controls are still created below with the old row positions.
LayoutUnitCards() {
    profiles := [
        ["Enabled", "Placement", "Priority", "upgradeEnabled", "upgradeLimitEnabled", "UpgradeLimit"],
        ["ChallengeEnabled", "ChallengePlacement", "ChallengePriority", "challengeUpgradeEnabled", "challengeUpgradeLimitEnabled", "ChallengeUpgradeLimit"],
        ["ContractEnabled", "ContractPlacement", "ContractPriority", "contractUpgradeEnabled", "contractUpgradeLimitEnabled", "ContractUpgradeLimit"],
        ["DungeonEnabled", "DungeonPlacement", "DungeonPriority", "dungeonUpgradeEnabled", "dungeonUpgradeLimitEnabled", "DungeonUpgradeLimit"],
        ["RaidEnabled", "RaidPlacement", "RaidPriority", "raidUpgradeEnabled", "raidUpgradeLimitEnabled", "RaidUpgradeLimit"],
        ["EventEnabled", "EventPlacement", "EventPriority", "eventUpgradeEnabled", "eventUpgradeLimitEnabled", "EventUpgradeLimit"],
        ["SummerEnabled", "SummerPlacement", "SummerPriority", "summerUpgradeEnabled", "summerUpgradeLimitEnabled", "SummerUpgradeLimit"]
    ]
    loop 6 {
        i := A_Index
        UnitCardPos(i, &x, &y)
        for names in profiles {
            spots := [[10, 8, 0], [109, 33, 60], [109, 59, 60], [152, 90, 0], [90, 116, 0], [109, 111, 60]]
            for k, name in names {
                ctrlName := name i
                try {
                    ctrl := %ctrlName%
                    if spots[k][3]
                        ctrl.Move(x + spots[k][1], y + spots[k][2], spots[k][3])
                    else
                        ctrl.Move(x + spots[k][1], y + spots[k][2])
                }
            }
        }
    }
}

;Create Unit slot
Loop 6 {
    UnitCardPos(A_Index, &cardX, &cardY)
    AddUnitCard(aaMainUI, A_Index, cardX, cardY)
}

enabled1 := aaMainUI.Add("CheckBox", "x818 y105 w15 h15", "")
enabled2 := aaMainUI.Add("CheckBox", "x818 y155 w15 h15", "")
enabled3 := aaMainUI.Add("CheckBox", "x818 y205 w15 h15", "")
enabled4 := aaMainUI.Add("CheckBox", "x818 y255 w15 h15", "")
enabled5 := aaMainUI.Add("CheckBox", "x818 y305 w15 h15", "")
enabled6 := aaMainUI.Add("CheckBox", "x818 y355 w15 h15", "")

upgradeEnabled1 := aaMainUI.Add("CheckBox", "x1070 y105 w15 h15", "")
upgradeEnabled2 := aaMainUI.Add("CheckBox", "x1070 y155 w15 h15", "")
upgradeEnabled3 := aaMainUI.Add("CheckBox", "x1070 y205 w15 h15", "")
upgradeEnabled4 := aaMainUI.Add("CheckBox", "x1070 y255 w15 h15", "")
upgradeEnabled5 := aaMainUI.Add("CheckBox", "x1070 y305 w15 h15", "")
upgradeEnabled6 := aaMainUI.Add("CheckBox", "x1070 y355 w15 h15", "")

upgradeLimitEnabled1 := aaMainUI.Add("CheckBox", "x1210 y105 w15 h15", "")
upgradeLimitEnabled2 := aaMainUI.Add("CheckBox", "x1210 y155 w15 h15", "")
upgradeLimitEnabled3 := aaMainUI.Add("CheckBox", "x1210 y205 w15 h15", "")
upgradeLimitEnabled4 := aaMainUI.Add("CheckBox", "x1210 y255 w15 h15", "")
upgradeLimitEnabled5 := aaMainUI.Add("CheckBox", "x1210 y305 w15 h15", "")
upgradeLimitEnabled6 := aaMainUI.Add("CheckBox", "x1210 y355 w15 h15", "")

ChallengeEnabled1 := aaMainUI.Add("CheckBox", "x818 y105 w15 h15 Hidden", "")
ChallengeEnabled2 := aaMainUI.Add("CheckBox", "x818 y155 w15 h15 Hidden", "")
ChallengeEnabled3 := aaMainUI.Add("CheckBox", "x818 y205 w15 h15 Hidden", "")
ChallengeEnabled4 := aaMainUI.Add("CheckBox", "x818 y255 w15 h15 Hidden", "")
ChallengeEnabled5 := aaMainUI.Add("CheckBox", "x818 y305 w15 h15 Hidden", "")
ChallengeEnabled6 := aaMainUI.Add("CheckBox", "x818 y355 w15 h15 Hidden", "")

challengeUpgradeEnabled1 := aaMainUI.Add("CheckBox", "x1070 y105 w15 h15 Hidden", "")
challengeUpgradeEnabled2 := aaMainUI.Add("CheckBox", "x1070 y155 w15 h15 Hidden", "")
challengeUpgradeEnabled3 := aaMainUI.Add("CheckBox", "x1070 y205 w15 h15 Hidden", "")
challengeUpgradeEnabled4 := aaMainUI.Add("CheckBox", "x1070 y255 w15 h15 Hidden", "")
challengeUpgradeEnabled5 := aaMainUI.Add("CheckBox", "x1070 y305 w15 h15 Hidden", "")
challengeUpgradeEnabled6 := aaMainUI.Add("CheckBox", "x1070 y355 w15 h15 Hidden", "")

challengeUpgradeLimitEnabled1 := aaMainUI.Add("CheckBox", "x1210 y105 w15 h15 Hidden", "")
challengeUpgradeLimitEnabled2 := aaMainUI.Add("CheckBox", "x1210 y155 w15 h15 Hidden", "")
challengeUpgradeLimitEnabled3 := aaMainUI.Add("CheckBox", "x1210 y205 w15 h15 Hidden", "")
challengeUpgradeLimitEnabled4 := aaMainUI.Add("CheckBox", "x1210 y255 w15 h15 Hidden", "")
challengeUpgradeLimitEnabled5 := aaMainUI.Add("CheckBox", "x1210 y305 w15 h15 Hidden", "")
challengeUpgradeLimitEnabled6 := aaMainUI.Add("CheckBox", "x1210 y355 w15 h15 Hidden", "")

ContractEnabled1 := aaMainUI.Add("CheckBox", "x818 y105 w15 h15 Hidden", "")
ContractEnabled2 := aaMainUI.Add("CheckBox", "x818 y155 w15 h15 Hidden", "")
ContractEnabled3 := aaMainUI.Add("CheckBox", "x818 y205 w15 h15 Hidden", "")
ContractEnabled4 := aaMainUI.Add("CheckBox", "x818 y255 w15 h15 Hidden", "")
ContractEnabled5 := aaMainUI.Add("CheckBox", "x818 y305 w15 h15 Hidden", "")
ContractEnabled6 := aaMainUI.Add("CheckBox", "x818 y355 w15 h15 Hidden", "")

contractUpgradeEnabled1 := aaMainUI.Add("CheckBox", "x1070 y105 w15 h15 Hidden", "")
contractUpgradeEnabled2 := aaMainUI.Add("CheckBox", "x1070 y155 w15 h15 Hidden", "")
contractUpgradeEnabled3 := aaMainUI.Add("CheckBox", "x1070 y205 w15 h15 Hidden", "")
contractUpgradeEnabled4 := aaMainUI.Add("CheckBox", "x1070 y255 w15 h15 Hidden", "")
contractUpgradeEnabled5 := aaMainUI.Add("CheckBox", "x1070 y305 w15 h15 Hidden", "")
contractUpgradeEnabled6 := aaMainUI.Add("CheckBox", "x1070 y355 w15 h15 Hidden", "")

contractUpgradeLimitEnabled1 := aaMainUI.Add("CheckBox", "x1210 y105 w15 h15 Hidden", "")
contractUpgradeLimitEnabled2 := aaMainUI.Add("CheckBox", "x1210 y155 w15 h15 Hidden", "")
contractUpgradeLimitEnabled3 := aaMainUI.Add("CheckBox", "x1210 y205 w15 h15 Hidden", "")
contractUpgradeLimitEnabled4 := aaMainUI.Add("CheckBox", "x1210 y255 w15 h15 Hidden", "")
contractUpgradeLimitEnabled5 := aaMainUI.Add("CheckBox", "x1210 y305 w15 h15 Hidden", "")
contractUpgradeLimitEnabled6 := aaMainUI.Add("CheckBox", "x1210 y355 w15 h15 Hidden", "")

DungeonEnabled1 := aaMainUI.Add("CheckBox", "x818 y105 w15 h15 Hidden", "")
DungeonEnabled2 := aaMainUI.Add("CheckBox", "x818 y155 w15 h15 Hidden", "")
DungeonEnabled3 := aaMainUI.Add("CheckBox", "x818 y205 w15 h15 Hidden", "")
DungeonEnabled4 := aaMainUI.Add("CheckBox", "x818 y255 w15 h15 Hidden", "")
DungeonEnabled5 := aaMainUI.Add("CheckBox", "x818 y305 w15 h15 Hidden", "")
DungeonEnabled6 := aaMainUI.Add("CheckBox", "x818 y355 w15 h15 Hidden", "")

dungeonUpgradeEnabled1 := aaMainUI.Add("CheckBox", "x1070 y105 w15 h15 Hidden", "")
dungeonUpgradeEnabled2 := aaMainUI.Add("CheckBox", "x1070 y155 w15 h15 Hidden", "")
dungeonUpgradeEnabled3 := aaMainUI.Add("CheckBox", "x1070 y205 w15 h15 Hidden", "")
dungeonUpgradeEnabled4 := aaMainUI.Add("CheckBox", "x1070 y255 w15 h15 Hidden", "")
dungeonUpgradeEnabled5 := aaMainUI.Add("CheckBox", "x1070 y305 w15 h15 Hidden", "")
dungeonUpgradeEnabled6 := aaMainUI.Add("CheckBox", "x1070 y355 w15 h15 Hidden", "")

dungeonUpgradeLimitEnabled1 := aaMainUI.Add("CheckBox", "x1210 y105 w15 h15 Hidden", "")
dungeonUpgradeLimitEnabled2 := aaMainUI.Add("CheckBox", "x1210 y155 w15 h15 Hidden", "")
dungeonUpgradeLimitEnabled3 := aaMainUI.Add("CheckBox", "x1210 y205 w15 h15 Hidden", "")
dungeonUpgradeLimitEnabled4 := aaMainUI.Add("CheckBox", "x1210 y255 w15 h15 Hidden", "")
dungeonUpgradeLimitEnabled5 := aaMainUI.Add("CheckBox", "x1210 y305 w15 h15 Hidden", "")
dungeonUpgradeLimitEnabled6 := aaMainUI.Add("CheckBox", "x1210 y355 w15 h15 Hidden", "")

RaidEnabled1 := aaMainUI.Add("CheckBox", "x818 y105 w15 h15 Hidden", "")
RaidEnabled2 := aaMainUI.Add("CheckBox", "x818 y155 w15 h15 Hidden", "")
RaidEnabled3 := aaMainUI.Add("CheckBox", "x818 y205 w15 h15 Hidden", "")
RaidEnabled4 := aaMainUI.Add("CheckBox", "x818 y255 w15 h15 Hidden", "")
RaidEnabled5 := aaMainUI.Add("CheckBox", "x818 y305 w15 h15 Hidden", "")
RaidEnabled6 := aaMainUI.Add("CheckBox", "x818 y355 w15 h15 Hidden", "")

raidUpgradeEnabled1 := aaMainUI.Add("CheckBox", "x1070 y105 w15 h15 Hidden", "")
raidUpgradeEnabled2 := aaMainUI.Add("CheckBox", "x1070 y155 w15 h15 Hidden", "")
raidUpgradeEnabled3 := aaMainUI.Add("CheckBox", "x1070 y205 w15 h15 Hidden", "")
raidUpgradeEnabled4 := aaMainUI.Add("CheckBox", "x1070 y255 w15 h15 Hidden", "")
raidUpgradeEnabled5 := aaMainUI.Add("CheckBox", "x1070 y305 w15 h15 Hidden", "")
raidUpgradeEnabled6 := aaMainUI.Add("CheckBox", "x1070 y355 w15 h15 Hidden", "")

raidUpgradeLimitEnabled1 := aaMainUI.Add("CheckBox", "x1210 y105 w15 h15 Hidden", "")
raidUpgradeLimitEnabled2 := aaMainUI.Add("CheckBox", "x1210 y155 w15 h15 Hidden", "")
raidUpgradeLimitEnabled3 := aaMainUI.Add("CheckBox", "x1210 y205 w15 h15 Hidden", "")
raidUpgradeLimitEnabled4 := aaMainUI.Add("CheckBox", "x1210 y255 w15 h15 Hidden", "")
raidUpgradeLimitEnabled5 := aaMainUI.Add("CheckBox", "x1210 y305 w15 h15 Hidden", "")
raidUpgradeLimitEnabled6 := aaMainUI.Add("CheckBox", "x1210 y355 w15 h15 Hidden", "")

EventEnabled1 := aaMainUI.Add("CheckBox", "x818 y105 w15 h15 Hidden", "")
EventEnabled2 := aaMainUI.Add("CheckBox", "x818 y155 w15 h15 Hidden", "")
EventEnabled3 := aaMainUI.Add("CheckBox", "x818 y205 w15 h15 Hidden", "")
EventEnabled4 := aaMainUI.Add("CheckBox", "x818 y255 w15 h15 Hidden", "")
EventEnabled5 := aaMainUI.Add("CheckBox", "x818 y305 w15 h15 Hidden", "")
EventEnabled6 := aaMainUI.Add("CheckBox", "x818 y355 w15 h15 Hidden", "")
SummerEnabled1 := aaMainUI.Add("CheckBox", "x818 y105 w15 h15 Hidden", "")
SummerEnabled2 := aaMainUI.Add("CheckBox", "x818 y155 w15 h15 Hidden", "")
SummerEnabled3 := aaMainUI.Add("CheckBox", "x818 y205 w15 h15 Hidden", "")
SummerEnabled4 := aaMainUI.Add("CheckBox", "x818 y255 w15 h15 Hidden", "")
SummerEnabled5 := aaMainUI.Add("CheckBox", "x818 y305 w15 h15 Hidden", "")
SummerEnabled6 := aaMainUI.Add("CheckBox", "x818 y355 w15 h15 Hidden", "")

eventUpgradeEnabled1 := aaMainUI.Add("CheckBox", "x1070 y105 w15 h15 Hidden", "")
eventUpgradeEnabled2 := aaMainUI.Add("CheckBox", "x1070 y155 w15 h15 Hidden", "")
eventUpgradeEnabled3 := aaMainUI.Add("CheckBox", "x1070 y205 w15 h15 Hidden", "")
eventUpgradeEnabled4 := aaMainUI.Add("CheckBox", "x1070 y255 w15 h15 Hidden", "")
eventUpgradeEnabled5 := aaMainUI.Add("CheckBox", "x1070 y305 w15 h15 Hidden", "")
eventUpgradeEnabled6 := aaMainUI.Add("CheckBox", "x1070 y355 w15 h15 Hidden", "")
summerUpgradeEnabled1 := aaMainUI.Add("CheckBox", "x1070 y105 w15 h15 Hidden", "")
summerUpgradeEnabled2 := aaMainUI.Add("CheckBox", "x1070 y155 w15 h15 Hidden", "")
summerUpgradeEnabled3 := aaMainUI.Add("CheckBox", "x1070 y205 w15 h15 Hidden", "")
summerUpgradeEnabled4 := aaMainUI.Add("CheckBox", "x1070 y255 w15 h15 Hidden", "")
summerUpgradeEnabled5 := aaMainUI.Add("CheckBox", "x1070 y305 w15 h15 Hidden", "")
summerUpgradeEnabled6 := aaMainUI.Add("CheckBox", "x1070 y355 w15 h15 Hidden", "")

eventUpgradeLimitEnabled1 := aaMainUI.Add("CheckBox", "x1210 y105 w15 h15 Hidden", "")
eventUpgradeLimitEnabled2 := aaMainUI.Add("CheckBox", "x1210 y155 w15 h15 Hidden", "")
eventUpgradeLimitEnabled3 := aaMainUI.Add("CheckBox", "x1210 y205 w15 h15 Hidden", "")
eventUpgradeLimitEnabled4 := aaMainUI.Add("CheckBox", "x1210 y255 w15 h15 Hidden", "")
eventUpgradeLimitEnabled5 := aaMainUI.Add("CheckBox", "x1210 y305 w15 h15 Hidden", "")
eventUpgradeLimitEnabled6 := aaMainUI.Add("CheckBox", "x1210 y355 w15 h15 Hidden", "")
summerUpgradeLimitEnabled1 := aaMainUI.Add("CheckBox", "x1210 y105 w15 h15 Hidden", "")
summerUpgradeLimitEnabled2 := aaMainUI.Add("CheckBox", "x1210 y155 w15 h15 Hidden", "")
summerUpgradeLimitEnabled3 := aaMainUI.Add("CheckBox", "x1210 y205 w15 h15 Hidden", "")
summerUpgradeLimitEnabled4 := aaMainUI.Add("CheckBox", "x1210 y255 w15 h15 Hidden", "")
summerUpgradeLimitEnabled5 := aaMainUI.Add("CheckBox", "x1210 y305 w15 h15 Hidden", "")
summerUpgradeLimitEnabled6 := aaMainUI.Add("CheckBox", "x1210 y355 w15 h15 Hidden", "")


aaMainUI.SetFont("s8 c" uiTheme[6])

; Mode selection dropdown
PlacementSelection.OnEvent("Change", ToggleMode)

; Placement dropdowns
Placement1 := aaMainUI.Add("DropDownList", "x908 y105 w60 h180 Choose1 +Center", ["1","2","3","4","5","6"])
Placement2 := aaMainUI.Add("DropDownList", "x908 y155 w60 h180 Choose1 +Center", ["1","2","3","4","5","6"])
Placement3 := aaMainUI.Add("DropDownList", "x908 y205 w60 h180 Choose1 +Center", ["1","2","3","4","5","6"])
Placement4 := aaMainUI.Add("DropDownList", "x908 y255 w60 h180 Choose1 +Center", ["1","2","3","4","5","6"])
Placement5 := aaMainUI.Add("DropDownList", "x908 y305 w60 h180 Choose1 +Center", ["1","2","3","4","5","6"])
Placement6 := aaMainUI.Add("DropDownList", "x908 y355 w60 h180 Choose1 +Center", ["1","2","3","4","5","6"])

Priority1 := aaMainUI.Add("DropDownList", "x990 y105 w60 h180 Choose1 +Center", ["1","2","3","4","5","6"])
Priority2 := aaMainUI.Add("DropDownList", "x990 y155 w60 h180 Choose1 +Center", ["1","2","3","4","5","6"])
Priority3 := aaMainUI.Add("DropDownList", "x990 y205 w60 h180 Choose1 +Center", ["1","2","3","4","5","6"])
Priority4 := aaMainUI.Add("DropDownList", "x990 y255 w60 h180 Choose1 +Center", ["1","2","3","4","5","6"])
Priority5 := aaMainUI.Add("DropDownList", "x990 y305 w60 h180 Choose1 +Center", ["1","2","3","4","5","6"])
Priority6 := aaMainUI.Add("DropDownList", "x990 y355 w60 h180 Choose1 +Center", ["1","2","3","4","5","6"])

; Upgrade Limit
UpgradeLimit1 := aaMainUI.Add("DropDownList", "x1290 y105 w60 h180 Choose1 +Center", ["0","1","2","3","4","5","6","7","8","9","DontPick"])
UpgradeLimit2 := aaMainUI.Add("DropDownList", "x1290 y155 w60 h180 Choose1 +Center", ["0","1","2","3","4","5","6","7","8","9","DontPick"])
UpgradeLimit3 := aaMainUI.Add("DropDownList", "x1290 y205 w60 h180 Choose1 +Center", ["0","1","2","3","4","5","6","7","8","9","DontPick"])
UpgradeLimit4 := aaMainUI.Add("DropDownList", "x1290 y255 w60 h180 Choose1 +Center", ["0","1","2","3","4","5","6","7","8","9","DontPick"])
UpgradeLimit5 := aaMainUI.Add("DropDownList", "x1290 y305 w60 h180 Choose1 +Center", ["0","1","2","3","4","5","6","7","8","9","DontPick"])
UpgradeLimit6 := aaMainUI.Add("DropDownList", "x1290 y355 w60 h180 Choose1 +Center", ["0","1","2","3","4","5","6","7","8","9","DontPick"])

ChallengePlacement1 := aaMainUI.Add("DropDownList", "x908 y105 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
ChallengePlacement2 := aaMainUI.Add("DropDownList", "x908 y155 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
ChallengePlacement3 := aaMainUI.Add("DropDownList", "x908 y205 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
ChallengePlacement4 := aaMainUI.Add("DropDownList", "x908 y255 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
ChallengePlacement5 := aaMainUI.Add("DropDownList", "x908 y305 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
ChallengePlacement6 := aaMainUI.Add("DropDownList", "x908 y355 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])

ChallengePriority1 := aaMainUI.Add("DropDownList", "x990 y105 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
ChallengePriority2 := aaMainUI.Add("DropDownList", "x990 y155 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
ChallengePriority3 := aaMainUI.Add("DropDownList", "x990 y205 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
ChallengePriority4 := aaMainUI.Add("DropDownList", "x990 y255 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
ChallengePriority5 := aaMainUI.Add("DropDownList", "x990 y305 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
ChallengePriority6 := aaMainUI.Add("DropDownList", "x990 y355 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])

ChallengeUpgradeLimit1 := aaMainUI.Add("DropDownList", "x1290 y105 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
ChallengeUpgradeLimit2 := aaMainUI.Add("DropDownList", "x1290 y155 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
ChallengeUpgradeLimit3 := aaMainUI.Add("DropDownList", "x1290 y205 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
ChallengeUpgradeLimit4 := aaMainUI.Add("DropDownList", "x1290 y255 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
ChallengeUpgradeLimit5 := aaMainUI.Add("DropDownList", "x1290 y305 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
ChallengeUpgradeLimit6 := aaMainUI.Add("DropDownList", "x1290 y355 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])

ContractPlacement1 := aaMainUI.Add("DropDownList", "x908 y105 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
ContractPlacement2 := aaMainUI.Add("DropDownList", "x908 y155 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
ContractPlacement3 := aaMainUI.Add("DropDownList", "x908 y205 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
ContractPlacement4 := aaMainUI.Add("DropDownList", "x908 y255 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
ContractPlacement5 := aaMainUI.Add("DropDownList", "x908 y305 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
ContractPlacement6 := aaMainUI.Add("DropDownList", "x908 y355 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])

ContractPriority1 := aaMainUI.Add("DropDownList", "x990 y105 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
ContractPriority2 := aaMainUI.Add("DropDownList", "x990 y155 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
ContractPriority3 := aaMainUI.Add("DropDownList", "x990 y205 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
ContractPriority4 := aaMainUI.Add("DropDownList", "x990 y255 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
ContractPriority5 := aaMainUI.Add("DropDownList", "x990 y305 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
ContractPriority6 := aaMainUI.Add("DropDownList", "x990 y355 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])

ContractUpgradeLimit1 := aaMainUI.Add("DropDownList", "x1290 y105 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
ContractUpgradeLimit2 := aaMainUI.Add("DropDownList", "x1290 y155 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
ContractUpgradeLimit3 := aaMainUI.Add("DropDownList", "x1290 y205 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
ContractUpgradeLimit4 := aaMainUI.Add("DropDownList", "x1290 y255 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
ContractUpgradeLimit5 := aaMainUI.Add("DropDownList", "x1290 y305 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
ContractUpgradeLimit6 := aaMainUI.Add("DropDownList", "x1290 y355 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])

DungeonPlacement1 := aaMainUI.Add("DropDownList", "x908 y105 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
DungeonPlacement2 := aaMainUI.Add("DropDownList", "x908 y155 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
DungeonPlacement3 := aaMainUI.Add("DropDownList", "x908 y205 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
DungeonPlacement4 := aaMainUI.Add("DropDownList", "x908 y255 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
DungeonPlacement5 := aaMainUI.Add("DropDownList", "x908 y305 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
DungeonPlacement6 := aaMainUI.Add("DropDownList", "x908 y355 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])

DungeonPriority1 := aaMainUI.Add("DropDownList", "x990 y105 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
DungeonPriority2 := aaMainUI.Add("DropDownList", "x990 y155 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
DungeonPriority3 := aaMainUI.Add("DropDownList", "x990 y205 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
DungeonPriority4 := aaMainUI.Add("DropDownList", "x990 y255 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
DungeonPriority5 := aaMainUI.Add("DropDownList", "x990 y305 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
DungeonPriority6 := aaMainUI.Add("DropDownList", "x990 y355 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])

DungeonUpgradeLimit1 := aaMainUI.Add("DropDownList", "x1290 y105 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
DungeonUpgradeLimit2 := aaMainUI.Add("DropDownList", "x1290 y155 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
DungeonUpgradeLimit3 := aaMainUI.Add("DropDownList", "x1290 y205 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
DungeonUpgradeLimit4 := aaMainUI.Add("DropDownList", "x1290 y255 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
DungeonUpgradeLimit5 := aaMainUI.Add("DropDownList", "x1290 y305 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
DungeonUpgradeLimit6 := aaMainUI.Add("DropDownList", "x1290 y355 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])

RaidPlacement1 := aaMainUI.Add("DropDownList", "x908 y105 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
RaidPlacement2 := aaMainUI.Add("DropDownList", "x908 y155 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
RaidPlacement3 := aaMainUI.Add("DropDownList", "x908 y205 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
RaidPlacement4 := aaMainUI.Add("DropDownList", "x908 y255 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
RaidPlacement5 := aaMainUI.Add("DropDownList", "x908 y305 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
RaidPlacement6 := aaMainUI.Add("DropDownList", "x908 y355 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])

RaidPriority1 := aaMainUI.Add("DropDownList", "x990 y105 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
RaidPriority2 := aaMainUI.Add("DropDownList", "x990 y155 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
RaidPriority3 := aaMainUI.Add("DropDownList", "x990 y205 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
RaidPriority4 := aaMainUI.Add("DropDownList", "x990 y255 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
RaidPriority5 := aaMainUI.Add("DropDownList", "x990 y305 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
RaidPriority6 := aaMainUI.Add("DropDownList", "x990 y355 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])

RaidUpgradeLimit1 := aaMainUI.Add("DropDownList", "x1290 y105 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
RaidUpgradeLimit2 := aaMainUI.Add("DropDownList", "x1290 y155 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
RaidUpgradeLimit3 := aaMainUI.Add("DropDownList", "x1290 y205 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
RaidUpgradeLimit4 := aaMainUI.Add("DropDownList", "x1290 y255 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
RaidUpgradeLimit5 := aaMainUI.Add("DropDownList", "x1290 y305 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
RaidUpgradeLimit6 := aaMainUI.Add("DropDownList", "x1290 y355 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])

EventPlacement1 := aaMainUI.Add("DropDownList", "x908 y105 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
EventPlacement2 := aaMainUI.Add("DropDownList", "x908 y155 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
EventPlacement3 := aaMainUI.Add("DropDownList", "x908 y205 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
EventPlacement4 := aaMainUI.Add("DropDownList", "x908 y255 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
EventPlacement5 := aaMainUI.Add("DropDownList", "x908 y305 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
EventPlacement6 := aaMainUI.Add("DropDownList", "x908 y355 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
SummerPlacement1 := aaMainUI.Add("DropDownList", "x908 y105 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
SummerPlacement2 := aaMainUI.Add("DropDownList", "x908 y155 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
SummerPlacement3 := aaMainUI.Add("DropDownList", "x908 y205 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
SummerPlacement4 := aaMainUI.Add("DropDownList", "x908 y255 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
SummerPlacement5 := aaMainUI.Add("DropDownList", "x908 y305 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
SummerPlacement6 := aaMainUI.Add("DropDownList", "x908 y355 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])

EventPriority1 := aaMainUI.Add("DropDownList", "x990 y105 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
EventPriority2 := aaMainUI.Add("DropDownList", "x990 y155 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
EventPriority3 := aaMainUI.Add("DropDownList", "x990 y205 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
EventPriority4 := aaMainUI.Add("DropDownList", "x990 y255 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
EventPriority5 := aaMainUI.Add("DropDownList", "x990 y305 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
EventPriority6 := aaMainUI.Add("DropDownList", "x990 y355 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
SummerPriority1 := aaMainUI.Add("DropDownList", "x990 y105 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
SummerPriority2 := aaMainUI.Add("DropDownList", "x990 y155 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
SummerPriority3 := aaMainUI.Add("DropDownList", "x990 y205 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
SummerPriority4 := aaMainUI.Add("DropDownList", "x990 y255 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
SummerPriority5 := aaMainUI.Add("DropDownList", "x990 y305 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])
SummerPriority6 := aaMainUI.Add("DropDownList", "x990 y355 w60 h180 Choose1 +Center Hidden", ["1","2","3","4","5","6"])

EventUpgradeLimit1 := aaMainUI.Add("DropDownList", "x1290 y105 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
EventUpgradeLimit2 := aaMainUI.Add("DropDownList", "x1290 y155 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
EventUpgradeLimit3 := aaMainUI.Add("DropDownList", "x1290 y205 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
EventUpgradeLimit4 := aaMainUI.Add("DropDownList", "x1290 y255 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
EventUpgradeLimit5 := aaMainUI.Add("DropDownList", "x1290 y305 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
EventUpgradeLimit6 := aaMainUI.Add("DropDownList", "x1290 y355 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
SummerUpgradeLimit1 := aaMainUI.Add("DropDownList", "x1290 y105 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
SummerUpgradeLimit2 := aaMainUI.Add("DropDownList", "x1290 y155 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
SummerUpgradeLimit3 := aaMainUI.Add("DropDownList", "x1290 y205 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
SummerUpgradeLimit4 := aaMainUI.Add("DropDownList", "x1290 y255 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
SummerUpgradeLimit5 := aaMainUI.Add("DropDownList", "x1290 y305 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])
SummerUpgradeLimit6 := aaMainUI.Add("DropDownList", "x1290 y355 w60 h180 Choose1 +Center Hidden", ["0","1","2","3","4","5","6","7","8","9","10"])


ToggleMode(*) {
    mode := PlacementSelection.Text
    Loop 6 {
        ; Hide all placements and priorities by default
        Enabled%A_Index%.Visible := false
        Placement%A_Index%.Visible := false
        Priority%A_Index%.Visible := false
        upgradeEnabled%A_Index%.Visible := false
        upgradeLimit%A_Index%.Visible := false
        upgradeLimitEnabled%A_Index%.Visible := false

        ChallengeEnabled%A_Index%.Visible := false
        ChallengePlacement%A_Index%.Visible := false
        ChallengePriority%A_Index%.Visible := false
        challengeUpgradeEnabled%A_Index%.Visible := false
        challengeUpgradeLimit%A_Index%.Visible := false
        challengeUpgradeLimitEnabled%A_Index%.Visible := false

        ContractEnabled%A_Index%.Visible := false
        ContractPlacement%A_Index%.Visible := false
        ContractPriority%A_Index%.Visible := false
        contractUpgradeEnabled%A_Index%.Visible := false
        contractUpgradeLimit%A_Index%.Visible := false
        contractUpgradeLimitEnabled%A_Index%.Visible := false

        DungeonEnabled%A_Index%.Visible := false
        DungeonPlacement%A_Index%.Visible := false
        DungeonPriority%A_Index%.Visible := false
        dungeonUpgradeEnabled%A_Index%.Visible := false
        dungeonUpgradeLimit%A_Index%.Visible := false
        dungeonUpgradeLimitEnabled%A_Index%.Visible := false

        RaidPlacement%A_Index%.Visible := false
        RaidPriority%A_Index%.Visible := false
        RaidEnabled%A_Index%.Visible := false
        raidUpgradeEnabled%A_Index%.Visible := false
        raidUpgradeLimit%A_Index%.Visible := false
        raidUpgradeLimitEnabled%A_Index%.Visible := false

        EventPlacement%A_Index%.Visible := false
        EventPriority%A_Index%.Visible := false
        EventEnabled%A_Index%.Visible := false
        EventUpgradeEnabled%A_Index%.Visible := false
        EventUpgradeLimit%A_Index%.Visible := false
        EventUpgradeLimitEnabled%A_Index%.Visible := false

        SummerPlacement%A_Index%.Visible := false   ; [Summer Hunt]
        SummerPriority%A_Index%.Visible := false
        SummerEnabled%A_Index%.Visible := false
        SummerUpgradeEnabled%A_Index%.Visible := false
        SummerUpgradeLimit%A_Index%.Visible := false
        SummerUpgradeLimitEnabled%A_Index%.Visible := false

        if (AA_ActivePanel != "")   ; [Settings panel] a panel is open - keep the unit controls hidden
            continue
        
        ; Add more modes as needed
        if (mode = "Default") {
            Enabled%A_Index%.Visible := true
            Placement%A_Index%.Visible := true
            Priority%A_Index%.Visible := true
            upgradeEnabled%A_Index%.Visible := true
            upgradeLimit%A_Index%.Visible := true
            upgradeLimitEnabled%A_Index%.Visible := true
        } else if (mode = "Challenge") {
            ChallengeEnabled%A_Index%.Visible := true
            ChallengePlacement%A_Index%.Visible := true
            ChallengePriority%A_Index%.Visible := true
            challengeUpgradeEnabled%A_Index%.Visible := true
            challengeUpgradeLimit%A_Index%.Visible := true
            challengeUpgradeLimitEnabled%A_Index%.Visible := true
        } else if (mode = "Contract") {
            ContractEnabled%A_Index%.Visible := true
            ContractPlacement%A_Index%.Visible := true
            ContractPriority%A_Index%.Visible := true
            contractUpgradeEnabled%A_Index%.Visible := true
            contractUpgradeLimit%A_Index%.Visible := true
            contractUpgradeLimitEnabled%A_Index%.Visible := true 
        } else if (mode = "Raid") {
            RaidEnabled%A_Index%.Visible := true
            RaidPlacement%A_Index%.Visible := true
            RaidPriority%A_Index%.Visible := true
            raidUpgradeEnabled%A_Index%.Visible := true
            raidUpgradeLimit%A_Index%.Visible := true
            raidUpgradeLimitEnabled%A_Index%.Visible := true
        } else if (mode = "Fool's Hunt") {
            EventEnabled%A_Index%.Visible := true
            EventPlacement%A_Index%.Visible := true
            EventPriority%A_Index%.Visible := true
            EventUpgradeEnabled%A_Index%.Visible := true
            EventUpgradeLimit%A_Index%.Visible := true
            EventUpgradeLimitEnabled%A_Index%.Visible := true
        } else if (mode = "Summer Hunt") {   ; [Summer Hunt] its own unit settings
            SummerEnabled%A_Index%.Visible := true
            SummerPlacement%A_Index%.Visible := true
            SummerPriority%A_Index%.Visible := true
            SummerUpgradeEnabled%A_Index%.Visible := true
            SummerUpgradeLimit%A_Index%.Visible := true
            SummerUpgradeLimitEnabled%A_Index%.Visible := true
        } else if (mode = "Dungeon") {
            DungeonEnabled%A_Index%.Visible := true
            DungeonPlacement%A_Index%.Visible := true
            DungeonPriority%A_Index%.Visible := true
            dungeonUpgradeEnabled%A_Index%.Visible := true
            dungeonUpgradeLimit%A_Index%.Visible := true
            dungeonUpgradeLimitEnabled%A_Index%.Visible := true
        }
        ; Add more modes as needed
    }
}
AA_BuildSettingsPanel()  ; [Settings panel] created hidden; the Settings button shows it
CM_BuildPanel()          ; [Custom movement] panel, created hidden; the Custom Map Movement button shows it
CP_BuildPanel()          ; [Custom placement] panel, created hidden; the Custom Placement tab shows it
DT_Init()                ; [Detection tester] read pattern names from Image.ahk, apply saved overrides
AA_BuildDebugPanel()     ; [Debug panel] created hidden; the Debug button shows it
Sched_BuildPanel()       ; [Scheduler panel] created hidden; the Scheduler button shows it
AA_BuildAdvancedPanel()  ; [Advanced panel] dungeon route / curses / shrines, created hidden
AA_BuildGuidePanel()     ; [Guide panel] setup guide, created hidden; the Guide button shows it
CardPick_BuildPanel()    ; [Card picker] Fool's Hunt card priority panel, created hidden; Card Prio opens it
AA_BuildStatsBox()       ; [Stats] Wins / Losses / Win % box, bottom left
LayoutUnitCards()
readInSettings()
AA_LoadPanelSettings()   ; [Settings panel] fill it from the settings files
AA_StyleFinish()         ; [Modern GUI] switches, dark inputs, status bar, tooltips, hover, rounded corners
; [Banner] your own picture across the bottom of the console (Images\banner.png, 525 x 48)
if FileExist(A_ScriptDir "\Images\banner.png") {
    global BannerPic := aaMainUI.Add("Picture", "x830 y646 w525 h48", A_ScriptDir "\Images\banner.png")
    process6.Visible := false, process7.Visible := false   ; [Polish] the banner sits where these two lines were
}
ST_Build(aaMainUI)   ; [Polish] live stats card
aaMainUI.Show("w1366 h700")
CenterMacroWindow()   ; Window follow was: WinMove(0, 0,,, "ahk_id " aaMainUIHwnd)
SetupDraggableGui()   ; Window follow drag the GUI by its background, Roblox follows
forceRobloxSize()  ; Initial force size and position
;------UNIT CONFIGURATION ;------UNIT CONFIGURATION ;------UNIT CONFIGURATION ;------UNIT CONFIGURATION ;------UNIT CONFIGURATION ;------UNIT CONFIGURATION ;------UNIT CONFIGURATION
;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS;------FUNCTIONS

;Process text
AddToLog(current) { 
    global process1, process2, process3, process4, process5, process6, process7, currentOutputFile, lastlog

    ; Remove arrow from all lines first
    process7.Value := StrReplace(process6.Value, "➤ ", "")
    process6.Value := StrReplace(process5.Value, "➤ ", "")
    process5.Value := StrReplace(process4.Value, "➤ ", "")
    process4.Value := StrReplace(process3.Value, "➤ ", "")
    process3.Value := StrReplace(process2.Value, "➤ ", "")
    process2.Value := StrReplace(process1.Value, "➤ ", "")
    
    ; Add arrow only to newest process ([Modern GUI] + time; the log file is unchanged)
    process1.Value := "➤ " FormatTime(, "HH:mm:ss") "  " current
    try WM_OnLog(current)   ; [Watch mode]
    
    elapsedTime := getElapsedTime()
    sleep 50
    ; [Fix] the log can be busy for a moment (another program reading it - e.g. Claude checking it in watch
    ; mode). Try a few times, and never stop the macro over a log line.
    loop 5 {
        try {
            FileAppend(current . " " . elapsedTime . "`n", currentOutputFile)
            break
        } catch {
            Sleep(60)
        }
    }

    ; Add webhook logging
    lastlog := current
    ; setting is read from disk once and cached (refreshed when webhook settings are saved)
    global SendActivityLogsCache
    if !IsSet(SendActivityLogsCache) || SendActivityLogsCache = "" {
        SendActivityLogsCache := FileExist("Settings\SendActivityLogs.txt") ? FileRead("Settings\SendActivityLogs.txt", "UTF-8") : "0"
    }
    if (SendActivityLogsCache = "1") {
        WebhookLog()
    }
}

;Timer
getElapsedTime() {
    global StartTime
    ElapsedTime := A_TickCount - StartTime
    Minutes := Mod(ElapsedTime // 60000, 60)  
    Seconds := Mod(ElapsedTime // 1000, 60)
    return Format("{:02}:{:02}", Minutes, Seconds)
}

;Basically the code to move roblox, below

sizeDown() {
    global rblxID

    if !WinExist(rblxID)
        return

    ; [Windowed] Roblox always ends up in windowed mode: fullscreen, maximized or minimized
    ; is switched back to a normal window before it is resized (was: one F11 sent to whatever
    ; window was active, only when fullscreen on the main monitor)
    RobloxEnsureWindowed()

    try {
        WinGetPos(&X, &Y, &OutWidth, &OutHeight, rblxID)
    } catch {
        AddToLog("Failed to get window position.")
        return ; Safely exit if the window doesn't exist or can't get position
    }

    ; Force the window size and retry if needed
    Loop 3 {
        try {
            WinMove(X, Y, targetWidth, targetHeight, rblxID)
            Sleep(100)
            WinGetPos(&X, &Y, &OutWidth, &OutHeight, rblxID)
            if (OutWidth == targetWidth && OutHeight == targetHeight)
                break
        } catch {
            AddToLog("Failed to get window position.")
            break ; Stop trying if something goes wrong
        }
    }
}
; [Windowed] true when Roblox covers the whole monitor it is on (fullscreen)
RobloxIsFullscreen() {
    global rblxID
    WinGetPos(&x, &y, &w, &h, rblxID)
    cx := x + w // 2, cy := y + h // 2
    loop MonitorGetCount() {
        MonitorGet(A_Index, &ml, &mt, &mr, &mb)
        if (cx >= ml && cx < mr && cy >= mt && cy < mb)
            return (w >= mr - ml && h >= mb - mt)
    }
    return (w >= A_ScreenWidth && h >= A_ScreenHeight)
}

; [Windowed] Puts Roblox in windowed mode: restores a minimized / maximized window and
; leaves fullscreen with F11 (sent to Roblox itself, checked again after each try).
RobloxEnsureWindowed() {
    global rblxID
    try {
        if (WinGetMinMax(rblxID) != 0) {     ; -1 minimized, 1 maximized
            WinRestore(rblxID)
            Sleep(300)
        }
        loop 3 {
            if !RobloxIsFullscreen()
                return true
            AddToLog("Roblox is fullscreen - switching to windowed mode")
            WinActivate(rblxID)
            WinWaitActive(rblxID, , 2)
            Send("{F11}")
            Sleep(1000)
        }
        AddToLog("Could not switch Roblox to windowed mode - press F11 in Roblox")
    }
    return false
}

moveRobloxWindow() {
    global aaMainUIHwnd, offsetX, offsetY, rblxID
    
    if !WinExist(rblxID) {
        AddToLog("Waiting for Roblox window...")
        return
    }

    ; First ensure correct size
    sizeDown()
    
    ; Then move relative to main UI
    WinGetPos(&x, &y, &w, &h, aaMainUIHwnd)
    WinMove(x + offsetX, y + offsetY,,, rblxID)
    WinActivate(rblxID)
}

forceRobloxSize() {
    global rblxID
    
    if (!WinExist(rblxID) && DM_On()) {   ; [Design mode] don't wait a minute for Roblox while editing the look
        AddToLog("[Design] Roblox isn't open - skipping the window check")
        return
    }
    if !WinExist(rblxID) {
        checkCount := 0
        While !WinExist(rblxID) {
            Sleep(5000)
            if(checkCount >= 5) {
                AddToLog("Attempting to locate the Roblox window")
            } 
            checkCount += 1
            if (checkCount > 12) { ; Give up after 1 minute
                AddToLog("Could not find Roblox window")
                return
            }
        }
        AddToLog("Found Roblox window")
    }

    WinActivate(rblxID)
    sizeDown()
    moveRobloxWindow()
}

; Function to periodically check window size
checkRobloxSize() {
    global rblxID
    if WinExist(rblxID) {
        WinGetPos(&X, &Y, &OutWidth, &OutHeight, rblxID)
        if (OutWidth != targetWidth || OutHeight != targetHeight) {
            sizeDown()
            moveRobloxWindow()
        }
    }
}
;Basically the code to move roblox, Above

checkSizeTimer() {
    if (WinExist("ahk_exe RobloxPlayerBeta.exe")) {
        WinGetPos(&X, &Y, &OutWidth, &OutHeight, "ahk_exe RobloxPlayerBeta.exe")
        if (OutWidth != 816 || OutHeight != 638) {
            AddToLog("Fixing Roblox window size")
            moveRobloxWindow()
        }
    }
}

; Function to toggle visibility of the checkboxes
ToggleDungeonCheckboxes() {
    global SaveChestsBox, StopAfterDefeat, DenyShrines, EditRoute, PrioritiseFutureRareChests
    
    ; Check the current visibility state and toggle
    currentState := SaveChestsBox.Visible  ; Use the visibility of the first checkbox to determine the state
    newVisibility := !currentState  ; Toggle visibility

    ; Set the visibility for all checkboxes
    SaveChestsBox.Visible := newVisibility
    StopAfterDefeat.Visible := newVisibility
    DenyShrines.Visible := newVisibility
    EditRoute.Visible := newVisibility   ; [Advanced panel] the Advanced Settings button
    PrioritiseFutureRareChests.Visible := newVisibility
}

ToggleSettingsVisibility() {
    global PlacementPatternText
    global PlacementPatternDropdown
    global PlaceSpeedText
    global PlaceSpeed
    global PlacementSelectionText
    global PlacementSelection
    global LobbySleepText
    global LobbySleepTimer

    global FirstAdaptationText
    global FirstAdaptation
    global SecondAdaptationText
    global SecondAdaptation
    global FinalAdaptationText
    global FinalAdaptation
    global MahoragoModeText
    global MahoragoMode

    ; Check the current visibility state of the placement settings
    if (PlacementPatternText.Visible) {
        ; Hide placement settings
        PlacementPatternText.Visible := false
        PlacementPatternDropdown.Visible := false
        PlaceSpeedText.Visible := false
        PlaceSpeed.Visible := false
        PlacementSelectionText.Visible := false
        PlacementSelection.Visible := false
        LobbySleepText.Visible := false
        LobbySleepTimer.Visible := false
        
        ; Show adaptation settings
        FirstAdaptationText.Visible := true
        FirstAdaptation.Visible := true
        SecondAdaptationText.Visible := true
        SecondAdaptation.Visible := true
        FinalAdaptationText.Visible := true
        FinalAdaptation.Visible := true
        MahoragoModeText.Visible := true
        MahoragoMode.Visible := true
    } else {
        ; Hide adaptation settings
        FirstAdaptationText.Visible := false
        FirstAdaptation.Visible := false
        SecondAdaptationText.Visible := false
        SecondAdaptation.Visible := false
        FinalAdaptationText.Visible := false
        FinalAdaptation.Visible := false
        MahoragoModeText.Visible := false
        MahoragoMode.Visible := false
        
        ; Show placement settings
        PlacementPatternText.Visible := true
        PlacementPatternDropdown.Visible := true
        PlaceSpeedText.Visible := true
        PlaceSpeed.Visible := true
        PlacementSelectionText.Visible := true
        PlacementSelection.Visible := true
        LobbySleepText.Visible := true
        LobbySleepTimer.Visible := true
    }
}