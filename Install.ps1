# =============================================================
# Install.ps1
# Run once as Administrator.
# Performs setup: Audit Policy + Log Folder + 4 Scheduled Tasks
# =============================================================

$logRoot = "C:\ActivityLogs"

Write-Host "1) Enabling Audit Policy..." -ForegroundColor Cyan
auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Process Termination" /success:enable | Out-Null

New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" `
    -Name "ProcessCreationIncludeCmdLine_Enabled" -Value 1 -Type DWord

Write-Host "2) Creating and hiding log directory..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

# Copy scripts from current directory to the log directory
$scriptSource = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Copy-Item "$scriptSource\StartupLogger.ps1" "$logRoot\StartupLogger.ps1" -Force
Copy-Item "$scriptSource\DailySummary.ps1"  "$logRoot\DailySummary.ps1"  -Force
Copy-Item "$scriptSource\WeeklyArchive.ps1" "$logRoot\WeeklyArchive.ps1" -Force
Copy-Item "$scriptSource\BackupLogs.ps1"    "$logRoot\BackupLogs.ps1"    -Force

attrib +h +s $logRoot

Write-Host "3) Registering Scheduled Tasks..." -ForegroundColor Cyan
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# --- Task 1: Record process activity every 15 minutes (starts at boot as well) ---
$actLog = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$logRoot\StartupLogger.ps1`""
$trigLog1 = New-ScheduledTaskTrigger -AtStartup
$trigLog2 = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration ([TimeSpan]::MaxValue)
Register-ScheduledTask -TaskName "ActivityLogger" -Action $actLog `
    -Trigger $trigLog1, $trigLog2 -Principal $principal -Force `
    -Description "Logs application start and termination events every 15 minutes" | Out-Null

# --- Task 2: Daily summary at 23:55 ---
$actSum = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$logRoot\DailySummary.ps1`""
$trigSum = New-ScheduledTaskTrigger -Daily -At "23:55"
Register-ScheduledTask -TaskName "DailySummary" -Action $actSum `
    -Trigger $trigSum -Principal $principal -Force `
    -Description "Daily summary of process launch counts" | Out-Null

# --- Task 3: Weekly archive every Sunday at 03:00 AM ---
$actArc = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$logRoot\WeeklyArchive.ps1`""
$trigArc = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "03:00"
Register-ScheduledTask -TaskName "WeeklyArchive" -Action $actArc `
    -Trigger $trigArc -Principal $principal -Force `
    -Description "Compresses log files older than one week" | Out-Null

# --- Task 4: Hourly backup (if external drive is connected) ---
$actBak = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$logRoot\BackupLogs.ps1`""
$trigBak = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration ([TimeSpan]::MaxValue)
Register-ScheduledTask -TaskName "LogBackup" -Action $actBak `
    -Trigger $trigBak -Principal $principal -Force `
    -Description "Backs up logs to an external location" | Out-Null

Write-Host "`nInstallation successful! Logs will be saved to: $logRoot" -ForegroundColor Green
