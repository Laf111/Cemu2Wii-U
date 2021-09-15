@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion

    color 4F
    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "HERE=!SCRIPT_FOLDER:\"="!"

    set "RESOURCES_PATH="!HERE:"=!\resources""
    set "fnrPath="!RESOURCES_PATH:"=!\fnr.exe""
    set "cmdOw="!RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1
    
    set "syncFolder="!HERE:"=!\ftpSyncFolders.bat""
    set "importWiiuSaves="!HERE:"=!\importWiiuSaves.bat""

    set "Start="!RESOURCES_PATH:"=!\vbs\Start.vbs""
    set "StartMinimizedWait="!RESOURCES_PATH:"=!\vbs\StartMinimizedWait.vbs""
    set "StartHiddenWait="!RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""
    set "browseFolder="!RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""

    set "LOGS="!HERE:"=!\logs""
    if not exist !LOGS! mkdir !LOGS! > NUL 2>&1
    set "config="!LOGS:"=!\lastConfig.ini""    
    
    set "logFile="!LOGS:"=!\dumpGamesFromWiiU.log""
    set "rulesFiles="!LOGS:"=!\rulesFiles.log""

    set /A "totalMoCopied=0"

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
    
    REM : clean ftp logs
    set "pat="!LOGS:"=!\ftp*.log""
    del /F /S !pat! > NUL 2>&1

    REM : online files folders
    set "WIIU_FOLDER="!HERE:"=!\WiiuFiles""
    set "ONLINE_FOLDER="!WIIU_FOLDER:"=!\OnlineFiles""

    set "ACCOUNTS_FOLDER="!ONLINE_FOLDER:"=!\mlc01\usr\save\system\act""
    if not exist !ACCOUNTS_FOLDER! (
        echo ERROR^: !ACCOUNTS_FOLDER! does not exist ^!^
        echo Use Cemu2Wii-U^\Get online files^, update accounts from my Wii-U^.lnk
        echo or Cemu2Wii-U^\Scan my Wii-U^.lnk
        echo before this script
        pause
        exit /b 99
    )

    set "config="!LOGS:"=!\lastConfig.ini""
    if exist !config! (
        for /F "delims=~= tokens=2" %%c in ('type !config! ^| find /I "MLC01_FOLDER_PATH" 2^>NUL') do set "MLC01_FOLDER_PATH=%%c"
        set "folder=!MLC01_FOLDER_PATH:"=!"
        choice /C yn /N /M "Use '!folder!' as MLC folder ? (y, n) : "
        if !ERRORLEVEL! EQU 1 (
            if exist !MLC01_FOLDER_PATH! (
                goto:getGamesFolder
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

    call:cleanConfigFile MLC01_FOLDER_PATH
    echo MLC01_FOLDER_PATH=!MLC01_FOLDER_PATH!>!config!

    :getGamesFolder
    if exist !config! (
        for /F "delims=~= tokens=2" %%c in ('type !config! ^| find /I "GAMES_FOLDER=" 2^>NUL') do set "GAMES_FOLDER=%%c"
        set "folder=!GAMES_FOLDER:"=!"
        choice /C yn /N /M "Use '!folder!' as games folder ? (y, n) : "
        if !ERRORLEVEL! EQU 1 (
            if exist !GAMES_FOLDER! (
                goto:begin
            ) else (
                echo Well^.^.^. !GAMES_FOLDER! does not exist anymore^!
                call:cleanConfigFile MLC01_FOLDER_PATH
            )
        )
    )
    echo Please select a Games folder^.^.^.
    :askGamesFolder
    for /F %%b in ('cscript /nologo !browseFolder! "Select games folder"') do set "folder=%%b" && set "GAMES_FOLDER=!folder:?= !"

    if [!GAMES_FOLDER!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit /b 75
        goto:askGamesFolder
    )

    REM : update last configuration
    call:cleanConfigFile GAMES_FOLDER
    echo GAMES_FOLDER=!GAMES_FOLDER!>>!config!
    
    
    :begin
REM    cls
    title Dump games installed on your Wii-U
    echo =========================================================
    echo Dump games installed on your Wii-U
    echo =========================================================
    echo.
    echo WARNING ^: no check can be done on amount of data donwloaded^.
    @echo Be sure you have enough space left^!
    echo.
    echo BE AWARE ^: transfert errors on update and DLC files can occur
    echo on symlinks not handled by FTP server^.
    echo These files are not used by CEMU^.
    echo Just ignore those errors^.
    pause
    
    cls
    echo On your Wii-U^, you need to ^:
    echo - disable the sleeping^/shutdown features
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
        pause
        exit /b 2
    )

    set "ftplogFile="!LOGS:"=!\ftpCheck.log""
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

    REM : get last scan folder
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
        echo ERROR^: last scan results were not found
        pause
        exit /b 90
    )
    cls
    if !noOldScan! EQU 1 goto:getList

    echo The last WiiU^'s scan found is !LAST_SCAN!
    choice /C yn /N /M "Is it still up to date (y, n)? : "
    if !ERRORLEVEL! EQU 1 goto:getList

    rmdir /Q /S !WIIUSCAN_FOLDER!
    goto:scanMyWii
        
    REM : get title;endTitleId;source;dataFound from scan results
    :getList

    set "wiiuScanFolder="!WIIUSCAN_FOLDER:"=!\!LAST_SCAN:"=!""
    set "gamesList="!wiiuScanFolder:"=!\gamesList.csv""

    set "remoteSaves="!wiiuScanFolder:"=!\Saves.log""
    set "remoteUpdates="!wiiuScanFolder:"=!\Updates.log""
    set "remoteDlc="!wiiuScanFolder:"=!\Dlc.log""

    set /A "nbGames=0"
    
    cls
    echo =========================================================
    echo Games found on the Wii-U
    echo =========================================================
    REM : loop on games
    for /F "delims=~; tokens=1-4" %%i in ('type !gamesList! ^| find /V "title"') do (

        set "second=%%j"
        set "endTitleId=!second:'=!"

        set "titles[!nbGames!]=%%i"
        set "endTitlesId[!nbGames!]=!endTitleId!"
        set "titlesSrc[!nbGames!]=%%k"
        echo !nbGames!	: %%i

        set /A "nbGames+=1"
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

    REM : ask for saves import mode and set shutdownFlag accordingly
    set /A "shutdownFlag=0"
    call:getSavesUserMode userSavesToImport

    if !shutdownFlag! EQU 1 (
        choice /C yn /N /T 12 /D n /M "Shutdown !USERDOMAIN! when done (y, n : default in 12s)? : "
        if !ERRORLEVEL! EQU 2 (
            set /A "shutdownFlag=0"
        ) else (
            echo Please^, save all your opened documents before continue^.^.^.
            pause
        )
    )

    cls
    set /A "nbGamesSelected-=1"
    set "START_DATE="

    set /A "nbPass=1"
    call:loopOnGames

    cls
    echo Fix unexpected transfert errors with a 2nd pass^.^.^.
    echo.
    call:loopOnGames

    call:waitEndOfTransfers
    
    for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
    set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
    set "DATE=%ldt%"
    
    echo =========================================================
    echo Now you can stop FTPiiU server on you wii-U
    echo All transferts ended^, done
    echo - start ^: !START_DATE!
    echo - end   ^: !DATE!
    echo ---------------------------------------------------------
    
    echo =========================================================
    echo games dumped successfully ^(!totalMoCopied! Mb^)
    echo.

    pause
    
    exit 0

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


    :waitEndOfTransfers

        :waitingLoop
        REM : wait all transfert end
        timeout /T 1 > NUL 2>&1
        wmic process get Commandline 2>NUL | find /I "cmd.exe" | find /I "ftpSyncFolders.bat" | find /I /V "wmic" | find /I /V "find" > NUL 2>&1 && goto:waitingLoop

    goto:eof
    REM : ------------------------------------------------------------------

    :getSavesUserMode
        REM : init to none (choice number 1)
        set "%1=select"
        set /A "shutdownFlag=1"

        echo.
        echo Please select an import mode for Wii-U saves ^:
        echo.

        :getChoice
        echo    1 ^: import all saves for all user
        echo    2 ^: select what to do ^(per game and per user^)
        echo        ^(will interrupt the downloading process^)
        echo.
        choice /C 12 /N /M "Please, enter your choice : "
        set "userChoice=!ERRORLEVEL!"

        choice /C yn /N /M "Confirm choice !userChoice!? (y/n to cancel) : "
        if !ERRORLEVEL! EQU 2 goto:getChoice

        REM : handling choice
        if !userChoice! EQU 1 goto:eof

        if !userChoice! EQU 2 set "%1=all" & goto:eof

    goto:eof
    REM : ------------------------------------------------------------------

    :loopOnGames

        REM : loop on the games selected
        for /L %%i in (0,1,!nbGamesSelected!) do (

            set "GAME_TITLE=!selectedTitles[%%i]!"
            set "endTitleIdFolder=!selectedEndTitlesId[%%i]!"

            REM : define local folders
            set "targetFolder="!GAMES_FOLDER:"=!\!GAME_TITLE!""
            set "codeFolder="!targetFolder:"=!\code""
            set "contentFolder="!targetFolder:"=!\content""
            set "metaFolder="!targetFolder:"=!\meta""
            set "updateFolder="!MLC01_FOLDER_PATH:"=!\usr\title\0005000e\!endTitleIdFolder!""
            set "dlcFolder="!MLC01_FOLDER_PATH:"=!\usr\title\0005000c\!endTitleIdFolder!""

            call:createRequieredFolders > NUL 2>&1
            REM : dump the game by FTP
            call:getGame !selectedtitlesSrc[%%i]!
        )
        set /A "nbPass=nbPass+1"
    goto:eof
    REM : ------------------------------------------------------------------
    
    :getGame
        REM : source (mlc or usb)
        set "src=%~1"

        REM : get saves only the first pass
        if !nbPass! GTR 1 goto:importGame

        REM : get current date
        for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
        set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
        set "DATE=%ldt%"
        if ["!START_DATE!"] == [""] set "START_DATE=%ldt%"
        echo !GAME_TITLE! ^: starting at !DATE!
        echo ---------------------------------------------------------
        echo - dumping !GAME_TITLE! to !targetFolder!
        set "msg="!GAME_TITLE!: start downloading at !DATE! to=!targetFolder:"=!""
        call:log2GamesDownloadFile !msg!

        :importGame
        REM : Import the game (minimized + no wait)
        wscript /nologo !StartMinimizedWait! !syncFolder! !wiiuIp! local !codeFolder! "/storage_%src%/usr/title/00050000/!endTitleIdFolder!/code" "!name! (code)"

        wscript /nologo !StartMinimizedWait! !syncFolder! !wiiuIp! local !contentFolder! "/storage_%src%/usr/title/00050000/!endTitleIdFolder!/content" "!name! (content)"

        wscript /nologo !StartMinimizedWait! !syncFolder! !wiiuIp! local !metaFolder! "/storage_%src%/usr/title/00050000/!endTitleIdFolder!/meta" "!name! (meta)"

        call:waitEndOfTransfers

        REM : search if this game has an update
        set "srcRemoteUpdate=!remoteUpdates:SRC=%src%!"
        type !srcRemoteUpdate! | find "!endTitleIdFolder!" > NUL 2>&1 && (

            if !nbPass! EQU 1 echo - dumping update

            REM : YES : import update in mlc01/usr/title (minimized + no wait)
            wscript /nologo !StartMinimizedWait! !syncFolder! !wiiuIp! local !updateFolder! "/storage_%src%/usr/title/0005000e/!endTitleIdFolder!" "!name! (update)"
        )
        REM : search if this game has a DLC
        set "srcRemoteDlc=!remoteDlc:SRC=%src%!"
        type !srcRemoteDlc! | find "!endTitleIdFolder!" > NUL 2>&1 && (

            if !nbPass! EQU 1 echo - dumping DLC

            REM : YES : import dlc in mlc01/usr/title/0005000C/!endTitleIdFolder! (minimized + no wait)
            wscript /nologo !StartMinimizedWait! !syncFolder! !wiiuIp! local !dlcFolder! "/storage_%src%/usr/title/0005000c/!endTitleIdFolder!" "!name! (DLC)"
        )

        call:waitEndOfTransfers

        REM : get saves only the first pass
        if !nbPass! GTR 1 (

            REM : compute the game size (waitEndOfTransfers already call for game files)
            set /A "dumpSize=0"
            call:getFolderSizeInMb !targetFolder! dumpSize
            set /A "totalMoCopied+=!dumpSize!"
            goto:eof
        )
        
        REM : search if this game has saves
        set "srcRemoteSaves=!remoteSaves:SRC=%src%!"
        type !srcRemoteSaves! | find "!endTitleIdFolder!" > NUL 2>&1 && (
                echo - dumping saves
                wscript /nologo !StartMinimizedWait! !importWiiuSaves! !MLC01_FOLDER_PATH! !userSavesToImport!
            )
        )

        REM : get current date
        for /F "usebackq tokens=1,2 delims=~=" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set "ldt=%%j"
        set "ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%_%ldt:~8,2%-%ldt:~10,2%-%ldt:~12,6%"
        set "DATE=%ldt%"

        echo ---------------------------------------------------------
        echo !GAME_TITLE! ^: ending at !DATE!
        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        set "msg="!GAME_TITLE!: downloaded at !DATE!""
        call:log2GamesDownloadFile !msg!
        
    goto:eof
    REM : ------------------------------------------------------------------


    :getSmb
        set "sr=%~1"
        set /A "d=%~2"

        set /A "%3=!sr:~0,%d%!+1"
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

    :getFolderSizeInMb

        set "folder="%~1""
        REM : prevent path to be stripped if contain '
        set "folder=!folder:'=`'!"
        set "folder=!folder:[=`[!"
        set "folder=!folder:]=`]!"
        set "folder=!folder:)=`)!"
        set "folder=!folder:(=`(!"

        set "psCommand=-noprofile -command "ls -r -force '!folder:"=!' | measure -s Length""

        set "line=NONE"
        for /F "usebackq tokens=2 delims=:" %%a in (`powershell !psCommand! ^| find /I "Sum"`) do set "line=%%a"
        REM : powershell call always return %ERRORLEVEL%=0

        if ["!line!"] == ["NONE"] (
            set "%2=0"
            goto:eof
        )

        set "sizeRead=%line: =%"

        if ["!sizeRead!"] == [" ="] (
            set "%2=0"
            goto:eof
        )

        set /A "im=0"
        if not ["!sizeRead!"] == ["0"] (

            REM : compute length before switching to 32bits integers
            call:strLength !sizeRead! len
            REM : forcing Mb unit
            if !len! GTR 6 (
                set /A "dif=!len!-6"
                call:getSmb %sizeRead% !dif! smb
                set "%2=!smb!"
                goto:eof
            ) else (
                set "%2=1"
                goto:eof
            )
        )
        set "%2=0.0"

    goto:eof
    REM : ------------------------------------------------------------------
    
    REM : ------------------------------------------------------------------
    :createRequieredFolders

        REM : in all case
        set "gameFolder="!GAMES_FOLDER:"=!\!GAME_TITLE!""
        if not exist !gameFolder! mkdir !gameFolder! > NUL 2>&1
        set "cemuSaveFolder="!gameFolder:"=!\Cemu\inGameSaves""
        if not exist !cemuSaveFolder! mkdir !cemuSaveFolder! > NUL 2>&1

        if not exist !codeFolder! mkdir !codeFolder! > NUL 2>&1
        if not exist !contentFolder! mkdir !contentFolder! > NUL 2>&1
        if not exist !metaFolder! mkdir !metaFolder! > NUL 2>&1
        REM : updateFolder is created with dlc one
        if not exist !dlcFolder! mkdir !dlcFolder! > NUL 2>&1
    goto:eof

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

    REM : function to log
    :log2GamesDownloadFile
        REM : arg1 = msg
        set "msg=%~1"

        set "glogFile="!WIIU_FOLDER:"=!\gameDownloadHistory.log""

        echo !msg! >> !glogFile!

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

    