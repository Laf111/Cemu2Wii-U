@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion
    color 4F
    title Backup CEMU saves

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "HERE=!SCRIPT_FOLDER:\"="!"

    pushd !HERE!

    set "RESOURCES_PATH="!HERE:"=!\resources""
    set "StartHiddenWait="!RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "fnrPath="!RESOURCES_PATH:"=!\fnr.exe""
    set "browseFolder="!RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""
    set "7za="!RESOURCES_PATH:"=!\7za.exe""

    set "cmdOw="!RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1

    set "LOGS="!HERE:"=!\logs""
    if not exist !LOGS! mkdir !LOGS! > NUL 2>&1

    REM : set current char codeset
    call:setCharSet

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end    
    
    REM : search if Cemu2Wii-U is not already running
    set /A "nbI=0"
    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "Cemu2Wii-U" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% GEQ 2 (
        echo ERROR^: Cemu2Wii-U is already^/still running^! Aborting^!
        wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "Cemu2Wii-U" | find /I /V "find"
        pause
        exit /b 100
    )
    
    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
    set "DATE=%ldt%"

    cls
    echo =========================================================
    echo  Backup CEMU saves^.
    echo =========================================================
    echo.

    if %nbArgs% EQU 0 goto:getInputs

    REM : when called with args
    if %nbArgs% NEQ 1 (
        echo ERROR on arguments passed ^(%nbArgs%^)
        echo SYNTAX^: "!THIS_SCRIPT!" MLC01_FOLDER_PATH
        echo given {%*}
        pause
        exit /b 99
    )

    REM : get and check MLC01_FOLDER_PATH
    set "MLC01_FOLDER_PATH=!args[0]!"

    if not exist !MLC01_FOLDER_PATH! (
        echo ERROR^: "!MLC01_FOLDER_PATH!" not found
        pause
        exit /b 91
    )

    set savesFolder="!MLC01_FOLDER_PATH:"=!\usr\save\00050000"
    if not exist !savesFolder! (
        echo ERROR^: !savesFolder! not found ^?
        pause
        exit /b 92
    )

    goto:inputsAvailable

    :getInputs
    REM : when called with no args

    set "config="!LOGS:"=!\lastConfig.ini""
    if exist !config! (
        for /F "delims=~= tokens=2" %%c in ('type !config! ^| find /I "MLC01_FOLDER_PATH" 2^>NUL') do set "MLC01_FOLDER_PATH=%%c"
        set "folder=!MLC01_FOLDER_PATH:"=!"
        choice /C yn /N /M "Use '!folder!' as MLC folder ? (y, n) : "
        if !ERRORLEVEL! EQU 1 (
            if exist !MLC01_FOLDER_PATH! (
                goto:inputsAvailable
            ) else (
                echo Well^.^.^. !MLC01_FOLDER_PATH! does not exist anymore^!
            )
        )
    )
    echo Please select a MLC folder ^(mlc01^)
    :askMlc01Folder
    for /F %%b in ('cscript /nologo !browseFolder! "Select a MLC folder"') do set "folder=%%b" && set "MLC01_FOLDER_PATH=!folder:?= !"

    if [!MLC01_FOLDER_PATH!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit /b 75
        goto:askMlc01Folder
    )

    REM : check if a usr/save exist
    set "savesFolder="!MLC01_FOLDER_PATH:"=!\usr\save\00050000""
    if not exist !savesFolder! (
        echo !savesFolder! not found ^?
        goto:askMlc01Folder
    )
    REM : update last configuration
    echo MLC01_FOLDER_PATH=!MLC01_FOLDER_PATH!>!config!

    :inputsAvailable
    
    
    set "WIIU_FOLDER="!HERE:"=!\WiiuFiles""
    set "ONLINE_FOLDER="!WIIU_FOLDER:"=!\OnlineFiles""
    set "BACKUPS_PATH="!WIIU_FOLDER:"=!\Backups""
    set "SYNCFOLDER_PATH="!WIIU_FOLDER:"=!\SyncFolders\Export""    
    if exist !SYNCFOLDER_PATH! rmdir /Q /S !SYNCFOLDER_PATH! > NUL 2>&1
    mkdir !SYNCFOLDER_PATH! > NUL 2>&1

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
    set "DATE=%ldt%"

    set "CEMU_BACKUP_PATH="!BACKUPS_PATH:"=!\!DATE!_CEMU_Saves""
    set "CEMU_BACKUP="!CEMU_BACKUP_PATH:"=!\!DATE!_CEMU_Saves.zip""
    if not exist !CEMU_BACKUP_PATH! mkdir !CEMU_BACKUP_PATH! > NUL 2>&1
    set "backupLog="!CEMU_BACKUP_PATH:"=!\!DATE!_CEMU_Saves.log"
    echo # backup of saves from !MLC01_FOLDER_PATH! > !backupLog!
    
    REM : re define savesFolder here in case of config loaded
    set "savesFolder="!MLC01_FOLDER_PATH:"=!\usr\save\00050000""
    set "syncSavesFolder="!SYNCFOLDER_PATH:"=!\usr\save\00050000""
    mkdir !syncSavesFolder! > NUL 2>&1
    
    robocopy !savesFolder! !syncSavesFolder! /MT:32 /mir > NUL 2>&1
    
    echo.
    echo ---------------------------------------------------------
    echo Backup CEMU saves in !CEMU_BACKUP!
    
    set "pat="!SYNCFOLDER_PATH:"=!\*""
    call !7za! a -y -w!CEMU_BACKUP_PATH! !CEMU_BACKUP! !pat!  > NUL 2>&1
    echo Done
    echo.

    pause
    if !ERRORLEVEL! NEQ 0 exit /b !ERRORLEVEL!
    exit /b 0

    goto:eof
    REM : ------------------------------------------------------------------


REM : ------------------------------------------------------------------
REM : functions


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

