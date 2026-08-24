# =============================================================
# Install.ps1
# شغّله مرة واحدة بس، كأدمن (Run as Administrator)
# بيعمل كل حاجة: Audit Policy + الفولدر + تسجيل الـ 4 Tasks
# =============================================================

$logRoot = "C:\ActivityLogs"

Write-Host "1) بتفعيل Audit Policy..." -ForegroundColor Cyan
auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Process Termination" /success:enable | Out-Null

New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" `
    -Name "ProcessCreationIncludeCmdLine_Enabled" -Value 1 -Type DWord

Write-Host "2) بيعمل الفولدر ويخفيه..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

# نسخ السكريبتات من مكان التشغيل الحالي لمجلد اللوج
$scriptSource = Split-Path -Parent $MyInvocation.MyCommand.Path
Copy-Item "$scriptSource\StartupLogger.ps1" "$logRoot\StartupLogger.ps1" -Force
Copy-Item "$scriptSource\DailySummary.ps1"  "$logRoot\DailySummary.ps1"  -Force
Copy-Item "$scriptSource\WeeklyArchive.ps1" "$logRoot\WeeklyArchive.ps1" -Force
Copy-Item "$scriptSource\BackupLogs.ps1"    "$logRoot\BackupLogs.ps1"    -Force

attrib +h +s $logRoot

Write-Host "3) بيسجل الـ Scheduled Tasks..." -ForegroundColor Cyan
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# --- Task 1: تسجيل النشاط كل 15 دقيقة (يبدأ عند الإقلاع كمان) ---
$actLog = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$logRoot\StartupLogger.ps1`""
$trigLog1 = New-ScheduledTaskTrigger -AtStartup
$trigLog2 = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration ([TimeSpan]::MaxValue)
Register-ScheduledTask -TaskName "ActivityLogger" -Action $actLog `
    -Trigger $trigLog1, $trigLog2 -Principal $principal -Force `
    -Description "يسجل فتح وقفل البرامج كل 15 دقيقة" | Out-Null

# --- Task 2: ملخص يومي الساعة 23:55 ---
$actSum = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$logRoot\DailySummary.ps1`""
$trigSum = New-ScheduledTaskTrigger -Daily -At "23:55"
Register-ScheduledTask -TaskName "DailySummary" -Action $actSum `
    -Trigger $trigSum -Principal $principal -Force `
    -Description "ملخص يومي لعدد مرات فتح كل برنامج" | Out-Null

# --- Task 3: أرشفة أسبوعية كل يوم أحد الساعة 3 الفجر ---
$actArc = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$logRoot\WeeklyArchive.ps1`""
$trigArc = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "03:00"
Register-ScheduledTask -TaskName "WeeklyArchive" -Action $actArc `
    -Trigger $trigArc -Principal $principal -Force `
    -Description "ضغط ملفات اللوج الأقدم من أسبوع" | Out-Null

# --- Task 4: باك أب كل ساعة (لو الفلاشة متوصلة) ---
$actBak = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$logRoot\BackupLogs.ps1`""
$trigBak = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration ([TimeSpan]::MaxValue)
Register-ScheduledTask -TaskName "LogBackup" -Action $actBak `
    -Trigger $trigBak -Principal $principal -Force `
    -Description "نسخ احتياطي للوج على مسار خارجي" | Out-Null

Write-Host "`nتم التركيب بنجاح! اللوج هيتسجل في: $logRoot" -ForegroundColor Green
