@echo off
setlocal EnableDelayedExpansion

title Bahga Tracker Uninstaller

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "PS_SCRIPT=%SCRIPT_DIR%\Uninstall.ps1"
set "LOG_FILE=%SCRIPT_DIR%\uninstall_log.txt"

echo ===================================================
echo           Bahga Tracker Uninstaller                
echo ===================================================
echo.

:: Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Requesting Administrator privileges...
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/k \"\"%~f0\"\"' -Verb RunAs"
    if !errorLevel! neq 0 (
        echo [X] Could not elevate privileges or operation was cancelled by user.
        echo [X] Elevation Error - Cancelled or failed > "%LOG_FILE%"
        echo.
        echo Press any key to exit...
        pause >nul
    )
    exit /b
)

:: Running as Administrator — change to script directory
cd /d "%SCRIPT_DIR%"
echo Running uninstaller script...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File "%PS_SCRIPT%"

echo.
echo ===================================================
echo Process completed. Check log if needed:
echo %LOG_FILE%
echo ===================================================
echo.
echo Press any key to exit...
pause >nul


