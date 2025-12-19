@echo off
setlocal

set "ROOT=%~dp0"
set "GAME_DIR=%ROOT:~0,-1%"
set "LOVE=%ROOT%tools\love-windows\lovec.exe"

if not exist "%LOVE%" (
  set "LOVE=%ROOT%tools\love-windows\love.exe"
)

if not exist "%LOVE%" (
  echo Could not find LÖVE executable.
  echo Expected: %ROOT%tools\love-windows\lovec.exe
  echo Or:       %ROOT%tools\love-windows\love.exe
  exit /b 1
)

"%LOVE%" "%GAME_DIR%"

endlocal
