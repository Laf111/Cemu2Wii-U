@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion
    title Dump all the files need to play online with CEMU
    color 4F

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "HERE=!SCRIPT_FOLDER:\"="!"

    pushd !HERE!
    
    set "RESOURCES_PATH="!HERE:"=!\resources""
    set "fnrPath="!RESOURCES_PATH:"=!\fnr.exe""
    set "StartHiddenWait="!RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""

    set "cmdOw="!RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1
    
    set "LOGS="!HERE:"=!\logs""
    if not exist !LOGS! mkdir !LOGS! > NUL 2>&1

    REM : set current char codeset
    call:setCharSet
    
    REM : create folders
    set "WIIU_FOLDER="!HERE:"=!\WiiuFiles""
    set "ONLINE_FOLDER="!WIIU_FOLDER:"=!\OnlineFiles""

    REM : create folders
    if not exist !ONLINE_FOLDER! mkdir !ONLINE_FOLDER! > NUL 2>&1

    echo =========================================================
    echo Get online files from your Wii-U
    echo =========================================================
    echo.
    echo.
    echo To download files throught FTP^, on your Wii-U^ you need to ^:
    echo.
    echo - disable the sleeping^/shutdown features
    echo - if you^'re using a permanent hack ^(CBHC^)^:
    echo    ^* launch HomeBrewLauncher
    echo    ^* then ftp-everywhere for CBHC
    echo - if you^'re not^:
    echo    ^* first run Mocha CFW HomeBrewLauncher
    echo    ^* then ftp-everywhere for MOCHA
    echo - get the IP adress displayed on Wii-U gamepad
    echo.
    echo Make sure the Wii U account you want to dump^/use has
    echo the "Save password" option checked ^(auto login^) ^!
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
    set "fnrLog="!LOGS:"=!\fnr_WinScp.log""

    REM : set WiiU ip adress
    !StartHiddenWait! !fnrPath! --cl --dir !WinScpFolder! --fileMask WinScp.ini --find "FTPiiU-IP" --replace "!wiiuIp!" --logFile !fnrLog!
    !StartHiddenWait! !fnrPath! --cl --dir !WinScpFolder! --fileMask WinScp.ini --find "FTPiiU-port" --replace "!port!" --logFile !fnrLog!

    :checkConnection
    cls
   
    REM : check its state
    set /A "state=0"
    call:getHostState !wiiuIp! state

    if !state! EQU 0 (
        echo ERROR^: !wiiuIp! was not found on your network ^!
        echo exiting 2
        pause
        exit /b 2
    )

    set "ftplogFile="!LOGS:"=!\ftpCheck_gwof.log""
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

    set "CCERTS_FOLDER="!ONLINE_FOLDER:"=!\mlc01\sys\title\0005001b\10054000\content\ccerts""
    if not exist !CCERTS_FOLDER! mkdir !CCERTS_FOLDER! > NUL 2>&1

    set "SCERTS_FOLDER="!ONLINE_FOLDER:"=!\mlc01\sys\title\0005001b\10054000\content\scerts""
    if not exist !SCERTS_FOLDER! mkdir !SCERTS_FOLDER! > NUL 2>&1

    set "MIIH_FOLDER="!ONLINE_FOLDER:"=!\mlc01\sys\title\0005001b\10056000""
    if not exist !MIIH_FOLDER! mkdir !MIIH_FOLDER! > NUL 2>&1

    set "JFL_FOLDER="!ONLINE_FOLDER:"=!\mlc01\sys\title\00050030\1001500A""
    set "UFL_FOLDER="!ONLINE_FOLDER:"=!\mlc01\sys\title\00050030\1001510A""
    set "EFL_FOLDER="!ONLINE_FOLDER:"=!\mlc01\sys\title\00050030\1001520A""

    echo Launching FTP transferts^.^.^.

    REM : run ftp transferts ^:
    echo.
    echo =========================================================
    echo - CCERTS
    echo ---------------------------------------------------------
    !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local "!CCERTS_FOLDER!" /storage_mlc/sys/title/0005001b/10054000/content/ccerts" "exit"
    echo.
    echo ---------------------------------------------------------
    echo - SCERTS
    echo ---------------------------------------------------------
    !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local "!SCERTS_FOLDER!" /storage_mlc/sys/title/0005001b/10054000/content/scerts" "exit"
    echo.
    echo ---------------------------------------------------------
    echo - MIIs Head
    echo ---------------------------------------------------------
    !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local "!MIIH_FOLDER!" /storage_mlc/sys/title/0005001b/10056000" "exit"
    echo.
    echo ---------------------------------------------------------
    echo - Friend list
    echo ---------------------------------------------------------

    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_mlc/sys/title/00050030/1001500A" "exit" > !ftplogFile! 2>&1
    type !ftplogFile! | find /I "Could not retrieve directory listing" > NUL 2>&1 && (
        goto:US
    )
    echo.
    echo found JPN one
    if not exist !JFL_FOLDER! mkdir !JFL_FOLDER! > NUL 2>&1
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local "!JFL_FOLDER!" /storage_mlc/sys/title/00050030/1001500A" "exit"

    :US
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_mlc/sys/title/00050030/1001510A" "exit" > !ftplogFile! 2>&1
    type !ftplogFile! | find /I "Could not retrieve directory listing" > NUL 2>&1 && (
        goto:EU
    )
    echo.
    echo found USA one
    if not exist !UFL_FOLDER! mkdir !UFL_FOLDER! > NUL 2>&1
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local "!UFL_FOLDER!" /storage_mlc/sys/title/00050030/1001510A" "exit"

    :EU
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_mlc/sys/title/00050030/1001520A" "exit" > !ftplogFile! 2>&1
    type !ftplogFile! | find /I "Could not retrieve directory listing" > NUL 2>&1 && (
        goto:getAccounts
    )
    echo found EUR one
    if not exist !EFL_FOLDER! mkdir !EFL_FOLDER! > NUL 2>&1
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local "!EFL_FOLDER!" /storage_mlc/sys/title/00050030/1001520A" "exit"

    :getAccounts
    echo.
    echo ---------------------------------------------------------
    echo - WII-U accounts
    echo ---------------------------------------------------------
    set "ACCOUNTS_FOLDER="!ONLINE_FOLDER:"=!\mlc01\usr\save\system\act""
    if not exist !ACCOUNTS_FOLDER! mkdir !ACCOUNTS_FOLDER! > NUL 2>&1
    
    !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local "!ACCOUNTS_FOLDER!" /storage_mlc/usr/save/system/act" "exit"

    echo.
    echo ---------------------------------------------------------
    echo - Identify Wii-U users and their accounts
    echo ---------------------------------------------------------
    set "wiiuUsersLog="!ONLINE_FOLDER:"=!\wiiuUsersList.log""

    call:getWiiuUsers

    echo =========================================================
    choice /C yn /N /M "Do you want to install the files in a mlc01 folder (y, n)? : "
    if !ERRORLEVEL! EQU 2 goto:noMlcInstall
    
    set "config="!LOGS:"=!\lastConfig.ini""    
    if exist !config! (
        for /F "delims=~= tokens=2" %%c in ('type !config! ^| find /I "MLC01_FOLDER_PATH" 2^>NUL') do set "MLC01_FOLDER_PATH=%%c"
        set "folder=!MLC01_FOLDER_PATH:"=!"
        choice /C yn /N /M "Use '!folder!' as MLC folder ? (y, n) : "
        if !ERRORLEVEL! EQU 1 goto:installFiles
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

    :installFiles
    set "srcFolder="!ONLINE_FOLDER:"=!\mlc01""
    
    REM : saves folder in the target mlc01 path
    set "savesFolder="!MLC01_FOLDER_PATH:"=!\usr\save\00050000""
    
    REM : get the list of the accounts existing in CEMU
    set "cemuAccountsList="
    call:getCemuAccountsList 
    
    REM : list of Wii-U accounts that do not exist in CEMU side
    set "accListToCreateInCemu=" 
    call:getUndefinedWiiuAccounts    
    
    pushd !HERE!
    
    if not ["!accListToCreateInCemu!"] == [""] (
        echo WARNING ^: If needed^, create the following accounts in CEMU
        echo ^(accounts tab of ^'General Settings^'^)
        echo.
        for %%a in ("!accListToCreateInCemu!") do echo %%a
        echo.
    )    
    
    robocopy !srcFolder! !MLC01_FOLDER_PATH! /S /MT:32 /IS /IT 
    goto:endMain
    
    :noMlcInstall
    echo.
    echo.
    echo Don^'t forget to create the following accounts
    echo and users in all your CEMU installs ^: 
    echo.
    type !wiiuUsersLog! | find /V "#"
    echo.
    echo =========================================================
    
    :endMain
    echo.
    echo Done
    echo.
    
    echo Don^'t foget to add opt^.bin and seeprom^.bin ^(dumped from
    echo your Wii-U using NANDDUMPER)^ close to cemu^.exe to play
    echo online^.
    echo =========================================================
    

    pause
    if !ERRORLEVEL! NEQ 0 exit /b !ERRORLEVEL!
    exit /b 0

    goto:eof
    REM : ------------------------------------------------------------------



REM : ------------------------------------------------------------------
REM : functions



    REM : check if Wii-U accounts need to be defined in CEMU
    :getUndefinedWiiuAccounts
    
        pusd !ACCOUNTS_FOLDER!
        for /F "delims=~" %%a in ('dir /B /A:D "80*" 2^>NUL') do (
            for /F "delims=~" %i in ("%%a") do (
                set "account=%%~nxi"
                echo !account!| findStr /R /I "^[8][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$" > NUL 2>&1 && (
                    REM : if it maches the patern
                    
                    REM : check if it is listed in cemuAccountsList
                    echo !cemuAccountsList! | find /V "!account!" > NUL 2>&1 && set "accListToCreateInCemu=!accListToCreateInCemu! !account!"
                )
            )
        )
    goto:eof
    REM : ------------------------------------------------------------------


    REM : scan MLC01_PATH_FOLDER to get accounts defined in CEMU
    :getCemuAccountsList

        pushd !savesFolder!
        
        for /F "delims=~" %%a in ('dir /S /B /A:D "80*" 2^>NUL') do (
            for /F "delims=~" %i in ("%%a") do (
                set "account=%%~nxi"
                echo !account!| findStr /R /I "^[8][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$" > NUL 2>&1 && (
                    REM : add to to list if it maches the patern and if not already listed
                    echo !cemuAccountsList! | find /V "!account!" > NUL 2>&1 && set "cemuAccountsList=!cemuAccountsList! !account!"
                )
            )
        )
    
    goto:eof
    REM : ------------------------------------------------------------------


    :getWiiuUsers

        REM : loop on all 800000XX folders found
        pushd !ACCOUNTS_FOLDER!
        for /F "delims=~" %%d in ('dir /B /A:D 80000* 2^>NUL') do (

            set "af="!ACCOUNTS_FOLDER:"=!\%%d\account.dat""
            for /F "delims=~= tokens=2" %%n in ('type !af! ^| find /I "IsPasswordCacheEnabled=0"') do (
                echo WARNING^: this account seems to not have "Save password" option checked ^(auto login^) ^!
                echo it might be unusable with CEMU
                echo.
            )

            REM : get AccountId from account.dat
            set "accId=NONE"
            for /F "delims=~= tokens=2" %%n in ('type !af! ^| findStr /I /R "^AccountId=.*"') do set "accId=%%n"
            if ["%accId%"] == ["NONE"] (
                echo ERROR^: fail to parse !af!
                pause
            )

            echo Found %%d\account.dat for !accId!            
            
            REM : fill/complete the wiiuUsersLog
            if exist !wiiuUsersLog! (
                type !wiiuUsersLog! | find /V /I "%%d" > NUL 2>&1 && echo !accId!=%%d >> !wiiuUsersLog!
            ) else (
                echo # account=user > !wiiuUsersLog!
                echo !accId!=%%d >> !wiiuUsersLog!
            )
            
        )
        pushd !HERE!

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
