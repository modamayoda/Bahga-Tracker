# =============================================================
# WeeklyArchive.ps1
# Compresses log, summary, and report files older than the
# configured threshold into a ZIP archive, then removes originals.
# Archive threshold is configured in config.json.
# Runs weekly (Sunday 03:00).
# =============================================================

# Load configuration
$logRoot    = "C:\ActivityLogs"
$configPath = Join-Path $logRoot "config.json"
$loaderPath = Join-Path $logRoot "ConfigLoader.ps1"

if (Test-Path $loaderPath) {
    . $loaderPath
    $cfg = Load-TrackerConfig -ConfigPath $configPath
    $logRoot       = $cfg.logRoot
    $daysThreshold = $cfg.archiveDaysThreshold
} else {
    $daysThreshold = 7
}

$archiveRoot = "$logRoot\Archive"
New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null

$oldFiles = Get-ChildItem -Path $logRoot -File |
    Where-Object {
        ($_.Name -like "process_log_*.csv" -or
         $_.Name -like "summary_*.txt" -or
         $_.Name -like "report_*.html") -and
        $_.LastWriteTime -lt (Get-Date).AddDays(-$daysThreshold)
    }

if ($oldFiles) {
    $zipName = "$archiveRoot\archive_$(Get-Date -Format 'yyyy-MM-dd').zip"
    Compress-Archive -Path $oldFiles.FullName -DestinationPath $zipName -Update
    $oldFiles | Remove-Item -Force
}

# Also clean up old watchdog marker files
Get-ChildItem -Path $logRoot -File -Filter ".watchdog_*" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$daysThreshold) } |
    Remove-Item -Force -ErrorAction SilentlyContinue
