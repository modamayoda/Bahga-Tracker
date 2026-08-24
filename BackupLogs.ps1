# =============================================================
# BackupLogs.ps1
# ينسخ ملفات اللوج والملخصات لمسار خارجي (فلاشة / شبكة) لو متوصل
# غيّر $backupPath للمسار المناسب عندك
# =============================================================

$logRoot    = "C:\ActivityLogs"
$backupPath = "D:\ActivityBackup"   # <-- غيّر ده لمسار الفلاشة أو الشبكة

$driveRoot = Split-Path $backupPath -Qualifier
if (Test-Path $driveRoot) {
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    Copy-Item -Path "$logRoot\*.csv" -Destination $backupPath -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "$logRoot\*.txt" -Destination $backupPath -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "$logRoot\Archive\*.zip" -Destination $backupPath -Force -ErrorAction SilentlyContinue
}
