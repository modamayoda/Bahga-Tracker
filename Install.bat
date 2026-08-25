@echo off
:: =============================================================
:: Install.bat - One-Click Installer for Bahga Tracker
:: Auto-elevates to Administrator and runs Install.ps1
:: =============================================================

title Bahga Tracker Installer

:: Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Requesting Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
echo ===================================================
echo           Bahga Tracker Setup Installer            
echo ===================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1"
echo.
echo Press any key to exit...
pause >nul
