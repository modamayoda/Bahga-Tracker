# =============================================================
# DailySummary.ps1
# Generates a text summary of application launch counts for the day.
# Runs daily at 23:55.
# =============================================================

$logRoot     = "C:\ActivityLogs"
$todayFile   = "$logRoot\process_log_$(Get-Date -Format 'yyyy-MM-dd').csv"
$summaryFile = "$logRoot\summary_$(Get-Date -Format 'yyyy-MM-dd').txt"

if (Test-Path $todayFile) {
    $data = Import-Csv $todayFile

    $summary = $data | Where-Object { $_.EventType -eq "Opened" } |
        Group-Object ProcessName |
        Sort-Object Count -Descending |
        ForEach-Object { "$($_.Name): $($_.Count) times" }

    $header = "Activity Summary for $(Get-Date -Format 'yyyy-MM-dd')`r`n" + ("-" * 40)
    $header, $summary | Out-File -FilePath $summaryFile -Encoding UTF8
}
