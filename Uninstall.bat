@echo off
:: =============================================================
:: Uninstall.bat - One-Click Uninstaller for Bahga Tracker
:: Auto-elevates to Administrator and runs Uninstall.ps1 with logging
:: =============================================================

title Bahga Tracker Uninstaller

:: Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ===================================================
    echo [!] Requesting Administrator privileges...
    echo ===================================================
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    if %errorLevel% neq 0 (
        echo [X] Failed to elevate to Administrator or cancelled by user.
        echo.
        echo Press any key to exit...
        pause >nul
    )
    exit /b
)

cd /d "%~dp0"
echo ===================================================
echo           Bahga Tracker Uninstaller                
echo ===================================================
echo.
echo Running uninstall script and logging output...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0Uninstall.ps1'"

echo.
echo ===================================================
echo Uninstall process finished. Check log if needed:
echo %~dp0uninstall_log.txt
echo ===================================================
echo.
echo Press any key to exit...
pause >nul

