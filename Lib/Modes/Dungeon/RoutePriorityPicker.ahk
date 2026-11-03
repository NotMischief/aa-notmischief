; [Advanced panel] The "Route Priority" window was replaced by the Advanced Settings panel
; in the main window (AA_BuildAdvancedPanel in Lib\GuiPanels.ahk builds the dropdowns).

roomOptions := ["Rare_Chest", "Chest", "Hoard", "Shop", "Shrine", "Boss"]

global routeDropDowns := []

OpenRoutePriorityPicker() {
    AA_ShowPanel("Advanced")
}

global routePriorityOrder := ["Rare_Chest", "Chest", "Hoard", "Shop", "Shrine", "Boss"]

OnRouteDropDownChange(ctrl, index) {
    if (index >= 0 and index <= 19) {
        routePriorityOrder[index] := ctrl.Text
        if (debugMessages) {
            AddToLog(Format("Priority {} set to {}", index, ctrl.Text))
        }
        RemoveEmptyStrings(routePriorityOrder)
        SaveDungeonLocal()
    } else {
        if (debugMessages) {
            AddToLog(Format("Invalid index {} for dropdown", index))
        }
    }
}