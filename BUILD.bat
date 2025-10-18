@echo off
REM Space Drone Adventure - Minimal Build Script
REM Builds a .love (LÖVE) package of the game

setlocal enabledelayedexpansion

REM Create dist directory if it doesn't exist
if not exist dist (
    mkdir dist
)

REM Remove old build
if exist dist\novus.love del /q dist\novus.love

REM Check if 7z is installed
where 7z >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo Using 7-Zip to create .love...
    7z a -tzip dist\novus.love conf.lua main.lua README.md docs\ src\ assets\ -r -x!dist -xr!*.love -xr!*.bat
    if exist dist\novus.love (
        echo Success! See dist\novus.love
    ) else (
        echo [Error] Failed to create .love file with 7-Zip.
    )
    goto :end
)

REM Fallback: use PowerShell
where powershell >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo Using PowerShell to create .love...
    powershell -Command "Compress-Archive -Path conf.lua,main.lua,README.md,docs,src,assets -DestinationPath dist/novus.zip -Force"
    if exist dist\novus.zip (
        rename dist\novus.zip novus.love
    )
    if exist dist\novus.love (
        echo Success! See dist\novus.love
    ) else (
        echo [Error] Failed to create .love file with PowerShell.
    )
    goto :end
)

echo [Error] Neither 7-Zip nor PowerShell Compress-Archive found. Please install 7-Zip.
:end
endlocal
