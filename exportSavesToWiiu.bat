@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion
    color 4F
    title Export CEMU saves to your Wii-U

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "HERE=!SCRIPT_FOLDER:\"="!"

    pushd !HERE!        
    
    set "RESOURCES_PATH="!HERE:"=!\resources""
    set "fnrPath="!RESOURCES_PATH:"=!\fnr.exe""
    set "browseFolder="!RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""
    set "StartHiddenWait="!RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""

    set "LOGS="!HERE:"=!\logs""
    if not exist !LOGS! mkdir !LOGS! > NUL 2>&1

    set "ftpSyncFolders="!HERE:"=!\ftpSyncFolders.bat""

    set "StartHiddenWait="!RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "StartMinimizedWait="!RESOURCES_PATH:"=!\vbs\StartMinimizedWait.vbs""

    set "LOGS="!HERE:"=!\logs""

    REM : set current char codeset
    call:setCharSet

    set "endTitleId=NONE"

    REM : J2000 unix timestamp (/ J1970)
    set /A "j2000=946684800"
        
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
    
    set "config="!LOGS:"=!\lastConfig.ini""    
    if exist !config! (
        for /F "delims=~= tokens=2" %%c in ('type !config! ^| find /I "MLC01_FOLDER_PATH" 2^>NUL') do set "MLC01_FOLDER_PATH=%%c"
        set "folder=!MLC01_FOLDER_PATH:"=!"
        choice /C yn /N /M "Use '!folder!' as MLC folder ? (y, n) : "
        if !ERRORLEVEL! EQU 1 goto:getSavesMode
    )
    echo Please select a MLC path folder ^(mlc01^)    
    :askMlc01Folder
    for /F %%b in ('cscript /nologo !browseFolder! "Select a MLC pacth folder"') do set "folder=%%b" && set "MLC01_FOLDER_PATH=!folder:?= !"

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
    set "userSavesToExport="select""    
    choice /C yn /N /M "Do you want to choose which accounts to be treated (y = select, n = treat all)? : "
    if !ERRORLEVEL! EQU 2 (
        choice /C yn /N /M "Please confirm, treat all accounts? : "
        if !ERRORLEVEL! EQU 1 set "userSavesToExport="all""
    )
    
    echo.    
    echo ---------------------------------------------------------
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
        
        push !RESOURCES-PATH!
        
        call:getValueInXml "//longname_en" !META_FILE! title
        call:getValueInXml "//title_id" !META_FILE! titleId

        if not ["!title!"] == ["NOT_FOUND"] if not ["!titleId!"] == ["NOT_FOUND"] echo !titleId!;!title! >> !localTid!
        pushd !savesFolder!
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
            for /F "delims=~; tokens=2" %%n in ('type !localTid! ^| find /I "!endTitleId!"') do set "title=%%n"
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

    set "WIIU_FOLDER="!HERE:"=!\WiiuFiles""
    set "BACKUPS_PATH="!WIIU_FOLDER:"=!\Backups""
    
    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
    set "DATE=%ldt%"

    REM : folder that contains temporarily the backup of each Wii-u Saves
    set "BACKUP_PATH="!BACKUPS_PATH:"=!\Wii-U_Saves""
    set "backupLog="!BACKUP_PATH:"=!\!DATE!.log"
    
    if not exist !BACKUP_PATH! mkdir !BACKUP_PATH! > NUL 2>&1

    pushd !HERE!
    echo.
    echo Wii-U saves will be backup in !BACKUP_PATH!
    echo.
    
    for /L %%n in (0,1,!nbGamesSelected!) do call:exportSaves %%n
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

    :exportSaves

        set /A "num=%~1"

        set "gameTitle=!selectedTitles[%num%]!"
        set "endTitleId=!selectedEndTitlesId[%num%]!"
        set "src=!selectedtitlesSrc[%num%]!"

        REM : get the account declared on the CEMU, loop on them
        set "cemuSaveFolder="!MLC01_FOLDER_PATH:"=!\mlc01\usr\save\00050000\!endTitleId!""
        if not exist !cemuSaveFolder! (
            echo WARNING ^: no CEMU saves found for !gameTitle!
            goto:eof
        )        
        
        REM : create remotes folders
        call:createRemoteFolders
        
        echo =========================================================
        echo Export CEMU saves of !gameTitle! to the Wii-U
        echo =========================================================

        set "backupFolder="!BACKUP_PATH:"=!\usr\save\00050000\!endTitleId!""
        
        echo Backup /storage_!src!/usr/save/00050000/!endTitleId!^.^.^.
        echo /storage_!src!/usr/save/00050000/!endTitleId!^.^.^. >> !backupLog!

        REM : download the whole save from the wii-U (as backup under BACKUP_PATH)
        wscript /nologo !StartHiddenWait! !ftpSyncFolders! !wiiuIp! local !backupFolder! "/storage_!src!/usr/save/00050000/!endTitleId!" "backup all !gameTitle! saves"
        
        set "metaFolder="!backupFolder:"=!\meta""        
        set "cemuSaveFolder="!savesFolder:"=!\!endTitleId!""
        
        REM : robocopy (sync) common folder in backupFolder
        set "commonFolder="!cemuSaveFolder:"=!\user\common""
        if exist !commonFolder! (
            set "localCommon="!backupFolder:"=!\user\common""
            mkdir !localCommon! > NUL 2>&1
            robocopy !commonFolder! !localCommon! /MT:32 /mir > NUL 2>&1
        )

        pushd !cemuSaveFolder!
        REM : file that contains mapping between user - account folder (optional because
        REM : created by getWiiuOnlineFiles.bat
        set "wiiuUsersLog="!ONLINE_FOLDER:"=!\wiiuUsersList.log""
        
        REM : loop on saves found in CEMU
        set "folder=NONE"
        for /F "delims=~" %%j in ('dir /B /A:D "80000*" 2^>NUL') do (
            set "folder=%%j"
            
            set "cemuUserSaveFolder="!cemuSaveFolder:"=!\user\!folder!""            
            call:exportSavesForCurrentAccount
        )
        
        echo Transfert save of !currentUser! [!folder!] for !gameTitle!^.^.^.
        echo ---------------------------------------------------------
        
        REM : launching transfert
        call !ftpSyncFolders! !wiiuIp! remote !backupFolder! "/storage_!src!/usr/save/00050000/!endTitleId!" "Export !gameTitle! saves for user !currentUser! to the Wii-U"
        set "cr=!ERRORLEVEL!"
        if !cr! NEQ 0 echo ERROR when exporting existing !gameTitle! saves for !currentUser! ^(!folder!^) ^!

        REM : log the slot used in a file
        echo ^> !currentUser! [!folder!] CEMU saves for !gameTitle! were exported to your Wii-U

        pushd !HERE!
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

        REM : if exist saveInfo.xml check if !folder! exist in saveinfo.xml
        if exist !saveInfo! (
            REM : if the account is not present in saveInfo.xml
            type !saveInfo! | find /I !folder! > NUL 2>&1 && goto:updateSaveInfo
            REM : add it
            set "stmp=!saveInfo!tmp"
            xml ed -s "//info" -t elem -n "account persistentId=""!folder!""" !saveInfo! > !stmp!
            xml ed -s "//info/account[@persistentId='!folder!']" -t elem -n "timestamp" -v "!hexValue!" !stmp! > !saveInfo!
            goto:eof

            :updateSaveInfo
            REM : else update it
            set "stmp=!saveInfo!tmp"
            xml ed -u "//info/account[@persistentId='!folder!']" -v "!hexValue!" !saveInfo! > !stmp!
            if !ERRORLEVEL! EQU 0 del /F !saveInfo! > NUL 2>&1 & move /Y !stmp! !saveInfo!
            goto:eof
        )
        REM : if saveinfo.xml does not exist
        echo ^<^?xml version=^"1^.0^" encoding=^"UTF-8^"^?^>^<info^>^<account persistentId=^"!folder!^"^>^<timestamp^>!hexValue!^<^/timestamp^>^<^/account^>^<^/info^> > !saveInfo!

    goto:eof
    REM : ------------------------------------------------------------------
    
    :exportSavesForCurrentAccount

        set "tobeDisplayed="!folder!""
        
        if exist !wiiuUsersLog! (

            type !wiiuUsersLog! | find /I !folder! > NUL 2>&1 && (
                set "user="NOT_FOUND""
                for /F "delims=~= tokens=1" %%k in (' type !wiiuUsersLog! | find /I !folder!') do set "user="%%k""                
                if [!user!] == ["NOT_FOUND"] set "tobeDisplayed=!user: =!"
            )            
        )
        
        if [!userSavesToExport!] == ["select"] (
            choice /C yn /N /M "Export !tobeDisplayed! CEMU saves to Wii-U (y, n)? : "
            if !ERRORLEVEL! EQU 2 goto:eof
        )

        REM : treatment for the user
        echo Treating !tobeDisplayed! saves
        
        REM : robocopy (sync) folder of current user
        set "localSaveFolder="!backupFolder:"=!\user\!folder!""
        mkdir !localSaveFolder! > NUL 2>&1
        robocopy !cemuUserSaveFolder! !localSaveFolder! /MT:32 /MIR > NUL 2>&1
        
        REM : cd to RESOURCES_PATH to use xml.exe
        pushd !RESOURCES_PATH!

        set "saveinfo="!metaFolder:"=!\saveinfo.xml""
        
        REM : update saveinfo file using user last settings
        call:updateSaveInfoFile

        pushd !MLC01_FOLDER_PATH!

        set /A "nbUsersTreated+=1"
    goto:eof
    REM : ------------------------------------------------------------------

    :createRemoteFolders
        set "ftplogFile="!BACKUP_PATH:"=!\ftpCheck.log""
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

    