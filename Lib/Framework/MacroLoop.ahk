#Requires AutoHotkey v2.0

; ============================================================================
;  MacroLoop.ahk  -  [Optimised] fixes the crash after running for a long time
; ----------------------------------------------------------------------------
;  Before: each step started the next one from inside itself
;      MonitorStage -> HandleStageEnd -> MonitorEndScreen -> RestartStage -> MonitorStage -> ...
;  None of them ever finished, so every match left more unfinished calls behind
;  until AutoHotkey ran out of room (the error you saw after a long run).
;
;  Now: a step hands off with NextStep(NextFunction). That ends the current step right
;  there, and RunMacroLoop starts the next one. Same steps, same clicks, same
;  order - but only one step is ever running, so nothing piles up.
; ============================================================================

class MacroNextStep extends Error {
    __New(step) {
        super.__New("Macro step hand-off")
        this.Step := step
    }
}

class MacroLoopState {
    static Active := false
}

; Hand off to the next step. Used where the code used to do "return NextFunction()".
NextStep(step) {
    if (MacroLoopState.Active)
        throw MacroNextStep(step)
    return RunMacroLoop(step) ; safety net: not started from StartMacro, run it the normal way
}

; Runs one step at a time. Started once by StartMacro.
RunMacroLoop(step) {
    MacroLoopState.Active := true
    FW_OnMacroStart()   ; [Framework] start with no failsafe timers armed
    try {
        loop {
            try {
                return step()   ; a step that just ends (nothing to hand off to) stops the macro, like before
            } catch MacroNextStep as handoff {
                step := handoff.Step
            } catch MacroStop as stop {
                ; [Framework] a failsafe decided the macro should stop (Lib\Framework\Failsafe.ahk)
                FW_Log("[Framework] Macro stopped: " stop.Message)
                return
            } catch Error as err {
                ; [Framework] unexpected runtime error: log it and rejoin, or re-throw when too many
                step := FW_HandleStepError(err)
            }
        }
    } finally {
        MacroLoopState.Active := false
    }
}
