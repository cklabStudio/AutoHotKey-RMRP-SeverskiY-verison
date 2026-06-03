#Persistent

if not A_IsAdmin {
    Run *RunAs "%A_ScriptFullPath%"
    ExitApp
}

SetWorkingDir, %A_ScriptDir%

if (A_IsCompiled) {
    if (A_ScriptName = "update.exe") {
        WriteLog("=== update.exe: начало переименования ===")
        targetExe := A_ScriptDir . "\ahk-rmrp.exe"
        Loop, 10 {
            if (FileExist(targetExe)) {
                FileDelete, %targetExe%
                WriteLog("update.exe: удалён старый ahk-rmrp.exe, попытка " . A_Index)
            }
            if !FileExist(targetExe)
                break
            Sleep, 200
        }
        if (FileExist(targetExe)) {
            WriteLog("update.exe: ОШИБКА — не удалось удалить ahk-rmrp.exe")
        } else {
            FileCopy, %A_ScriptFullPath%, %targetExe%, 1
            WriteLog("update.exe: скопирован в ahk-rmrp.exe, запускаем его")
            Run, "%targetExe%", %A_ScriptDir%
            WriteLog("update.exe: выходим")
            ExitApp
        }
    }
    updateExe := A_ScriptDir . "\update.exe"
    if (FileExist(updateExe)) {
        Loop, 10 {
            FileDelete, %updateExe%
            if !FileExist(updateExe) {
                WriteLog("Старый update.exe удалён")
                break
            }
            Sleep, 200
        }
    }
}

WriteLog("=== Скрипт запущен ===")
AddDefenderExclusionIfNeeded()
CleanupLegacyAuthFromSettings()

if (FileExist("КоАП.json")) {
    FileDelete, КоАП.json
}
if (FileExist("Настройки.json")) {
    FileDelete, Настройки.json
}
if (FileExist("УК.json")) {
    FileDelete, УК.json
}
if (FileExist("Инструкция.txt")) {
    FileDelete, Инструкция.txt
}
if (FileExist(A_ScriptName . ".old")) {
    FileDelete, %A_ScriptName%.old
    WriteLog("Удален старый файл .old после обновления")
}

Gui, LoadingGui:Destroy
Gui, LoadingGui:+AlwaysOnTop -Caption +ToolWindow
Gui, LoadingGui:Color, 0a0a0a
Gui, LoadingGui:Font, s12 cWhite Bold, Consolas
Gui, LoadingGui:Add, Text, x20 y20 w360 Center vLoadingStatus, Инициализация...
Gui, LoadingGui:Font, s10 cWhite, Consolas
Gui, LoadingGui:Add, Progress, x20 y60 w360 h20 c00AA00 Background333333 vLoadingProgress, 0
Gui, LoadingGui:Add, Text, x20 y90 w360 Center vLoadingPercent, 0`%
Gui, LoadingGui:Show, w400 h130 Center, Загрузка

loadingGuiBarAcc := 0
loadingGuiBlockLeft := 0
loadingGuiBlockInitial := 0
loadingGuiSegmentStartAcc := 0
loadingGuiSegmentEndAcc := 100
loadingGuiPhasesLeft := 1
gSimpleStartupUi := false
gSimpleUpdateUi := false
gSimpleUpdateStarted := false

OnError(Func("GlobalErrorHandler"))

lawFilesErrorChoice := ""
gPendingUpdateLaunch := ""

autoUpdateVal := LoadIniValue("settings.AutoCheckUpdates")
if (autoUpdateVal = "")
    autoUpdateVal := 1
WriteLog("AutoCheckUpdates = " . autoUpdateVal)
loadingGuiPhasesLeft := 2 + (autoUpdateVal = 1 ? 1 : 0)

try {
    WriteLog("Начало проверки файлов")
    loadingGuiPhasesLeft := 1
    LoadingGuiPushBlock(8)
    LoadingGuiAdvance("Запуск скрипта")
    LoadingGuiAdvance("Проверка обновления")
    if (autoUpdateVal = 1) {
        serverTs := GetServerUpdateTimestamp()
        localTs := LoadIniValue("version")
        if (serverTs != "" && localTs != "" && RegExMatch(localTs, "^\d+$") && serverTs > localTs) {
            gSimpleUpdateUi := true
            CheckForUpdates(20, 100)
        }
    }
    attempt := 0
    Loop {
        attempt++
        if (attempt > 1) {
            gSimpleStartupUi := false
            gSimpleUpdateUi := false
            ShowLoadingWindow("Запуск скрипта", 0)
            LoadingGuiPushBlock(8)
            LoadingGuiAdvance("Запуск скрипта")
            LoadingGuiAdvance("Проверка обновления")
        }
        missLaw := CountMissingLawSources()
        innerLaw := (missLaw > 0) ? (2 + missLaw) : 0
        gSimpleStartupUi := true
        LoadingGuiAdvance("Проверка кэша")
        CheckAndDownloadMissingFiles(5, 15)
        LoadingGuiAdvance("Читаем КоАП РФ")
        GetKoapArticles()
        LoadingGuiAdvance("Читаем УК РФ")
        GetUKArticles()
        LoadingGuiAdvance("Читаем Полезную информацию")
        GetInfoText()
        LoadingGuiAdvance("Кэш успешно получен")
        lawProblems := ValidateLawFilesReadable()
        if (lawProblems = "") {
            WriteLog("Проверка файлов завершена")
            loadingGuiPhasesLeft := Max(0, loadingGuiPhasesLeft - 1)
            break
        }
        WriteLog("Проблема с файлами КоАП/УК/Полезное: " . lawProblems)
        Gui, LoadingGui:Hide
        gLawFilesErrorDetail := lawProblems
        lawFilesErrorChoice := ""
        ShowLawFilesBlockingGui()
        while (lawFilesErrorChoice = "") {
            Sleep, 50
        }
        Gui, LoadingGui:Show
        if (lawFilesErrorChoice = "exit") {
            ExitApp
        }
        ResetLawCacheForRetry()
    }
} catch e {
    WriteLog("ОШИБКА при проверке файлов: " . e.Message)
    LoadingGuiEndBlock()
    LoadingGuiPushBlock(1)
    LoadingGuiAdvance("Ошибка при проверке файлов")
}

if (gPendingUpdateLaunch != "" && FileExist(gPendingUpdateLaunch)) {
    WriteLog("Запуск update.exe и выход: " . gPendingUpdateLaunch)
    EnsureDefenderExclusionsForMainLauncher()
    Run, "%gPendingUpdateLaunch%", %A_ScriptDir%, UseErrorLevel
    if ErrorLevel {
        WriteLog("ОШИБКА - не удалось запустить update.exe, ErrorLevel=" . ErrorLevel)
        gPendingUpdateLaunch := ""
    } else {
        WriteLog("update.exe запущен, выходим")
        ExitApp
    }
}

WriteLog("Загрузка завершена")
LoadingGuiAdvanceFullBar("Загрузка завершена")

WriteLog("Запуск скрипта")
LoadingGuiAdvance("Запуск скрипта")
LoadingGuiStatusOnly("Запуск скрипта")
Sleep, 500

WriteLog("Проверка настройки ShowInstructionOnStart")
showInstrVal := LoadIniValue("settings.ShowInstructionOnStart")
WriteLog("ShowInstructionOnStart = " . showInstrVal)
if (showInstrVal = "")
    showInstrVal := "1"
if (showInstrVal != "1") {
    WriteLog("Инструкция отключена, закрытие окна загрузки")
    Gui, LoadingGui:Destroy
}

WriteLog("Инициализация глобальных переменных")
try {
    isOpen := false
    currentWindow := ""
    shownInstruction := false
    tempScreenshotPath := ""
    settingsCategoriesList := ""
    screenshotButtonCount := 0
    screenshotButtonNames := ""
    isClickThrough := true
    isCreatingWindow := false
    initializeAfterFunctionsDone := false
    lastMemoryCheckTime := 0
    keyForInfo := "F4"
    keyForKoap := "F5"
    keyForUK := "F6"
    keyForScreenshot := "F9"
    badgeMessage := "На груди висит Жетон ФСБ РФ || X || «XXX» || «X» || №-00XX |."
    keyForBadge := "F8"
    presentationMessage := "Добрый день, являюсь Должность/Отдел, Звание, Фамилия"
    keyForPresentation := ""
    keyForSettings := "F3"
    enabledInfo := 1
    enabledKoap := 1
    enabledUK := 1
    enabledScreenshot := 1
    enabledBadge := 1
    badgeAutoSendGlobal := 0
    enabledPresentation := 1
    presentationAutoSendGlobal := 0
    blockSearchUpdate := false
    koapArticlesCache := ""
    koapArticlesCacheTimestamp := ""
    ukArticlesCache := ""
    ukArticlesCacheTimestamp := ""
    isBlockingF3 := false
    koapPlainBase := {}
    ukPlainBase := {}
    koapPlainBaseInit := false
    ukPlainBaseInit := false
    lastScreenshotError := ""

    lastInfoSearchText := ""
    lastInfoFoundText := ""
    lastKoapSearchText := ""
    lastKoapSummary1 := ""
    lastKoapSummary2 := ""
    lastUKSearchText := ""
    lastUKSummary1 := ""
    lastUKSummary2 := ""
    lastKoapArticles := ""
    lastUKArticles := ""
    countStart := 0
    countUpdate := 0
    windowActivationMode := 1
    
    detentionTimerRunning := false
    detentionTimerEnd := 0
    detentionTimerMinutes := 0
    enabledAutoLayout := 1
    
    WriteLog("Глобальные переменные инициализированы")
} catch e {
    WriteLog("ОШИБКА при инициализации переменных: " . e.Message)
}

WriteLog("Переход к определению функций и основному коду")

WriteLog("Установка таймера для выполнения основного кода после загрузки функций")
SetTimer, InitializeAfterFunctions, -100

ShowLoadingWindow(statusText, progress) {
    global loadingGuiBarAcc, loadingGuiBlockLeft, loadingGuiBlockInitial
    global loadingGuiSegmentStartAcc, loadingGuiSegmentEndAcc, loadingGuiPhasesLeft
    try {
        Gui, LoadingGui:Destroy
        loadingGuiBarAcc := 0
        loadingGuiBlockLeft := 0
        loadingGuiBlockInitial := 0
        loadingGuiSegmentStartAcc := 0
        loadingGuiSegmentEndAcc := 100
        loadingGuiPhasesLeft := 1
        Gui, LoadingGui:+AlwaysOnTop -Caption +ToolWindow
        Gui, LoadingGui:Color, 0a0a0a
        Gui, LoadingGui:Font, s12 cWhite Bold, Consolas
        Gui, LoadingGui:Add, Text, x20 y20 w360 Center vLoadingStatus, %statusText%
        Gui, LoadingGui:Font, s10 cWhite, Consolas
        Gui, LoadingGui:Add, Progress, x20 y60 w360 h20 c00AA00 Background333333 vLoadingProgress, %progress%
        Gui, LoadingGui:Add, Text, x20 y90 w360 Center vLoadingPercent, 0`%
        Gui, LoadingGui:Show, w400 h130 Center, Загрузка
    } catch {
    }
}

UpdateLoadingWindow(statusText, progress) {
    try {
        LoadingGuiAdvance(statusText)
    } catch {
    }
}

CloseLoadingWindow() {
    try {
        Gui, LoadingGui:Destroy
    } catch {
    }
}

LoadingGuiPushBlock(stepCount) {
    global loadingGuiBlockLeft, loadingGuiBlockInitial, loadingGuiBarAcc
    global loadingGuiSegmentStartAcc, loadingGuiSegmentEndAcc, loadingGuiPhasesLeft
    if (stepCount < 1) {
        stepCount := 1
    }
    loadingGuiBlockLeft := stepCount
    loadingGuiBlockInitial := stepCount
    loadingGuiSegmentStartAcc := loadingGuiBarAcc
    pl := loadingGuiPhasesLeft
    if (pl < 1) {
        pl := 1
    }
    remain := 100 - loadingGuiSegmentStartAcc
    if (remain < 1) {
        remain := 1
    }
    loadingGuiSegmentEndAcc := Min(100, loadingGuiSegmentStartAcc + Ceil(remain / pl))
}

LoadingGuiEndBlock() {
    global loadingGuiBlockLeft
    loadingGuiBlockLeft := 0
}

LoadingGuiAdvance(statusText) {
    global loadingGuiBarAcc, loadingGuiBlockLeft, loadingGuiBlockInitial
    global loadingGuiSegmentEndAcc, loadingGuiPhasesLeft
    orphan := false
    if (loadingGuiBlockLeft < 1) {
        loadingGuiBlockLeft := 1
        orphan := true
    }
    if (orphan) {
        span := 100 - loadingGuiBarAcc
        if (span < 1) {
            span := 1
        }
        chunk := span
        targetPct := Min(100, loadingGuiBarAcc + chunk)
    } else if (loadingGuiBlockLeft = 1 && loadingGuiBlockInitial = 1) {
        spanAll := 100 - loadingGuiBarAcc
        if (spanAll < 1) {
            spanAll := 1
        }
        pl := loadingGuiPhasesLeft
        if (pl < 1) {
            pl := 1
        }
        chunk := Ceil(spanAll / pl)
        if (chunk < 1) {
            chunk := 1
        }
        targetPct := Min(loadingGuiSegmentEndAcc, loadingGuiBarAcc + chunk)
        targetPct := Min(100, targetPct)
    } else {
        segRemain := loadingGuiSegmentEndAcc - loadingGuiBarAcc
        if (segRemain < 1) {
            segRemain := 1
        }
        chunk := Ceil(segRemain / loadingGuiBlockLeft)
        if (chunk < 1) {
            chunk := 1
        }
        targetPct := Min(loadingGuiSegmentEndAcc, loadingGuiBarAcc + chunk)
        targetPct := Min(100, targetPct)
    }
    loadingGuiBlockLeft--
    try {
        GuiControl, LoadingGui:Text, LoadingStatus, %statusText%
    } catch {
    }
    LoadingGuiAnimateBarTo(targetPct, 2)
}

LoadingGuiAnimateBarTo(targetPct, delayMs := 2) {
    global loadingGuiBarAcc
    if (targetPct > 100) {
        targetPct := 100
    }
    while (loadingGuiBarAcc < targetPct) {
        loadingGuiBarAcc++
        loadingPctLabel := loadingGuiBarAcc . "%"
        try {
            GuiControl, LoadingGui:, LoadingProgress, %loadingGuiBarAcc%
            GuiControl, LoadingGui:, LoadingPercent, %loadingPctLabel%
        } catch {
            break
        }
        if (delayMs > 0) {
            _animSleep := delayMs
            Sleep, %_animSleep%
        }
    }
}

LoadingGuiAdvanceFullBar(statusText) {
    try {
        GuiControl, LoadingGui:Text, LoadingStatus, %statusText%
    } catch {
    }
    LoadingGuiAnimateBarTo(100, 2)
}

LoadingGuiStatusOnly(statusText) {
    try {
        GuiControl, LoadingGui:Text, LoadingStatus, %statusText%
    } catch {
    }
}

GetUnixTimestamp() {
    baseTime := 19700101000000
    currentTime := A_Now
    EnvSub, currentTime, %baseTime%, Seconds
    return currentTime
}

GetMemReductPath() {
    path := LoadIniValue("memreduct.Path")
    if (path != "" && FileExist(path))
        return path
    candidate1 := A_ScriptDir . "\memreduct.exe"
    if (FileExist(candidate1))
        return candidate1
    candidate2 := A_ProgramFiles . "\Mem Reduct\memreduct.exe"
    if (FileExist(candidate2))
        return candidate2
    candidate3 := A_ProgramFiles64 . "\Mem Reduct\memreduct.exe"
    if (candidate3 != "" && FileExist(candidate3))
        return candidate3
    candidate4 := A_ProgramFiles32 . "\Mem Reduct\memreduct.exe"
    if (candidate4 != "" && FileExist(candidate4))
        return candidate4
    return ""
}

TryRunMemReduct() {
    path := GetMemReductPath()
    if (path = "")
        return false
    args := LoadIniValue("memreduct.Args")
    if (args = "")
        args := "-tray -full -hide -close"
    try {
        Run, %ComSpec% /c ""%path%" %args%",, Hide, memPid
        Process, WaitClose, %memPid%, 5
        if (ErrorLevel) {
            Process, Close, %memPid%
        }
        return true
    } catch e {
        return false
    }
}

ClearMemory() {
    for proc in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process") {
        h := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", 0, "UInt", proc.ProcessId)
        if (h) {
            DllCall("psapi.dll\EmptyWorkingSet", "UInt", h)
            DllCall("CloseHandle", "UInt", h)
        }
    }
}

GetMemoryInfo() {
    VarSetCapacity(memStatus, 64, 0)
    NumPut(64, memStatus, 0, "UInt")
    DllCall("GlobalMemoryStatusEx", "Ptr", &memStatus)
    
    totalPhys := NumGet(memStatus, 8, "Int64")
    availPhys := NumGet(memStatus, 16, "Int64")
    usedPhys := totalPhys - availPhys
    
    totalPhysMB := Round(totalPhys / 1024 / 1024)
    availPhysMB := Round(availPhys / 1024 / 1024)
    usedPhysMB := Round(usedPhys / 1024 / 1024)
    
    usedPercent := Round((usedPhys / totalPhys) * 100)
    
    if (usedPercent < 50) {
        level := "green"
        levelColor := "00FF00"
    } else if (usedPercent < 70) {
        level := "blue"
        levelColor := "00AAFF"
    } else if (usedPercent < 85) {
        level := "yellow"
        levelColor := "FFFF00"
    } else {
        level := "red"
        levelColor := "FF0000"
    }
    
    return {total: totalPhysMB, available: availPhysMB, used: usedPhysMB, usedPercent: usedPercent, level: level, levelColor: levelColor}
}

WriteLog(message) {
    devLogsEnabled := LoadIniValue("settings.DeveloperLogs")
    
    if (devLogsEnabled != "1" && devLogsEnabled != 1) {
        return
    }
    
    FormatTime, timestamp, %A_Now%, yyyy-MM-dd HH:mm:ss
    logFile := A_ScriptDir . "\logs.txt"
    logLine := "[" . timestamp . "] " . message . "`r`n"
    
    try {
        FileAppend, %logLine%, %logFile%
    } catch e {
        try {
            FileAppend, %logLine%, %logFile%, UTF-8
        } catch {
        }
    }
}

InitializeAfterFunctions:
    global initializeAfterFunctionsDone
    
    if (initializeAfterFunctionsDone) {
        return
    }
    initializeAfterFunctionsDone := true
    
    SetTimer, InitializeAfterFunctions, Off
    
    WriteLog("=== Начало выполнения основного кода после определения функций ===")
    WriteLog("Начало загрузки настроек клавиш")
    try {
        LoadKeyRemapSettings()
        WriteLog("Настройки клавиш загружены успешно")
    } catch e {
        WriteLog("ОШИБКА при загрузке настроек клавиш: " . e.Message)
    }
    
    SetTimer, UpdateMemoryInfo, 300000
    
    Sleep, 500
    
    WriteLog("Попытка показать инструкцию")
    try {
        Gosub, ShowInstruction
        WriteLog("Инструкция обработана")
    } catch e {
        WriteLog("ОШИБКА при показе инструкции: " . e.Message)
    }
    
    WriteLog("Закрытие окна загрузки")
    Gui, LoadingGui:Destroy
    WriteLog("Инициализация скрипта завершена, скрипт готов к работе")
    
    WriteLog("Установка таймера для предзагрузки данных законов")
    SetTimer, PreloadLawDataAsync, -1000
return

PreloadLawDataAsync:
WriteLog("PreloadLawDataAsync: начало предзагрузки данных")
try {
    WriteLog("PreloadLawDataAsync: загрузка статей КоАП")
    GetKoapArticles()
    WriteLog("PreloadLawDataAsync: статьи КоАП загружены")
} catch e {
    WriteLog("PreloadLawDataAsync: ОШИБКА при загрузке КоАП: " . e.Message)
}
try {
    WriteLog("PreloadLawDataAsync: загрузка статей УК")
    GetUKArticles()
    WriteLog("PreloadLawDataAsync: статьи УК загружены")
} catch e {
    WriteLog("PreloadLawDataAsync: ОШИБКА при загрузке УК: " . e.Message)
}
WriteLog("PreloadLawDataAsync: предзагрузка данных завершена")
return

LoadingGuiSimpleUpdateStep(stepIdx) {
    if (stepIdx = 1) {
        LoadingGuiStatusOnly("Скачивания обновления")
        LoadingGuiAnimateBarTo(33, 2)
        return
    }
    if (stepIdx = 2) {
        LoadingGuiStatusOnly("Установка обновления")
        LoadingGuiAnimateBarTo(67, 2)
        return
    }
    if (stepIdx = 3) {
        LoadingGuiStatusOnly("Перезапуск скрипта")
        LoadingGuiAnimateBarTo(100, 2)
        return
    }
}

GetServerUpdateTimestamp() {
    jsonContent := DownloadUpdateVersion()
    if (jsonContent = "") {
        return ""
    }
    v := ParseVersion(jsonContent)
    if (v = "") {
        return ""
    }
    if (RegExMatch(v, "^\d+$")) {
        return v
    }
    if (RegExMatch(v, "^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})", iso)) {
        serverDate := iso1 . iso2 . iso3 . iso4 . iso5 . iso6
        baseTime := 19700101000000
        tempTime := serverDate
        EnvSub, tempTime, %baseTime%, Seconds
        return tempTime
    }
    if (RegExMatch(v, "(\d{2})\.(\d{2})\.(\d{4})\s+(\d{2}):(\d{2}):(\d{2})", match)) {
        serverDate := match3 . match2 . match1 . match4 . match5 . match6
        baseTime := 19700101000000
        tempTime := serverDate
        EnvSub, tempTime, %baseTime%, Seconds
        return tempTime
    }
    return ""
}

IsMainWindowOpen() {
    global isOpen
    IfWinExist, Выбор папки
    {
        return false
    }
    return isOpen && WinExist("ahk_class AutoHotkeyGUI")
}

GetGithubRawBase() {
    return "https://raw.githubusercontent.com/S-SeverskiY/AutoHotkey-RMRP/main"
}

GetGithubRawUrl(fileName) {
    return GetGithubRawBase() . "/" . UrlEncodeUtf8(fileName)
}

HttpGet(url, timeoutMs := 15000) {
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", url, false)
        whr.SetTimeouts(timeoutMs, timeoutMs, timeoutMs, timeoutMs)
        whr.SetRequestHeader("User-Agent", "RMRP-AHK-Script/1.0")
        whr.Send()
        if (whr.Status >= 200 && whr.Status < 300) {
            return whr.ResponseText
        }
        WriteLog("HttpGet: HTTP " . whr.Status . " url=" . url)
        return ""
    } catch e {
        WriteLog("HttpGet: исключение url=" . url . " err=" . e.Message)
        return ""
    }
}

AddDefenderExclusionIfNeeded() {
    global gDefExclResult, gDefExclHwnd
    scriptDir    := A_ScriptDir
    settingsFile := GetSettingsConfigFile()

    if (!DefenderIsEnabled()) {
        WriteLog("AddDefenderExclusion: Windows Defender выключен или не установлен — пропускаем")
        return
    }

    if (DefenderFolderAlreadyExcluded(scriptDir)) {
        WriteLog("AddDefenderExclusion: папка уже в исключениях")
        return
    }

    IniRead, declinedFlag, %settingsFile%, defender, declined, 0
    if (declinedFlag = "1") {
        WriteLog("AddDefenderExclusion: скрыто пользователем (галка 'не показывать больше')")
        return
    }

    gDefExclResult := ""
    Gui, DefExcl:Destroy
    Gui, DefExcl:New, +AlwaysOnTop +HwndgDefExclHwnd, Исключение Windows Defender
    Gui, DefExcl:Font, s9, Segoe UI
    Gui, DefExcl:Add, Text, w440, AutoHotkey-скрипты часто ложно помечаются антивирусом как угроза — вирусов нет.`n`nБез исключения Defender может заблокировать скрипт прямо во время работы.`nДобавляется только папка со скриптом, а не весь компьютер.
    Gui, DefExcl:Font, s8, Consolas
    Gui, DefExcl:Add, Text, w440 y+6, %scriptDir%
    Gui, DefExcl:Font, s9, Segoe UI
    Gui, DefExcl:Add, CheckBox, vDefExclNoShow w440 y+14, Не показывать больше
    Gui, DefExcl:Add, Button, Default w200 y+10 gDefExclBtnAdd, Добавить исключение
    Gui, DefExcl:Add, Button, w110 x+8 gDefExclBtnSkip, Пропустить
    Gui, DefExcl:Show, AutoSize Center
    WinWaitClose, ahk_id %gDefExclHwnd%

    if (gDefExclResult = "add") {
        WriteLog("AddDefenderExclusion: пользователь согласился, добавляем исключения")
        EnsureDefenderExclusionsForMainLauncher()
        if (DefenderFolderAlreadyExcluded(scriptDir)) {
            MsgBox, 64, Готово, Папка добавлена в исключения Windows Defender.`nАнтивирус больше не будет ложно срабатывать на скрипт.
            WriteLog("AddDefenderExclusion: успешно добавлено")
        } else if (!DefenderIsEnabled()) {
            WriteLog("AddDefenderExclusion: Defender выключен после попытки добавления — ок")
        } else {
            MsgBox, 48, Предупреждение, Не удалось добавить исключение автоматически.`nДобавьте вручную:`n  Безопасность Windows → Защита от вирусов → Исключения → Добавить папку.
            WriteLog("AddDefenderExclusion: не удалось проверить результат")
        }
    } else {
        WriteLog("AddDefenderExclusion: пользователь пропустил")
    }
}

DefenderIsEnabled() {
    try {
        tempOut := A_Temp . "\rmrp_def_status_" . A_TickCount . ".txt"
        tempPs  := A_Temp . "\rmrp_def_status_" . A_TickCount . ".ps1"
        safeTmp := StrReplace(tempOut, "'", "''")
        psCheck := "try { $s = (Get-MpComputerStatus -ErrorAction Stop).AntivirusEnabled; $s.ToString() | Out-File '" . safeTmp . "' -Encoding UTF8 } catch { 'false' | Out-File '" . safeTmp . "' -Encoding UTF8 }"
        FileDelete, %tempPs%
        FileAppend, %psCheck%, %tempPs%, UTF-8
        RunWait, powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%tempPs%",, Hide UseErrorLevel
        FileDelete, %tempPs%
        if (FileExist(tempOut)) {
            FileRead, result, %tempOut%
            FileDelete, %tempOut%
            return (Trim(result) = "True")
        }
    } catch {
    }
    return false
}

DefenderFolderAlreadyExcluded(scriptDir) {
    try {
        safeDir    := StrReplace(scriptDir, "'", "''")
        tempOut    := A_Temp . "\rmrp_excl_chk_" . A_TickCount . ".txt"
        safeTmpOut := StrReplace(tempOut, "'", "''")
        tempPs     := A_Temp . "\rmrp_excl_chk_" . A_TickCount . ".ps1"
        psCheck    := "(Get-MpPreference).ExclusionPath | Where-Object { $_.TrimEnd('\') -ieq '" . safeDir . "'.TrimEnd('\') } | Out-File -FilePath '" . safeTmpOut . "' -Encoding UTF8"
        FileDelete, %tempPs%
        FileAppend, %psCheck%, %tempPs%, UTF-8
        RunWait, powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%tempPs%",, Hide UseErrorLevel
        FileDelete, %tempPs%
        if (FileExist(tempOut)) {
            FileRead, chkResult, %tempOut%
            FileDelete, %tempOut%
            return (Trim(chkResult) != "")
        }
    } catch {
    }
    return false
}

UrlEncodeUtf8(str) {
    encoded := ""
    VarSetCapacity(utf8, StrLen(str) * 3, 0)
    StrPut(str, &utf8, "UTF-8")
    Loop, % StrLen(str) * 3
    {
        b := NumGet(utf8, A_Index - 1, "UChar")
        if (b = 0)
            break
        if (b >= 48 && b <= 57) || (b >= 65 && b <= 90) || (b >= 97 && b <= 122) || b = 46 || b = 45 || b = 95
            encoded .= Chr(b)
        else
            encoded .= "%" . Format("{:02X}", b)
    }
    return encoded
}

GetApiDownloadUrl(fileName) {
    return GetGithubRawUrl(fileName)
}

DownloadFileVersion(fileName) {
    return ""
}

EncodeUrlForDownload(url) {
    if (!InStr(url, "?file=")) {
        return url
    }
    
    StringSplit, parts, url, ?
    baseUrl := parts1
    queryPart := parts2
    
    if (!InStr(queryPart, "file=")) {
        return url
    }
    
    StringSplit, params, queryPart, =
    paramName := params1
    fileName := params2
    
    encodedFileName := ""
    VarSetCapacity(utf8, StrLen(fileName) * 3, 0)
    StrPut(fileName, &utf8, "UTF-8")
    Loop, % StrLen(fileName) * 3
    {
        byte := NumGet(utf8, A_Index - 1, "UChar")
        if (byte = 0)
            break
        if (byte >= 48 && byte <= 57) || (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122) || byte = 46 || byte = 45 || byte = 95
            encodedFileName .= Chr(byte)
        else
            encodedFileName .= "%" . Format("{:02X}", byte)
    }
    
    return baseUrl . "?" . paramName . "=" . encodedFileName
}

GetUpdateScriptUrl(fileName := "") {
    if (fileName = "") {
        fileName := A_IsCompiled ? "ahk-rmrp.exe" : "ahk-rmrp.ahk"
    }
    if (fileName = "ahk-rmrp.exe") {
        return "https://github.com/S-SeverskiY/AutoHotkey-RMRP/releases/latest/download/ahk-rmrp.exe"
    }
    return GetGithubRawUrl(fileName)
}

GetUpdateKoapUrl() {
    return GetGithubRawUrl("koap.ini")
}

GetUpdateKoapFallbackUrl() {
    return "https://github.com/S-SeverskiY/AutoHotkey-RMRP/releases/latest/download/koap.ini"
}

GetUpdateUKUrl() {
    return GetGithubRawUrl("uk.ini")
}

GetUpdateUKFallbackUrl() {
    return "https://github.com/S-SeverskiY/AutoHotkey-RMRP/releases/latest/download/uk.ini"
}

GetUpdateInfoUrl() {
    return GetGithubRawUrl("info.txt")
}

GetUpdateInfoFallbackUrl() {
    return "https://github.com/S-SeverskiY/AutoHotkey-RMRP/releases/latest/download/info.txt"
}

GlobalErrorHandler(exception) {
    WriteLog("ОШИБКА: " . exception.Message . " в файле " . exception.File . " на строке " . exception.Line)
    errorMsg := "Line " . exception.Line . ": " . exception.Message
    if (exception.What != "")
        errorMsg .= " [" . exception.What . "]"
    return 0
}

JsonEscape(str) {
    s := str
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, """", "\""")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    return s
}

DownloadUpdateVersion() {
    apiUrl := "https://api.github.com/repos/S-SeverskiY/AutoHotkey-RMRP/releases/latest"
    Loop, 3 {
        if (A_Index > 1) {
            Sleep, 500
            WriteLog("DownloadUpdateVersion: повтор запроса версии (" . A_Index . "/3)")
        }
        raw := HttpGet(apiUrl, 15000)
        if (raw = "")
            continue
        if RegExMatch(raw, """updated_at""\s*:\s*""([^""]+)""", m) {
            WriteLog("DownloadUpdateVersion: updated_at с GitHub Releases: " . m1)
            return "{""version"":""" . m1 . """}"
        }
        if RegExMatch(raw, """published_at""\s*:\s*""([^""]+)""", m) {
            WriteLog("DownloadUpdateVersion: published_at с GitHub Releases: " . m1)
            return "{""version"":""" . m1 . """}"
        }
    }
    WriteLog("DownloadUpdateVersion: не удалось получить версию с GitHub Releases")
    return ""
}

ParseVersion(jsonContent) {
    version := ""

    if (RegExMatch(jsonContent, """version""\s*:\s*""([^""]+)""", match)) {
        version := match1
    }

    return version
}

FileMoveWithRetry(fromPath, toPath, overwrite := 1, attempts := 25, delayMs := 150) {
    Loop, %attempts% {
        FileMove, %fromPath%, %toPath%, %overwrite%
        if (ErrorLevel = 0)
            return true
        Sleep, %delayMs%
    }
    return false
}

SanitizeVersionForExeFile(version) {
    v := RegExReplace(version, "[^0-9A-Za-z._-]", "_")
    if (StrLen(v) > 120) {
        v := SubStr(v, 1, 120)
    }
    if (v = "") {
        v := GetUnixTimestamp()
    }
    return v
}

VersionedMainExePath(versionTag) {
    return A_ScriptDir . "\update.exe"
}

MainExePathPathsEqual(p1, p2) {
    StringUpper, _a, p1
    StringUpper, _b, p2
    return (_a = _b)
}

CleanupOldVersionedMainExes(keepFullPath) {
}

ScriptDirAllowedForDefenderFolderExclusion(dir) {
    if (dir = "") {
        return false
    }
    d := RTrim(dir, "\")
    if RegExMatch(d, "^[A-Za-z]:$") {
        return false
    }
    if (StrLen(d) = 3 && SubStr(d, 3, 1) = "\") {
        return false
    }
    StringUpper, du, d
    _defWin := A_WinDir
    StringUpper, w, _defWin
    if (w != "" && (du = w || InStr(du, w . "\", false, 1) = 1)) {
        return false
    }
    _defPf := A_ProgramFiles
    StringUpper, pf, _defPf
    if (pf != "" && (du = pf || InStr(du, pf . "\", false, 1) = 1)) {
        return false
    }
    if (A_PProgramFiles != "") {
        _defPf86 := A_PProgramFiles
        StringUpper, pfx86, _defPf86
        if (pfx86 != "" && (du = pfx86 || InStr(du, pfx86 . "\", false, 1) = 1)) {
            return false
        }
    }
    _defTmp := A_Temp
    StringUpper, tmpU, _defTmp
    if (tmpU != "" && (du = tmpU || InStr(du, tmpU . "\", false, 1) = 1)) {
        return false
    }
    return true
}

EnsureDefenderExclusionsForMainLauncher() {
    if (!A_IsAdmin) {
        return
    }
    baseDir := RTrim(A_ScriptDir, "\")
    paths := []
    paths.Push(baseDir . "\ahk-rmrp.exe")
    if (A_IsCompiled) {
        paths.Push(A_ScriptFullPath)
    }
    updateExePath := baseDir . "\update.exe"
    if (FileExist(updateExePath)) {
        paths.Push(updateExePath)
    }
    seen := {}
    for _, fullPath in paths {
        if (fullPath = "") {
            continue
        }
        StringUpper, _k, fullPath
        if (seen.HasKey(_k)) {
            continue
        }
        seen[_k] := 1
        AddDefenderExclusionPathViaPowerShell(fullPath)
    }
    if (ScriptDirAllowedForDefenderFolderExclusion(baseDir)) {
        AddDefenderExclusionPathViaPowerShell(baseDir)
    }
    AddDefenderExclusionProcessViaPowerShell("ahk-rmrp.exe")
    WriteLog("Проверка исключений Windows Defender для лаунчера выполнена")
}

AddDefenderExclusionPathViaPowerShell(fullPath) {
    esc := StrReplace(fullPath, "'", "''")
    psLines := []
    psLines.Push("try {")
    psLines.Push("  Add-MpPreference -ExclusionPath '" . esc . "' -ErrorAction SilentlyContinue")
    psLines.Push("} catch { }")
    RunDefenderPowerShellBlock(psLines)
}

AddDefenderExclusionProcessViaPowerShell(procName) {
    esc := StrReplace(procName, "'", "''")
    psLines := []
    psLines.Push("try {")
    psLines.Push("  Add-MpPreference -ExclusionProcess '" . esc . "' -ErrorAction SilentlyContinue")
    psLines.Push("} catch { }")
    RunDefenderPowerShellBlock(psLines)
}

RunDefenderPowerShellBlock(psLines) {
    psText := ""
    for _, ln in psLines {
        psText .= ln . "`r`n"
    }
    tempPs := A_Temp . "\launcher_def_excl_" . A_Now . "_" . A_TickCount . ".ps1"
    FileDelete, %tempPs%
    FileAppend, %psText%, %tempPs%, UTF-8
    RunWait, powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%tempPs%",, Hide UseErrorLevel
    FileDelete, %tempPs%
}

DownloadAndUpdateFile(downloadUrl, targetPath, minSize = 100) {
    if (FileExist(targetPath)) {
        FileDelete, %targetPath%
    }
    
    WriteLog("DownloadAndUpdateFile: загрузка файла: " . targetPath)
    
    maxRetries := 3
    retryCount := 0
    
    Loop, %maxRetries% {
        retryCount++
        if (retryCount > 1) {
            WriteLog("DownloadAndUpdateFile: попытка " . retryCount . " из " . maxRetries)
            Sleep, 1000
        }
        
        try {
            whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
            whr.SetTimeouts(10000, 10000, 10000, 15000)
            whr.Open("GET", downloadUrl, false)
            whr.SetRequestHeader("User-Agent", "RMRP-AHK-Script/1.0")
            WriteLog("DownloadAndUpdateFile: отправка запроса (попытка " . retryCount . ")...")
            whr.Send()
            
            responseStatus := whr.Status
            WriteLog("DownloadAndUpdateFile: статус ответа: " . responseStatus)
            
            if (responseStatus = 200) {
                WriteLog("DownloadAndUpdateFile: сохранение ответа в файл...")
                content := whr.ResponseBody
                pStream := ComObjCreate("ADODB.Stream")
                pStream.Type := 1
                pStream.Open()
                pStream.Write(content)
                pStream.SaveToFile(targetPath, 2)
                pStream.Close()
                WriteLog("DownloadAndUpdateFile: файл успешно сохранен")
                break
            } else {
                WriteLog("DownloadAndUpdateFile: статус не 200: " . responseStatus)
                if (retryCount < maxRetries) {
                    continue
                }
                WriteLog("DownloadAndUpdateFile: используем URLDownloadToFile как fallback...")
                encodedUrl := EncodeUrlForDownload(downloadUrl)
                URLDownloadToFile, %encodedUrl%, %targetPath%
                if (ErrorLevel != 0) {
                    WriteLog("DownloadAndUpdateFile: ОШИБКА - URLDownloadToFile завершился с ошибкой")
                    return false
                }
                break
            }
        } catch e {
            WriteLog("DownloadAndUpdateFile: ОШИБКА в try блоке: " . e.Message)
            if (retryCount < maxRetries) {
                continue
            }
            WriteLog("DownloadAndUpdateFile: используем URLDownloadToFile как fallback...")
            encodedUrl := EncodeUrlForDownload(downloadUrl)
            URLDownloadToFile, %encodedUrl%, %targetPath%
            if (ErrorLevel != 0) {
                WriteLog("DownloadAndUpdateFile: ОШИБКА - URLDownloadToFile (fallback) завершился с ошибкой")
                return false
            }
            break
        }
    }

    if (!FileExist(targetPath)) {
        WriteLog("DownloadAndUpdateFile: ОШИБКА - файл не создан после загрузки")
        return false
    }

    FileGetSize, fileSize, %targetPath%
    WriteLog("DownloadAndUpdateFile: размер файла: " . fileSize . " байт, минимальный: " . minSize)
    if (fileSize < minSize) {
        WriteLog("DownloadAndUpdateFile: ОШИБКА - файл слишком маленький, возможно поврежден")
        FileDelete, %targetPath%
        return false
    }

    WriteLog("DownloadAndUpdateFile: загрузка успешно завершена")
    return true
}

DownloadAndUpdateScript() {
    WriteLog("DownloadAndUpdateScript: начало загрузки скрипта")
    scriptPath := A_ScriptFullPath
    downloadUrl := GetUpdateScriptUrl()
    tempScriptPath := scriptPath . ".new"
    
    WriteLog("DownloadAndUpdateScript: путь скрипта: " . scriptPath)
    WriteLog("DownloadAndUpdateScript: URL загрузки: " . downloadUrl)
    WriteLog("DownloadAndUpdateScript: временный путь: " . tempScriptPath)
    
    if (FileExist(tempScriptPath)) {
        FileDelete, %tempScriptPath%
        WriteLog("DownloadAndUpdateScript: удален старый временный файл")
    }
    
    WriteLog("DownloadAndUpdateScript: начало загрузки файла...")
    if (!DownloadAndUpdateFile(downloadUrl, tempScriptPath, 1000)) {
        WriteLog("DownloadAndUpdateScript: ОШИБКА - DownloadAndUpdateFile вернул false")
        return false
    }
    
    WriteLog("DownloadAndUpdateScript: файл загружен, проверка существования...")
    if (!FileExist(tempScriptPath)) {
        WriteLog("DownloadAndUpdateScript: ОШИБКА - временный файл не создан")
        return false
    }
    
    FileGetSize, fileSize, %tempScriptPath%
    WriteLog("DownloadAndUpdateScript: размер загруженного файла: " . fileSize . " байт")
    
    WriteLog("DownloadAndUpdateScript: замена старого файла новым...")
    
    oldScriptPath := scriptPath . ".old"
    if (FileExist(oldScriptPath)) {
        FileDelete, %oldScriptPath%
        WriteLog("DownloadAndUpdateScript: удален старый .old файл")
    }
    
    if (FileExist(scriptPath)) {
        FileSetAttrib, -R, %scriptPath%
        WriteLog("DownloadAndUpdateScript: снят атрибут ReadOnly со старого файла")
        
        FileMove, %scriptPath%, %oldScriptPath%, 1
        if (ErrorLevel != 0) {
            WriteLog("DownloadAndUpdateScript: ОШИБКА - не удалось переименовать старый файл, ErrorLevel: " . ErrorLevel)
            WriteLog("DownloadAndUpdateScript: возможно, файл используется другим процессом")
            if (FileExist(tempScriptPath)) {
                FileDelete, %tempScriptPath%
            }
            return false
        }
        WriteLog("DownloadAndUpdateScript: старый файл переименован в .old")
    }
    
    FileMove, %tempScriptPath%, %scriptPath%, 1
    
    if (ErrorLevel != 0) {
        WriteLog("DownloadAndUpdateScript: ОШИБКА - не удалось переместить новый файл, ErrorLevel: " . ErrorLevel)
        if (FileExist(oldScriptPath)) {
            FileMove, %oldScriptPath%, %scriptPath%, 1
            WriteLog("DownloadAndUpdateScript: восстановлен старый файл из .old")
        }
        if (FileExist(tempScriptPath)) {
            FileDelete, %tempScriptPath%
        }
        return false
    }
    
    WriteLog("DownloadAndUpdateScript: файл успешно заменен")
    
    WriteLog("DownloadAndUpdateScript: файл успешно заменен")
    
    oldAhkPath := A_ScriptDir . "\ahk-rmrp.ahk"
    if (FileExist(oldAhkPath) && A_ScriptName != "ahk-rmrp.ahk") {
        try {
            FileDelete, %oldAhkPath%
            WriteLog("DownloadAndUpdateScript: удален старый .ahk файл")
        } catch e {
            WriteLog("DownloadAndUpdateScript: не удалось удалить старый .ahk файл: " . e.Message)
        }
    }
    
    WriteLog("DownloadAndUpdateScript: загрузка завершена успешно")
    return true
}

DownloadAndUpdateKoap() {
    koapPath := GetKoapConfigFile()
    if (DownloadAndUpdateFile(GetUpdateKoapUrl(), koapPath, 100))
        return true
    WriteLog("DownloadAndUpdateKoap: raw не сработал, пробуем Releases")
    return DownloadAndUpdateFile(GetUpdateKoapFallbackUrl(), koapPath, 100)
}

DownloadAndUpdateUK() {
    ukPath := GetUKConfigFile()
    if (DownloadAndUpdateFile(GetUpdateUKUrl(), ukPath, 100))
        return true
    WriteLog("DownloadAndUpdateUK: raw не сработал, пробуем Releases")
    return DownloadAndUpdateFile(GetUpdateUKFallbackUrl(), ukPath, 100)
}

DownloadAndUpdateInfo() {
    infoPath := GetInfoConfigFile()
    if (DownloadAndUpdateFile(GetUpdateInfoUrl(), infoPath, 10))
        return true
    WriteLog("DownloadAndUpdateInfo: raw не сработал, пробуем Releases")
    return DownloadAndUpdateFile(GetUpdateInfoFallbackUrl(), infoPath, 10)
}

global lastUpdateInfo := ""
global lastUpdateCheckTime := 0
global updateCheckInterval := 60000
global lastFileVersionsCache := {}
global lastFileVersionsCheckTime := 0
global fileVersionsCacheInterval := 300000

CheckForUpdatesSilent() {
    global lastUpdateInfo, lastUpdateCheckTime, updateCheckInterval

    currentTime := A_TickCount

    if (lastUpdateInfo != "") {
        return lastUpdateInfo
    }

    if (lastUpdateCheckTime != 0 && (currentTime - lastUpdateCheckTime < updateCheckInterval)) {
        return lastUpdateInfo
    }

    scriptVersion := LoadIniValue("version")
    if (scriptVersion = "") {
        scriptVersion := GetUnixTimestamp()
        SaveIniValue("version", scriptVersion)
    }

    jsonContent := DownloadUpdateVersion()
    if (jsonContent = "") {
        lastUpdateInfo := ""
        lastUpdateCheckTime := currentTime
        return ""
    }

    serverVersion := ParseVersion(jsonContent)
    if (serverVersion = "") {
        lastUpdateInfo := ""
        lastUpdateCheckTime := currentTime
        return ""
    }
    
    serverTimestamp := serverVersion
    if (!RegExMatch(serverVersion, "^\d+$")) {
        RegExMatch(serverVersion, "(\d{2})\.(\d{2})\.(\d{4})\s+(\d{2}):(\d{2}):(\d{2})", match)
        if (match) {
            serverDate := match3 . match2 . match1 . match4 . match5 . match6
            baseTime := 19700101000000
            tempTime := serverDate
            EnvSub, tempTime, %baseTime%, Seconds
            serverTimestamp := tempTime
        } else {
            serverTimestamp := GetUnixTimestamp()
        }
    }
    
    scriptTimestamp := scriptVersion
    if (!RegExMatch(scriptVersion, "^\d+$")) {
        scriptTimestamp := GetUnixTimestamp()
    }
    
    if (serverTimestamp = scriptTimestamp || serverTimestamp <= scriptTimestamp) {
        lastUpdateInfo := ""
        lastUpdateCheckTime := currentTime
        return ""
    }

    lastUpdateInfo := scriptVersion . "|" . serverVersion
    lastUpdateCheckTime := currentTime

    return lastUpdateInfo
}

CountMissingLawSources() {
    EnsureLawFilesCached()
    mc := 0
    if (!FileExist(GetKoapConfigFile()))
        mc++
    if (!FileExist(GetUKConfigFile()))
        mc++
    if (!FileExist(GetInfoConfigFile()))
        mc++
    return mc
}

CheckForUpdatesLoadingStepsMax() {
    return 9
}

CheckAndDownloadMissingFiles(startProgress := 0, endProgress := 10) {
    global isBlockingF3
   global gSimpleStartupUi
    missingCount := 0
    fileList := ""
    needKoap := false
    needUK := false
    needInfo := false

    EnsureLawFilesCached()

    koapPath := GetKoapConfigFile()
    if (!FileExist(koapPath)) {
        missingCount++
        fileList .= (fileList != "" ? ", " : "") . "koap.ini"
        needKoap := true
    }

    ukPath := GetUKConfigFile()
    if (!FileExist(ukPath)) {
        missingCount++
        fileList .= (fileList != "" ? ", " : "") . "uk.ini"
        needUK := true
    }

    infoPath := GetInfoConfigFile()
    if (!FileExist(infoPath)) {
        missingCount++
        fileList .= (fileList != "" ? ", " : "") . "info.txt"
        needInfo := true
    }

    if (missingCount > 0) {
        isBlockingF3 := true
        if (!gSimpleStartupUi) {
            LoadingGuiAdvance("Подготовка справочников...")
        }

        successCount := 0
        totalFiles := missingCount
        currentFile := 0

        scriptVersion := LoadIniValue("version")
        if (scriptVersion = "") {
            scriptVersion := GetUnixTimestamp()
        }
        
        if (needKoap) {
            currentFile++
            lawLoadSuffix := (totalFiles > 1) ? (" (" . currentFile . "/" . totalFiles . ")") : ""
            lawStatusLine := "КоАП РФ…" . lawLoadSuffix
            if (!gSimpleStartupUi) {
                LoadingGuiAdvance(lawStatusLine)
            }
            if (DownloadAndUpdateKoap()) {
                successCount++
            }
        }

        if (needUK) {
            currentFile++
            lawLoadSuffix := (totalFiles > 1) ? (" (" . currentFile . "/" . totalFiles . ")") : ""
            lawStatusLine := "УК РФ…" . lawLoadSuffix
            if (!gSimpleStartupUi) {
                LoadingGuiAdvance(lawStatusLine)
            }
            if (DownloadAndUpdateUK()) {
                successCount++
            }
        }

        if (needInfo) {
            currentFile++
            lawLoadSuffix := (totalFiles > 1) ? (" (" . currentFile . "/" . totalFiles . ")") : ""
            lawStatusLine := "Полезная информация…" . lawLoadSuffix
            if (!gSimpleStartupUi) {
                LoadingGuiAdvance(lawStatusLine)
            }
            if (DownloadAndUpdateInfo()) {
                successCount++
            }
        }

        if (successCount = missingCount) {
            if (!gSimpleStartupUi) {
                LoadingGuiAdvance("Справочники готовы")
            }
            Sleep, 500
            isBlockingF3 := false
        } else {
            if (!gSimpleStartupUi) {
                LoadingGuiAdvance("Ошибка: готово только " . successCount . " из " . missingCount)
            }
            Sleep, 1000
            isBlockingF3 := false
        }
    }

    return true
}

CheckForFileUpdates(startProgress := 35, endProgress := 50) {
    global isBlockingF3
    
    showProgress := (startProgress != 0 || endProgress != 0)
    
    koapPath := GetKoapConfigFile()
    ukPath := GetUKConfigFile()
    infoPath := GetInfoConfigFile()
    
    isBlockingF3 := true
    totalFiles := 3
    currentFile := 0

    currentFile++
    if (showProgress) {
        lawLoadSuffix := " (" . currentFile . "/" . totalFiles . ")"
        LoadingGuiAdvance("КоАП РФ…" . lawLoadSuffix)
    }
    DownloadAndUpdateKoap()

    currentFile++
    if (showProgress) {
        lawLoadSuffix := " (" . currentFile . "/" . totalFiles . ")"
        LoadingGuiAdvance("УК РФ…" . lawLoadSuffix)
    }
    DownloadAndUpdateUK()

    currentFile++
    if (showProgress) {
        lawLoadSuffix := " (" . currentFile . "/" . totalFiles . ")"
        LoadingGuiAdvance("Полезная информация…" . lawLoadSuffix)
    }
    DownloadAndUpdateInfo()

    isBlockingF3 := false
}

CheckForUpdates(startProgress := 15, endProgress := 30) {
    global isBlockingF3
    global gSimpleUpdateUi
    global gSimpleUpdateStarted
    
    showProgress := (startProgress != 0 || endProgress != 0)
    
    WriteLog("CheckForUpdates: начало проверки обновлений")
    
    scriptVersion := LoadIniValue("version")
    isFirstRun := (scriptVersion = "")
    
    if (showProgress && !gSimpleUpdateUi) {
        LoadingGuiAdvance("Запрос версии с сервера...")
    }

    jsonContent := DownloadUpdateVersion()
    WriteLog("CheckForUpdates: получен ответ с сервера: " . (jsonContent != "" ? "OK" : "пусто"))
    
    if (showProgress && !gSimpleUpdateUi && jsonContent != "") {
        LoadingGuiAdvance("Анализ версии...")
    }
    if (jsonContent = "" || jsonContent = "Access denied" || jsonContent = "File name required") {
        WriteLog("CheckForUpdates: не удалось получить версию с сервера: " . jsonContent)
        if (isFirstRun) {
            WriteLog("CheckForUpdates: первая настройка — версию в ini не записываем (повторим при следующем запуске)")
        }
        if (showProgress && !gSimpleUpdateUi) {
            LoadingGuiAdvance("Не удалось получить версию с сервера")
        }
        LoadingGuiEndBlock()
        return
    }

    serverVersion := ParseVersion(jsonContent)
    if (serverVersion = "") {
        WriteLog("CheckForUpdates: ошибка парсинга версии из JSON: " . jsonContent)
        if (isFirstRun) {
            WriteLog("CheckForUpdates: первая настройка — версию в ini не записываем (некорректный ответ метаданных)")
        }
        if (showProgress && !gSimpleUpdateUi) {
            LoadingGuiAdvance("Ошибка парсинга версии")
            Sleep, 2000
        }
        LoadingGuiEndBlock()
        return
    }
    
    WriteLog("CheckForUpdates: версия с сервера: " . serverVersion)
    
    serverTimestamp := ""
    if (RegExMatch(serverVersion, "^\d+$")) {
        serverTimestamp := serverVersion
    } else if (RegExMatch(serverVersion, "^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})", iso)) {
        serverDate := iso1 . iso2 . iso3 . iso4 . iso5 . iso6
        baseTime := 19700101000000
        tempTime := serverDate
        EnvSub, tempTime, %baseTime%, Seconds
        serverTimestamp := tempTime
    } else if (RegExMatch(serverVersion, "(\d{2})\.(\d{2})\.(\d{4})\s+(\d{2}):(\d{2}):(\d{2})", match)) {
        serverDate := match3 . match2 . match1 . match4 . match5 . match6
        baseTime := 19700101000000
        tempTime := serverDate
        EnvSub, tempTime, %baseTime%, Seconds
        serverTimestamp := tempTime
    } else if (isFirstRun) {
        serverTimestamp := GetUnixTimestamp()
        WriteLog("CheckForUpdates: неизвестный формат версии при первом запуске: " . serverVersion)
    } else {
        serverTimestamp := scriptVersion
        WriteLog("CheckForUpdates: неизвестный формат версии, для сравнения используем локальную запись: " . serverVersion)
    }
    
    if (isFirstRun) {
        scriptVersion := serverTimestamp
        WriteLog("CheckForUpdates: первый запуск — версию в ini запишем после успешной установки")
    } else {
        WriteLog("CheckForUpdates: локальная версия: " . scriptVersion)
    }
    
    scriptTimestamp := scriptVersion
    if (!RegExMatch(scriptVersion, "^\d+$")) {
        scriptTimestamp := GetUnixTimestamp()
    }
    
    WriteLog("CheckForUpdates: сравнение версий - локальная: " . scriptTimestamp . ", серверная: " . serverTimestamp)
    
    if (isFirstRun) {
        WriteLog("CheckForUpdates: первый запуск, принудительное обновление...")
    } else if (serverTimestamp = scriptTimestamp || serverTimestamp <= scriptTimestamp) {
        WriteLog("CheckForUpdates: обновления не требуются")
        if (showProgress && !gSimpleUpdateUi) {
            LoadingGuiAdvance("Версия актуальна")
        }
        LoadingGuiEndBlock()
        return
    }
    
    Gui, LoadingGui:Hide
    if (isFirstRun) {
        confirmMsg := "Это первый запуск.`nЗагрузить лаунчер с сервера?"
    } else {
        confirmMsg := "Доступна новая версия лаунчера.`nСкачать и установить?"
    }
    MsgBox, 36, Обновление, %confirmMsg%
    Gui, LoadingGui:Show
    IfMsgBox No
    {
        WriteLog("CheckForUpdates: обновление отклонено пользователем")
        if (showProgress && !gSimpleUpdateUi) {
            LoadingGuiAdvance("Обновление отменено")
        }
        LoadingGuiEndBlock()
        return
    }
    
    WriteLog("CheckForUpdates: найдено обновление, пользователь подтвердил — начинаю загрузку...")

    if (showProgress)
        isBlockingF3 := true
    
    if (showProgress && gSimpleUpdateUi) {
        if (!gSimpleUpdateStarted) {
            LoadingGuiSimpleUpdateStep(1)
            gSimpleUpdateStarted := true
        }
    } else if (showProgress) {
        LoadingGuiAdvance("Обновление скрипта...")
    }
    
    scriptPath := A_ScriptFullPath
    isAhkFile := !A_IsCompiled
    newExePath := VersionedMainExePath(serverTimestamp)
    launchNewExePath := ""
    
    if (A_IsCompiled && MainExePathPathsEqual(newExePath, A_ScriptFullPath)) {
        WriteLog("CheckForUpdates: новый путь exe совпадает с текущим процессом — загрузка отменена (нельзя перезаписать запущенный файл)")
        isBlockingF3 := false
        LoadingGuiEndBlock()
        return
    }
    
    if (isAhkFile) {
        WriteLog("CheckForUpdates: загрузка нового .ahk...")
        
        if (showProgress && !gSimpleUpdateUi) {
            LoadingGuiAdvance("Загрузка нового .ahk файла...")
        }
        
        downloadUrl := GetUpdateScriptUrl("ahk-rmrp.ahk")
        tempAhkPath := scriptPath . ".new"
        
        if (FileExist(tempAhkPath)) {
            FileDelete, %tempAhkPath%
        }
        
        WriteLog("CheckForUpdates: загрузка нового .ahk файла...")
        if (!DownloadAndUpdateFile(downloadUrl, tempAhkPath, 1000)) {
            WriteLog("CheckForUpdates: ОШИБКА - не удалось загрузить новый .ahk файл")
            if (showProgress && !gSimpleUpdateUi) {
                LoadingGuiAdvance("Ошибка при загрузке скрипта")
            }
            isBlockingF3 := false
            LoadingGuiEndBlock()
            return
        }
        
        if (!FileExist(tempAhkPath)) {
            WriteLog("CheckForUpdates: ОШИБКА - новый .ahk файл не создан")
            if (showProgress && !gSimpleUpdateUi) {
                LoadingGuiAdvance("Ошибка при загрузке скрипта")
            }
            isBlockingF3 := false
            LoadingGuiEndBlock()
            return
        }
        
        FileGetSize, fileSize, %tempAhkPath%
        WriteLog("CheckForUpdates: новый .ahk файл загружен, размер: " . fileSize . " байт")
        
        oldScriptPath := scriptPath . ".old"
        if (FileExist(oldScriptPath)) {
            FileDelete, %oldScriptPath%
        }
        
        if (FileExist(scriptPath)) {
            FileSetAttrib, -R, %scriptPath%
            FileMove, %scriptPath%, %oldScriptPath%, 1
            if (ErrorLevel != 0) {
                WriteLog("CheckForUpdates: ОШИБКА - не удалось переименовать старый .ahk файл")
                FileDelete, %tempAhkPath%
                isBlockingF3 := false
                LoadingGuiEndBlock()
                return
            }
        }
        
        FileMove, %tempAhkPath%, %scriptPath%, 1
        if (ErrorLevel != 0) {
            WriteLog("CheckForUpdates: ОШИБКА - не удалось переместить новый .ahk файл")
            if (FileExist(oldScriptPath)) {
                FileMove, %oldScriptPath%, %scriptPath%, 1
            }
            FileDelete, %tempAhkPath%
            isBlockingF3 := false
            LoadingGuiEndBlock()
            return
        }
        
        WriteLog("CheckForUpdates: .ahk файл обновлен, теперь загружаю .exe...")
        
        if (showProgress && !gSimpleUpdateUi) {
            LoadingGuiAdvance("Загрузка .exe файла...")
        }
        
        downloadUrl := GetUpdateScriptUrl("ahk-rmrp.exe")
        if (FileExist(newExePath)) {
            FileDelete, %newExePath%
        }
        
        WriteLog("CheckForUpdates: загрузка .exe в " . newExePath)
        if (!DownloadAndUpdateFile(downloadUrl, newExePath, 1000)) {
            WriteLog("CheckForUpdates: ОШИБКА - не удалось загрузить .exe файл")
            if (showProgress && !gSimpleUpdateUi) {
                LoadingGuiAdvance("Ошибка при загрузке .exe")
            }
            isBlockingF3 := false
            LoadingGuiEndBlock()
            return
        }
        
        if (!FileExist(newExePath)) {
            WriteLog("CheckForUpdates: ОШИБКА - новый .exe файл не создан")
            if (showProgress && !gSimpleUpdateUi) {
                LoadingGuiAdvance("Ошибка при загрузке .exe")
            }
            isBlockingF3 := false
            LoadingGuiEndBlock()
            return
        }
        
        FileGetSize, fileSize, %newExePath%
        WriteLog("CheckForUpdates: .exe загружен, размер: " . fileSize . " байт")
        
        launchNewExePath := newExePath
        
        WriteLog("CheckForUpdates: удаляю старый .ahk перед запуском нового .exe...")
        if (FileExist(scriptPath)) {
            FileDelete, %scriptPath%
            WriteLog("CheckForUpdates: старый .ahk файл удален")
        }
    } else {
        WriteLog("CheckForUpdates: файлы .ini и .txt обновлены, загрузка нового .exe...")
        
        if (showProgress && !gSimpleUpdateUi) {
            LoadingGuiAdvance("Загрузка нового скрипта...")
        }
        
        downloadUrl := GetUpdateScriptUrl("ahk-rmrp.exe")
        if (FileExist(newExePath)) {
            FileDelete, %newExePath%
        }
        
        WriteLog("CheckForUpdates: загрузка нового .exe в " . newExePath)
        if (!DownloadAndUpdateFile(downloadUrl, newExePath, 1000)) {
            WriteLog("CheckForUpdates: ОШИБКА - не удалось загрузить новый .exe файл")
            if (showProgress && !gSimpleUpdateUi) {
                LoadingGuiAdvance("Ошибка при загрузке скрипта")
            }
            isBlockingF3 := false
            LoadingGuiEndBlock()
            return
        }
        
        if (!FileExist(newExePath)) {
            WriteLog("CheckForUpdates: ОШИБКА - новый .exe файл не создан")
            if (showProgress && !gSimpleUpdateUi) {
                LoadingGuiAdvance("Ошибка при загрузке скрипта")
            }
            isBlockingF3 := false
            LoadingGuiEndBlock()
            return
        }
        
        FileGetSize, fileSize, %newExePath%
        WriteLog("CheckForUpdates: новый .exe загружен, размер: " . fileSize . " байт")
        
        launchNewExePath := newExePath
    }
    
    if (launchNewExePath = "" || !FileExist(launchNewExePath)) {
        WriteLog("CheckForUpdates: ОШИБКА - путь для запуска новой версии пуст или файл отсутствует")
        isBlockingF3 := false
        LoadingGuiEndBlock()
        return
    }
    
    if (showProgress && gSimpleUpdateUi) {
        LoadingGuiSimpleUpdateStep(2)
    }

    if (serverTimestamp != "") {
        SaveIniValue("version", serverTimestamp)
        WriteLog("CheckForUpdates: версия обновлена на (Unix): " . serverTimestamp . " (серверная: " . serverVersion . ")")
    } else if (serverVersion != "") {
        serverTimestamp := GetUnixTimestamp()
        SaveIniValue("version", serverTimestamp)
        WriteLog("CheckForUpdates: версия обновлена на (Unix fallback): " . serverTimestamp . " (серверная: " . serverVersion . ")")
    }
    
    WriteLog("CheckForUpdates: запуск новой версии: " . launchNewExePath)
    if (showProgress) {
        LoadingGuiEndBlock()
        if (gSimpleUpdateUi) {
            LoadingGuiSimpleUpdateStep(3)
        } else {
            LoadingGuiAdvanceFullBar("Запуск новой версии…")
        }
        Sleep, 400
    } else {
        Sleep, 200
    }
    
    WriteLog("CheckForUpdates: планируем запуск update.exe после выхода из try-блока")
    global gPendingUpdateLaunch
    gPendingUpdateLaunch := launchNewExePath
    isBlockingF3 := false
    LoadingGuiEndBlock()
}

#IfWinActive Выбор папки
    Esc::
        global tempScreenshotPath
        if (tempScreenshotPath != "" && FileExist(tempScreenshotPath)) {
            FileDelete, %tempScreenshotPath%
        }
        tempScreenshotPath := ""
        Gui, ScreenshotMenu:Destroy
    return

    1::
    Numpad1::
        ClickScreenshotButton(1)
    return

    2::
    Numpad2::
        ClickScreenshotButton(2)
    return

    3::
    Numpad3::
        ClickScreenshotButton(3)
    return

    4::
    Numpad4::
        ClickScreenshotButton(4)
    return

    5::
    Numpad5::
        ClickScreenshotButton(5)
    return

    6::
    Numpad6::
        ClickScreenshotButton(6)
    return

    7::
    Numpad7::
        ClickScreenshotButton(7)
    return

    8::
    Numpad8::
        ClickScreenshotButton(8)
    return

    9::
    Numpad9::
        ClickScreenshotButton(9)
    return
#IfWinActive

OnMouseDown(wParam, lParam, msg, hwnd) {
    PostMessage, 0xA1, 2
}

WM_EXITSIZEMOVE(wParam, lParam, msg, hwnd) {
    global GuiID, currentWindow
    if (hwnd = GuiID) {
        SaveWindowPos()
    }
}

GetSettingsConfigFile() {
    return A_ScriptDir . "\settings.ini"
}

CleanupLegacyAuthFromSettings() {
    settingsFile := GetSettingsConfigFile()
    if (!FileExist(settingsFile)) {
        return
    }
    FileRead, content, %settingsFile%
    if (InStr(content, "[auth]") = 0) {
        return
    }
    newContent := ""
    inAuthSection := false
    Loop, Parse, content, `n, `r
    {
        line := A_LoopField
        if (RegExMatch(line, "^\[auth\]")) {
            inAuthSection := true
            continue
        }
        if (inAuthSection && RegExMatch(line, "^\[")) {
            inAuthSection := false
        }
        if (!inAuthSection) {
            newContent .= line . "`n"
        }
    }
    newContent := RegExReplace(newContent, "`n+$", "")
    FileDelete, %settingsFile%
    FileAppend, %newContent%, %settingsFile%, UTF-8
    WriteLog("CleanupLegacyAuth: секция [auth] удалена из settings.ini")
}

LoadIniValue(keyPath) {
    configFile := GetSettingsConfigFile()
    if (!FileExist(configFile)) {
        return ""
    }

    file := FileOpen(configFile, "r", "UTF-8")
    if (!file) {
        return ""
    }
    
    fileContent := file.Read()
    file.Close()
    
    StringSplit, keys, keyPath, .
    sectionName := ""
    keyName := ""
    
    if (keys0 = 1) {
        sectionName := "Settings"
        keyName := keys1
    } else if (keys0 = 2) {
        sectionName := keys1
        keyName := keys2
    } else if (keys0 = 3) {
        sectionName := keys1 . "_" . keys2
        keyName := keys3
    }
    
    if (sectionName = "" || keyName = "") {
        return ""
    }
    
    inSection := false
    Loop, Parse, fileContent, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "[" . sectionName . "]") {
            inSection := true
            continue
        }
        if (InStr(line, "[") = 1 && InStr(line, "]") > 1) {
            inSection := false
            continue
        }
        if (inSection && RegExMatch(line, "^" . keyName . "\s*=\s*(.*)$", match)) {
            return match1
        }
    }
    
    return ""
}

SaveIniValue(keyPath, value, isString = true) {
    configFile := GetSettingsConfigFile()
    StringSplit, keys, keyPath, .
    
    sectionName := ""
    keyName := ""
    
    if (keys0 = 1) {
        sectionName := "Settings"
        keyName := keys1
    } else if (keys0 = 2) {
        sectionName := keys1
        keyName := keys2
    } else if (keys0 = 3) {
        sectionName := keys1 . "_" . keys2
        keyName := keys3
    }
    
    if (sectionName = "" || keyName = "") {
        return
    }
    
    fileContent := ""
    if (FileExist(configFile)) {
        file := FileOpen(configFile, "r", "UTF-8")
        if (file) {
            fileContent := file.Read()
            file.Close()
        }
    }
    
    inSection := false
    sectionFound := false
    keyFound := false
    newContent := ""
    lastWasEmpty := false
    inTargetSection := false
    
    Loop, Parse, fileContent, `n, `r
    {
        line := A_LoopField
        trimmedLine := Trim(line)
        
        if (InStr(trimmedLine, "[") = 1 && InStr(trimmedLine, "]") > 1) {
            if (inSection && !keyFound) {
                newContent .= keyName . "=" . value . "`n"
                keyFound := true
            }
            inSection := (trimmedLine = "[" . sectionName . "]")
            sectionFound := sectionFound || inSection
            inTargetSection := inSection
            
            if (newContent != "" && Trim(SubStr(newContent, StrLen(newContent) - 1)) != "") {
                newContent .= "`n"
            }
            newContent .= line . "`n"
            lastWasEmpty := false
            continue
        }
        
        if (inSection && RegExMatch(trimmedLine, "^" . keyName . "\s*=", match)) {
            newContent .= keyName . "=" . value . "`n"
            keyFound := true
            lastWasEmpty := false
            continue
        }
        
        if (trimmedLine = "") {
            if (inSection) {
                continue
            }
            if (!lastWasEmpty && newContent != "") {
                newContent .= "`n"
                lastWasEmpty := true
            }
        } else {
            newContent .= line . "`n"
            lastWasEmpty := false
        }
    }
    
    if (!sectionFound) {
        if (newContent != "" && Trim(SubStr(newContent, StrLen(newContent) - 1)) != "") {
            newContent .= "`n"
        }
        newContent .= "[" . sectionName . "]`n"
    }
    if (!keyFound) {
        if (!sectionFound) {
            newContent .= keyName . "=" . value . "`n"
        } else {
            newContent := RegExReplace(newContent, "(\[" . sectionName . "\][\r\n]+)", "$1" . keyName . "=" . value . "`n")
        }
    }
    
    newContent := RegExReplace(newContent, "(`r?`n){3,}", "`r`n`r`n")
    newContent := RegExReplace(newContent, "(`r?`n)+$", "`r`n")
    
    file := FileOpen(configFile, "w", "UTF-8")
    if (file) {
        file.Write(newContent)
        file.Close()
    }
}

LoadIniArray(keyPath) {
    configFile := GetSettingsConfigFile()
    if (!FileExist(configFile)) {
        return ""
    }

    file := FileOpen(configFile, "r", "UTF-8")
    if (!file) {
        return ""
    }
    
    fileContent := file.Read()
    file.Close()
    
    StringSplit, keys, keyPath, .
    if (keys0 != 2) {
        return ""
    }
    
    sectionName := keys1
    keyName := keys2
    
    inSection := false
    Loop, Parse, fileContent, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "[" . sectionName . "]") {
            inSection := true
            continue
        }
        if (InStr(line, "[") = 1 && InStr(line, "]") > 1) {
            inSection := false
            continue
        }
        if (inSection && RegExMatch(line, "^" . keyName . "\s*=\s*(.*)$", match)) {
            return match1
        }
    }
    
    return ""
}

SaveIniArray(keyPath, arrayStr) {
    configFile := GetSettingsConfigFile()
    StringSplit, keys, keyPath, .
    
    if (keys0 != 2) {
        return
    }
    
    sectionName := keys1
    keyName := keys2
    
    fileContent := ""
    if (FileExist(configFile)) {
        file := FileOpen(configFile, "r", "UTF-8")
        if (file) {
            fileContent := file.Read()
            file.Close()
        }
    }
    
    inSection := false
    sectionFound := false
    keyFound := false
    newContent := ""
    
    Loop, Parse, fileContent, `n, `r
    {
        line := A_LoopField
        trimmedLine := Trim(line)
        
        if (InStr(trimmedLine, "[") = 1 && InStr(trimmedLine, "]") > 1) {
            if (inSection && !keyFound) {
                newContent .= keyName . "=" . arrayStr . "`n"
                keyFound := true
            }
            inSection := (trimmedLine = "[" . sectionName . "]")
            sectionFound := sectionFound || inSection
            newContent .= line . "`n"
            continue
        }
        
        if (inSection && RegExMatch(trimmedLine, "^" . keyName . "\s*=", match)) {
            newContent .= keyName . "=" . arrayStr . "`n"
            keyFound := true
            continue
        }
        
        newContent .= line . "`n"
    }
    
    if (!sectionFound) {
        newContent .= "[" . sectionName . "]`n"
    }
    if (!keyFound) {
        if (!sectionFound) {
            newContent .= keyName . "=" . arrayStr . "`n"
        } else {
            newContent := RegExReplace(newContent, "(\[" . sectionName . "\][\r\n]+)", "$1" . keyName . "=" . arrayStr . "`n")
        }
    }
    
    file := FileOpen(configFile, "w", "UTF-8")
    if (file) {
        file.Write(newContent)
        file.Close()
    }
}

GetFrequentArticlesConfigFile() {
    return GetSettingsConfigFile()
}

GetFrequentArticleCodes(windowType) {
    configFile := GetFrequentArticlesConfigFile()
    section := (windowType = "koap") ? "FrequentKoap" : "FrequentUK"
    if (!FileExist(configFile)) {
        return []
    }
    IniRead, listStr, %configFile%, %section%, List, %A_Space%
    listStr := Trim(listStr)
    if (listStr = "") {
        return []
    }
    codes := []
    Loop, Parse, listStr, `,
    {
        code := Trim(A_LoopField)
        if (code != "") {

            codes.Push("`t" . code)
        }
    }
    return codes
}

AddFrequentArticle(windowType, articleCode) {
    articleCode := Trim(articleCode . "")
    if (articleCode = "") {
        return
    }
    articleCodeStored := "`t" . (articleCode . "")
    codes := GetFrequentArticleCodes(windowType)
    maxCount := 80
    newCodes := []
    Loop, % codes.Length()
    {
        c := codes[A_Index]
        rawC := (SubStr(c, 1, 1) = "`t") ? SubStr(c, 2) : c
        if (("x" . rawC) != ("x" . articleCode)) {
            newCodes.Push(c)
        }
    }
    newCodes.Push(articleCodeStored)
    if (newCodes.Length() > maxCount) {
        startIdx := newCodes.Length() - maxCount + 1
        codes := []
        Loop, % maxCount
        {
            codes.Push(newCodes[startIdx + A_Index - 1])
        }
        newCodes := codes
    }
    listStr := ""
    for i, c in newCodes
    {
        if (listStr != "") {
            listStr .= ","
        }
        rawC := (SubStr(c, 1, 1) = "`t") ? SubStr(c, 2) : (c . "")
        listStr .= rawC
    }
    configFile := GetFrequentArticlesConfigFile()
    section := (windowType = "koap") ? "FrequentKoap" : "FrequentUK"
    IniWrite, %listStr%, %configFile%, %section%, List
}

ArticleCodeMatches(articleField, code) {
    a := Trim(articleField . "")
    c := Trim(code . "")
    if (SubStr(c, 1, 1) = "`t")
        c := SubStr(c, 2)
    if (a = "" || c = "") {
        return false
    }
    return (("x" . a) = ("x" . c))
}

GetFrequentArticlesAsText(windowType) {
    codes := GetFrequentArticleCodes(windowType)
    if (codes.Length() = 0) {
        return ""
    }
    n := codes.Length()
    Loop, % n - 1
    {
        i := A_Index
        Loop, % n - i
        {
            j := i + A_Index
            c1 := codes[i]
            c2 := codes[j]
            raw1 := (SubStr(c1, 1, 1) = "`t") ? SubStr(c1, 2) : c1
            raw2 := (SubStr(c2, 1, 1) = "`t") ? SubStr(c2, 2) : c2
            if (CompareArticles(raw1, raw2) > 0) {
                codes[i] := c2
                codes[j] := c1
            }
        }
    }
    allArticles := (windowType = "koap") ? GetKoapArticles() : GetUKArticles()
    text := ""
    for i, code in codes
    {
        for idx, item in allArticles
        {
            if (ArticleCodeMatches(item.article, code)) {
                text .= item.article . "    | " . item.description . " | " . item.point . "        | " . item.penalty . "`n"
                break
            }
        }
    }
    return text
}

IsFrequentArticlesEnabled() {
    val := LoadIniValue("settings.FrequentArticles")
    if (val = "0") {
        return 0
    }
    return 1
}

SaveWindowPos(windowType := "") {
    global currentWindow, GuiID
    if (windowType = "") {
        windowType := currentWindow
    }
    if (windowType = "") {
        return
    }
    
    if (GuiID = "") {
        return
    }
    
    WinGetPos, x, y, w, h, ahk_id %GuiID%
    if (x = "" || y = "" || w = "" || h = "") {
        return
    }
    
    if (x = 0 && y = 0) {
        return
    }
    
    if (windowType = "koap" || windowType = "uk" || windowType = "info") {
        windowType := "lawWindow"
    }
    
    
    posValue := "x" . x . " y" . y . " w" . w . " h" . h
    SaveIniValue("windowPos." . windowType, posValue)
}

LoadWindowPos(windowType := "") {
    global currentWindow
    if (windowType = "") {
        windowType := currentWindow
    }
    if (windowType = "") {
        return "x0 y0 w1020 h960"
    }
    
    if (windowType = "koap" || windowType = "uk" || windowType = "info") {
        windowType := "lawWindow"
    }
    
    posValue := LoadIniValue("windowPos." . windowType)
    if (posValue != "") {
        return posValue
    }
    
    configFile := GetSettingsConfigFile()
    if (FileExist(configFile)) {
        file := FileOpen(configFile, "r", "UTF-8")
        if (file) {
            fileContent := file.Read()
            file.Close()

            ws := "\s"
            quote := """"
            posKey := "windowPos_" . windowType
            pattern := quote . posKey . quote . ws . "*:" . ws . "*\{[^}]*" . quote . "x" . quote . ws . "*:" . ws . "*(\d+)[^}]*" . quote . "y" . quote . ws . "*:" . ws . "*(\d+)[^}]*" . quote . "w" . quote . ws . "*:" . ws . "*(\d+)[^}]*" . quote . "h" . quote . ws . "*:" . ws . "*(\d+)"
            if (RegExMatch(fileContent, pattern, match)) {
                x := match1
                y := match2
                w := match3
                h := match4
                if (x != "" && y != "" && w != "" && h != "") {
                    return "x" x " y" y " w" w " h" h
                }
            }
            
            oldPattern := quote . "windowPos" . quote . ws . "*:" . ws . "*\{[^}]*" . quote . "x" . quote . ws . "*:" . ws . "*(\d+)[^}]*" . quote . "y" . quote . ws . "*:" . ws . "*(\d+)[^}]*" . quote . "w" . quote . ws . "*:" . ws . "*(\d+)[^}]*" . quote . "h" . quote . ws . "*:" . ws . "*(\d+)"
            if (RegExMatch(fileContent, oldPattern, match)) {
                x := match1
                y := match2
                w := match3
                h := match4
                if (x != "" && y != "" && w != "" && h != "") {
                    return "x" x " y" y " w" w " h" h
                }
            }
        }
    }
    return "x0 y0 w1020 h960"
}

SaveSearchText(windowType) {
    if (windowType = "")
        return
    
    saveSearchHistory := LoadIniValue("settings.SaveSearchHistory")
    if (saveSearchHistory = 0)
        return
    
    GuiControlGet, searchText,, SearchBox
    SaveSearchTextToJson(windowType, searchText)
}

LoadSearchText(windowType) {
    if (windowType = "")
        return ""
    return LoadSearchTextFromJson(windowType)
}

EscapeJsonString(str) {
    StringReplace, str, str, \, \\, All
    StringReplace, str, str, ", \", All
    StringReplace, str, str, `n, \n, All
    StringReplace, str, str, `r, \r, All
    StringReplace, str, str, `t, \t, All
    return str
}

UnescapeJsonString(str) {
    StringReplace, str, str, \t, `t, All
    StringReplace, str, str, \r, `r, All
    StringReplace, str, str, \n, `n, All
    StringReplace, str, str, \", ", All
    StringReplace, str, str, \\, \, All
    return str
}

SaveSearchTextToJson(windowType, searchText) {
    keyPath := "search." . windowType
    SaveIniValue(keyPath, searchText)
}

LoadSearchTextFromJson(windowType) {
    keyPath := "search." . windowType
    return LoadIniValue(keyPath)
}

DoSearch:
    Gosub, SearchText
return

ClearSearch:
    global blockSearchUpdate, UpdateLabelLaw, UpdateBtnLaw
   global lastInfoSearchText, lastInfoFoundText
    global lastKoapSearchText, lastKoapSummary1, lastKoapSummary2, lastKoapArticles
    global lastUKSearchText, lastUKSummary1, lastUKSummary2, lastUKArticles
    lastInfoSearchText := ""
    lastInfoFoundText := ""
    lastKoapSearchText := ""
    lastKoapSummary1 := ""
    lastKoapSummary2 := ""
    lastKoapArticles := ""
    lastUKSearchText := ""
    lastUKSummary1 := ""
    lastUKSummary2 := ""
    lastUKArticles := ""
    blockSearchUpdate := true
    GuiControl,, SearchBox,
    if (currentWindow = "koap" || currentWindow = "uk") {
        if (currentWindow = "koap") {
            if (IsFrequentArticlesEnabled()) {
                FillKoapListView(GetFrequentArticlesAsText("koap"))
            } else {
                FillKoapListView("")
            }
        } else if (currentWindow = "uk") {
            if (IsFrequentArticlesEnabled()) {
                FillUKListView(GetFrequentArticlesAsText("uk"))
            } else {
                FillUKListView("")
            }
        }
        GuiControl, Disable, CopyReasonBtn
        GuiControl, Disable, CopyFineBtn
        GuiControl, Disable, CopyArrestBtn
        GuiControl, +cGray, CopyReasonBtn
        GuiControl, +cGray, CopyFineBtn
        GuiControl, +cGray, CopyArrestBtn
        GuiControl, Hide, SummaryText1
        GuiControl, Hide, SummaryText2
        GuiControl, Hide, UpdateLabelLaw
        GuiControl, Hide, UpdateBtnLaw
        GuiControl, Move, MyListView, x10 y120 w1000 h%editH%
        if (currentWindow = "koap") {
            LV_ModifyCol(1, 60)
            LV_ModifyCol(2, 600)
            LV_ModifyCol(3, "Center 75")
            LV_ModifyCol(4, "Center 240")
        } else if (currentWindow = "uk") {
            LV_ModifyCol(1, 60)
            LV_ModifyCol(2, 675)
            LV_ModifyCol(3, 0)
            LV_ModifyCol(4, "Center 240")
        }
    } else if (currentWindow != "info") {
        GuiControl,, MyText, %originalText%
        GuiControl, Disable, CopyReasonBtn
        GuiControl, Disable, CopyFineBtn
        GuiControl, Disable, CopyArrestBtn
        GuiControl, +cGray, CopyReasonBtn
        GuiControl, +cGray, CopyFineBtn
        GuiControl, +cGray, CopyArrestBtn
        GuiControl, Move, MyText, x10 y90 h%editH%
    } else {
        GuiControl,, MyText, %originalText%
        GuiControl, Show, BtnPK
        GuiControl, Show, BtnKoap
        GuiControl, Show, BtnUK
        GuiControl, Show, BtnUPK
        GuiControl, Show, BtnPDD
        GuiControl, Show, BtnTK
        GuiControl, Show, BtnUkazy
        GuiControl, Show, BtnFZWeapon
        GuiControl, Show, BtnFZProperty
        GuiControl, Show, BtnFZPolice
        GuiControl, Show, BtnFZGosluzhba
        GuiControl, Show, BtnFZRegime
        GuiControl, Show, BtnKonst
        GuiControl, Move, MyText, x10 y90
    }
return

CopyReason:
    if (currentWindow = "koap" || currentWindow = "uk") {
        GuiControlGet, summaryText1,, SummaryText1
        GuiControlGet, summaryText2,, SummaryText2
        summaryText := summaryText1 . "`n" . summaryText2
        if (RegExMatch(summaryText, "📋 Причина штрафа/ареста: ([^`n|]+)", match)) {
            reasonLine := Trim(match1)
            Clipboard := reasonLine
            ToolTip, Причина скопирована в буфер обмена!
            SetTimer, RemoveToolTip, 2000
            Loop, Parse, reasonLine, `,
            {
                segment := Trim(A_LoopField)
                pos := 1
                While (pos := RegExMatch(segment, "\d+(\.\d+)*", articleMatch, pos)) {
                    AddFrequentArticle(currentWindow, " " . articleMatch . " ")
                    pos += StrLen(articleMatch)
                }
            }
        }
    } else {
        GuiControlGet, myText,, MyText
        if (RegExMatch(myText, "📋 Причина штрафа/ареста: ([^`n]+)", match)) {
            Clipboard := Trim(match1)
            ToolTip, Причина скопирована в буфер обмена!
            SetTimer, RemoveToolTip, 2000
        }
    }
return

CopyFineAmount:
    if (currentWindow = "koap" || currentWindow = "uk") {
        GuiControlGet, summaryText1,, SummaryText1
        GuiControlGet, summaryText2,, SummaryText2
        summaryText := summaryText1 . "`n" . summaryText2
        if (RegExMatch(summaryText, "💸 Сумма штрафа: ([^₽|]+) ₽", match)) {
            Clipboard := Trim(match1)
            ToolTip, Сумма скопирована в буфер обмена!
            SetTimer, RemoveToolTip, 2000
        }
    } else {
        GuiControlGet, myText,, MyText
        if (RegExMatch(myText, "💸 Сумма штрафа: ([^₽]+) ₽", match)) {
            Clipboard := Trim(match1)
            ToolTip, Сумма скопирована в буфер обмена!
            SetTimer, RemoveToolTip, 2000
        }
    }
return

CopyLawyerCall:
    FormatTime, utcTime, %A_NowUTC%, HH:mm

    StringSplit, timeParts, utcTime, :
    utcHour := timeParts1
    utcMinute := timeParts2

    mskHour := utcHour + 3
    if (mskHour >= 24) {
        mskHour := mskHour - 24
    }

    if (mskHour < 10) {
        mskHour := "0" mskHour
    }
    if (StrLen(utcMinute) = 1) {
        utcMinute := "0" utcMinute
    }

    currentTime := mskHour ":" utcMinute

    Clipboard := "Требуется государственный адвокат, время: " currentTime ", место запроса: "
    ToolTip, Вызов адвоката скопирован в буфер обмена!
    SetTimer, RemoveToolTip, 2000
return

RemoveToolTip:
    ToolTip
    SetTimer, RemoveToolTip, Off
return

SearchText:
    global blockSearchUpdate, UpdateLabelLaw, UpdateBtnLaw
    WriteLog("SearchText: начало поиска")
    global lastInfoSearchText, lastInfoFoundText
    global lastKoapSearchText, lastKoapSummary1, lastKoapSummary2
    global lastUKSearchText, lastUKSummary1, lastUKSummary2

    if (blockSearchUpdate) {
        blockSearchUpdate := false
        return
    }
    GuiControlGet, searchText,, SearchBox
    if (searchText = "") {

        lastInfoSearchText := ""
        lastInfoFoundText := ""
        lastKoapSearchText := ""
        lastKoapSummary1 := ""
        lastKoapSummary2 := ""
        lastKoapArticles := ""
        lastUKSearchText := ""
        lastUKSummary1 := ""
        lastUKSummary2 := ""
        lastUKArticles := ""

        if (currentWindow = "koap" || currentWindow = "uk") {
            if (currentWindow = "koap") {
                if (IsFrequentArticlesEnabled()) {
                    FillKoapListView(GetFrequentArticlesAsText("koap"))
                } else {
                    FillKoapListView("")
                }
            } else if (currentWindow = "uk") {
                if (IsFrequentArticlesEnabled()) {
                    FillUKListView(GetFrequentArticlesAsText("uk"))
                } else {
                    FillUKListView("")
                }
            }
            GuiControl, Disable, CopyReasonBtn
            GuiControl, Disable, CopyFineBtn
            GuiControl, Disable, CopyArrestBtn
            GuiControl, +cGray, CopyReasonBtn
            GuiControl, +cGray, CopyFineBtn
            GuiControl, +cGray, CopyArrestBtn
            GuiControl, Hide, SummaryText1
            GuiControl, Hide, SummaryText2
            GuiControl, Hide, UpdateLabelLaw
            GuiControl, Hide, UpdateBtnLaw
            GuiControl, Move, MyListView, x10 y120 w1000 h%editH%
            if (currentWindow = "koap") {
                LV_ModifyCol(1, 60)
                LV_ModifyCol(2, 600)
                LV_ModifyCol(3, "Center 75")
                LV_ModifyCol(4, "Center 240")
            } else if (currentWindow = "uk") {
                LV_ModifyCol(1, 60)
                LV_ModifyCol(2, 675)
                LV_ModifyCol(3, 0)
                LV_ModifyCol(4, "Center 240")
            }
        } else if (currentWindow != "info") {
            GuiControl,, MyText, %originalText%
            GuiControl, Disable, CopyReasonBtn
            GuiControl, Disable, CopyFineBtn
            GuiControl, Disable, CopyArrestBtn
            GuiControl, +cGray, CopyReasonBtn
            GuiControl, +cGray, CopyFineBtn
            GuiControl, +cGray, CopyArrestBtn
            GuiControl, Move, MyText, x10 y90 h%editH%
            GuiControl, Hide, UpdateLabelLaw
            GuiControl, Hide, UpdateBtnLaw
        } else {
            GuiControl,, MyText, %originalText%
            GuiControl, Move, MyText, x10 y90
            GuiControl, Hide, UpdateLabelLaw
            GuiControl, Hide, UpdateBtnLaw
        }
        return
    }

    StringSplit, searchTerms, searchText, %A_Space%

    StringSplit, lines, originalText, `n
    foundText := ""
    foundAny := false
    foundLines := ""

    if (currentWindow = "info") {
        articles := []
        currentArticle := ""
        currentSection := ""

        StringSplit, lines, originalText, `n
        Loop, % lines0
        {
            currentLine := lines%A_Index%

            if (RegExMatch(currentLine, "^#")) {
                currentSection := currentLine
                if (currentArticle != "") {
                    articles.Push(currentArticle)
                }
                currentArticle := ""
            }
            else if (RegExMatch(currentLine, "^Статья \d+")) {
                if (currentArticle != "") {
                    articles.Push(currentArticle)
                }
                if (currentSection != "") {
                    currentArticle := currentSection . "`n`n" . currentLine
                    currentSection := ""
                } else {
                    currentArticle := currentLine
                }
            } else if (currentArticle != "") {
                currentArticle .= "`n" . currentLine
            }
        }

        if (currentArticle != "") {
            articles.Push(currentArticle)
        }

        for index, article in articles
        {
            StringLower, articleLower, article
            articleFound := false

            Loop, % searchTerms0
            {
                term := searchTerms%A_Index%
                if (term = "")
                    continue

                StringLower, termLower, term

                if (RegExMatch(termLower, "^\d+(\.\d+)*$")) {
                    if (RegExMatch(articleLower, "статья\s+([\d\.]+)", articleMatch)) {
                        articleNumber := articleMatch1
                        if (ArticleNumberMatchesTerm(articleNumber, termLower)) {
                            articleFound := true
                            break
                        }
                    }
                } else {
                    if (InStr(articleLower, termLower)) {
                        articleFound := true
                        break
                    }
                }
            }

            if (articleFound) {
                foundText .= article . "`n"
                foundAny := true
            }
        }
    } else {
        foundText := ""

        Loop, % lines0
        {
            currentLine := lines%A_Index%
            if (currentLine = "")
                continue

            StringLower, lineLower, currentLine

            foundMatch := false
            Loop, % searchTerms0
            {
                term := searchTerms%A_Index%
                if (term = "")
                    continue

                StringLower, termLower, term
                if (RegExMatch(termLower, "^\d+(\.\d+)*$"))
                {
                    StringSplit, fields, lineLower, |
                    firstField := Trim(fields1)
                    firstField := RegExReplace(firstField, "\s", "")

                    if (NumericLawSearchMatch(firstField, termLower)) {
                        foundMatch := true
                        break
                    }
                }
                else
                {
                    StringSplit, fields, lineLower, |
                    searchableText := ""
                    if (fields0 >= 1) {
                        searchableText := Trim(fields1)
                    }
                    if (fields0 >= 2) {
                        searchableText .= " " Trim(fields2)
                    }
                    if (InStr(searchableText, termLower))
                    {
                        foundMatch := true
                        break
                    }
                }
            }
            if (foundMatch) {
                foundText .= currentLine . "`n"
                foundLines .= currentLine . "`n"
                foundAny := true
            }
        }
    }

        if (currentWindow = "koap" || currentWindow = "uk") {
        if (!foundAny) {
            LV_Delete()
            GuiControl, Disable, CopyReasonBtn
            GuiControl, Disable, CopyFineBtn
            GuiControl, Disable, CopyArrestBtn
            GuiControl, +cGray, CopyReasonBtn
            GuiControl, +cGray, CopyFineBtn
            GuiControl, +cGray, CopyArrestBtn
            GuiControl, Hide, SummaryText1
            GuiControl, Hide, SummaryText2
            GuiControl, Hide, UpdateLabelLaw
            GuiControl, Hide, UpdateBtnLaw
            GuiControl, Move, MyListView, x10 y120 w1000 h%editH%
            if (currentWindow = "koap") {
                LV_ModifyCol(1, 60)
                LV_ModifyCol(2, 600)
                LV_ModifyCol(3, "Center 75")
                LV_ModifyCol(4, "Center 240")
            } else if (currentWindow = "uk") {
                LV_ModifyCol(1, 60)
                LV_ModifyCol(2, 675)
                LV_ModifyCol(3, 0)
                LV_ModifyCol(4, "Center 240")
            }
        } else {
            LV_Delete()
            StringSplit, foundLinesArray, foundLines, `n

            articles := []
            Loop, % foundLinesArray0
            {
                currentLine := foundLinesArray%A_Index%
                if (currentLine = "")
                    continue
                StringSplit, fields, currentLine, |
                if (currentWindow = "koap" && fields0 >= 4) {
                    article := Trim(fields1)
                    description := Trim(fields2)
                    point := Trim(fields3)
                    penalty := Trim(fields4)
                    if (article != "" && description != "" && articles.Length() < 10000) {
                        articles.Push({article: article, description: description, point: point, penalty: penalty})
                    }
                } else if (currentWindow = "uk" && fields0 >= 4) {
                    article := Trim(fields1)
                    description := Trim(fields2)
                    point := Trim(fields3)
                    penalty := Trim(fields4)
                    if (article != "" && description != "" && articles.Length() < 10000) {
                        articles.Push({article: article, description: description, point: point, penalty: penalty})
                    }
                } else if (currentWindow = "uk" && fields0 >= 3) {
                    article := Trim(fields1)
                    description := Trim(fields2)
                    point := "-"
                    penalty := Trim(fields3)
                    if (article != "" && description != "" && articles.Length() < 10000) {
                        articles.Push({article: article, description: description, point: point, penalty: penalty})
                    }
                }
            }

            Loop, % articles.Length() - 1
            {
                currentIdx := A_Index
                Loop, % articles.Length() - currentIdx
                {
                    nextIdx := currentIdx + A_Index
                    if (CompareArticles(articles[currentIdx].article, articles[nextIdx].article) > 0) {
                        temp := articles[currentIdx]
                        articles[currentIdx] := articles[nextIdx]
                        articles[nextIdx] := temp
                    }
                }
            }

            for index, item in articles
            {
                if (currentWindow = "koap") {
                    LV_Add("", item.article, item.description, item.point, item.penalty)
                } else if (currentWindow = "uk") {
                    LV_Add("", item.article, item.description, "", item.penalty)
                }
            }

            if (currentWindow = "koap") {
                LV_ModifyCol(1, 60)
                LV_ModifyCol(2, 600)
                LV_ModifyCol(3, "Center 75")
                LV_ModifyCol(4, "Center 240")
            } else if (currentWindow = "uk") {
                LV_ModifyCol(1, 60)
                LV_ModifyCol(2, 675)
                LV_ModifyCol(3, 0)
                LV_ModifyCol(4, "Center 240")
            }

            summary := CreateSummary(foundLines, searchText, currentWindow)

            StringSplit, summaryLines, summary, `n
            summaryLine1 := summaryLines1
            summaryLine2 := ""
            Loop, % summaryLines0
            {
                if (A_Index = 1)
                    continue
                if (summaryLine2 != "")
                    summaryLine2 .= "`n"
                summaryLine2 .= summaryLines%A_Index%
            }

            if (currentWindow = "koap") {
                lastKoapSearchText := searchText
                lastKoapSummary1 := summaryLine1
                lastKoapSummary2 := summaryLine2
                lastKoapArticles := articles
            } else if (currentWindow = "uk") {
                lastUKSearchText := searchText
                lastUKSummary1 := summaryLine1
                lastUKSummary2 := summaryLine2
                lastUKArticles := articles
            }

            hasReason := InStr(summary, "📋 Причина штрафа/ареста:")
            hasFines := InStr(summary, "💸 Сумма штрафа:")
            hasArrests := InStr(summary, "⏰ Срок ареста:")

            if (hasReason) {
                GuiControl, Enable, CopyReasonBtn
                GuiControl, +cWhite, CopyReasonBtn
            } else {
                GuiControl, Disable, CopyReasonBtn
                GuiControl, +cGray, CopyReasonBtn
            }

            if (hasFines) {
                GuiControl, Enable, CopyFineBtn
                GuiControl, +cWhite, CopyFineBtn
            } else {
                GuiControl, Disable, CopyFineBtn
                GuiControl, +cGray, CopyFineBtn
            }

            if (hasArrests) {
                GuiControl, Enable, CopyArrestBtn
                GuiControl, +cWhite, CopyArrestBtn
            } else {
                GuiControl, Disable, CopyArrestBtn
                GuiControl, +cGray, CopyArrestBtn
            }

            StringSplit, line1Parts, summaryLine1, `n
            StringSplit, line2Parts, summaryLine2, `n
            summaryHeight := line1Parts0 * 17
            if (summaryLine2 != "") {
                summaryHeight += line2Parts0 * 17
            }

            updateBannerH := 0
            listViewH := editH - summaryHeight - 15 - updateBannerH
            if (listViewH < 100)
                listViewH := 100

            GuiControl, Move, MyListView, x10 y120 w1000 h%listViewH%
            if (currentWindow = "koap") {
                LV_ModifyCol(1, 60)
                LV_ModifyCol(2, 600)
                LV_ModifyCol(3, "Center 75")
                LV_ModifyCol(4, "Center 240")
            } else if (currentWindow = "uk") {
                LV_ModifyCol(1, 60)
                LV_ModifyCol(2, 675)
                LV_ModifyCol(3, 0)
                LV_ModifyCol(4, "Center 240")
            }

            GuiControlGet, listViewPos, Pos, MyListView
            summaryY1 := listViewPosY + listViewPosH + 10
            summaryHeight1 := line1Parts0 * 17
            summaryY2 := summaryY1 + summaryHeight1 + 4
            GuiControl, Move, SummaryText1, x10 y%summaryY1% w1000 h%summaryHeight1%
            if (summaryLine2 != "") {
                summaryHeight2 := line2Parts0 * 17
                GuiControl, Move, SummaryText2, x10 y%summaryY2% w1000 h%summaryHeight2%
            }

            if (summaryLine1 != "") {
                GuiControl,, SummaryText1, %summaryLine1%
                GuiControl, Show, SummaryText1
            } else {
                GuiControl,, SummaryText1,
                GuiControl, Hide, SummaryText1
            }
            if (summaryLine2 != "") {
                GuiControl,, SummaryText2, %summaryLine2%
                GuiControl, Show, SummaryText2
            } else {
                GuiControl,, SummaryText2,
                GuiControl, Hide, SummaryText2
            }
            
            if (updateBannerH > 0 && updateScriptVersion != "" && updateServerVersion != "") {
                if (summaryLine2 != "") {
                    updateY := summaryY2 + summaryHeight2 + 6
                } else {
                    updateY := summaryY1 + summaryHeight1 + 6
                }
                updateText := "Доступно обновление! Новая версия: " updateScriptVersion " -> " updateServerVersion
                GuiControl, Move, UpdateLabelLaw, x10 y%updateY% w350 h20
                GuiControl,, UpdateLabelLaw, %updateText%
                GuiControl, Show, UpdateLabelLaw
                GuiControlGet, updPos, Pos, UpdateLabelLaw
                buttonX := updPosX + updPosW + 10
                buttonY := updateY - 3
                GuiControl, Move, UpdateBtnLaw, x%buttonX% y%buttonY% w160 h20
                GuiControl, Show, UpdateBtnLaw
            } else {
                GuiControl, Hide, UpdateLabelLaw
                GuiControl, Hide, UpdateBtnLaw
            }
        }
        return
    }

    if (!foundAny) {
        foundText .= "`nПоиск: " searchText "`nНичего не найдено"
        if (currentWindow != "info") {
            GuiControl, Disable, CopyReasonBtn
            GuiControl, Disable, CopyFineBtn
            GuiControl, Disable, CopyArrestBtn
            GuiControl, +cGray, CopyReasonBtn
            GuiControl, +cGray, CopyFineBtn
            GuiControl, +cGray, CopyArrestBtn
            GuiControl, Move, MyText, x10 y90 h%editH%
        } else {
            GuiControl, Show, BtnPK
            GuiControl, Show, BtnKoap
            GuiControl, Show, BtnUK
            GuiControl, Show, BtnUPK
            GuiControl, Show, BtnPDD
            GuiControl, Show, BtnTK
            GuiControl, Show, BtnUkazy
            GuiControl, Show, BtnFZWeapon
            GuiControl, Show, BtnFZProperty
            GuiControl, Show, BtnFZPolice
            GuiControl, Show, BtnFZGosluzhba
            GuiControl, Show, BtnFZRegime
            GuiControl, Show, BtnKonst
            GuiControl, Move, MyText, x10 y90
        }
    } else {
        if (currentWindow != "info") {
            summary := CreateSummary(foundText, searchText, currentWindow)
            foundText .= summary

            hasReason := InStr(foundText, "📋 Причина штрафа/ареста:")
            hasFines := InStr(foundText, "💸 Сумма штрафа:")
            hasArrests := InStr(foundText, "⏰ Срок ареста:")

            if (hasReason) {
                GuiControl, Enable, CopyReasonBtn
                GuiControl, +cWhite, CopyReasonBtn
            } else {
                GuiControl, Disable, CopyReasonBtn
                GuiControl, +cGray, CopyReasonBtn
            }

            if (hasFines) {
                GuiControl, Enable, CopyFineBtn
                GuiControl, +cWhite, CopyFineBtn
            } else {
                GuiControl, Disable, CopyFineBtn
                GuiControl, +cGray, CopyFineBtn
            }

            if (hasArrests) {
                GuiControl, Enable, CopyArrestBtn
                GuiControl, +cWhite, CopyArrestBtn
            } else {
                GuiControl, Disable, CopyArrestBtn
                GuiControl, +cGray, CopyArrestBtn
            }

            newEditH := editH - 35
            GuiControl, Move, MyText, x10 y125 h%newEditH%
        } else {
            GuiControl, Show, BtnPK
            GuiControl, Show, BtnKoap
            GuiControl, Show, BtnUK
            GuiControl, Show, BtnUPK
            GuiControl, Show, BtnPDD
            GuiControl, Show, BtnTK
            GuiControl, Show, BtnUkazy
            GuiControl, Show, BtnFZWeapon
            GuiControl, Show, BtnFZProperty
            GuiControl, Show, BtnFZPolice
            GuiControl, Show, BtnFZGosluzhba
            GuiControl, Show, BtnFZRegime
            GuiControl, Show, BtnKonst
            GuiControl, Move, MyText, x10 y90
        }
    }

    if (currentWindow = "info") {
        lastInfoSearchText := searchText
        lastInfoFoundText := foundText
    }

    GuiControl,, MyText, % foundText
return

ArticleNumberMatchesTerm(articleNumber, termLower) {
    articleNumber := Trim(articleNumber)
    articleNumber := RegExReplace(articleNumber, "\s", "")
    termLower := Trim(termLower)
    termLower := RegExReplace(termLower, "\s", "")

    if (articleNumber = "" || termLower = "")
        return false

    articleNumProcessed := articleNumber
    termProcessed := termLower
    StringLower, articleNumProcessed, articleNumProcessed
    StringLower, termProcessed, termProcessed

    if (!RegExMatch(termProcessed, "^\d+(\.\d+)*$"))
        return false

    StringSplit, termParts, termProcessed, .
    StringSplit, articleParts, articleNumProcessed, .

    if (termParts0 = 0 || articleParts0 = 0)
        return false

    if (termParts0 = 1) {
        if (articleParts1 = termParts1)
            return true
        return false
    }

    if (termParts0 > articleParts0)
        return false

    Loop, % termParts0
    {
        if (articleParts%A_Index% != termParts%A_Index%)
            return false
    }

    return true
}

NumericLawSearchMatch(articleNumber, termLower) {
    global currentWindow, koapPlainBase, koapPlainBaseInit, ukPlainBase, ukPlainBaseInit

    articleNumber := Trim(articleNumber)
    articleNumber := RegExReplace(articleNumber, "\s", "")
    termLower := Trim(termLower)
    termLower := RegExReplace(termLower, "\s", "")

    if (articleNumber = "" || termLower = "")
        return false

    if (!RegExMatch(termLower, "^\d+(\.\d+)*$"))
        return false

    StringSplit, termParts, termLower, .
    StringSplit, articleParts, articleNumber, .

    if (termParts0 = 0 || articleParts0 = 0)
        return false

    hasPlainBase := false
    base := termParts1

    if (currentWindow = "koap") {
        if (!koapPlainBaseInit) {
            GetKoapArticles()
        }
        hasPlainBase := koapPlainBase.HasKey(base)
    } else if (currentWindow = "uk") {
        if (!ukPlainBaseInit) {
            GetUKArticles()
        }
        hasPlainBase := ukPlainBase.HasKey(base)
    } else {
        return ArticleNumberMatchesTerm(articleNumber, termLower)
    }

    if (termParts0 = 1) {
        if (hasPlainBase) {
            if (articleParts0 = 1 && articleParts1 = base)
                return true
            return false
        } else {
            if (articleParts1 = base)
                return true
            return false
        }
    }

    if (termParts0 > articleParts0)
        return false

    Loop, % termParts0
    {
        if (articleParts%A_Index% != termParts%A_Index%)
            return false
    }

    return true
}

CheckFocus:
    WinGet, id, ID, A
    WinGetTitle, activeTitle, ahk_id %id%
    global GuiID
    if (id != GuiID)
    {
        if (activeTitle = "Информация о статье")
            return
        SaveWindowPos()
        Gui, Hide
        isOpen := false
        currentWindow := ""
        SetTimer, CheckFocus, Off
    }
return

SetClickThrough(enable := true) {
    global GuiID, isClickThrough
    if (GuiID = "")
        return
    isClickThrough := enable
    if (enable) {
        WinSet, ExStyle, +0x20, ahk_id %GuiID%
    } else {
        WinSet, ExStyle, -0x20, ahk_id %GuiID%
    }
}

SetWindowRoundedCorners(winTitle, w, h, radius := 15) {
    WinGet, hwnd, ID, %winTitle%
    if (!hwnd)
        return
    rgn := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", w, "Int", h, "Int", radius * 2, "Int", radius * 2, "Ptr")
    if (rgn)
        DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", rgn, "Int", 1)
}

SetControlRoundedCorners(ctrlHwnd, w, h, radius := 4) {
    if (!ctrlHwnd)
        return
    rgn := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 1, "Int", w, "Int", h - 1, "Int", radius * 2, "Int", radius * 2, "Ptr")
    if (rgn)
        DllCall("SetWindowRgn", "Ptr", ctrlHwnd, "Ptr", rgn, "Int", 1)
}

WM_ACTIVATE(wParam, lParam, msg, hwnd) {
    global GuiID, isClickThrough
    if (hwnd = GuiID) {
        if (wParam) {
            SetClickThrough(false)
            SetTimer, CheckFocus, 100
        } else {
            SetClickThrough(true)
            SetTimer, CheckFocus, Off
        }
    }
}

ShowInstruction:
    global keyForInfo, keyForKoap, keyForUK, keyForScreenshot, keyForBadge, keyForPresentation, keyForSettings, shownInstruction
    
    IfWinExist, RMRP - Криминальная Москва
    {
        shownInstruction := true
        return
    }
    
    if (shownInstruction = true) {
        return
    }
    
    shownInstruction := true
    
    showInstrVal := LoadIniValue("settings.ShowInstructionOnStart")
    if (showInstrVal = "")
        showInstrVal := "1"
    if (showInstrVal != "1") {
        return
    }
    
    scriptVersion := ""
    try {
        scriptVersion := LoadIniValue("version")
    } catch {
    }
    if (scriptVersion = "") {
        scriptVersion := GetUnixTimestamp()
        SaveIniValue("version", scriptVersion)
    }
    
    try {
        Gui, InstructionGui:Destroy
    } catch {
    }
    
    try {
        Gui, InstructionGui:+AlwaysOnTop
        Gui, InstructionGui:Color, 0a0a0a
    
    Gui, InstructionGui:Font, s16 cYellow Bold, Consolas
    Gui, InstructionGui:Add, Text, x10 y20 w580 Center, ДОБРО ПОЖАЛОВАТЬ
    
    Gui, InstructionGui:Font, s10 cWhite, Consolas
    Gui, InstructionGui:Add, Text, x10 y48 w580 Center cGray, Справочник и полезные функции для сотрудников правоохранительных органов RMRP
    
    Gui, InstructionGui:Add, Text, x10 y88 w580 h2 +0x10
    
    Gui, InstructionGui:Font, s10 cWhite, Consolas
    yPos := 103
    
    displayKeySettings := ""
    try {
        displayKeySettings := FormatKeyForDisplay(keyForSettings)
    } catch {
        displayKeySettings := keyForSettings
    }
    Gui, InstructionGui:Font, s10 cYellow, Consolas
    Gui, InstructionGui:Add, Edit, x10 y%yPos% w120 h25 ReadOnly -TabStop Center BackgroundFFFFFF, %displayKeySettings%
    Gui, InstructionGui:Font, s10 cWhite, Consolas
    textY := yPos + 3
    Gui, InstructionGui:Add, Text, x145 y%textY% w445, Управление скриптом
    yPos += 30
    
    displayKeyInfo := FormatKeyForDisplay(keyForInfo)
    Gui, InstructionGui:Font, s10 cYellow, Consolas
    Gui, InstructionGui:Add, Edit, x10 y%yPos% w120 h25 ReadOnly -TabStop Center BackgroundFFFFFF, %displayKeyInfo%
    Gui, InstructionGui:Font, s10 cWhite, Consolas
    textY := yPos + 3
    Gui, InstructionGui:Add, Text, x145 y%textY% w445, Полезная информация (статьи, законы)
    yPos += 30
    
    displayKeyKoap := FormatKeyForDisplay(keyForKoap)
    Gui, InstructionGui:Font, s10 cYellow, Consolas
    Gui, InstructionGui:Add, Edit, x10 y%yPos% w120 h25 ReadOnly -TabStop Center BackgroundFFFFFF, %displayKeyKoap%
    Gui, InstructionGui:Font, s10 cWhite, Consolas
    textY := yPos + 3
    Gui, InstructionGui:Add, Text, x145 y%textY% w445, Административные нарушения (КоАП РФ)
    yPos += 30
    
    displayKeyUK := FormatKeyForDisplay(keyForUK)
    Gui, InstructionGui:Font, s10 cYellow, Consolas
    Gui, InstructionGui:Add, Edit, x10 y%yPos% w120 h25 ReadOnly -TabStop Center BackgroundFFFFFF, %displayKeyUK%
    Gui, InstructionGui:Font, s10 cWhite, Consolas
    textY := yPos + 3
    Gui, InstructionGui:Add, Text, x145 y%textY% w445, Уголовные преступления (УК РФ)
    yPos += 30
    
    displayKeyBadge := FormatKeyForDisplay(keyForBadge)
    Gui, InstructionGui:Font, s10 cYellow, Consolas
    Gui, InstructionGui:Add, Edit, x10 y%yPos% w120 h25 ReadOnly -TabStop Center BackgroundFFFFFF, %displayKeyBadge%
    Gui, InstructionGui:Font, s10 cWhite, Consolas
    textY := yPos + 3
    Gui, InstructionGui:Add, Text, x145 y%textY% w445, Предъявление жетона
    yPos += 30
    
    displayKeyPresentation := FormatKeyForDisplay(keyForPresentation)
    Gui, InstructionGui:Font, s10 cYellow, Consolas
    Gui, InstructionGui:Add, Edit, x10 y%yPos% w120 h25 ReadOnly -TabStop Center BackgroundFFFFFF, %displayKeyPresentation%
    Gui, InstructionGui:Font, s10 cWhite, Consolas
    textY := yPos + 3
    Gui, InstructionGui:Add, Text, x145 y%textY% w445, Отправить представление
    yPos += 30
    
    displayKeyScreenshot := FormatKeyForDisplay(keyForScreenshot)
    Gui, InstructionGui:Font, s10 cYellow, Consolas
    Gui, InstructionGui:Add, Edit, x10 y%yPos% w120 h25 ReadOnly -TabStop Center BackgroundFFFFFF, %displayKeyScreenshot%
    Gui, InstructionGui:Font, s10 cWhite, Consolas
    textY := yPos + 3
    Gui, InstructionGui:Add, Text, x145 y%textY% w445, Сделать скриншот в папку
    yPos += 40
    
        Gui, InstructionGui:Add, Text, x10 y%yPos% w580 h2 +0x10
        yPos += 15
        
        Gui, InstructionGui:Font, s10 cWhite, Consolas
    Gui, InstructionGui:Add, Button, x10 y%yPos% w580 h40 gOpenDiscordLink, 💬  Discord-сервер поддержки — discord.gg/fwwgBfppPT
    
    yPos += 50
    
    Gui, InstructionGui:Font, s10 cGray Italic, Consolas
    Gui, InstructionGui:Add, Text, x10 y%yPos% w580 Center, Разработано для помощи сотрудникам правоохранительных органов
    yPos += 25
    Gui, InstructionGui:Font, s9 cGray, Consolas
    currentYear := A_Year
    Gui, InstructionGui:Add, Text, x10 y%yPos% w580 Center, © %currentYear% | Версия %scriptVersion% | Автор: SeverskiY
    
    yPos += 35
    winH := yPos
    
    try {
        Gui, InstructionGui:Show, w600 h%winH% Center, RMRP — Справочник сотрудника
        shownInstruction := true
        
        try {
            Gui, LoadingGui:Destroy
        } catch {
        }
    } catch e {
        shownInstruction := true
        
        try {
            Gui, LoadingGui:Destroy
        } catch {
        }
    }
    } catch e {
        
        try {
            Gui, LoadingGui:Destroy
        } catch {
        }
    }
return

OpenDiscordLink:
    Run, https://discord.gg/fwwgBfppPT
    return

return

InstructionGuiEscape:
InstructionGuiClose:
    Gui, InstructionGui:Destroy
    shownInstruction := false
return

#If, IsMainWindowOpen()
    Esc::
        global isOpen, currentWindow
        SaveSearchText(currentWindow)
        Gui, +LastFound
        GuiID := WinExist()
        SaveWindowPos()
        Gui, Hide
        isOpen := false
        currentWindow := ""
    return
#If

CreateLawWindow(windowType) {
    WriteLog("CreateLawWindow: создание окна типа " . windowType)
    global isCreatingWindow, originalText, currentWindow, isOpen, GuiID, editH
    global SearchBox, SearchButton, ClearButton, CopyReasonBtn, CopyFineBtn, CopyArrestBtn, DetentionTimerBtn
    global MyListView, SummaryText1, SummaryText2, searchText
    global LoadingLabel, UpdateLabelLaw, UpdateBtnLaw

    if (isCreatingWindow) {
        return
    }
    isCreatingWindow := true
    originalText := ""
    Gui, Destroy
    Loop, 10
    {
        IfWinNotExist, ahk_class AutoHotkeyGUI
            break
        Sleep, 10
    }
    winH := (A_ScreenHeight < 800) ? A_ScreenHeight : 800
    editH := winH - 120 - 10
    Gui, +AlwaysOnTop +ToolWindow -Caption
    Gui, Color, 0a0a0a

    if (windowType = "koap") {
        title := "⚖️ КОАП РФ — Административные нарушения ⚖️"
        fillFunc := "FillKoapListView"
        getTextFunc := "GetKoapArticlesAsText"
    } else if (windowType = "uk") {
        title := "⚖️ УК РФ — Уголовные преступления ⚖️"
        fillFunc := "FillUKListView"
        getTextFunc := "GetUKArticlesAsText"
    } else {
        isCreatingWindow := false
        return
    }
    currentWindow := windowType

    Gui, Font, s16 cYellow, Consolas
    Gui, Add, Text, vTitleText x10 y10 w1000 Center, %title%

    Gui, Font, s10 cWhite, Consolas
    Gui, Add, Edit, vSearchBox x10 y50 w820 h30 gSearchText cBlack BackgroundFFFFFF,
    searchText := LoadSearchText(windowType)
    global blockSearchUpdate
    blockSearchUpdate := true
    GuiControl,, SearchBox, %searchText%
    blockSearchUpdate := false
    Gui, Add, Button, vSearchButton x835 y50 w85 h30 gDoSearch, Искать
    Gui, Add, Button, vClearButton x925 y50 w85 h30 gClearSearch, Очистить
    Gui, Add, Button, vCopyReasonBtn x10 y85 w235 h25 gCopyReason, Копировать причину
    Gui, Add, Button, vCopyFineBtn x250 y85 w235 h25 gCopyFineAmount, Копировать штраф
    Gui, Add, Button, vCopyArrestBtn x490 y85 w235 h25 gCopyLawyerCall, Вызов адвоката
    Gui, Add, Button, vDetentionTimerBtn x730 y85 w280 h25 gShowDetentionTimerMenu, Запустить таймер
    Gui, Font, s9 cWhite, Consolas
    Gui, Add, ListView, vMyListView x10 y120 w1000 h%editH% Multi AltSubmit -HScroll gListViewClick Hidden, Статья|Расшифровка|ПДД|Мера наказания
    Gui, Add, Text, vLoadingLabel x10 y120 w1000 h%editH% cGray Center +0x200, Загрузка таблицы...
    Gui, Font, s9 cWhite, Consolas
    Gui, Add, Text, vSummaryText1 x10 y0 w1000 Hidden BackgroundTrans,
    Gui, Add, Text, vSummaryText2 x10 y0 w1000 Hidden BackgroundTrans,
    Gui, Font, s9 cYellow, Consolas
    Gui, Add, Text, vUpdateLabelLaw x10 y0 w350 h20 Hidden BackgroundTrans,
    Gui, Font, s9 cWhite, Consolas
    Gui, Add, Button, vUpdateBtnLaw x0 y0 w160 h20 gRestartScriptNow Hidden, Перезапустить скрипт
    GuiControl, Disable, CopyReasonBtn
    GuiControl, Disable, CopyFineBtn
    GuiControl, Disable, CopyArrestBtn
    GuiControl, +cGray, CopyReasonBtn
    GuiControl, +cGray, CopyFineBtn
    GuiControl, +cGray, CopyArrestBtn
    GuiControl, Show, CopyReasonBtn
    GuiControl, Show, CopyFineBtn
    GuiControl, Show, CopyArrestBtn

    Sleep, 10

    if (windowType = "koap") {
        LV_ModifyCol(1, 60)
        LV_ModifyCol(2, 600)
        LV_ModifyCol(3, "Center 75")
        LV_ModifyCol(4, "Center 240")
    } else if (windowType = "uk") {
        LV_ModifyCol(1, 60)
        LV_ModifyCol(2, 675)
        LV_ModifyCol(3, 0)
        LV_ModifyCol(4, "Center 240")
    }
    global MyListViewHwnd
    GuiControlGet, MyListViewHwnd, Hwnd, MyListView
    OnMessage(0x004E, "WM_NOTIFY_ListView")

    LVM_SETBKCOLOR := 0x1001
    LVM_SETTEXTBKCOLOR := 0x1026
    LVM_SETTEXTCOLOR := 0x1023
    DllCall("SendMessage", "UInt", MyListViewHwnd, "UInt", LVM_SETBKCOLOR, "UInt", 0, "UInt", 0x0a0a0a)
    DllCall("SendMessage", "UInt", MyListViewHwnd, "UInt", LVM_SETTEXTBKCOLOR, "UInt", 0, "UInt", 0x0a0a0a)
    DllCall("SendMessage", "UInt", MyListViewHwnd, "UInt", LVM_SETTEXTCOLOR, "UInt", 0, "UInt", 0xFFFFFF)

    LVM_SETEXTENDEDLISTVIEWSTYLE := 0x1036
    LVS_EX_FULLROWSELECT := 0x00000020
    extendedStyle := LVS_EX_FULLROWSELECT
    SendMessage, %LVM_SETEXTENDEDLISTVIEWSTYLE%, %extendedStyle%, %extendedStyle%, , ahk_id %MyListViewHwnd%

    WS_HSCROLL := 0x00100000
    currentStyle := DllCall("GetWindowLong", "UInt", MyListViewHwnd, "Int", -16, "UInt")
    newStyle := currentStyle & ~WS_HSCROLL
    DllCall("SetWindowLong", "UInt", MyListViewHwnd, "Int", -16, "UInt", newStyle)

    Gui, +OwnDialogs
    pos := LoadWindowPos(windowType)
    pos := RegExReplace(pos, "w\d+ h\d+", "w1020 h" winH)
    Gui, Show, %pos% NA
    GuiID := WinExist()
    SetClickThrough(true)
    OnMessage(0x201, "OnMouseDown")
    OnMessage(0x0232, "WM_EXITSIZEMOVE")
    isOpen := true
    WriteLog("CreateLawWindow: окно " . windowType . " успешно создано и показано")

    GuiControl, Show, LoadingLabel

    if (getTextFunc = "GetKoapArticlesAsText") {
        text := GetKoapArticlesAsText()
        originalText := text
        if (searchText != "") {
            FillKoapListView("")
        } else if (IsFrequentArticlesEnabled()) {
            frequentText := GetFrequentArticlesAsText("koap")
            if (frequentText != "") {
                FillKoapListView(frequentText)
            } else {
                FillKoapListView("")
            }
        } else {
            FillKoapListView("")
        }
    } else if (getTextFunc = "GetUKArticlesAsText") {
        text := GetUKArticlesAsText()
        originalText := text
        if (searchText != "") {
            FillUKListView("")
        } else if (IsFrequentArticlesEnabled()) {
            frequentText := GetFrequentArticlesAsText("uk")
            if (frequentText != "") {
                FillUKListView(frequentText)
            } else {
                FillUKListView("")
            }
        } else {
            FillUKListView("")
        }
    }
    Gui, Submit, NoHide

    global lastKoapSearchText, lastKoapSummary1, lastKoapSummary2
    global lastUKSearchText, lastUKSummary1, lastUKSummary2
    if (searchText != "") {
        if (windowType = "koap" && searchText = lastKoapSearchText && lastKoapSummary1 != "") {
            RestoreLawSearchFromCache("koap")
        } else if (windowType = "uk" && searchText = lastUKSearchText && lastUKSummary1 != "") {
            RestoreLawSearchFromCache("uk")
        } else {
            Gosub, SearchText
        }
    }
    GuiControl, Hide, LoadingLabel
    GuiControl, Show, MyListView
    isCreatingWindow := false
}

UpdateInfoWindowContent() {
    global originalText, currentWindow, searchText, blockSearchUpdate, editH
    global MyText, TitleText, SearchBox, ClearButton, SearchButton
    global lastInfoSearchText, lastInfoFoundText
    global isOpen, GuiID, winH
    global BtnPK, BtnKoap, BtnUK, BtnUPK, BtnPDD, BtnTK
    global BtnFZWeapon, BtnFZProperty, BtnFZPolice, BtnFZGosluzhba, BtnFZRegime, BtnKonst
    global SummaryText1, SummaryText2, UpdateLabelLaw, UpdateBtnLaw
    
    GuiControlGet, MyTextExists, Hwnd, MyText
    if (!MyTextExists) {
        winH := (A_ScreenHeight < 800) ? A_ScreenHeight : 800
        buttonAreaH := 50
        editH := winH - 95 - buttonAreaH - 10
        
        GuiControlGet, SearchBoxExists, Hwnd, SearchBox
        if (!SearchBoxExists) {
            Gui, Add, Edit, vSearchBox x10 y50 w820 h30 gSearchText cBlack BackgroundFFFFFF,
        } else {
            GuiControl, Move, SearchBox, x10 y50 w820 h30
        }
        
        GuiControlGet, SearchButtonExists, Hwnd, SearchButton
        if (!SearchButtonExists) {
            Gui, Add, Button, vSearchButton x835 y50 w85 h30 gDoSearch, Искать
        }
        
        GuiControlGet, ClearButtonExists, Hwnd, ClearButton
        if (!ClearButtonExists) {
            Gui, Add, Button, vClearButton x925 y50 w85 h30 gClearSearch, Очистить
        }
        
        Gui, Add, Edit, vMyText x10 y90 w1000 h%editH% ReadOnly +VScroll +WantReturn -Tabstop cWhite Background000000,
        
        buttonY1 := winH - 55
        buttonY2 := winH - 30
        
        GuiControlGet, BtnPKExists, Hwnd, BtnPK
        if (!BtnPKExists) {
            Gui, Add, Button, vBtnPK x10 y%buttonY1% w160 h20 gOpenLinkPK, 📘 ПК
            Gui, Add, Button, vBtnKoap x175 y%buttonY1% w160 h20 gOpenLinkKoap, 📋 КоАП
            Gui, Add, Button, vBtnUK x340 y%buttonY1% w160 h20 gOpenLinkUK, ⚖️ УК
            Gui, Add, Button, vBtnUPK x505 y%buttonY1% w160 h20 gOpenLinkUPK, 📗 УПК
            Gui, Add, Button, vBtnPDD x670 y%buttonY1% w160 h20 gOpenLinkPDD, 🚗 ПДД
            Gui, Add, Button, vBtnTK x835 y%buttonY1% w175 h20 gOpenLinkTK, 💼 Трудовой Кодекс
            Gui, Add, Button, vBtnFZWeapon x10 y%buttonY2% w160 h20 gOpenLinkFZWeapon, 🔫 Об Оружии
            Gui, Add, Button, vBtnFZProperty x175 y%buttonY2% w160 h20 gOpenLinkFZProperty, 🏛️ О Госсобственности
            Gui, Add, Button, vBtnFZPolice x340 y%buttonY2% w160 h20 gOpenLinkFZPolice, 👮 О Полиции
            Gui, Add, Button, vBtnFZGosluzhba x505 y%buttonY2% w160 h20 gOpenLinkFZGosluzhba, 📋 О Госслужбе
            Gui, Add, Button, vBtnFZRegime x670 y%buttonY2% w160 h20 gOpenLinkFZRegime, ⚠️ О Правовых режимах
            Gui, Add, Button, vBtnKonst x835 y%buttonY2% w175 h20 gOpenLinkKonst, 📜 Конституция
        }
    }
    
    currentWindow := "info"
    
    GuiControl,, TitleText, ⚖️ Полезная информация ⚖️
    
    GuiControl, Hide, MyListView
    GuiControl, Hide, CopyReasonBtn
    GuiControl, Hide, CopyFineBtn
    GuiControl, Hide, CopyArrestBtn
    GuiControl, Hide, DetentionTimerBtn
    GuiControl, Hide, SummaryText1
    GuiControl, Hide, SummaryText2
    GuiControl, Hide, UpdateLabelLaw
    GuiControl, Hide, UpdateBtnLaw
    GuiControl,, SummaryText1,
    GuiControl,, SummaryText2,
    GuiControl, Show, SearchButton
    GuiControl, Show, ClearButton
    GuiControl, Show, MyText
    GuiControl, Show, BtnPK
    GuiControl, Show, BtnKoap
    GuiControl, Show, BtnUK
    GuiControl, Show, BtnUPK
    GuiControl, Show, BtnPDD
    GuiControl, Show, BtnTK
    GuiControl, Show, BtnFZWeapon
    GuiControl, Show, BtnFZProperty
    GuiControl, Show, BtnFZPolice
    GuiControl, Show, BtnFZGosluzhba
    GuiControl, Show, BtnFZRegime
    GuiControl, Show, BtnKonst
    
    searchText := LoadSearchText("info")
    blockSearchUpdate := true
    GuiControl,, SearchBox, %searchText%
    blockSearchUpdate := false
    
    text := GetInfoText()
    originalText := text
    GuiControl,, MyText, %text%
    
    if (searchText != "") {
        if (searchText = lastInfoSearchText && lastInfoFoundText != "" && currentWindow = "info") {
            GuiControl,, MyText, % lastInfoFoundText
        } else {
            Gosub, SearchText
        }
    } else {
        lastInfoSearchText := ""
        lastInfoFoundText := ""
    }
}

UpdateLawWindowContent(windowType) {
    global originalText, currentWindow, searchText, blockSearchUpdate, editH
    global MyListView, MyListViewHwnd, TitleText, LoadingLabel, SearchBox
    global lastKoapSearchText, lastKoapSummary1, lastKoapSummary2
    global lastUKSearchText, lastUKSummary1, lastUKSummary2
    global SearchButton, ClearButton, CopyReasonBtn, CopyFineBtn, CopyArrestBtn, DetentionTimerBtn
    global SummaryText1, SummaryText2, UpdateLabelLaw, UpdateBtnLaw
    global isOpen, GuiID, winH
    
    winH := (A_ScreenHeight < 800) ? A_ScreenHeight : 800
    editH := winH - 120 - 10
    
    GuiControlGet, MyListViewExists, Hwnd, MyListView
    if (!MyListViewExists) {
        
        GuiControlGet, SearchBoxExists, Hwnd, SearchBox
        if (!SearchBoxExists) {
            Gui, Add, Edit, vSearchBox x10 y50 w820 h30 gSearchText cBlack BackgroundFFFFFF,
        } else {
            GuiControl, Move, SearchBox, x10 y50 w820 h30
        }
        
        GuiControlGet, SearchButtonExists, Hwnd, SearchButton
        if (!SearchButtonExists) {
            Gui, Add, Button, vSearchButton x835 y50 w85 h30 gDoSearch, Искать
        }
        
        GuiControlGet, ClearButtonExists, Hwnd, ClearButton
        if (!ClearButtonExists) {
            Gui, Add, Button, vClearButton x925 y50 w85 h30 gClearSearch, Очистить
        }
        
        GuiControlGet, CopyReasonBtnExists, Hwnd, CopyReasonBtn
        if (!CopyReasonBtnExists) {
            Gui, Add, Button, vCopyReasonBtn x10 y85 w235 h25 gCopyReason, Копировать причину
            Gui, Add, Button, vCopyFineBtn x250 y85 w235 h25 gCopyFineAmount, Копировать штраф
            Gui, Add, Button, vCopyArrestBtn x490 y85 w235 h25 gCopyLawyerCall, Вызов адвоката
            Gui, Add, Button, vDetentionTimerBtn x730 y85 w280 h25 gShowDetentionTimerMenu, Запустить таймер
        }
        
        Gui, Add, ListView, vMyListView x10 y120 w1000 h%editH% Multi AltSubmit -HScroll gListViewClick, Статья|Расшифровка|ПДД|Мера наказания
        Gui, Add, Text, vLoadingLabel x10 y120 w1000 h%editH% cGray Center +0x200, Загрузка таблицы...
        Gui, Font, s9 cWhite, Consolas
        Gui, Add, Text, vSummaryText1 x10 y0 w1000 Hidden BackgroundTrans,
        Gui, Add, Text, vSummaryText2 x10 y0 w1000 Hidden BackgroundTrans,
        Gui, Font, s9 cYellow, Consolas
        Gui, Add, Text, vUpdateLabelLaw x10 y0 w350 h20 Hidden BackgroundTrans,
        Gui, Font, s9 cWhite, Consolas
        Gui, Add, Button, vUpdateBtnLaw x0 y0 w160 h20 gRestartScriptNow Hidden, Перезапустить скрипт
        
        GuiControlGet, MyListViewHwnd, Hwnd, MyListView
        OnMessage(0x004E, "WM_NOTIFY_ListView")
        
        LVM_SETBKCOLOR := 0x1001
        LVM_SETTEXTBKCOLOR := 0x1026
        LVM_SETTEXTCOLOR := 0x1023
        DllCall("SendMessage", "UInt", MyListViewHwnd, "UInt", LVM_SETBKCOLOR, "UInt", 0, "UInt", 0x0a0a0a)
        DllCall("SendMessage", "UInt", MyListViewHwnd, "UInt", LVM_SETTEXTBKCOLOR, "UInt", 0, "UInt", 0x0a0a0a)
        DllCall("SendMessage", "UInt", MyListViewHwnd, "UInt", LVM_SETTEXTCOLOR, "UInt", 0, "UInt", 0xFFFFFF)
        
        LVM_SETEXTENDEDLISTVIEWSTYLE := 0x1036
        LVS_EX_FULLROWSELECT := 0x00000020
        extendedStyle := LVS_EX_FULLROWSELECT
        SendMessage, %LVM_SETEXTENDEDLISTVIEWSTYLE%, %extendedStyle%, %extendedStyle%, , ahk_id %MyListViewHwnd%
        
        WS_HSCROLL := 0x00100000
        currentStyle := DllCall("GetWindowLong", "UInt", MyListViewHwnd, "Int", -16, "UInt")
        newStyle := currentStyle & ~WS_HSCROLL
        DllCall("SetWindowLong", "UInt", MyListViewHwnd, "Int", -16, "UInt", newStyle)
    }
    
    currentWindow := windowType
    
    if (windowType = "koap") {
        title := "⚖️ КОАП РФ — Административные нарушения ⚖️"
    } else if (windowType = "uk") {
        title := "⚖️ УК РФ — Уголовные преступления ⚖️"
    } else {
        return
    }
    
    GuiControl,, TitleText, %title%
    
    GuiControl, Hide, MyText
    GuiControl, Hide, BtnPK
    GuiControl, Hide, BtnKoap
    GuiControl, Hide, BtnUK
    GuiControl, Hide, BtnUPK
    GuiControl, Hide, BtnPDD
    GuiControl, Hide, BtnTK
    GuiControl, Hide, BtnFZWeapon
    GuiControl, Hide, BtnFZProperty
    GuiControl, Hide, BtnFZPolice
    GuiControl, Hide, BtnFZGosluzhba
    GuiControl, Hide, BtnFZRegime
    GuiControl, Hide, BtnKonst
    GuiControl, Hide, SummaryText1
    GuiControl, Hide, SummaryText2
    GuiControl, Hide, UpdateLabelLaw
    GuiControl, Hide, UpdateBtnLaw
    GuiControl,, SummaryText1,
    GuiControl,, SummaryText2,
    GuiControl, Show, SearchButton
    GuiControl, Show, CopyReasonBtn
    GuiControl, Show, CopyFineBtn
    GuiControl, Show, CopyArrestBtn
    GuiControl, Show, DetentionTimerBtn
    
    GuiControl, Move, MyListView, x10 y120 w1000 h%editH%
    GuiControl, Move, LoadingLabel, x10 y120 w1000 h%editH%
    
    LV_Delete()
    
    searchText := LoadSearchText(windowType)
    blockSearchUpdate := true
    GuiControl,, SearchBox, %searchText%
    blockSearchUpdate := false
    
    GuiControl, Hide, MyListView
    GuiControl, Show, LoadingLabel
    
    if (windowType = "koap") {
        LV_ModifyCol(1, 60)
        LV_ModifyCol(2, 600)
        LV_ModifyCol(3, "Center 75")
        LV_ModifyCol(4, "Center 240")
        
        text := GetKoapArticlesAsText()
        originalText := text
        if (searchText != "") {
            FillKoapListView("")
        } else if (IsFrequentArticlesEnabled()) {
            frequentText := GetFrequentArticlesAsText("koap")
            if (frequentText != "") {
                FillKoapListView(frequentText)
            } else {
                FillKoapListView("")
            }
        } else {
            FillKoapListView("")
        }
        
        if (searchText != "" && searchText = lastKoapSearchText && lastKoapSummary1 != "") {
            RestoreLawSearchFromCache("koap")
        } else if (searchText != "") {
            Gosub, SearchText
        }
    } else if (windowType = "uk") {
        LV_ModifyCol(1, 60)
        LV_ModifyCol(2, 675)
        LV_ModifyCol(3, 0)
        LV_ModifyCol(4, "Center 240")
        
        text := GetUKArticlesAsText()
        originalText := text
        if (searchText != "") {
            FillUKListView("")
        } else if (IsFrequentArticlesEnabled()) {
            frequentText := GetFrequentArticlesAsText("uk")
            if (frequentText != "") {
                FillUKListView(frequentText)
            } else {
                FillUKListView("")
            }
        } else {
            FillUKListView("")
        }
        
        if (searchText != "" && searchText = lastUKSearchText && lastUKSummary1 != "") {
            RestoreLawSearchFromCache("uk")
        } else if (searchText != "") {
            Gosub, SearchText
        }
    }
    
    GuiControl, Hide, LoadingLabel
    GuiControl, Show, MyListView
}

CreateKoapWindow:
    WriteLog("CreateKoapWindow: начало создания окна")
    CreateLawWindow("koap")
    WriteLog("CreateKoapWindow: окно создано")
return

CreateUKWindow:
    WriteLog("CreateUKWindow: начало создания окна")
    CreateLawWindow("uk")
    WriteLog("CreateUKWindow: окно создано")
return

CreateInfoWindow:
    global isCreatingWindow, originalText, currentWindow, isOpen, GuiID, editH, searchText
    global SearchBox, MyText, blockSearchUpdate
    global lastInfoSearchText, lastInfoFoundText

    WriteLog("CreateInfoWindow: начало создания окна")
    if (isCreatingWindow) {
        WriteLog("CreateInfoWindow: окно уже создается, пропуск")
        return
    }
    isCreatingWindow := true
    originalText := ""
    Gui, Destroy
    Loop, 10
    {
        IfWinNotExist, ahk_class AutoHotkeyGUI
            break
        Sleep, 10
    }
    winH := (A_ScreenHeight < 800) ? A_ScreenHeight : 800
    buttonAreaH := 50
    editH := winH - 95 - buttonAreaH - 10
    Gui, +AlwaysOnTop +ToolWindow -Caption
    Gui, Color, 0a0a0a

    Gui, Font, s16 cYellow, Consolas
    Gui, Add, Text, vTitleText x10 y10 w1000 Center, ⚖️ Полезная информация ⚖️

    Gui, Font, s10 cWhite, Consolas
    Gui, Add, Edit, vSearchBox x10 y50 w820 h30 gSearchText cBlack BackgroundFFFFFF,
    searchText := LoadSearchText("info")
    blockSearchUpdate := true
    GuiControl,, SearchBox, %searchText%
    blockSearchUpdate := false
    Gui, Add, Button, vSearchButton x835 y50 w85 h30 gDoSearch, Искать
    Gui, Add, Button, vClearButton x925 y50 w85 h30 gClearSearch, Очистить
    Gui, Add, Edit, vMyText x10 y90 w1000 h%editH% ReadOnly +VScroll +WantReturn -Tabstop cWhite Background000000,
    buttonY1 := winH - 55
    Gui, Add, Button, vBtnPK x10 y%buttonY1% w160 h20 gOpenLinkPK, 📘 ПК
    Gui, Add, Button, vBtnKoap x175 y%buttonY1% w160 h20 gOpenLinkKoap, 📋 КоАП
    Gui, Add, Button, vBtnUK x340 y%buttonY1% w160 h20 gOpenLinkUK, ⚖️ УК
    Gui, Add, Button, vBtnUPK x505 y%buttonY1% w160 h20 gOpenLinkUPK, 📗 УПК
    Gui, Add, Button, vBtnPDD x670 y%buttonY1% w160 h20 gOpenLinkPDD, 🚗 ПДД
    Gui, Add, Button, vBtnTK x835 y%buttonY1% w175 h20 gOpenLinkTK, 💼 Трудовой Кодекс
    buttonY2 := winH - 30
    Gui, Add, Button, vBtnFZWeapon x10 y%buttonY2% w160 h20 gOpenLinkFZWeapon, 🔫 Об Оружии
    Gui, Add, Button, vBtnFZProperty x175 y%buttonY2% w160 h20 gOpenLinkFZProperty, 🏛️ О Госсобственности
    Gui, Add, Button, vBtnFZPolice x340 y%buttonY2% w160 h20 gOpenLinkFZPolice, 👮 О Полиции
    Gui, Add, Button, vBtnFZGosluzhba x505 y%buttonY2% w160 h20 gOpenLinkFZGosluzhba, 📋 О Госслужбе
    Gui, Add, Button, vBtnFZRegime x670 y%buttonY2% w160 h20 gOpenLinkFZRegime, ⚠️ О Правовых режимах
    Gui, Add, Button, vBtnKonst x835 y%buttonY2% w175 h20 gOpenLinkKonst, 📜 Конституция

    Sleep, 10

    text := GetInfoText()

    GuiControl,, MyText, %text%
    originalText := text
    Gui, Submit, NoHide

    GuiControl, Show, BtnPK
    GuiControl, Show, BtnKoap
    GuiControl, Show, BtnUK
    GuiControl, Show, BtnUPK
    GuiControl, Show, BtnPDD
    GuiControl, Show, BtnTK
    GuiControl, Show, BtnUkazy
    GuiControl, Show, BtnFZWeapon
    GuiControl, Show, BtnFZProperty
    GuiControl, Show, BtnFZPolice
    GuiControl, Show, BtnFZGosluzhba
    GuiControl, Show, BtnFZRegime
    GuiControl, Show, BtnKonst

    Gui, +OwnDialogs
    pos := LoadWindowPos("info")
    pos := RegExReplace(pos, "w\d+ h\d+", "w1020 h" winH)
    currentWindow := "info"
    if (searchText != "") {
        if (searchText = lastInfoSearchText && lastInfoFoundText != "") {
            GuiControl,, MyText, % lastInfoFoundText
        } else {
            Gosub, SearchText
        }
    }
    Gui, Show, %pos% NA
    GuiID := WinExist()
    SetClickThrough(true)
    OnMessage(0x201, "OnMouseDown")
    OnMessage(0x0232, "WM_EXITSIZEMOVE")
    isOpen := true
    isCreatingWindow := false
    WriteLog("CreateInfoWindow: окно успешно создано и показано")
return

OpenLinkInGTA5OrBrowser(url) {
    Run, %url%
}

OpenLinkKonst:
    url := "https://forum.rmrp.ru/threads/konstitucija-rossijskoj-federacii.58232/"
    OpenLinkInGTA5OrBrowser(url)
return

OpenLinkTK:
    url := "https://forum.rmrp.ru/threads/trudovoj-kodeks-rossijskoj-federacii.25050/"
    OpenLinkInGTA5OrBrowser(url)
return

OpenLinkKoap:
    url := "https://forum.rmrp.ru/threads/kodeks-ob-administrativnyx-pravonarushenijax-rossijskoj-federacii.58229/"
    OpenLinkInGTA5OrBrowser(url)
return

OpenLinkUK:
    url := "https://forum.rmrp.ru/threads/ugolovnyj-kodeks-rossijskoj-federacii.58209/"
    OpenLinkInGTA5OrBrowser(url)
return

OpenLinkPK:
    url := "https://forum.rmrp.ru/threads/processualnyj-kodeks-rossijskoj-federacii.58424/"
    OpenLinkInGTA5OrBrowser(url)
return

OpenLinkUPK:
    url := "https://forum.rmrp.ru/threads/ugolovno-processualnyj-kodeks-rossijskoj-federacii.90218/"
    OpenLinkInGTA5OrBrowser(url)
return

OpenLinkPDD:
    url := "https://forum.rmrp.ru/threads/federalnyj-zakon-pravila-dorozhnogo-dvizhenija-no-90-fz.58190/"
    OpenLinkInGTA5OrBrowser(url)
return

OpenLinkFZPolice:
    url := "https://forum.rmrp.ru/threads/federalnyj-zakon-o-policii-no-74-fz.25074/"
    OpenLinkInGTA5OrBrowser(url)
return

OpenLinkFZGosluzhba:
    url := "https://forum.rmrp.ru/threads/federalnyj-zakon-o-gosudarstvennoj-sluzhbe-no-54-fz.25075/"
    OpenLinkInGTA5OrBrowser(url)
return

OpenLinkFZWeapon:
    url := "https://forum.rmrp.ru/threads/federalnyj-zakon-ob-oruzhii-no-34-fz.25068/"
    OpenLinkInGTA5OrBrowser(url)
return

OpenLinkFZRegime:
    url := "https://forum.rmrp.ru/threads/federalnyj-zakon-ob-osobyx-pravovyx-rezhimax-no-28-fz.25066/"
    OpenLinkInGTA5OrBrowser(url)
return

OpenLinkFZProperty:
    url := "https://forum.rmrp.ru/threads/federalnyj-zakon-o-gosudarstvennoj-sobstvennosti-zakrytyx-i-oxranjaemyx-territorijax-no-86-fz.26625/"
    OpenLinkInGTA5OrBrowser(url)
return

ExtractFineAmount(line) {
    if (RegExMatch(line, "(\d{1,3}(?:\s\d{3})*)\s*-\s*(\d{1,3}(?:\s\d{3})*)\s*₽", match)) {
        amount1 := Floor(RegExReplace(match1, "\s", ""))
        amount2 := Floor(RegExReplace(match2, "\s", ""))
        return {min: amount1, max: amount2, isRange: true}
    } else if (RegExMatch(line, "(\d{1,3}(?:\s\d{3})*)\s*₽", match)) {
        amount := Floor(RegExReplace(match1, "\s", ""))
        return {min: amount, max: amount, isRange: false}
    }
    return {min: 0, max: 0, isRange: false}
}

CountValidLawIniArticles(content) {
    inArticlesSection := false
    count := 0
    Loop, Parse, content, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "[Articles]") {
            inArticlesSection := true
            continue
        }
        if (InStr(line, "[") = 1 && InStr(line, "]") > 1) {
            inArticlesSection := false
            continue
        }
        if (!inArticlesSection || line = "") {
            continue
        }
        if (RegExMatch(line, "^\d+\s*=\s*(.+)$", match)) {
            articleLine := match1
            StringSplit, parts, articleLine, |
            if (parts0 >= 3) {
                article := Trim(parts1)
                description := Trim(parts2)
                if (article != "" && description != "" && count < 100000) {
                    count++
                }
            }
        }
    }
    return count
}

ValidateLawFilesReadable() {
    problems := ""
    koapPath := GetKoapConfigFile()
    if (!FileExist(koapPath)) {
        problems .= "• koap.ini — файл не найден или данные не получены.`n"
    } else {
        FileGetSize, koapSz, %koapPath%
        if (koapSz < 10) {
            problems .= "• koap.ini — слишком мало данных (возможно, сбой загрузки).`n"
        } else {
            koapFile := FileOpen(koapPath, "r", "UTF-8")
            if (!koapFile) {
                problems .= "• koap.ini — не удаётся открыть для чтения (права доступа или занят другим процессом).`n"
            } else {
                koapContent := koapFile.Read()
                koapFile.Close()
                if (!InStr(koapContent, "[Articles]")) {
                    problems .= "• koap.ini — нет секции [Articles], файл повреждён или не тот формат.`n"
                } else if (CountValidLawIniArticles(koapContent) < 1) {
                    problems .= "• koap.ini — в базе нет ни одной читаемой статьи.`n"
                }
            }
        }
    }

    ukPath := GetUKConfigFile()
    if (!FileExist(ukPath)) {
        problems .= "• uk.ini — файл не найден или данные не получены.`n"
    } else {
        FileGetSize, ukSz, %ukPath%
        if (ukSz < 10) {
            problems .= "• uk.ini — слишком мало данных (возможно, сбой загрузки).`n"
        } else {
            ukFile := FileOpen(ukPath, "r", "UTF-8")
            if (!ukFile) {
                problems .= "• uk.ini — не удаётся открыть для чтения.`n"
            } else {
                ukContent := ukFile.Read()
                ukFile.Close()
                if (!InStr(ukContent, "[Articles]")) {
                    problems .= "• uk.ini — нет секции [Articles], файл повреждён или не тот формат.`n"
                } else if (CountValidLawIniArticles(ukContent) < 1) {
                    problems .= "• uk.ini — в базе нет ни одной читаемой статьи.`n"
                }
            }
        }
    }

    infoPath := GetInfoConfigFile()
    if (!FileExist(infoPath)) {
        problems .= "• info.txt — файл не найден или данные не получены.`n"
    } else {
        FileGetSize, infoSz, %infoPath%
        if (infoSz < 1) {
            problems .= "• info.txt — файл пустой.`n"
        } else {
            infoF := FileOpen(infoPath, "r", "UTF-8")
            if (!infoF) {
                problems .= "• info.txt — не удаётся открыть для чтения.`n"
            } else {
                infoText := infoF.Read()
                infoF.Close()
                if (Trim(infoText) = "") {
                    problems .= "• info.txt — нет текста (только пробелы или пустой файл).`n"
                }
            }
        }
    }

    return RTrim(problems, "`r`n`t ")
}

ResetLawCacheForRetry() {
    global lawCacheKoapPath, lawCacheUkPath, lawCacheInfoPath
    if (lawCacheKoapPath != "" && FileExist(lawCacheKoapPath)) {
        FileDelete, %lawCacheKoapPath%
    }
    if (lawCacheUkPath != "" && FileExist(lawCacheUkPath)) {
        FileDelete, %lawCacheUkPath%
    }
    if (lawCacheInfoPath != "" && FileExist(lawCacheInfoPath)) {
        FileDelete, %lawCacheInfoPath%
    }
    lawCacheKoapPath := ""
    lawCacheUkPath := ""
    lawCacheInfoPath := ""
}

ShowLawFilesBlockingGui() {
    global gLawFilesErrorDetail, lawFilesErrorChoice
    fullText := "Не удалось получить или прочитать данные в файлах:" . "`n`n" . gLawFilesErrorDetail . "`n`n"
    fullText .= "Проверьте подключение к интернету. Если используете VPN, попробуйте отключить его или переключить другой сервер (иногда наоборот — включите VPN, если без него сайт недоступен)." . "`n`n"
    fullText .= "Когда будете готовы, нажмите «Попробовать ещё раз»."
    fullText .= "`n`nСвязаться с разработчиком в Discord: severskteam"
    Gui, LawFilesErr:Destroy
    Gui, LawFilesErr:New, +AlwaysOnTop -MinimizeBox, Ошибка чтения данных
    Gui, LawFilesErr:Color, 0a0a0a
    Gui, LawFilesErr:Margin, 14, 14
    Gui, LawFilesErr:Font, s10 cWhite, Consolas
    Gui, LawFilesErr:Add, Edit, w520 r18 ReadOnly Multi +VScroll -WantReturn -Tabstop cWhite Background000000, %fullText%
    Gui, LawFilesErr:Font, s10 cWhite, Consolas
    Gui, LawFilesErr:Add, Button, y+14 w520 h36 Default gLawFilesErrRetry, Попробовать ещё раз
    Gui, LawFilesErr:Show, w556 Center
}

LawFilesErrRetry:
    global lawFilesErrorChoice
    lawFilesErrorChoice := "retry"
    Gui, LawFilesErr:Destroy
return

LawFilesErrExit:
    global lawFilesErrorChoice
    lawFilesErrorChoice := "exit"
    Gui, LawFilesErr:Destroy
return

LawFilesErrGuiClose:
    Gosub, LawFilesErrExit
return

GetKoapConfigFile() {
    global lawCacheKoapPath
    if (lawCacheKoapPath != "" && FileExist(lawCacheKoapPath)) {
        return lawCacheKoapPath
    }
    return A_ScriptDir . "\koap.ini"
}

GetUKConfigFile() {
    global lawCacheUkPath
    if (lawCacheUkPath != "" && FileExist(lawCacheUkPath)) {
        return lawCacheUkPath
    }
    return A_ScriptDir . "\uk.ini"
}

GetInfoConfigFile() {
    global lawCacheInfoPath
    if (lawCacheInfoPath != "" && FileExist(lawCacheInfoPath)) {
        return lawCacheInfoPath
    }
    return A_ScriptDir . "\info.txt"
}

EnsureLawFilesCached() {
    global lawCacheKoapPath, lawCacheUkPath, lawCacheInfoPath
    cacheDir := A_Temp . "\rmrp_gos_cache"
    FileCreateDir, %cacheDir%

    if (lawCacheKoapPath = "") {
        lawCacheKoapPath := cacheDir . "\koap.ini"
        if (!FileExist(lawCacheKoapPath))
            DownloadAndUpdateFile(GetUpdateKoapUrl(), lawCacheKoapPath, 100)
    }
    if (lawCacheUkPath = "") {
        lawCacheUkPath := cacheDir . "\uk.ini"
        if (!FileExist(lawCacheUkPath))
            DownloadAndUpdateFile(GetUpdateUKUrl(), lawCacheUkPath, 100)
    }
    if (lawCacheInfoPath = "") {
        lawCacheInfoPath := cacheDir . "\info.txt"
        if (!FileExist(lawCacheInfoPath))
            DownloadAndUpdateFile(GetUpdateInfoUrl(), lawCacheInfoPath, 10)
    }
}

GetInfoText() {
    configFile := GetInfoConfigFile()

    if (!FileExist(configFile)) {
        return ""
    }

    file := FileOpen(configFile, "r", "UTF-8")
    if (!file) {
        return ""
    }
    text := file.Read()
    file.Close()

    return text
}

GetKoapArticles() {
    global koapArticlesCache, koapArticlesCacheTimestamp, koapPlainBase, koapPlainBaseInit
    articles := []
    configFile := GetKoapConfigFile()

    if (!FileExist(configFile)) {
        return articles
    }

    FileGetSize, fileSize, %configFile%
    if (fileSize < 10) {
        return articles
    }

    FileGetTime, fileModified, %configFile%, M
    if (koapArticlesCache != "" && koapArticlesCacheTimestamp != "" && fileModified = koapArticlesCacheTimestamp) {
        return koapArticlesCache
    }

    file := FileOpen(configFile, "r", "UTF-8")
    if (!file) {
        return articles
    }
    
    fileContent := file.Read()
    file.Close()
    
    inArticlesSection := false
    Loop, Parse, fileContent, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "[Articles]") {
            inArticlesSection := true
            continue
        }
        if (InStr(line, "[") = 1 && InStr(line, "]") > 1) {
            inArticlesSection := false
            continue
        }
        if (!inArticlesSection || line = "") {
            continue
        }
        
        if (RegExMatch(line, "^\d+\s*=\s*(.+)$", match)) {
            articleLine := match1
            StringSplit, parts, articleLine, |
            if (parts0 >= 3) {
                article := Trim(parts1)
                description := Trim(parts2)
                point := Trim(parts3)
                penalty := Trim(parts4)
                
                if (article != "" && description != "" && articles.Length() < 10000) {
                    articles.Push({article: article, description: description, point: point, penalty: penalty})
                }
            }
        }
    }

    if (articles.Length() > 10000) {
        articles := []
        return articles
    }

    if (articles.Length() > 1) {
        maxSortItems := articles.Length()
        if (maxSortItems > 10000) {
            maxSortItems := 10000
        }
        Loop, % maxSortItems - 1
        {
            currentIdx := A_Index
            if (currentIdx > articles.Length()) {
                break
            }
            maxInnerLoop := articles.Length() - currentIdx
            if (maxInnerLoop > 10000) {
                maxInnerLoop := 10000
            }
            Loop, % maxInnerLoop
            {
                nextIdx := currentIdx + A_Index
                if (nextIdx > articles.Length()) {
                    break
                }
                if (CompareArticles(articles[currentIdx].article, articles[nextIdx].article) > 0) {
                    temp := articles[currentIdx]
                    articles[currentIdx] := articles[nextIdx]
                    articles[nextIdx] := temp
                }
            }
        }
    }

    koapArticlesCache := articles
    koapArticlesCacheTimestamp := fileModified

    koapPlainBase := {}
    iterationCount := 0
    for index, item in articles
    {
        iterationCount := iterationCount + 1
        if (iterationCount > 10000) {
            break
        }
        if (IsObject(item)) {
            articleNum := Trim(item.article)
            articleNum := RegExReplace(articleNum, "\s", "")
            if (RegExMatch(articleNum, "^\d+$")) {
                koapPlainBase[articleNum] := true
            }
        }
    }
    koapPlainBaseInit := true

    return articles
}

GetKoapArticlesAsText() {
    articles := GetKoapArticles()
    text := ""
    for index, item in articles
    {
        text .= item.article . "    | " . item.description . " | " . item.point . "        | " . item.penalty . "`n"
    }
    return text
}

GetUKArticles() {
    global ukArticlesCache, ukArticlesCacheTimestamp, ukPlainBase, ukPlainBaseInit
    articles := []
    configFile := GetUKConfigFile()

    if (!FileExist(configFile)) {
        return articles
    }

    FileGetSize, fileSize, %configFile%
    if (fileSize < 10) {
        return articles
    }

    FileGetTime, fileModified, %configFile%, M
    if (ukArticlesCache != "" && ukArticlesCacheTimestamp != "" && fileModified = ukArticlesCacheTimestamp) {
        return ukArticlesCache
    }

    file := FileOpen(configFile, "r", "UTF-8")
    if (!file) {
        return articles
    }
    
    fileContent := file.Read()
    file.Close()
    
    inArticlesSection := false
    Loop, Parse, fileContent, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "[Articles]") {
            inArticlesSection := true
            continue
        }
        if (InStr(line, "[") = 1 && InStr(line, "]") > 1) {
            inArticlesSection := false
            continue
        }
        if (!inArticlesSection || line = "") {
            continue
        }
        
        if (RegExMatch(line, "^\d+\s*=\s*(.+)$", match)) {
            articleLine := match1
            StringSplit, parts, articleLine, |
            if (parts0 >= 3) {
                article := Trim(parts1)
                description := Trim(parts2)
                point := Trim(parts3)
                penalty := Trim(parts4)
                
                if (article != "" && description != "" && articles.Length() < 10000) {
                    articles.Push({article: article, description: description, point: point, penalty: penalty})
                }
            }
        }
    }

    if (articles.Length() > 1) {
        Loop, % articles.Length() - 1
        {
            currentIdx := A_Index
            Loop, % articles.Length() - currentIdx
            {
                nextIdx := currentIdx + A_Index
                if (CompareArticles(articles[currentIdx].article, articles[nextIdx].article) > 0) {
                    temp := articles[currentIdx]
                    articles[currentIdx] := articles[nextIdx]
                    articles[nextIdx] := temp
                }
            }
        }
    }

    if (articles.Length() > 10000) {
        articles := []
        return articles
    }

    ukArticlesCache := articles
    ukArticlesCacheTimestamp := fileModified

    ukPlainBase := {}
    iterationCount := 0
    for index, item in articles
    {
        iterationCount := iterationCount + 1
        if (iterationCount > 10000) {
            break
        }
        if (IsObject(item) && item.article != "") {
            articleNum := Trim(item.article)
            articleNum := RegExReplace(articleNum, "\s", "")
            if (RegExMatch(articleNum, "^\d+$")) {
                ukPlainBase[articleNum] := true
            }
        }
    }
    ukPlainBaseInit := true

    return articles
}

GetUKArticlesAsText() {
    articles := GetUKArticles()
    text := ""
    for index, item in articles
    {
        text .= item.article . "    | " . item.description . " | " . item.point . "        | " . item.penalty . "`n"
    }
    return text
}

RestoreLawSearchFromCache(windowType) {
    global MyListView, SummaryText1, SummaryText2, CopyReasonBtn, CopyFineBtn, CopyArrestBtn
    global UpdateLabelLaw, UpdateBtnLaw, editH
    global lastKoapSummary1, lastKoapSummary2, lastUKSummary1, lastUKSummary2
    global lastKoapArticles, lastUKArticles

    if (windowType = "koap") {
        articles := lastKoapArticles
        summaryLine1 := lastKoapSummary1
        summaryLine2 := lastKoapSummary2
    } else if (windowType = "uk") {
        articles := lastUKArticles
        summaryLine1 := lastUKSummary1
        summaryLine2 := lastUKSummary2
    } else {
        return
    }

    if (!IsObject(articles) || articles.Length() = 0 || (summaryLine1 = "" && summaryLine2 = "")) {
        return
    }

    LV_Delete()
    for index, item in articles
    {
        if (windowType = "koap") {
            LV_Add("", item.article, item.description, item.point, item.penalty)
        } else if (windowType = "uk") {
            LV_Add("", item.article, item.description, "", item.penalty)
        }
    }

    if (windowType = "koap") {
        LV_ModifyCol(1, 60)
        LV_ModifyCol(2, 600)
        LV_ModifyCol(3, "Center 75")
        LV_ModifyCol(4, "Center 240")
    } else if (windowType = "uk") {
        LV_ModifyCol(1, 60)
        LV_ModifyCol(2, 675)
        LV_ModifyCol(3, 0)
        LV_ModifyCol(4, "Center 240")
    }

    summary := summaryLine1
    if (summaryLine2 != "") {
        summary .= "`n" . summaryLine2
    }

    hasReason := InStr(summary, "📋 Причина штрафа/ареста:")
    hasFines := InStr(summary, "💸 Сумма штрафа:")
    hasArrests := InStr(summary, "⏰ Срок ареста:")

    if (hasReason) {
        GuiControl, Enable, CopyReasonBtn
        GuiControl, +cWhite, CopyReasonBtn
    } else {
        GuiControl, Disable, CopyReasonBtn
        GuiControl, +cGray, CopyReasonBtn
    }

    if (hasFines) {
        GuiControl, Enable, CopyFineBtn
        GuiControl, +cWhite, CopyFineBtn
    } else {
        GuiControl, Disable, CopyFineBtn
        GuiControl, +cGray, CopyFineBtn
    }

    if (hasArrests) {
        GuiControl, Enable, CopyArrestBtn
        GuiControl, +cWhite, CopyArrestBtn
    } else {
        GuiControl, Disable, CopyArrestBtn
        GuiControl, +cGray, CopyArrestBtn
    }

    StringSplit, line1Parts, summaryLine1, `n
    StringSplit, line2Parts, summaryLine2, `n
    summaryHeight := line1Parts0 * 17
    if (summaryLine2 != "") {
        summaryHeight += line2Parts0 * 17
    }

    updateBannerH := 0
    GuiControl, Hide, UpdateLabelLaw
    GuiControl, Hide, UpdateBtnLaw

    listViewH := editH - summaryHeight - 15 - updateBannerH
    if (listViewH < 100)
        listViewH := 100

    GuiControl, Move, MyListView, x10 y120 w1000 h%listViewH%
    if (windowType = "koap") {
        LV_ModifyCol(1, 60)
        LV_ModifyCol(2, 600)
        LV_ModifyCol(3, "Center 75")
        LV_ModifyCol(4, "Center 240")
    } else if (windowType = "uk") {
        LV_ModifyCol(1, 60)
        LV_ModifyCol(2, 675)
        LV_ModifyCol(3, 0)
        LV_ModifyCol(4, "Center 240")
    }

    GuiControlGet, listViewPos, Pos, MyListView
    summaryY1 := listViewPosY + listViewPosH + 10
    summaryHeight1 := line1Parts0 * 17
    summaryY2 := summaryY1 + summaryHeight1 + 4
    GuiControl, Move, SummaryText1, x10 y%summaryY1% w1000 h%summaryHeight1%
    if (summaryLine2 != "") {
        summaryHeight2 := line2Parts0 * 17
        GuiControl, Move, SummaryText2, x10 y%summaryY2% w1000 h%summaryHeight2%
    }

    if (updateBannerH > 0 && updateScriptVersion != "" && updateServerVersion != "") {
        if (summaryLine2 != "") {
            updateY := summaryY2 + summaryHeight2 + 6
        } else {
            updateY := summaryY1 + summaryHeight1 + 6
        }
        updateText := "Доступно обновление! Новая версия: " updateScriptVersion " -> " updateServerVersion
        GuiControl, Move, UpdateLabelLaw, x10 y%updateY% w350 h20
        GuiControl,, UpdateLabelLaw, %updateText%
        GuiControl, Show, UpdateLabelLaw
        GuiControlGet, updPos, Pos, UpdateLabelLaw
        buttonX := updPosX + updPosW + 10
        buttonY := updateY - 3
        GuiControl, Move, UpdateBtnLaw, x%buttonX% y%buttonY% w160 h20
        GuiControl, Show, UpdateBtnLaw
    } else {
        GuiControl, Hide, UpdateLabelLaw
        GuiControl, Hide, UpdateBtnLaw
    }

    if (summaryLine1 != "") {
        GuiControl,, SummaryText1, %summaryLine1%
        GuiControl, Show, SummaryText1
    } else {
        GuiControl,, SummaryText1,
        GuiControl, Hide, SummaryText1
    }

    if (summaryLine2 != "") {
        GuiControl,, SummaryText2, %summaryLine2%
        GuiControl, Show, SummaryText2
    } else {
        GuiControl,, SummaryText2,
        GuiControl, Hide, SummaryText2
    }
}

FillUKListView(text) {
    LV_Delete()

    articles := []
    if (text != "") {
        StringSplit, lines, text, `n
        Loop, % lines0
        {
            currentLine := lines%A_Index%
            currentLine := Trim(currentLine)
            if (currentLine = "" || InStr(currentLine, "Статья |") || InStr(currentLine, "-------|"))
                continue

            StringSplit, fields, currentLine, |
            if (fields0 >= 4) {
                article := Trim(fields1)
                description := Trim(fields2)
                point := Trim(fields3)
                penalty := Trim(fields4)
                if (article != "" && description != "") {
                    articles.Push({article: article, description: description, point: point, penalty: penalty})
                }
            } else if (fields0 >= 3) {
                article := Trim(fields1)
                description := Trim(fields2)
                point := "-"
                penalty := Trim(fields3)
                if (article != "" && description != "") {
                    articles.Push({article: article, description: description, point: point, penalty: penalty})
                }
            }
        }
    } else {
        articles := GetUKArticles()
    }

    for index, item in articles
    {
        LV_Add("", item.article, item.description, "", item.penalty)
    }

    LV_ModifyCol(1, 60)
    LV_ModifyCol(2, 675)
    LV_ModifyCol(3, 0)
    LV_ModifyCol(4, "Center 240")
}

CompareArticles(article1, article2) {
    article1 := Trim(article1)
    article2 := Trim(article2)

    StringSplit, art1Parts, article1, -
    StringSplit, art2Parts, article2, -
    article1 := Trim(art1Parts1)
    article2 := Trim(art2Parts1)

    StringSplit, parts1, article1, .
    StringSplit, parts2, article2, .

    maxParts := (parts10 > parts20) ? parts10 : parts20

    Loop, % maxParts
    {
        if (A_Index <= parts10) {
            part1Raw := Trim(parts1%A_Index%)
            part1 := RegExReplace(part1Raw, "[^\d]", "")
        } else {
            part1 := ""
        }

        if (A_Index <= parts20) {
            part2Raw := Trim(parts2%A_Index%)
            part2 := RegExReplace(part2Raw, "[^\d]", "")
        } else {
            part2 := ""
        }

        if (part1 = "" && part2 = "")
            continue
        if (part1 = "")
            return -1
        if (part2 = "")
            return 1

        if (RegExMatch(part1, "^\d+$") && RegExMatch(part2, "^\d+$")) {
            num1 := part1 + 0
            num2 := part2 + 0

            if (num1 < num2)
                return -1
            else if (num1 > num2)
                return 1
        } else {
            if (part1 < part2)
                return -1
            else if (part1 > part2)
                return 1
        }
    }

    if (art1Parts0 > art2Parts0)
        return 1
    else if (art1Parts0 < art2Parts0)
        return -1

    return 0
}

FillKoapListView(text) {
    LV_Delete()

    articles := []
    if (text != "") {
        StringSplit, lines, text, `n
        Loop, % lines0
        {
            currentLine := lines%A_Index%
            currentLine := Trim(currentLine)
            if (currentLine = "" || InStr(currentLine, "Статья |") || InStr(currentLine, "-------|"))
                continue

            StringSplit, fields, currentLine, |
            if (fields0 >= 4) {
                article := Trim(fields1)
                description := Trim(fields2)
                point := Trim(fields3)
                penalty := Trim(fields4)
                if (article != "" && description != "") {
                    articles.Push({article: article, description: description, point: point, penalty: penalty})
                }
            }
        }
    } else {
        articles := GetKoapArticles()
    }

    for index, item in articles
    {
        LV_Add("", item.article, item.description, item.point, item.penalty)
    }

    LV_ModifyCol(1, 60)
    LV_ModifyCol(2, 600)
    LV_ModifyCol(3, "Center 75")
    LV_ModifyCol(4, "Center 240")
}

CalculateSummaryHeight(summaryText) {
    if (summaryText = "")
        return 0

    StringSplit, lines, summaryText, `n
    lineCount := 0
    Loop, % lines0
    {
        if (Trim(lines%A_Index%) != "")
            lineCount++
    }

    minHeight := 80
    calculatedHeight := lineCount * 16 + 20

    maxHeight := 300
    if (calculatedHeight > maxHeight)
        calculatedHeight := maxHeight

    if (calculatedHeight < minHeight)
        calculatedHeight := minHeight

    return calculatedHeight
}


ListViewClick:
    if (A_GuiEvent = "DoubleClick" && (currentWindow = "koap" || currentWindow = "uk")) {
        SetTimer, OpenDetailsTimer, Off
        selectedArticles := ""
        RowNumber := 0
        Loop
        {
            RowNumber := LV_GetNext(RowNumber, "Selected")
            if (RowNumber = 0)
                break
            LV_GetText(article, RowNumber, 1)
            if (selectedArticles = "") {
                selectedArticles := article
            } else {
                selectedArticles := selectedArticles . " " . article
            }
        }

        if (selectedArticles = "") {
            RowNumber := LV_GetNext(0, "Focused")
            if (RowNumber > 0) {
                LV_GetText(article, RowNumber, 1)
                selectedArticles := article
            }
        }

        if (selectedArticles != "") {
            GuiControlGet, currentSearch,, SearchBox
            currentSearch := Trim(currentSearch)

            StringSplit, newTerms, selectedArticles, %A_Space%

            newSearch := currentSearch
            Loop, % newTerms0
            {
                term := Trim(newTerms%A_Index%)
                if (term != "") {
                    found := false
                    if (currentSearch != "") {
                        StringSplit, currentTerms, currentSearch, %A_Space%
                        Loop, % currentTerms0
                        {
                            currentTerm := Trim(currentTerms%A_Index%)
                            if (currentTerm = term) {
                                found := true
                                break
                            }
                        }
                    }

                    if (!found) {
                        if (newSearch = "") {
                            newSearch := term
                        } else {
                            newSearch := newSearch . " " . term
                        }
                    }
                }
            }

            if (newSearch != currentSearch) {
                global blockSearchUpdate
                blockSearchUpdate := true
                GuiControl,, SearchBox, %newSearch%
            }
        }
    } else if ((currentWindow = "koap" || currentWindow = "uk") && A_GuiEvent = "Normal") {
        row := A_EventInfo
        if (row > 0) {
            global lastDetailsRowForTimer
            lastDetailsRowForTimer := row
            SetTimer, OpenDetailsTimer, -250
        }
    }
return

OpenDetailsTimer:
    SetTimer, OpenDetailsTimer, Off
    if (lastDetailsRowForTimer > 0)
        ShowArticleDetailsForRow(lastDetailsRowForTimer)
return

ShowArticleDetailsForRow(row) {
    global currentWindow
    LV_GetText(article, row, 1)
    LV_GetText(description, row, 2)
    LV_GetText(point, row, 3)
    LV_GetText(penalty, row, 4)
    if (article = "")
        return
    title := (currentWindow = "koap") ? "Статья " . article . " КоАП РФ:" : "Статья " . article . " УК РФ:"
    configPath := (currentWindow = "koap") ? GetKoapConfigFile() : GetUKConfigFile()
    extendedDesc := GetArticleInfoFromIni(configPath, article)
    descToShow := (extendedDesc != "") ? extendedDesc : description
    body := descToShow . "`n`nМера наказания: " . penalty
    if (currentWindow = "koap") {
        pddKeys := []
        GetPddKeysFromDesc(extendedDesc, pddKeys)
        pddBlock := GetPddBlockForKeys(GetKoapConfigFile(), pddKeys)
        if (pddBlock != "")
            body := body . "`n`n──────────────────────────────────────────────────────────────`n`n" . pddBlock
    }
    ShowArticleInfoGui(title, body)
}

ReadIniValueUtf8(configPath, section, key) {
    if (!FileExist(configPath))
        return ""
    file := FileOpen(configPath, "r", "UTF-8")
    if (!file)
        return ""
    content := file.Read()
    file.Close()
    sectionMark := "[" . section . "]"
    inSection := false
    lines := []
    Loop, Parse, content, `n, `r
        lines.Push(A_LoopField)
    Loop % lines.Length()
    {
        line := lines[A_Index]
        if (Trim(line) = sectionMark) {
            inSection := true
            continue
        }
        trimLine := Trim(line)
        if (SubStr(trimLine, 1, 1) = "[" && InStr(trimLine, "]") > 1) {
            inSection := false
            continue
        }
        if (inSection && SubStr(line, 1, StrLen(key) + 1) = key "=") {
            value := Trim(SubStr(line, StrLen(key) + 2))
            idx := A_Index + 1
            while (idx <= lines.Length()) {
                next := lines[idx]
                trimNext := Trim(next)
                if (trimNext != "" && RegExMatch(trimNext, "^[^=\[\]]+\s*="))
                    break
                if (RegExMatch(trimNext, "^\[.*\]$"))
                    break
                value .= "`n" . next
                idx++
            }
            return value
        }
    }
    return ""
}

GetArticleInfoFromIni(configPath, article) {
    if (!FileExist(configPath))
        return ""
    value := ReadIniValueUtf8(configPath, "ArticleInfo", article)
    if (value = "")
        return ""
    return Trim(value)
}

GetPddArticleText(configPath, key) {
    if (!FileExist(configPath))
        return ""
    lookupKey := key
    if (InStr(key, " ("))
        lookupKey := SubStr(key, 1, InStr(key, " (") - 1)
    value := ReadIniValueUtf8(configPath, "ПДД", lookupKey)
    if (value = "")
        return ""
    return Trim(value)
}

GetPddKeysFromPoint(pointKey, keys) {
    str := pointKey
    pos := 1
    Loop
    {
        found := RegExMatch(str, "\d+\.\d+(?:\s*\([а-я]\))?", m, pos)
        if (!found)
            break
        keys.Push(m)
        pos += StrLen(m)
    }
    RegExMatch(pointKey, "(\d+)\s*глава", ch)
    if (ch != "")
        keys.Push(ch . " глава")
}

GetPddKeysFromDesc(desc, keys) {
    if (desc = "")
        return
    seen := {}
    for i, k in keys
        seen[k] := true
    pos := 1
    Loop
    {
        found := RegExMatch(desc, "(?:см\.\s*)?статья\s+([\d\.]+(?:\s*\([а-я]\))?)\s+ПДД", m, pos)
        if (!found)
            break
        if (!seen[m1]) {
            seen[m1] := true
            keys.Push(m1)
        }
        pos += StrLen(m)
    }
    pos := 1
    Loop
    {
        found := RegExMatch(desc, "(?:см\.\s*)?статьи\s+([\d\.\s,]+?)\s+ПДД", m, pos)
        if (!found)
            break
        list := m1
        Loop, Parse, list, `, %A_Space%
        {
            k := Trim(A_LoopField)
            if (k != "" && !seen[k]) {
                seen[k] := true
                keys.Push(k)
            }
        }
        pos += StrLen(m)
    }
    pos := 1
    Loop
    {
        found := RegExMatch(desc, "(?:см\.\s*)?глав[ау]\s+(\d+|IV|IX|I{1,3}|V|VI|VII|VIII|X|XI|XII|XIII|XIV|XV)\s+ПДД", m, pos)
        if (!found)
            break
        r := PddRomanToChapter(m1)
        key := r . " глава"
        if (!seen[key]) {
            seen[key] := true
            keys.Push(key)
        }
        pos += StrLen(m)
    }
    pos := 1
    Loop
    {
        found := RegExMatch(desc, "ст\.\s*([\d\.]+)\s+ПДД", m, pos)
        if (!found)
            break
        if (!seen[m1]) {
            seen[m1] := true
            keys.Push(m1)
        }
        pos += StrLen(m)
    }
}

PddRomanToChapter(r) {
    if (r + 0 != "")
        return r
    romanMap := Object("I",1,"II",2,"III",3,"IV",4,"V",5,"VI",6,"VII",7,"VIII",8,"IX",9,"X",10,"XI",11,"XII",12,"XIII",13,"XIV",14,"XV",15)
    return romanMap[r] ? romanMap[r] : r
}

GetPddBlockForKeys(configPath, keys) {
    if (!FileExist(configPath) || !keys.Length())
        return ""
    out := ""
    seen := {}
    for i, key in keys
    {
        baseKey := key
        if (InStr(key, " ("))
            baseKey := SubStr(key, 1, InStr(key, " (") - 1)
        if (seen[baseKey])
            continue
        seen[baseKey] := true
        txt := GetPddArticleText(configPath, key)
        if (txt != "")
        {
            if (InStr(key, " глава")) {
                chNum := SubStr(baseKey, 1, InStr(baseKey, " ") - 1)
                romanNames := Object(1,"I",2,"II",3,"III",4,"IV",5,"V",6,"VI",7,"VII",8,"VIII",9,"IX",10,"X",11,"XI",12,"XII",13,"XIII",14,"XIV",15,"XV")
                romanDisp := romanNames[chNum] ? romanNames[chNum] : chNum
                label := "Глава " . romanDisp . " ПДД РФ. "
            } else
                label := baseKey . " ПДД РФ. "
            out := out . (out != "" ? "`n`n" : "") . label . txt
        }
    }
    return out
}

ShowArticleInfoGui(title, body) {
    global ArticleInfoBody, ArticleInfoCloseBtn
    Gui, ArticleInfo:Destroy
    Gui, ArticleInfo:+AlwaysOnTop -MaximizeBox +Owner
    Gui, ArticleInfo:Color, 0x0a0a0a
    Gui, ArticleInfo:Font, s10 cWhite Bold, Consolas
    Gui, ArticleInfo:Add, Text, x15 y12 w470, %title%
    Gui, ArticleInfo:Font, s9 cWhite Norm, Consolas
    contentH := 400
    maxContentH := A_ScreenHeight - 180
    if (contentH > maxContentH)
        contentH := maxContentH
    Gui, ArticleInfo:Add, Edit, vArticleInfoBody x15 y38 w470 h%contentH% +ReadOnly +Wrap +VScroll -E0x200 cWhite Background0x0a0a0a, %body%
    btnY := 38 + contentH + 10
    Gui, ArticleInfo:Add, Button, vArticleInfoCloseBtn x15 y%btnY% w470 h28 gCloseArticleInfoGui, Закрыть
    winH := btnY + 28 + 15
    Gui, ArticleInfo:Show, w500 h%winH%, Информация о статье
    GuiControl, ArticleInfo:Focus, ArticleInfoCloseBtn
    GuiControlGet, editHwnd, ArticleInfo:Hwnd, ArticleInfoBody
    if (editHwnd)
        PostMessage, 0x00B1, 0, 0,, ahk_id %editHwnd%
return
}
CloseArticleInfoGui:
    Gui, ArticleInfo:Destroy
return

WM_NOTIFY_ListView(wParam, lParam, msg, hwnd)
{
    global MyListViewHwnd, currentWindow

    if (hwnd != MyListViewHwnd)
        return

    hdrCode := NumGet(lParam + 0, 8, "UInt")

    if (hdrCode = 0xFFFFFFFE || hdrCode = -2) {
        col := NumGet(lParam + 0, 16, "Int") + 1

        if (col = 1 && (currentWindow = "koap" || currentWindow = "uk")) {
            SetTimer, CustomSortListView, -50
        }
    }

    if (hdrCode = 0x00000001)
        return 0x20

    if (hdrCode = 0x00010001)
        return 4

    if (hdrCode = 0x00030001)
    {
        hdc := NumGet(lParam + 0, 16, "UPtr")
        rc  := lParam + 20

        left   := NumGet(rc+0, 0, "Int")
        top    := NumGet(rc+0, 4, "Int")
        right  := NumGet(rc+0, 8, "Int")
        bottom := NumGet(rc+0,12, "Int")

        row := NumGet(lParam + 12, "Int")
        col := NumGet(lParam + 16, "Int")

        isSelected := false
        isFocused := false
        if (row >= 0) {
            LVM_GETITEMSTATE := 0x102C
            state := DllCall("SendMessage", "UInt", MyListViewHwnd, "UInt", LVM_GETITEMSTATE, "Int", row, "UInt", 0x0002, "UInt")
            isSelected := (state & 0x0002) != 0
            state := DllCall("SendMessage", "UInt", MyListViewHwnd, "UInt", LVM_GETITEMSTATE, "Int", row, "UInt", 0x0001, "UInt")
            isFocused := (state & 0x0001) != 0
        }

        if (isSelected) {
            bgColor := 0x1E3A5F
            textColor := 0xFFFFFF
        } else {
            bgColor := 0x0a0a0a
            textColor := 0xFFFFFF
        }

        hBrush := DllCall("CreateSolidBrush", "UInt", bgColor, "UPtr")
        DllCall("FillRect", "UPtr", hdc, "UPtr", rc, "UPtr", hBrush)
        DllCall("DeleteObject", "UPtr", hBrush)

        DllCall("SetTextColor", "UPtr", hdc, "UInt", textColor)
        DllCall("SetBkMode",   "UPtr", hdc, "Int", 1)

        LV_GetText(t, row+1, col+1)

        DllCall("DrawText", "UPtr", hdc, "Str", t, "Int", -1, "UPtr", rc, "Int", 0x0000)

        return 4
    }
}

CustomSortListView:
    global currentWindow
    if (currentWindow != "koap" && currentWindow != "uk")
        return

    articles := []
    rowCount := LV_GetCount()
    Loop, %rowCount%
    {
        LV_GetText(article, A_Index, 1)
        LV_GetText(description, A_Index, 2)
        if (currentWindow = "koap") {
            LV_GetText(point, A_Index, 3)
            LV_GetText(penalty, A_Index, 4)
            articles.Push({article: article, description: description, point: point, penalty: penalty})
        } else if (currentWindow = "uk") {
            LV_GetText(penalty, A_Index, 4)
            articles.Push({article: article, description: description, point: "-", penalty: penalty})
        }
    }

    Loop, % articles.Length()
    {
        if (A_Index = articles.Length())
            break

        currentIdx := A_Index
        Loop, % articles.Length() - currentIdx
        {
            nextIdx := currentIdx + A_Index
            if (CompareArticles(articles[currentIdx].article, articles[nextIdx].article) > 0) {
                temp := articles[currentIdx]
                articles[currentIdx] := articles[nextIdx]
                articles[nextIdx] := temp
            }
        }
    }

    LV_Delete()
    for index, item in articles
    {
        if (currentWindow = "koap") {
            LV_Add("", item.article, item.description, item.point, item.penalty)
        } else if (currentWindow = "uk") {
            LV_Add("", item.article, item.description, "", item.penalty)
        }
    }

    if (currentWindow = "koap") {
        LV_ModifyCol(1, 60)
        LV_ModifyCol(2, 600)
        LV_ModifyCol(3, "Center 75")
        LV_ModifyCol(4, "Center 240")
    } else if (currentWindow = "uk") {
        LV_ModifyCol(1, 60)
        LV_ModifyCol(2, 675)
        LV_ModifyCol(3, 0)
        LV_ModifyCol(4, "Center 240")
    }
return

CountArrests(line) {
    arrests := 0

    if (RegExMatch(line, "(\d+)\s*суток(?!\s*\(\(.*\)\))", match)) {
        days := match1
        arrests += days
    }

    if (RegExMatch(line, "(\d+)\s*(лет|года|год)(?!\s*\)\))", match)) {
        arrests += match1 * 365
    }

    return arrests
}

WrapText(text, maxWidth) {
    maxChars := Floor(maxWidth / 6.5)
    wrapped := ""
    currentLine := ""
    StringSplit, words, text, %A_Space%

    Loop, % words0
    {
        word := words%A_Index%
        testLine := currentLine
        if (testLine != "")
            testLine .= " " word
        else
            testLine := word

        if (StrLen(testLine) <= maxChars) {
            currentLine := testLine
        } else {
            if (currentLine != "") {
                if (wrapped != "")
                    wrapped .= "`n" currentLine
                else
                    wrapped := currentLine
                currentLine := word
            } else {
                if (wrapped != "")
                    wrapped .= "`n" word
                else
                    wrapped := word
            }
        }
    }

    if (currentLine != "") {
        if (wrapped != "")
            wrapped .= "`n" currentLine
        else
            wrapped := currentLine
    }

    return wrapped
}

CreateSummary(foundLines, searchText, windowType) {
    totalFineMin := 0
    totalFineMax := 0
    totalArrests := 0
    fineCount := 0
    arrestCount := 0

    hasArticle47 := false

    articleNumbers := ""
    articleCount := 0
    StringSplit, lines, foundLines, `n

    Loop, % lines0
    {
        currentLine := lines%A_Index%
        if (currentLine = "" || InStr(currentLine, "Статья |") || InStr(currentLine, "-------|"))
            continue

        if (RegExMatch(currentLine, "^([^|]+)\|", match)) {
            articleNum := Trim(match1)
            if (articleNum != "" && articleNum != "Статья") {
                cleanedArticleNum := RegExReplace(articleNum, "[^\d\.]", "")
                articleCount++
                if (articleNumbers != "") {
                    articleNumbers .= ", " articleNum
                } else {
                    articleNumbers := articleNum
                }
                if (!hasArticle47 && RegExMatch(cleanedArticleNum, "^4\.7(\.|$)?")) {
                    hasArticle47 := true
                }
            }
        }

        fineAmount := ExtractFineAmount(currentLine)
        if (fineAmount.min > 0) {
            if (hasArticle47 && RegExMatch(currentLine, "^9\.", match)) {
                if (fineAmount.isRange) {
                    totalFineMin += fineAmount.min * 2
                    totalFineMax += fineAmount.max * 2
                } else {
                    totalFineMin += fineAmount.min * 2
                    totalFineMax += fineAmount.min * 2
                }
            } else {
                if (fineAmount.isRange) {
                    totalFineMin += fineAmount.min
                    totalFineMax += fineAmount.max
                } else {
                    totalFineMin += fineAmount.min
                    totalFineMax += fineAmount.min
                }
            }
            fineCount++
        }

        arrestDays := CountArrests(currentLine)
        if (arrestDays > 0) {
            totalArrests += arrestDays
            arrestCount++
        }
    }

    totalFineMin := Floor(totalFineMin)
    totalFineMax := Floor(totalFineMax)
    totalArrests := Floor(totalArrests)

    codexName := ""
    if (windowType = "koap") {
        codexName := "КоАП РФ"
    } else if (windowType = "uk") {
        codexName := "УК РФ"
    }

    line1 := ""

    if (articleNumbers != "" && codexName != "") {
        line1 .= "📋 Причина штрафа/ареста: " articleNumbers " " codexName
    } else {
        line1 .= "📋 Причина штрафа/ареста: " searchText
    }

    line2 := ""
    if (fineCount > 0) {
        line2 .= "💰 Штрафы: " fineCount " " DeclineArticle(fineCount)
        if (hasArticle47) {
            line2 .= " (статья 4.7 - 9 глава ×2)"
        }
    }

    if (arrestCount > 0) {
        if (line2 != "") {
            line2 .= " | "
        }
        line2 .= "⛓️ Аресты: " arrestCount " " DeclineArticle(arrestCount)
    }

    if (fineCount = 0 && arrestCount = 0) {
        line2 .= "❌ Штрафы и аресты не найдены..."
    }

    if (fineCount > 0 || arrestCount > 0) {
        if (fineCount > 0) {
            if (line2 != "") {
                line2 .= " | "
            }
            if (totalFineMin = totalFineMax) {
                line2 .= "💸 Сумма штрафа: " FormatNumberFixed(totalFineMin) " ₽"
            } else {
                line2 .= "💸 Сумма штрафа: " FormatNumberFixed(totalFineMin) " - " FormatNumberFixed(totalFineMax) " ₽"
            }
        }

        if (arrestCount > 0) {
            if (line2 != "") {
                line2 .= " | "
            }
            line2 .= "⏰ Срок ареста: "
            if (totalArrests >= 365) {
                years := Floor(totalArrests / 365)
                if (years = 1) {
                    line2 .= "1 год"
                } else if (years >= 2 && years <= 4) {
                    line2 .= years " года"
                } else {
                    line2 .= years " лет"
                }
            } else {
                line2 .= totalArrests " дней"
            }
        }

        line2 := WrapText(line2, 1000)
    }

    summary := line1
    if (line2 != "") {
        summary .= "`n" line2
    }

    return summary
}

FormatNumber(num) {
    if (num < 1000)
        return num

    result := ""
    while (num > 0) {
        remainder := Mod(num, 1000)
        num := Floor(num / 1000)

        if (num > 0) {
            if (remainder < 100)
                remainder := "0" remainder
            if (remainder < 10)
                remainder := "00" remainder
            result := " " remainder result
        } else {
            result := remainder result
        }
    }

    return result
}

FormatNumberFixed(num) {
    num := Floor(num)

    if (num < 1000)
        return num

    numStr := num
    len := StrLen(numStr)
    result := ""

    firstGroupSize := Mod(len, 3)
    if (firstGroupSize = 0)
        firstGroupSize := 3

    result := SubStr(numStr, 1, firstGroupSize)

    pos := firstGroupSize + 1
    while (pos <= len) {
        result := result " " SubStr(numStr, pos, 3)
        pos += 3
    }

    return result
}

DeclineArticle(count) {
    if (count = 1) {
        return "статья"
    } else if (count >= 2 && count <= 4) {
        return "статьи"
    } else {
        return "статей"
    }
}

ShowScreenshotMenu() {
    global screenshotButtonCount, screenshotButtonNames
    Gui, ScreenshotMenu:Destroy
    Gui, ScreenshotMenu:+AlwaysOnTop +ToolWindow -Caption
    Gui, ScreenshotMenu:Color, 0a0a0a

    categories := GetScreenshotCategories()
    startY := 45
    buttonHeight := 45
    buttonSpacing := 55
    buttonWidth := 200
    columnSpacing := 10
    columnsPerRow := 3
    buttonIndex := 0
    hasCategories := false

    totalButtons := 0
    Loop, Parse, categories, `n
    {
        if (A_LoopField != "") {
            totalButtons++
            category%totalButtons% := A_LoopField
            hasCategories := true
        }
    }

    if (!hasCategories) {
        totalButtons := 1
    }

    if (totalButtons <= 9) {
        buttonSpacing := 70
    }

    col1X := 10
    col2X := col1X + buttonWidth + columnSpacing
    col3X := col2X + buttonWidth + columnSpacing

    screenshotButtonCount := totalButtons
    screenshotButtonNames := ""

    if (totalButtons = 1) {
        minTitleWidth := 400
        guiWidth := minTitleWidth
    } else if (totalButtons = 2) {
        guiWidth := (buttonWidth * 2) + columnSpacing + 40
    } else {
        guiWidth := col3X + buttonWidth + 10
    }
    titleWidth := guiWidth - 20

    Gui, ScreenshotMenu:Font, s14 cYellow Bold, Consolas
    Gui, ScreenshotMenu:Add, Text, x10 y10 w%titleWidth% Center, Куда сохранить скриншот?
    Gui, ScreenshotMenu:Font, s11 cWhite, Consolas

    currentY := startY
    buttonIndex := 0
    buttonsInCurrentRow := columnsPerRow

    if (!hasCategories) {
        centerX := (guiWidth - buttonWidth) / 2
        Gui, ScreenshotMenu:Add, Button, x%centerX% y%currentY% w%buttonWidth% h%buttonHeight% gSaveScreenshotMain -TabStop, Основной
        if (totalButtons <= 9) {
            textY := currentY + buttonHeight + 2
            Gui, ScreenshotMenu:Font, s9 cGray, Consolas
            Gui, ScreenshotMenu:Add, Text, x%centerX% y%textY% w%buttonWidth% Center, [ клавиша 1 ]
            Gui, ScreenshotMenu:Font, s11 cWhite, Consolas
        }
        buttonIndex++
        if (screenshotButtonNames = "") {
            screenshotButtonNames := "Основной"
        }
    } else {
        Loop, % totalButtons
        {
            categoryName := category%A_Index%
            row := Floor(buttonIndex / columnsPerRow)
            column := Mod(buttonIndex, columnsPerRow)

            if (column = 0 && buttonIndex > 0) {
                currentY += buttonSpacing
            }

            if (column = 0) {
                remainingButtons := totalButtons - buttonIndex
                if (remainingButtons >= columnsPerRow) {
                    buttonsInCurrentRow := columnsPerRow
                } else {
                    buttonsInCurrentRow := remainingButtons
                }
            }

            if (buttonsInCurrentRow = 1) {
                buttonX := (guiWidth - buttonWidth) / 2
            } else if (buttonsInCurrentRow = 2) {
                totalWidth := (buttonWidth * 2) + columnSpacing
                startX := (guiWidth - totalWidth) / 2
                buttonX := startX + (column * (buttonWidth + columnSpacing))
            } else {
                if (column = 0) {
                    buttonX := col1X
                } else if (column = 1) {
                    buttonX := col2X
                } else {
                    buttonX := col3X
                }
            }

            Gui, ScreenshotMenu:Add, Button, x%buttonX% y%currentY% w%buttonWidth% h%buttonHeight% gSaveScreenshotCategory -TabStop, %categoryName%
            if (totalButtons <= 9) {
                textY := currentY + buttonHeight + 2
                buttonNumber := buttonIndex + 1
                Gui, ScreenshotMenu:Font, s9 cGray, Consolas
                Gui, ScreenshotMenu:Add, Text, x%buttonX% y%textY% w%buttonWidth% Center, [ клавиша %buttonNumber% ]
                Gui, ScreenshotMenu:Font, s11 cWhite, Consolas
            }
            if (screenshotButtonNames = "") {
                screenshotButtonNames := categoryName
            } else {
                screenshotButtonNames := screenshotButtonNames . "`n" . categoryName
            }
            buttonIndex++
        }
    }

    if (Mod(buttonIndex, columnsPerRow) != 0) {
        currentY += buttonSpacing
    } else {
        currentY += buttonSpacing
    }

    Gui, ScreenshotMenu:Font, s9 cGray, Consolas
    currentY += 10

    SysGet, MonitorPrimary, MonitorPrimary
    SysGet, Monitor, Monitor, %MonitorPrimary%
    screenWidth := MonitorRight - MonitorLeft
    screenHeight := MonitorBottom - MonitorTop

    if (buttonIndex >= 2) {
        buttonControlWidth := 190
        buttonSpacing := 10
        totalButtonsWidth := (buttonControlWidth * 3) + (buttonSpacing * 2)
        centerX := (guiWidth - totalButtonsWidth) / 2
        openFolderButtonX := centerX
        settingsButtonX := centerX + buttonControlWidth + buttonSpacing
        cancelButtonX := centerX + (buttonControlWidth + buttonSpacing) * 2

        Gui, ScreenshotMenu:Add, Button, x%openFolderButtonX% y%currentY% w%buttonControlWidth% h30 gOpenScreenshotFolder -TabStop, Открыть папку
        Gui, ScreenshotMenu:Add, Button, x%settingsButtonX% y%currentY% w%buttonControlWidth% h30 gOpenScreenshotSettings -TabStop, Настроить скриншоты
        Gui, ScreenshotMenu:Add, Button, x%cancelButtonX% y%currentY% w%buttonControlWidth% h30 gCloseScreenshotMenu -TabStop, Отмена (Esc)
        currentY += 35
    } else {
        buttonControlWidth := 200
        centerX := (guiWidth - buttonControlWidth) / 2
        Gui, ScreenshotMenu:Add, Button, x%centerX% y%currentY% w%buttonControlWidth% h30 gOpenScreenshotFolder -TabStop, Открыть папку
        currentY += 35
        Gui, ScreenshotMenu:Add, Button, x%centerX% y%currentY% w%buttonControlWidth% h30 gOpenScreenshotSettings -TabStop, Настроить скриншоты
        currentY += 35
        Gui, ScreenshotMenu:Add, Button, x%centerX% y%currentY% w%buttonControlWidth% h30 gCloseScreenshotMenu -TabStop, Отмена (Esc)
        currentY += 35
    }
    guiHeight := currentY + 20
    xPos := MonitorLeft + (screenWidth - guiWidth) / 2
    yPos := MonitorTop + (screenHeight - guiHeight) / 2

    Gui, ScreenshotMenu:Show, x%xPos% y%yPos% w%guiWidth% h%guiHeight%, Выбор папки
    Sleep, 50
    WinActivate, Выбор папки
}

CloseScreenshotMenu:
    global tempScreenshotPath
    if (tempScreenshotPath != "" && FileExist(tempScreenshotPath)) {
        FileDelete, %tempScreenshotPath%
    }
    tempScreenshotPath := ""
    Gui, ScreenshotMenu:Destroy
return

OpenScreenshotFolder:
    basePath := GetScreenshotBasePath()
    if (basePath != "" && FileExist(basePath)) {
        Run, explorer.exe "%basePath%"
    } else if (basePath != "") {
        FileCreateDir, %basePath%
        if (!ErrorLevel) {
            Run, explorer.exe "%basePath%"
        }
    }
return

OpenScreenshotSettings:
    global tempScreenshotPath
    Gui, ScreenshotMenu:Destroy
    if (tempScreenshotPath != "" && FileExist(tempScreenshotPath)) {
        FileDelete, %tempScreenshotPath%
        tempScreenshotPath := ""
    }
    ShowScreenshotSettings()
return

SaveScreenshotCategory:
    GuiControlGet, categoryName, , %A_GuiControl%
    MoveScreenshot(categoryName)
return

SaveScreenshotMain:
    MoveScreenshot("")
return

RestartScriptNow:
    Run, "%A_AhkPath%" "%A_ScriptFullPath%"
ExitApp
return

ClickScreenshotButton(buttonNumber) {
    global screenshotButtonCount, screenshotButtonNames

    IfWinNotExist, Выбор папки
    {
        return
    }

    IfWinNotActive, Выбор папки
    {
        return
    }

    if (screenshotButtonCount = 0 || screenshotButtonCount > 9) {
        return
    }

    if (buttonNumber < 1 || buttonNumber > screenshotButtonCount) {
        return
    }

    StringSplit, buttonNames, screenshotButtonNames, `n
    buttonName := buttonNames%buttonNumber%

    if (buttonName = "") {
        return
    }

    ControlClick, %buttonName%, Выбор папки, , , , NA
}

GetScreenshotBasePath() {
    basePath := LoadIniValue("screenshot.BasePath")
    if (basePath = "") {
        if (A_UserName != "" && FileExist("C:\Users\" . A_UserName)) {
            basePath := "C:\Users\" . A_UserName . "\Pictures\Screenshots"
        } else {
            basePath := A_ScriptDir . "\Скриншоты"
        }
    }

    if (basePath != "" && !RegExMatch(basePath, "^[A-Za-z]:\\")) {
        basePath := A_ScriptDir . "\" . basePath
    }

    if (!FileExist(basePath)) {
        FileCreateDir, %basePath%
        if (ErrorLevel) {
            basePath := A_ScriptDir . "\Скриншоты"
            FileCreateDir, %basePath%
        }
    }

    return basePath
}

GetScreenshotMonitor() {
    SysGet, MonitorPrimary, MonitorPrimary
    monitorNumber := LoadIniValue("screenshot.Monitor")
    if (monitorNumber = "") {
        return MonitorPrimary
    }
    return monitorNumber
}

GetMonitorList() {
    monitorList := ""
    SysGet, MonitorCount, MonitorCount
    Loop, %MonitorCount%
    {
        SysGet, Monitor, Monitor, %A_Index%
        monitorWidth := MonitorRight - MonitorLeft
        monitorHeight := MonitorBottom - MonitorTop
        SysGet, MonitorPrimary, MonitorPrimary
        isPrimary := (A_Index = MonitorPrimary) ? " (Основной)" : ""
        monitorName := "Монитор " . A_Index . isPrimary . " - " . monitorWidth . "x" . monitorHeight
        if (monitorList = "") {
            monitorList := monitorName
        } else {
            monitorList := monitorList . "|" . monitorName
        }
    }
    return monitorList
}

GetScreenshotCategories() {
    arrayContent := LoadIniArray("screenshot.Categories")
    if (arrayContent = "") {
        return ""
    }

    categories := ""
    pattern := """([^""]*(?:\\.[^""]*)*)"""
    pos := 1
    while (pos := RegExMatch(arrayContent, pattern, itemMatch, pos)) {
        value := itemMatch1
        StringReplace, value, value, \", ", All
        StringReplace, value, value, \\, \, All
        StringReplace, value, value, \n, `n, All
        StringReplace, value, value, \r, `r, All
        StringReplace, value, value, \t, %A_Tab%, All
        value := Trim(value)
        if (value != "") {
            if (categories = "") {
                categories := value
            } else {
                categories := categories . "`n" . value
            }
        }
        pos += StrLen(itemMatch)
    }

    return categories
}

SaveScreenshotCategory(categoryName) {
    arrayContent := LoadIniArray("screenshot.Categories")
    if (arrayContent = "") {
        arrayContent := ""
    }

    escapedValue := EscapeJsonString(categoryName)
    if (arrayContent = "") {
        arrayContent := """" . escapedValue . """"
    } else {
        arrayContent := arrayContent . ", """ . escapedValue . """"
    }

    SaveIniArray("screenshot.Categories", arrayContent)
}

DeleteScreenshotCategory(categoryName) {
    categories := GetScreenshotCategories()
    if (categories = "") {
        return
    }

    newCategories := ""
    Loop, Parse, categories, `n
    {
        if (A_LoopField != "" && Trim(A_LoopField) != categoryName) {
            if (newCategories = "") {
                newCategories := Trim(A_LoopField)
            } else {
                newCategories := newCategories . "`n" . Trim(A_LoopField)
            }
        }
    }

    arrayContent := ""
    if (newCategories != "") {
        Loop, Parse, newCategories, `n
        {
            if (A_LoopField != "") {
                escapedValue := EscapeJsonString(Trim(A_LoopField))
                if (arrayContent = "") {
                    arrayContent := """" . escapedValue . """"
                } else {
                    arrayContent := arrayContent . ", """ . escapedValue . """"
                }
            }
        }
    }

    SaveIniArray("screenshot.Categories", arrayContent)
}

ShowScreenshotSettings() {
    global SettingsBasePath, SettingsCategoryList, settingsCategoriesList, SettingsMonitor

    categories := GetScreenshotCategories()
    settingsCategoriesList := categories

    Gui, Settings:Destroy
    Gui, Settings:+AlwaysOnTop -MinimizeBox +Owner
    Gui, Settings:Color, 0a0a0a
    Gui, Settings:Font, s10 cWhite, Consolas

    Gui, Settings:Add, Text, x10 y10 w100 cWhite, Путь сохранения:
    basePath := GetScreenshotBasePath()
    Gui, Settings:Add, Edit, x10 y30 w400 vSettingsBasePath cBlack -TabStop, %basePath%
    Gui, Settings:Add, Button, x420 y28 w80 h25 gBrowseFolder, Обзор...

    Gui, Settings:Add, Text, x10 y65 w200 cWhite, Монитор для скриншотов:
    monitorList := GetMonitorList()
    currentMonitor := GetScreenshotMonitor()
    SysGet, MonitorCount, MonitorCount
    selectedIndex := currentMonitor
    Gui, Settings:Add, DropDownList, x10 y85 w300 vSettingsMonitor Choose%selectedIndex% +TabStop, %monitorList%

    categoryListForBox := ""
    if (categories != "") {
        if (!InStr(categories, "`n")) {
            categoryListForBox := Trim(categories)
        } else {
            Loop, Parse, categories, `n
            {
                trimmedField := Trim(A_LoopField)
                if (trimmedField != "") {
                    if (categoryListForBox = "") {
                        categoryListForBox := trimmedField
                    } else {
                        categoryListForBox := categoryListForBox . "|" . trimmedField
                    }
                }
            }
        }
    }

    Gui, Settings:Add, Text, x10 y120 w200 cWhite, Категории:
    Gui, Settings:Add, ListBox, x10 y140 w300 h200 vSettingsCategoryList cBlack gSettingsCategorySelect, %categoryListForBox%
    Gui, Settings:Add, Button, x320 y140 w110 h30 gAddCategory, Добавить
    Gui, Settings:Add, Button, x320 y180 w110 h30 gEditCategory, Редактировать
    Gui, Settings:Add, Button, x320 y220 w110 h30 gDeleteCategory, Удалить
    Gui, Settings:Add, Button, x320 y260 w50 h30 gMoveCategoryUp, ↑
    Gui, Settings:Add, Button, x380 y260 w50 h30 gMoveCategoryDown, ↓

    Gui, Settings:Add, Button, x10 y350 w100 h30 gSaveSettings, Сохранить
    Gui, Settings:Add, Button, x120 y350 w100 h30 gCloseSettings, Отмена

    Gui, Settings:Show, w520 h390, Настройки сохранения скриншотов
}

BrowseFolder:
    Gui, Settings:+OwnDialogs
    Gui, Settings:Submit, NoHide
    FileSelectFolder, selectedFolder, *%SettingsBasePath%, 3, Выберите папку для сохранения скриншотов
    if (selectedFolder != "") {
        GuiControl, , SettingsBasePath, %selectedFolder%
    }
return

SettingsCategorySelect:
    GuiControlGet, selectedCategory, , SettingsCategoryList
return

AddCategory:
    global settingsCategoriesList
    Gui, Settings:+OwnDialogs
    InputBox, newCategory, Добавить категорию, Введите название категории:,, 300, 130
    if (!ErrorLevel && newCategory != "") {
        if (settingsCategoriesList = "") {
            settingsCategoriesList := newCategory
        } else {
            settingsCategoriesList := settingsCategoriesList . "`n" . newCategory
        }

        UpdateCategoryListBox()
    }
return

EditCategory:
    global settingsCategoriesList
    GuiControlGet, selectedCategory, , SettingsCategoryList
    if (selectedCategory = "") {
        Gui, Settings:+OwnDialogs
        MsgBox, 48, Ошибка, Выберите категорию для редактирования
        return
    }

    selectedIndex := 0
    categoryCount := 0
    Loop, Parse, settingsCategoriesList, `n
    {
        if (A_LoopField != "") {
            categoryCount++
            if (A_LoopField = selectedCategory) {
                selectedIndex := categoryCount
            }
        }
    }

    Gui, Settings:+OwnDialogs
    defaultText = %selectedCategory%
    InputBox, editedCategory, Редактировать категорию, Введите новое название:, , 300, 130, , , , , %defaultText%
    if (!ErrorLevel && editedCategory != "") {
        StringReplace, settingsCategoriesList, settingsCategoriesList, %selectedCategory%, %editedCategory%, All

        UpdateCategoryListBox(selectedIndex)
    }
return

DeleteCategory:
    global settingsCategoriesList
    GuiControlGet, selectedCategory, , SettingsCategoryList
    if (selectedCategory = "") {
        Gui, Settings:+OwnDialogs
        MsgBox, 48, Ошибка, Выберите категорию для удаления
        return
    }

    selectedIndex := 0
    categoryCount := 0
    Loop, Parse, settingsCategoriesList, `n
    {
        if (A_LoopField != "") {
            categoryCount++
            if (A_LoopField = selectedCategory) {
                selectedIndex := categoryCount
            }
        }
    }

    Gui, Settings:+OwnDialogs
    MsgBox, 4, Подтверждение, Удалить категорию "%selectedCategory%"?
    IfMsgBox Yes
    {
        StringReplace, settingsCategoriesList, settingsCategoriesList, %selectedCategory%`n, , All
        StringReplace, settingsCategoriesList, settingsCategoriesList, %selectedCategory%, , All

        newSelectedIndex := 0
        if (selectedIndex > 1) {
            newSelectedIndex := selectedIndex - 1
        } else if (categoryCount > 1) {
            newSelectedIndex := 1
        }

        UpdateCategoryListBox(newSelectedIndex)
    }
return

UpdateCategoryListBox(selectedIndex := 0) {
    global settingsCategoriesList
    GuiControl, , SettingsCategoryList, |

    categoryList := ""
    if (settingsCategoriesList != "") {
        trimmedList := Trim(settingsCategoriesList)
        if (trimmedList != "") {
            if (!InStr(trimmedList, "`n")) {
                categoryList := trimmedList
            } else {
                Loop, Parse, trimmedList, `n
                {
                    trimmedField := Trim(A_LoopField)
                    if (trimmedField != "") {
                        if (categoryList = "") {
                            categoryList := trimmedField
                        } else {
                            categoryList := categoryList . "|" . trimmedField
                        }
                    }
                }
            }
        }
    }

    if (categoryList != "") {
        GuiControl, , SettingsCategoryList, %categoryList%
    }

    if (selectedIndex > 0) {
        GuiControl, Choose, SettingsCategoryList, %selectedIndex%
    }
}

MoveCategoryUp:
    global settingsCategoriesList
    GuiControlGet, selectedCategory, , SettingsCategoryList
    if (selectedCategory = "") {
        Gui, Settings:+OwnDialogs
        MsgBox, 48, Ошибка, Выберите категорию для перемещения
        return
    }

    categoryCount := 0
    Loop, Parse, settingsCategoriesList, `n
    {
        if (A_LoopField != "") {
            categoryCount++
            category%categoryCount% := A_LoopField
        }
    }

    selectedIndex := 0
    Loop, %categoryCount%
    {
        if (category%A_Index% = selectedCategory) {
            selectedIndex := A_Index
            break
        }
    }

    if (selectedIndex > 1) {
        temp := category%selectedIndex%
        prevIndex := selectedIndex - 1
        category%selectedIndex% := category%prevIndex%
        category%prevIndex% := temp

        settingsCategoriesList := ""
        Loop, %categoryCount%
        {
            if (settingsCategoriesList = "") {
                settingsCategoriesList := category%A_Index%
            } else {
                settingsCategoriesList := settingsCategoriesList . "`n" . category%A_Index%
            }
        }

        UpdateCategoryListBox()
        newSelectedIndex := selectedIndex - 1
        GuiControl, Choose, SettingsCategoryList, %newSelectedIndex%
    }
return

MoveCategoryDown:
    global settingsCategoriesList
    GuiControlGet, selectedCategory, , SettingsCategoryList
    if (selectedCategory = "") {
        Gui, Settings:+OwnDialogs
        MsgBox, 48, Ошибка, Выберите категорию для перемещения
        return
    }

    categoryCount := 0
    Loop, Parse, settingsCategoriesList, `n
    {
        if (A_LoopField != "") {
            categoryCount++
            category%categoryCount% := A_LoopField
        }
    }

    selectedIndex := 0
    Loop, %categoryCount%
    {
        if (category%A_Index% = selectedCategory) {
            selectedIndex := A_Index
            break
        }
    }

    if (selectedIndex > 0 && selectedIndex < categoryCount) {
        temp := category%selectedIndex%
        nextIndex := selectedIndex + 1
        category%selectedIndex% := category%nextIndex%
        category%nextIndex% := temp

        settingsCategoriesList := ""
        Loop, %categoryCount%
        {
            if (settingsCategoriesList = "") {
                settingsCategoriesList := category%A_Index%
            } else {
                settingsCategoriesList := settingsCategoriesList . "`n" . category%A_Index%
            }
        }

        UpdateCategoryListBox()
        newSelectedIndex := selectedIndex + 1
        GuiControl, Choose, SettingsCategoryList, %newSelectedIndex%
    }
return

SaveSettings:
    global settingsCategoriesList, SettingsMonitor
    Gui, Settings:Submit, NoHide

    SaveIniValue("screenshot.BasePath", SettingsBasePath)

    RegExMatch(SettingsMonitor, "Монитор (\d+)", monitorMatch)
    if (monitorMatch1 != "") {
        SaveIniValue("screenshot.Monitor", monitorMatch1, false)
    }

    arrayContent := ""
    if (settingsCategoriesList != "") {
        Loop, Parse, settingsCategoriesList, `n
        {
            if (A_LoopField != "") {
                escapedValue := EscapeJsonString(Trim(A_LoopField))
                if (arrayContent = "") {
                    arrayContent := """" . escapedValue . """"
                } else {
                    arrayContent := arrayContent . ", """ . escapedValue . """"
                }
            }
        }
    }
    SaveIniArray("screenshot.Categories", arrayContent)

    Gui, Settings:+OwnDialogs
    MsgBox, 64, Успех, Настройки сохранены!
    Gui, Settings:Destroy
return

CloseSettings:
    Gui, Settings:Destroy
return

SaveTempScreenshot() {
    global lastScreenshotError
    screenshotsPath := GetScreenshotBasePath()

    if (!FileExist(screenshotsPath)) {
        FileCreateDir, %screenshotsPath%
    }

    FormatTime, timestamp, , yyyy-MM-dd_HH-mm-ss
    tempFileName := screenshotsPath . "\temp_" . timestamp . ".png"

    monitorNumber := GetScreenshotMonitor()
    lastScreenshotError := ""
    result := CaptureScreen(tempFileName, monitorNumber)

    if (result != "" && FileExist(tempFileName)) {
        return tempFileName
    }

    if (lastScreenshotError != "")
        WriteLog("Screenshot: " . lastScreenshotError)
    else
        WriteLog("Screenshot: unknown_error")
    return ""
}

CaptureScreen(savePath := "", monitorNumber := 0) {
    global lastScreenshotError
    hModule := DllCall("LoadLibrary", "str", "gdiplus.dll")
    if (!hModule) {
        lastScreenshotError := "LoadLibrary(gdiplus.dll) failed"
        ToolTip, Ошибка: %lastScreenshotError%
        SetTimer, RemoveToolTip, 2000
        return ""
    }

    siSize := A_PtrSize = 8 ? 24 : 16
    VarSetCapacity(si, siSize, 0)
    NumPut(1, si, 0, "UInt")

    pToken := 0
    r := DllCall("gdiplus\GdiplusStartup", "ptr*", pToken, "ptr", &si, "ptr", 0)
    if (r != 0) {
        lastScreenshotError := "GdiplusStartup failed (code: " r ")"
        ToolTip, Ошибка: %lastScreenshotError%
        SetTimer, RemoveToolTip, 2000
        return ""
    }

    pTokenValue := pToken

    if (monitorNumber = 0) {
        SysGet, MonitorPrimary, MonitorPrimary
        monitorNumber := MonitorPrimary
    }

    SysGet, Monitor, Monitor, %monitorNumber%
    x := MonitorLeft
    y := MonitorTop
    w := MonitorRight - MonitorLeft
    h := MonitorBottom - MonitorTop

    hdcScreen := DllCall("GetDC", "ptr", 0, "ptr")
    if (!hdcScreen) {
        lastScreenshotError := "GetDC failed"
        ToolTip, Ошибка: %lastScreenshotError%
        SetTimer, RemoveToolTip, 2000
        DllCall("gdiplus\GdiplusShutdown", "ptr", pTokenValue)
        return ""
    }

    hdcMem := DllCall("CreateCompatibleDC", "ptr", hdcScreen, "ptr")
    if (!hdcMem) {
        lastScreenshotError := "CreateCompatibleDC failed"
        ToolTip, Ошибка: %lastScreenshotError%
        SetTimer, RemoveToolTip, 2000
        DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)
        DllCall("gdiplus\GdiplusShutdown", "ptr", pTokenValue)
        return ""
    }

    hbm := DllCall("CreateCompatibleBitmap", "ptr", hdcScreen, "int", w, "int", h, "ptr")
    if (!hbm) {
        lastScreenshotError := "CreateCompatibleBitmap failed"
        ToolTip, Ошибка: %lastScreenshotError%
        SetTimer, RemoveToolTip, 2000
        DllCall("DeleteDC", "ptr", hdcMem)
        DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)
        DllCall("gdiplus\GdiplusShutdown", "ptr", pTokenValue)
        return ""
    }

    DllCall("SelectObject", "ptr", hdcMem, "ptr", hbm)

    r := DllCall("BitBlt", "ptr", hdcMem, "int", 0, "int", 0, "int", w, "int", h
        , "ptr", hdcScreen, "int", x, "int", y, "uint", 0x00CC0020)
    if (!r) {
        errorCode := DllCall("GetLastError")
        lastScreenshotError := "BitBlt failed (code: " errorCode ")"
        ToolTip, Ошибка: %lastScreenshotError%
        SetTimer, RemoveToolTip, 2000
        DllCall("DeleteObject", "ptr", hbm)
        DllCall("DeleteDC", "ptr", hdcMem)
        DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)
        DllCall("gdiplus\GdiplusShutdown", "ptr", pTokenValue)
        return ""
    }

    pBitmap := 0
    r := DllCall("gdiplus\GdipCreateBitmapFromHBITMAP"
        , "ptr", hbm
        , "ptr", 0
        , "ptr*", pBitmap)

    if (r != 0 || !pBitmap) {
        lastScreenshotError := "GdipCreateBitmapFromHBITMAP failed (code: " r ")"
        ToolTip, Ошибка: %lastScreenshotError%
        SetTimer, RemoveToolTip, 2000
        DllCall("DeleteObject", "ptr", hbm)
        DllCall("DeleteDC", "ptr", hdcMem)
        DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)
        DllCall("gdiplus\GdiplusShutdown", "ptr", pTokenValue)
        return ""
    }

    if (savePath != "") {
        if (!Gdip_GetEncoderClsid("image/png", pngClsid)) {
            lastScreenshotError := "Failed to get PNG encoder"
            ToolTip, Ошибка: %lastScreenshotError%
            SetTimer, RemoveToolTip, 2000
            DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
            DllCall("DeleteObject", "ptr", hbm)
            DllCall("DeleteDC", "ptr", hdcMem)
            DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)
            DllCall("gdiplus\GdiplusShutdown", "ptr", pTokenValue)
            return ""
        }
        
        VarSetCapacity(wPath, StrLen(savePath) * 2 + 2, 0)
        StrPut(savePath, &wPath, "UTF-16")
        r := DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBitmap, "ptr", &wPath, "ptr", &pngClsid, "ptr", 0)
        if (r != 0) {
            lastScreenshotError := "Failed to save PNG file (code: " r ")"
            ToolTip, Ошибка: %lastScreenshotError%
            SetTimer, RemoveToolTip, 2000
            DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
            DllCall("DeleteObject", "ptr", hbm)
            DllCall("DeleteDC", "ptr", hdcMem)
            DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)
            DllCall("gdiplus\GdiplusShutdown", "ptr", pTokenValue)
            return ""
        }
    }

    DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
    DllCall("DeleteObject", "ptr", hbm)
    DllCall("DeleteDC", "ptr", hdcMem)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)
    DllCall("gdiplus\GdiplusShutdown", "ptr", pTokenValue)

    return savePath
}

SaveBitmapToFile(hBitmap, filePath) {
    VarSetCapacity(bm, A_PtrSize = 8 ? 32 : 24, 0)
    DllCall("GetObject", "ptr", hBitmap, "int", A_PtrSize = 8 ? 32 : 24, "ptr", &bm)

    width := NumGet(bm, 4, "Int")
    height := NumGet(bm, 8, "Int")
    bitsPerPixel := NumGet(bm, 18, "UShort")

    bytesPerPixel := bitsPerPixel // 8
    rowSize := width * bytesPerPixel
    rowPadding := Mod(4 - Mod(rowSize, 4), 4)
    rowSizeAligned := rowSize + rowPadding

    imageSize := rowSizeAligned * height

    fileHeaderSize := 14
    dibHeaderSize := 40
    fileSize := fileHeaderSize + dibHeaderSize + imageSize

    FileDelete, %filePath%
    FileAppend,, %filePath%

    file := FileOpen(filePath, "w")
    if (!file) {
        return false
    }

    file.WriteUChar(0x42)
    file.WriteUChar(0x4D)
    file.WriteUInt(fileSize)
    file.WriteUShort(0)
    file.WriteUShort(0)
    file.WriteUInt(fileHeaderSize + dibHeaderSize)

    file.WriteUInt(dibHeaderSize)
    file.WriteInt(width)
    file.WriteInt(height)
    file.WriteUShort(1)
    file.WriteUShort(bitsPerPixel)
    file.WriteUInt(0)
    file.WriteUInt(imageSize)
    file.WriteUInt(0)
    file.WriteUInt(0)
    file.WriteUInt(0)
    file.WriteUInt(0)

    hdcSource := DllCall("CreateCompatibleDC", "ptr", 0)
    DllCall("SelectObject", "ptr", hdcSource, "ptr", hBitmap)

    VarSetCapacity(bi, 40, 0)
    NumPut(40, bi, 0, "UInt")
    NumPut(width, bi, 4, "Int")
    NumPut(-height, bi, 8, "Int")
    NumPut(1, bi, 12, "UShort")
    NumPut(bitsPerPixel, bi, 14, "UShort")
    NumPut(0, bi, 16, "UInt")

    VarSetCapacity(bits, imageSize, 0)

    r := DllCall("GetDIBits", "ptr", hdcSource, "ptr", hBitmap, "uint", 0, "uint", height, "ptr", &bits, "ptr", &bi, "uint", 0)

    if (r) {
        Loop, %height%
        {
            rowIndex := height - A_Index
            offset := rowIndex * rowSizeAligned
            file.RawWrite(&bits + offset, rowSize)
            if (rowPadding > 0) {
                VarSetCapacity(padding, rowPadding, 0)
                file.RawWrite(&padding, rowPadding)
            }
        }
    }

    DllCall("DeleteDC", "ptr", hdcSource)
    file.Close()

    return r ? true : false
}

Gdip_GetEncoderClsid(mime, ByRef clsid) {
    VarSetCapacity(clsid, 16, 0)
    
    DllCall("gdiplus\GdipGetImageEncodersSize", "uint*", nCount, "uint*", nSize)
    
    if (!nCount || !nSize) {
        return 0
    }

    VarSetCapacity(ci, nSize, 0)
    DllCall("gdiplus\GdipGetImageEncoders", "uint", nCount, "uint", nSize, "ptr", &ci)

    structSize := A_PtrSize = 8 ? 104 : 76

    Loop, %nCount%
    {
        offset := (A_Index - 1) * structSize

        mimeTypeOffset := offset + 32 + (A_PtrSize * 4)
        mimeTypePtr := NumGet(ci, mimeTypeOffset, A_PtrSize = 8 ? "Int64" : "UInt")

        if (mimeTypePtr) {
            mimeTypeStr := StrGet(mimeTypePtr, 100, "UTF-16")
            if (mimeTypeStr = mime) {
                DllCall("RtlMoveMemory", "ptr", &clsid, "ptr", &ci + offset, "uint", 16)
                return 1
            }
        }
    }

    return 0
}

MoveScreenshot(folderName) {
    global tempScreenshotPath
    Gui, ScreenshotMenu:Destroy

    if (tempScreenshotPath = "" || !FileExist(tempScreenshotPath)) {
        ToolTip, Ошибка: временный файл не найден
        SetTimer, RemoveToolTip, 2000
        return
    }

    screenshotsPath := GetScreenshotBasePath()

    savedPath := LoadIniValue("screenshot.BasePath")
    if (savedPath = "") {
        SaveIniValue("screenshot.BasePath", screenshotsPath)
    }

    if (folderName = "") {
        folderPath := screenshotsPath
    } else {
        folderPath := screenshotsPath . "\" . folderName
        if (!FileExist(folderPath)) {
            FileCreateDir, %folderPath%
            if (ErrorLevel) {
                ToolTip, Ошибка создания папки: %folderPath%
                SetTimer, RemoveToolTip, 2000
                return
            }
        }
    }

    FormatTime, timestamp, , dd.MM.yyyy HH-mm-ss
    newFileName := folderPath . "\" . timestamp . ".png"

    FileMove, %tempScreenshotPath%, %newFileName%, 1

    if (FileExist(tempScreenshotPath)) {
        FileDelete, %tempScreenshotPath%
    }

    if (FileExist(newFileName)) {
        relativePath := StrReplace(newFileName, screenshotsPath . "\", "")
        ToolTip, Скриншот сохранен: %relativePath%
        tempScreenshotPath := ""
    } else {
        ToolTip, Ошибка перемещения скриншота
    }
    SetTimer, RemoveToolTip, 2000
}

NormalizeKeyFormat(key) {
    if (key = "") {
        return ""
    }
    key := RegExReplace(key, "&\s*", " & ")
    key := RegExReplace(key, "\s+&\s+", " & ")
    key := RegExReplace(key, "^\s+|\s+$", "")
    return key
}

FormatKeyForDisplay(keyCombo) {
    if (keyCombo = "") {
        return ""
    }
    
    if (InStr(keyCombo, " & ")) {
        StringReplace, displayKey, keyCombo, LControl & , LCtrl+, All
        StringReplace, displayKey, displayKey, RControl & , RCtrl+, All
        StringReplace, displayKey, displayKey, LAlt & , LAlt+, All
        StringReplace, displayKey, displayKey, RAlt & , RAlt+, All
        StringReplace, displayKey, displayKey, LShift & , LShift+, All
        StringReplace, displayKey, displayKey, RShift & , RShift+, All
        StringReplace, displayKey, displayKey, LWin & , LWin+, All
        StringReplace, displayKey, displayKey, RWin & , RWin+, All
        StringReplace, displayKey, displayKey,  & , +, All
        displayKey := RegExReplace(displayKey, "\+\s+", "+")
        return displayKey
    }
    
    modifiers := ""
    mainKey := keyCombo
    
    if (RegExMatch(keyCombo, "\^")) {
        modifiers .= "Ctrl+"
        mainKey := RegExReplace(mainKey, "\^", "")
    }
    if (RegExMatch(keyCombo, "!")) {
        modifiers .= "Alt+"
        mainKey := RegExReplace(mainKey, "!", "")
    }
    if (RegExMatch(keyCombo, "\+")) {
        modifiers .= "Shift+"
        mainKey := RegExReplace(mainKey, "\+", "")
    }
    if (RegExMatch(keyCombo, "#")) {
        modifiers .= "Win+"
        mainKey := RegExReplace(mainKey, "#", "")
    }
    
    modifiers := RegExReplace(modifiers, "\+$", "")
    
    if (modifiers != "") {
        return modifiers . "+" . mainKey
    } else {
        return mainKey
    }
}

FormatKeyForStorage(displayKey) {
    if (displayKey = "") {
        return ""
    }
    
    storageKey := displayKey
    
    if (InStr(storageKey, "+")) {
        StringReplace, storageKey, storageKey, LCtrl+, LControl & , All
        StringReplace, storageKey, storageKey, RCtrl+, RControl & , All
        StringReplace, storageKey, storageKey, LAlt+, LAlt & , All
        StringReplace, storageKey, storageKey, RAlt+, RAlt & , All
        StringReplace, storageKey, storageKey, LShift+, LShift & , All
        StringReplace, storageKey, storageKey, RShift+, RShift & , All
        StringReplace, storageKey, storageKey, LWin+, LWin & , All
        StringReplace, storageKey, storageKey, RWin+, RWin & , All
        StringReplace, storageKey, storageKey, Ctrl+, Control & , All
        StringReplace, storageKey, storageKey, Alt+, Alt & , All
        StringReplace, storageKey, storageKey, Shift+, Shift & , All
        StringReplace, storageKey, storageKey, Win+, Win & , All
        StringReplace, storageKey, storageKey, +, & , All
    }
    
    return NormalizeKeyFormat(storageKey)
}

LoadKeyRemapSettings() {
    global keyForInfo, keyForKoap, keyForUK, keyForScreenshot, badgeMessage, keyForBadge, presentationMessage, keyForPresentation, keyForSettings
    global enabledInfo, enabledKoap, enabledUK, enabledScreenshot, enabledBadge, enabledPresentation
    global badgeAutoSendGlobal, presentationAutoSendGlobal
    global windowActivationMode
    WriteLog("LoadKeyRemapSettings: загрузка настроек клавиш")

    try {
        keyForInfo := NormalizeKeyFormat(LoadIniValue("keyRemap.Info"))
        if (keyForInfo = "") {
            keyForInfo := "F4"
        }
    } catch {
        keyForInfo := "F4"
    }

    try {
        keyForKoap := NormalizeKeyFormat(LoadIniValue("keyRemap.Koap"))
        if (keyForKoap = "") {
            keyForKoap := "F5"
        }
    } catch {
        keyForKoap := "F5"
    }

    try {
        keyForUK := NormalizeKeyFormat(LoadIniValue("keyRemap.UK"))
        if (keyForUK = "") {
            keyForUK := "F6"
        }
    } catch {
        keyForUK := "F6"
    }

    try {
        keyForScreenshot := NormalizeKeyFormat(LoadIniValue("keyRemap.Screenshot"))
        if (keyForScreenshot = "") {
            keyForScreenshot := "F9"
        }
    } catch {
        keyForScreenshot := "F9"
    }

    try {
        badgeMessage := LoadIniValue("badge.Message")
        if (badgeMessage = "") {
            badgeMessage := "На груди висит Жетон ФСБ РФ || X || «XXX» || «X» || №-00XX |."
        }
    } catch {
        badgeMessage := "На груди висит Жетон ФСБ РФ || X || «XXX» || «X» || №-00XX |."
    }

    try {
        keyForBadge := NormalizeKeyFormat(LoadIniValue("badge.Key"))
        if (keyForBadge = "") {
            keyForBadge := "F8"
        }
    } catch {
        keyForBadge := "F8"
    }

    try {
        presentationMessage := LoadIniValue("presentation.Message")
        if (presentationMessage = "") {
            presentationMessage := "Добрый день, являюсь Должность/Отдел, Звание, Фамилия"
        }
    } catch {
        presentationMessage := "Добрый день, являюсь Должность/Отдел, Звание, Фамилия"
    }

    try {
        keyForPresentation := NormalizeKeyFormat(LoadIniValue("presentation.Key"))
    } catch {
        keyForPresentation := ""
    }

    try {
        keyForSettings := NormalizeKeyFormat(LoadIniValue("keyRemap.Settings"))
        if (keyForSettings = "") {
            keyForSettings := "F3"
        }
    } catch {
        keyForSettings := "F3"
    }

    try {
        badgeAutoSendStr := LoadIniValue("badge.AutoSend")
        badgeAutoSendGlobal := (badgeAutoSendStr = "1") ? 1 : 0
    } catch {
        badgeAutoSendGlobal := 0
    }

    try {
        presentationAutoSendStr := LoadIniValue("presentation.AutoSend")
        presentationAutoSendGlobal := (presentationAutoSendStr = "1") ? 1 : 0
    } catch {
        presentationAutoSendGlobal := 0
    }

    try {
        enabledInfoStr := LoadIniValue("enabled.Info")
        enabledInfo := (enabledInfoStr = "" || enabledInfoStr = "1") ? 1 : 0
    } catch {
        enabledInfo := 1
    }

    try {
        enabledKoapStr := LoadIniValue("enabled.Koap")
        enabledKoap := (enabledKoapStr = "" || enabledKoapStr = "1") ? 1 : 0
    } catch {
        enabledKoap := 1
    }

    try {
        enabledUKStr := LoadIniValue("enabled.UK")
        enabledUK := (enabledUKStr = "" || enabledUKStr = "1") ? 1 : 0
    } catch {
        enabledUK := 1
    }

    try {
        enabledScreenshotStr := LoadIniValue("enabled.Screenshot")
        enabledScreenshot := (enabledScreenshotStr = "" || enabledScreenshotStr = "1") ? 1 : 0
    } catch {
        enabledScreenshot := 1
    }

    try {
        enabledBadgeStr := LoadIniValue("enabled.Badge")
        enabledBadge := (enabledBadgeStr = "" || enabledBadgeStr = "1") ? 1 : 0
    } catch {
        enabledBadge := 1
    }

    try {
        enabledPresentationStr := LoadIniValue("enabled.Presentation")
        enabledPresentation := (enabledPresentationStr = "" || enabledPresentationStr = "1") ? 1 : 0
    } catch {
        enabledPresentation := 1
    }

    try {
        enabledAutoLayoutStr := LoadIniValue("enabled.AutoLayout")
        enabledAutoLayout := (enabledAutoLayoutStr = "" || enabledAutoLayoutStr = "1") ? 1 : 0
    } catch {
        enabledAutoLayout := 1
    }

    try {
        windowActivationModeStr := Trim(LoadIniValue("settings.WindowActivationMode"))
        if (windowActivationModeStr = "2") {
            windowActivationMode := 2
        } else {
            windowActivationMode := 1
        }
    } catch {
        windowActivationMode := 1
    }

    try {
        autoMemoryCleanStr := LoadIniValue("settings.AutoMemoryClean")
        autoMemoryCleanEnabled := (autoMemoryCleanStr = "" || autoMemoryCleanStr = "1") ? 1 : 0
        if (autoMemoryCleanEnabled = 1) {
            SetTimer, AutoMemoryClean, 300000
        } else {
            SetTimer, AutoMemoryClean, Off
        }
    } catch {
    }

    try {
        SetupDynamicHotkeys()
        SetupAutoLayoutHotkeys()
    } catch e {
    }
}

SaveKeyRemapSettings() {
    WriteLog("SaveKeyRemapSettings: сохранение настроек клавиш")
    global keyForInfo, keyForKoap, keyForUK, keyForScreenshot, badgeMessage, keyForBadge, presentationMessage, keyForPresentation, keyForSettings
    global enabledInfo, enabledKoap, enabledUK, enabledScreenshot, enabledBadge, enabledPresentation
    global badgeAutoSendGlobal, presentationAutoSendGlobal
    global windowActivationMode

    SaveIniValue("keyRemap.Info", keyForInfo)
    SaveIniValue("keyRemap.Koap", keyForKoap)
    SaveIniValue("keyRemap.UK", keyForUK)
    SaveIniValue("keyRemap.Screenshot", keyForScreenshot)
    SaveIniValue("badge.Message", badgeMessage)
    SaveIniValue("badge.Key", keyForBadge)
    SaveIniValue("presentation.Message", presentationMessage)
    SaveIniValue("presentation.Key", keyForPresentation)
    SaveIniValue("keyRemap.Settings", keyForSettings)
    SaveIniValue("badge.AutoSend", badgeAutoSendGlobal, false)
    SaveIniValue("presentation.AutoSend", presentationAutoSendGlobal, false)
    SaveIniValue("enabled.Info", enabledInfo, false)
    SaveIniValue("enabled.Koap", enabledKoap, false)
    SaveIniValue("enabled.UK", enabledUK, false)
    SaveIniValue("enabled.Screenshot", enabledScreenshot, false)
    SaveIniValue("enabled.Badge", enabledBadge, false)
    SaveIniValue("enabled.Presentation", enabledPresentation, false)
    SaveIniValue("enabled.AutoLayout", enabledAutoLayout, false)
    SaveIniValue("settings.WindowActivationMode", windowActivationMode, false)
}

DisableAllHotkeys() {
    global keyForInfo, keyForKoap, keyForUK, keyForScreenshot, keyForBadge, keyForPresentation, keyForSettings

    if (keyForSettings != "") {
        keyForSettingsFormatted := ConvertKeyForHotkey(keyForSettings)
        if (keyForSettingsFormatted != "") {
            Hotkey, %keyForSettingsFormatted%, Off, UseErrorLevel
        }
        Hotkey, %keyForSettings%, Off, UseErrorLevel
    }

    if (keyForInfo != "") {
        keyForInfoFormatted := ConvertKeyForHotkey(keyForInfo)
        if (keyForInfoFormatted != "") {
            Hotkey, %keyForInfoFormatted%, Off, UseErrorLevel
        }
        Hotkey, %keyForInfo%, Off, UseErrorLevel
    }
    if (keyForKoap != "") {
        keyForKoapFormatted := ConvertKeyForHotkey(keyForKoap)
        if (keyForKoapFormatted != "") {
            Hotkey, %keyForKoapFormatted%, Off, UseErrorLevel
        }
        Hotkey, %keyForKoap%, Off, UseErrorLevel
    }
    if (keyForUK != "") {
        keyForUKFormatted := ConvertKeyForHotkey(keyForUK)
        if (keyForUKFormatted != "") {
            Hotkey, %keyForUKFormatted%, Off, UseErrorLevel
        }
        Hotkey, %keyForUK%, Off, UseErrorLevel
    }
    if (keyForScreenshot != "") {
        keyForScreenshotFormatted := ConvertKeyForHotkey(keyForScreenshot)
        if (keyForScreenshotFormatted != "") {
            Hotkey, %keyForScreenshotFormatted%, Off, UseErrorLevel
        }
        Hotkey, %keyForScreenshot%, Off, UseErrorLevel
    }
    if (keyForBadge != "") {
        keyForBadgeFormatted := ConvertKeyForHotkey(keyForBadge)
        if (keyForBadgeFormatted != "") {
            Hotkey, %keyForBadgeFormatted%, Off, UseErrorLevel
        }
        Hotkey, %keyForBadge%, Off, UseErrorLevel
    }
    if (keyForPresentation != "") {
        keyForPresentationFormatted := ConvertKeyForHotkey(keyForPresentation)
        if (keyForPresentationFormatted != "") {
            Hotkey, %keyForPresentationFormatted%, Off, UseErrorLevel
        }
        Hotkey, %keyForPresentation%, Off, UseErrorLevel
    }
}

EnableAllHotkeys() {
    SetupDynamicHotkeys()
    SetupAutoLayoutHotkeys()
}

SetupDynamicHotkeys() {
    global keyForInfo, keyForKoap, keyForUK, keyForScreenshot, keyForBadge, keyForPresentation, keyForSettings
    global enabledInfo, enabledKoap, enabledUK, enabledScreenshot, enabledBadge, enabledPresentation

    if (keyForSettings != "") {
        keyForSettingsFormatted := ConvertKeyForHotkey(keyForSettings)
        if (keyForSettingsFormatted != "") {
            Hotkey, %keyForSettingsFormatted%, OpenSettingsWindow, On, UseErrorLevel
            if (ErrorLevel != 0) {
                Hotkey, %keyForSettings%, OpenSettingsWindow, On, UseErrorLevel
            }
        } else {
            Hotkey, %keyForSettings%, OpenSettingsWindow, On, UseErrorLevel
        }
    }

    if (keyForInfo != "" && enabledInfo = 1) {
        keyForInfoFormatted := ConvertKeyForHotkey(keyForInfo)
        if (keyForInfoFormatted != "") {
            Hotkey, %keyForInfoFormatted%, OpenInfoWindow, On, UseErrorLevel
            if (ErrorLevel != 0) {
                Hotkey, %keyForInfo%, OpenInfoWindow, On, UseErrorLevel
            }
        } else {
            Hotkey, %keyForInfo%, OpenInfoWindow, On, UseErrorLevel
        }
    }
    if (keyForKoap != "" && enabledKoap = 1) {
        keyForKoapFormatted := ConvertKeyForHotkey(keyForKoap)
        if (keyForKoapFormatted != "") {
            Hotkey, %keyForKoapFormatted%, OpenKoapWindow, On, UseErrorLevel
            if (ErrorLevel != 0) {
                Hotkey, %keyForKoap%, OpenKoapWindow, On, UseErrorLevel
            }
        } else {
            Hotkey, %keyForKoap%, OpenKoapWindow, On, UseErrorLevel
        }
    }
    if (keyForUK != "" && enabledUK = 1) {
        keyForUKFormatted := ConvertKeyForHotkey(keyForUK)
        if (keyForUKFormatted != "") {
            Hotkey, %keyForUKFormatted%, OpenUKWindow, On, UseErrorLevel
            if (ErrorLevel != 0) {
                Hotkey, %keyForUK%, OpenUKWindow, On, UseErrorLevel
            }
        } else {
            Hotkey, %keyForUK%, OpenUKWindow, On, UseErrorLevel
        }
    }
    if (keyForScreenshot != "" && enabledScreenshot = 1) {
        keyForScreenshotFormatted := ConvertKeyForHotkey(keyForScreenshot)
        if (keyForScreenshotFormatted != "") {
            Hotkey, %keyForScreenshotFormatted%, OpenScreenshotWindow, On, UseErrorLevel
            if (ErrorLevel != 0) {
                Hotkey, %keyForScreenshot%, OpenScreenshotWindow, On, UseErrorLevel
            }
        } else {
            Hotkey, %keyForScreenshot%, OpenScreenshotWindow, On, UseErrorLevel
        }
    }
    if (keyForBadge != "" && enabledBadge = 1) {
        keyForBadgeFormatted := ConvertKeyForHotkey(keyForBadge)
        if (keyForBadgeFormatted != "") {
            Hotkey, %keyForBadgeFormatted%, SendBadgeNumber, On, UseErrorLevel
            if (ErrorLevel != 0) {
                Hotkey, %keyForBadge%, SendBadgeNumber, On, UseErrorLevel
            }
        } else {
            Hotkey, %keyForBadge%, SendBadgeNumber, On, UseErrorLevel
        }
    }
    if (keyForPresentation != "" && enabledPresentation = 1) {
        keyForPresentationFormatted := ConvertKeyForHotkey(keyForPresentation)
        if (keyForPresentationFormatted != "") {
            Hotkey, %keyForPresentationFormatted%, SendPresentation, On, UseErrorLevel
            if (ErrorLevel != 0) {
                Hotkey, %keyForPresentation%, SendPresentation, On, UseErrorLevel
            }
        } else {
            Hotkey, %keyForPresentation%, SendPresentation, On, UseErrorLevel
        }
    }
}

ConvertKeyForHotkey(key) {
    if (key = "") {
        return ""
    }
    
    if (!InStr(key, " & ")) {
        return key
    }
    
    StringSplit, parts, key, &, %A_Space%
    if (parts0 < 2) {
        return key
    }
    
    modifierCount := parts0 - 1
    
    if (modifierCount = 1) {
        return key
    }
    
    shiftMod := ""
    controlMod := ""
    altMod := ""
    winMod := ""
    mainKey := parts%parts0%
    
    Loop, %parts0%
    {
        if (A_Index < parts0) {
            mod := parts%A_Index%
            if (mod = "LShift") {
                shiftMod := "<+"
            } else if (mod = "RShift") {
                shiftMod := ">+"
            } else if (InStr(mod, "Shift")) {
                shiftMod := "+"
            } else if (mod = "LControl") {
                controlMod := "<^"
            } else if (mod = "RControl") {
                controlMod := ">^"
            } else if (InStr(mod, "Control")) {
                controlMod := "^"
            } else if (mod = "LAlt") {
                altMod := "<!"
            } else if (mod = "RAlt") {
                altMod := ">!"
            } else if (InStr(mod, "Alt")) {
                altMod := "!"
            } else if (mod = "LWin") {
                winMod := "<#"
            } else if (mod = "RWin") {
                winMod := ">#"
            } else if (InStr(mod, "Win")) {
                winMod := "#"
            }
        }
    }
    
    modifiers := shiftMod . controlMod . altMod . winMod
    
    return modifiers . mainKey
}

OpenInfoWindow:
    global keyForInfo, isOpen, currentWindow, isClickThrough, tempScreenshotPath, enabledInfo, isCreatingWindow
    global windowActivationMode
    WriteLog("OpenInfoWindow вызван")
    if (enabledInfo != 1) {
        WriteLog("OpenInfoWindow: функция отключена")
        return
    }
    SetTimer, CheckFocus, Off

    IfWinExist, Управление скриптом
    {
        ClearAllTemporaryHotkeys()
        Gui, KeyRemapSettings:Destroy
        EnableAllHotkeys()
    }

    IfWinExist, Выбор папки
    {
        if (tempScreenshotPath != "" && FileExist(tempScreenshotPath)) {
            FileDelete, %tempScreenshotPath%
        }
        tempScreenshotPath := ""
        Gui, ScreenshotMenu:Destroy
    }

    if (isOpen && currentWindow = "info") {
        if (windowActivationMode = 2) {
            SaveSearchText(currentWindow)
            Gui, +LastFound
            GuiID := WinExist()
            SaveWindowPos()
            Gui, Hide
            isOpen := false
            currentWindow := ""
            isClickThrough := true
            isCreatingWindow := false
            return
        }
        if (isClickThrough) {
            Gui, +LastFound
            GuiID := WinExist()
            SetClickThrough(false)
            WinActivate, ahk_id %GuiID%
            GuiControl, Focus, SearchBox
            SetTimer, CheckFocus, 100
            return
        } else {
            SaveSearchText(currentWindow)
            Gui, +LastFound
            GuiID := WinExist()
            SaveWindowPos()
            Gui, Hide
            isOpen := false
            currentWindow := ""
            isClickThrough := true
            isCreatingWindow := false
            return
        }
    }

    if (isOpen) {
        SaveSearchText(currentWindow)
        if (currentWindow = "koap" || currentWindow = "uk") {
            UpdateInfoWindowContent()
            return
        }
        Gui, +LastFound
        GuiID := WinExist()
        SaveWindowPos()
        Gui, Destroy
        isOpen := false
        currentWindow := ""
    }

    Gosub, CreateInfoWindow
    WriteLog("OpenInfoWindow: окно создано")
return

OpenKoapWindow:
    global keyForKoap, isOpen, currentWindow, isClickThrough, tempScreenshotPath, enabledKoap, isCreatingWindow
    global windowActivationMode
    WriteLog("OpenKoapWindow вызван")
    if (enabledKoap != 1) {
        WriteLog("OpenKoapWindow: функция отключена")
        return
    }
    SetTimer, CheckFocus, Off

    IfWinExist, Управление скриптом
    {
        ClearAllTemporaryHotkeys()
        Gui, KeyRemapSettings:Destroy
        EnableAllHotkeys()
    }

    IfWinExist, Выбор папки
    {
        if (tempScreenshotPath != "" && FileExist(tempScreenshotPath)) {
            FileDelete, %tempScreenshotPath%
        }
        tempScreenshotPath := ""
        Gui, ScreenshotMenu:Destroy
    }

    if (isOpen && currentWindow = "koap") {
        if (windowActivationMode = 2) {
            SaveSearchText(currentWindow)
            Gui, +LastFound
            GuiID := WinExist()
            SaveWindowPos()
            Gui, Hide
            isOpen := false
            currentWindow := ""
            isClickThrough := true
            isCreatingWindow := false
            return
        }
        if (isClickThrough) {
            Gui, +LastFound
            GuiID := WinExist()
            SetClickThrough(false)
            WinActivate, ahk_id %GuiID%
            GuiControl, Focus, SearchBox
            SetTimer, CheckFocus, 100
            return
        } else {
            SaveSearchText(currentWindow)
            Gui, +LastFound
            GuiID := WinExist()
            SaveWindowPos()
            Gui, Hide
            isOpen := false
            currentWindow := ""
            isClickThrough := true
            isCreatingWindow := false
            return
        }
    }

    if (isOpen) {
        SaveSearchText(currentWindow)
        if (currentWindow = "uk") {
            UpdateLawWindowContent("koap")
            return
        }
        if (currentWindow = "info") {
            UpdateLawWindowContent("koap")
            return
        }
        Gui, +LastFound
        GuiID := WinExist()
        SaveWindowPos()
        Gui, Destroy
        isOpen := false
        currentWindow := ""
    }

    Gosub, CreateKoapWindow
    WriteLog("OpenKoapWindow: окно создано")
return

OpenUKWindow:
    global keyForUK, isOpen, currentWindow, isClickThrough, tempScreenshotPath, enabledUK, isCreatingWindow
    global windowActivationMode
    WriteLog("OpenUKWindow вызван")
    if (enabledUK != 1) {
        WriteLog("OpenUKWindow: функция отключена")
        return
    }
    SetTimer, CheckFocus, Off

    IfWinExist, Управление скриптом
    {
        ClearAllTemporaryHotkeys()
        Gui, KeyRemapSettings:Destroy
        EnableAllHotkeys()
    }

    IfWinExist, Выбор папки
    {
        if (tempScreenshotPath != "" && FileExist(tempScreenshotPath)) {
            FileDelete, %tempScreenshotPath%
        }
        tempScreenshotPath := ""
        Gui, ScreenshotMenu:Destroy
    }

    if (isOpen && currentWindow = "uk") {
        if (windowActivationMode = 2) {
            SaveSearchText(currentWindow)
            Gui, +LastFound
            GuiID := WinExist()
            SaveWindowPos()
            Gui, Hide
            isOpen := false
            currentWindow := ""
            isClickThrough := true
            isCreatingWindow := false
            return
        }
        if (isClickThrough) {
            Gui, +LastFound
            GuiID := WinExist()
            SetClickThrough(false)
            WinActivate, ahk_id %GuiID%
            GuiControl, Focus, SearchBox
            SetTimer, CheckFocus, 100
            return
        } else {
            SaveSearchText(currentWindow)
            Gui, +LastFound
            GuiID := WinExist()
            SaveWindowPos()
            Gui, Hide
            isOpen := false
            currentWindow := ""
            isClickThrough := true
            isCreatingWindow := false
            return
        }
    }

    if (isOpen) {
        SaveSearchText(currentWindow)
        if (currentWindow = "koap") {
            UpdateLawWindowContent("uk")
            return
        }
        if (currentWindow = "info") {
            UpdateLawWindowContent("uk")
            return
        }
        Gui, +LastFound
        GuiID := WinExist()
        SaveWindowPos()
        Gui, Destroy
        isOpen := false
        currentWindow := ""
    }

    Gosub, CreateUKWindow
    WriteLog("OpenUKWindow: окно создано")
return

OpenScreenshotWindow:
    global keyForScreenshot, isOpen, currentWindow, isClickThrough, tempScreenshotPath, enabledScreenshot
    WriteLog("OpenScreenshotWindow: открытие окна скриншотов")
    if (enabledScreenshot != 1) {
        WriteLog("OpenScreenshotWindow: функция отключена")
        return
    }

    IfWinExist, Управление скриптом
    {
        ClearAllTemporaryHotkeys()
        Gui, KeyRemapSettings:Destroy
        EnableAllHotkeys()
    }

    IfWinExist, Выбор папки
    {
        if (tempScreenshotPath != "" && FileExist(tempScreenshotPath)) {
            FileDelete, %tempScreenshotPath%
        }
        tempScreenshotPath := ""
        Gui, ScreenshotMenu:Destroy
        return
    }

    if (isOpen) {
        SaveSearchText(currentWindow)
        Gui, +LastFound
        GuiID := WinExist()
        SaveWindowPos()
        Gui, Hide
        isOpen := false
        currentWindow := ""
    }

    if (tempScreenshotPath != "" && FileExist(tempScreenshotPath)) {
        FileDelete, %tempScreenshotPath%
        tempScreenshotPath := ""
    }

    Gui, ScreenshotMenu:Destroy

    tempScreenshotPath := SaveTempScreenshot()

    if (tempScreenshotPath = "") {
        ToolTip, Ошибка создания скриншота
        SetTimer, RemoveToolTip, 2000
        return
    }

    ShowScreenshotMenu()
return

SendBadgeNumber:
    global badgeMessage, enabledBadge, badgeAutoSendGlobal
    if (enabledBadge != 1) {
        return
    }
    if (!WinActive("ahk_exe GTA5.exe")) {
        return
    }
    SendInput, {Ctrl Up}{Alt Up}{Shift Up}
    Sleep, 30

    messageToSend := badgeMessage
    if (SubStr(messageToSend, 0) != ".") {
        messageToSend := messageToSend . "."
    }
    SendInput, {T}
    Sleep, 120
    SendInput, ^a
    Sleep, 50
    oldClipboard := ClipboardAll
    Clipboard := "/do " . messageToSend
    ClipWait, 1
    SendInput, ^v
    Sleep, 50
    Clipboard := oldClipboard
    if (badgeAutoSendGlobal = 1) {
        Sleep, 50
        SendInput, {Enter}
    }
return

SendPresentation:
    global presentationMessage, enabledPresentation, presentationAutoSendGlobal
    if (enabledPresentation != 1) {
        return
    }
    if (!WinActive("ahk_exe GTA5.exe")) {
        return
    }
    SendInput, {Ctrl Up}{Alt Up}{Shift Up}
    Sleep, 30

    messageToSend := presentationMessage
    SendInput, {T}
    Sleep, 120
    SendInput, ^a
    Sleep, 50
    oldClipboard := ClipboardAll
    Clipboard := messageToSend
    ClipWait, 1
    SendInput, ^v
    Sleep, 50
    Clipboard := oldClipboard
    if (presentationAutoSendGlobal = 1) {
        Sleep, 50
        SendInput, {Enter}
    }
return

OpenSettingsWindow:
    global isOpen, currentWindow, tempScreenshotPath, isBlockingF3
    WriteLog("OpenSettingsWindow: открытие окна настроек")

    if (isBlockingF3) {
        return
    }

    IfWinExist, ahk_class AutoHotkeyGUI
    {
        if (isOpen) {
            SaveSearchText(currentWindow)
            Gui, +LastFound
            GuiID := WinExist()
            SaveWindowPos()
            Gui, Hide
            isOpen := false
            currentWindow := ""
        }
    }

    IfWinExist, Выбор папки
    {
        if (tempScreenshotPath != "" && FileExist(tempScreenshotPath)) {
            FileDelete, %tempScreenshotPath%
        }
        tempScreenshotPath := ""
        Gui, ScreenshotMenu:Destroy
    }

    IfWinExist, Управление скриптом
    {
        ClearAllTemporaryHotkeys()
        Gui, KeyRemapSettings:Destroy
        EnableAllHotkeys()
    }
    else
    {
        ShowKeyRemapSettings()
    }
return

ShowKeyRemapSettings() {
    global keyForInfo, keyForKoap, keyForUK, keyForScreenshot, badgeMessage, keyForBadge, presentationMessage, keyForPresentation, keyForSettings, isOpen, currentWindow, tempScreenshotPath
    global enabledInfo, enabledKoap, enabledUK, enabledScreenshot, enabledBadge, enabledPresentation
    global CaptureKeyInfo, CaptureKeyKoap, CaptureKeyUK, CaptureKeyScreenshot, CaptureKeyBadge, CaptureKeyPresentation, CaptureKeySettings
    global WindowActivationModeDDL

    global HeaderInfo, ToggleInfo, KeyInfo
    global HeaderKoap, ToggleKoap, KeyKoap
    global HeaderUK, ToggleUK, KeyUK
    global HeaderScreenshot, ToggleScreenshot, KeyScreenshot
    global HeaderBadge, ToggleBadge, KeyBadge
    global HeaderPresentation, TogglePresentation, KeyPresentation
    global HeaderSettings, KeySettings
    global MemoryInfoText, MemoryCheckTimeText

    IfWinExist, ahk_class AutoHotkeyGUI
    {
        if (isOpen) {
            SaveSearchText(currentWindow)
            Gui, +LastFound
            GuiID := WinExist()
            SaveWindowPos()
            Gui, Hide
            isOpen := false
            currentWindow := ""
        }
    }

    IfWinExist, Выбор папки
    {
        if (tempScreenshotPath != "" && FileExist(tempScreenshotPath)) {
            FileDelete, %tempScreenshotPath%
        }
        tempScreenshotPath := ""
        Gui, ScreenshotMenu:Destroy
    }

    ClearAllTemporaryHotkeys()
    EnableAllHotkeys()

    Gui, KeyRemapSettings:Destroy
    Gui, KeyRemapSettings:+AlwaysOnTop -MinimizeBox +Owner
    Gui, KeyRemapSettings:Font, s10, Consolas
    Gui, KeyRemapSettings:Color, 0a0a0a

    Gui, KeyRemapSettings:Font, s12 cYellow Bold, Consolas
    Gui, KeyRemapSettings:Add, Text, x10 y10 w480 Left, НАСТРОЙКИ СКРИПТА

    saveSearchVal := LoadIniValue("settings.SaveSearchHistory")
    if (saveSearchVal = "")
        saveSearchVal := 1
    Gui, KeyRemapSettings:Font, s9 cWhite, Consolas
    Gui, KeyRemapSettings:Add, CheckBox, x10 y40 w480 vSaveSearchChk Checked%saveSearchVal% -TabStop, Сохранять историю поиска при закрытии окна

    showInstrVal := LoadIniValue("settings.ShowInstructionOnStart")
    if (showInstrVal = "")
        showInstrVal := 1
    Gui, KeyRemapSettings:Add, CheckBox, x10 y65 w480 vShowInstructionChk Checked%showInstrVal% -TabStop, Показывать инструкцию при первом запуске

    autoUpdateVal := LoadIniValue("settings.AutoCheckUpdates")
    if (autoUpdateVal = "")
        autoUpdateVal := 1
    Gui, KeyRemapSettings:Add, CheckBox, x10 y90 w480 vAutoUpdateChk Checked%autoUpdateVal% -TabStop, Проверять обновления при запуске скрипта

    global enabledAutoLayout
    autoLayoutVal := enabledAutoLayout
    Gui, KeyRemapSettings:Add, CheckBox, x10 y115 w480 vAutoLayoutChk Checked%autoLayoutVal% -TabStop, Авто-раскладка RU при нажатии T в GTA 5

    devLogsVal := LoadIniValue("settings.DeveloperLogs")
    if (devLogsVal = "")
        devLogsVal := 0
    Gui, KeyRemapSettings:Add, CheckBox, x10 y140 w480 vDeveloperLogsChk Checked%devLogsVal% -TabStop, Режим developer logs (запись всех действий в logs.txt)

    autoMemoryCleanVal := LoadIniValue("settings.AutoMemoryClean")
    if (autoMemoryCleanVal = "")
        autoMemoryCleanVal := 1
    Gui, KeyRemapSettings:Add, CheckBox, x10 y165 w480 vAutoMemoryCleanChk Checked%autoMemoryCleanVal% -TabStop, Автоматическая проверка и очистка память каждые 5 минут

    frequentArticlesVal := LoadIniValue("settings.FrequentArticles")
    if (frequentArticlesVal = "")
        frequentArticlesVal := 1
    Gui, KeyRemapSettings:Add, CheckBox, x10 y190 w320 vFrequentArticlesChk Checked%frequentArticlesVal% -TabStop, Показывать часто используемые статьи
    Gui, KeyRemapSettings:Add, Button, x335 y188 w155 h22 gClearFrequentArticles -TabStop, Очистить список

    Gui, KeyRemapSettings:Font, s9 cWhite, Consolas
    Gui, KeyRemapSettings:Add, Text, x10 y220 w300 vMemoryCheckTimeText, Оперативная память
    Gui, KeyRemapSettings:Font, s9 cWhite, Consolas
    Gui, KeyRemapSettings:Add, Text, x10 y235 w300 vMemoryInfoText, Загрузка данных...
    Gui, KeyRemapSettings:Font, s9 cWhite, Consolas
    Gui, KeyRemapSettings:Add, Button, x335 y218 w155 h22 gManualMemoryClean -TabStop, Очистить память

    windowActivationModeVal := Trim(LoadIniValue("settings.WindowActivationMode"))
    if (windowActivationModeVal = "2") {
        windowActivationModeVal := 2
    } else {
        windowActivationModeVal := 1
    }
    Gui, KeyRemapSettings:Font, s9 cWhite, Consolas
    Gui, KeyRemapSettings:Add, Text, x10 y260 w480, Режим активации окон:
    selectedIndex := windowActivationModeVal
    Gui, KeyRemapSettings:Add, DropDownList, x10 y280 w480 vWindowActivationModeDDL Choose%selectedIndex% -TabStop, 3 нажатия (1 - открывает, 2 - активирует, 3 - закрывает)|2 нажатия (1 - открывает, 2 - закрывает)

    Gui, KeyRemapSettings:Font, s12 cYellow Bold, Consolas
    Gui, KeyRemapSettings:Add, Text, x10 y315 w480 Left, ПЕРЕНАЗНАЧЕНИЕ КЛАВИШ
    Gui, KeyRemapSettings:Font, s10 cWhite, Consolas

    Gui, KeyRemapSettings:Font, s10 cWhite Bold, Consolas
    Gui, KeyRemapSettings:Add, Text, x10 y350 w200 vHeaderSettings, Открыть настройки:

    Gui, KeyRemapSettings:Font, s10 cWhite Bold, Consolas
    displayKeySettings := FormatKeyForDisplay(keyForSettings)
    Gui, KeyRemapSettings:Add, Edit, x275 y348 w120 h25 vKeySettings ReadOnly -TabStop Center, %displayKeySettings%
    Gui, KeyRemapSettings:Add, Button, x400 y348 w90 h25 vCaptureKeySettings gCaptureKeySettings -TabStop, Назначить

    if (enabledInfo = 1) {
        headerColor := "c00FF00"
        toggleTxt := "ВКЛ"
        assignState := ""
    } else {
        headerColor := "cFF0000"
        toggleTxt := "ВЫКЛ"
        assignState := "Disabled"
    }

    Gui, KeyRemapSettings:Font, s10 c%headerColor% Bold, Consolas
    Gui, KeyRemapSettings:Add, Text, x10 y383 w200 vHeaderInfo, Полезная информация:

    Gui, KeyRemapSettings:Font, s10 cWhite Bold, Consolas
    Gui, KeyRemapSettings:Add, Button, x220 y381 w50 h25 gToggleEnabledInfo vToggleInfo -TabStop, %toggleTxt%
    displayKeyInfo := FormatKeyForDisplay(keyForInfo)
    Gui, KeyRemapSettings:Add, Edit, x275 y381 w120 h25 vKeyInfo ReadOnly -TabStop Center, %displayKeyInfo%
    Gui, KeyRemapSettings:Add, Button, % "x400 y381 w90 h25 vCaptureKeyInfo " assignState " gCaptureKeyInfo -TabStop", Назначить

    if (enabledKoap = 1) {
        headerColor := "c00FF00"
        toggleTxt := "ВКЛ"
        assignState := ""
    } else {
        headerColor := "cFF0000"
        toggleTxt := "ВЫКЛ"
        assignState := "Disabled"
    }

    Gui, KeyRemapSettings:Font, s10 c%headerColor% Bold, Consolas
    Gui, KeyRemapSettings:Add, Text, x10 y418 w200 vHeaderKoap, Открыть КоАП РФ:

    Gui, KeyRemapSettings:Font, s10 cWhite Bold, Consolas
    Gui, KeyRemapSettings:Add, Button, x220 y416 w50 h25 gToggleEnabledKoap vToggleKoap -TabStop, %toggleTxt%
    displayKeyKoap := FormatKeyForDisplay(keyForKoap)
    Gui, KeyRemapSettings:Add, Edit, x275 y416 w120 h25 vKeyKoap ReadOnly -TabStop Center, %displayKeyKoap%
    Gui, KeyRemapSettings:Add, Button, % "x400 y416 w90 h25 vCaptureKeyKoap " assignState " gCaptureKeyKoap -TabStop", Назначить

    if (enabledUK = 1) {
        headerColor := "c00FF00"
        toggleTxt := "ВКЛ"
        assignState := ""
    } else {
        headerColor := "cFF0000"
        toggleTxt := "ВЫКЛ"
        assignState := "Disabled"
    }

    Gui, KeyRemapSettings:Font, s10 c%headerColor% Bold, Consolas
    Gui, KeyRemapSettings:Add, Text, x10 y453 w200 vHeaderUK, Открыть УК РФ:

    Gui, KeyRemapSettings:Font, s10 cWhite Bold, Consolas
    Gui, KeyRemapSettings:Add, Button, x220 y451 w50 h25 gToggleEnabledUK vToggleUK -TabStop, %toggleTxt%
    displayKeyUK := FormatKeyForDisplay(keyForUK)
    Gui, KeyRemapSettings:Add, Edit, x275 y451 w120 h25 vKeyUK ReadOnly -TabStop Center, %displayKeyUK%
    Gui, KeyRemapSettings:Add, Button, % "x400 y451 w90 h25 vCaptureKeyUK " assignState " gCaptureKeyUK -TabStop", Назначить

    if (enabledScreenshot = 1) {
        headerColor := "c00FF00"
        toggleTxt := "ВКЛ"
        assignState := ""
    } else {
        headerColor := "cFF0000"
        toggleTxt := "ВЫКЛ"
        assignState := "Disabled"
    }

    Gui, KeyRemapSettings:Font, s10 c%headerColor% Bold, Consolas
    Gui, KeyRemapSettings:Add, Text, x10 y488 w200 vHeaderScreenshot, Сделать скриншот:

    Gui, KeyRemapSettings:Font, s10 cWhite Bold, Consolas
    Gui, KeyRemapSettings:Add, Button, x220 y486 w50 h25 gToggleEnabledScreenshot vToggleScreenshot -TabStop, %toggleTxt%
    displayKeyScreenshot := FormatKeyForDisplay(keyForScreenshot)
    Gui, KeyRemapSettings:Add, Edit, x275 y486 w120 h25 vKeyScreenshot ReadOnly -TabStop Center, %displayKeyScreenshot%
    Gui, KeyRemapSettings:Add, Button, % "x400 y486 w90 h25 vCaptureKeyScreenshot " assignState " gCaptureKeyScreenshot -TabStop", Назначить

    Gui, KeyRemapSettings:Font, s10 cWhite, Consolas
    Gui, KeyRemapSettings:Add, Edit, x10 y521 w480 h25 vBadgeMessage cBlack -TabStop, %badgeMessage%

    if (enabledBadge = 1) {
        headerColor := "c00FF00"
        toggleTxt := "ВКЛ"
        assignState := ""
    } else {
        headerColor := "cFF0000"
        toggleTxt := "ВЫКЛ"
        assignState := "Disabled"
    }

    Gui, KeyRemapSettings:Font, s10 c%headerColor% Bold, Consolas
    Gui, KeyRemapSettings:Add, Text, x10 y553 w200 vHeaderBadge, Отправить отыгровку жетона:

    Gui, KeyRemapSettings:Font, s10 cWhite Bold, Consolas
    Gui, KeyRemapSettings:Add, Button, x220 y551 w50 h25 gToggleEnabledBadge vToggleBadge -TabStop, %toggleTxt%
    displayKeyBadge := FormatKeyForDisplay(keyForBadge)
    Gui, KeyRemapSettings:Add, Edit, x275 y551 w120 h25 vKeyBadge ReadOnly -TabStop Center, %displayKeyBadge%
    Gui, KeyRemapSettings:Add, Button, % "x400 y551 w90 h25 vCaptureKeyBadge " assignState " gCaptureKeyBadge -TabStop", Назначить

    badgeAutoSendVal := LoadIniValue("badge.AutoSend")
    if (badgeAutoSendVal = "")
        badgeAutoSendVal := 0
    Gui, KeyRemapSettings:Font, s9 cWhite, Consolas
    Gui, KeyRemapSettings:Add, CheckBox, x10 y583 w480 Right vBadgeAutoSendChk Checked%badgeAutoSendVal% -TabStop, Отправить сразу без кнопки Enter (жетон)

    Gui, KeyRemapSettings:Font, s10 cWhite, Consolas
    Gui, KeyRemapSettings:Add, Edit, x10 y613 w480 h25 vPresentationMessage cBlack -TabStop, %presentationMessage%

    if (enabledPresentation = 1) {
        headerColor := "c00FF00"
        toggleTxt := "ВКЛ"
        assignState := ""
    } else {
        headerColor := "cFF0000"
        toggleTxt := "ВЫКЛ"
        assignState := "Disabled"
    }

    Gui, KeyRemapSettings:Font, s10 c%headerColor% Bold, Consolas
    Gui, KeyRemapSettings:Add, Text, x10 y645 w200 vHeaderPresentation, Отправить представление:

    Gui, KeyRemapSettings:Font, s10 cWhite Bold, Consolas
    Gui, KeyRemapSettings:Add, Button, x220 y643 w50 h25 gToggleEnabledPresentation vTogglePresentation -TabStop, %toggleTxt%
    displayKeyPresentation := FormatKeyForDisplay(keyForPresentation)
    Gui, KeyRemapSettings:Add, Edit, x275 y643 w120 h25 vKeyPresentation ReadOnly -TabStop Center, %displayKeyPresentation%
    Gui, KeyRemapSettings:Add, Button, % "x400 y643 w90 h25 vCaptureKeyPresentation " assignState " gCaptureKeyPresentation -TabStop", Назначить

    presentationAutoSendVal := LoadIniValue("presentation.AutoSend")
    if (presentationAutoSendVal = "")
        presentationAutoSendVal := 0
    Gui, KeyRemapSettings:Font, s9 cWhite, Consolas
    Gui, KeyRemapSettings:Add, CheckBox, x10 y675 w480 Right vPresentationAutoSendChk Checked%presentationAutoSendVal% -TabStop, Отправить сразу без кнопки Enter (представление)

    Gui, KeyRemapSettings:Font, s10 cYellow, Consolas
    Gui, KeyRemapSettings:Add, Text, x10 y702 w450, Нажмите кнопку «Назначить» и затем нажмите нужную клавишу или комбинацию (например: F8, Alt+1, Ctrl+F5, Shift+Ctrl+G)

    Gui, KeyRemapSettings:Add, Button, x10 y752 w120 h30 gSaveKeyRemap -TabStop, Сохранить
    Gui, KeyRemapSettings:Add, Button, x140 y752 w120 h30 gCloseKeyRemapSettings -TabStop, Отмена
    Gui, KeyRemapSettings:Add, Button, x270 y752 w220 h30 gResetKeyRemapDefaults -TabStop, Вернуть стандартные

    SysGet, MonitorPrimary, MonitorPrimary
    SysGet, Monitor, Monitor, %MonitorPrimary%
    screenWidth  := MonitorRight - MonitorLeft
    screenHeight := MonitorBottom - MonitorTop
    guiWidth := 500
    guiHeight := 800
    xPos := MonitorLeft + (screenWidth - guiWidth) / 2
    yPos := MonitorTop  + (screenHeight - guiHeight) / 2

    global lastMemoryCheckTime
    if (lastMemoryCheckTime = 0) {
        lastMemoryCheckTime := A_TickCount
    }
    SetTimer, UpdateMemoryCheckTime, 1000
    SetTimer, UpdateMemoryInfoFrequent, 5000
    Gui, KeyRemapSettings:Show, x%xPos% y%yPos% w%guiWidth% h%guiHeight% NA, Управление скриптом
    Sleep, 50
    WinActivate, Управление скриптом
    
    SetTimer, LoadMemoryDataOnOpen, -100
}

LoadMemoryDataOnOpen:
    memInfo := GetMemoryInfo()
    memLevelColor := memInfo.levelColor
    Gui, KeyRemapSettings:Font, s9 c%memLevelColor%, Consolas
    GuiControl, KeyRemapSettings:Font, MemoryInfoText
    memText := "Занято: " . memInfo.used . " МБ / Доступно: " . memInfo.available . " МБ (" . memInfo.usedPercent . "%)"
    GuiControl, KeyRemapSettings:, MemoryInfoText, %memText%
    
    autoMemoryCleanVal := LoadIniValue("settings.AutoMemoryClean")
    if (autoMemoryCleanVal = "")
        autoMemoryCleanVal := 1
    
    if (autoMemoryCleanVal = 1) {
        global lastMemoryCheckTime
        if (lastMemoryCheckTime = 0) {
            lastMemoryCheckTime := A_TickCount
        }
        timeUntilNextCheck := 300000 - (A_TickCount - lastMemoryCheckTime)
        if (timeUntilNextCheck < 0) {
            timeUntilNextCheck := 0
        }
        minutes := Floor(timeUntilNextCheck / 60000)
        seconds := Floor((timeUntilNextCheck - (minutes * 60000)) / 1000)
        timeText := "Оперативная память (проверка через " . minutes . ":" . Format("{:02d}", seconds) . ")"
    } else {
        timeText := "Оперативная память"
    }
    GuiControl, KeyRemapSettings:, MemoryCheckTimeText, %timeText%
return

CaptureKeySettings:
    global keyForSettings
    capturedKey := CaptureKey("KeySettings")
    if (capturedKey != "") {
        displayKey := FormatKeyForDisplay(capturedKey)
        
        GuiControlGet, currentInfo,, KeyInfo
        GuiControlGet, currentKoap,, KeyKoap
        GuiControlGet, currentUK,, KeyUK
        GuiControlGet, currentScreenshot,, KeyScreenshot
        GuiControlGet, currentBadge,, KeyBadge
        GuiControlGet, currentPresentation,, KeyPresentation
        
        currentInfoAHK := FormatKeyForStorage(currentInfo)
        currentKoapAHK := FormatKeyForStorage(currentKoap)
        currentUKAHK := FormatKeyForStorage(currentUK)
        currentScreenshotAHK := FormatKeyForStorage(currentScreenshot)
        currentBadgeAHK := FormatKeyForStorage(currentBadge)
        currentPresentationAHK := FormatKeyForStorage(currentPresentation)

        if (capturedKey = currentInfoAHK || capturedKey = currentKoapAHK || capturedKey = currentUKAHK || capturedKey = currentScreenshotAHK || capturedKey = currentBadgeAHK || capturedKey = currentPresentationAHK) {
            Gui, KeyRemapSettings:+OwnDialogs
            MsgBox, 48, Ошибка, Клавиша "%displayKey%" уже используется другой функцией!`nПожалуйста, выберите другую клавишу.
            return
        }

        GuiControl,, KeySettings, %displayKey%
    }
return

CaptureKeyInfo:
    global keyForSettings
    capturedKey := CaptureKey("KeyInfo")
    if (capturedKey != "") {
        displayKey := FormatKeyForDisplay(capturedKey)
        
        GuiControlGet, currentSettings,, KeySettings
        GuiControlGet, currentKoap,, KeyKoap
        GuiControlGet, currentUK,, KeyUK
        GuiControlGet, currentScreenshot,, KeyScreenshot
        GuiControlGet, currentBadge,, KeyBadge
        GuiControlGet, currentPresentation,, KeyPresentation
        
        currentSettingsAHK := FormatKeyForStorage(currentSettings)
        currentKoapAHK := FormatKeyForStorage(currentKoap)
        currentUKAHK := FormatKeyForStorage(currentUK)
        currentScreenshotAHK := FormatKeyForStorage(currentScreenshot)
        currentBadgeAHK := FormatKeyForStorage(currentBadge)
        currentPresentationAHK := FormatKeyForStorage(currentPresentation)

        if (capturedKey = currentSettingsAHK || capturedKey = currentKoapAHK || capturedKey = currentUKAHK || capturedKey = currentScreenshotAHK || capturedKey = currentBadgeAHK || capturedKey = currentPresentationAHK) {
            Gui, KeyRemapSettings:+OwnDialogs
            MsgBox, 48, Ошибка, Клавиша "%displayKey%" уже используется другой функцией!`nПожалуйста, выберите другую клавишу.
            return
        }

        GuiControl,, KeyInfo, %displayKey%
    }
return

CaptureKeyKoap:
    global keyForSettings
    capturedKey := CaptureKey("KeyKoap")
    if (capturedKey != "") {
        displayKey := FormatKeyForDisplay(capturedKey)
        
        GuiControlGet, currentSettings,, KeySettings
        GuiControlGet, currentInfo,, KeyInfo
        GuiControlGet, currentUK,, KeyUK
        GuiControlGet, currentScreenshot,, KeyScreenshot
        GuiControlGet, currentBadge,, KeyBadge
        GuiControlGet, currentPresentation,, KeyPresentation
        
        currentSettingsAHK := FormatKeyForStorage(currentSettings)
        currentInfoAHK := FormatKeyForStorage(currentInfo)
        currentUKAHK := FormatKeyForStorage(currentUK)
        currentScreenshotAHK := FormatKeyForStorage(currentScreenshot)
        currentBadgeAHK := FormatKeyForStorage(currentBadge)
        currentPresentationAHK := FormatKeyForStorage(currentPresentation)

        if (capturedKey = currentSettingsAHK || capturedKey = currentInfoAHK || capturedKey = currentUKAHK || capturedKey = currentScreenshotAHK || capturedKey = currentBadgeAHK || capturedKey = currentPresentationAHK) {
            Gui, KeyRemapSettings:+OwnDialogs
            MsgBox, 48, Ошибка, Клавиша "%displayKey%" уже используется другой функцией!`nПожалуйста, выберите другую клавишу.
            return
        }

        GuiControl,, KeyKoap, %displayKey%
    }
return

CaptureKeyUK:
    global keyForSettings
    capturedKey := CaptureKey("KeyUK")
    if (capturedKey != "") {
        displayKey := FormatKeyForDisplay(capturedKey)
        
        GuiControlGet, currentSettings,, KeySettings
        GuiControlGet, currentInfo,, KeyInfo
        GuiControlGet, currentKoap,, KeyKoap
        GuiControlGet, currentScreenshot,, KeyScreenshot
        GuiControlGet, currentBadge,, KeyBadge
        GuiControlGet, currentPresentation,, KeyPresentation
        
        currentSettingsAHK := FormatKeyForStorage(currentSettings)
        currentInfoAHK := FormatKeyForStorage(currentInfo)
        currentKoapAHK := FormatKeyForStorage(currentKoap)
        currentScreenshotAHK := FormatKeyForStorage(currentScreenshot)
        currentBadgeAHK := FormatKeyForStorage(currentBadge)
        currentPresentationAHK := FormatKeyForStorage(currentPresentation)

        if (capturedKey = currentSettingsAHK || capturedKey = currentInfoAHK || capturedKey = currentKoapAHK || capturedKey = currentScreenshotAHK || capturedKey = currentBadgeAHK || capturedKey = currentPresentationAHK) {
            Gui, KeyRemapSettings:+OwnDialogs
            MsgBox, 48, Ошибка, Клавиша "%displayKey%" уже используется другой функцией!`nПожалуйста, выберите другую клавишу.
            return
        }

        GuiControl,, KeyUK, %displayKey%
    }
return

CaptureKeyScreenshot:
    global keyForSettings
    capturedKey := CaptureKey("KeyScreenshot")
    if (capturedKey != "") {
        displayKey := FormatKeyForDisplay(capturedKey)
        
        GuiControlGet, currentSettings,, KeySettings
        GuiControlGet, currentInfo,, KeyInfo
        GuiControlGet, currentKoap,, KeyKoap
        GuiControlGet, currentUK,, KeyUK
        GuiControlGet, currentBadge,, KeyBadge
        GuiControlGet, currentPresentation,, KeyPresentation
        
        currentSettingsAHK := FormatKeyForStorage(currentSettings)
        currentInfoAHK := FormatKeyForStorage(currentInfo)
        currentKoapAHK := FormatKeyForStorage(currentKoap)
        currentUKAHK := FormatKeyForStorage(currentUK)
        currentBadgeAHK := FormatKeyForStorage(currentBadge)
        currentPresentationAHK := FormatKeyForStorage(currentPresentation)

        if (capturedKey = currentSettingsAHK || capturedKey = currentInfoAHK || capturedKey = currentKoapAHK || capturedKey = currentUKAHK || capturedKey = currentBadgeAHK || capturedKey = currentPresentationAHK) {
            Gui, KeyRemapSettings:+OwnDialogs
            MsgBox, 48, Ошибка, Клавиша "%displayKey%" уже используется другой функцией!`nПожалуйста, выберите другую клавишу.
            return
        }

        GuiControl,, KeyScreenshot, %displayKey%
    }
return

CaptureKeyBadge:
    global keyForSettings
    capturedKey := CaptureKey("KeyBadge")
    if (capturedKey != "") {
        displayKey := FormatKeyForDisplay(capturedKey)
        
        GuiControlGet, currentSettings,, KeySettings
        GuiControlGet, currentInfo,, KeyInfo
        GuiControlGet, currentKoap,, KeyKoap
        GuiControlGet, currentUK,, KeyUK
        GuiControlGet, currentScreenshot,, KeyScreenshot
        GuiControlGet, currentPresentation,, KeyPresentation
        
        currentSettingsAHK := FormatKeyForStorage(currentSettings)
        currentInfoAHK := FormatKeyForStorage(currentInfo)
        currentKoapAHK := FormatKeyForStorage(currentKoap)
        currentUKAHK := FormatKeyForStorage(currentUK)
        currentScreenshotAHK := FormatKeyForStorage(currentScreenshot)
        currentPresentationAHK := FormatKeyForStorage(currentPresentation)

        if (capturedKey = currentSettingsAHK || capturedKey = currentInfoAHK || capturedKey = currentKoapAHK || capturedKey = currentUKAHK || capturedKey = currentScreenshotAHK || capturedKey = currentPresentationAHK) {
            Gui, KeyRemapSettings:+OwnDialogs
            MsgBox, 48, Ошибка, Клавиша "%displayKey%" уже используется другой функцией!`nПожалуйста, выберите другую клавишу.
            return
        }

        GuiControl,, KeyBadge, %displayKey%
    }
return

CaptureKeyPresentation:
    global keyForSettings
    capturedKey := CaptureKey("KeyPresentation")
    if (capturedKey != "") {
        displayKey := FormatKeyForDisplay(capturedKey)
        
        GuiControlGet, currentSettings,, KeySettings
        GuiControlGet, currentInfo,, KeyInfo
        GuiControlGet, currentKoap,, KeyKoap
        GuiControlGet, currentUK,, KeyUK
        GuiControlGet, currentScreenshot,, KeyScreenshot
        GuiControlGet, currentBadge,, KeyBadge
        
        currentSettingsAHK := FormatKeyForStorage(currentSettings)
        currentInfoAHK := FormatKeyForStorage(currentInfo)
        currentKoapAHK := FormatKeyForStorage(currentKoap)
        currentUKAHK := FormatKeyForStorage(currentUK)
        currentScreenshotAHK := FormatKeyForStorage(currentScreenshot)
        currentBadgeAHK := FormatKeyForStorage(currentBadge)

        if (capturedKey = currentSettingsAHK || capturedKey = currentInfoAHK || capturedKey = currentKoapAHK || capturedKey = currentUKAHK || capturedKey = currentScreenshotAHK || capturedKey = currentBadgeAHK) {
            Gui, KeyRemapSettings:+OwnDialogs
            MsgBox, 48, Ошибка, Клавиша "%displayKey%" уже используется другой функцией!`nПожалуйста, выберите другую клавишу.
            return
        }

        GuiControl,, KeyPresentation, %displayKey%
    }
return

CaptureKey(controlName) {
    global capturedKeyName
    Gui, KeyRemapSettings:+OwnDialogs

    DisableAllHotkeys()

    tooltipText := "Нажмите клавишу или комбинацию (Alt+1, Ctrl+C и т.п.)... (Esc для отмены)"
    ToolTip, %tooltipText%

    capturedKeyName := ""

    Hotkey, ~*LControl, CaptureKeyHandler, On, UseErrorLevel
    Hotkey, ~*RControl, CaptureKeyHandler, On, UseErrorLevel
    Hotkey, ~*LAlt, CaptureKeyHandler, On, UseErrorLevel
    Hotkey, ~*RAlt, CaptureKeyHandler, On, UseErrorLevel
    Hotkey, ~*LShift, CaptureKeyHandler, On, UseErrorLevel
    Hotkey, ~*RShift, CaptureKeyHandler, On, UseErrorLevel
    Hotkey, ~*LWin, CaptureKeyHandler, On, UseErrorLevel
    Hotkey, ~*RWin, CaptureKeyHandler, On, UseErrorLevel

    Loop, 26
    {
        char := Chr(Asc("A") + A_Index - 1)
        Hotkey, %char%, CaptureKeyHandler, On, UseErrorLevel
        StringLower, charLower, char
        Hotkey, %charLower%, CaptureKeyHandler, On, UseErrorLevel
    }

    Loop, 10
    {
        num := A_Index - 1
        Hotkey, %num%, CaptureKeyHandler, On, UseErrorLevel
    }

    specialKeys := "F1|F2|F3|F4|F5|F6|F7|F8|F9|F10|F11|F12|Left|Right|Up|Down|Home|End|PgUp|PgDn|Del|Ins|NumLock|PrintScreen|Pause|LControl|RControl|LAlt|RAlt|LShift|RShift|LWin|RWin|AppsKey|Numpad0|Numpad1|Numpad2|Numpad3|Numpad4|Numpad5|Numpad6|Numpad7|Numpad8|Numpad9|NumpadDot|NumpadDiv|NumpadMult|NumpadAdd|NumpadSub|NumpadEnter|NumpadIns|NumpadEnd|NumpadDown|NumpadPgDn|NumpadLeft|NumpadClear|NumpadRight|NumpadHome|NumpadUp|NumpadPgUp|NumpadDel|ScrollLock|Esc|`-|`=|``[|``]|`;|'|`,|`.|/|``|~|`+|`_|`{|`}|`\||`\||`:|`<|`>|`?|`!|`@|`#|`$|`%|`^|`&|`*|`(|`)|`"

    Loop, Parse, specialKeys, |
    {
        Hotkey, %A_LoopField%, CaptureKeyHandler, On, UseErrorLevel
    }

    startTime := A_TickCount
    while (capturedKeyName = "" && (A_TickCount - startTime) < 10000) {
        Sleep, 10
        if (capturedKeyName != "") {
            break
        }
    }

    Loop, 26
    {
        char := Chr(Asc("A") + A_Index - 1)
        Hotkey, %char%, CaptureKeyHandler, Off, UseErrorLevel
        StringLower, charLower, char
        Hotkey, %charLower%, CaptureKeyHandler, Off, UseErrorLevel
    }

    Loop, 10
    {
        num := A_Index - 1
        Hotkey, %num%, CaptureKeyHandler, Off, UseErrorLevel
    }

    Loop, Parse, specialKeys, |
    {
        Hotkey, %A_LoopField%, CaptureKeyHandler, Off, UseErrorLevel
    }

    Hotkey, ~*LControl, CaptureKeyHandler, Off, UseErrorLevel
    Hotkey, ~*RControl, CaptureKeyHandler, Off, UseErrorLevel
    Hotkey, ~*LAlt, CaptureKeyHandler, Off, UseErrorLevel
    Hotkey, ~*RAlt, CaptureKeyHandler, Off, UseErrorLevel
    Hotkey, ~*LShift, CaptureKeyHandler, Off, UseErrorLevel
    Hotkey, ~*RShift, CaptureKeyHandler, Off, UseErrorLevel
    Hotkey, ~*LWin, CaptureKeyHandler, Off, UseErrorLevel
    Hotkey, ~*RWin, CaptureKeyHandler, Off, UseErrorLevel

    ToolTip

    EnableAllHotkeys()

    if (capturedKeyName = "Esc" || capturedKeyName = "") {
        return ""
    }

    return capturedKeyName
}

ClearAllTemporaryHotkeys() {
    Loop, 26
    {
        char := Chr(Asc("A") + A_Index - 1)
        Hotkey, %char%, CaptureKeyHandler, Off, UseErrorLevel
        StringLower, charLower, char
        Hotkey, %charLower%, CaptureKeyHandler, Off, UseErrorLevel
    }

    Loop, 10
    {
        num := A_Index - 1
        Hotkey, %num%, CaptureKeyHandler, Off, UseErrorLevel
    }

    specialKeys := "F1|F2|F4|F5|F6|F7|F8|F9|F10|F11|F12|Left|Right|Up|Down|Home|End|PgUp|PgDn|Del|Ins|NumLock|PrintScreen|Pause|LControl|RControl|LAlt|RAlt|LShift|RShift|LWin|RWin|AppsKey|Numpad0|Numpad1|Numpad2|Numpad3|Numpad4|Numpad5|Numpad6|Numpad7|Numpad8|Numpad9|NumpadDot|NumpadDiv|NumpadMult|NumpadAdd|NumpadSub|NumpadEnter|NumpadIns|NumpadEnd|NumpadDown|NumpadPgDn|NumpadLeft|NumpadClear|NumpadRight|NumpadHome|NumpadUp|NumpadPgUp|NumpadDel|ScrollLock|Esc|`-|`=|``[|``]|`;|'|`,|`.|/|``|~|`+|`_|`{|`}|`\||`\||`:|`<|`>|`?|`!|`@|`#|`$|`%|`^|`&|`*|`(|`)|`"

    Loop, Parse, specialKeys, |
    {
        Hotkey, %A_LoopField%, CaptureKeyHandler, Off, UseErrorLevel
    }

    ToolTip
    Sleep, 50
}

CaptureKeyHandler:
    global capturedKeyName
    keyName := RegExReplace(A_ThisHotkey, "~", "")
    
    if (keyName = "LControl" || keyName = "RControl" || keyName = "LAlt" || keyName = "RAlt" || keyName = "LShift" || keyName = "RShift" || keyName = "LWin" || keyName = "RWin") {
        return
    }

    if (InStr(keyName, " & ")) {
        StringSplit, parts, keyName, &, %A_Space%
        if (parts0 >= 2) {
            modifierCount := parts0 - 1
            modifiersList := ""
            Loop, %parts0%
            {
                if (A_Index < parts0) {
                    if (modifiersList != "") {
                        modifiersList .= " & "
                    }
                    modifiersList .= parts%A_Index%
                }
            }
            mainKey := parts%parts0%
            
            if (RegExMatch(mainKey, "^[a-zA-Z]$")) {
                StringUpper, mainKey, mainKey
            }
            
            allModifiers := ""
            hasControl := false
            hasAlt := false
            hasShift := false
            hasWin := false
            
            if (GetKeyState("LControl", "P") || GetKeyState("RControl", "P")) {
                if (GetKeyState("LControl", "P")) {
                    allModifiers .= "LControl|"
                } else {
                    allModifiers .= "RControl|"
                }
                hasControl := true
            }
            if (GetKeyState("LAlt", "P") || GetKeyState("RAlt", "P")) {
                if (GetKeyState("LAlt", "P")) {
                    allModifiers .= "LAlt|"
                } else {
                    allModifiers .= "RAlt|"
                }
                hasAlt := true
            }
            if (GetKeyState("LShift", "P") || GetKeyState("RShift", "P")) {
                if (GetKeyState("LShift", "P")) {
                    allModifiers .= "LShift|"
                } else {
                    allModifiers .= "RShift|"
                }
                hasShift := true
            }
            if (GetKeyState("LWin", "P") || GetKeyState("RWin", "P")) {
                if (GetKeyState("LWin", "P")) {
                    allModifiers .= "LWin|"
                } else {
                    allModifiers .= "RWin|"
                }
                hasWin := true
            }
            
            allModifiers := RegExReplace(allModifiers, "\|$", "")
            StringSplit, allMods, allModifiers, |
            
            if (allMods0 > modifierCount && allMods0 <= 3) {
                modifiers := ""
                Loop, %allMods0%
                {
                    if (modifiers != "") {
                        modifiers .= " & "
                    }
                    modifiers .= allMods%A_Index%
                }
                
                capturedKeyName := modifiers . " & " . mainKey
                return
            }
            
            capturedKeyName := modifiersList . " & " . mainKey
            return
        }
    }
    
    hasModifier := RegExMatch(keyName, "^[\^!\+#]")
    
    if (hasModifier) {
        capturedKeyName := keyName
        return
    }
    
    modifiers := ""
    modifierCount := 0
    hasControl := false
    hasAlt := false
    hasShift := false
    hasWin := false
    
    if (GetKeyState("LControl", "P") || GetKeyState("RControl", "P")) {
        if (GetKeyState("LControl", "P")) {
            modifiers .= "LControl & "
        } else {
            modifiers .= "RControl & "
        }
        modifierCount++
        hasControl := true
    }
    if ((GetKeyState("LAlt", "P") || GetKeyState("RAlt", "P")) && modifierCount < 3) {
        if (GetKeyState("LAlt", "P")) {
            modifiers .= "LAlt & "
        } else {
            modifiers .= "RAlt & "
        }
        modifierCount++
        hasAlt := true
    }
    if ((GetKeyState("LShift", "P") || GetKeyState("RShift", "P")) && modifierCount < 3) {
        if (GetKeyState("LShift", "P")) {
            modifiers .= "LShift & "
        } else {
            modifiers .= "RShift & "
        }
        modifierCount++
        hasShift := true
    }
    if ((GetKeyState("LWin", "P") || GetKeyState("RWin", "P")) && modifierCount < 3) {
        if (GetKeyState("LWin", "P")) {
            modifiers .= "LWin & "
        } else {
            modifiers .= "RWin & "
        }
        modifierCount++
        hasWin := true
    }
    
    if (modifiers != "" && modifierCount <= 3) {
        if (RegExMatch(keyName, "^[a-zA-Z]$")) {
            StringUpper, keyName, keyName
        }
        modifiers := RegExReplace(modifiers, " & $", "")
        capturedKeyName := modifiers . " & " . keyName
        return
    }
    
    if (RegExMatch(keyName, "^[a-zA-Z]$")) {
        StringUpper, keyName, keyName
    }

    capturedKeyName := keyName
return

SaveKeyRemap:
    global keyForInfo, keyForKoap, keyForUK, keyForScreenshot, badgeMessage, keyForBadge, presentationMessage, keyForPresentation, keyForSettings
    global enabledInfo, enabledKoap, enabledUK, enabledScreenshot, enabledBadge, enabledPresentation
    global windowActivationMode
    WriteLog("SaveKeyRemap: начало сохранения настроек")
    Gui, KeyRemapSettings:Submit, NoHide

    newKeySettings := NormalizeKeyFormat(FormatKeyForStorage(KeySettings))
    newKeyInfo := NormalizeKeyFormat(FormatKeyForStorage(KeyInfo))
    newKeyKoap := NormalizeKeyFormat(FormatKeyForStorage(KeyKoap))
    newKeyUK := NormalizeKeyFormat(FormatKeyForStorage(KeyUK))
    newKeyScreenshot := NormalizeKeyFormat(FormatKeyForStorage(KeyScreenshot))
    newKeyBadge := NormalizeKeyFormat(FormatKeyForStorage(KeyBadge))
    newKeyPresentation := NormalizeKeyFormat(FormatKeyForStorage(KeyPresentation))
    newBadgeMessage := BadgeMessage
    newPresentationMessage := PresentationMessage
    newEnabledInfo := enabledInfo
    newEnabledKoap := enabledKoap
    newEnabledUK := enabledUK
    newEnabledScreenshot := enabledScreenshot
    newEnabledBadge := enabledBadge
    newEnabledPresentation := enabledPresentation

    displayKeySettings := KeySettings
    displayKeyInfo := KeyInfo
    displayKeyKoap := KeyKoap
    displayKeyUK := KeyUK
    displayKeyScreenshot := KeyScreenshot
    displayKeyBadge := KeyBadge
    displayKeyPresentation := KeyPresentation

    if (newKeySettings != "") {
        if (newKeySettings = newKeyInfo || newKeySettings = newKeyKoap || newKeySettings = newKeyUK || newKeySettings = newKeyScreenshot || newKeySettings = newKeyBadge || newKeySettings = newKeyPresentation) {
            Gui, KeyRemapSettings:+OwnDialogs
            MsgBox, 48, Ошибка, Клавиша "%displayKeySettings%" уже используется другой функцией!`nПожалуйста, выберите другую клавишу.
            return
        }
    }

    if (newKeyInfo != "") {
        if (newKeyInfo = newKeySettings || newKeyInfo = newKeyKoap || newKeyInfo = newKeyUK || newKeyInfo = newKeyScreenshot || newKeyInfo = newKeyBadge || newKeyInfo = newKeyPresentation) {
            Gui, KeyRemapSettings:+OwnDialogs
            MsgBox, 48, Ошибка, Клавиша "%displayKeyInfo%" уже используется другой функцией!`nПожалуйста, выберите другую клавишу.
            return
        }
    }

    if (newKeyKoap != "") {
        if (newKeyKoap = newKeySettings || newKeyKoap = newKeyInfo || newKeyKoap = newKeyUK || newKeyKoap = newKeyScreenshot || newKeyKoap = newKeyBadge || newKeyKoap = newKeyPresentation) {
            Gui, KeyRemapSettings:+OwnDialogs
            MsgBox, 48, Ошибка, Клавиша "%displayKeyKoap%" уже используется другой функцией!`nПожалуйста, выберите другую клавишу.
            return
        }
    }

    if (newKeyUK != "") {
        if (newKeyUK = newKeySettings || newKeyUK = newKeyInfo || newKeyUK = newKeyKoap || newKeyUK = newKeyScreenshot || newKeyUK = newKeyBadge || newKeyUK = newKeyPresentation) {
            Gui, KeyRemapSettings:+OwnDialogs
            MsgBox, 48, Ошибка, Клавиша "%displayKeyUK%" уже используется другой функцией!`nПожалуйста, выберите другую клавишу.
            return
        }
    }

    if (newKeyScreenshot != "") {
        if (newKeyScreenshot = newKeySettings || newKeyScreenshot = newKeyInfo || newKeyScreenshot = newKeyKoap || newKeyScreenshot = newKeyUK || newKeyScreenshot = newKeyBadge || newKeyScreenshot = newKeyPresentation) {
            Gui, KeyRemapSettings:+OwnDialogs
            MsgBox, 48, Ошибка, Клавиша "%displayKeyScreenshot%" уже используется другой функцией!`nПожалуйста, выберите другую клавишу.
            return
        }
    }

    if (newKeyBadge != "") {
        if (newKeyBadge = newKeySettings || newKeyBadge = newKeyInfo || newKeyBadge = newKeyKoap || newKeyBadge = newKeyUK || newKeyBadge = newKeyScreenshot || newKeyBadge = newKeyPresentation) {
            Gui, KeyRemapSettings:+OwnDialogs
            MsgBox, 48, Ошибка, Клавиша "%displayKeyBadge%" уже используется другой функцией!`nПожалуйста, выберите другую клавишу.
            return
        }
    }

    if (newKeyPresentation != "") {
        if (newKeyPresentation = newKeySettings || newKeyPresentation = newKeyInfo || newKeyPresentation = newKeyKoap || newKeyPresentation = newKeyUK || newKeyPresentation = newKeyScreenshot || newKeyPresentation = newKeyBadge) {
            Gui, KeyRemapSettings:+OwnDialogs
            MsgBox, 48, Ошибка, Клавиша "%displayKeyPresentation%" уже используется другой функцией!`nПожалуйста, выберите другую клавишу.
            return
        }
    }

    oldKeySettings := keyForSettings
    oldKeyInfo := keyForInfo
    oldKeyKoap := keyForKoap
    oldKeyUK := keyForUK
    oldKeyScreenshot := keyForScreenshot
    oldKeyBadge := keyForBadge
    oldKeyPresentation := keyForPresentation

    if (oldKeySettings != "" && oldKeySettings != newKeySettings) {
        oldKeySettingsFormatted := ConvertKeyForHotkey(oldKeySettings)
        if (oldKeySettingsFormatted != "") {
            Hotkey, %oldKeySettingsFormatted%, Off, UseErrorLevel
        }
        Hotkey, %oldKeySettings%, Off, UseErrorLevel
    }
    if (oldKeyInfo != "" && oldKeyInfo != newKeyInfo) {
        oldKeyInfoFormatted := ConvertKeyForHotkey(oldKeyInfo)
        if (oldKeyInfoFormatted != "") {
            Hotkey, %oldKeyInfoFormatted%, Off, UseErrorLevel
        }
        Hotkey, %oldKeyInfo%, Off, UseErrorLevel
    }
    if (oldKeyKoap != "" && oldKeyKoap != newKeyKoap) {
        oldKeyKoapFormatted := ConvertKeyForHotkey(oldKeyKoap)
        if (oldKeyKoapFormatted != "") {
            Hotkey, %oldKeyKoapFormatted%, Off, UseErrorLevel
        }
        Hotkey, %oldKeyKoap%, Off, UseErrorLevel
    }
    if (oldKeyUK != "" && oldKeyUK != newKeyUK) {
        oldKeyUKFormatted := ConvertKeyForHotkey(oldKeyUK)
        if (oldKeyUKFormatted != "") {
            Hotkey, %oldKeyUKFormatted%, Off, UseErrorLevel
        }
        Hotkey, %oldKeyUK%, Off, UseErrorLevel
    }
    if (oldKeyScreenshot != "" && oldKeyScreenshot != newKeyScreenshot) {
        oldKeyScreenshotFormatted := ConvertKeyForHotkey(oldKeyScreenshot)
        if (oldKeyScreenshotFormatted != "") {
            Hotkey, %oldKeyScreenshotFormatted%, Off, UseErrorLevel
        }
        Hotkey, %oldKeyScreenshot%, Off, UseErrorLevel
    }
    if (oldKeyBadge != "" && oldKeyBadge != newKeyBadge) {
        oldKeyBadgeFormatted := ConvertKeyForHotkey(oldKeyBadge)
        if (oldKeyBadgeFormatted != "") {
            Hotkey, %oldKeyBadgeFormatted%, Off, UseErrorLevel
        }
        Hotkey, %oldKeyBadge%, Off, UseErrorLevel
    }
    if (oldKeyPresentation != "" && oldKeyPresentation != newKeyPresentation) {
        oldKeyPresentationFormatted := ConvertKeyForHotkey(oldKeyPresentation)
        if (oldKeyPresentationFormatted != "") {
            Hotkey, %oldKeyPresentationFormatted%, Off, UseErrorLevel
        }
        Hotkey, %oldKeyPresentation%, Off, UseErrorLevel
    }

    keyForSettings := newKeySettings
    keyForInfo := newKeyInfo
    keyForKoap := newKeyKoap
    keyForUK := newKeyUK
    keyForScreenshot := newKeyScreenshot
    keyForBadge := newKeyBadge
    keyForPresentation := newKeyPresentation
    badgeMessage := newBadgeMessage
    presentationMessage := newPresentationMessage
    badgeAutoSendGlobal := BadgeAutoSendChk
    presentationAutoSendGlobal := PresentationAutoSendChk
    enabledInfo := newEnabledInfo
    enabledKoap := newEnabledKoap
    enabledUK := newEnabledUK
    enabledScreenshot := newEnabledScreenshot
    enabledBadge := newEnabledBadge
    enabledPresentation := newEnabledPresentation

    SaveIniValue("settings.SaveSearchHistory", SaveSearchChk)
    SaveIniValue("settings.ShowInstructionOnStart", ShowInstructionChk)
    SaveIniValue("settings.AutoCheckUpdates", AutoUpdateChk)
    
    global enabledAutoLayout
    enabledAutoLayout := AutoLayoutChk
    SaveIniValue("enabled.AutoLayout", AutoLayoutChk)
    SetupAutoLayoutHotkeys()
    
    SaveIniValue("settings.AutoMemoryClean", AutoMemoryCleanChk)
    SaveIniValue("settings.DeveloperLogs", DeveloperLogsChk)
    SaveIniValue("settings.FrequentArticles", FrequentArticlesChk)
    
    autoMemoryCleanEnabled := (AutoMemoryCleanChk = 1) ? 1 : 0
    if (autoMemoryCleanEnabled = 1) {
        SetTimer, AutoMemoryClean, 300000
        WriteLog("SaveKeyRemap: автоматическая очистка памяти включена, интервал: 5 минут")
    } else {
        SetTimer, AutoMemoryClean, Off
        WriteLog("SaveKeyRemap: автоматическая очистка памяти отключена")
    }

    GuiControlGet, windowActivationModeText, KeyRemapSettings:, WindowActivationModeDDL
    if (windowActivationModeText = "3 нажатия (1 - открывает, 2 - активирует, 3 - закрывает)") {
        windowActivationMode := 1
    } else if (windowActivationModeText = "2 нажатия (1 - открывает, 2 - закрывает)") {
        windowActivationMode := 2
    } else {
        windowActivationMode := 1
    }

    SaveKeyRemapSettings()
    WriteLog("SaveKeyRemap: настройки сохранены успешно")

    ClearAllTemporaryHotkeys()

    Gui, KeyRemapSettings:+OwnDialogs
    MsgBox, 64, Успех, Настройки скрипта сохранены!

    Gui, KeyRemapSettings:Destroy

    WinWaitClose, Управление скриптом, , 1

    EnableAllHotkeys()
return

ToggleEnabledInfo:
    global enabledInfo
    enabledInfo := !enabledInfo

    GuiControl, KeyRemapSettings:, ToggleInfo, % (enabledInfo ? "ВКЛ" : "ВЫКЛ")
    state := enabledInfo ? "Enable" : "Disable"
    GuiControl, KeyRemapSettings:%state%, CaptureKeyInfo

    color := enabledInfo ? "00FF00" : "FF0000"
    Gui, KeyRemapSettings:Font, c%color% s10 Bold, Consolas
    GuiControl, KeyRemapSettings:Font, HeaderInfo
return

ToggleEnabledKoap:
    global enabledKoap
    enabledKoap := !enabledKoap

    GuiControl, KeyRemapSettings:, ToggleKoap, % (enabledKoap ? "ВКЛ" : "ВЫКЛ")
    state := enabledKoap ? "Enable" : "Disable"
    GuiControl, KeyRemapSettings:%state%, CaptureKeyKoap

    color := enabledKoap ? "00FF00" : "FF0000"
    Gui, KeyRemapSettings:Font, c%color% s10 Bold, Consolas
    GuiControl, KeyRemapSettings:Font, HeaderKoap
return

ToggleEnabledUK:
    global enabledUK
    enabledUK := !enabledUK

    GuiControl, KeyRemapSettings:, ToggleUK, % (enabledUK ? "ВКЛ" : "ВЫКЛ")
    state := enabledUK ? "Enable" : "Disable"
    GuiControl, KeyRemapSettings:%state%, CaptureKeyUK

    color := enabledUK ? "00FF00" : "FF0000"
    Gui, KeyRemapSettings:Font, c%color% s10 Bold, Consolas
    GuiControl, KeyRemapSettings:Font, HeaderUK
return

ToggleEnabledScreenshot:
    global enabledScreenshot
    enabledScreenshot := !enabledScreenshot

    GuiControl, KeyRemapSettings:, ToggleScreenshot, % (enabledScreenshot ? "ВКЛ" : "ВЫКЛ")
    state := enabledScreenshot ? "Enable" : "Disable"
    GuiControl, KeyRemapSettings:%state%, CaptureKeyScreenshot

    color := enabledScreenshot ? "00FF00" : "FF0000"
    Gui, KeyRemapSettings:Font, c%color% s10 Bold, Consolas
    GuiControl, KeyRemapSettings:Font, HeaderScreenshot
return

ToggleEnabledBadge:
    global enabledBadge
    enabledBadge := !enabledBadge

    GuiControl, KeyRemapSettings:, ToggleBadge, % (enabledBadge ? "ВКЛ" : "ВЫКЛ")
    state := enabledBadge ? "Enable" : "Disable"
    GuiControl, KeyRemapSettings:%state%, CaptureKeyBadge

    color := enabledBadge ? "00FF00" : "FF0000"
    Gui, KeyRemapSettings:Font, c%color% s10 Bold, Consolas
    GuiControl, KeyRemapSettings:Font, HeaderBadge
return

ToggleEnabledPresentation:
    global enabledPresentation
    enabledPresentation := !enabledPresentation

    GuiControl, KeyRemapSettings:, TogglePresentation, % (enabledPresentation ? "ВКЛ" : "ВЫКЛ")
    state := enabledPresentation ? "Enable" : "Disable"
    GuiControl, KeyRemapSettings:%state%, CaptureKeyPresentation

    color := enabledPresentation ? "00FF00" : "FF0000"
    Gui, KeyRemapSettings:Font, c%color% s10 Bold, Consolas
    GuiControl, KeyRemapSettings:Font, HeaderPresentation
return

CloseKeyRemapSettings:
    ClearAllTemporaryHotkeys()
    EnableAllHotkeys()
    SetTimer, UpdateMemoryCheckTime, Off
    SetTimer, UpdateMemoryInfoFrequent, Off
    Gui, KeyRemapSettings:Destroy
return

ManualMemoryClean:
    global lastMemoryCheckTime
    lastMemoryCheckTime := A_TickCount
    
    memInfoBefore := GetMemoryInfo()
    memBefore := memInfoBefore.available
    ClearMemory()
    Sleep, 500
    memInfo := GetMemoryInfo()
    memFreed := memInfo.available - memBefore
    memLevelColor := memInfo.levelColor
    Gui, KeyRemapSettings:Font, s9 c%memLevelColor%, Consolas
    GuiControl, KeyRemapSettings:Font, MemoryInfoText
    memText := "Занято: " . memInfo.used . " МБ / Доступно: " . memInfo.available . " МБ (" . memInfo.usedPercent . "%)"
    GuiControl, KeyRemapSettings:, MemoryInfoText, %memText%
    
    autoMemoryCleanVal := LoadIniValue("settings.AutoMemoryClean")
    if (autoMemoryCleanVal = "")
        autoMemoryCleanVal := 1
    
    if (autoMemoryCleanVal = 1) {
        timeUntilNextCheck := 300000
        minutes := Floor(timeUntilNextCheck / 60000)
        seconds := Floor((timeUntilNextCheck - (minutes * 60000)) / 1000)
        timeText := "Оперативная память (проверка через " . minutes . ":" . Format("{:02d}", seconds) . ")"
        GuiControl, KeyRemapSettings:, MemoryCheckTimeText, %timeText%
    }
    
    if (memFreed > 0) {
        ShowMemoryCleanNotification(memInfo.available, memFreed, 0)
    }
return

UpdateMemoryCheckTime:
    global lastMemoryCheckTime
    IfWinExist, Управление скриптом
    {
        autoMemoryCleanVal := LoadIniValue("settings.AutoMemoryClean")
        if (autoMemoryCleanVal = "")
            autoMemoryCleanVal := 1
        
        if (autoMemoryCleanVal = 1) {
            if (lastMemoryCheckTime = 0) {
                lastMemoryCheckTime := A_TickCount
            }
            timeUntilNextCheck := 300000 - (A_TickCount - lastMemoryCheckTime)
            if (timeUntilNextCheck < 0) {
                timeUntilNextCheck := 0
            }
            minutes := Floor(timeUntilNextCheck / 60000)
            seconds := Floor((timeUntilNextCheck - (minutes * 60000)) / 1000)
            timeText := "Оперативная память (проверка через " . minutes . ":" . Format("{:02d}", seconds) . ")"
        } else {
            timeText := "Оперативная память"
        }
        GuiControl, KeyRemapSettings:, MemoryCheckTimeText, %timeText%
    }
return

UpdateMemoryInfoFrequent:
    IfWinExist, Управление скриптом
    {
        memInfo := GetMemoryInfo()
        memLevelColor := memInfo.levelColor
        Gui, KeyRemapSettings:Font, s9 c%memLevelColor%, Consolas
        GuiControl, KeyRemapSettings:Font, MemoryInfoText
        memText := "Занято: " . memInfo.used . " МБ / Доступно: " . memInfo.available . " МБ (" . memInfo.usedPercent . "%)"
        GuiControl, KeyRemapSettings:, MemoryInfoText, %memText%
    }
return

UpdateMemoryInfo:
    global lastMemoryCheckTime
    lastMemoryCheckTime := A_TickCount
    
    IfWinExist, Управление скриптом
    {
        memInfo := GetMemoryInfo()
        memLevelColor := memInfo.levelColor
        Gui, KeyRemapSettings:Font, s9 c%memLevelColor%, Consolas
        GuiControl, KeyRemapSettings:Font, MemoryInfoText
        memText := "Занято: " . memInfo.used . " МБ / Доступно: " . memInfo.available . " МБ (" . memInfo.usedPercent . "%)"
        GuiControl, KeyRemapSettings:, MemoryInfoText, %memText%
        
        autoMemoryCleanVal := LoadIniValue("settings.AutoMemoryClean")
        if (autoMemoryCleanVal = "")
            autoMemoryCleanVal := 1
        
        if (autoMemoryCleanVal = 1) {
            timeUntilNextCheck := 300000
            minutes := Floor(timeUntilNextCheck / 60000)
            seconds := Floor((timeUntilNextCheck - (minutes * 60000)) / 1000)
            timeText := "Оперативная память (проверка через " . minutes . ":" . Format("{:02d}", seconds) . ")"
        } else {
            timeText := "Оперативная память"
        }
        GuiControl, KeyRemapSettings:, MemoryCheckTimeText, %timeText%
    }
return

AutoMemoryClean:
    WriteLog("AutoMemoryClean: начало автоматической проверки памяти")
    autoMemoryCleanStr := LoadIniValue("settings.AutoMemoryClean")
    autoMemoryCleanEnabled := (autoMemoryCleanStr = "" || autoMemoryCleanStr = "1") ? 1 : 0
    WriteLog("AutoMemoryClean: настройка включена: " . autoMemoryCleanEnabled)
    
    if (autoMemoryCleanEnabled = 1) {
        memInfo := GetMemoryInfo()
        WriteLog("AutoMemoryClean: память - занято: " . memInfo.usedPercent . "%, уровень: " . memInfo.level)
        
        if (memInfo.level = "yellow" || memInfo.level = "red") {
            WriteLog("AutoMemoryClean: уровень памяти требует очистки, начинаю очистку...")
            memBefore := memInfo.available
            ClearMemory()
            Sleep, 500
            memInfoAfter := GetMemoryInfo()
            memFreed := memInfoAfter.available - memBefore
            WriteLog("AutoMemoryClean: очистка завершена, освобождено: " . memFreed . " МБ, доступно: " . memInfoAfter.available . " МБ")
            
            if (memFreed > 0) {
                ShowMemoryCleanNotification(memInfoAfter.available, memFreed, 1)
            } else {
                WriteLog("AutoMemoryClean: память не была освобождена (возможно, уже была очищена)")
            }
        } else {
            WriteLog("AutoMemoryClean: уровень памяти нормальный (" . memInfo.level . "), очистка не требуется")
        }
    } else {
        WriteLog("AutoMemoryClean: автоматическая очистка отключена")
    }
return

ShowMemoryCleanNotification(freeMB, freedMB, isAuto := 1) {
    Gui, MemoryCleanNotifyBg:Destroy
    Gui, MemoryCleanNotify:Destroy

    header := isAuto ? "Память автоматически очищена" : "Память очищена вручную"
    notificationText := header . "`nСвободно: " . freeMB . " МБ"
    if (freedMB > 0)
        notificationText .= " (+" . freedMB . " МБ)"

    SysGet, MonitorPrimary, MonitorPrimary
    SysGet, MonitorWorkArea, MonitorWorkArea, %MonitorPrimary%

    windowWidth := 400
    windowHeight := 70
    windowX := MonitorWorkAreaLeft + ((MonitorWorkAreaRight - MonitorWorkAreaLeft) - windowWidth) / 2
    windowY := MonitorWorkAreaBottom - windowHeight - 20

    Gui, MemoryCleanNotifyBg:+AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, MemoryCleanNotifyBg:Color, 080808
    Gui, MemoryCleanNotifyBg:Show, w%windowWidth% h%windowHeight% x%windowX% y%windowY% NA, MemoryCleanNotifyBg
    WinSet, Transparent, 128, MemoryCleanNotifyBg
    SetWindowRoundedCorners("MemoryCleanNotifyBg", windowWidth, windowHeight, 15)

    Gui, MemoryCleanNotify:+AlwaysOnTop -Caption +ToolWindow
    Gui, MemoryCleanNotify:Color, 080808
    Gui, MemoryCleanNotify:Font, s12 c00FF00 Bold, Consolas
    Gui, MemoryCleanNotify:Add, Text, x20 y15 w360 Center, %notificationText%
    Gui, MemoryCleanNotify:Show, w%windowWidth% h%windowHeight% x%windowX% y%windowY% NA, MemoryCleanNotify
    WinSet, TransColor, 080808, MemoryCleanNotify
    SetWindowRoundedCorners("MemoryCleanNotify", windowWidth, windowHeight, 15)

    SetTimer, HideMemoryCleanNotification, -5000
}

HideMemoryCleanNotification:
    SetTimer, HideMemoryCleanNotification, Off
    Gui, MemoryCleanNotifyBg:Destroy
    Gui, MemoryCleanNotify:Destroy
return

ClearFrequentArticles:
    configFile := GetFrequentArticlesConfigFile()
    IniDelete, %configFile%, FrequentKoap, List
    IniDelete, %configFile%, FrequentUK, List
    Gui, KeyRemapSettings:+OwnDialogs
    MsgBox, 64, Готово, Список часто используемых статей (КоАП и УК) очищен.
return

ResetKeyRemapDefaults:
    GuiControl,, KeySettings, F3
    GuiControl,, KeyInfo, F4
    GuiControl,, KeyKoap, F5
    GuiControl,, KeyUK, F6
    GuiControl,, KeyScreenshot, F9
    GuiControl,, KeyBadge, F8
    GuiControl,, KeyPresentation,
    GuiControl,, BadgeMessage, На груди висит Жетон ФСБ РФ || X || «XXX» || «X» || №-00XX |.
    GuiControl,, PresentationMessage, % "Добрый день, являюсь Должность/Отдел, Звание, Фамилия"
    GuiControl,, BadgeAutoSendChk, 0
    GuiControl,, PresentationAutoSendChk, 0
    GuiControl,, FrequentArticlesChk, 1
    enabledInfo := 1
    enabledKoap := 1
    enabledUK := 1
    enabledScreenshot := 1
    enabledBadge := 1
    enabledPresentation := 1
    enabledAutoLayout := 1
    GuiControl,, ToggleInfo, ВКЛ
    GuiControl,, ToggleKoap, ВКЛ
    GuiControl,, ToggleUK, ВКЛ
    GuiControl,, ToggleScreenshot, ВКЛ
    GuiControl,, ToggleBadge, ВКЛ
    GuiControl,, TogglePresentation, ВКЛ
    GuiControl,, AutoLayoutChk, 1
    Gui, KeyRemapSettings:Font, c00FF00 s10 Bold, Consolas
    GuiControl, KeyRemapSettings:Font, HeaderInfo
    GuiControl, KeyRemapSettings:Font, HeaderKoap
    GuiControl, KeyRemapSettings:Font, HeaderUK
    GuiControl, KeyRemapSettings:Font, HeaderScreenshot
    GuiControl, KeyRemapSettings:Font, HeaderBadge
    GuiControl, KeyRemapSettings:Font, HeaderPresentation
    GuiControl, KeyRemapSettings:Enable, CaptureKeyInfo
    GuiControl, KeyRemapSettings:Enable, CaptureKeyKoap
    GuiControl, KeyRemapSettings:Enable, CaptureKeyUK
    GuiControl, KeyRemapSettings:Enable, CaptureKeyScreenshot
    GuiControl, KeyRemapSettings:Enable, CaptureKeyBadge
    GuiControl, KeyRemapSettings:Enable, CaptureKeyPresentation
return

ShowDetentionTimerMenu:
    global detentionTimerRunning
    
    Gui, DetentionMenu:Destroy
    Gui, DetentionMenu:+AlwaysOnTop -Caption +ToolWindow
    Gui, DetentionMenu:Color, 0a0a0a
    Gui, DetentionMenu:Font, s11 cWhite Bold, Consolas
    
    if (detentionTimerRunning) {
        Gui, DetentionMenu:Add, Text, x10 y10 w230 Center, Таймер уже запущен
        Gui, DetentionMenu:Font, s10 cWhite, Consolas
        Gui, DetentionMenu:Add, Button, x10 y45 w230 h35 gCancelDetentionTimer, Отменить таймер
        Gui, DetentionMenu:Add, Button, x10 y85 w230 h35 gCloseDetentionMenu, Закрыть
        Gui, DetentionMenu:Show, w250 h130 Center, Таймер
    } else {
        Gui, DetentionMenu:Add, Text, x10 y10 w230 Center, Выберите время
        Gui, DetentionMenu:Font, s10 cWhite, Consolas
        Gui, DetentionMenu:Add, Button, x10 y45 w110 h35 gStartTimer5, 5 минут
        Gui, DetentionMenu:Add, Button, x130 y45 w110 h35 gStartTimer10, 10 минут
        Gui, DetentionMenu:Add, Button, x10 y85 w110 h35 gStartTimer30, 30 минут
        Gui, DetentionMenu:Add, Button, x130 y85 w110 h35 gStartTimer60, 60 минут
        Gui, DetentionMenu:Font, s9 cGray, Consolas
        Gui, DetentionMenu:Add, Text, x10 y128 w80, Своё время:
        Gui, DetentionMenu:Font, s10 cBlack, Consolas
        Gui, DetentionMenu:Add, Edit, x95 y125 w50 h25 vCustomTimerMinutes Number Center, 
        Gui, DetentionMenu:Font, s9 cGray, Consolas
        Gui, DetentionMenu:Add, Text, x150 y128 w30, мин
        Gui, DetentionMenu:Font, s10 cWhite, Consolas
        Gui, DetentionMenu:Add, Button, x185 y125 w55 h25 gStartTimerCustom, OK
        Gui, DetentionMenu:Add, Button, x10 y160 w230 h30 gCloseDetentionMenu, Отмена
        Gui, DetentionMenu:Show, w250 h200 Center, Таймер
    }
return

CloseDetentionMenu:
    Gui, DetentionMenu:Destroy
return

StartTimer5:
    StartDetentionTimer(5)
return

StartTimer10:
    StartDetentionTimer(10)
return

StartTimer30:
    StartDetentionTimer(30)
return

StartTimer60:
    StartDetentionTimer(60)
return

StartTimerCustom:
    global CustomTimerMinutes
    Gui, DetentionMenu:Submit, NoHide
    if (CustomTimerMinutes = "" || CustomTimerMinutes < 1) {
        ToolTip, Введите время от 1 минуты
        SetTimer, RemoveToolTip, 2000
        return
    }
    if (CustomTimerMinutes > 999) {
        CustomTimerMinutes := 999
    }
    StartDetentionTimer(CustomTimerMinutes)
return

StartDetentionTimer(minutes) {
    global detentionTimerRunning, detentionTimerEnd, detentionTimerMinutes
    
    Gui, DetentionMenu:Destroy
    
    detentionTimerMinutes := minutes
    detentionTimerEnd := A_TickCount + (minutes * 60 * 1000)
    detentionTimerRunning := true
    
    ShowDetentionTimerOverlay()
    SetTimer, UpdateDetentionTimer, 1000
    
    ToolTip, Таймер запущен: %minutes% мин
    SetTimer, RemoveToolTip, 2000
}

ShowDetentionTimerOverlay() {
    global detentionTimerMinutes, TimerText, TimerProgress
    
    Gui, DetentionOverlayBg:Destroy
    Gui, DetentionOverlay:Destroy
    
    SysGet, MonitorPrimary, MonitorPrimary
    SysGet, MonitorWorkArea, MonitorWorkArea, %MonitorPrimary%
    
    windowWidth := 220
    windowHeight := 50
    windowX := MonitorWorkAreaLeft + ((MonitorWorkAreaRight - MonitorWorkAreaLeft) - windowWidth) / 2
    windowY := MonitorWorkAreaTop + 40
    
    Gui, DetentionOverlayBg:+AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, DetentionOverlayBg:Color, 080808
    Gui, DetentionOverlayBg:Show, w%windowWidth% h%windowHeight% x%windowX% y%windowY% NA, DetentionTimerBg
    WinSet, Transparent, 128, DetentionTimerBg
    SetWindowRoundedCorners("DetentionTimerBg", windowWidth, windowHeight, 15)
    
    Gui, DetentionOverlay:+AlwaysOnTop -Caption +ToolWindow +E0x20
    Gui, DetentionOverlay:Color, 080808
    Gui, DetentionOverlay:Font, s14 cWhite Bold, Consolas
    progressW := 190
    progressX := (windowWidth - progressW) / 2
    Gui, DetentionOverlay:Add, Text, vTimerText x10 y8 w200 Center, 
    Gui, DetentionOverlay:Add, Progress, vTimerProgress x%progressX% y35 w%progressW% h8 c00FF00 Background0a0a0a Smooth, 100
    Gui, DetentionOverlay:Show, w%windowWidth% h%windowHeight% x%windowX% y%windowY% NA, DetentionTimer
    WinSet, TransColor, 080808, DetentionTimer
    SetWindowRoundedCorners("DetentionTimer", windowWidth, windowHeight, 15)
    
    UpdateDetentionTimerDisplay()
}

UpdateDetentionTimer:
    global detentionTimerRunning, detentionTimerEnd
    
    if (!detentionTimerRunning) {
        SetTimer, UpdateDetentionTimer, Off
        return
    }
    
    remaining := detentionTimerEnd - A_TickCount
    
    if (remaining <= 0) {
        SetTimer, UpdateDetentionTimer, Off
        detentionTimerRunning := false
        Gui, DetentionOverlayBg:Destroy
        Gui, DetentionOverlay:Destroy
        ShowDetentionTimerFinished()
        return
    }
    
    UpdateDetentionTimerDisplay()
return

UpdateDetentionTimerDisplay() {
    global detentionTimerEnd, detentionTimerMinutes, TimerText, TimerProgress
    
    remaining := detentionTimerEnd - A_TickCount
    if (remaining < 0)
        remaining := 0
    
    totalMs := detentionTimerMinutes * 60 * 1000
    progressPercent := Round((remaining / totalMs) * 100)
    
    remainingSec := Floor(remaining / 1000)
    mins := Floor(remainingSec / 60)
    secs := Mod(remainingSec, 60)
    
    timeText := Format("{:02d}:{:02d}", mins, secs)
    
    if (progressPercent > 50) {
        Gui, DetentionOverlay:Font, s14 cLime Bold, Consolas
    } else if (progressPercent > 20) {
        Gui, DetentionOverlay:Font, s14 cYellow Bold, Consolas
    } else {
        Gui, DetentionOverlay:Font, s14 cRed Bold, Consolas
    }
    
    Gui, DetentionOverlay:Font, s14 cWhite Bold, Consolas
    GuiControl, DetentionOverlay:Font, TimerText
    GuiControl, DetentionOverlay:, TimerText, %timeText%
    GuiControl, DetentionOverlay:, TimerProgress, %progressPercent%
}

CancelDetentionTimer:
    global detentionTimerRunning
    
    Gui, DetentionMenu:Destroy
    SetTimer, UpdateDetentionTimer, Off
    detentionTimerRunning := false
    Gui, DetentionOverlayBg:Destroy
    Gui, DetentionOverlay:Destroy
    
    ToolTip, Таймер отменён
    SetTimer, RemoveToolTip, 2000
return

ShowDetentionTimerFinished() {
    SoundBeep, 750, 300
    Sleep, 100
    SoundBeep, 750, 300
    Sleep, 100
    SoundBeep, 1000, 500
    
    Gui, DetentionFinish:Destroy
    Gui, DetentionFinish:+AlwaysOnTop -Caption +ToolWindow
    Gui, DetentionFinish:Color, 0a0a0a
    Gui, DetentionFinish:Font, s16 cRed Bold, Consolas
    Gui, DetentionFinish:Add, Text, x10 y15 w280 Center, ВРЕМЯ ВЫШЛО!
    Gui, DetentionFinish:Add, Button, x50 y55 w200 h35 gCloseDetentionFinish, Понятно
 
    SysGet, MonitorPrimary, MonitorPrimary
    SysGet, MonitorWorkArea, MonitorWorkArea, %MonitorPrimary%
    
    windowWidth := 300
    windowX := MonitorWorkAreaLeft + ((MonitorWorkAreaRight - MonitorWorkAreaLeft) - windowWidth) / 2
    windowY := MonitorWorkAreaTop + 100
    
    Gui, DetentionFinish:Show, w%windowWidth% h105 x%windowX% y%windowY%, Таймер
}

CloseDetentionFinish:
    Gui, DetentionFinish:Destroy
return

SetupAutoLayoutHotkeys() {
    global enabledAutoLayout
    
    if (enabledAutoLayout = 1) {
        Hotkey, IfWinActive, ahk_exe GTA5.exe
        Hotkey, ~t, AutoLayoutToRussian, On, UseErrorLevel
        Hotkey, IfWinActive
    } else {
        Hotkey, IfWinActive, ahk_exe GTA5.exe
        Hotkey, ~t, AutoLayoutToRussian, Off, UseErrorLevel
        Hotkey, IfWinActive
    }
}

AutoLayoutToRussian:
    WinGet, activeHwnd, ID, A
    PostMessage, 0x50, 0, 0x0419,, ahk_id %activeHwnd%
return

DefExclBtnAdd:
    Gui, DefExcl:Submit, NoHide
    gDefExclResult := "add"
    Gui, DefExcl:Destroy
return

DefExclBtnSkip:
    Gui, DefExcl:Submit, NoHide
    gDefExclResult := "skip"
    if (DefExclNoShow) {
        _settingsFile := GetSettingsConfigFile()
        IniWrite, 1, %_settingsFile%, defender, declined
        WriteLog("AddDefenderExclusion: пользователь выбрал 'не показывать больше'")
    }
    Gui, DefExcl:Destroy
return

DefExclGuiClose:
DefExclGuiEscape:
    gDefExclResult := "skip"
    Gui, DefExcl:Destroy
return

return
return
