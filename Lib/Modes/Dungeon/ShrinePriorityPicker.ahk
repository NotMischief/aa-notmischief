; [Advanced panel] The "Avoided Shrines" window was replaced by the Advanced Settings panel
; in the main window (AA_BuildAdvancedPanel in Lib\GuiPanels.ahk builds the dropdowns).

shrineOptions := ["None", "Burst", "Armor", "Chaos", "Vamparism", "Frenzy"]

global shrineDropDowns := []
global enabledShrines := []

OpenShrinePriorityPicker() {
    AA_ShowPanel("Advanced")
}

global shrinePriorityOrder := [
    "None",
    "Burst",
    "Armor",
    "Chaos",
    "Vamparism",
    "Frenzy"
]

OnShrineDropDownChange(ctrl, index) {
    if (index >= 1 && index <= shrinePriorityOrder.Length) {
        shrinePriorityOrder[index] := ctrl.Text

        RemoveEmptyStrings(shrinePriorityOrder)
        UpdateEnabledShrines()

        SaveDungeonLocal()
    }
}

UpdateEnabledShrines() {
    global enabledShrines

    enabledShrines := []

    for index, shrine in shrinePriorityOrder {
        if (shrine != "" && shrine != "None")
            enabledShrines.Push(shrine)
    }
}

ShouldSkipShrine(shrine) {
    global enabledShrines
    return HasValue(enabledShrines, shrine)
}
