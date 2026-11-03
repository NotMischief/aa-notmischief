#Requires AutoHotkey v2.0

; [Scheduler team swap] Equips team 1-4 in the lobby (called by Sched_RunPendingTeamSwap).
TS_SwapTeam(teamNum) {
    teams := [
        [567, 232],   ; Team 1 - Load
        [567, 319],   ; Team 2 - Load
        [567, 406],   ; Team 3 - Load
        [567, 493],   ; Team 4 - Load
    ]
    if (teamNum < 1 || teamNum > teams.Length) {
        AddToLog("Team swap: there is no Team " teamNum)
        return false
    }
    AddToLog("Team swap: equipping Team " teamNum)
    SendInput("K") ; Open Units
    Sleep 2000
    ; [UI update] find the Teams tab and the Load buttons by their text first
    try {
        if (tb := SH_Find("^teams?$", 0, 60, 800, 200)) {
            FixClick(tb.x, tb.y)
            Sleep(1000)
            loads := []
            for it in SH_Items(100, 120, 650, 440)
                if RegExMatch(it.t, "^load$")
                    loads.Push(it)
            if (loads.Length >= teamNum) {
                ; top to bottom = Team 1, 2, 3, 4
                list := ""
                for i, it in loads
                    list .= Format("{:05}", it.y) "|" i "`n"
                order := StrSplit(Sort(RTrim(list, "`n")), "`n")
                pick := loads[Integer(StrSplit(order[teamNum], "|")[2])]
                FixClick(pick.x, pick.y)
                Sleep 2000
                SendInput("K")
                Sleep 1000
                return true
            }
        }
    }
    FixClick(398, 223) ; Click Teams
    Sleep 1000
    FixClick(teams[teamNum][1], teams[teamNum][2]) ; Load team
    Sleep 2000
    SendInput("K") ; Close Units
    Sleep 1000
    return true
}
