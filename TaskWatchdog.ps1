# =============================================================
# TaskWatchdog.ps1
# Anti-tamper watchdog: verifies scheduled tasks and log directory
# exist and are intact. Logs alerts if tampering is detected.
# Runs every 30 minutes via Scheduled Task.
# =============================================================

$logRoot = "C:\ActivityLogs"
$configPath = Join-Path $logRoot "config.json"
$loaderPath = Join-Path $logRoot "ConfigLoader.ps1"

# Load config if available
if (Test-Path $loaderPath) {
    . $loaderPath
    $cfg = Load-TrackerConfig -ConfigPath $configPath
    $logRoot = $cfg.logRoot
}

$alertFile = Join-Path $logRoot "alerts.log"

function Log-WatchdogAlert {
    param ([string]$Message, [string]$Severity = "CRITICAL")
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$time] [WATCHDOG] [$Severity] $Message"
    try {
        $line | Out-File -FilePath $alertFile -Append -Encoding UTF8
    } catch {}
}

$expectedTasks = @("ActivityLogger", "DailySummary", "WeeklyArchive", "LogBackup", "TaskWatchdog")
$tamperedTasks = @()

foreach ($taskName in $expectedTasks) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if (-not $task) {
        $tamperedTasks += $taskName
        Log-WatchdogAlert "Scheduled task '$taskName' is MISSING! Possible tampering detected."
    } elseif ($task.State -eq 'Disabled') {
        $tamperedTasks += $taskName
        Log-WatchdogAlert "Scheduled task '$taskName' is DISABLED! Possible tampering detected."
    }
}

# Check log directory exists
if (-not (Test-Path $logRoot)) {
    Log-WatchdogAlert "Log directory '$logRoot' is MISSING! Possible tampering detected."
    # Attempt to recreate
    try {
        New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
        attrib +h +s $logRoot 2>&1 | Out-Null
        Log-WatchdogAlert "Log directory recreated successfully." "INFO"
    } catch {
        Log-WatchdogAlert "Failed to recreate log directory: $($_.Exception.Message)"
    }
}

# Check critical scripts exist in log directory
$requiredScripts = @("StartupLogger.ps1", "DailySummary.ps1", "WeeklyArchive.ps1", "BackupLogs.ps1", "ConfigLoader.ps1")
foreach ($script in $requiredScripts) {
    $scriptPath = Join-Path $logRoot $script
    if (-not (Test-Path $scriptPath)) {
        Log-WatchdogAlert "Script '$script' is MISSING from '$logRoot'! Possible tampering detected."
    }
}

# Summary
if ($tamperedTasks.Count -gt 0) {
    Log-WatchdogAlert "Tampering summary: $($tamperedTasks.Count) task(s) affected: $($tamperedTasks -join ', ')" "CRITICAL"
} else {
    # Only log a healthy check once per day to avoid flooding
    $todayMarker = Join-Path $logRoot ".watchdog_$(Get-Date -Format 'yyyy-MM-dd')"
    if (-not (Test-Path $todayMarker)) {
        Log-WatchdogAlert "All systems healthy. All tasks and files verified." "INFO"
        "" | Out-File -FilePath $todayMarker -Encoding UTF8
    }
}
