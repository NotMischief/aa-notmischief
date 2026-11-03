#Requires AutoHotkey v2.0

; ============================================================================
;  Timers.ahk  -  [Framework] named deadlines and cooldowns
; ----------------------------------------------------------------------------
;  Ported from Anime Guardians:
;    Lib\Functions\TimerManager.ahk     (class TimerManager)
;    Lib\Functions\CooldownManager.ahk  (class CooldownManager + wrappers)
;  Pure bookkeeping on A_TickCount - no clicks, no keys, no detection, no SetTimer.
;  Added for Anime Adventures: TimerManager.ShiftAll() (pause support) and
;  TimerManager.ClearAll() (fresh state when the macro starts).
;  Not ported: Guardians' Challenge cooldown helpers (Guardians-specific).
; ============================================================================

class TimerManager {
    static timers := Map()

    ; Starts a failsafe timer for a given name and duration (ms)
    static Start(name, durationMs) {
        this.timers[name] := A_TickCount + durationMs
    }

    ; Checks if the failsafe timer has expired
    static HasExpired(name) {
        return this.timers.Has(name) && A_TickCount >= this.timers[name]
    }

    ; Gets remaining time in milliseconds
    static GetRemaining(name) {
        if !this.timers.Has(name)
            return 0
        remaining := this.timers[name] - A_TickCount
        return remaining > 0 ? remaining : 0
    }

    ; Clears a timer
    static Clear(name) {
        if this.timers.Has(name)
            this.timers.Delete(name)
    }

    ; Resets the timer (if needed)
    static Reset(name, durationMs) {
        this.Start(name, durationMs)
    }

    ; [Adventures] Clears every timer
    static ClearAll() {
        this.timers := Map()
    }

    ; [Adventures] Moves every deadline later by ms (used after the macro was paused)
    static ShiftAll(ms) {
        if (ms <= 0)
            return
        names := []
        for name in this.timers
            names.Push(name)
        for name in names
            this.timers[name] := this.timers[name] + ms
    }
}

class CooldownManager {
    static cooldowns := Map()

    ; Sets a cooldown in milliseconds for the given action name
    static SetCooldown(name, durationMs) {
        this.cooldowns[name] := A_TickCount + durationMs
    }

    ; Returns true if the action is still on cooldown
    static IsOnCooldown(name) {
        return this.cooldowns.Has(name) && A_TickCount < this.cooldowns[name]
    }

    ; Returns remaining cooldown time in milliseconds (0 if ready)
    static GetRemaining(name) {
        if !this.cooldowns.Has(name)
            return 0
        remaining := this.cooldowns[name] - A_TickCount
        return remaining > 0 ? remaining : 0
    }

    ; Clears the cooldown
    static ClearCooldown(name) {
        if this.cooldowns.Has(name)
            this.cooldowns.Delete(name)
    }
}

ApplyCooldown(name, durationMs) {
    CooldownManager.SetCooldown(name, durationMs)
}

ClearCooldown(name) {
    CooldownManager.ClearCooldown(name)
}

IsOnCooldown(name) {
    return CooldownManager.IsOnCooldown(name)
}
