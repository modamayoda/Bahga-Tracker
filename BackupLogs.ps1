# =============================================================
# BackupLogs.ps1
# Copies log, summary, report, and archive files to an external
# path (USB drive / network) if available.
# Backup path is configured in config.json.
# =============================================================

# Load configuration
$logRoot    = "C:\ActivityLogs"
$configPath = Join-Path $logRoot "config.json"
$loaderPath = Join-Path $logRoot "ConfigLoader.ps1"

if (Test-Path $loaderPath) {
    . $loaderPath
    $cfg = Load-TrackerConfig -ConfigPath $configPath
    $logRoot    = $cfg.logRoot
    $backupPath = $cfg.backupPath
} else {
    $backupPath = "D:\ActivityBackup"
}

$driveRoot = Split-Path $backupPath -Qualifier
if (Test-Path $driveRoot) {
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

    # Copy CSV logs
    Copy-Item -Path "$logRoot\*.csv"  -Destination $backupPath -Force -ErrorAction SilentlyContinue
    # Copy TXT summaries
    Copy-Item -Path "$logRoot\*.txt"  -Destination $backupPath -Force -ErrorAction SilentlyContinue
    # Copy HTML reports
    Copy-Item -Path "$logRoot\*.html" -Destination $backupPath -Force -ErrorAction SilentlyContinue
    # Copy alert logs
    Copy-Item -Path "$logRoot\*.log"  -Destination $backupPath -Force -ErrorAction SilentlyContinue
    # Copy ZIP archives
    if (Test-Path "$logRoot\Archive") {
        $archiveBackup = Join-Path $backupPath "Archive"
        New-Item -ItemType Directory -Path $archiveBackup -Force | Out-Null
        Copy-Item -Path "$logRoot\Archive\*.zip" -Destination $archiveBackup -Force -ErrorAction SilentlyContinue
    }
}
