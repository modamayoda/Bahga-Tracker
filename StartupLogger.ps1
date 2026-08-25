# =============================================================
# StartupLogger.ps1
# Logs process creation/termination (Event ID 4688 / 4689).
# Filters out system processes and detects blacklisted apps.
# Appends to a daily CSV log file.
# =============================================================

# Load configuration
$logRoot    = "C:\ActivityLogs"
$configPath = Join-Path $logRoot "config.json"
$loaderPath = Join-Path $logRoot "ConfigLoader.ps1"

if (Test-Path $loaderPath) {
    . $loaderPath
    $cfg = Load-TrackerConfig -ConfigPath $configPath
    $logRoot = $cfg.logRoot
} else {
    # Minimal fallback if ConfigLoader is missing
    $cfg = @{
        excludeProcesses = @("svchost.exe","csrss.exe","System","smss.exe","services.exe","lsass.exe","conhost.exe","dllhost.exe")
        blacklistedApps  = @{}
        alerts           = @{ enabled = $false; logFile = "alerts.log" }
        logIntervalMinutes = 15
    }
}

New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

$todayFile = "$logRoot\process_log_$(Get-Date -Format 'yyyy-MM-dd').csv"

# Fetch events from the last interval
$intervalMinutes = $cfg.logIntervalMinutes
$newEntries = Get-WinEvent -FilterHashtable @{
    LogName   = 'Security'
    Id        = 4688, 4689
    StartTime = (Get-Date).AddMinutes(-$intervalMinutes)
} -ErrorAction SilentlyContinue | ForEach-Object {
    $xml  = [xml]$_.ToXml()
    $data = $xml.Event.EventData.Data
    [PSCustomObject]@{
        Time        = $_.TimeCreated
        EventType   = if ($_.Id -eq 4688) { "Opened" } else { "Closed" }
        ProcessName = ($data | Where-Object { $_.Name -eq 'NewProcessName' -or $_.Name -eq 'ProcessName' }).'#text'
        CommandLine = ($data | Where-Object { $_.Name -eq 'CommandLine' }).'#text'
        User        = ($data | Where-Object { $_.Name -eq 'SubjectUserName' }).'#text'
    }
}

if ($newEntries) {
    # --- Filter out system/excluded processes ---
    $excludeList = $cfg.excludeProcesses
    $filteredEntries = $newEntries | Where-Object {
        $procLeaf = Split-Path $_.ProcessName -Leaf -ErrorAction SilentlyContinue
        if (-not $procLeaf) { $procLeaf = $_.ProcessName }
        $procLeaf -notin $excludeList
    }

    # --- Detect blacklisted apps ---
    if ($cfg.alerts.enabled -and $cfg.blacklistedApps.Count -gt 0) {
        foreach ($entry in $filteredEntries) {
            if ($entry.EventType -ne "Opened") { continue }

            $procLeaf = Split-Path $entry.ProcessName -Leaf -ErrorAction SilentlyContinue
            if (-not $procLeaf) { $procLeaf = $entry.ProcessName }

            $category = Test-Blacklisted -ProcessName $procLeaf -BlacklistConfig $cfg.blacklistedApps
            if ($category) {
                Write-Alert -LogRoot $logRoot -AlertFile $cfg.alerts.logFile `
                    -Message "BLACKLISTED APP detected: '$procLeaf' (Category: $category, User: $($entry.User), Time: $($entry.Time))" `
                    -Severity "CRITICAL"
            }
        }
    }

    # --- Write filtered entries to CSV ---
    if ($filteredEntries) {
        if (Test-Path $todayFile) {
            $filteredEntries | Export-Csv -Path $todayFile -NoTypeInformation -Encoding UTF8 -Append
        } else {
            $filteredEntries | Export-Csv -Path $todayFile -NoTypeInformation -Encoding UTF8
        }
    }
}
