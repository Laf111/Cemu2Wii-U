@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------

REM : main

    setlocal EnableDelayedExpansion
    color 4F
    title Import WiiU saves to CEMU

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "HERE=!SCRIPT_FOLDER:\"="!"

    pushd !HERE!
    set "syncFolder="!HERE:"=!\ftpSyncFolders.bat""
    
    set "RESOURCES_PATH="!HERE:"=!\resources""
    set "StartHiddenWait="!RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartMinimizedWait="!RESOURCES_PATH:"=!\vbs\StartMinimizedWait.vbs""

    set "LOGS="!HERE:"=!\logs""
    if not exist !LOGS! mkdir !LOGS! > NUL 2>&1

    REM : set current char codeset
    call:setCharSet

    REM : J2000 unix timestamp (/ J1970)
    set /A "j2000=946684800"


    echo =========================================================
    echo Import Wii-U saves to CEMU^.
    echo =========================================================
    echo.

    echo Please select a MLC path folder ^(mlc01^)
    :askMlc01Folder
    for /F %%b in ('cscript /nologo !browseFolder! "Select a MLC pacth folder"') do set "folder=%%b" && set "MLC01_FOLDER_PATH=!folder:?= !"

    if [!MLC01_FOLDER_PATH!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit /b 75
        goto:askMlc01Folder
    )

    REM : check if a usr/save exist
    set savesFolder="!MLC01_FOLDER_PATH:"=!\usr\save\00050000"
    if not exist !savesFolder! (
        echo !savesFolder! not found ^?
        goto:askMlc01Folder
    )
    echo.    
    echo ---------------------------------------------------------
    set "userSavesToImport="select""    
    choice /C yn /N /M "Do you want to choose which accounts to be treated (y = select, n = treat all)? : "
    if !ERRORLEVEL! EQU 2 (
        choice /C yn /N /M "Please confirm, treat all accounts? : "
        if !ERRORLEVEL! EQU 1 set "userSavesToImport="all""
    )
    
    echo.    
    echo ---------------------------------------------------------
    echo On your Wii-U^, you need to ^:
    echo - disable the sleeping^/shutdown features
    echo - if you^'re using a permanent hack ^(CBHC^)^:
    echo    ^* launch HomeBrewLauncher
    echo    ^* then ftp-everywhere for CBHC
    echo - if you^'re not^:
    echo    ^* first run Mocha CFW HomeBrewLauncher
    echo    ^* then ftp-everywhere for MOCHA
    echo.
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
    for /F "delims=~= tokens=2" %%i in ('type !winScpIni! ^| find "HostName="') do set "ipRead=%%i"
    REM : and teh port
    for /F "delims=~= tokens=2" %%i in ('type !winScpIni! ^| find "PortNumber="') do set "portRead=%%i"

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

    set "winScpIniTmpl="!WinScpFolder:"=!\WinSCP.ini-tmpl""


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
        echo ERROR ^: unable to connect^, check that your Wii-U is powered on and that FTP_every_where is launched
        echo Pause this script until you fix it ^(CTRL-C to abort^)
        pause
        goto:checkConnection
    )
    type !ftplogFile! | find /I "Could not retrieve directory listing" > NUL 2>&1 && (
        echo ERROR ^: unable to list games on NAND^, launch MOCHA CFW before FTP_every_where on the Wii-U
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
    if exist !localTid! del /F !localTid!

    REM : cd to savesFolder="!MLC01_FOLDER_PATH:"=!\usr\save\00050000"
    pushd !savesFolder!
    
    REM : searching for meta file from here
    for /F "delims=~" %%i in ('dir /B /S "meta.xml" 2^> NUL') do (

        REM : meta.xml
        set "META_FILE="%%i""
        
        call:getFromMetaXml longname_en title
        call:getFromMetaXml title_id titlelId

        if not ["!titlelId!"] == ["NOT_FOUND"] ( 
            set /A "NB_GAMES+=1"
            echo !titleId!;!title! >> !localTid!
        )
    )

    :getList
    REM : get title;endTitleId;source;dataFound from scan results
    set "gamesList="!WIIUSCAN_FOLDER:"=!\!LAST_SCAN:"=!\gamesList.csv""

    set /A "nbGames=0"

    cls
    echo =========================================================

    for /F "delims=~; tokens=1-4" %%i in ('type !gamesList! ^| find /V "endTitleId"') do (

        set "endTitleId=%%i"

        REM : if the game is also installed on your PC in !MLC01_FOLDER_PATH!
        type !localTid! | find /I "!endTitleId!" > NUL 2>&1 && (
        
            REM : get the title from !localTid!
            for /F "delims=~; tokens=2" %%n in ('type !localTid! | find /I "!endTitleId!"') set "title=%%n"
            set "titles[!nbGames!]=!title!"
            set "endTitlesId[!nbGames!]=%%i"
            set "titlesSrc[!nbGames!]=%%k"
            echo !nbGames!	: !title!

            set /A "nbGames+=1"
        )
    )
    echo =========================================================

    REM : list of selected games
    REM : selected games
    set /A "nbGamesSelected=0"

    set /P "listGamesSelected=Please enter game's numbers list (separated with a space): "
    if not ["!listGamesSelected: =!"] == [""] (
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

    if !nbGamesSelected! EQU 0 (
        echo WARNING^: no games selected ^?
        pause
        exit 11
    )
    set /A "nbGamesSelected-=1"

    cls

    set "WIIU_FOLDER="!HERE:"=!\WiiuFiles""
    set "BACKUPS_PATH="!WIIU_FOLDER:"=!\Backups""
    
    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
    set "DATE=%ldt%"

    REM : folder that contains temporarily the backup of each Wii-u Saves
    set "BACKUP_PATH="!BACKUPS_PATH:"=!\CEMU_Saves""
    set "backupLog="!BACKUP_PATH:"=!\!DATE!.log"
    
    if not exist !BACKUP_PATH! mkdir !BACKUP_PATH! > NUL 2>&1

    echo.
    echo Cemu saves will be backup in !BACKUP_PATH!
    echo.

    for /L %%n in (0,1,!nbGamesSelected!) do call:importSaves %%n
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
    
    :importSaves
        set /A "num=%~1"

        REM : set gameTitle (used for naming user's rar file)
        set "gameTitle=!selectedTitles[%num%]!"
        set "endTitleId=!selectedEndTitlesId[%num%]!"
        set "src=!selectedtitlesSrc[%num%]!"

        echo =========================================================
        echo Import saves for !gameTitle! ^(%endTitleId%^)
        echo Source location ^: ^/storage_!src!
        echo =========================================================

        set "backupFolder="!BACKUP_PATH:"=!\usr\save\00050000\!endTitleId!""
        mkdir !backupFolder! > NUL 2>&1
        set "srcFolder="!savesFolder:"=!\!endTitleId!""
        REM : srcFolder exist because it was listed in localTid
        echo Backup !srcFolder!^.^.^.
        echo !srcFolder!^.^.^. >> !backupLog!
        robocopy !srcFolder! !backupFolder! /MT:32 /MIR > NUL 2>&1        
        
        set "backupFolderMeta="!backupFolder:"=!\meta""
        set "saveinfo="!backupFolderMeta:"=!\saveinfo.xml""
        
        REM : launching transfert (backup the Wii-U saves)
        call !syncFolder! !wiiuIp! local !backupFolder! "/storage_!src!/usr/save/00050000/!endTitleId!" "!gameTitle! (saves)"
        set "cr=!ERRORLEVEL!"
        if !cr! NEQ 0 (
            echo ERROR when downloading existing saves of !gameTitle! ^!
            goto:eof
        )

        echo Synchronize last imported saves for !gameTitle! ^(%endTitleId%^) 
        echo ---------------------------------------------------------
        
        REM : get the account declared on the Wii-U, loop on them
        set "backupFolderUser="!backupFolder:"=!\user""
        if not exist !backupFolderUser! (
            echo No Wii-U save was found for !gameTitle!
            goto:eof
        )
        
        pushd !backupFolderUser!
        REM : file that contains mapping between user - account folder (optional because
        REM : created by getWiiuOnlineFiles.bat
        set "wiiuUsersLog="!ONLINE_FOLDER:"=!\wiiuUsersList.log""
        
        REM : loop on saves found on the Wii-U
        set "folder=NONE"
        for /F "delims=~" %%j in ('dir /B /A:D "80000*" 2^>NUL') do (
            set "folder=%%j"
            
            set "wiiuUserFolder="!backupFolderUser:"=!\user\!folder!""            
            pushd !wiiuUserFolder!
            call:importSavesForCurrentUser
            pushd !MLC01_FOLDER_PATH!
        )
        REM : robocopy common folder
        set "wiiuCommonFolder="!backupFolder:"=!\user\common""
        if exist !wiiuCommonFolder! (
            set "cemuCommonFolder="!cemuSaveFolder:"=!\user\common""
            if not exist !cemuCommonFolder! mkdir !cemuCommonFolder! > NUL 2>&1
            robocopy !wiiuCommonFolder! !cemuCommonFolder! /MT:32 /MIR > NUL 2>&1
        )
        
        REM : CEMU does not use te saveInfo.xml file for now => copy Wii-U one
        
        REM : robocopy meta folder
        set "cemuMetaFolder="!cemuSaveFolder:"=!\meta""
        if not exist !cemuMetaFolder! mkdir !cemuMetaFolder! > NUL 2>&1
        robocopy !backupFolderMeta! !cemuMetaFolder! /MT:32 /MIR > NUL 2>&1

        
        echo ---------------------------------------------------------

        pushd !MLC01_FOLDER_PATH!

    goto:eof
    REM : ------------------------------------------------------------------


    :importSavesForCurrentUser

    
        set "tobeDisplayed="!folder!""
        
        if exist !wiiuUsersLog! (

            type !wiiuUsersLog! | find /I !folder! > NUL 2>&1 && (
                set "user="NOT_FOUND""
                for /F "delims=~= tokens=1" %%k in (' type !wiiuUsersLog! | find /I !folder!') do set "user="%%k""                
                if [!user!] == ["NOT_FOUND"] set "tobeDisplayed=!user: =!"
            )            
        )
        
        if [!userSavesToImport!] == ["select"] (
            choice /C yn /N /M "Import !tobeDisplayed! Wii-U saves to CEMU (y, n)? : "
            if !ERRORLEVEL! EQU 2 goto:eof
        )

        REM : CEMU save for the current user
        set "cemuUserSaveFolder="!cemuSaveFolder:"=!\user\!folder!""
        if not exist !cemuUserSaveFolder! mkdir !cemuUserSaveFolder! > NUl 2>&1
        
        REM : folder come from Wii-U => robocopy !wiiuUserFolder! !cemuUserSaveFolder!
        robocopy !wiiuUserFolder! !cemuUserSaveFolder! /MT:32 /MIR > NUL 2>&1        

        echo ^> !gameTitle! WII-U saves imported for !tobeDisplayed!

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

