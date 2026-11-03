
#Requires AutoHotkey v2.0


global PriorityCardSelector := Gui("+AlwaysOnTop")
PriorityCardSelector.SetFont("s10 bold", "Segoe UI")
PriorityCardSelector.BackColor := "0c000a"
PriorityCardSelector.MarginX := 20
PriorityCardSelector.MarginY := 20

PriorityOrder := PriorityCardSelector.Add(
    "GroupBox",
    "x30 y25 w180 h570 cWhite",
    "Foolshunt Priority Order"
)

options := [
    "placeholder1_1", "placeholder1_2", "placeholder1_3",
    "placeholder1_4", "placeholder1_5", "placeholder1_6",
    "placeholder1_7", "placeholder1_8", "placeholder1_9",
    "placeholder1_10", "placeholder1_11", "placeholder1_12",
    "placeholder1_13", "placeholder1_14", "placeholder1_15",
    "placeholder1_16", "placeholder1_17", "placeholder1_18",
    "placeholder1_19"
]

numDropDowns := 19
yStart := 50
ySpacing := 28

global dropDowns := []

Loop numDropDowns {
    index := A_Index
    yPos := yStart + ((index - 1) * ySpacing)

    dropDown := PriorityCardSelector.Add(
        "DropDownList",
        Format("x60 y{} w135 Choose{}", yPos, index),
        options
    )

    dropDowns.Push(dropDown)
    AttachDropDownEvent(dropDown, index, OnDropDownChangeFools)
}

DebuffGroupbox := PriorityCardSelector.Add(
    "GroupBox",
    "x30 y610 w180 h120 cWhite",
    "Debuff Priority"
)

RadioRandom := PriorityCardSelector.Add(
    "Radio",
    "x54 y630 w120 h23 cWhite Checked",
    "Random Tier"
)

RadioHighest := PriorityCardSelector.Add(
    "Radio",
    "x54 y655 w120 h23 cWhite",
    "Highest Tier"
)

PriorityCardSelector.Add(
    "Text",
    "x54 y680 w180 cWhite +BackgroundTrans",
    "Random = Pick any"
)

PriorityCardSelector.Add(
    "Text",
    "x54 y700 w180 cWhite +BackgroundTrans",
    "Highest = Tier 3>2>1"
)

global priorityOrder := [
    "new_path", "range_3", "attack_3", "cooldown_3",
    "range_2", "attack_2", "cooldown_2", "blessing_2",
    "range_1", "attack_1", "cooldown_1", "blessing_1",
    "shield", "explosive_death_21", "explosive_death_3",
    "speed", "health", "regen", "yen"
]

OpenFoolsPriorityPicker() {
    PriorityCardSelector.Show()
}

OnDropDownChangeFools(ctrl, index) {
    if (index >= 1 && index <= priorityOrder.Length) {
        priorityOrder[index] := ctrl.Text

        AddToLog(Format(
            "Priority {} set to {}",
            index,
            ctrl.Text
        ))

        RemoveEmptyStrings(priorityOrder)
        SaveFoolsLocal()
    } else {
        AddToLog(Format("Invalid index {} for dropdown", index))
    }
}

LogPriorityOrderFools() {
    logText := "Current Priority Order: " . StringJoin(priorityOrder, ", ")
    AddToLog(logText)
}

SaveFoolsConfig(*) {
    SaveFoolsLocal()
    return
}

LoadFoolsConfig(*) {
    LoadFoolsLocal()
    return
}

SaveFoolsConfigToFile(filePath) {
    global dropDowns, debugMessages

    directory := "Settings"

    if !DirExist(directory)
        DirCreate(directory)

    if !FileExist(filePath)
        FileAppend("", filePath)

    file := FileOpen(filePath, "w", "UTF-8")
    if !file {
        AddToLog("Failed to save the Foolshunt configuration.")
        return
    }

    file.WriteLine("[FoolsCardPriority]")

    for index, dropDown in dropDowns {
        file.WriteLine(Format("Card{}={}", index, dropDown.Text))
    }

    file.Close()

    if (debugMessages)
        AddToLog("Foolshunt configuration saved successfully to " filePath ".`n")
}

LoadFoolsConfigFromFile(filePath) {
    global dropDowns, priorityOrder, debugMessages

    if !FileExist(filePath) {
        AddToLog("No Foolshunt configuration file found. Creating new local configuration.")
        SaveFoolsLocal()
        return
    }

    file := FileOpen(filePath, "r", "UTF-8")
    if !file {
        AddToLog("Failed to load the Foolshunt configuration.")
        return
    }

    section := ""

    while !file.AtEOF {
        line := Trim(file.ReadLine())

        if RegExMatch(line, "^\[(.*)\]$", &match) {
            section := match[1]
            continue
        }

        if (section = "FoolsCardPriority") {
            if RegExMatch(line, "^Card(\d+)=(.*)$", &match) {
                slot := Integer(match[1])
                value := match[2]

                if (slot >= 1 && slot <= dropDowns.Length) {
                    priorityOrder[slot] := value
                    dropDowns[slot].Text := value
                }
            }
        }
    }

    file.Close()

    if (debugMessages)
        AddToLog("Foolshunt configuration loaded successfully.")
}

SaveFoolsLocal(*) {
    SaveFoolsConfigToFile("Settings\FoolshuntCardPriority.txt")
}

LoadFoolsLocal(*) {
    LoadFoolsConfigFromFile("Settings\FoolshuntCardPriority.txt")
}