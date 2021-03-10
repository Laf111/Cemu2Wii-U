@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main

    setlocal EnableDelayedExpansion
    title Format large SDCard and install HBL and requiered app

    color 4F

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "HERE=!SCRIPT_FOLDER:\"="!"

    pushd !HERE!
    
    set "RESOURCES_PATH="!HERE:"=!\resources""
    set "ffat32="!RESOURCES_PATH:"=!\fat32format.exe""
    set "7za="!RESOURCES_PATH:"=!\7za.exe""
    set "browseFolder="!RESOURCES_PATH:"=!\vbs\BrowseFolderDialog.vbs""

    set "cmdOw="!RESOURCES_PATH:"=!\cmdOw.exe""
    !cmdOw! @ /MAX > NUL 2>&1
    
    set "LOGS="!HERE:"=!\logs""
    if not exist !LOGS! mkdir !LOGS! > NUL 2>&1

    REM : set current char codeset
    call:setCharSet
    cls

    echo =========================================================
    echo Prepare a SDcard for the Wii-U
    echo =========================================================
    echo.
    echo - format your device in FAT32 (32K clusters size)
    echo - install ^:
    echo       ^* HBL ^(HomeBrew Launcher^)
    echo       ^* appStore ^(HomeBrew AppStore^)
    echo       ^* DDD ^(WiiU Disk itle Dumper^)
    echo       ^* FTP everywhere for MOCHA ^(ftpiiu^)
    echo       ^* FTP everywhere for CBHC ^(ftpiiu^)
    echo       ^* nanddumper ^(to dump your NAND and get online files^)
    echo       ^* dumpling ^(dump your games^)
    echo.
    echo Once plugged in your Wii-U^, open the internet browser
    echo and enter the following adress ^: http^:^/^/wiiuexploit^.xyz
    echo ^(you might add this URL to your favorites^)
    echo.
    echo if your wiiu is connected to internet^, you can use
    echo appStore to update^/install other apps.
    echo.
    echo =========================================================
    echo.
    echo Close ALL windows explorer instances^, before continue
    echo.
    pause

    :askDrive
    set "SDCARD="NONE""
    for /F %%b in ('cscript /nologo !browseFolder! "Select the drive of your SDCard"') do set "folder=%%b" && set "SDCARD=!folder:?= !"
    if [!SDCARD!] == ["NONE"] (
        choice /C yn /N /M "No item selected, do you wish to cancel (y, n)? : "
        if !ERRORLEVEL! EQU 1 timeout /T 4 > NUL 2>&1 && exit 75
        goto:askDrive
    )

    for %%a in (!SDCARD!) do set "SDCARD=%%~da"
    :formatDrive
    REM : format %SDCARD% with fat32format.exe
    !ffat32! -c64 %SDCARD%
    if !ERRORLEVEL! NEQ 0 goto:formatDrive
    echo.
    echo ---------------------------------------------------------
    echo Installing content^.^.^.
    REM : install content
    set "sdCardContent="!RESOURCES_PATH:"=!\WiiuSDcard.zip""

    call !7za! x -y -aoa -w!LOGS! !sdCardContent! -o!SDCARD!
     
    echo done
    echo =========================================================

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
