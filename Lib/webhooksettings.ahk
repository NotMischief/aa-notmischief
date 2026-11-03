#Include %A_ScriptDir%\Lib\Discord-Webhook-master\lib\WEBHOOK.ahk
#Include %A_ScriptDir%\Lib\AHKv2-Gdip-master\Gdip_All.ahk

global WebhookURLFile := "Settings\WebhookURL.txt"
global DiscordUserIDFile := "Settings\DiscordUSERID.txt"
global SendActivityLogsFile := "Settings\SendActivityLogs.txt"
global WebhookURL := ""  
global webhook := ""
global currentStreak := 0
global lastResult := "none"
global Wins := 0
global loss := 0
global mode := ""
global StartTime := A_TickCount 
global stageStartTime := A_TickCount
global macroStartTime := A_TickCount
global detectedMap := "No Map Found"

if (!FileExist("Settings")) {
    DirCreate("Settings")
}

win_messages := [
            "clean victory secured 🏆",
            "macro going crazy rn fr 🔥",
            "stacking those Ws 📈",
            "another dub in the books 🎯",
            "back to back wins incoming 💫",
            "(˵ •̀ ᴗ – ˵ ) ✧",
            "♡‧₊˚✧ ૮ ˶ᵔ ᵕ ᵔ˶ ა ✧˚₊‧♡",
            "/)_/)`n(,,>.<)`n/ >❤️",
            "૮꒰ ˶• ༝ •˶꒱ა ♡",
            "✧｡٩(ˊᗜˋ )و✧*｡",
            "( •̯́ ₃ •̯̀)",
            "₍ᐢ•ﻌ•ᐢ₎*･ﾟ｡"

        ],
        lose_messages := [
            "next one is a win fr 💯",
            "just warming up 🔥",
            "next run is the one 🎮",
            "almost had it that time 🎯",
            "getting better each run 📈",
            "(╯°□°)╯︵ ┻━┻",
            "(ಠ益ಠ)",
            "(╥﹏╥)",
            "(⇀‸↼‶)",
            "(◣ _ ◢)",
            "<(ꐦㅍ _ㅍ)>"
        ],
        ; Milestone messages (every 10th attempt)
        milestone_win_messages := [
        "milestone #{count} win secured! 🏆",
        "#{count} wins and counting! 📈",
        "#{count} wins in the books! 🔥",
        "reached #{count} wins! ⭐",
        "#{count} wins and still going strong! 💫"
        ],
        milestone_lose_messages := [
        "milestone #{count} loss... just bad luck, next time! 🍀",
        "#{count} losses, but we'll get 'em next time! 🤞",
        "reached #{count} losses... just one of those days! 🤷‍♂️",
        "hit #{count} losses, but we’ll turn it around soon! 🙌",
        "milestone #{count} loss, but no worries—next game is ours! 😎"
        ]
        ; Streak messages
        winstreak_messages := [
            "#{streak} win streak lets gooo 🏆",
            "on fire with #{streak} wins 🔥",
            "unstoppable #{streak} win streak 💫",
            "#{streak} wins in a row sheesh 📈",
            "#{streak} win streak going crazy 🌟"
            "(˵ •̀ ᴗ – ˵ ) ✧",
            "♡‧₊˚✧ ૮ ˶ᵔ ᵕ ᵔ˶ ა ✧˚₊‧♡",
            "/)_/)`n(,,>.<)`n/ >❤️",
            "૮꒰ ˶• ༝ •˶꒱ა ♡",
            "✧｡٩(ˊᗜˋ )و✧*｡",
            "( •̯́ ₃ •̯̀)"
        ],
        losestreak_messages := [
            "#{streak} runs of experience gained 📚",
            "#{streak} tries closer to victory 🎯",
            "learning from #{streak} attempts 💪",
            "#{streak} runs of practice secured 📈",
            "comeback loading after #{streak} 🔄"
            "(╯°□°)╯︵ ┻━┻",
            "(ಠ益ಠ)",
            "(╥﹏╥)",
            "(⇀‸↼‶)",
            "(◣ _ ◢)",
            "<(ꐦㅍ _ㅍ)>"
        ],
        ; Time-based messages
        long_win_messages := [
        "took #{time} but macro finally popped off 💪",
        "#{time} grind actually paid off wtf 😳",
        "pc earned its rest after #{time} 😴",
        "#{time} of pure skill 🔥",
        ],
        long_lose_messages := [
        "#{time} of valuable experience 📚",
        "#{time} of strategy learning 🧠",
        "#{time} closer to victory 🎯",
        "#{time} of practice makes perfect ⭐",
        "#{time} getting stronger 💪"
        ]

CalculateElapsedTime(startTime) {
    elapsedTimeMs := A_TickCount - startTime
    elapsedTimeSec := Floor(elapsedTimeMs / 1000)
    elapsedHours := Floor(elapsedTimeSec / 3600)
    elapsedMinutes := Floor(Mod(elapsedTimeSec, 3600) / 60)
    elapsedSeconds := Mod(elapsedTimeSec, 60)
    return Format("{:02}:{:02}:{:02}", elapsedHours, elapsedMinutes, elapsedSeconds)
}

; Function to update streak
UpdateStreak(isWin) {
    global currentStreak, lastResult
    
    ; Initialize lastResult if it doesn't exist
    if (!IsSet(lastResult)) {
        lastResult := "none"
    }
    
    if (isWin) {
        if (lastResult = "win")
            currentStreak += 1
        else
            currentStreak := 1
    } else {
        if (lastResult = "lose")
            currentStreak -= 1
        else
            currentStreak := -1
    }
    
    lastResult := isWin ? "win" : "lose"
}

UpdateMap(mapName) {
    global detectedMap
    
    ; Initialize detectedMap if it doesn't exist
    if (!IsSet(detectedMap)) {
        detectedMap := "No Map Found"
    }
    
    detectedMap := mapName
}

SendWebhookWithTime(isWin, stageLength) {
    global currentStreak, Wins, loss, WebhookURL, webhook, macroStartTime, detectedMap
    
    ; Update streak
    UpdateStreak(isWin)

    if !AA_WebhookEnabled()   ; [Settings panel] "Webhook Enabled" is off
        return

    ; Check if webhook file exists first
    if (!FileExist(WebhookURLFile)) {
    AddToLog("No webhook configured - skipping webhook")
    return  ; Just return if no webhook file
    }

    ; Read webhook URL from file
    WebhookURL := WH_URL()
    if (WebhookURL = "") {
        AddToLog("Invalid webhook URL - skipping webhook")
        return
    }
    
    ; Initialize webhook
    webhook := WebHookBuilder(WebhookURL)
    
    ; Calculate macro runtime (total time)
    macroLength := FormatStageTime(A_TickCount - macroStartTime)
    
    ; Build session data
    sessionData := "⌛ Macro Runtime: " macroLength "`n"
    . "⏱️ Stage Length: " stageLength "`n"
    . "🔄 Current Streak: " (currentStreak > 0 ? currentStreak " Win Streak" : Abs(currentStreak) " Loss Streak") "`n"
    . "🗺️ Current Map: " detectedMap "`n"
    . ":video_game: Current Mode: " mode "`n"
    . ":white_check_mark: Successful Runs: " Wins "`n"
    . "❌ Failed Runs: " loss "`n"
    . ":bar_chart: Total Runs: " (loss+Wins) "`n"
    . ":scales: Win Rate: " Format("{:.1f}%", (Wins/(Wins+loss))*100) "`n"
    isWin ? 0x0AB02D : 0xB00A0A,
    isWin ? "win" : "lose"
    try sessionData .= DG_WebhookText()   ; [Damage list] everyone's damage from the last reading (Summer)
    
    ; Send webhook
    WebhookScreenshot(
        isWin ? "Stage Complete!" : "Stage Failed",
        sessionData,
        isWin ? 0x0AB02D : 0xB00A0A,
        isWin ? "win" : "lose"
    )
}

SendFinalWebhookBeforeExit() {
    global currentStreak, Wins, loss, WebhookURL, webhook, macroStartTime

    ; Check if webhook file exists first
    if (!FileExist(WebhookURLFile)) {
        AddToLog("No webhook configured - skipping final webhook")
        return
    }

    ; Read webhook URL from file
    WebhookURL := FileRead(WebhookURLFile, "UTF-8")
    if !(WebhookURL ~= 'i)https?:\/\/discord\.com\/api\/webhooks\/(\d{18,19})\/[\w-]{68}') {
        AddToLog("Invalid webhook URL - skipping final webhook")
        return
    }

    ; Initialize webhook
    webhook := WebHookBuilder(WebhookURL)

    ; Calculate total macro runtime
    macroLength := FormatStageTime(A_TickCount - macroStartTime)

    ; Build session summary
    sessionData := "📌 **Script is shutting down!**`n"
    . "⌛ Total Runtime: " macroLength "`n"
    . "🔄 Final Streak: " (currentStreak > 0 ? currentStreak " Win Streak" : (currentStreak < 0 ? Abs(currentStreak) " Loss Streak" : "No active streak")) "`n"
    . ":white_check_mark: Successful Runs: " Wins "`n"
    . "❌ Failed Runs: " loss "`n"
    . ":bar_chart: Total Runs: " (loss + Wins) "`n"
    . ":scales: Win Rate: " (Wins + loss > 0 ? Format("{:.1f}%", (Wins / (Wins + loss)) * 100) : "N/A") "`n"

    ; Send final webhook
    WebhookScreenshot(
        "Final Session Summary",
        sessionData,
        0xFFA500,  ; Orange color to indicate script shutdown
        "exit"
    )
}

CropImage(pBitmap, x, y, width, height) {
    ; Initialize GDI+ Graphics from the source bitmap
    pGraphics := Gdip_GraphicsFromImage(pBitmap)
    if !pGraphics {
        MsgBox("Failed to initialize graphics object")
        return
    }

    ; Create a new bitmap for the cropped image
    pCroppedBitmap := Gdip_CreateBitmap(width, height)
    if !pCroppedBitmap {
        MsgBox("Failed to create cropped bitmap")
        Gdip_DeleteGraphics(pGraphics)
        return
    }

    ; Initialize GDI+ Graphics for the new cropped bitmap
    pTargetGraphics := Gdip_GraphicsFromImage(pCroppedBitmap)
    if !pTargetGraphics {
        MsgBox("Failed to initialize graphics for cropped bitmap")
        Gdip_DisposeImage(pCroppedBitmap)
        Gdip_DeleteGraphics(pGraphics)
        return
    }

    ; Copy the selected area from the source bitmap to the new cropped bitmap
    Gdip_DrawImage(pTargetGraphics, pBitmap, 0, 0, width, height, x, y, width, height)

    ; Cleanup
    Gdip_DeleteGraphics(pGraphics)
    Gdip_DeleteGraphics(pTargetGraphics)

    ; Return the cropped bitmap
    return pCroppedBitmap
}


WebhookSettings() { 
    if FileExist(WebhookURLFile)
        WebhookURLBox.Value := FileRead(WebhookURLFile, "UTF-8")

    if FileExist(DiscordUserIDFile)
        DiscordUserIDBox.Value := FileRead(DiscordUserIDFile, "UTF-8")

    if FileExist(SendActivityLogsFile) ; Load checkbox value
        SendActivityLogsBox.Value := (FileRead(SendActivityLogsFile, "UTF-8") = "1")

    
}

SaveWebhookSettings() {
    
    if !(WebhookURLBox.Value = "" || RegExMatch(WebhookURLBox.Value, "^https://discord\.com/api/webhooks/.*")) {
        MsgBox("Invalid Webhook URL! Please enter a valid Discord webhook URL.", "Error", "+0x1000", )
        WebhookURLBox.Value := ""
        return
    }

    if !(RegExMatch(DiscordUserIDBox.Value, "^\d*$")) {
        MsgBox("Invalid Discord User ID! Please enter a valid Discord User ID or keep it empty.", "Error", "+0x1000")
        DiscordUserIDBox.Value := ""
        return
    }

    AddToLog("Saving Webhook Configuration")
    
    ; Delete old files if they exist
    if FileExist(WebhookURLFile)
        FileDelete(WebhookURLFile)

    if FileExist(DiscordUserIDFile)
        FileDelete(DiscordUserIDFile)

    if FileExist(SendActivityLogsFile)
        FileDelete(SendActivityLogsFile)

    ; Save the new values
    FileAppend(WebhookURLBox.Value, WebhookURLFile, "UTF-8")
    FileAppend(DiscordUserIDBox.Value, DiscordUserIDFile, "UTF-8")
    FileAppend(SendActivityLogsBox.Value ? "1" : "0", SendActivityLogsFile, "UTF-8")
    global SendActivityLogsCache := "" ; [Optimised] AddToLog re-reads the setting next time
}

; [Settings panel] "Webhook Enabled" (Settings\WebhookEnabled.txt, saved by
; AA_SaveWebhookEnabled in GuiEvents.ahk). No file = enabled, so existing setups keep
; sending exactly as before. Read once and cached.
AA_WebhookEnabled() {
    global AA_WebhookEnabledCache
    if !IsSet(AA_WebhookEnabledCache) || AA_WebhookEnabledCache = "" {
        val := "1"
        try {
            if FileExist("Settings\WebhookEnabled.txt")
                val := Trim(FileRead("Settings\WebhookEnabled.txt", "UTF-8"))
        }
        AA_WebhookEnabledCache := (val = "0") ? "0" : "1"
    }
    return AA_WebhookEnabledCache = "1"
}

TextWebhook() {
    global lastlog

    ; Calculate the runtime
    ElapsedTimeMs := A_TickCount - StartTime
    ElapsedTimeSec := Floor(ElapsedTimeMs / 1000)
    ElapsedHours := Floor(ElapsedTimeSec / 3600)
    ElapsedMinutes := Floor(Mod(ElapsedTimeSec, 3600) / 60)
    ElapsedSeconds := Mod(ElapsedTimeSec, 60)
    Runtime := Format("{} hours, {} minutes", ElapsedHours, ElapsedMinutes)

    ; Prepare the attachment and embed
    myEmbed := EmbedBuilder()
        .setTitle("")
        .setDescription("[" FormatTime(A_Now, "hh:mm tt") "] " lastlog)
        .setColor(0x0077ff)
        

    ; Send the webhook
    webhook.send({
        content: (""),
        embeds: [myEmbed],
        files: []
    })
}

InitiateWinWebhook() {
    global WebhookURL := FileRead(WebhookURLFile, "UTF-8")
    global DiscordUserID := FileRead(DiscordUserIDFile, "UTF-8")

    if (webhookURL ~= 'i)https?:\/\/discord\.com\/api\/webhooks\/(\d{18,19})\/[\w-]{68}') {
        global webhook := WebHookBuilder(WebhookURL)
        stageLength := FormatStageTime(A_TickCount - stageStartTime)
        SendWebhookWithTime(true, stageLength)
    }
}

InitiateLoseWebhook() {
    global WebhookURL := FileRead(WebhookURLFile, "UTF-8")
    global DiscordUserID := FileRead(DiscordUserIDFile, "UTF-8")

    if (webhookURL ~= 'i)https?:\/\/discord\.com\/api\/webhooks\/(\d{18,19})\/[\w-]{68}') {
        global webhook := WebHookBuilder(WebhookURL)
        stageLength := FormatStageTime(A_TickCount - stageStartTime)
        SendWebhookWithTime(false, stageLength)
    }
}

WebhookLog() {
    global WebhookURL := FileRead(WebhookURLFile, "UTF-8")
    global DiscordUserID := FileRead(DiscordUserIDFile, "UTF-8")

    if !AA_WebhookEnabled()   ; [Settings panel] "Webhook Enabled" is off
        return

    if (webhookURL ~= 'i)https?:\/\/discord\.com\/api\/webhooks\/(\d{18,19})\/[\w-]{68}') {
        global webhook := WebHookBuilder(WebhookURL)
        TextWebhook()
    } 
}

SaveWebhookBtnClick() {
    AddToLog("Attempting to save webhook settings...")
    SaveWebhookSettings()
    AddToLog("Webhook settings saved")
}
;Discord webhooks, above

WebhookScreenshot(title, description, color := 0x0dffff, status := "") {
    global webhook, WebhookURL, DiscordUserID, wins, loss, currentStreak, stageStartTime

    footerMessages := Map(
        "win", win_messages,
        "lose", lose_messages,
        "milestone_win", milestone_win_messages,
        "milestone_lose", milestone_lose_messages,
        "winstreak", winstreak_messages,
        "losestreak", losestreak_messages,
        "long_win", long_win_messages,
        "long_lose", long_lose_messages
    )

    global WebhookURL := WH_URL()   ; [Fix] read cleanly (no BOM / spaces / line breaks)
    if (WebhookURL = "") {
        AddToLog("[Webhook] No valid webhook URL in Settings\WebhookURL.txt - not sending")
        return
    }
    global webhook := WebHookBuilder(WebhookURL)
    global DiscordUserID := ""
    try DiscordUserID := RegExReplace(FileRead(A_ScriptDir "\Settings\DiscordUSERID.txt", "UTF-8"), "[^\d]", "")
    global wins, loss, currentStreak, stageStartTime

    if (!IsSet(stageStartTime)) {
        stageStartTime := A_TickCount
    }

    if !(webhookURL ~= 'i)https?:\/\/discord\.com\/api\/webhooks\/(\d{18,19})\/[\w-]{68}') {
        return
    }

    ; Select appropriate message based on conditions
    footerText := ""
    messages := footerMessages[status = "win" ? "win" : "lose"]  ; default messages

    stageLength := CalculateElapsedTime(stageStartTime)
    stageMinutes := Floor((A_TickCount - stageStartTime) / (1000 * 60))

    ReplaceVars(text, vars) {
        for key, value in vars {
            text := StrReplace(text, "#{" key "}", value)
        }
        return text
    }

    if (status = "win") {
        if (Mod(wins, 5) = 0) {
            messages := footerMessages["milestone_win"]
            footerText := ReplaceVars(messages[Random(1, messages.Length)], Map("count", wins))
        } else if (currentStreak >= 3) {
            messages := footerMessages["winstreak"]
            footerText := ReplaceVars(messages[Random(1, messages.Length)], Map("streak", currentStreak))
        }
    } else {
        if (Mod(loss, 5) = 0) {
            messages := footerMessages["milestone_lose"]
            footerText := ReplaceVars(messages[Random(1, messages.Length)], Map("count", loss))
        } else if (currentStreak <= -3) {
            messages := footerMessages["losestreak"]
            footerText := ReplaceVars(messages[Random(1, messages.Length)], Map("streak", Abs(currentStreak)))
        }
    }

    if (footerText = "") {
        footerText := messages[Random(1, messages.Length)]
    }

    UserIDSent := (DiscordUserID = "") ? "" : "<@" DiscordUserID ">"

    ; Initialize GDI+
    pToken := Gdip_Startup()
    if !pToken {
        MsgBox("Failed to initialize GDI+")
        return
    }

    ; Capture and process screen
    pBitmap := Gdip_BitmapFromScreen()
    if !pBitmap {
        MsgBox("Failed to capture the screen")
        Gdip_Shutdown(pToken)
        return
    }

    ; [Window follow] crop where the GUI is now (was always the top-left corner)
    cropX := 0, cropY := 0
    try {
        WinGetPos(&cropX, &cropY,,, "ahk_id " aaMainUIHwnd)
        cropX -= SysGet(76), cropY -= SysGet(77) ; screenshot starts at the virtual-screen corner
    }
    pCroppedBitmap := CropImage(pBitmap, cropX, cropY, 1366, 633)
    if !pCroppedBitmap {
        MsgBox("Failed to crop the bitmap")
        Gdip_DisposeImage(pBitmap)
        Gdip_Shutdown(pToken)
        return
    }

    try {
        ; Prepare and send webhook
        attachment := AttachmentBuilder(pCroppedBitmap)
        myEmbed := EmbedBuilder()
        myEmbed.setTitle(title)
        myEmbed.setDescription(description)
        myEmbed.setColor(color)
        myEmbed.setImage(attachment)
        myEmbed.setFooter({ text: footerText })

        res := webhook.send({
            content: UserIDSent,
            embeds: [myEmbed],
            files: [attachment]
        })
        ; [Fix] the answer from Discord used to be ignored, so a refused webhook looked like a sent one
        st := 0
        try st := res.status
        if (st >= 200 && st < 300)
            AddToLog("[Webhook] Sent to Discord")
        else {
            txt := ""
            try txt := SubStr(res.text, 1, 120)
            AddToLog("[Webhook] Discord refused it (status " st "): " txt)
        }
    } catch Error as err{
        AddToLog("[Webhook] Couldn't send (" err.Message ") - continuing without sending")
    }

    ; Cleanup
    Gdip_DisposeImage(pBitmap)
    Gdip_DisposeImage(pCroppedBitmap)
    Gdip_Shutdown(pToken)
}


SendWebhookRequest(webhook, params, maxRetries := 3) {
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", webhook, false)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.Send(JSON.Stringify(params))
        AddToLog("Webhook sent successfully")
        return true
    } catch {
        AddToLog("Unable to send webhook - continuing without sending")
        return false
    }
}

sendDCWebhook() {
    if !AA_WebhookEnabled()   ; [Settings panel] "Webhook Enabled" is off
        return
    MacroRuntime := CalculateElapsedTime(MacroStartTime)
    StageRuntime := CalculateElapsedTime(StageStartTime)

    ; Prepare the embed
    myEmbed := EmbedBuilder()
    myEmbed.setTitle(":exclamation: Client Disconnected :exclamation:")
    myEmbed.setDescription(":stopwatch: Disconnected At: " MacroRuntime "`n:stopwatch: Stage Runtime: " StageRuntime "")
    myEmbed.setColor(0xB00A0A)

    ; [Fix] WebhookURL is the URL text by now (not the settings box), so WebhookURL.Value failed here
    url := WH_URL()
    if (url = "") {
        AddToLog("No webhook configured - skipping webhook")
        return
    }
    global Webhook := WebHookBuilder(url)

    ; Send the webhook
    try {
        Webhook.send({
            embeds: [myEmbed],
        })

        AddToLog("Sent webhook successfully")
    } catch Error as err{
        AddToLog("Failed to send webhook")
    }

}

; [Fix] the webhook URL from Settings\WebhookURL.txt (full path), without BOM, spaces or line breaks.
; "" when there is no valid Discord webhook URL.
WH_URL() {
    u := ""
    try u := FileRead(A_ScriptDir "\Settings\WebhookURL.txt", "UTF-8")
    u := Trim(StrReplace(u, Chr(0xFEFF), ""), " `t`r`n")
    if RegExMatch(u, 'i)https?:\/\/discord\.com\/api\/webhooks\/(\d{18,19})\/[\w-]{68}', &m)
        return m[0]
    return ""
}
