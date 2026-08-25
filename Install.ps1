# =============================================================
# Install.ps1
# Run once as Administrator.
# Performs setup: Audit Policy + Log Folder + 4 Scheduled Tasks
# Logs all output and errors to install_log.txt
# =============================================================

$ErrorActionPreference = "Continue"

# 1. Resolve Script Source Directory safely
$scriptSource = $PSScriptRoot
if (-not $scriptSource) {
    if ($MyInvocation.MyCommand.Path) {
        $scriptSource = Split-Path -Parent $MyInvocation.MyCommand.Path
    } else {
        $scriptSource = (Get-Location).Path
    }
}
$installLog = Join-Path $scriptSource "install_log.txt"

# 2. Helper Logging Function
function Log-Message {
    param (
        [string]$Message,
        [string]$Level = "INFO", # INFO, SUCCESS, WARNING, ERROR
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    $time = Get-Date -Format "HH:mm:ss"
    $logLine = "[$time] [$Level] $Message"
    
    try {
        $logLine | Out-File -FilePath $installLog -Append -Encoding UTF8
    } catch {
        # Fallback if writing to log file fails
    }
    
    Write-Host $Message -ForegroundColor $Color
}

try {
    # Initialize Log File
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "===================================================" | Out-File -FilePath $installLog -Encoding UTF8
    "Bahga Tracker Installation Log - $timestamp"          | Out-File -FilePath $installLog -Append -Encoding UTF8
    "===================================================" | Out-File -FilePath $installLog -Append -Encoding UTF8

    $summary = [System.Collections.Generic.List[string]]::new()
    $hasError = $false

    Log-Message "Starting Bahga Tracker Installation..." "INFO" Cyan
    Log-Message "Script Directory: $scriptSource" "INFO" Gray

    # --- Check Administrator Privileges ---
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Log-Message "ERROR: Script is not running with Administrator privileges!" "ERROR" Red
        Log-Message "Please right click Install.bat and select 'Run as Administrator'." "ERROR" Yellow
        $summary.Add("[FAIL] Administrator privileges check failed")
        $hasError = $true
        return
    }

    # --- Step 1: Audit Policy ---
    Log-Message "`n1) Enabling Audit Policy..." "INFO" Cyan
    try {
        # Try GUID first (works on all Windows display languages), fallback to subcategory name
        $audit1 = auditpol /set /subcategory:"{0CCE922B-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable 2>&1
        if ($LASTEXITCODE -ne 0) {
            $audit1 = auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable 2>&1
        }
        Log-Message "AuditPol (Process Creation): $audit1" "INFO" Gray

        $audit2 = auditpol /set /subcategory:"{0CCE922C-69AE-11D9-BED3-505054503030}" /success:enable 2>&1
        if ($LASTEXITCODE -ne 0) {
            $audit2 = auditpol /set /subcategory:"Process Termination" /success:enable 2>&1
        }
        Log-Message "AuditPol (Process Termination): $audit2" "INFO" Gray

        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" -Force -ErrorAction Stop | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" `
            -Name "ProcessCreationIncludeCmdLine_Enabled" -Value 1 -Type DWord -ErrorAction Stop | Out-Null
        
        Log-Message "[OK] Audit policies and Registry settings applied successfully." "SUCCESS" Green
        $summary.Add("[SUCCESS] Audit Policy & Registry configured")
    } catch {
        Log-Message "[FAIL] Error setting Audit Policy: $($_.Exception.Message)" "ERROR" Red
        $summary.Add("[FAIL] Audit Policy configuration")
        $hasError = $true
    }

    # --- Step 2: Create log directory and copy scripts ---
    $logRoot = "C:\ActivityLogs"
    Log-Message "`n2) Creating log directory ($logRoot) and copying scripts..." "INFO" Cyan
    try {
        New-Item -ItemType Directory -Path $logRoot -Force -ErrorAction Stop | Out-Null

        $filesToCopy = @("StartupLogger.ps1", "DailySummary.ps1", "WeeklyArchive.ps1", "BackupLogs.ps1")
        foreach ($file in $filesToCopy) {
            $src = Join-Path $scriptSource $file
            if (Test-Path $src) {
                Copy-Item $src "$logRoot\$file" -Force -ErrorAction Stop
                Log-Message "Copied: $file -> $logRoot\$file" "INFO" Gray
            } else {
                throw "Source file missing: $src"
            }
        }

        attrib +h +s $logRoot 2>&1 | Out-Null
        Log-Message "[OK] Directory created and scripts copied successfully." "SUCCESS" Green
        $summary.Add("[SUCCESS] Log Directory & Files setup")
    } catch {
        Log-Message "[FAIL] Error preparing log directory: $($_.Exception.Message)" "ERROR" Red
        $summary.Add("[FAIL] Log Directory & Files setup")
        $hasError = $true
    }

    # --- Step 3: Register Scheduled Tasks ---
    Log-Message "`n3) Registering Scheduled Tasks..." "INFO" Cyan
    try {
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

        # Task 1: ActivityLogger
        $actLog = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$logRoot\StartupLogger.ps1`""
        $trigLog1 = New-ScheduledTaskTrigger -AtStartup
        $trigLog2 = New-ScheduledTaskTrigger -Once -At (Get-Date) `
            -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration (New-TimeSpan -Days 3650)
        Register-ScheduledTask -TaskName "ActivityLogger" -Action $actLog `
            -Trigger $trigLog1, $trigLog2 -Principal $principal -Force -ErrorAction Stop | Out-Null
        Log-Message "Registered Scheduled Task: ActivityLogger" "SUCCESS" Green

        # Task 2: DailySummary
        $actSum = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$logRoot\DailySummary.ps1`""
        $trigSum = New-ScheduledTaskTrigger -Daily -At "23:55"
        Register-ScheduledTask -TaskName "DailySummary" -Action $actSum `
            -Trigger $trigSum -Principal $principal -Force -ErrorAction Stop | Out-Null
        Log-Message "Registered Scheduled Task: DailySummary" "SUCCESS" Green

        # Task 3: WeeklyArchive
        $actArc = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$logRoot\WeeklyArchive.ps1`""
        $trigArc = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "03:00"
        Register-ScheduledTask -TaskName "WeeklyArchive" -Action $actArc `
            -Trigger $trigArc -Principal $principal -Force -ErrorAction Stop | Out-Null
        Log-Message "Registered Scheduled Task: WeeklyArchive" "SUCCESS" Green

        # Task 4: LogBackup
        $actBak = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$logRoot\BackupLogs.ps1`""
        $trigBak = New-ScheduledTaskTrigger -Once -At (Get-Date) `
            -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 3650)
        Register-ScheduledTask -TaskName "LogBackup" -Action $actBak `
            -Trigger $trigBak -Principal $principal -Force -ErrorAction Stop | Out-Null
        Log-Message "Registered Scheduled Task: LogBackup" "SUCCESS" Green

        $summary.Add("[SUCCESS] 4 Scheduled Tasks registered")
    } catch {
        Log-Message "[FAIL] Error registering scheduled tasks: $($_.Exception.Message)" "ERROR" Red
        $summary.Add("[FAIL] Scheduled Tasks registration")
        $hasError = $true
    }

    # --- SUMMARY REPORT ---
    Log-Message "`n===================================================" "INFO" Yellow
    Log-Message "               INSTALLATION SUMMARY                " "INFO" Yellow
    Log-Message "===================================================" "INFO" Yellow

    foreach ($item in $summary) {
        if ($item -like "*[SUCCESS]*") {
            Log-Message $item "SUCCESS" Green
        } else {
            Log-Message $item "ERROR" Red
        }
    }

    if (-not $hasError) {
        Log-Message "`n[OK] Installation completed successfully!" "SUCCESS" Green
        Log-Message "Logs folder: $logRoot" "INFO" Cyan
    } else {
        Log-Message "`n[!] Installation completed with ERRORS." "ERROR" Red
        Log-Message "Please check details in: $installLog" "WARNING" Yellow
    }

    Log-Message "Log file saved at: $installLog`n" "INFO" Gray

} catch {
    Log-Message "`n[FATAL ERROR] An unexpected error occurred: $($_.Exception.Message)" "ERROR" Red
    Log-Message "Stack Trace: $($_.ScriptStackTrace)" "ERROR" Red
} finally {
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Yellow
    Write-Host "  Press ENTER to close this window..." -ForegroundColor Yellow
    Write-Host "====================================================" -ForegroundColor Yellow
    Read-Host
}
