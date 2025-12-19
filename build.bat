@echo off
setlocal EnableDelayedExpansion

set "ROOT=%~dp0"
set "ROOT_DIR=%ROOT:~0,-1%"
set "LOVE_DIR=%ROOT_DIR%\tools\love-windows"
set "LOVE_EXE=%LOVE_DIR%\love.exe"
set "DIST=%ROOT_DIR%\dist"
set "OUT=%DIST%\novus.love"
set "WINOUT=%DIST%\windows"
set "STAGE="
set "STAGE_BASE=%TEMP%\novus_stage_"
set "ERRMSG="
set "PS_LOG=%TEMP%\novus_build_ps_%RANDOM%%RANDOM%.log"
set "OUT_ZIP=%DIST%\novus.zip"

if not exist "%LOVE_EXE%" (
  set "ERRMSG=Build failed: could not find LOVE at %LOVE_EXE%"
  goto :fail
)

if not exist "%DIST%" mkdir "%DIST%" >nul

if exist "%OUT%" del /f /q "%OUT%" >nul
if exist "%OUT_ZIP%" del /f /q "%OUT_ZIP%" >nul

for /l %%i in (1,1,25) do (
  set "STAGE=%STAGE_BASE%!RANDOM!!RANDOM!"
  if not exist "!STAGE!" (
    mkdir "!STAGE!" >nul 2>&1
    if not errorlevel 1 goto :stage_ok
  )
)
set "ERRMSG=Build failed while creating staging folder in %TEMP%."
goto :fail

:stage_ok

robocopy "%ROOT_DIR%" "%STAGE%" /E /NFL /NDL /NJH /NJS /NP /XD ".git" ".windsurf" "tools" "dist" /XF "run.bat" "build.bat" >nul
if errorlevel 8 (
  set "ERRMSG=Build failed while staging files."
  goto :fail
)

if exist "%PS_LOG%" del /f /q "%PS_LOG%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Compress-Archive -Path (Join-Path $env:STAGE '*') -DestinationPath $env:OUT_ZIP -Force" 1>nul 2>"%PS_LOG%"
if errorlevel 1 (
  if exist "%PS_LOG%" type "%PS_LOG%"
  set "ERRMSG=Build failed while creating %OUT%."
  goto :fail
)

if exist "%PS_LOG%" del /f /q "%PS_LOG%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; for($i=0;$i -lt 20;$i++){ try { Move-Item -LiteralPath $env:OUT_ZIP -Destination $env:OUT -Force; exit 0 } catch { Start-Sleep -Milliseconds 200 } }; throw 'Move-Item failed'" 1>nul 2>"%PS_LOG%"
if errorlevel 1 (
  if exist "%PS_LOG%" type "%PS_LOG%"
  set "ERRMSG=Build failed while renaming %OUT_ZIP% to %OUT%"
  goto :fail
)

rmdir /s /q "%STAGE%" >nul 2>&1

if not exist "%WINOUT%" mkdir "%WINOUT%" >nul

robocopy "%LOVE_DIR%" "%WINOUT%" /E /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 (
  set "ERRMSG=Build failed while copying LOVE runtime files."
  goto :fail
)

copy /b "%LOVE_EXE%"+"%OUT%" "%WINOUT%\novus.exe" >nul
if errorlevel 1 (
  set "ERRMSG=Build failed while creating %WINOUT%\novus.exe"
  goto :fail
)

echo Built: %OUT%
echo Built: %WINOUT%\novus.exe

endlocal

exit /b 0

:fail
echo %ERRMSG%
if exist "%STAGE%" rmdir /s /q "%STAGE%" >nul 2>&1
endlocal
pause
exit /b 1
