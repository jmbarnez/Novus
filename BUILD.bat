@echo off
REM Space Drone Adventure - Build Script
REM Creates a standalone .love file that can be distributed and run

setlocal enabledelayedexpansion

REM Colors for output
for /F %%a in ('copy /Z "%~f0" nul') do set "BS=%%a"

echo.
echo %BS%[92m=== Space Drone Adventure - LÖVE Build System ===%BS%[0m
echo.

REM Check if we're in the right directory
if not exist "conf.lua" (
    echo %BS%[91mError: conf.lua not found!%BS%[0m
    echo Please run this script from the project root directory.
    pause
    exit /b 1
)

echo %BS%[94mProject directory: %cd%%BS%[0m
echo.

REM Define paths
set OUTPUT_DIR=%cd%\dist
set OUTPUT_FILE=%OUTPUT_DIR%\space-drone-adventure.love
set LOVE_PATH=%PROGRAMFILES%\LÖVE

REM Create dist directory if it doesn't exist
if not exist "%OUTPUT_DIR%" (
    echo %BS%[93m[*] Creating dist directory...%BS%[0m
    mkdir "%OUTPUT_DIR%"
) else (
    echo %BS%[93m[*] Dist directory already exists%BS%[0m
)

REM Remove old .love file if it exists
if exist "%OUTPUT_FILE%" (
    echo %BS%[93m[*] Removing old build: %OUTPUT_FILE%%BS%[0m
    del "%OUTPUT_FILE%"
)

REM Check if 7-Zip is installed (preferred for .love files)
set HAVE_7ZIP=0
where 7z >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    set HAVE_7ZIP=1
    echo %BS%[92m[+] Found 7-Zip%BS%[0m
)

REM Check if PowerShell can compress (fallback)
set HAVE_POWERSHELL=0
where powershell >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    set HAVE_POWERSHELL=1
    if %HAVE_7ZIP% EQU 0 (
        echo %BS%[92m[+] Found PowerShell%BS%[0m
    )
)

echo.
echo %BS%[94m[*] Building project...%BS%[0m
echo.

REM Build using 7-Zip (preferred method)
if %HAVE_7ZIP% EQU 1 (
    echo %BS%[93m[*] Using 7-Zip to create .love file...%BS%[0m
    
    REM Add all files to the zip, using store method to preserve structure
    cd /d "%cd%"
    7z a -tzip "%OUTPUT_FILE%" "conf.lua" "main.lua" "README.md" "GEMINI.md" "docs\" "src\" "assets\" -r -x!".git" -x!"dist\" -x!"*.love"
    
    if !ERRORLEVEL! EQU 0 (
        echo %BS%[92m[+] Successfully created: %OUTPUT_FILE%%BS%[0m
    ) else (
        echo %BS%[91m[-] 7-Zip compression failed!%BS%[0m
        exit /b 1
    )
) else if %HAVE_POWERSHELL% EQU 1 (
    echo %BS%[93m[*] Using PowerShell to create .love file...%BS%[0m
    
    REM Create a temporary directory for zipping
    set TEMP_ZIP=%OUTPUT_DIR%\temp_archive.zip
    if exist "!TEMP_ZIP!" del "!TEMP_ZIP!"
    
    REM Use PowerShell's Compress-Archive
    powershell -Command "Compress-Archive -Path 'conf.lua','main.lua','README.md','GEMINI.md','docs','src','assets' -DestinationPath '!TEMP_ZIP!' -Force"
    
    if !ERRORLEVEL! EQU 0 (
        ren "!TEMP_ZIP!" "space-drone-adventure.love"
        echo %BS%[92m[+] Successfully created: %OUTPUT_FILE%%BS%[0m
    ) else (
        echo %BS%[91m[-] PowerShell compression failed!%BS%[0m
        exit /b 1
    )
) else (
    echo %BS%[91m[-] Error: Neither 7-Zip nor PowerShell found!%BS%[0m
    echo Please install 7-Zip or ensure PowerShell is available.
    pause
    exit /b 1
)

echo.
echo %BS%[92m=== Build Complete! ===%BS%[0m
echo.
echo %BS%[96mOutput file: %OUTPUT_FILE%%BS%[0m
echo.
echo Next steps:
echo   1. Install LÖVE 11.3 from https://love2d.org if not already installed
echo   2. Double-click the .love file to run the game
echo   3. Or associate .love files with LÖVE to run by double-click
echo.
echo To associate .love files with LÖVE on Windows:
echo   Right-click a .love file ^> Open with ^> Choose another app ^> LÖVE
echo.

REM Optional: Verify the file size
if exist "%OUTPUT_FILE%" (
    for /f %%A in ('dir /b /s "%OUTPUT_FILE%"') do (
        set FILE_SIZE=%%~zA
    )
    
    setlocal enabledelayedexpansion
    set /a SIZE_MB=!FILE_SIZE! / 1048576
    if !SIZE_MB! EQU 0 (
        set /a SIZE_KB=!FILE_SIZE! / 1024
        echo %BS%[93mFile size: !SIZE_KB! KB%BS%[0m
    ) else (
        echo %BS%[93mFile size: !SIZE_MB! MB%BS%[0m
    )
)

echo.
echo %BS%[92m[+] Ready to play!%BS%[0m
echo.

pause
