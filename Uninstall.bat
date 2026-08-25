@echo off
setlocal EnableDelayedExpansion

title Bahga Tracker Uninstaller

:: =============================================================
:: Uninstall.bat - Robust launcher for Windows 10/11
:: Right-click -> Run as Administrator
:: =============================================================

echo ===================================================
echo           Bahga Tracker Uninstaller                
echo ===================================================
echo.

:: 1. Resolve paths
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "PS_SCRIPT=%SCRIPT_DIR%\Uninstall.ps1"
set "LOG_FILE=%SCRIPT_DIR%\uninstall_log.txt"

echo [INFO] Script directory: %SCRIPT_DIR%
echo.

:: 2. Verify Uninstall.ps1 exists
if not exist "%PS_SCRIPT%" (
    echo ===================================================
    echo [ERROR] Uninstall.ps1 not found!
    echo [ERROR] Expected at: %PS_SCRIPT%
    echo.
    echo Make sure all project files are in the same folder.
    echo ===================================================
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

:: 3. Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Not running as Administrator. Requesting elevation...
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "Start-Process cmd.exe -ArgumentList '/k cd /d \"%SCRIPT_DIR%\" && \"%~f0\"' -Verb RunAs"
    if !errorLevel! neq 0 (
        echo.
        echo [X] Could not elevate privileges or operation was cancelled.
        echo.
        echo Press any key to exit...
        pause >nul
    )
    exit /b
)

:: 4. Running as Administrator — change to script directory
cd /d "%SCRIPT_DIR%"
echo [OK] Running as Administrator.
echo.

:: 5. Run the PowerShell uninstaller
echo Starting PowerShell uninstaller...
echo ===================================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"

echo.
echo ===================================================
if exist "%LOG_FILE%" (
    echo Uninstallation log saved at:
    echo %LOG_FILE%
) else (
    echo [WARNING] No log file was created.
)
echo ===================================================
echo.
echo Press any key to exit...
pause >nul
