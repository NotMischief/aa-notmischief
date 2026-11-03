; [Advanced panel] The "Avoided Curses" window was replaced by the Advanced Settings panel
; in the main window (AA_BuildAdvancedPanel in Lib\GuiPanels.ahk builds the dropdowns).

curseOptions := ["None", "Flying", "Wind", "Money", "Health", "Exploding", "Shielding", "Regen", "Frenzy", "Burst", "Armor", "Chaos", "Vamparism"]

global curseDropDowns := []
global enabledCurses := []

OpenCursePriorityPicker() {
    AA_ShowPanel("Advanced")
}

global cursePriorityOrder := ["None", "Flying", "Wind", "Money", "Health", "Exploding", "Shielding", "Regen"]


OnCurseDropDownChange(ctrl, index) {
    if (index >= 0 and index <= 19) {
        cursePriorityOrder[index] := ctrl.Text
        if (debugMessages) {
            AddToLog(Format("Priority {} set to {}", index, ctrl.Text))
        }
        RemoveEmptyStrings(cursePriorityOrder)
        UpdateEnabledCurses()
        SaveDungeonLocal()
    } else {
        if (debugMessages) {
            AddToLog(Format("Invalid index {} for dropdown", index))
        }
    }
}

UpdateEnabledCurses() {
    global enabledCurses
    enabledCurses := []
    for index, curse in cursePriorityOrder {
        if (curse != "" and curse != "None") {
            enabledCurses.Push(curse)
        }
    }
}

ShouldSkipCurse(curse) {
    global enabledCurses
    return HasValue(enabledCurses, curse)
}

LogSkippedCurses() {
    global enabledCurses
    if (enabledCurses.Length > 0) {
        AddToLog("Skipped Curses: " . StringJoin(enabledCurses))
    } else {
        AddToLog("No curses are skipped.")
    }
}