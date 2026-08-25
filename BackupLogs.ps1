# =============================================================
# BackupLogs.ps1
# Copies log and summary files to an external path (USB drive / network) if available.
# Update $backupPath to match your target backup path.
# =============================================================

$logRoot    = "C:\ActivityLogs"
$backupPath = "D:\ActivityBackup"   # <-- Change this to your USB drive or network path

$driveRoot = Split-Path $backupPath -Qualifier
if (Test-Path $driveRoot) {
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    Copy-Item -Path "$logRoot\*.csv" -Destination $backupPath -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "$logRoot\*.txt" -Destination $backupPath -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "$logRoot\Archive\*.zip" -Destination $backupPath -Force -ErrorAction SilentlyContinue
}
