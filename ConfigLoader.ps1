# =============================================================
# ConfigLoader.ps1
# Loads configuration from config.json with safe fallback defaults.
# Dot-source this file in other scripts: . "$logRoot\ConfigLoader.ps1"
# =============================================================

function Load-TrackerConfig {
    param (
        [string]$ConfigPath
    )

    # Default configuration (fallback if config.json is missing or corrupt)
    $defaults = @{
        logRoot                = "C:\ActivityLogs"
        backupPath             = "D:\ActivityBackup"
        logIntervalMinutes     = 15
        summaryTime            = "23:55"
        archiveDaysThreshold   = 7
        backupIntervalHours    = 1
        excludeProcesses       = @(
            "svchost.exe", "csrss.exe", "System", "smss.exe", "wininit.exe",
            "services.exe", "lsass.exe", "RuntimeBroker.exe", "SearchIndexer.exe",
            "conhost.exe", "dllhost.exe", "taskhostw.exe", "spoolsv.exe",
            "fontdrvhost.exe", "WmiPrvSE.exe", "Memory Compression", "Registry",
            "System Idle Process", "dwm.exe", "sihost.exe", "ctfmon.exe",
            "SecurityHealthService.exe", "MsMpEng.exe", "NisSrv.exe",
            "SearchHost.exe", "StartMenuExperienceHost.exe", "TextInputHost.exe",
            "ShellExperienceHost.exe", "ApplicationFrameHost.exe",
            "SystemSettings.exe", "backgroundTaskHost.exe", "CompPkgSrv.exe",
            "audiodg.exe", "WUDFHost.exe", "dasHost.exe", "LsaIso.exe",
            "sgrmbroker.exe", "SgrmBroker.exe", "uhssvc.exe"
        )
        blacklistedApps        = @{
            games   = @("*steam*", "*epicgames*", "*minecraft*", "*fortnite*", "*roblox*", "*valorant*")
            social  = @("*telegram*", "*discord*", "*whatsapp*")
            vpn     = @("*vpn*", "*proxy*", "*tor.exe*", "*psiphon*")
            torrent = @("*utorrent*", "*bittorrent*", "*qbittorrent*")
        }
        alerts                 = @{ enabled = $true; logFile = "alerts.log" }
        antiTamper             = @{ setPermissions = $true; enableWatchdog = $true; watchdogIntervalMinutes = 30 }
    }

    # Try to load config.json
    if ($ConfigPath -and (Test-Path $ConfigPath)) {
        try {
            $jsonContent = Get-Content -Path $ConfigPath -Raw -Encoding UTF8
            $config = $jsonContent | ConvertFrom-Json

            # Convert JSON object to hashtable for easier access
            $result = @{}

            # Simple properties
            $result.logRoot              = if ($config.logRoot)              { $config.logRoot }              else { $defaults.logRoot }
            $result.backupPath           = if ($config.backupPath)           { $config.backupPath }           else { $defaults.backupPath }
            $result.logIntervalMinutes   = if ($config.logIntervalMinutes)   { $config.logIntervalMinutes }   else { $defaults.logIntervalMinutes }
            $result.summaryTime          = if ($config.summaryTime)          { $config.summaryTime }          else { $defaults.summaryTime }
            $result.archiveDaysThreshold = if ($config.archiveDaysThreshold) { $config.archiveDaysThreshold } else { $defaults.archiveDaysThreshold }
            $result.backupIntervalHours  = if ($config.backupIntervalHours)  { $config.backupIntervalHours }  else { $defaults.backupIntervalHours }

            # Arrays and objects
            $result.excludeProcesses = if ($config.excludeProcesses) {
                @($config.excludeProcesses)
            } else {
                $defaults.excludeProcesses
            }

            # Blacklisted apps — convert PSObject to hashtable
            if ($config.blacklistedApps) {
                $bl = @{}
                $config.blacklistedApps.PSObject.Properties | ForEach-Object {
                    $bl[$_.Name] = @($_.Value)
                }
                $result.blacklistedApps = $bl
            } else {
                $result.blacklistedApps = $defaults.blacklistedApps
            }

            # Alerts
            if ($config.alerts) {
                $result.alerts = @{
                    enabled = if ($null -ne $config.alerts.enabled) { $config.alerts.enabled } else { $true }
                    logFile = if ($config.alerts.logFile) { $config.alerts.logFile } else { "alerts.log" }
                }
            } else {
                $result.alerts = $defaults.alerts
            }

            # Anti-tamper
            if ($config.antiTamper) {
                $result.antiTamper = @{
                    setPermissions            = if ($null -ne $config.antiTamper.setPermissions) { $config.antiTamper.setPermissions } else { $true }
                    enableWatchdog            = if ($null -ne $config.antiTamper.enableWatchdog) { $config.antiTamper.enableWatchdog } else { $true }
                    watchdogIntervalMinutes   = if ($config.antiTamper.watchdogIntervalMinutes) { $config.antiTamper.watchdogIntervalMinutes } else { 30 }
                }
            } else {
                $result.antiTamper = $defaults.antiTamper
            }

            return $result
        } catch {
            # If JSON parsing fails, return defaults
            return $defaults
        }
    } else {
        return $defaults
    }
}

function Test-Blacklisted {
    param (
        [string]$ProcessName,
        [hashtable]$BlacklistConfig
    )

    # Returns the category name if blacklisted, or $null if clean
    foreach ($category in $BlacklistConfig.Keys) {
        foreach ($pattern in $BlacklistConfig[$category]) {
            if ($ProcessName -like $pattern) {
                return $category
            }
        }
    }
    return $null
}

function Write-Alert {
    param (
        [string]$LogRoot,
        [string]$AlertFile,
        [string]$Message,
        [string]$Severity = "WARNING"  # WARNING, CRITICAL, INFO
    )

    $alertPath = Join-Path $LogRoot $AlertFile
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$time] [$Severity] $Message"

    try {
        $line | Out-File -FilePath $alertPath -Append -Encoding UTF8
    } catch {
        # Silent fail — we don't want alert logging to break the main script
    }
}
