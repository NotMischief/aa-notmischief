; [Auto update] checks GitHub for a newer version of the macro's CODE when the macro starts.
; Only code is replaced (Main.ahk, Lib, Images, the setup file). Settings, walks, map pictures, minimaps
; and logs on this computer are never touched. The old code is kept in "Backup (before update ...)".
;   Settings\AutoUpdate.txt   Auto (default) | Ask | Off
;   Auto: also checks every 15 min in the lobby / between Dungeon rooms (needs Watch mode on) and
;   installs there, then the usual Watch-mode reload carries on by itself.
;   Settings\UpdateRepo.txt   owner/repo (default NotMischief/aa-notmischief)
;   Settings\UpdateToken.txt  a read-only GitHub token - only needed while the repo is private

AU_ReadText(path, def) {
    try {
        v := Trim(FileRead(path, "UTF-8"), " `t`r`n" Chr(0xFEFF))
        if (v != "")
            return v
    }
    return def
}
AU_Setting(file, def) => AU_ReadText(A_ScriptDir "\Settings\" file, def)
AU_Repo() => AU_Setting("UpdateRepo.txt", "NotMischief/aa-notmischief")
AU_LocalVersion() => AU_ReadText(A_ScriptDir "\VERSION.txt", "0")

AU_Mode() => StrLower(AU_Setting("AutoUpdate.txt", "Auto"))

AU_Start() {
    if (AU_Mode() = "off")
        return
    rf := A_ScriptDir "\Settings\WatchResume.txt"   ; reloaded by Watch mode mid-run: the lobby check handles updates
    try {
        if (FileExist(rf) && DateDiff(A_Now, FileGetTime(rf, "M"), "Seconds") < 300)
            return
    }
    SetTimer(AU_Check, -4000)   ; a few seconds after start-up, so the window is up first
}

; GET a GitHub API url. Returns the WinHttp request (Status/ResponseText/ResponseBody), or 0.
AU_Get(url, accept) {
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", url, false)
        req.SetTimeouts(5000, 5000, 10000, 90000)
        req.SetRequestHeader("User-Agent", "AA-NotMischief-Updater")
        req.SetRequestHeader("Accept", accept)
        tok := AU_Setting("UpdateToken.txt", "")
        if (tok != "")
            req.SetRequestHeader("Authorization", "Bearer " tok)
        req.Send()
        return req
    }
    return 0
}

AU_Check() {
    repo := AU_Repo()
    req := AU_Get("https://api.github.com/repos/" repo "/contents/VERSION.txt", "application/vnd.github.raw")
    if (!req || req.Status != 200) {
        st := req ? req.Status : "no connection"
        if (st = 404)
            AddToLog("[Update] Couldn't see the update repo (private? put a token in Settings\UpdateToken.txt)")
        else
            AddToLog("[Update] Couldn't check for updates (" st ")")
        return
    }
    remote := Trim(req.ResponseText, " `t`r`n")
    localV := AU_LocalVersion()
    if !RegExMatch(remote, "^\d{4}\.\d\d\.\d\d\.\d{4}$")
        return
    if (StrCompare(remote, localV) <= 0) {
        AddToLog("[Update] Macro is up to date (" localV ")")
        return
    }
    if (AU_Mode() != "auto") {
        ans := MsgBox("A newer version of the macro is out.`n`nThis computer: " localV "`nNew: " remote
            . "`n`nUpdate now? Only the code is replaced - your settings, walks and maps stay."
            . "`n(No answer in 30 s = not now.)", "AA NotMischef - Update", "YesNo Iconi T30")
        if (ans != "Yes") {
            AddToLog("[Update] Update " remote " skipped for now")
            return
        }
    }
    AU_Install(repo, remote)
}

; [Watch mode] called at the lobby / between Dungeon rooms. Auto mode only, at most every 15 minutes.
; Installs without reloading - Watch mode sees the new code and reloads with "carry on by itself".
AU_LobbyCheck() {
    static last := 0
    if (AU_Mode() != "auto" || (last && A_TickCount - last < 900000))
        return false
    last := A_TickCount
    repo := AU_Repo()
    req := AU_Get("https://api.github.com/repos/" repo "/contents/VERSION.txt", "application/vnd.github.raw")
    if (!req || req.Status != 200)
        return false
    remote := Trim(req.ResponseText, " `t`r`n")
    if (!RegExMatch(remote, "^\d{4}\.\d\d\.\d\d\.\d{4}$") || StrCompare(remote, AU_LocalVersion()) <= 0)
        return false
    return AU_Install(repo, remote, false)
}

AU_Install(repo, remote, doReload := true) {
    AddToLog("[Update] Downloading " remote "...")
    req := AU_Get("https://api.github.com/repos/" repo "/zipball/main", "application/vnd.github+json")
    if (!req || req.Status != 200) {
        AddToLog("[Update] Download failed (" (req ? req.Status : "no connection") ") - nothing changed")
        return false
    }
    zip := A_Temp "\aa_notmischief_update.zip"
    out := A_Temp "\aa_notmischief_update"
    try {
        try FileDelete(zip)
        try DirDelete(out, true)
        s := ComObject("ADODB.Stream")
        s.Type := 1
        s.Open()
        s.Write(req.ResponseBody)
        s.SaveToFile(zip, 2)
        s.Close()
        cmd := Format('powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath `'{1}`' -DestinationPath `'{2}`' -Force"', zip, out)
        RunWait(cmd, , "Hide")
    } catch as e {
        AddToLog("[Update] Couldn't unpack the update (" e.Message ") - nothing changed")
        return false
    }
    src := ""
    loop files out "\*", "D"
        src := A_LoopFileFullPath
    if (src = "" || !FileExist(src "\Main.ahk") || !DirExist(src "\Lib")) {
        AddToLog("[Update] The download didn't look like the macro - nothing changed")
        return false
    }
    ; keep the current code, so a bad update can be undone (only the 3 newest backups are kept)
    bak := A_ScriptDir "\Backup (before update " FormatTime(, "yyyy-MM-dd HHmm") ")"
    try {
        DirCreate(bak)
        DirCopy(A_ScriptDir "\Lib", bak "\Lib", 1)
        try DirCopy(A_ScriptDir "\Images", bak "\Images", 1)
        FileCopy(A_ScriptDir "\Main.ahk", bak "\Main.ahk", 1)
        try FileCopy(A_ScriptDir "\VERSION.txt", bak "\VERSION.txt", 1)
    } catch as e {
        AddToLog("[Update] Couldn't back up the current code (" e.Message ") - not updating")
        return false
    }
    list := ""
    loop files A_ScriptDir "\Backup (before update *", "D"
        list .= A_LoopFileFullPath "`n"
    if (list != "") {
        arr := StrSplit(Sort(RTrim(list, "`n")), "`n")
        while (arr.Length > 3)
            try DirDelete(arr.RemoveAt(1), true)
    }
    try {
        DirCopy(src "\Lib", A_ScriptDir "\Lib", 1)
        if DirExist(src "\Images")
            DirCopy(src "\Images", A_ScriptDir "\Images", 1)
        FileCopy(src "\Main.ahk", A_ScriptDir "\Main.ahk", 1)
        FileCopy(src "\VERSION.txt", A_ScriptDir "\VERSION.txt", 1)
        if FileExist(src "\Setup (first time).bat")
            FileCopy(src "\Setup (first time).bat", A_ScriptDir "\Setup (first time).bat", 1)
    } catch as e {
        AddToLog("[Update] Copying the new code failed (" e.Message ") - the old code is in " bak)
        return false
    }
    try FileSetTime(A_Now, A_ScriptDir "\Main.ahk")   ; so Watch mode sees the code as new
    if !doReload {
        AddToLog("[Update] Updated to " remote " - reloading in the lobby, it carries on by itself")
        return true
    }
    AddToLog("[Update] Updated to " remote " - restarting")
    Sleep(800)
    Reload()
    return true
}
