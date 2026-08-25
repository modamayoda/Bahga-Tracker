# =============================================================
# StartupLogger.ps1
# Logs process creation/termination (Event ID 4688 / 4689) every 15 minutes.
# Appends to a daily CSV log file.
# =============================================================

$logRoot = "C:\ActivityLogs"
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

$todayFile = "$logRoot\process_log_$(Get-Date -Format 'yyyy-MM-dd').csv"

$newEntries = Get-WinEvent -FilterHashtable @{
    LogName   = 'Security'
    Id        = 4688, 4689
    StartTime = (Get-Date).AddMinutes(-15)
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
    if (Test-Path $todayFile) {
        $newEntries | Export-Csv -Path $todayFile -NoTypeInformation -Encoding UTF8 -Append
    } else {
        $newEntries | Export-Csv -Path $todayFile -NoTypeInformation -Encoding UTF8
    }
}
