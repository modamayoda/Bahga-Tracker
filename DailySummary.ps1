# =============================================================
# DailySummary.ps1
# يعمل ملخص نصي بسيط لعدد مرات فتح كل برنامج في اليوم
# يشتغل مرة كل يوم الساعة 23:55
# =============================================================

$logRoot     = "C:\ActivityLogs"
$todayFile   = "$logRoot\process_log_$(Get-Date -Format 'yyyy-MM-dd').csv"
$summaryFile = "$logRoot\summary_$(Get-Date -Format 'yyyy-MM-dd').txt"

if (Test-Path $todayFile) {
    $data = Import-Csv $todayFile

    $summary = $data | Where-Object { $_.EventType -eq "Opened" } |
        Group-Object ProcessName |
        Sort-Object Count -Descending |
        ForEach-Object { "$($_.Name): $($_.Count) مرة" }

    $header = "ملخص نشاط يوم $(Get-Date -Format 'yyyy-MM-dd')`r`n" + ("-" * 40)
    $header, $summary | Out-File -FilePath $summaryFile -Encoding UTF8
}
