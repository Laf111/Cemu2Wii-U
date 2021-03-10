@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------

REM : main

    setlocal EnableDelayedExpansion
    color 4F
    title Backup WiiU saves

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
    
    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
    set "DATE=%ldt%"

    cls
    echo =========================================================
    echo Backup Wii-U saves^.
    echo =========================================================
    echo.
    echo On your Wii-U^, you need to ^:
    echo - have your SDCard plugged in your Wii-U
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
    if !noOldScan! EQU 1 goto:getList

    echo The last WiiU^'s scan found is !LAST_SCAN!
    choice /C yn /N /M "Is it still up to date (y, n)? : "
    if !ERRORLEVEL! EQU 1 goto:getList

    rmdir /Q /S !WIIUSCAN_FOLDER! > NUL 2>&1
    goto:scanMyWii

    :getList
    REM : get title;endTitleId;source;dataFound from scan results
    set "gamesList="!WIIUSCAN_FOLDER:"=!\!LAST_SCAN:"=!\gamesList.csv""

    set /A "nbGames=0"

    cls
    echo =========================================================

    for /F "delims=~; tokens=1-2" %%i in ('type !gamesList! ^| find /V "endTitleId"') do (

        set "selectedTitles[!nbGames!]=%%i"
        set "selectedEndTitlesId[!nbGames!]=%%i"
        set "selectedtitlesSrc[!nbGames!]=%%j"
        
        set /A "nbGames+=1"
    )
    if !nbGames! EQU 0 (
        echo WARNING^: no games selected ^?
        pause
        exit /b 11
    )
    set /A "nbGames-=1"

    cls
    set "WIIU_FOLDER="!HERE:"=!\WiiuFiles""
    set "ONLINE_FOLDER="!WIIU_FOLDER:"=!\OnlineFiles""
    set "BACKUPS_PATH="!WIIU_FOLDER:"=!\Backups""
    set "SYNCFOLDER_PATH="!WIIU_FOLDER:"=!\SyncFolders\Import""
    if not exist !SYNCFOLDER_PATH! mkdir !SYNCFOLDER_PATH! > NUL 2>&1

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
    set "DATE=%ldt%"

    REM : folder that contains temporarily the backup of each Wii-u Saves

    set "WIIU_BACKUP_PATH="!BACKUPS_PATH:"=!\!DATE!_WIIU_Saves""
    if not exist !WIIU_BACKUP_PATH! mkdir !WIIU_BACKUP_PATH! > NUL 2>&1
    set "WIIU_BACKUP="!WIIU_BACKUP_PATH:"=!\!DATE!_WIIU_Saves.zip""
    
    set "backupLog="!WIIU_BACKUP_PATH:"=!\!DATE!.log"
    echo # gameTitle;endTitleId;WiiU Save Folder > !backupLog!

    pushd !HERE!
    echo.
    REM : list of Wii-U accounts that do not exist in CEMU side
    set "accListToCreateInCemu="
    for /L %%n in (0,1,!nbGames!) do call:importSaves %%n

    echo.
    echo ---------------------------------------------------------
    echo Backup WII-U saves in !WIIU_BACKUP!
    set "pat="!SYNCFOLDER_PATH:"=!\*""
    
    
    call !7za! a -y -w!WIIU_BACKUP_PATH! !WIIU_BACKUP! !pat!
    echo Done
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

        set "gameTitle=!selectedTitles[%num%]!"
        set "endTitleId=!selectedEndTitlesId[%num%]!"
        set "src=!selectedtitlesSrc[%num%]!"

        echo =========================================================
        echo Backup saves for !gameTitle!
        echo Source location ^: ^/storage_!src!
        echo =========================================================

        REM : log title
        set "syncFolderPath="!SYNCFOLDER_PATH:"=!\usr\save\00050000\!endTitleId!""
        mkdir !syncFolderPath! > NUL 2>&1
        
        REM : launching transfert (backup the Wii-U saves)
        call !ftpSyncFolders! !wiiuIp! local !syncFolderPath! "/storage_!src!/usr/save/00050000/!endTitleId!" "!gameTitle! (saves)"
        set "cr=!ERRORLEVEL!"
        if !cr! NEQ 0 (
            echo ERROR when downloading existing saves of !endTitleId! ^!
            goto:eof
        )
        
        set "META_FILE="!syncFolderPath:"=!\meta\meta.xml""
        if exist !META_FILE! call:getFromMetaXml shortname_en gameTitle
        
        echo !gameTitle!;!endTitleId!;usr/save/00050000/!endTitleId! >> !backupLog!
        
        set "syncFolderUser="!syncFolderPath:"=!\user""
        if not exist !syncFolderUser! goto:eof
        
        pushd !syncFolderUser!

        REM : loop on accounts found on the Wii-U
        set "folder=NONE"
        for /F "delims=~" %%j in ('dir /B /A:D "80*" 2^>NUL') do (
            set "folder=%%j"

            echo !accListToCreateInCemu! | find /V "!folder!" > NUL 2>&1 && set "accListToCreateInCemu=!accListToCreateInCemu! !folder!"
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

    :getHostState
        set "ipaddr=%~1"
        set /A "state=0"
        ping -n 1 !ipaddr! > NUL 2>&1
        if !ERRORLEVEL! EQU 0 set /A "state=1"

        set "%2=%state%"
    goto:eof
    REM : ------------------------------------------------------------------

