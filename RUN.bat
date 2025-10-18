@echo off
REM Space Drone Adventure - Developer Runner
REM Quickly launches the game from the current project folder

echo.
echo === Space Drone Adventure - Developer Mode ===
echo.

REM Check if we're in the right directory
if not exist "conf.lua" (
    echo Error: conf.lua not found!
    echo Please run this script from the project root directory.
    pause
    exit /b 1
)

if not exist "main.lua" (
    echo Error: main.lua not found!
    echo Please run this script from the project root directory.
    pause
    exit /b 1
)

echo Project directory: %cd%
echo.

REM Check if LÖVE is installed
set LOVE_EXE=
where love >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    set LOVE_EXE=love
    echo [+] Found LÖVE in PATH
    goto :run_game
)

REM Try common installation paths
if exist "C:\Program Files\LOVE\love.exe" (
    set LOVE_EXE="C:\Program Files\LOVE\love.exe"
    echo [+] Found LÖVE at: C:\Program Files\LOVE\love.exe
    goto :run_game
)

if exist "C:\Program Files (x86)\LOVE\love.exe" (
    set LOVE_EXE="C:\Program Files (x86)\LOVE\love.exe"
    echo [+] Found LÖVE at: C:\Program Files (x86)\LOVE\love.exe
    goto :run_game
)

if exist "C:\Program Files\LÖVE\love.exe" (
    set LOVE_EXE="C:\Program Files\LÖVE\love.exe"
    echo [+] Found LÖVE at: C:\Program Files\LÖVE\love.exe
    goto :run_game
)

if exist "C:\Program Files (x86)\LÖVE\love.exe" (
    set LOVE_EXE="C:\Program Files (x86)\LÖVE\love.exe"
    echo [+] Found LÖVE at: C:\Program Files (x86)\LÖVE\love.exe
    goto :run_game
)

echo Error: LÖVE not found!
echo Please install LÖVE 11.3 from https://love2d.org
echo.
echo Common installation paths checked:
echo   - C:\Program Files\LOVE\love.exe
echo   - C:\Program Files (x86)\LOVE\love.exe
echo   - C:\Program Files\LÖVE\love.exe
echo   - C:\Program Files (x86)\LÖVE\love.exe
echo   - PATH environment variable
pause
exit /b 1

:run_game
echo.
echo [*] Launching Space Drone Adventure in developer mode...
echo.

REM Run the game
%LOVE_EXE% . %*

REM Check if the game exited with an error
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [!] Game exited with error code: %ERRORLEVEL%
    echo.
    echo This might indicate:
    echo   - A Lua syntax error in the code
    echo   - Missing assets or files
    echo   - LÖVE version compatibility issue
    echo.
    pause
) else (
    echo.
    echo [+] Game exited normally
)