#Requires AutoHotkey v2.0

ExportConfigCode(*) {
    configPath :=  A_ScriptDir "\Settings\Configuration.txt"

    if !FileExist(configPath) {
        AddToLog("Configuration.txt not found.")
        return
    }

    try {
        config := FileRead(configPath, "UTF-8")
        encoded := "FHC1-" . Base64Encode(config)

        A_Clipboard := encoded
        ClipWait(2)

        AddToLog("Config code copied to clipboard.")
    } catch as err {
        AddToLog("Config export failed: " err.Message)
    }
}

ImportConfigCode(*) {
    configCode := InputBox("Paste the config code here:", "Import Config Code", "x200 y200 w500 h150")

    if (configCode.Result != "OK")
        return

    code := Trim(configCode.Value)

    if !RegExMatch(code, "^FHC1-[A-Za-z0-9+/=]+$") {
        AddToLog("Invalid Foolshunt config code.")
        return
    }

    encoded := SubStr(code, 6)

    try {
        config := Base64Decode(encoded)

        if !InStr(config, "[Placement]")
            throw Error("Missing placement section.")

        configPath := A_ScriptDir "\Settings\Configuration.txt"
        backupPath := A_ScriptDir "\Settings\Configuration_backup.txt"

        if FileExist(configPath)
            FileCopy(configPath, backupPath, 1)

            FileDelete(configPath)
            FileAppend(config, configPath, "UTF-8")

        AddToLog("Config imported. Backup saved as Configuration_backup.txt.")
    } catch as err {
    AddToLog("Config import failed: " err.Message)
    MsgBox("Config import failed:`n" err.Message)
}
}

Base64Encode(text) {
    ; Convert text to UTF-8 bytes
    byteCount := StrPut(text, "UTF-8") - 1
    bytes := Buffer(byteCount + 1, 0)
    StrPut(text, bytes, "UTF-8")

    chars := 0
    if !DllCall("Crypt32\CryptBinaryToStringW",
        "Ptr", bytes,
        "UInt", byteCount,
        "UInt", 0x40000001,
        "Ptr", 0,
        "UInt*", &chars)
        throw Error("Base64 encoding size failed.")

    output := Buffer(chars * 2, 0)

    if !DllCall("Crypt32\CryptBinaryToStringW",
        "Ptr", bytes,
        "UInt", byteCount,
        "UInt", 0x40000001,
        "Ptr", output,
        "UInt*", &chars)
        throw Error("Base64 encoding failed.")

    return RTrim(StrGet(output, "UTF-16"), "`r`n")
}

Base64Decode(encoded) {
    charCount := StrLen(encoded)
    input := Buffer((charCount + 1) * 2, 0)
    StrPut(encoded, input, "UTF-16")

    size := 0
    if !DllCall("Crypt32\CryptStringToBinaryW",
        "Ptr", input,
        "UInt", charCount,
        "UInt", 1,
        "Ptr", 0,
        "UInt*", &size,
        "Ptr", 0,
        "Ptr", 0)
        throw Error("Base64 size calculation failed.")

    output := Buffer(size, 0)

    if !DllCall("Crypt32\CryptStringToBinaryW",
        "Ptr", input,
        "UInt", charCount,
        "UInt", 1,
        "Ptr", output,
        "UInt*", &size,
        "Ptr", 0,
        "Ptr", 0)
        throw Error("Base64 decoding failed.")

    return StrGet(output, size, "UTF-8")
}