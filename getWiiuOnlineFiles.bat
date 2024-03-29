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
    set "browseFolder="!RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""
    !cmdOw! @ /MAX > NUL 2>&1

    set "LOGS="!HERE:"=!\logs""
    if not exist !LOGS! mkdir !LOGS! > NUL 2>&1
    set "config="!LOGS:"=!\lastConfig.ini""    

    REM : set current char codeset
    call:setCharSet

    REM : search if Cemu2Wii-U is not already running
    set /A "nbI=0"
    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cmd.exe" ^| find /I /V "setup" ^| find /I "Cemu2Wii-U" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% GEQ 2 (
        echo ERROR^: Cemu2Wii-U is already^/still running^! Aborting^!
        wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "Cemu2Wii-U" | find /I /V "find" ^| find /I /V "setup"
        pause
        exit /b 100
    )

    REM : search if CEMU is not already running
    set /A "nbI=0"
    for /F "delims=~=" %%f in ('wmic process get Commandline 2^>NUL ^| find /I "cemu.exe" ^| find /I /V "find" /C') do set /A "nbI=%%f"
    if %nbI% GEQ 1 (
        echo ERROR^: CEMU is already^/still running^! Aborting^!
        wmic process get Commandline 2>NUL | find /I "CEMU.exe" | find /I /V "find"
        pause
        exit /b 100
    )

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
    echo - launch WiiU FTP Server and press B to mount NAND paths
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
    set "CCERTS_FOLDER="!ONLINE_FOLDER:"=!\mlc01\sys\title\0005001b\10054000\content\ccerts""
    mkdir !CCERTS_FOLDER! > NUL 2>&1

    set "SCERTS_FOLDER="!ONLINE_FOLDER:"=!\mlc01\sys\title\0005001b\10054000\content\scerts""
    mkdir !SCERTS_FOLDER! > NUL 2>&1

    set "MIIH_FOLDER="!ONLINE_FOLDER:"=!\mlc01\sys\title\0005001b\10056000""
    mkdir !MIIH_FOLDER! > NUL 2>&1

    set "JFL_FOLDER="!ONLINE_FOLDER:"=!\mlc01\sys\title\00050030\1001500A""
    set "UFL_FOLDER="!ONLINE_FOLDER:"=!\mlc01\sys\title\00050030\1001510A""
    set "EFL_FOLDER="!ONLINE_FOLDER:"=!\mlc01\sys\title\00050030\1001520A""

    echo Launching FTP transferts^.^.^.

    REM : run ftp transferts ^:
    echo.
    echo =========================================================
    echo - CCERTS
    echo ---------------------------------------------------------
    !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local -mirror "!CCERTS_FOLDER!" /storage_mlc/sys/title/0005001b/10054000/content/ccerts" "exit"
    echo.
    echo ---------------------------------------------------------
    echo - SCERTS
    echo ---------------------------------------------------------
    !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local -mirror "!SCERTS_FOLDER!" /storage_mlc/sys/title/0005001b/10054000/content/scerts" "exit"
    echo.
    echo ---------------------------------------------------------
    echo - MIIs Head
    echo ---------------------------------------------------------
    !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local -mirror "!MIIH_FOLDER!" /storage_mlc/sys/title/0005001b/10056000" "exit"
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
    mkdir !JFL_FOLDER! > NUL 2>&1
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local -mirror "!JFL_FOLDER!" /storage_mlc/sys/title/00050030/1001500A" "exit"

    :US
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_mlc/sys/title/00050030/1001510A" "exit" > !ftplogFile! 2>&1
    type !ftplogFile! | find /I "Could not retrieve directory listing" > NUL 2>&1 && (
        goto:EU
    )
    echo.
    echo found USA one
    mkdir !UFL_FOLDER! > NUL 2>&1
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local -mirror "!UFL_FOLDER!" /storage_mlc/sys/title/00050030/1001510A" "exit"

    :EU
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "ls /storage_mlc/sys/title/00050030/1001520A" "exit" > !ftplogFile! 2>&1
    type !ftplogFile! | find /I "Could not retrieve directory listing" > NUL 2>&1 && (
        goto:getAccounts
    )
    echo found EUR one
    mkdir !EFL_FOLDER! > NUL 2>&1
    !winScp! /command "option batch on" "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local -mirror "!EFL_FOLDER!" /storage_mlc/sys/title/00050030/1001520A" "exit"

    :getAccounts
    echo.
    echo ---------------------------------------------------------
    echo - WII-U accounts
    echo ---------------------------------------------------------
    set "ACCOUNTS_FOLDER="!ONLINE_FOLDER:"=!\mlc01\usr\save\system\act""
    mkdir !ACCOUNTS_FOLDER! > NUL 2>&1

    !winScp! /command "open ftp://USER:PASSWD@!wiiuIp!/ -timeout=5 -rawsettings FollowDirectorySymlinks=1 FtpForcePasvIp2=0 FtpPingType=0" "synchronize local -mirror "!ACCOUNTS_FOLDER!" /storage_mlc/usr/save/system/act" "exit"

    echo.
    echo ---------------------------------------------------------
    echo - Identify Wii-U users and their accounts
    echo ---------------------------------------------------------
    set "wiiuUsersLog="!ONLINE_FOLDER:"=!\wiiuUsersList.log""
    del /F /S !wiiuUsersLog! > NUL 2>&1

    call:getWiiuUsers

    echo =========================================================
    choice /C yn /N /M "Do you want to install the files in a mlc01 folder (y, n)? : "
    if !ERRORLEVEL! EQU 2 goto:noMlcInstall

    set "config="!LOGS:"=!\lastConfig.ini""
    if exist !config! (
        for /F "delims=~= tokens=2" %%c in ('type !config! ^| find /I "MLC01_FOLDER_PATH" 2^>NUL') do set "MLC01_FOLDER_PATH=%%c"
        set "folder=!MLC01_FOLDER_PATH:"=!"
        choice /C yn /N /M "Use '!folder!' as MLC folder ? (y, n) : "
        if !ERRORLEVEL! EQU 2 goto:askMlc01Folder

        if exist !MLC01_FOLDER_PATH! (
            goto:installFiles
        ) else (
            echo Well^.^.^. !MLC01_FOLDER_PATH! does not exist anymore^!
            call:cleanConfigFile MLC01_FOLDER_PATH
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

    echo.
    echo =========================================================
    echo.
    echo Accounts found in !MLC01_FOLDER_PATH! ^:
    echo.
    echo ^> !cemuAccountsList!
    echo.
    if ["!accListToCreateInCemu!"] == [""] (
        echo.
        echo The following accounts will be updated ^:
        echo.
        type !wiiuUsersLog! | find /V "#"
        echo.
        choice /C yn /N /M "Continue (y, n)? : "
        if !ERRORLEVEL! EQU 2 (
            echo Cancelled by user
            goto:endMain
        )
        goto:overwriteFiles
    )

    echo The following Wii-U accounts does not exist on CEMU side ^:
    echo.
    for %%a in (!accListToCreateInCemu!) do echo ^> %%a
    echo.
    echo If you want to replace existing CEMU accounts with your Wii-U ones
    echo ^(and overwrite your saves with the Wii-U ones^)
    echo Use ^'Rename an account in a MLC folder^' first to rename accounts in
    echo !MLC01_FOLDER_PATH!
    echo with the Wii-U ones ^:
    echo.
    type !wiiuUsersLog! | find /V "#"
    echo.
    echo OR^,
    echo.
    echo You can choose to import them anyway but in this case^, note
    echo that you^'ll be able to play online using Cemu and continue^/synchronize
    echo your saves with the Wii-U ONLY with thoses accounts^!
    echo.
    echo.
    choice /C yn /N /M "Import Wii-U accounts in CEMU (y, n)? : "
    if !ERRORLEVEL! EQU 1 goto:overwriteFiles

    echo Use ^'Rename an account in a MLC folder^' and relaunch this script^.
    echo.

    goto:endMain

    :overwriteFiles
    REM : Wii-U accounts exists in CEMU side
    robocopy !srcFolder! !MLC01_FOLDER_PATH! /S /MT:32 /IS /IT

    :noMlcInstall
    if not ["!accListToCreateInCemu!"] == [""] (
        echo =========================================================
        echo.
        echo Don^'t forget to enable online mode for the following accounts
        echo and users in all your CEMU installs ^:
        echo.
        for %%a in (!accListToCreateInCemu!) do (
            type !wiiuUsersLog! | find /V "#" | find /I "%%a"
        )
        echo.
    )
    :endMain
    echo =========================================================
    echo.
    echo Done
    echo.

    echo Don^'t foget to ^:
    echo - enable online mode for new accounts
    echo - add opt^.bin and seeprom^.bin ^(dumped from
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


    REM : check if Wii-U accounts need to be defined in CEMU
    :getUndefinedWiiuAccounts

        pushd !ACCOUNTS_FOLDER!
        for /F "delims=~" %%a in ('dir /B /A:D "80*" 2^>NUL') do (
            set "account=%%a"
            set /A "accountValid=1"
            echo !account!| findStr /R /V "^[8][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$" > NUL 2>&1 && set /A "accountValid=0"

            if !accountValid! EQU 1 (
                REM : check if it is listed in cemuAccountsList
                echo !cemuAccountsList! | find /V "!account!" > NUL 2>&1 && set "accListToCreateInCemu=!accListToCreateInCemu! !account!"
            )
        )
    goto:eof
    REM : ------------------------------------------------------------------


    REM : scan MLC01_FOLDER_PATH to get accounts defined in CEMU
    :getCemuAccountsList

        REM : search in usr\save\system\act
        set "CemuAccountsFolder="!MLC01_FOLDER_PATH:"=!\usr\save\system\act""

        if exist !CemuAccountsFolder! (

            pushd !CemuAccountsFolder!

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


    :getWiiuUsers

        REM : loop on all 800000XX folders found
        pushd !ACCOUNTS_FOLDER!
        for /F "delims=~" %%d in ('dir /B /A:D 80000* 2^>NUL') do (

            set "af="!ACCOUNTS_FOLDER:"=!\%%d\account.dat""
            for /F "delims=~= tokens=2" %%n in ('type !af! ^| find /I "IsPasswordCacheEnabled=0"') do (
                echo WARNING^: this account seems to not have "Save password" option checked ^(auto login^) ^!
                echo it might be unusable with CEMU^!
                echo.
                echo Check "Save password" option for %%d account on the Wii-U and relaunch this script
                echo.
                pause
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
                echo # user=account > !wiiuUsersLog!
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
