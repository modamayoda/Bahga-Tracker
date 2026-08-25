# =============================================================
# Uninstall.ps1
# Unregisters 5 Scheduled Tasks (including Watchdog),
# resets NTFS permissions, and logs output to uninstall_log.txt.
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

# 2. Load config for logRoot path
$logRoot = "C:\ActivityLogs"
$configFile = Join-Path $scriptSource "config.json"
if (-not (Test-Path $configFile)) {
    $configFile = Join-Path $logRoot "config.json"
}
if (Test-Path $configFile) {
    try {
        $configJson = Get-Content -Path $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($configJson.logRoot) { $logRoot = $configJson.logRoot }
    } catch {}
}

# 3. Helper Logging Function
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

    # --- Step 1: Unregister Scheduled Tasks ---
    Log-Message "`n1) Removing Scheduled Tasks..." "INFO" Cyan
    $tasks = @("ActivityLogger", "DailySummary", "WeeklyArchive", "LogBackup", "TaskWatchdog")
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

    # --- Step 2: Reset NTFS Permissions ---
    Log-Message "`n2) Resetting NTFS permissions on log directory..." "INFO" Cyan
    if (Test-Path $logRoot) {
        try {
            # Remove hidden/system attributes
            attrib -h -s $logRoot 2>&1 | Out-Null

            # Reset to inherited permissions
            $acl = Get-Acl $logRoot
            $acl.SetAccessRuleProtection($false, $true)  # Re-enable inheritance
            Set-Acl $logRoot $acl -ErrorAction Stop

            Log-Message "[OK] NTFS permissions reset to default (inheritance enabled)." "SUCCESS" Green
        } catch {
            Log-Message "[WARN] Could not reset permissions: $($_.Exception.Message)" "WARNING" Yellow
            Log-Message "You may need to manually adjust permissions on: $logRoot" "INFO" Gray
        }
    } else {
        Log-Message "[INFO] Log directory not found: $logRoot (already removed?)" "INFO" Gray
    }

    # --- SUMMARY ---
    Log-Message "`n===================================================" "INFO" Yellow
    Log-Message "              UNINSTALLATION SUMMARY               " "INFO" Yellow
    Log-Message "===================================================" "INFO" Yellow

    if ($successCount -eq $tasks.Count) {
        Log-Message "[OK] All $($tasks.Count) Scheduled Tasks have been successfully unregistered." "SUCCESS" Green
    } else {
        Log-Message "[!] $successCount/$($tasks.Count) tasks processed. Check details in: $uninstallLog" "WARNING" Yellow
    }

    Log-Message ""
    Log-Message "Note: Log files in '$logRoot' have NOT been deleted." "INFO" Cyan
    Log-Message "To completely remove all data, manually delete: $logRoot" "INFO" Gray
    Log-Message ""
    Log-Message "Log file saved at: $uninstallLog`n" "INFO" Gray

} catch {
    Log-Message "`n[FATAL ERROR] An unexpected error occurred: $($_.Exception.Message)" "ERROR" Red
    Log-Message "Stack Trace: $($_.ScriptStackTrace)" "ERROR" Red
} finally {
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Yellow
    Write-Host "  Press ENTER to close this window..." -ForegroundColor Yellow
    Write-Host "====================================================" -ForegroundColor Yellow
    Read-Host
}

# To completely delete the log directory as well (optional - uncomment lines below):
# Remove-Item $logRoot -Recurse -Force
