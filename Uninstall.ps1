# =============================================================
# Uninstall.ps1
# Unregisters the 4 Scheduled Tasks. Uncomment below to delete old logs.
# =============================================================

"ActivityLogger", "DailySummary", "WeeklyArchive", "LogBackup" | ForEach-Object {
    Unregister-ScheduledTask -TaskName $_ -Confirm:$false -ErrorAction SilentlyContinue
}

Write-Host "All Scheduled Tasks have been unregistered." -ForegroundColor Yellow

# To completely delete the log directory as well (optional - uncomment lines below):
# attrib -h -s "C:\ActivityLogs"
# Remove-Item "C:\ActivityLogs" -Recurse -Force
