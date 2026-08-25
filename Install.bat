@echo off
:: =============================================================
:: Install.bat - One-Click Installer for Bahga Tracker
:: Auto-elevates to Administrator and runs Install.ps1 with full logging
:: =============================================================

title Bahga Tracker Installer

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
echo           Bahga Tracker Setup Installer            
echo ===================================================
echo.
echo Running setup script and logging output...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0Install.ps1'"

echo.
echo ===================================================
echo Setup finished. If any error occurred, check:
echo %~dp0install_log.txt
echo ===================================================
echo.
echo Press any key to exit...
pause >nul

