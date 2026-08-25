# =============================================================
# Uninstall.ps1
# Unregisters the 4 Scheduled Tasks and logs output to uninstall_log.txt.
# =============================================================

$ErrorActionPreference = "Continue"

# 1. Resolve Script Source Directory safely
$scriptSource = $PSScriptRoot
if (-not $scriptSource) {
    if ($MyInvocation.MyCommand.Path) {
        $scriptSource = Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        $scriptSource = (Get-Location).Path
    }
}
$uninstallLog = Join-Path $scriptSource "uninstall_log.txt"

# 2. Helper Logging Function
function Log-Message {
    param (
        [string]$Message,
        [string]$Level = "INFO",
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    $time = Get-Date -Format "HH:mm:ss"
    $logLine = "[$time] [$Level] $Message"
    try {
        $logLine | Out-File -FilePath $uninstallLog -Append -Encoding UTF8
    } catch {}
    Write-Host $Message -ForegroundColor $Color
}

try {
    # Initialize Log File
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "===================================================" | Out-File -FilePath $uninstallLog -Encoding UTF8
    "Bahga Tracker Uninstallation Log - $timestamp"        | Out-File -FilePath $uninstallLog -Append -Encoding UTF8
    "===================================================" | Out-File -FilePath $uninstallLog -Append -Encoding UTF8

    Log-Message "Starting Bahga Tracker Uninstallation..." "INFO" Cyan

    $tasks = @("ActivityLogger", "DailySummary", "WeeklyArchive", "LogBackup")
    $successCount = 0

    foreach ($task in $tasks) {
        try {
            $taskExists = Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue
            if ($taskExists) {
                Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction Stop
                Log-Message "[OK] Unregistered scheduled task: $task" "SUCCESS" Green
                $successCount++
            } else {
                Log-Message "[INFO] Scheduled task not found (already removed): $task" "INFO" Gray
                $successCount++
            }
        } catch {
            Log-Message "[FAIL] Error removing task '$task': $($_.Exception.Message)" "ERROR" Red
        }
    }

    Log-Message "`n===================================================" "INFO" Yellow
    Log-Message "              UNINSTALLATION SUMMARY               " "INFO" Yellow
    Log-Message "===================================================" "INFO" Yellow

    if ($successCount -eq $tasks.Count) {
        Log-Message "[OK] All Scheduled Tasks have been successfully unregistered." "SUCCESS" Green
    } else {
        Log-Message "[!] Some tasks could not be unregistered. Check details in: $uninstallLog" "WARNING" Yellow
    }

    Log-Message "Log file saved at: $uninstallLog`n" "INFO" Gray

} catch {
    Log-Message "`n[FATAL ERROR] An unexpected error occurred: $($_.Exception.Message)" "ERROR" Red
    Log-Message "Stack Trace: $($_.ScriptStackTrace)" "ERROR" Red
}

# To completely delete the log directory as well (optional - uncomment lines below):
# attrib -h -s "C:\ActivityLogs"
# Remove-Item "C:\ActivityLogs" -Recurse -Force


