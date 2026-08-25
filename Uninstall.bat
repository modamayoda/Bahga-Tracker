@echo off
:: =============================================================
:: Uninstall.bat - One-Click Uninstaller for Bahga Tracker
:: Auto-elevates to Administrator and runs Uninstall.ps1
:: =============================================================

title Bahga Tracker Uninstaller

:: Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Requesting Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
echo ===================================================
echo           Bahga Tracker Uninstaller                
echo ===================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall.ps1"
echo.
echo Press any key to exit...
pause >nul
