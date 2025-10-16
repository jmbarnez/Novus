@echo off
REM Space Drone Adventure - Quick Build Script (Simple Version)
REM Creates a .love file without color codes for maximum compatibility

setlocal enabledelayedexpansion

echo.
echo === Space Drone Adventure - Quick Build ===
echo.

REM Check if we're in the right directory
if not exist "conf.lua" (
    echo Error: conf.lua not found!
    echo Please run this script from the project root directory.
    pause
    exit /b 1
)

echo Project directory: %cd%
echo.

REM Define paths
set OUTPUT_DIR=%cd%\dist
set OUTPUT_FILE=%OUTPUT_DIR%\space-drone-adventure.love

REM Create dist directory if it doesn't exist
if not exist "%OUTPUT_DIR%" (
    echo [*] Creating dist directory...
    mkdir "%OUTPUT_DIR%"
)

REM Remove old .love file if it exists
if exist "%OUTPUT_FILE%" (
    echo [*] Removing old build...
    del "%OUTPUT_FILE%"
)

echo [*] Building project...
echo.

REM Try 7-Zip first
where 7z >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [+] Using 7-Zip...
    7z a -tzip "%OUTPUT_FILE%" "conf.lua" "main.lua" "README.md" "GEMINI.md" "docs\" "src\" "assets\" -r -x!".git" -x!"dist\" -x!"*.love"
    goto :BuildComplete
)

REM Try PowerShell
where powershell >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [+] Using PowerShell...
    powershell -Command "Compress-Archive -Path 'conf.lua','main.lua','README.md','GEMINI.md','docs','src','assets' -DestinationPath '%OUTPUT_FILE%' -Force"
    goto :BuildComplete
)

echo [-] Error: Neither 7-Zip nor PowerShell found!
echo Please install 7-Zip or ensure PowerShell is available.
pause
exit /b 1

:BuildComplete
if %ERRORLEVEL% EQU 0 (
    echo.
    echo === Build Complete! ===
    echo.
    echo Output file: %OUTPUT_FILE%
    echo.
    echo To run the game:
    echo   - Double-click the .love file (if LÖVE is installed and associated)
    echo   - Or drag and drop it onto love.exe
    echo.
    echo To associate .love files with LÖVE:
    echo   - Download LÖVE 11.3 from https://love2d.org
    echo   - Right-click a .love file and select "Open with" LÖVE
    echo.
) else (
    echo.
    echo [-] Build failed!
    pause
    exit /b 1
)

pause
