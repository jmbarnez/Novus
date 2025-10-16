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

echo Project directory: %cd%
echo.

REM Check if LÖVE is installed
where love >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    REM Try common installation paths
    if exist "C:\Program Files\LÖVE\love.exe" (
        set LOVE_EXE=C:\Program Files\LÖVE\love.exe
    ) else if exist "C:\Program Files (x86)\LÖVE\love.exe" (
        set LOVE_EXE=C:\Program Files (x86)\LÖVE\love.exe
    ) else (
        echo Error: LÖVE not found!
        echo Please install LÖVE 11.3 from https://love2d.org
        pause
        exit /b 1
    )
) else (
    set LOVE_EXE=love
)

echo [+] Found LÖVE: %LOVE_EXE%
echo.
echo [*] Launching Space Drone Adventure in developer mode...
echo.

REM Run the game
"%LOVE_EXE%" . %*

REM Check if the game exited with an error
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [!] Game exited with error code: %ERRORLEVEL%
    pause
)

