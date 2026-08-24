# =============================================================
# WeeklyArchive.ps1
# يضغط ملفات اللوج والملخصات الأقدم من 7 أيام في ملف ZIP
# ويشيلها من المكان الأصلي بعد الضغط - يشتغل كل أسبوع
# =============================================================

$logRoot     = "C:\ActivityLogs"
$archiveRoot = "$logRoot\Archive"
New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null

$oldFiles = Get-ChildItem -Path $logRoot -File |
    Where-Object {
        ($_.Name -like "process_log_*.csv" -or $_.Name -like "summary_*.txt") -and
        $_.LastWriteTime -lt (Get-Date).AddDays(-7)
    }

if ($oldFiles) {
    $zipName = "$archiveRoot\archive_$(Get-Date -Format 'yyyy-MM-dd').zip"
    Compress-Archive -Path $oldFiles.FullName -DestinationPath $zipName -Update
    $oldFiles | Remove-Item -Force
}
