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
    set "browseFolder="!RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""
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
    if %nbArgs% NEQ 3 (
        echo ERROR on arguments passed ^(%nbArgs%^)
        echo SYNTAX^: "!THIS_SCRIPT!" BACKUP_PATH gameMode userSavesMode
        echo userSavesMode and gameMode = select ^/ all
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

    set "gamesMode=!args[2]!"
    set "gamesMode=!gamesMode: =!"
    set "gamesMode=!gamesMode:"=!"
    
    echo !gamesMode! | | find /I /V "select" | find /I /V "all" > NUL 2>&1 && (
        echo ERROR^: !gamesMode! is not equal to 'all' or 'select'
        pause
        exit /b 93
    )
    
    goto:inputsAvailable    
    
    :getInputs
    REM : when called with no args
    
    echo Please browse to the zip file    
    REM : browse to the file
    :browse2Zip
    for /F %%b in ('cscript /nologo !browseFile! "Please browse to zip file"') do set "file=%%b" && set "BACKUP_PATH=!file:?= !"
    if [!BACKUP_PATH!] == ["NONE"] (
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
    set "gamesMode="select""    
    choice /C yn /N /M "Do you want to choose which games to be treated (y = select, n = treat all)? : "
    if !ERRORLEVEL! EQU 2 (
        choice /C yn /N /M "Please confirm, treat all games? : "
        if !ERRORLEVEL! EQU 1 set "gamesMode="all""
    )
    echo.    
    echo ---------------------------------------------------------
    set "userSavesMode="select""    
    choice /C yn /N /M "Do you want to choose which accounts to be treated (y = select, n = treat all)? : "
    if !ERRORLEVEL! EQU 2 (
        choice /C yn /N /M "Please confirm, treat all accounts? : "
        if !ERRORLEVEL! EQU 1 set "userSavesMode="all""
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
        
        call:uncompress

        REM : gamesMode not used
        set "userSavesMode="select""    
        choice /C yn /N /M "Do you want to choose which accounts to be treated (y = select, n = treat all)? : "
        if !ERRORLEVEL! EQU 2 (
            choice /C yn /N /M "Please confirm, treat all accounts? : "
            if !ERRORLEVEL! EQU 1 set "userSavesMode="all""
        )
        
        REM : export a Wii-U backup decompressed in a SYNCFOLDER_PATH to the Wii-U
        call "exportSavesToWiiu.bat" !SYNCFOLDER_PATH! select
    ) else (
        REM : ask for mlc destination
        set "MLC01_FOLDER_PATH="NONE""
        call:getMlcTarget

        if [!MLC01_FOLDER_PATH!] == ["NONE"] echo Cancelled by user & timeout /T 4 > NUL 2>&1 && exit /b 75

        REM : gamesMode
        set "gamesMode="select""    
        choice /C yn /N /M "Do you want to choose which games to be treated (y = select, n = treat all)? : "
        if !ERRORLEVEL! EQU 2 (
            choice /C yn /N /M "Please confirm, treat all games? : "
            if !ERRORLEVEL! EQU 1 set "gamesMode="all""
        )
        
        set "userSavesMode="select""    
        choice /C yn /N /M "Do you want to choose which accounts to be treated (y = select, n = treat all)? : "
        if !ERRORLEVEL! EQU 2 (
            choice /C yn /N /M "Please confirm, treat all accounts? : "
            if !ERRORLEVEL! EQU 1 set "userSavesMode="all""
        )
        if [!gamesMode!] == ["all"] if [!userSavesMode!] == ["all"] (
            REM : confirm deletion
            echo. 
            echo You choose to restore the backup in !MLC01_FOLDER_PATH!
            echo Duplicated saves will be overwriten
            echo. 
        
            choice /C yn /N /M "Confirm (y, n)? : "
            if !ERRORLEVEL! EQU 2 echo Cancelled by user & timeout /T 4 > NUL 2>&1 & exit /b 76
            
            REM : extract
            call !7za! x -y -aoa -w!LOGS! !BACKUP_PATH! -o!MLC01_FOLDER_PATH!
            goto:endMain
        )
        
        REM : here user choose to select games and/or accounts
        set "SYNCFOLDER_PATH="!WIIU_FOLDER:"=!\SyncFolders\Restore""
        if exist !SYNCFOLDER_PATH! rmdir /Y !SYNCFOLDER_PATH! > NUL 2>&1        
        mkdir !SYNCFOLDER_PATH! > NUL 2>&1
        
        call:uncompress

        call:syncMlcFolders
        
    )
    :endMain
    set "cr=!ERRORLEVEL!"
    echo =========================================================
    if !cr! NEQ 0 (
        echo ERROR^: when restoring !BACKUP_PATH! ^!
    ) else (
        echo Done
    )
    echo.
    pause
    if !cr! NEQ 0 exit /b !cr!
    exit /b 0

    goto:eof
    REM : ------------------------------------------------------------------



REM : ------------------------------------------------------------------
REM : functions

    REM : uncompress in SYNCFOLDER_PATH
    :uncompress
    
        echo.
        echo Uncompressing !BACKUP_PATH!^.^.^.
        echo.
        call !7za! x -y -aoa -w!SYNCFOLDER_PATH! !BACKUP_PATH! -o!SYNCFOLDER_PATH! > NUL 2>&1
    
    goto:eof
    REM : ------------------------------------------------------------------

    REM : scan MLC01_PATH_FOLDER to get accounts defined in CEMU
    :getCemuAccountsList

        pushd !savesFolder!
        
        for /F "delims=~" %%a in ('dir /S /B /A:D "80*" 2^>NUL') do (
            for /F "delims=~" %%i in ("%%a") do (
                set "account=%%~nxi"

                set /A "accountValid=1"
                echo !account!| findStr /R /V "^[8][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$" > NUL 2>&1 && set /A "accountValid=0"

                if !accountValid! EQU 1 (
                    REM : add to to list if it maches the patern and if not already listed
                    echo !cemuAccountsList! | find /V "!account!" > NUL 2>&1 && set "cemuAccountsList=!cemuAccountsList! !account!"
                )
            )
        )
    
    goto:eof
    REM : ------------------------------------------------------------------
    
    REM : function to get and set char set code for current host
    :getMlcTarget

        set "config="!LOGS:"=!\lastConfig.ini""    
        if exist !config! (
            for /F "delims=~= tokens=2" %%c in ('type !config! ^| find /I "MLC01_FOLDER_PATH" 2^>NUL') do set "MLC01_FOLDER_PATH=%%c"
            set "folder=!MLC01_FOLDER_PATH:"=!"
            choice /C yn /N /M "Use '!folder!' as MLC folder ? (y, n) : "
            if !ERRORLEVEL! EQU 1 goto:eof
        )
        
        :askMlc01Folder
        echo Please select a MLC folder ^(mlc01^)    
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

    :syncAccounts
    
                        
        REM : loop on accounts found in 
        set "folder=NONE"
        for /F "delims=~" %%j in ('dir /B /A:D "80*" 2^>NUL') do (
            set "folder=%%j"
            
            set "srcGameAccount="!SYNCFOLDER_PATH:"=!\usr\save\00050000\!endTitleId!\!folder!""
            set "gameAccount="!MLC01_FOLDER_PATH:"=!\usr\save\00050000\!endTitleId!\!folder!""
            
            REM : do you want to overwrite saves for !folder! account 
            REM : YES robocopy !srcGameAccount! !gameAccount!

        )
            
    goto:eof
    REM : ------------------------------------------------------------------

    :syncGame
    
                        
            REM : if the game is also installed on your PC in !MLC01_FOLDER_PATH!
            type !localTid! | find /I "!endTitleId!" > NUL 2>&1 && (
            
                REM : get the title from !localTid!
                for /F "delims=~; tokens=2" %%n in ('type !localTid! ^| find /I "!endTitleId!"') do set "title=%%n"
                
                if [!gamesMode!] == ["select"] (
                    choice /C yn /N /M "Import !title![!endTitleId!] saves (y, n)? : "
                    if !ERRORLEVEL! EQU 2 goto:eof
                    
                    REM : loop on accounts found in source SYNCFOLDER_PATH
                    pushd !srcGameSaveFolder!
                    
                    if [!userSavesMode!] == ["all"] (
                        REM : robocopy whole folder
                    
                    ) else (
                    
                        call:syncAccounts
                    )
                )
                
            
            )
            
    goto:eof
    REM : ------------------------------------------------------------------
    
    REM : synchronize games and account : overwrite MLC01_FOLDER_PATH files with selected ones from SYNCFOLDER_PATH
    :syncMlcFolders

        set "localTid="!SYNCFOLDER_PATH:"=!\cemuTitlesId.log""
        if exist !localTid! del /F !localTid! > NUL 2>&1
    
        REM : get games list in !MLC01_FOLDER_PATH! : targetGamesList
        set "gamesFolder="!MLC01_FOLDER_PATH:"=!\games""
        if exist !gamesFolder! (
            call:getCemuTitles !gamesFolder!
        ) else (    
            set "oldUpFolder="!MLC01_FOLDER_PATH:"=!\usr\title\00050000""
            if exist !oldUpFolder! call:getCemuTitles !oldUpFolder!

            set "upFolder="!MLC01_FOLDER_PATH:"=!\usr\title\0005000e"
            if exist !upFolder! call:getCemuTitles !upFolder!

            set "dlcFolder="!MLC01_FOLDER_PATH:"=!\usr\title\0005000c""
            if exist !dlcFolder! call:getCemuTitles !dlcFolder!
        )
        REM : re define savesFolder here in case of config loaded
        set "savesFolder="!MLC01_FOLDER_PATH:"=!\usr\save\00050000""
        call:getCemuTitles !savesFolder!
        
        set "cemuAccountsList="
        call:getCemuAccountsList 
        
        set "srcSaveFolder="!SYNCFOLDER_PATH:"=!\usr\save\00050000""
        if not exist !srcSaveFolder! (
            echo ERROR^: !srcSaveFolder! does not exist^, cancelling
            pause
            exit /b 55
        )
        REM : cd SYNCFOLDER_PATH\usr\save\00050000
        pushd !srcSaveFolder!

        
        for /F "delims=~" %%i in ('dir /S /B /A:D "*" 2^>NUL') do (
            for /F "delims=~" %%i in ("%%a") do (
                set "endTitleId=%%~nxi"
                
                echo !endTitleId!| findStr /R /I "^[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$" > NUL 2>&1 && (
                
                    REM : if MLC01_FOLDER_PATH\usr\save\00050000\titleId exist
                    set "gameSaveFolder="!MLC01_FOLDER_PATH:"=!\usr\save\00050000\!endTitleId!""
                    set "srcGameSaveFolder="!SYNCFOLDER_PATH:"=!\usr\save\00050000\!endTitleId!""                    
                    if exist !gameSaveFolder! if exist !srcGameSaveFolder! call:syncGame
                )
            )
        )        

            
        REM : do you want to treat title[titleId] ? 
        
        REM : YES : if userSavesMode = all
        REM             YES : robocopy SYNCFOLDER_PATH\usr\save\00050000\titleId MLC01_FOLDER_PATH\usr\save\00050000\titleId (created before if needed)
        REM             NO : cd SYNCFOLDER_PATH\usr\save\00050000\titleId\user
        REM                  loop on accounts in SYNCFOLDER_PATH\usr\save\00050000\titleId\user
        REM                  robocopy SYNCFOLDER_PATH\usr\save\00050000\titleId\user\account MLC01_FOLDER_PATH\usr\save\00050000\titleId\account
    
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


    