@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

REM : This script backup Cemu saves for selected games then prepare a
REM : folder (syncFolder) like the Wii-U side. All accounts existing
REM : on Wii-U side are treated (even i they are not found in CEMU)

    setlocal EnableDelayedExpansion
    color 4F
    title Import WiiU saves to CEMU

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
    set "config="!LOGS:"=!\lastConfig.ini""
    
    set "ftpSyncFolders="!HERE:"=!\ftpSyncFolders.bat""

    REM : set current char codeset
    call:setCharSet

    REM : search if Cemu2Wii-U is not already running
    set /A "nbI=0"
    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "Cemu2Wii-U" ^| find /I /V "dumpGamesFromWiiu" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% GEQ 2 (
        echo ERROR^: Cemu2Wii-U is already^/still running^! Aborting^!
        wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "Cemu2Wii-U" | find /I /V "find" ^| find /I /V "dumpGamesFromWiiu"
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
    echo Import Wii-U saves to CEMU^.
    echo =========================================================
    echo.

    if %nbArgs% EQU 0 goto:getInputs

    REM : when called with args
    if %nbArgs% NEQ 2 (
        echo ERROR on arguments passed ^(%nbArgs%^)
        echo SYNTAX^: "!THIS_SCRIPT!" MLC01_FOLDER_PATH userSaveMode
        echo userSaveMode = select ^/ all
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

    set checkFolder="!MLC01_FOLDER_PATH:"=!\usr\save\00050010"
    if not exist !checkFolder! (
        echo ERROR^: !checkFolder! not found ^?
        pause
        exit /b 92
    )

    set "userSaveMode=!args[1]!"
    set "userSaveMode=!userSaveMode: =!"
    set "userSaveMode=!userSaveMode:"=!"

    echo !userSaveMode! | find /I /V "select" | find /I /V "all" > NUL 2>&1 && (
        echo ERROR^: !userSaveMode! is not equal to 'all' or 'select'
        pause
        exit /b 93
    )
    goto:inputsAvailable

    :getInputs
    REM : when called with no args

    if exist !config! (
        for /F "delims=~= tokens=2" %%c in ('type !config! ^| find /I "MLC01_FOLDER_PATH" 2^>NUL') do set "MLC01_FOLDER_PATH=%%c"
        set "folder=!MLC01_FOLDER_PATH:"=!"
        choice /C yn /N /M "Use '!folder!' as MLC folder ? (y, n) : "
        if !ERRORLEVEL! EQU 1 (
            if exist !MLC01_FOLDER_PATH! (
                goto:getSavesMode
            ) else (
                echo Well^.^.^. !MLC01_FOLDER_PATH! does not exist anymore^!
                call:cleanConfigFile MLC01_FOLDER_PATH
            )
        )
    )
    echo Please select a MLC folder ^(mlc01^)^.^.^.
    :askMlc01Folder
    for /F %%b in ('cscript /nologo !browseFolder! "Select a MLC folder"') do set "folder=%%b" && set "MLC01_FOLDER_PATH=!folder:?= !"

    if [!MLC01_FOLDER_PATH!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit /b 75
        goto:askMlc01Folder
    )

    REM : check if a usr/save exist
    set "checkFolder="!MLC01_FOLDER_PATH:"=!\usr\save\00050010""
    if not exist !checkFolder! (
        echo !checkFolder! not found ^?
        goto:askMlc01Folder
    )
    REM : update last configuration
    call:cleanConfigFile MLC01_FOLDER_PATH
    echo MLC01_FOLDER_PATH=!MLC01_FOLDER_PATH!>!config!

    :getSavesMode
    echo.
    echo ---------------------------------------------------------
    set "userSaveMode="select""
    choice /C yn /N /M "Do you want to choose which accounts to be treated (y = select, n = treat ALL)? : "
    if !ERRORLEVEL! EQU 2 (
        choice /C yn /N /M "Please confirm, treat ALL accounts (CEMU saves of other users will be overwritten as well !) ? : "
        if !ERRORLEVEL! EQU 1 set "userSaveMode="all""
    )

    :inputsAvailable
    echo.
    echo ---------------------------------------------------------
    echo On your Wii-U^, you need to ^:
    echo - have your SDCard plugged in your Wii-U
    echo - launch WiiU FTP Server and press B to mount NAND paths
    echo - get the IP adress displayed on Wii-U gamepad
    echo.
    echo Press any key to continue when you^'re ready
    echo ^(CTRL-C^) to abort
    pause
    cls

    set "WinScpFolder="!RESOURCES_PATH:"=!\winSCP""
    set "WinScp="!WinScpFolder:"=!\WinScp.com""
    set "winScpIniTmpl="!WinScpFolder:"=!\WinSCP.ini-tmpl""
    set "winScpIni="!WinScpFolder:"=!\WinScp.ini""
    if not exist !winScpIni! goto:getWiiuIp

    REM : get the hostname
    set "ipRead="
    for /F "delims=~= tokens=2" %%i in ('type !winScpIni! ^| find "HostName="') do set "ipRead=%%i"
    if ["!ipRead!"] == [""] goto:getWiiuIp
    REM : and the port
    set "portRead="
    for /F "delims=~= tokens=2" %%i in ('type !winScpIni! ^| find "PortNumber="') do set "portRead=%%i"
    if ["!portRead!"] == [""] goto:getWiiuIp

    echo Found an existing FTP configuration ^:
    echo.
    echo PortNumber=!ipRead!
    echo HostName=!portRead!
    echo.
    choice /C yn /N /M "Use this setup (y, n)? : "
    if !ERRORLEVEL! EQU 1 set "wiiuIp=!ipRead!" && goto:checkConnection

    :getWiiuIp
    set /P "wiiuIp=Please enter your Wii-U local IP adress : "
    set /P "port=Please enter the port used : "

    REM : prepare winScp.ini file
    copy /Y  !winScpIniTmpl! !winScpIni! > NUL 2>&1
    set "fnrLog="!HERE:"=!\logs\fnr_WinScp.log""

    REM : set WiiU ip adress
    !StartHiddenWait! !fnrPath! --cl --dir !WinScpFolder! --fileMask WinScp.ini --find "FTPiiU-IP" --replace "!wiiuIp!" --logFile !fnrLog!
    !StartHiddenWait! !fnrPath! --cl --dir !WinScpFolder! --fileMask WinScp.ini --find "FTPiiU-port" --replace "!port!" --logFile !fnrLog!

    :checkConnection
    REM : check its state
    set /A "state=0"
    call:getHostState !wiiuIp! state

    if !state! EQU 0 (
        echo ERROR^: !wiiuIp! was not found on your network ^!
        pause
        exit 2
    )

    set "ftplogFile="!HERE:"=!\logs\ftpCheck_iws.log""
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=8 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_mlc/usr/save/system/act" "exit" > !ftplogFile! 2>&1
    type !ftplogFile! | find /I "Connection failed" > NUL 2>&1 && (
        echo ERROR ^: unable to connect^, check that your Wii-U is powered on and that 
        echo WiiuFtpServer was launched with mounting NAND paths ^(press B^)
        echo Pause this script until you fix it ^(CTRL-C to abort^)
        pause
        goto:checkConnection
    )
    type !ftplogFile! | find /I "Could not retrieve directory listing" > NUL 2>&1 && (
        echo ERROR ^: unable to list games on NAND^, launch MOCHA CFW before WiiuFtpServer on the Wii-U
        echo Pause this script until you fix it ^(CTRL-C to abort^)
        pause
        goto:checkConnection
    )
    cls

    REM : scans folder
    set /A "noOldScan=0"
    :scanMyWii
    set "WIIUSCAN_FOLDER="!HERE:"=!\WiiuFiles\Scans""
    if not exist !WIIUSCAN_FOLDER! (
        mkdir !WIIUSCAN_FOLDER! > NUL 2>&1
        set "scanNow="!HERE:"=!\scanWiiU.bat""
        call !scanNow! !wiiuIp!
        set /A "noOldScan=1"
    )

    set "LAST_SCAN="NOT_FOUND""
    for /F "delims=~" %%i in ('dir /B /A:D /O:N !WIIUSCAN_FOLDER! 2^>NUL') do set "LAST_SCAN="%%i""

    if [!LAST_SCAN!] == ["NOT_FOUND"] (
        set "scanNow="!HERE:"=!\scanWiiU.bat""
        call !scanNow! !wiiuIp!
        set /A "noOldScan=1"
        goto:scanMyWii
    )
    cls
    if !noOldScan! EQU 1 goto:getLocalTitleId

    echo The last WiiU^'s scan found is !LAST_SCAN!
    choice /C yn /N /M "Is it still up to date (y, n)? : "
    if !ERRORLEVEL! EQU 1 goto:getLocalTitleId

    rmdir /Q /S !WIIUSCAN_FOLDER! > NUL 2>&1
    goto:scanMyWii

    REM : get the list of titleId of your installed games
    :getLocalTitleId

    REM create a log file containing all your games titleId
    set "localTid="!WIIUSCAN_FOLDER:"=!\!LAST_SCAN:"=!\cemuTitlesId.log""
    if exist !localTid! del /F !localTid! > NUL 2>&1

    set "gamesFolder="!MLC01_FOLDER_PATH:"=!\games""

    if exist !gamesFolder! (
        call:getCemuTitles !gamesFolder!
    ) else (
        REM old update location but also new location of games when installing games with CEMU title manager    
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

    :getList
    REM : get title;endTitleId;source;dataFound from scan results
    set "gamesList="!WIIUSCAN_FOLDER:"=!\!LAST_SCAN:"=!\gamesList.csv""

    set /A "nbGames=0"

    cls
    echo =========================================================

    set "completeList="
    for /F "delims=~; tokens=1-3" %%i in ('type !gamesList! ^| find /V "endTitleId"') do (

        set "tid=%%j"
        set "endTitleId=!tid:'=!"        
        
        REM : if the game is also installed on your PC in !MLC01_FOLDER_PATH!
        type !localTid! | find /I "!endTitleId!" > NUL 2>&1 && (

            REM : get the title from !localTid!
            for /F "delims=~; tokens=2" %%n in ('type !localTid! ^| find /I "!endTitleId!"') do set "title=%%n"
            set "titles[!nbGames!]=!title!"
            set "endTitlesId[!nbGames!]=!endTitleId!"
            set "titlesSrc[!nbGames!]=%%k"
            echo !nbGames!	: !title!

            set "completeList=!nbGames! !completeList!"

            set /A "nbGames+=1"
        )
    )
    echo =========================================================

    REM : list of selected games
    REM : selected games
    set /A "nbGamesSelected=0"

    set /P "listGamesSelected=Please enter game's numbers list (separated with a space) or 'all' to treat all games : "
    :displayList

    if not ["!listGamesSelected!"] == ["all"] (

        if not ["!listGamesSelected!"] == [""] (
            echo !listGamesSelected! | findStr /R /V /C:"^[0-9 ]*$" > NUL 2>&1 && echo ERROR^: not a list of integers && pause && goto:getList

            echo =========================================================
            for %%l in (!listGamesSelected!) do (
                echo %%l | findStr /R /V "[0-9]" > NUL 2>&1 && echo ERROR^: %%l not in the list && pause && goto:getList
                set /A "number=%%l"
                if !number! GEQ !nbGames! echo ERROR^: !number! not in the list & pause & goto:getList

                echo - !titles[%%l]!
                set "selectedTitles[!nbGamesSelected!]=!titles[%%l]!"
                set "selectedEndTitlesId[!nbGamesSelected!]=!endTitlesId[%%l]!"
                set "selectedtitlesSrc[!nbGamesSelected!]=!titlesSrc[%%l]!"

                set /A "nbGamesSelected+=1"
            )
        ) else (
            goto:getList
        )
    ) else (
        set "listGamesSelected=!completeList!"
        goto:displayList
    )
    echo =========================================================
    echo.
    choice /C ync /N /M "Continue (y, n) or cancel (c)? : "
    if !ERRORLEVEL! EQU 3 echo Canceled by user^, exiting && timeout /T 3 > NUL 2>&1 && exit /b 98
    if !ERRORLEVEL! EQU 2 goto:getList

    cls
    echo =========================================================
    if !nbGamesSelected! EQU 0 (
        echo WARNING^: no games selected ^?
        pause
        exit /b 11
    )
    set /A "nbGamesSelected-=1"

    cls
    set "WIIU_FOLDER="!HERE:"=!\WiiuFiles""
    set "ONLINE_FOLDER="!WIIU_FOLDER:"=!\OnlineFiles""
    set "BACKUPS_PATH="!WIIU_FOLDER:"=!\Backups""
    set "SYNCFOLDER_PATH="!WIIU_FOLDER:"=!\SyncFolders\Import""
    REM : because FTP server on the wii-u does not manage timestamp
    REM : (returning 1970-01-01:23:00:00 for all files)
    REM : use only an empty local folder
    rmdir /Q /S !SYNCFOLDER_PATH! > NUL 2>&1
    mkdir !SYNCFOLDER_PATH! > NUL 2>&1

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
    set "DATE=%ldt%"

    REM : folder that contains temporarily the backup of each Wii-u Saves

    set "CEMU_BACKUP_PATH="!BACKUPS_PATH:"=!\!DATE!_CEMU_Saves""
    set "CEMU_BACKUP="!CEMU_BACKUP_PATH:"=!\!DATE!_CEMU_Saves.zip""
    if not exist !CEMU_BACKUP_PATH! mkdir !CEMU_BACKUP_PATH! > NUL 2>&1
    set "backupLog="!CEMU_BACKUP_PATH:"=!\!DATE!_CEMU_Saves.log"
    echo # gameTitle;endTitleId;cemu Save Folder > !backupLog!

    pushd !HERE!
    echo.
    REM : list of Wii-U accounts that do not exist in CEMU side
    set "accListToCreateInCemu="
    for /L %%n in (0,1,!nbGamesSelected!) do call:importSaves %%n

    echo.
    echo ---------------------------------------------------------
    echo Backup CEMU saves in !CEMU_BACKUP!
    set "pat="!CEMU_BACKUP_PATH:"=!\*""
    call !7za! a -y -w!CEMU_BACKUP_PATH! !CEMU_BACKUP! !pat!  > NUL 2>&1
    set "zipSrc="!CEMU_BACKUP_PATH:"=!\usr""
    rmdir /Q /S !zipSrc! > NUL 2>&1

    echo Done
    echo.
    echo CEMU saves were backup to !WIIU_BACKUP! 
    echo.

    if not ["!accListToCreateInCemu!"] == [""] (
        echo ---------------------------------------------------------
        echo WARNING ^: If needed^, create the following accounts in CEMU
        echo ^(accounts tab of ^'General Settings^'^)
        echo.
        for %%a in (!accListToCreateInCemu!) do echo ^> %%a
        echo.
    )

    echo =========================================================
    echo Now you can stop WiiuFtpServer
    echo.
    pause

    if !ERRORLEVEL! NEQ 0 exit /b !ERRORLEVEL!
    exit /b 0

    goto:eof
    REM : ------------------------------------------------------------------

REM : ------------------------------------------------------------------
REM : functions

    :cleanConfigFile
        REM : pattern to search in log file
        set "pat=%~1"
        set "configTmp="!config:"=!.tmp""
        if exist !configTmp! (
            del /F !config! > NUL 2>&1
            move /Y !configTmp! !config! > NUL 2>&1
        )

        type !config! | find /I /V "!pat!" > !configTmp!

        del /F /S !config! > NUL 2>&1
        move /Y !configTmp! !config! > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------
    

    REM : scan MLC01_PATH_FOLDER to get accounts defined in CEMU
    :getCemuAccountsList

        REM : search in usr\save\system\act
        set "ACCOUNTS_FOLDER="!MLC01_FOLDER_PATH:"=!\usr\save\system\act""

        if exist !ACCOUNTS_FOLDER! (

            pushd !ACCOUNTS_FOLDER!

            for /F "delims=~" %%a in ('dir /S /B /A:D "80*" 2^>NUL') do (
                for /F "delims=~" %%i in ("%%a") do (
                    set "account=%%~nxi"
                    set "account=!account: =!"

                    set /A "accountValid=1"
                    echo !account!| findStr /R /V "^[8][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$" > NUL 2>&1 && set /A "accountValid=0"

                    if !accountValid! EQU 1 (
                        REM : add to to list if it maches the patern and if not already listed
                        echo !cemuAccountsList! | find /V "!account!" > NUL 2>&1 && set "cemuAccountsList=!cemuAccountsList! !account!"
                    )
                )
            )
        )

    goto:eof
    REM : ------------------------------------------------------------------


    REM : faster than using xmlStarlet
    :getFromMetaXml
        set "node=%~1"
        set "value=NOT_FOUND"

        set "titleLine="NONE""
        for /F "tokens=1-2 delims=>" %%j in ('type !META_FILE! ^| find "%node%"') do set "titleLine="%%k""
        if not [!titleLine!] == ["NONE"] for /F "delims=<" %%j in (!titleLine!) do set "value=%%j"

        set "%2=!value!"
    goto:eof
    REM : ------------------------------------------------------------------

    :getCemuTitles
        set "folder="%~1""

        pushd !folder!

        REM : searching for meta file from here
        for /F "delims=~" %%i in ('dir /B /S "meta.xml" 2^> NUL') do (

            REM : meta.xml
            set "META_FILE="%%i""

            call:getFromMetaXml shortname_en title
            call:getFromMetaXml title_id titleId

            if not ["!title!"] == ["NOT_FOUND"] if not ["!titleId!"] == ["NOT_FOUND"] (
                if exist !localTid! (
                    type !localTid! | find /I /V "!titleId!" > NUL 2>&1 && echo !titleId!;!title! >> !localTid!
                ) else (
                    echo !titleId!;!title! > !localTid!
                )
            )
        )

    goto:eof
    REM : ------------------------------------------------------------------

    :treatWiiuAccount

        set "user=NOT_FOUND"
        set "tobeDisplayed=!folder!"

        if exist !wiiuUsersLog! (
            type !wiiuUsersLog! | find /I "!folder!" > NUL 2>&1 && (

                for /F "delims=~= tokens=1" %%k in ('type !wiiuUsersLog! ^| find /I "!folder!"') do set "user=%%k"
                if not ["!user!"] == ["NOT_FOUND"] set "tobeDisplayed=!user: =![!folder!]"
            )
        )

        REM : CEMU save for the current user
        set "cemuUserSaveFolder="!cemuUserGameFolder:"=!\!folder!""

        REM : existance flag
        set /A "accExistOnCemu=1"
        if not exist !cemuUserSaveFolder! (
            set /A "accExistOnCemu=0"

            REM : check if it is listed in cemuAccountsList
            echo !cemuAccountsList! | find /V "!folder!" > NUL 2>&1 && (

                choice /C yn /N /M "Saves of !tobeDisplayed! does not exist in CEMU, import it anyway ? (y, n)? : "
                if !ERRORLEVEL! EQU 2 goto:eof

                echo !accListToCreateInCemu! | find /V "!folder!" > NUL 2>&1 && (
                    if ["!user!"] == ["NOT_FOUND"] (
                        set "accListToCreateInCemu=!accListToCreateInCemu! !folder!"
                    ) else (
                        set "accListToCreateInCemu=!accListToCreateInCemu! !folder![user=!tobeDisplayed!]"
                    )
                )
            )
            mkdir !cemuUserSaveFolder! > NUl 2>&1
        )
        if [!userSaveMode!] == ["select"] (
            if !accExistOnCemu! EQU 1 (
                choice /C yn /N /M "Import !tobeDisplayed! !gameTitle! saves to CEMU (y, n)? : "
                if !ERRORLEVEL! EQU 2 goto:eof
                choice /C yn /N /M "Please confirm (y, n)? : "
                if !ERRORLEVEL! EQU 2 goto:eof

            )
        )


        REM : sync folders
        set "syncUserSaveFolder="!syncUserGameFolder:"=!\!folder!""
        robocopy !syncUserSaveFolder! !cemuUserSaveFolder! /MT:32 /MIR > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------


    :importSaves
        set /A "num=%~1"

        set "gameTitle=!selectedTitles[%num%]!"
        set "endTitleId=!selectedEndTitlesId[%num%]!"
        set "src=!selectedtitlesSrc[%num%]!"

        echo =========================================================
        echo Import saves for !gameTitle! ^(!endTitleId!^)
        echo Source location ^: ^/storage_!src!
        echo =========================================================

        set "cemuSaveFolder="!savesFolder:"=!\!endTitleId!""
        REM : cemuSaveFolder exist because it was listed in localTid

        REM : backup CEMU saves for this game to CEMU_BACKUP_PATH for ALL ACCOUNTS
        echo.
        echo Backup Cemu !gameTitle! saves^.^.^.

        set "backupFolderPath="!CEMU_BACKUP_PATH:"=!\usr\save\00050000\!endTitleId!""
        mkdir !backupFolderPath! > NUL 2>&1
        robocopy !cemuSaveFolder! !backupFolderPath! /MT:32 /MIR > NUL 2>&1

        REM : backup done, continue treatments for synchronizing using !SYNCFOLDER_PATH!

        REM : log title
        echo !gameTitle!;!endTitleId!;/storage_!src!/usr/save/00050000/!endTitleId! >> !backupLog!

        REM : temporary folder for FTP sync
        set "syncFolderPath="!SYNCFOLDER_PATH:"=!\usr\save\00050000\!endTitleId!""
        mkdir !syncFolderPath! > NUL 2>&1

        echo.
        echo Get Wii-U !gameTitle! saves^.^.^.

        REM : launching transfert (donwloading wii-u saves as !syncFolderPath! is empty)
        call !ftpSyncFolders! !wiiuIp! local !syncFolderPath! "/storage_!src!/usr/save/00050000/!endTitleId!" "!gameTitle! (saves)"
        set "cr=!ERRORLEVEL!"
        if !cr! NEQ 0 (
            echo ERROR when backuping !gameTitle! saves in !backupFolderPath! ^!
            goto:eof
        )

        REM : fill syncFolder with

        REM : copy common folder from Wii-U to CEMU
        set "commonMetaFolder="!syncFolderPath:"=!\user\common""
        set "cemuCommonFolder="!cemuSaveFolder:"=!\user\common""
        if exist !commonMetaFolder! (
            mkdir !cemuCommonFolder! > NUL 2>&1
            robocopy !commonMetaFolder! !cemuCommonFolder! /MT:32 /mir > NUL 2>&1
        )

        REM : CEMU does not use saveinfo.xml (leave untouched)


        REM : Loop on Wii-u accounts, ask to treat, robocopy syncFolderPath -> MLC01_FOLDER_PATH
        set "syncUserGameFolder="!syncFolderPath:"=!\user""

        set "cemuUserGameFolder="!cemuSaveFolder:"=!\user""
        pushd !syncUserGameFolder!

        REM : file that contains mapping between user - account folder (optional because
        REM : created by getWiiuOnlineFiles.bat
        set "wiiuUsersLog="!ONLINE_FOLDER:"=!\wiiuUsersList.log""

        REM : loop on accounts found in WII-U
        set "folder=NONE"
        for /F "delims=~" %%j in ('dir /B /A:D "80*" 2^>NUL') do (
            set "folder=%%j"

            call:treatWiiuAccount
        )

        echo ---------------------------------------------------------

        REM : log the slot used in a file
        echo ^> Wii-U saves for !gameTitle! were imported

        pushd !HERE!


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

    :getHostState
        set "ipaddr=%~1"
        set /A "state=0"
        ping -n 1 !ipaddr! > NUL 2>&1
        if !ERRORLEVEL! EQU 0 set /A "state=1"

        set "%2=%state%"
    goto:eof
    REM : ------------------------------------------------------------------

