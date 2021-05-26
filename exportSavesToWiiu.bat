@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

REM : This script backup Wii-U saves for selected games then prepare a
REM : folder (syncFolder) like the Wii-U side. If an account is defined in CEMU
REM : but not on the Wii-U, user will be asked to confirm its treatment (even if
REM : userSaveMode = all)

    setlocal EnableDelayedExpansion
    color 4F
    title Export CEMU saves to your Wii-U

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

    set "ftpSyncFolders="!HERE:"=!\ftpSyncFolders.bat""

    REM : set current char codeset
    call:setCharSet

    REM : search if Cemu2Wii-U is not already running
    set /A "nbI=0"
    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I "Cemu2Wii-U" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% GEQ 2 (
        echo ERROR^: Cemu2Wii-U is already^/still running^! Aborting^!
        wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "Cemu2Wii-U" | find /I /V "find"
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
    echo  Export CEMU saves to the Wii-U^.
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

    set savesFolder="!MLC01_FOLDER_PATH:"=!\usr\save\00050000"
    if not exist !savesFolder! (
        echo ERROR^: !savesFolder! not found ^?
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

    set "config="!LOGS:"=!\lastConfig.ini""
    if exist !config! (
        for /F "delims=~= tokens=2" %%c in ('type !config! ^| find /I "MLC01_FOLDER_PATH" 2^>NUL') do set "MLC01_FOLDER_PATH=%%c"
        set "folder=!MLC01_FOLDER_PATH:"=!"
        choice /C yn /N /M "Use '!folder!' as MLC folder ? (y, n) : "
        if !ERRORLEVEL! EQU 1 (
            if exist !MLC01_FOLDER_PATH! (
                goto:getSavesMode
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

    :getSavesMode
    echo.
    echo ---------------------------------------------------------
    set "userSaveMode="select""
    choice /C yn /N /M "Do you want to choose which accounts to be treated (y = select, n = treat all)? : "
    if !ERRORLEVEL! EQU 2 (
        choice /C yn /N /M "Please confirm, treat all accounts? : "
        if !ERRORLEVEL! EQU 1 set "userSaveMode="all""
    )

    :inputsAvailable

    echo.
    echo ---------------------------------------------------------
    echo On your Wii-U^, you need to ^:
    echo - have your SDCard plugged in your Wii-U
    echo - launch WiiU FTP Server
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

    set "ftplogFile="!HERE:"=!\logs\ftpCheck_estw.log""
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_mlc/usr/save/system/act" "exit" > !ftplogFile! 2>&1
    type !ftplogFile! | find /I "Connection failed" > NUL 2>&1 && (
        echo ERROR ^: unable to connect^, check that your Wii-U is powered on and that WiiuFtpServer is launched
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

    :getList
    REM : get title;endTitleId;source;dataFound from scan results
    set "gamesList="!WIIUSCAN_FOLDER:"=!\!LAST_SCAN:"=!\gamesList.csv""

    set /A "nbGames=0"

    cls
    echo =========================================================

    set "completeList="
    for /F "delims=~; tokens=1-2" %%i in ('type !gamesList! ^| find /V "endTitleId"') do (

        set "endTitleId=%%i"
        REM : if the game is also installed on your PC in !MLC01_FOLDER_PATH!
        type !localTid! | find /I "!endTitleId!" > NUL 2>&1 && (

            REM : get the title from !localTid!
            for /F "delims=~; tokens=2" %%n in ('type !localTid! ^| find /I "!endTitleId!"') do set "title=%%n"
            set "titles[!nbGames!]=!title!"
            set "endTitlesId[!nbGames!]=%%i"
            set "titlesSrc[!nbGames!]=%%j"
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
    set "SYNCFOLDER_PATH="!WIIU_FOLDER:"=!\SyncFolders\Export""
    REM : because FTP server on the wii-u does not manage timestamp
    REM : (returning 1970-01-01:23:00:00 for all files)
    REM : use only an empty local folder
    rmdir /Q /S !SYNCFOLDER_PATH! > NUL 2>&1
    mkdir !SYNCFOLDER_PATH! > NUL 2>&1

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
    set "DATE=%ldt%"

    set "WIIU_BACKUP_PATH="!BACKUPS_PATH:"=!\!DATE!_WIIU_Saves""
    if not exist !WIIU_BACKUP_PATH! mkdir !WIIU_BACKUP_PATH! > NUL 2>&1
    set "WIIU_BACKUP="!WIIU_BACKUP_PATH:"=!\!DATE!_WIIU_Saves.zip""

    set "backupLog="!WIIU_BACKUP_PATH:"=!\!DATE!.log"
    echo # gameTitle;endTitleId;WiiU Save Folder > !backupLog!

    echo.
    for /L %%n in (0,1,!nbGamesSelected!) do call:exportSaves %%n

    echo.
    echo ---------------------------------------------------------
    echo Backup WII-U saves in !WIIU_BACKUP!
    set "pat="!WIIU_BACKUP_PATH:"=!\*""

    call !7za! a -y -w!WIIU_BACKUP_PATH! !WIIU_BACKUP! !pat!
    set "zipSrc="!WIIU_BACKUP_PATH:"=!\usr""
    rmdir /Q /S !zipSrc! > NUL 2>&1
    echo Done
    echo.
    echo Wii-U saves were backup to !WIIU_BACKUP! 
    echo.

    echo =========================================================
    echo Now you can stop FTPiiU server
    echo.
    pause

    if !ERRORLEVEL! NEQ 0 exit /b !ERRORLEVEL!
    exit /b 0

    goto:eof
    REM : ------------------------------------------------------------------



REM : ------------------------------------------------------------------
REM : functions

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

    :treatCemuAccount

        set "user=NOT_FOUND"
        set "tobeDisplayed=!folder!"

        if exist !wiiuUsersLog! (
            type !wiiuUsersLog! | find /I "!folder!" > NUL 2>&1 && (

                for /F "delims=~= tokens=1" %%k in (' type !wiiuUsersLog! ^| find /I "!folder!"') do set "user=%%k"
                if not ["!user!"] == ["NOT_FOUND"] set "tobeDisplayed=!user: =!"
            )
        )
        REM : cemuUserSaveFolder exists
        set "cemuUserSaveFolder="!cemuUserGameFolder:"=!\!folder!""

        REM : what about on wii-u side ?
        set "wiiuUserSaveFolder="!wiiuUserGameFolder:"=!\!folder!""
        REM : YES => already treated in treatWiiuAccount, exit
        if exist !wiiuUserSaveFolder! goto:eof


        REM : existance flag
        set /A "accExistOnWiiu=0"

        type !saveinfo! | find /I "!folder!" > NUL 2>&1 && set /A "accExistOnWiiu=1"
        REM : if account is not found, exit
        if !accExistOnWiiu! EQU 0 goto:eof


        REM : case where account is defined in saveinfo.xml but no folder was found on wii-U side :
        REM : try to inject the CEMU save...

        REM : treatment for the user
        echo Treating !tobeDisplayed! saves

        REM : Synchronize /storage_!src!/usr/save/00050000/!endTitleId!/user/!folder! with cemuUserSaveFolder content
        call !ftpSyncFolders! !wiiuIp! remote !cemuUserSaveFolder! "/storage_!src!/usr/save/00050000/!endTitleId!/user/!folder!" "Export !gameTitle! saves to the Wii-U"
        set "cr=!ERRORLEVEL!"

        REM : cd to RESOURCES_PATH to use xml.exe
        pushd !RESOURCES_PATH!

        REM : update saveinfo file
        call:updateSaveInfoFile

        REM : cd back to cemuUserGameFolder
        pushd !cemuUserGameFolder!

    goto:eof
    REM : ------------------------------------------------------------------

    :treatWiiuAccount

        set "user="NOT_FOUND""
        set "tobeDisplayed=!folder!"

        if exist !wiiuUsersLog! (
            type !wiiuUsersLog! | find /I "!folder!" > NUL 2>&1 && (

                for /F "delims=~= tokens=1" %%k in (' type !wiiuUsersLog! ^| find /I "!folder!"') do set "user=%%k"
                if not ["!user!"] == ["NOT_FOUND"] set "tobeDisplayed=!user: =![!folder!]"
            )
        )
        REM : wiiuUserSaveFolder exists
        set "wiiuUserSaveFolder="!wiiuUserGameFolder:"=!\!folder!""

        REM : what about on CEMU side ?
        set "cemuUserSaveFolder="!cemuUserGameFolder:"=!\!folder!""

        REM : cemuUserSaveFolder folder does not exist, exit
        if not exist !cemuUserSaveFolder! goto:eof

        if [!userSaveMode!] == ["select"] (
            choice /C yn /N /M "Export !tobeDisplayed! CEMU saves for !gameTitle! to Wii-U (y, n)? : "
            if !ERRORLEVEL! EQU 2 goto:eof
            choice /C yn /N /M "Please confirm (y, n)? : "
            if !ERRORLEVEL! EQU 2 goto:eof
        )

        REM : treatment for the user
        echo Treating !tobeDisplayed! saves

        REM : Synchronize /storage_!src!/usr/save/00050000/!endTitleId! with cemuUserSaveFolder content
        call !ftpSyncFolders! !wiiuIp! remote !cemuUserSaveFolder! "/storage_!src!/usr/save/00050000/!endTitleId!/user/!folder!" "Export !gameTitle! saves to the Wii-U"
        set "cr=!ERRORLEVEL!"

        REM : cd to RESOURCES_PATH to use xml.exe
        pushd !RESOURCES_PATH!
        REM : saveInfo.xml come from Wii-u side (cemu one was overwritten earlier)

        REM : update saveinfo file
        call:updateSaveInfoFile

        REM : cd back to wiiuUserGameFolder
        pushd !wiiuUserGameFolder!

    goto:eof
    REM : ------------------------------------------------------------------

    :exportSaves

        set /A "num=%~1"

        set "gameTitle=!selectedTitles[%num%]!"
        set "endTitleId=!selectedEndTitlesId[%num%]!"
        set "src=!selectedtitlesSrc[%num%]!"

        set "cemuSaveFolder="!savesFolder:"=!\!endTitleId!""
        REM : cemuSaveFolder exist because it was listed in localTid

        REM : create game save folder on the wii-U (if needed)
        call:createRemoteFolders

        echo =========================================================
        echo Export CEMU saves of !gameTitle! to the Wii-U
        echo =========================================================

        echo.
        echo Backup Wii-U !gameTitle! saves^.^.^.

        REM : backup Wii-U saves for this game to WIIU_BACKUP_PATH
        set "backupFolderPath="!WIIU_BACKUP_PATH:"=!\usr\save\00050000\!endTitleId!""
        mkdir !backupFolderPath! > NUL 2>&1


        set "SITENAME=!gameTitle! (saves)"
        set "logFile="!HERE:"=!\logs\ftpSyncFolders_!SITENAME!.log""
        del /F /S !logFile! > NUL 2>&1

        REM : launching transfert (donwloading wii-u saves as !backupFolderPath! is empty)
        call !ftpSyncFolders! !wiiuIp! local !backupFolderPath! "/storage_!src!/usr/save/00050000/!endTitleId!" "!gameTitle! (saves)"
        set "cr=!ERRORLEVEL!"
        if !cr! NEQ 0 (
            echo ERROR when backuping !gameTitle! saves in !backupFolderPath! ^!
            goto:eof
        )

        REM : backup done, continue treatments for synchronizing using !SYNCFOLDER_PATH!

        REM : log title
        echo !gameTitle!;!endTitleId!;/storage_!src!/usr/save/00050000/!endTitleId! >> !backupLog!

        REM : temporary folder for FTP sync
        set "syncFolderPath="!SYNCFOLDER_PATH:"=!\usr\save\00050000\!endTitleId!""
        mkdir !syncFolderPath! > NUL 2>&1

        REM : fill syncFolder with

        REM : meta folder from the wii-U
        set "wiiuMetaFolder="!backupFolderPath:"=!\meta""
        set "syncMetaFolder="!syncFolderPath:"=!\meta""

        REM : saveInfo.xml file (earlier copied from wii-u side in syncFolderPath)
        set "saveinfo="!syncMetaFolder:"=!\saveinfo.xml""

        if exist !wiiuMetaFolder! (
            mkdir !syncMetaFolder! > NUL 2>&1
            robocopy !wiiuMetaFolder! !syncMetaFolder! /MT:32 /mir > NUL 2>&1
        )

        set "cemuUserGameFolder="!cemuSaveFolder:"=!\user""
        set "wiiuUserGameFolder="!backupFolderPath:"=!\user""
        pushd !wiiuUserGameFolder!

        REM : file that contains mapping between user - account folder (optional because
        REM : created by getWiiuOnlineFiles.bat
        set "wiiuUsersLog="!ONLINE_FOLDER:"=!\wiiuUsersList.log""

        set "SITENAME=Export !gameTitle! saves to the Wii-U"
        set "logFile="!HERE:"=!\logs\ftpSyncFolders_!SITENAME!.log""
        del /F /S !logFile! > NUL 2>&1

        REM : loop on accounts found in WII-U
        set "folder=NONE"
        for /F "delims=~" %%j in ('dir /B /A:D "80*" 2^>NUL') do (
            set "folder=%%j"

            call:treatWiiuAccount
        )

        REM : add account existing in CEMU side and found in saveInfo.xml, otherwise ask user what to do
        REM :  loop on accounts found in CEMU
        pushd !cemuUserGameFolder!

        REM : loop on accounts found in CEMU
        set "folder=NONE"
        for /F "delims=~" %%j in ('dir /B /A:D "80*" 2^>NUL') do (
            set "folder=%%j"

            call:treatCemuAccount
        )

        REM : user/common folder from CEMU
        set "commonUserSaveFolder="!cemuUserGameFolder:"=!\common""
        if exist !commonUserSaveFolder! (

            REM : the common folder is created by CEMU as soon as 2 accounts exist
            set "pat="!commonUserSaveFolder:"=!\*.*""

            REM : launch the transfert and treat the 00000000 account only if files are found in the folder
            dir /S /B !pat! | findStr /R ".*" > NUL 2>&1 && (

                REM : Synchronize /storage_!src!/usr/save/00050000/!endTitleId!/user/common with commonUserSaveFolder content
                call !ftpSyncFolders! !wiiuIp! remote !commonUserSaveFolder! "/storage_!src!/usr/save/00050000/!endTitleId!/user/common" "Export !gameTitle! common saves to the Wii-U"
                set "cr=!ERRORLEVEL!"

                set "folder=00000000"
                REM : cd to RESOURCES_PATH to use xml.exe
                pushd !RESOURCES_PATH!
                REM : saveInfo.xml come from Wii-u side (cemu one was overwritten earlier)

                REM : update saveinfo file (force timestamp to 0 for common folder 00000000
                call:updateSaveInfoFile
            )
        )
        REM : cd back to HERE
        pushd !HERE!

        REM : Synchronize /storage_!src!/usr/save/00050000/!endTitleId!/meta with meta folder updated under syncMetaFolder
        call !ftpSyncFolders! !wiiuIp! remote !syncMetaFolder! "/storage_!src!/usr/save/00050000/!endTitleId!/meta" "Export !gameTitle! saves to the Wii-U"
        set "cr=!ERRORLEVEL!"

        echo ---------------------------------------------------------
        REM : log the slot used in a file
        echo ^> CEMU saves for !gameTitle! were exported to your Wii-U

        pushd !HERE!
    goto:eof
    REM : ------------------------------------------------------------------


    :getTs1970

        set "arg=%~2"

        set "ts="
        if not ["!arg!"] == [""] set "ts=%arg%"

        REM : if ts is not given : compute timestamp of the current date
        if ["%ts%"] == [""] for /F "delims=~= tokens=2" %%t in ('wmic os get localdatetime /value') do set "ts=%%t"

        set /A "yy=10000%ts:~0,4% %% 10000, mm=100%ts:~4,2% %% 100, dd=100%ts:~6,2% %% 100"
        set /A "dd=dd-2472663+1461*(yy+4800+(mm-14)/12)/4+367*(mm-2-(mm-14)/12*12)/12-3*((yy+4900+(mm-14)/12)/100)/4"
        set /A "ss=(((1%ts:~8,2%*60)+1%ts:~10,2%)*60)+1%ts:~12,2%-366100-%ts:~21,1%((1%ts:~22,3%*60)-60000)"

        set /A "%1+=dd*86400"

    goto:eof
    REM : ------------------------------------------------------------------

    :strLength
        Set "s=#%~1"
        Set "len=0"
        For %%N in (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) do (
          if "!s:~%%N,1!" neq "" (
            set /a "len+=%%N"
            set "s=!s:~%%N!"
          )
        )
        set /A "%2=%len%"
    goto:eof
    REM : ------------------------------------------------------------------

    REM : number to hexa with 16 digits
    :num2hex

        set /a "num = %~1"
        set "hex="
        set "hex.10=a"
        set "hex.11=b"
        set "hex.12=c"
        set "hex.13=d"
        set "hex.14=e"
        set "hex.15=f"

        :loop
        set /a "hextmp = num %% 16"
        if %hextmp% gtr 9 set hextmp=!hex.%hextmp%!
        set /a "num /= 16"
        set "hex=%hextmp%%hex%"
        if %num% gtr 0 goto loop

        :loop2
        call:strLength !hex! len
        if !len! LSS 16 set "hex=0!hex!" & goto:loop2

        set "%2=!hex!"

    goto:eof
    REM : ------------------------------------------------------------------

    :updateSaveInfoFile

        REM : init the value with now (J2000)
        call:getTs1970 now
        set /A "nowJ2K=!now!-j2000"
        call:num2hex !nowJ2K! hexValue

        set "stmp=!saveInfo!tmp"
        del /F !stmp! > NUL 2>&1

        REM : if exist saveInfo.xml check if !folder! exist in saveinfo.xml
        if exist !saveInfo! (
            REM : if the account is not present in saveInfo.xml
            type !saveInfo! | find /I "!folder!" > NUL 2>&1 && goto:updateSaveInfo
            REM : add it
            xml ed -s "//info" -t elem -n "account persistentId=""!folder!""" !saveInfo! > !stmp!
            xml ed -s "//info/account[@persistentId='!folder!']" -t elem -n "timestamp" -v "!hexValue!" !stmp! > !saveInfo!
            del /F !stmp! > NUL 2>&1
            goto:eof

            :updateSaveInfo
            REM : else update it

            xml ed -u "//info/account[@persistentId='!folder!']/timestamp" -v "!hexValue!" !saveInfo! > !stmp!
            if !ERRORLEVEL! EQU 0 del /F !saveInfo! > NUL 2>&1 & move /Y !stmp! !saveInfo! > NUL 2>&1
            del /F !stmp! > NUL 2>&1
            goto:eof
        )
        REM : if saveinfo.xml does not exist
        echo ^<^?xml version=^"1^.0^" encoding=^"UTF-8^"^?^>^<info^>^<^/account^>^<account persistentId=^"!folder!^"^>^<timestamp^>!hexValue!^<^/timestamp^>^<^/account^>^<^/info^> > !saveInfo!

    goto:eof
    REM : ------------------------------------------------------------------

    :createRemoteFolders
        set "ftplogFile="!WIIU_BACKUP_PATH:"=!\ftpCheck.log""
        !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "mkdir /storage_!src!/usr/save/00050000/!endTitleId!" "exit"  > !ftplogFile! 2>&1

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

