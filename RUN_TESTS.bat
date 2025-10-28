@echo off
REM RUN_TESTS.bat - Run Lua test suite (Windows)
REM This script ensures it runs from the repository root, checks for 'lua' on PATH,
REM runs the test runner, prints results, and pauses so double-clicked windows stay open.

:: Change to the script directory (repository root when the batch file is in repo root)
pushd "%~dp0" >nul

setlocal
echo Running tests from %CD%

:: Check that 'lua' is available
where lua >nul 2>&1
if not errorlevel 1 (
    lua tests\run_tests.lua
) else (
    where luajit >nul 2>&1
    if not errorlevel 1 (
        luajit tests\run_tests.lua
    ) else (
        where love >nul 2>&1
        if not errorlevel 1 (
            echo 'lua' and 'luajit' not found but Love2D is available — running tests under Love2D.
            echo This will launch Love2D briefly to run tests and then exit.
            love .
        ) else (
            :: Try common installation locations for Love2D
            if exist "%ProgramFiles%\LOVE\love.exe" (
                echo Found Love2D at "%ProgramFiles%\LOVE\love.exe" — launching test runner.
                "%ProgramFiles%\LOVE\love.exe" tests\love_runner
            ) else if exist "%ProgramFiles(x86)%\LOVE\love.exe" (
                echo Found Love2D at "%ProgramFiles(x86)%\LOVE\love.exe" — launching test runner.
                "%ProgramFiles(x86)%\LOVE\love.exe" tests\love_runner
            ) else (
                echo ERROR: No suitable Lua interpreter found on PATH.
                echo Install Lua or LuaJIT and ensure 'lua' or 'luajit' is on PATH, or install Love2D to run tests via the engine.
                echo You can also run tests manually with your interpreter, e.g. C:\path\to\lua.exe tests\run_tests.lua
                pause
                popd >nul
                exit /b 1
            )
        )
    )
)
if errorlevel 1 (
    echo Some tests failed.
    pause
    popd >nul
    exit /b 1
)

echo Tests completed successfully.
pause
endlocal
popd >nul
