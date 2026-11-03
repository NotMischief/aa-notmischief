#Requires AutoHotkey v2.0

; ============================================================================
;  FrameworkConfig.ahk  -  [Framework] failsafe and error-recovery settings
; ----------------------------------------------------------------------------
;  Edit the numbers below to tune the failsafes. Times are in milliseconds
;  (60000 = 1 minute). Set any timeout to 0 to switch that failsafe off.
;  Nothing here is saved by the GUI - these are plain script settings, like
;  Lib\Toggles.ahk.
;
;  Where each timeout is used (see the Obsidian note "Migration Plan"):
;    FW_EntranceTimeoutMs  - GameMango.ahk: ChallengeMode, StoryMode, LegendMode,
;                            RaidMode, InfinityCastleMode, FoolsEvent, CursedWombMode
;    FW_LoadTimeoutMs      - GameMango.ahk: CheckLoaded
;    FW_VoteTimeoutMs      - GameMango.ahk: StartedGame
;    FW_StageTimeoutMs     - armed in GameMango.ahk RestartStage; checked in
;                            Game\UnitPlacement.ahk PlacingUnits, PlaceFoolUnits;
;                            Game\Upgrading.ahk PostUpgradeChecks; GameMango.ahk MonitorStage.
;                            Not armed for Story "Infinity" or Winter Event.
;    FW_EndScreenTimeoutMs - GameMango.ahk: MonitorEndScreen; Modes\Contract.ahk: HandleContractEnd;
;                            Modes\Portal.ahk: HandlePortalReJoin (Solo/Creating only);
;                            Modes\Dungeon\Dungeon_FutureRareChest.ahk: MonitorDungeonEnd
;    FW_LobbyTimeoutMs     - GameMango.ahk: CheckLobby
;    FW_ReconnectTimeoutMs - GameMango.ahk: Reconnect (retry loop), RejoinPrivateServer
; ============================================================================

global FW_FailsafesEnabled   := true          ; master switch for all timeouts below

global FW_EntranceTimeoutMs  := 3 * 60000     ; walking to / opening a mode in the lobby
global FW_LoadTimeoutMs      := 3 * 60000     ; waiting to load into a stage
global FW_VoteTimeoutMs      := 3 * 60000     ; vote-start screen still showing
global FW_StageTimeoutMs     := 45 * 60000    ; one stage (placement + upgrades + monitoring)
global FW_EndScreenTimeoutMs := 5 * 60000     ; results / end screen handling
global FW_LobbyTimeoutMs     := 3 * 60000     ; waiting to arrive in the lobby
global FW_ReconnectTimeoutMs := 5 * 60000     ; one reconnect / rejoin attempt, then relaunch

; If timeouts fire more often than this per hour, the macro stops instead of
; rejoining again (reconnect/rejoin relaunches are not counted). 0 = no limit.
global FW_MaxFailsafesPerHour := 6

; Runtime errors: log, rejoin, carry on - unless more than FW_MaxErrors happen
; within FW_ErrorWindowMs; then the macro stops and AutoHotkey shows the error.
global FW_ErrorRecoveryEnabled := true
global FW_MaxErrors            := 3
global FW_ErrorWindowMs        := 10 * 60000
