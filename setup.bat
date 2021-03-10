@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion
    
    
    REM : Cemu2Wii-U Version
    set "VERSION=V1"    
    title Cemu2Wii-U !VERSION!

    color 4F
    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "HERE=!SCRIPT_FOLDER:\"="!"

    pushd !HERE!
    
    set "RESOURCES_PATH="!HERE:"=!\resources""
    set "browseFolder="!RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""
    set "Start="!RESOURCES_PATH:"=!\vbs\Start.vbs""

    set "cmdOw="!RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1
    
    set "LOGS="!HERE:"=!\logs""
    if not exist !LOGS! mkdir !LOGS! > NUL 2>&1

    REM : set current char codeset
    call:setCharSet
    
    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
    set "DATE=%ldt%"
    
    cls

    echo =========================================================
    echo Cemu2Wii-U !VERSION! installer
    echo =========================================================
    echo.
    
    :askShortcutsFolder
    for /F %%b in ('cscript /nologo !browseFolder! "Select a folder where to create shortcuts (a Wii-U subfolder will be created)"') do set "folder=%%b" && set "OUTPUT_FOLDER=!folder:?= !"
    if [!OUTPUT_FOLDER!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit 75
        goto:askShortcutsFolder
    )    
    set "SHORTCUTS_FOLDER="!OUTPUT_FOLDER:"=!\Cemu2Wii-U""

    mkdir !SHORTCUTS_FOLDER! > NUL 2>&1
    
    REM : create a shortcut to WinSCP
    set "WD_FOLDER="!RESOURCES_PATH:"=!\winSCP""
    set "TARGET_PATH="!WD_FOLDER:"=!\WinSCP.exe""
    set "ICO_PATH="!RESOURCES_PATH:"=!\icons\WinSCP.ico""
    set "LINK_PATH="!SHORTCUTS_FOLDER:"=!\WinSCP^.lnk""
    set "LINK_DESCRIPTION="FTP to Wii-U using WinSCP""

    if not exist !LINK_PATH! (
        echo Creating a shortcut to WinSCP
        call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !WD_FOLDER!
    )

    REM : create a shortcut to scanWiiU.bat (if needed)
    set "LINK_PATH="!SHORTCUTS_FOLDER:"=!\Scan my Wii-U^.lnk""
    set "LINK_DESCRIPTION="Take snapshot of your Wii-U content ^(list games^, saves^, updates and DLC^)""
    set "TARGET_PATH="!HERE:"=!\scanWiiU.bat""
    set "ICO_PATH="!RESOURCES_PATH:"=!\icons\wii-u.ico""
    if not exist !LINK_PATH! (
        echo Creating a shortcut to scanWiiU^.bat
        call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !HERE!
    )

    set "scansFolder="!HERE:"=!\WiiuFiles\Scans""
    if exist !scansFolder! (
        REM : create a shortcut to explore scans saved
        set "LINK_PATH="!SHORTCUTS_FOLDER:"=!\Scans results^.lnk""
        set "LINK_DESCRIPTION="Explore existing Wii-U scan results""
        set "TARGET_PATH=!scansFolder!"
        set "ICO_PATH="!RESOURCES_PATH:"=!\icons\scanResults.ico""

        if not exist !LINK_PATH! (
            echo Creating a shortcut to access to Wii-U scans results
            call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !HERE!
        )
    )

    REM : create a shortcut to getWiiuOnlineFiles.bat (if needed)
    set "LINK_PATH="!SHORTCUTS_FOLDER:"=!\Get online files^, update accounts from my Wii-U^.lnk""
    set "LINK_DESCRIPTION="Download all necessary files to play online with CEMU and update your accounts""
    set "TARGET_PATH="!HERE:"=!\getWiiuOnlineFiles.bat""
    set "ICO_PATH="!RESOURCES_PATH:"=!\icons\online.ico""
    if not exist !LINK_PATH! (
            echo Creating a shortcut to getWiiuOnlineFiles^.bat
        call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !HERE!
    )

    REM : create a shortcut to createWiiuSDcard.bat (if needed)
    set "LINK_PATH="!SHORTCUTS_FOLDER:"=!\Create a SDCard for Wii-U^.lnk""
    set "LINK_DESCRIPTION="Format and prepare a SDCard ^(even a large one^) for your Wii-U""
    set "TARGET_PATH="!HERE:"=!\createWiiuSDcard.bat""
    set "ICO_PATH="!RESOURCES_PATH:"=!\icons\sdcard.ico""
    if not exist !LINK_PATH! (
            echo Creating a shortcut to createWiiuSDcard^.bat
        call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !HERE!
    )

    REM : create a shortcut to exportSavesToWiiu.bat (if needed)
    set "LINK_PATH="!SHORTCUTS_FOLDER:"=!\Export CEMU saves to my Wii-U^.lnk""
    set "LINK_DESCRIPTION="Export CEMU saves to your Wii-U""
    set "TARGET_PATH="!HERE:"=!\exportSavesToWiiu.bat""
    set "ICO_PATH="!RESOURCES_PATH:"=!\icons\exportSave.ico""
    if not exist !LINK_PATH! (
            echo Creating a shortcut to exportSavesToWiiu^.bat
        call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !HERE!
    )

    REM : create a shortcut to importWiiuSaves.bat (if needed)
    set "LINK_PATH="!SHORTCUTS_FOLDER:"=!\Import saves from my Wii-U^.lnk""
    set "LINK_DESCRIPTION="Import saves from my Wii-U""
    set "TARGET_PATH="!HERE:"=!\importWiiuSaves.bat""
    set "ICO_PATH="!RESOURCES_PATH:"=!\icons\importSave.ico""
    if not exist !LINK_PATH! (
            echo Creating a shortcut to importWiiuSaves^.bat
        call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !HERE!
    )

    REM : create a shortcut to changeAccount.bat (if needed)
    set "LINK_PATH="!SHORTCUTS_FOLDER:"=!\Rename an account in a MLC folder^.lnk""
    set "LINK_DESCRIPTION="Rename an account in a MLC folder""
    set "TARGET_PATH="!HERE:"=!\changeAccount.bat""
    set "ICO_PATH="!RESOURCES_PATH:"=!\icons\cemu.ico""
    if not exist !LINK_PATH! (
            echo Creating a shortcut to changeAccount^.bat
        call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !HERE!
    )

    REM : create a shortcut to restoreBackup.bat (if needed)
    set "LINK_PATH="!SHORTCUTS_FOLDER:"=!\Restore a Wii-U or CEMU backup^.lnk""
    set "LINK_DESCRIPTION="Restore a Wii-U or CEMU backup""
    set "TARGET_PATH="!HERE:"=!\restoreBackup.bat""
    set "ICO_PATH="!RESOURCES_PATH:"=!\icons\compress.ico""
    if not exist !LINK_PATH! (
            echo Creating a shortcut to restoreBackup^.bat
        call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !HERE!
    )

    REM : create a shortcut to backupWiiuSaves.bat (if needed)
    set "LINK_PATH="!SHORTCUTS_FOLDER:"=!\Backup all Wii-U saves^.lnk""
    set "LINK_DESCRIPTION="Backup all Wii-U saves""
    set "TARGET_PATH="!HERE:"=!\backupWiiuSaves.bat""
    set "ICO_PATH="!RESOURCES_PATH:"=!\icons\BackupWiiU.ico""
    if not exist !LINK_PATH! (
            echo Creating a shortcut to backupWiiuSaves^.bat
        call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !HERE!
    )
    
    REM : create a shortcut to backupCemuSaves.bat (if needed)
    set "LINK_PATH="!SHORTCUTS_FOLDER:"=!\Backup all Cemu saves^.lnk""
    set "LINK_DESCRIPTION="Backup all Cemu saves""
    set "TARGET_PATH="!HERE:"=!\backupCemuSaves.bat""
    set "ICO_PATH="!RESOURCES_PATH:"=!\icons\BackupCemu.ico""
    if not exist !LINK_PATH! (
            echo Creating a shortcut to backupCemuSaves^.bat
        call:shortcut  !TARGET_PATH! !LINK_PATH! !LINK_DESCRIPTION! !ICO_PATH! !HERE!
    )
    
    echo.
    echo =========================================================
    echo.
    echo Done, opening !SHORTCUTS_FOLDER:"=!^.^.^.
    timeout /T 2 > NUL 2>&1

    wscript /nologo !Start! "%windir%\explorer.exe" !SHORTCUTS_FOLDER!
        
    timeout /T 4 > NUL 2>&1
    exit /b 0

    goto:eof
    REM : ------------------------------------------------------------------



REM : ------------------------------------------------------------------
REM : functions


    REM : function to create a shortcut
    :shortcut

        set "TARGET_PATH="%~1""
        set "LINK_PATH="%~2""
        set "LINK_DESCRIPTION="%~3""
        set "ICO_PATH="%~4""
        set "WD_PATH="%~5""

        if not exist !TARGET_PATH! goto:eof

        set "TMP_VBS_FILE="!TEMP!\RACC_!DATE!.vbs""

        REM : create object
        echo set oWS = WScript^.CreateObject^("WScript.Shell"^) >> !TMP_VBS_FILE!
        echo sLinkFile = !LINK_PATH! >> !TMP_VBS_FILE!
        echo set oLink = oWS^.createShortCut^(sLinkFile^) >> !TMP_VBS_FILE!
        echo oLink^.TargetPath = !TARGET_PATH! >> !TMP_VBS_FILE!
        echo oLink^.Description = !LINK_DESCRIPTION! >> !TMP_VBS_FILE!
        if not [!ICO_PATH!] == ["NONE"] echo oLink^.IconLocation = !ICO_PATH! >> !TMP_VBS_FILE!
        if not [!WD_PATH!] == ["NONE"] echo oLink^.WorkingDirectory = !WD_PATH! >> !TMP_VBS_FILE!
        echo oLink^.Save >> !TMP_VBS_FILE!

        REM : running VBS file
        cscript /nologo !TMP_VBS_FILE!

        if !ERRORLEVEL! EQU 0 (
            del /F !TMP_VBS_FILE! > NUL 2>&1
        ) else (
            echo ERROR^: in !TMP_VBS_FILE!
            pause
            del /F !TMP_VBS_FILE! > NUL 2>&1
        )

    goto:eof
    REM : ------------------------------------------------------------------

    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value 2^>NUL ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            echo Host char codeSet not found in %0 ^?
            timeout /t 8 > NUL 2>&1
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1

        REM : get locale for current HOST
        set "L0CALE_CODE=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic path Win32_OperatingSystem get Locale /value 2^>NUL ^| find "="') do set "L0CALE_CODE=%%f"

    goto:eof
    REM : ------------------------------------------------------------------
        