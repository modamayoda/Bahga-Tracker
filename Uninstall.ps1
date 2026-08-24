# =============================================================
# Uninstall.ps1
# بيشيل الـ 4 Tasks. لو عايز تمسح اللوج القديم كمان شيل التعليق تحت
# =============================================================

"ActivityLogger", "DailySummary", "WeeklyArchive", "LogBackup" | ForEach-Object {
    Unregister-ScheduledTask -TaskName $_ -Confirm:$false -ErrorAction SilentlyContinue
}

Write-Host "تم إلغاء تسجيل كل الـ Tasks." -ForegroundColor Yellow

# لمسح مجلد اللوج كله كمان (اختياري - شيل الـ # من السطرين دول):
# attrib -h -s "C:\ActivityLogs"
# Remove-Item "C:\ActivityLogs" -Recurse -Force
