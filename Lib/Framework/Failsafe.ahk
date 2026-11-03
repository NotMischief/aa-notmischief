#Requires AutoHotkey v2.0

; ============================================================================
;  Failsafe.ahk  -  [Framework] stage failsafes and error containment
; ============================================================================

; Thrown to end the macro loop cleanly (RunMacroLoop logs it and stops).
class MacroStop extends Error {
}

class StageGuard {
    static triggers := []   ; A_TickCount of each counted failsafe trigger

    ; Start (or restart) the deadline. ms <= 0 or failsafes off -> guard cleared.
    static Arm(name, ms) {
        global FW_FailsafesEnabled
        if (!FW_FailsafesEnabled || ms <= 0) {
            TimerManager.Clear(name)
            return
        }
        TimerManager.Start(name, ms)
    }

    static Disarm(name) {
        TimerManager.Clear(name)
    }

    ; Does nothing unless the guard is armed, has expired, and the macro loop is running.
    static Check(name, reason := "", counted := true) {
        if (!MacroLoopState.Active || !TimerManager.HasExpired(name))
            return
        TimerManager.Clear(name)
        FW_Log("[Failsafe] " name " timeout" (reason != "" ? " (" reason ")" : "") " - rejoining")
        if (counted)
            this.CountTrigger(name)
        NextStep(RejoinPrivateServer)
    }

    static CountTrigger(name) {
        global FW_MaxFailsafesPerHour
        now := A_TickCount
        kept := []
        for t in this.triggers {
            if (now - t < 3600000)
                kept.Push(t)
        }
        kept.Push(now)
        this.triggers := kept
        if (FW_MaxFailsafesPerHour > 0 && kept.Length > FW_MaxFailsafesPerHour) {
            ; [24/7] used to stop the macro for good. Now: say so, rest 10 minutes, then rejoin and carry on.
            FW_Log("[Failsafe] " kept.Length " failsafes within one hour (last: " name ") - resting 10 minutes, then rejoining")
            try sendDCWebhook()
            this.triggers := []
            Sleep(600000)
        }
    }
}

; [Failsafe] a step finished without saying what comes next. Lobby -> start the mode again; anything
; else -> rejoin. At most 6 times in 30 minutes, then stop (something is really wrong).
FW_StepEnded() {
    static ends := []
    now := A_TickCount
    kept := []
    for t in ends
        if (now - t < 1800000)
            kept.Push(t)
    kept.Push(now)
    ends := kept
    if (kept.Length > 6) {
        FW_Log("[Framework] Macro stopped: it got lost " kept.Length " times in 30 minutes")
        return 0
    }
    w := ""
    try w := SC_WhereSure()
    if (w = "lobby" || w = "queue") {
        FW_Log("[Failsafe] Lost track of what to do - this is the lobby, starting again")
        return StartSelectedMode
    }
    FW_Log("[Failsafe] Lost track of what to do (screen: " (w = "" ? "unknown" : w) ") - rejoining")
    return RejoinPrivateServer
}

; Called once by RunMacroLoop when a run starts.
FW_OnMacroStart() {
    TimerManager.ClearAll()
}

; Stage timeout is skipped for the open-ended modes that MonitorStage already
; treats specially (anti-AFK): Story "Infinity" and Winter Event.
FW_StageGuardApplies() {
    global mode, StoryActDropdown
    try {
        if ((mode = "Story" && StoryActDropdown.Text = "Infinity") || (mode = "Winter Event"))
            return false
    }
    return true
}

; Called by RunMacroLoop for an unexpected runtime error inside a step.
; Returns the step to continue with, or re-throws to stop the macro.
FW_HandleStepError(err) {
    global FW_ErrorRecoveryEnabled, FW_MaxErrors, FW_ErrorWindowMs
    static errorTimes := []

    where := ""
    try {
        SplitPath(err.File, &fileName)
        where := " [" fileName ":" err.Line "]"
    }
    msg := ""
    try msg := err.Message
    what := ""
    try what := err.What
    FW_Log("[Error] " msg (what != "" ? " in " what : "") where)

    if (!FW_ErrorRecoveryEnabled)
        throw err

    now := A_TickCount
    kept := []
    for t in errorTimes {
        if (now - t < FW_ErrorWindowMs)
            kept.Push(t)
    }
    kept.Push(now)
    errorTimes := kept

    if (kept.Length > FW_MaxErrors) {
        FW_Log("[Error] " kept.Length " errors within " Round(FW_ErrorWindowMs / 60000) " min - stopping the macro")
        throw err
    }
    FW_Log("[Error] Recovering by rejoining (" kept.Length "/" FW_MaxErrors ")")
    return RejoinPrivateServer
}

; AddToLog, but never lets a logging problem raise a second error.
FW_Log(text) {
    try {
        AddToLog(text)
    } catch {
        OutputDebug(text)
    }
}
