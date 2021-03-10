@echo off
setlocal EnableExtensions
REM : ------------------------------------------------------------------
REM : main
    setlocal EnableDelayedExpansion
    color 4F

    title fix formating issues on batch files

    REM : set current char codeset
    call:setCharSet

    set "THIS_SCRIPT=%~0"

    REM : directory of this script
    set "SCRIPT_FOLDER="%~dp0"" && set "HERE=!SCRIPT_FOLDER:\"="!"
    pushd %HERE%

    set "RESOURCES_PATH="%HERE:"=%\resources""
    set "fnrPath="!RESOURCES_PATH:"=!\fnr.exe""
    set "StartHiddenWait="!RESOURCES_PATH:"=!\vbs\StartHiddenWait.vbs""

    set "LOGS="%HERE:"=%\logs""
    if not exist !LOGS! mkdir !LOGS! > NUL 2>&1
    
    set "fixBatFilesLog="!LOGS:"=!\fixBatFiles.log""  
    REM : check if folder name contains forbiden character for batch file
    call:securePathForDos %HERE% SAFE_PATH
    
    if not [%HERE%] == [!SAFE_PATH!] (
        echo ERROR ^: please rename your folders to have this compatible path 
        echo !SAFE_PATH!
        pause
        exit 95
    )
            
    echo =========================================================
    REM : ------------------------------------------------------------------

    set "toBeRemoved=%HERE:"=%\"

    echo ^> Check bat files^.^.^.
    echo.
    
    REM : Convert all files to ANSI and set them readonly
    set "pat="*.bat""
    for /F "delims=~" %%f in ('dir /S /B !pat! ^| find /V "fixBatFile"') do (

        set "filePath="%%f""

        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        echo ^> !filePath:%toBeRemoved%=!
        echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        echo - remove readonly attribute
        attrib -R !filePath! > NUL 2>&1

        echo - remove trailing spaces
        REM : file name
        for /F "delims=~" %%i in (!filePath!) do set "fileName=%%~nxi"

        REM : remove trailing space
        wscript /nologo !StartHiddenWait! !fnrPath! --cl --dir !PATH! --fileMask "!fileName!"  --includeSubDirectories --useRegEx --find "[ ]{1,}\r" --replace "" --logFile !fixBatFilesLog!

        echo - check file consistency
        call:checkFile

        echo - convert file to ANSI
        set "tmpFile=!filePath:.bat=.tmp!"
        type !filePath! > !tmpFile!
        del /F !filePath! > NUL 2>&1
        move /Y !tmpFile! !filePath! > NUL 2>&1

        echo - set readonly attribute
        attrib +R !filePath! > NUL 2>&1
    )

    echo.
    echo =========================================================
    echo done
    echo.

    pause
    exit /b 0

goto:eof

REM : ------------------------------------------------------------------
REM : functions

    REM : remove DOS forbiden character from a path
    :securePathForDos
        REM : str is expected protected with double quotes
        set "string=%~1"
        
        echo "%~1" | find "*" > NUL 2>&1 && (
            echo ^* is not allowed in path
            set "string=!string:*=!"
        )

        echo "%~1" | find "(" > NUL 2>&1 && (
            echo ^( is not allowed in path
            set "string=!string:(=!"
        )
        echo "%~1" | find ")" > NUL 2>&1 && (
            echo ^) is not allowed in path
            set "string=!string:)=!"
        )
        if ["!string!"] == ["%~1"] (

            set "string=!string:&=!"
            set "string=!string:?=!"
            set "string=!string:\!=!"
            set "string=!string:%%=!"
            set "string=!string:^=!"
            set "string=!string:/=!"
            set "string=!string:>=!"
            set "string=!string:<=!"
            set "string=!string:|=!"

            REM : WUP restrictions
            set "string=!string:™=!"
            set "string=!string:®=!"
            set "string=!string:©=!"
            set "string=!string:É=E!"
            
        )
        set "%2="!string!""

    goto:eof
    REM : ------------------------------------------------------------------
    
    REM : function to get and set char set code for current host
    :setCharSet

        REM : get charset code for current HOST
        set "CHARSET=NOT_FOUND"
        for /F "tokens=2 delims=~=" %%f in ('wmic os get codeset /value 2^>NUL ^| find "="') do set "CHARSET=%%f"

        if ["%CHARSET%"] == ["NOT_FOUND"] (
            echo Host char codeSet not found in %0 ^?
            pause
            exit /b 9
        )
        REM : set char code set, output to host log file

        chcp %CHARSET% > NUL 2>&1

    goto:eof
    REM : ------------------------------------------------------------------


    :checkFile

        type !filePath! | find /I "2>&1 set" && echo ERROR^: syntax error1 in !filePath!
        type !filePath! | find /I "goto::" && echo ERROR^: syntax error2 in !filePath!
        type !filePath! | find /I "call::" && echo ERROR^: syntax error3 in !filePath!
        type !filePath! | find /I ".bat.bat" && echo ERROR^: syntax error4 in !filePath!
        type !filePath! | find /I ":=" | find /V "::" && echo ERROR^: syntax error5 in !filePath!
        type !filePath! | find /I " TODO" && echo WARNING^: TODO found in !filePath!
        type !filePath! | find /I "echo OK" && echo WARNING^: unexpected debug traces^? in !filePath!

        set /A "wngDetected=0"
        REM : loop on ':' find in the file
        for /F "delims=:~ tokens=2" %%p in ('type !filePath! ^| find /I /V "REM" ^| find /I /V "echo" ^| find "   :" ^| find /V "=" ^| find /I /V "choice " ^| findStr /R "[A-Z]*" 2^>NUL') do (

            set "label=%%p"
            REM : search for "call:!label!" count occurences
            set /A "nbCall=0"
            for /F "delims=~" %%c in ('type !filePath! ^| find /I /C "call:!label: =!" 2^>NUL') do set /A "nbCall=%%c"

            REM : search for "goto:!label!" count occurences
            set /A "nbGoto=0"
            for /F "delims=~" %%c in ('type !filePath! ^| find /I /C "goto:!label: =!" 2^>NUL') do set /A "nbGoto=%%c"

            if !nbCall! EQU 0 if !nbGoto! EQU 0 (
                echo.
                echo WARNING ^: !label! not used in !filePath!
                set /A "wngDetected=1"
                pause
            )
            if !nbGoto! EQU 0 if !nbCall! EQU 0 if !wngDetected! EQU 0 (
                echo.
                echo WARNING ^: !label! not used in !filePath!
                set /A "wngDetected=1"
                pause
            )
        )
        if !wngDetected! EQU 1 timeout /T 3 > NUL 2>&1

    goto:eof