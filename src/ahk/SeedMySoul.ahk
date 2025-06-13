;────────────────────────────────────────────────────────────────────────────
;  SeedMySoul – Auto-join for Hell Let Loose
;  v1.0.1-beta7  ·  2025-06-12  (one-and-done, v2-correct)
;────────────────────────────────────────────────────────────────────────────
#Requires AutoHotkey v2
#SingleInstance Off                 ; scheduler may try; script self-refuses
#Warn

;──── CONFIG – reference screen (2560×1440) ─────────────────────────────────
REF_W := 2560,  REF_H := 1440
ENLIST_REF_X := 168,  ENLIST_REF_Y := 776
;────────────────────────────────────────────────────────────────────────────

;──── CONSTANTS ─────────────────────────────────────────────────────────────
STEAM_EXE := "C:\Program Files (x86)\Steam\steam.exe"
HLL_APPID := 686810
HLL_EXE   := "hll-win64-shipping.exe"     ; change if yours differs
LOCKFILE  := A_Temp "\SeedMySoul.lock"
LOGFILE   := A_Desktop "\seedsoul_log.txt"
;────────────────────────────────────────────────────────────────────────────

;──── QUICK LOGGER ─────────────────────────────────────────────────────────
Log(txt) {
    FileAppend(FormatTime() " - " txt "`n", LOGFILE)
}

;──── PREVENT DUPLICATE INSTANCES (lock-file) ──────────────────────────────
if FileExist(LOCKFILE) {
    ; Check if lockfile is old (more than 10 minutes)
    fileTime := FileGetTime(LOCKFILE, "M")
    currentTime := A_Now
    timeDiff := DateDiff(currentTime, fileTime, "Minutes")
    
    if (timeDiff < 10) {
        Log("Another recent instance detected → exiting")
        ExitApp
    } else {
        Log("Found old lockfile, cleaning up and continuing")
        FileDelete(LOCKFILE)
    }
}
FileAppend("lock", LOCKFILE)             ; create guard

try
{
    ;──── EXTRA GUARD – abort if game already open ─────────────────────────
    if ProcessExist(HLL_EXE) {
    Log("HLL already running – proceeding with automation")
} else {
    Log("Launching HLL via Steam")
    Run('"' STEAM_EXE '" -applaunch ' HLL_APPID)
    if !WinWait("ahk_class UnrealWindow", , 120)
        throw Error("HLL window not found after 120 s")
    WinActivate("ahk_class UnrealWindow")
    WinWaitActive("ahk_class UnrealWindow", , 10)
    Log("HLL window found and activated")
}

    ;──── CLI ARG CHECK ────────────────────────────────────────────────────
    if A_Args.Length < 2
        throw ValueError("missing CLI arguments")
    serverName := A_Args[1]
    serverPop  := A_Args[2]
    Log("Args OK – server '" serverName "'  pop " serverPop)

    ;──── LAUNCH HLL VIA STEAM ─────────────────────────────────────────────
    Run('"' STEAM_EXE '" -applaunch ' HLL_APPID)
    Log("Launched HLL via Steam")

    if !WinWait("ahk_class UnrealWindow", , 120)
        throw Error("HLL window not found after 120 s")
    WinActivate("ahk_class UnrealWindow")
    WinWaitActive("ahk_class UnrealWindow", , 10)
    Log("HLL window found and activated")

    ;──── RESOLUTION HELPER ───────────────────────────────────────────────
    scrW := A_ScreenWidth,  scrH := A_ScreenHeight
    
    Scaled(x, y) {
        return [Floor(x*scrW/REF_W), Floor(y*scrH/REF_H)]
    }

    enlist := Scaled(ENLIST_REF_X, ENLIST_REF_Y)
    Log("Screen " scrW "×" scrH " – Enlist @ " enlist[1] "," enlist[2])

    ;──── INITIAL DELAY ───────────────────────────────────────────────────
    Log("Waiting 60 s for HLL to initialise…")
    Sleep 60000

    ;──── SPLASH / LEGAL BYPASS (30 s cap) ────────────────────────────────
    start := A_TickCount
    while (A_TickCount - start < 30000)
    {
        Log("Bypassing splash")
        WinActivate("ahk_class UnrealWindow")
        WinWaitActive("ahk_class UnrealWindow", , 5)
        SendInput("{Enter}")
        Sleep 200
        SendInput("{Space}")
        Sleep 200
        Click(scrW//2, scrH//2)
        Sleep 500
    }
    Log("Finished splash bypass")

    ;──── MAIN MENU DELAY ─────────────────────────────────────────────────
    Log("Waiting 20 s for main menu…")
    Sleep 20000

    ;──── CLICK "ENLIST" ──────────────────────────────────────────────────
    Log("Clicking Enlist")
    Click(enlist*)
    Sleep 200
    Click(enlist*)                             ; double-tap
    Sleep 30000                                ; allow server list load

    ;──── SEARCH BAR & SERVER NAME ────────────────────────────────────────
    search := Scaled(1262, 263)
    Log("Typing server name")
    Click(search*)
    Sleep 300
    SendInput("^a{Delete}")
    Sleep 300
    SendInput(serverName)
    Sleep 7000

    ;──── DOUBLE-CLICK FIRST ROW & JOIN ───────────────────────────────────
    Log("Selecting first server row")
    Click(scrW//2, Floor(scrH*0.40), , 2)

    join := Scaled(1954, 490)
    Log("Clicking Join")
    Click(join*)
    Log("Pressed Join – automation complete")

    ;──── FINAL SAFETY – brief freeze & terminate ────────────────────────
    BlockInput(True)
    Sleep 250
    BlockInput(False)

    Suspend(True)                  ; disable residual hotkeys/clicks
}
catch Error as e
{
    Log("ERROR: " e.Message)
}
finally
{
    FileDelete(LOCKFILE)           ; always release lock
    ExitApp
}