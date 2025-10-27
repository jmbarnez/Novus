@echo off
REM NOVUS - Developer Runner
REM Quickly launches the game from the current project folder

echo.
echo === NOVUS - Developer Mode ===
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
echo [*] Launching NOVUS in developer mode...
echo.

REM Create timestamp for this session
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "timestamp=%dt:~0,4%-%dt:~4,2%-%dt:~6,2%_%dt:~8,2%-%dt:~10,2%-%dt:~12,2%"

REM Log file path
set LOG_FILE=run_log.txt

REM Display session start info
echo.
echo ========================================
echo Session started: %timestamp%
echo Project directory: %cd%
echo LÖVE executable: %LOVE_EXE%
echo ========================================
echo.
echo [*] Output will be logged to: %LOG_FILE%
echo.

REM Log session start info
echo. >> run_log.txt
echo ======================================== >> run_log.txt
echo Session started: %timestamp% >> run_log.txt
echo Project directory: %cd% >> run_log.txt
echo LÖVE executable: %LOVE_EXE% >> run_log.txt
echo ======================================== >> run_log.txt
echo. >> run_log.txt
echo [*] Output will be logged to: %LOG_FILE% >> run_log.txt
echo. >> run_log.txt

REM Run the game and capture output to temp file, then display and log
echo Running: %LOVE_EXE% . %*
%LOVE_EXE% . %* > temp_game_output.txt 2>&1
set EXIT_CODE=%ERRORLEVEL%
echo Game exit code: %EXIT_CODE%

REM Check if temp file exists and show its contents
if exist temp_game_output.txt (
    echo Temp file exists, contents:
    type temp_game_output.txt
    echo.
    echo Appending to log...
    type temp_game_output.txt >> run_log.txt
    del temp_game_output.txt
) else (
    echo ERROR: temp_game_output.txt was not created!
)

REM Log and display session end
(
echo.
echo ----------------------------------------
if %EXIT_CODE% NEQ 0 (
    echo [!] Game exited with error code: %EXIT_CODE%
) else (
    echo [+] Game exited normally
)
echo Session ended: %timestamp%
echo ========================================
) | powershell -NoProfile -Command "$input | Tee-Object -FilePath '%LOG_FILE%' -Append"

REM Pause on error for debugging
if %EXIT_CODE% NEQ 0 (
    echo.
    echo [*] Output logged to: %LOG_FILE%
    echo This might indicate:
    echo   - A Lua syntax error in the code
    echo   - Missing assets or files
    echo   - LÖVE version compatibility issue
    echo.
    pause
)