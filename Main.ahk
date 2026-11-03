#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

SendMode "Event"
SetWorkingDir(A_ScriptDir)   ; [Fix] files like Settings\WebhookURL.txt are opened by relative path - when the
                             ; macro was started from elsewhere they weren't found ("No webhook configured")

#Include %A_ScriptDir%\Lib\Framework\MacroLoop.ahk
; [Framework] failsafes and timers (from Anime Guardians TimerManager pattern) - see Lib\Framework\FrameworkConfig.ahk
#Include %A_ScriptDir%\Lib\Framework\FrameworkConfig.ahk
#Include %A_ScriptDir%\Lib\Functions\Timers.ahk
#Include %A_ScriptDir%\Lib\Framework\Failsafe.ahk
#Include %A_ScriptDir%\Lib\Tools\WindowFollow.ahk
#Include %A_ScriptDir%\Lib\Scheduler.ahk
#Include %A_ScriptDir%\Lib\Tools\Image.ahk
#Include %A_ScriptDir%\Lib\Toggles.ahk
#Include %A_ScriptDir%\Lib\Modes\Winter\PriorityPicker.ahk
#Include %A_ScriptDir%\Lib\Modes\Dungeon\RoutePriorityPicker.ahk
#Include %A_ScriptDir%\Lib\Modes\Dungeon\CursePriorityPicker.ahk
#Include %A_ScriptDir%\Lib\Modes\Dungeon\ShrinePriorityPicker.ahk
#Include %A_ScriptDir%\Lib\Modes\Fools-Hunt\MapSkipper.ahk
#Include %A_ScriptDir%\Lib\Modes\Fools-Hunt\FoolCardPrio.ahk
#Include %A_ScriptDir%\Lib\ConfigCode.ahk
#Include %A_ScriptDir%\Lib\Game\CustomMovement.ahk   ; [Custom movement] before GUI.ahk so its settings exist when the GUI is built
#Include %A_ScriptDir%\Lib\Game\CustomPlacement.ahk  ; [Custom placement] your own unit spots per map (before GUI.ahk, like Custom movement)
#Include %A_ScriptDir%\Lib\Game\CardPicker.ahk       ; [Card picker] Fool's Hunt card picker + panel (before GUI.ahk)
#Include %A_ScriptDir%\Lib\Tools\DetectionTester.ahk   ; [Detection tester] before GUI.ahk (Debug panel; applies saved pattern overrides)
#Include %A_ScriptDir%\lib/GUI.ahk
#Include %A_ScriptDir%\lib/GameMango.ahk
; [Modularized] code moved out of GameMango.ahk / Functions.ahk (functions only - load position does not matter)
#Include %A_ScriptDir%\Lib\Tools\Utilities.ahk
#Include %A_ScriptDir%\Lib\Functions\Input.ahk
#Include %A_ScriptDir%\Lib\Functions\ScreenActions.ahk
#Include %A_ScriptDir%\Lib\Game\UnitPlacement.ahk
#Include %A_ScriptDir%\Lib\Game\Upgrading.ahk
#Include %A_ScriptDir%\Lib\Game\StageEvents.ahk
#Include %A_ScriptDir%\Lib\Game\LobbyNavigation.ahk
#Include %A_ScriptDir%\Lib\Game\MapDetection.ahk
#Include %A_ScriptDir%\Lib\Game\MapMovement.ahk
#Include %A_ScriptDir%\Lib\Game\TeamSwap.ahk   ; [Scheduler team swap] team coordinates + swap routine (functions only)
#Include %A_ScriptDir%\Lib\Modes\Contract.ahk
#Include %A_ScriptDir%\Lib\GuiEvents.ahk
#Include %A_ScriptDir%\lib/Config.ahk
#Include %A_ScriptDir%\lib/Modes/Fools-Hunt/MapConfig.ahk
#Include %A_ScriptDir%\lib\Modes\Winter\WinterConfig.ahk
#Include %A_ScriptDir%\lib/Modes/Dungeon/DungeonConfig.ahk
#Include %A_ScriptDir%\Lib\Modes\Dungeon\Dungeon_FutureRareChest.ahk
#Include %A_ScriptDir%\Lib\Modes\Portal.ahk
#Include %A_ScriptDir%\Lib\Modes\Winter\Winter2024.ahk
#Include %A_ScriptDir%\Lib\Modes\Fools-Hunt\FoolsHunt.ahk
#Include %A_ScriptDir%\Lib\Tools\FindText.ahk
#Include %A_ScriptDir%\Lib\OCR-main\Lib\OCR.ahk
#Include %A_ScriptDir%\Lib\Improved\FoolsHotbar.ahk
#Include %A_ScriptDir%\Lib\Improved\UnitTypes.ahk   ; [Unit types] F6: Ground / Hill / Hybrid per slot
#Include %A_ScriptDir%\Lib\Improved\SmartPlace.ahk   ; [Smart placement] reads the green/red placement map   ; [Hotbar check] Fool's Hunt own-units check
#Include %A_ScriptDir%\Lib\Improved\VisionHelper.ahk   ; [Python vision] fast placement map + RapidOCR
#Include %A_ScriptDir%\Lib\Improved\DesignMode.ahk   ; [Design mode] auto-reload + window picture while Claude edits the UI
#Include %A_ScriptDir%\Lib\Improved\SummerHunt.ahk   ; [Summer Hunt] text-based vote / cards / end screen
#Include %A_ScriptDir%\Lib\Improved\WatchMode.ahk   ; [Watch mode] F9: pictures + lobby reload for live fixes
#Include %A_ScriptDir%\Lib\Improved\StatsPanel.ahk   ; [Polish] live stats strip
#Include %A_ScriptDir%\Lib\Improved\RecordMode.ahk   ; [Record mode] F8: watch and record while you play
#Include %A_ScriptDir%\Lib\Improved\AutoUpdate.ahk   ; [Auto update] new code from GitHub at start-up (asks first)
#Include %A_ScriptDir%\Lib\PlacementLogics.ahk
#Include %A_ScriptDir%\lib/webhooksettings.ahk
;#Include %A_ScriptDir%\Lib\UpdateChecker.ahk

DM_Init()   ; [Design mode] (before the Roblox check, which waits for Roblox)
GetScreenInfoStartUp()
WM_Init()   ; [Watch mode]
AU_Start()   ; [Auto update] check GitHub for a newer version (Settings\AutoUpdate.txt: Ask/Auto/Off)
VH_Start()   ; [Python vision] start the helper (falls back silently if Python is missing)

;DEBUG SECTIOn




 /* 
 Fixes:
 FindText Issues:
 Dungeon{
 -all special room
 -bossroom
 -chestroom
 -shop
 -shrine
 }
 General{
 -CancelMode
 -Victory
 -Defeat
 -ReturntoLobby
 -Votestart
 }
 */ 
