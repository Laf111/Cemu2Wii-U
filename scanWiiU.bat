@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F

    REM : checking arguments
    set /A "nbArgs=0"
    :continue
        if "%~1"=="" goto:end
        set "args[%nbArgs%]="%~1""
        set /A "nbArgs +=1"
        shift
        goto:continue
    :end

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "HERE=!SCRIPT_FOLDER:\"="!"

    set "RESOURCES_PATH="!HERE:"=!\resources""
    set "fnrPath="!RESOURCES_PATH:"=!\fnr.exe""

    set "StartWait="!RESOURCES_PATH:"=!\vbs\StartWait.vbs""
    set "StartHiddenWait="!RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""

    set "cmdOw="!RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1
    
    set "LOGS="!HERE:"=!\logs""
    if not exist !LOGS! mkdir !LOGS! > NUL 2>&1
    
    REM : set current char codeset
    call:setCharSet

    set "WIIUSCAN_FOLDER="!HERE:"=!\WiiuFiles\Scans""
    if not exist !WIIUSCAN_FOLDER! mkdir !WIIUSCAN_FOLDER! > NUL 2>&1

    REM : get current date
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,2%"
    set "DATE=%ldt%"

    set "wiiuScanFolder="!WIIUSCAN_FOLDER:"=!\!DATE!""

    echo =========================================================
    echo Take a snapshot of Games^, updates and DLC and saves
    echo installed on your PC and on your Wii-U
    echo =========================================================
    echo.

    set "WinScpFolder="!RESOURCES_PATH:"=!\winSCP""
    set "WinScp="!WinScpFolder:"=!\WinScp.com""
    set "winScpIniTmpl="!WinScpFolder:"=!\WinSCP.ini-tmpl""
    set "winScpIni="!WinScpFolder:"=!\WinScp.ini""

    if %nbArgs% NEQ 0 (
        set "wiiuIp=!args[0]!"
        goto:checkConnection
    )

    echo On your Wii-U^, you need to ^:
    echo - disable the sleeping^/shutdown features
    echo - launched WiiU FTP Server
    echo.
    echo - get the IP adress displayed on Wii-U gamepad
    echo.
    echo Press any key to continue when you^'re ready
    echo ^(CTRL-C^) to abort
    pause
    cls

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
    set "fnrLog="!LOGS:"=!\fnr_WinScp.log""

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
        exit /b 2
    )

    set "ftplogFile="!LOGS:"=!\ftpCheck_sw.log""
    !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_mlc/usr/save/system/act" "exit" > !ftplogFile! 2>&1
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
    
    REM : ok so far, create scan folder
    mkdir !wiiuScanFolder!

    REM : log files
    set "remoteTids="!wiiuScanFolder:"=!\SRCTitleIds.log""
    set "remoteSaves="!wiiuScanFolder:"=!\SRCSaves.log""
    set "remoteUpdates="!wiiuScanFolder:"=!\SRCUpdates.log""
    set "remoteDlc="!wiiuScanFolder:"=!\SRCDlc.log""

    REM : if needed, dump account.dat for all users
    REM : online files folders
    set "WIIU_FOLDER="!HERE:"=!\WiiuFiles""
    set "ONLINE_FOLDER="!WIIU_FOLDER:"=!\OnlineFiles""
    set "SITENAME=FTP2WIIU"

    REM : lists of games and their endTitleId
    set /A "nbGames=0"
    set /A "nbGamesMlc=0"
    set /A "nbGamesUsb=0"

    for %%i in (mlc usb) do (
        set "src=%%i"

        echo Scanning wii-u storage_!src!^.^.^.

        REM : get saves list
        set "outputFile=!remoteSaves:SRC=%%i!"
        !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_!src!/usr/save/00050000" "exit" > !outputFile!

        REM : get games list
        set "outputFile=!remoteTids:SRC=%%i!"
        set "gamesListSrc=!outputFile!"

        !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_!src!/usr/title/00050000"  "exit" > !outputFile!

        REM : get updates list
        set "outputFile=!remoteUpdates:SRC=%%i!"
        !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_!src!/usr/title/0005000e"  "exit" > !outputFile!

        REM : get DLC list
        set "outputFile=!remoteDlc:SRC=%%i!"
        !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_!src!/usr/title/0005000c"  "exit" > !outputFile!

        REM : parsing the %src%GamesList.txt and get the titleIds
        for /F "tokens=9" %%j in ('type !gamesListSrc! ^| find "Drwxr"') do (

            set "endTitlesId[!nbGames!]=%%j"
            set "titlesSrc[!nbGames!]=!src!"

            set /A "nbGames+=1"
            if ["!src!"] == ["mlc"] set /A "nbGamesMlc+=1"
            if ["!src!"] == ["usb"] set /A "nbGamesUsb+=1"
             )
        )
    )
    if !nbGames! EQU 0 (
        echo WARNING : no games were found ^?
        pause
        exit /b 10
    )

    REM : create a global list of saves
    set "output=!remoteSaves:SRC=!"
    type !remoteSaves:SRC=mlc! | find "Drwxr" > !output!
    type !remoteSaves:SRC=usb! | find "Drwxr" >> !output!

    REM : create a global list of updates
    set "output=!remoteUpdates:SRC=!"
    type !remoteUpdates:SRC=mlc!  | find "Drwxr" > !output!
    type !remoteUpdates:SRC=usb!  | find "Drwxr" >> !output!

    REM : create a global list of Dlc
    set "output=!remoteDlc:SRC=!"
    type !remoteDlc:SRC=mlc!  | find "Drwxr" > !output!
    type !remoteDlc:SRC=usb!  | find "Drwxr" >> !output!

    set "gamesList="!wiiuScanFolder:"=!\gamesList.csv""
    set "tmpFile=!gamesList:csv=tmp!"
    cls

    echo =========================================================
    echo List of games found ^:
    echo ---------------------------------------------------------

    REM : loop on the games found
    set /A "nbg=!nbGames!-1"

    for /L %%i in (0,1,!nbg!) do (

        echo !endTitlesId[%%i]! found on !titlesSrc[%%i]!

        set "save="
        set "file=!remoteSaves:SRC=!"
        type !file! | find /I "!endTitlesId[%%i]!" > NUL 2>&1 && set "save=X"

        set "update="
        set "file=!remoteUpdates:SRC=!"
        type !file! | find /I "!endTitlesId[%%i]!" > NUL 2>&1 && set "update=X"

        set "file=!remoteDlc:SRC=!"
        set "dlc="
        type !file! | find /I "!endTitlesId[%%i]!" > NUL 2>&1 && set "dlc=X"

        echo !endTitlesId[%%i]!;!titlesSrc[%%i]!;!save!;!update!;!dlc! >> !tmpFile!
    )

    REM : create gamesList
    echo endTitleId;source;save;update;dlc > !gamesList!
    type !tmpFile! | sort >> !gamesList!
    del /F !tmpFile!

    echo =========================================================
    echo Total ^: !nbGames! games found ^(mlc ^: %nbGamesMlc%^, usb ^: %nbGamesUsb%^)
    echo =========================================================
    echo Results folder ^: !wiiuScanFolder!
    echo ---------------------------------------------------------
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

    :getHostState
        set "ipaddr=%~1"
        set /A "state=0"
        ping -n 1 !ipaddr! > NUL 2>&1
        if !ERRORLEVEL! EQU 0 set /A "state=1"

        set "%2=%state%"
    goto:eof
    REM : ------------------------------------------------------------------

