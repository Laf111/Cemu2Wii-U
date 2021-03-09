@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion
    color 4F
    title Restore Cemu2Wii-U backups

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "HERE=!SCRIPT_FOLDER:\"="!"

    pushd !HERE!        
    
    set "RESOURCES_PATH="!HERE:"=!\resources""
    set "browseFile="!RESOURCES_PATH:"=!\vbs\BrowseFileDialog.vbs""
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
        
    REM : search if CEMU is not already running
    set /A "nbI=0"
    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cemu.exe" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% GEQ 1 (
        echo ERROR^: CEMU is already^/still running^! Aborting^!
        wmic process get Commandline 2>NUL | find /I "CEMU.exe" | find /I /V "find"
        pause
        exit /b 100
    )

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
    set "DATE=%ldt%"
    
    cls
    echo =========================================================
    echo  Restore Cemu2Wii-U backups^.
    echo =========================================================
    echo.
    
    REM : initialize to CEMU the tye of the zip file
    set "zipNature=CEMU"
    
    if %nbArgs% EQU 0 goto:getInputs
    
    REM : when called with args
    if %nbArgs% NEQ 2 (
        echo ERROR on arguments passed ^(%nbArgs%^)
        echo SYNTAX^: "!THIS_SCRIPT!" BACKUP_PATH userSavesMode
        echo userSavesMode = select ^/ all
        echo given {%*}
        pause
        exit /b 99
    )

    REM : get and check BACKUP_PATH
    set "BACKUP_PATH=!args[0]!"    
    
    if not exist !BACKUP_PATH! (
        echo ERROR^: "!BACKUP_PATH!" not found
        pause
        exit /b 91    
    )
    
    REM : check file
    echo !BACKUP_PATH! | find /V ".zip" > NUL 2>&1 && (
        echo ERROR^: "!BACKUP_PATH!" is not a zip file
        pause
        exit /b 92
    )
    
    set "userSavesMode=!args[1]!"
    set "userSavesMode=!userSavesMode: =!"
    set "userSavesMode=!userSavesMode:"=!"
    
    echo !userSavesMode! | | find /I /V "select" | find /I /V "all" > NUL 2>&1 && (
        echo ERROR^: !userSavesMode! is not equal to 'all' or 'select'
        pause
        exit /b 93
    )
    
    goto:inputsAvailable    
    
    :getInputs
    REM : when called with no args
    
    echo Please browse to the zip file    
    REM : browse to the file
    :browse2Zip
    for /F %%b in ('cscript /nologo !browseFile! "Please browse to zip file"') do set "file=%%b" && set "zipFile=!file:?= !"
    if [!zipFile!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit /b 75
        goto:browse2Zip
    )
    REM : check file
    echo !BACKUP_PATH! | find /V ".zip" > NUL 2>&1 && (
        echo !BACKUP_PATH! is not a zip file
        goto:browse2Zip
    )

    echo.    
    echo ---------------------------------------------------------
    set "userSavesToExport="select""    
    choice /C yn /N /M "Do you want to choose which accounts to be treated (y = select, n = treat all)? : "
    if !ERRORLEVEL! EQU 2 (
        choice /C yn /N /M "Please confirm, treat all accounts? : "
        if !ERRORLEVEL! EQU 1 set "userSavesToExport="all""
    )
    
    :inputsAvailable
    
    REM : update zipNature
    echo !BACKUP_PATH! | find "WIIU_Saves.zip" > NUL 2>&1 && set "zipNature=WIIU"    
    
    REM : extract archive as MLC01_FOLDER_PATH    
    set "WIIU_FOLDER="!HERE:"=!\WiiuFiles""
    pushd !HERE!
    
    if ["!zipNature!"] == ["WIIU"] (
        set "SYNCFOLDER_PATH="!WIIU_FOLDER:"=!\SyncFolders\Restore""
        if exist !SYNCFOLDER_PATH! rmdir /Y !SYNCFOLDER_PATH! > NUL 2>&1        
        mkdir !SYNCFOLDER_PATH! > NUL 2>&1
        
        echo.
        echo Uncompressing !BACKUP_PATH!^.^.^.
        echo.
        call !7za! e -y -aoa -w!SYNCFOLDER_PATH! !BACKUP_PATH! -o!SYNCFOLDER_PATH! > NUL 2>&1
        
        set "userSavesToExport="select""    
        choice /C yn /N /M "Do you want to choose which accounts to be treated (y = select, n = treat all)? : "
        if !ERRORLEVEL! EQU 2 (
            choice /C yn /N /M "Please confirm, treat all accounts? : "
            if !ERRORLEVEL! EQU 1 set "userSavesToExport="all""
        )
        
        REM : export a Wii-U backup decompress to a mlc path to te Wii-U
        call "exportSavesToWiiu.bat" !SYNCFOLDER_PATH! select
    ) else (
        REM : ask for mlc destination
        set "MLC01_FOLDER_PATH="NONE""
        call:getMlcTarget

        if [!MLC01_FOLDER_PATH!] == ["NONE"] (
            choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
            if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit /b 75
        )
        REM : confirm deletion
        echo. 
        echo You choose to restore the backup in !MLC01_FOLDER_PATH!
        echo Duplicated saves will be overwriten
        echo. 
        
        choice /C yn /N /M "Confirm (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit /b 76
        
        REM : extract
        call !7za! e -y -aoa -w!LOGS! !BACKUP_PATH! -o!MLC01_FOLDER_PATH! > NUL 2>&1
    )
    set "cr=!ERRORLEVEL!"
    echo =========================================================
    if !cr! NEQ 0 (
        echo ERROR^: when restoring !BACKUP_PATH! ^!
    ) else (
        echo Done
    )
    echo.
    if !cr! NEQ 0 exit /b !cr!
    exit /b 0

    goto:eof
    REM : ------------------------------------------------------------------



REM : ------------------------------------------------------------------
REM : functions

    REM : function to get and set char set code for current host
    :getMlcTarget

        set "config="!LOGS:"=!\lastConfig.ini""    
        if exist !config! (
            for /F "delims=~= tokens=2" %%c in ('type !config! ^| find /I "MLC01_FOLDER_PATH" 2^>NUL') do set "MLC01_FOLDER_PATH=%%c"
            set "folder=!MLC01_FOLDER_PATH:"=!"
            choice /C yn /N /M "Use '!folder!' as MLC folder ? (y, n) : "
            if !ERRORLEVEL! EQU 1 goto:eof
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


    