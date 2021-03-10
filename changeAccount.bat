@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion
    color 4F
    title Change accountId recursively in a MLC PATH

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "HERE=!SCRIPT_FOLDER:\"="!"
    pushd !HERE!
    
    set "RESOURCES_PATH="!HERE:"=!\resources""
    set "browseFolder="!RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""
    set "brcPath="!RESOURCES_PATH:"=!\BRC_Unicode_64\BRC64.exe""
        
    set "cmdOw="!RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1
    
    set "LOGS="!HERE:"=!\logs""
    if not exist !LOGS! mkdir !LOGS! > NUL 2>&1
    set "changeAccountLog="!LOGS:"=!\changeAccount.log""

    REM : set current char codeset
    call:setCharSet

    REM : search if CEMU is not already running
    set /A "nbI=0"
    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cemu.exe" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% GEQ 1 (
        echo ERROR^: CEMU is already^/still running^! Aborting^!
        wmic process get Commandline 2>NUL | find /I "CEMU.exe" | find /I /V "find"
        pause
        exit /b 100
    )
    
    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    cls
    echo =========================================================
    echo  Change accountId recursively in a MLC PATH^.
    echo =========================================================
    echo.
    
    if %nbArgs% EQU 0 goto:getInputs
    
    REM : when called with args
    if %nbArgs% NEQ 3 (
        echo ERROR on arguments passed ^(%nbArgs%^)
        echo SYNTAX^: "!THIS_SCRIPT!" MLC01_FOLDER_PATH SRC_ACCOUNT TARGET_ACCOUNT
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
    
    set "SRC_ACCOUNT=!args[1]!"
    set "SRC_ACCOUNT=!SRC_ACCOUNT:"=!"    
    set /A "srcAccValidity=1"
    echo !SRC_ACCOUNT!| findStr /R /V "^[8][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$" > NUL 2>&1 && set /A "srcAccValidity=0"
    if !srcAccValidity! EQU 0 (
        echo ERROR^: !SRC_ACCOUNT! does no match the expected patern ^(8XXXXXXX^)
        pause
        exit /b 92
    )
    
    set "TARGET_ACCOUNT=!args[2]!"
    set "TARGET_ACCOUNT=!TARGET_ACCOUNT:"=!"
    set /A "tgtAccValidity=1"
    echo !TARGET_ACCOUNT!| findStr /R /V "^[8][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$" > NUL 2>&1 && set /A "tgtAccValidity=0"
    if !tgtAccValidity! EQU 0 (
        echo ERROR^: !TARGET_ACCOUNT! does no match the expected patern ^(8XXXXXXX^)
        pause
        exit /b 93
    )
    
    goto:inputsAvailable
    
    :getInputs
    REM : when called with no args
    
    set "config="!LOGS:"=!\lastConfig.ini""    
    if exist !config! (
        for /F "delims=~= tokens=2" %%c in ('type !config! ^| find /I "MLC01_FOLDER_PATH" 2^>NUL') do set "MLC01_FOLDER_PATH=%%c"
        set "folder=!MLC01_FOLDER_PATH:"=!"

        choice /C yn /N /M "Use '!folder!' as MLC folder ? (y, n) : "
        if !ERRORLEVEL! EQU 1 goto:getSrcAcc
    )
    echo Please select a MLC folder ^(mlc01^)    
    :askMlc01Folder

    for /F %%b in ('cscript /nologo !browseFolder! "Select a MLC folder"') do set "folder=%%b" && set "MLC01_FOLDER_PATH=!folder:?= !"

    if [!MLC01_FOLDER_PATH!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit /b 75
        goto:askMlc01Folder
    )
    set savesFolder="!MLC01_FOLDER_PATH:"=!\usr\save\00050000"
    if not exist !savesFolder! (
        echo ERROR^: !savesFolder! not found ^?
        goto:askMlc01Folder
    )
    REM : update last configuration
    echo MLC01_FOLDER_PATH=!MLC01_FOLDER_PATH!>!config!
    
    :getSrcAcc
    set savesFolder="!MLC01_FOLDER_PATH:"=!\usr\save\00050000"    
    
    echo.
    set /P "SRC_ACCOUNT=Please enter the source account Id (8XXXXXXX) : "
    set /A "srcAccValidity=1"
    echo !SRC_ACCOUNT!| findStr /R /V "^[8][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$" > NUL 2>&1 && set /A "srcAccValidity=0"
    if !srcAccValidity! EQU 0 (
        echo ERROR^: !SRC_ACCOUNT! does no match the expected patern ^(8XXXXXXX^)
        goto:getSrcAcc
    )
    
    :getTgtAcc
    echo.
    set /P "TARGET_ACCOUNT=Please enter the target account Id (8XXXXXXX) : "
    echo.
    set /A "tgtAccValidity=1"
    echo !TARGET_ACCOUNT!| findStr /R /V "^[8][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$" > NUL 2>&1 && set /A "tgtAccValidity=0"
    if !tgtAccValidity! EQU 0 (
        echo ERROR^: !TARGET_ACCOUNT! does no match the expected patern ^(8XXXXXXX^)
        goto:getTgtAcc
    )
    timeout /T 2 > NUL 2>&1
    
    :inputsAvailable

    title Change accountId recursively in !MLC01_FOLDER_PATH!
    cls
    echo =========================================================
    if %nbArgs% NEQ 0 goto:rename
    set "sf=!savesFolder:"=!"
    choice /C yn /N /M "Rename all folders named !SRC_ACCOUNT! with !TARGET_ACCOUNT! in !sf! ? (y, n) : "
    if !ERRORLEVEL! EQU 2 (
        echo WARNING^: cancelled by user
        pause
        tmieout /T 3 > NUL 2>&1
        exit /b 1
    )
    
    :rename
    call !brcPath! /DIR^:!savesFolder! /REPLACECI^:!SRC_ACCOUNT!^:!TARGET_ACCOUNT! /EXECUTE /RECURSIVE > !changeAccountLog!

    echo.
    echo.
    echo =========================================================
    echo Done
    echo log file = !changeAccountLog!
    echo.

    echo.
    echo Create the account !TARGET_ACCOUNT! in all versions of CEMU 
    echo using the MLC path !MLC01_FOLDER_PATH!
    echo ^(in ^'General Settings^' ^/ Accounts tab^)
    echo.
    echo Otherwise saves won^'t show up ^!
    pause
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
