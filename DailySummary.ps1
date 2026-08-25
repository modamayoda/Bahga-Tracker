# =============================================================
# DailySummary.ps1
# Generates daily usage reports in both TXT and HTML formats.
# Calculates app usage duration, categories, and includes alerts.
# Runs daily at 23:55.
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
    $cfg = @{
        blacklistedApps = @{}
        alerts = @{ enabled = $false; logFile = "alerts.log" }
    }
}

$todayStr    = Get-Date -Format 'yyyy-MM-dd'
$todayFile   = "$logRoot\process_log_$todayStr.csv"
$summaryFile = "$logRoot\summary_$todayStr.txt"
$htmlFile    = "$logRoot\report_$todayStr.html"

if (-not (Test-Path $todayFile)) { return }

$data = Import-Csv $todayFile -Encoding UTF8

# ─── Calculate usage stats ───────────────────────────────────

# Group by process name (leaf only)
$openEvents  = $data | Where-Object { $_.EventType -eq "Opened" }
$closeEvents = $data | Where-Object { $_.EventType -eq "Closed" }

$usageStats = @{}

foreach ($event in $openEvents) {
    $procLeaf = Split-Path $event.ProcessName -Leaf -ErrorAction SilentlyContinue
    if (-not $procLeaf) { $procLeaf = $event.ProcessName }
    # Skip empty names
    if (-not $procLeaf -or $procLeaf -eq '') { continue }

    if (-not $usageStats.ContainsKey($procLeaf)) {
        $usageStats[$procLeaf] = @{
            Name       = $procLeaf
            OpenCount  = 0
            TotalTime  = [timespan]::Zero
            Users      = [System.Collections.Generic.HashSet[string]]::new()
            Category   = "other"
        }
    }

    $usageStats[$procLeaf].OpenCount++

    if ($event.User) {
        $usageStats[$procLeaf].Users.Add($event.User) | Out-Null
    }

    # Try to find matching close event for duration
    $openTime = [datetime]$event.Time
    $matchClose = $closeEvents | Where-Object {
        $cl = Split-Path $_.ProcessName -Leaf -ErrorAction SilentlyContinue
        if (-not $cl) { $cl = $_.ProcessName }
        $cl -eq $procLeaf -and [datetime]$_.Time -gt $openTime
    } | Select-Object -First 1

    if ($matchClose) {
        $duration = [datetime]$matchClose.Time - $openTime
        if ($duration.TotalHours -lt 24) {
            $usageStats[$procLeaf].TotalTime += $duration
        }
    }

    # Check blacklist category
    if ($cfg.blacklistedApps -and $cfg.blacklistedApps.Count -gt 0) {
        $cat = $null
        foreach ($category in $cfg.blacklistedApps.Keys) {
            foreach ($pattern in $cfg.blacklistedApps[$category]) {
                if ($procLeaf -like $pattern) {
                    $cat = $category
                    break
                }
            }
            if ($cat) { break }
        }
        if ($cat) {
            $usageStats[$procLeaf].Category = $cat
        }
    }
}

# Sort by open count descending
$sortedStats = $usageStats.Values | Sort-Object { $_.OpenCount } -Descending

# ─── Generate TXT Summary ────────────────────────────────────

$txtLines = @()
$txtLines += "============================================"
$txtLines += "  Activity Summary for $todayStr"
$txtLines += "============================================"
$txtLines += ""
$txtLines += "Top Applications by Launch Count:"
$txtLines += ("-" * 44)

$rank = 1
foreach ($app in $sortedStats | Select-Object -First 20) {
    $durationStr = ""
    if ($app.TotalTime.TotalMinutes -ge 1) {
        $hours = [math]::Floor($app.TotalTime.TotalHours)
        $mins  = $app.TotalTime.Minutes
        $durationStr = " (${hours}h ${mins}m)"
    }
    $categoryTag = if ($app.Category -ne "other") { " [$($app.Category)]" } else { "" }
    $txtLines += "  ${rank}. $($app.Name): $($app.OpenCount) times${durationStr}${categoryTag}"
    $rank++
}

$txtLines += ""
$txtLines += "Total unique applications: $($sortedStats.Count)"
$txtLines += "Total launch events: $(($sortedStats | Measure-Object -Property OpenCount -Sum).Sum)"

# Check for today's alerts
$alertFile = Join-Path $logRoot $cfg.alerts.logFile
if (Test-Path $alertFile) {
    $todayAlerts = Get-Content $alertFile -Encoding UTF8 | Where-Object { $_ -like "*$todayStr*" -and $_ -like "*BLACKLISTED*" }
    if ($todayAlerts) {
        $txtLines += ""
        $txtLines += "!! ALERTS ($($todayAlerts.Count) blacklisted app detections) !!"
        foreach ($alert in $todayAlerts | Select-Object -First 10) {
            $txtLines += "  $alert"
        }
    }
}

$txtLines | Out-File -FilePath $summaryFile -Encoding UTF8

# ─── Generate HTML Report ─────────────────────────────────────

$totalLaunches = ($sortedStats | Measure-Object -Property OpenCount -Sum).Sum
if (-not $totalLaunches) { $totalLaunches = 0 }
$maxCount = if ($sortedStats.Count -gt 0) { ($sortedStats | Select-Object -First 1).OpenCount } else { 1 }

# Build chart bars HTML
$chartBarsHtml = ""
$top10 = $sortedStats | Select-Object -First 10
foreach ($app in $top10) {
    $pct = [math]::Round(($app.OpenCount / [math]::Max($maxCount, 1)) * 100)
    $durationStr = ""
    if ($app.TotalTime.TotalMinutes -ge 1) {
        $hours = [math]::Floor($app.TotalTime.TotalHours)
        $mins  = $app.TotalTime.Minutes
        $durationStr = "${hours}h ${mins}m"
    } else {
        $durationStr = "< 1m"
    }
    $catClass = if ($app.Category -ne "other") { "cat-$($app.Category)" } else { "" }
    $catBadge = if ($app.Category -ne "other") { "<span class='badge badge-$($app.Category)'>$($app.Category)</span>" } else { "" }

    $chartBarsHtml += @"
            <div class="chart-row">
                <div class="chart-label" title="$($app.Name)">$($app.Name)</div>
                <div class="chart-bar-container">
                    <div class="chart-bar $catClass" style="width: ${pct}%">
                        <span class="chart-value">$($app.OpenCount)x</span>
                    </div>
                </div>
                <div class="chart-duration">$durationStr $catBadge</div>
            </div>
"@
}

# Build full table rows
$tableRowsHtml = ""
$rowNum = 1
foreach ($app in $sortedStats) {
    $durationStr = ""
    if ($app.TotalTime.TotalMinutes -ge 1) {
        $hours = [math]::Floor($app.TotalTime.TotalHours)
        $mins  = $app.TotalTime.Minutes
        $durationStr = "${hours}h ${mins}m"
    } else {
        $durationStr = "< 1m"
    }
    $catBadge = if ($app.Category -ne "other") { "<span class='badge badge-$($app.Category)'>$($app.Category)</span>" } else { "-" }
    $usersStr = ($app.Users -join ", ")
    if (-not $usersStr) { $usersStr = "-" }

    $tableRowsHtml += @"
                <tr>
                    <td>$rowNum</td>
                    <td class="app-name">$($app.Name)</td>
                    <td>$($app.OpenCount)</td>
                    <td>$durationStr</td>
                    <td>$catBadge</td>
                    <td>$usersStr</td>
                </tr>
"@
    $rowNum++
}

# Build alerts section
$alertsSectionHtml = ""
if (Test-Path $alertFile) {
    $todayAlerts = Get-Content $alertFile -Encoding UTF8 | Where-Object { $_ -like "*$todayStr*" }
    if ($todayAlerts) {
        $alertItemsHtml = ""
        foreach ($a in $todayAlerts | Select-Object -First 20) {
            $alertItemsHtml += "                <div class='alert-item'>$([System.Web.HttpUtility]::HtmlEncode($a))</div>`n"
        }
        $alertsSectionHtml = @"
        <div class="card alerts-card">
            <h2>🚨 Alerts ($($todayAlerts.Count))</h2>
            <div class="alerts-list">
$alertItemsHtml
            </div>
        </div>
"@
    }
}

# Category counts
$catCounts = @{}
foreach ($app in $sortedStats) {
    if ($app.Category -ne "other") {
        if (-not $catCounts.ContainsKey($app.Category)) { $catCounts[$app.Category] = 0 }
        $catCounts[$app.Category] += $app.OpenCount
    }
}

$catStatsHtml = ""
if ($catCounts.Count -gt 0) {
    foreach ($cat in $catCounts.Keys | Sort-Object) {
        $catStatsHtml += "                <div class='stat-item'><span class='badge badge-$cat'>$cat</span> <strong>$($catCounts[$cat])</strong> launches</div>`n"
    }
}

$htmlContent = @"
<!DOCTYPE html>
<html lang="en" dir="ltr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bahga Tracker - Daily Report $todayStr</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');

        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background: #0a0a1a;
            color: #e0e0e0;
            min-height: 100vh;
            padding: 24px;
        }

        .container { max-width: 1100px; margin: 0 auto; }

        /* Header */
        .header {
            text-align: center;
            padding: 40px 24px;
            margin-bottom: 24px;
            background: linear-gradient(135deg, #1a1a3e 0%, #0d0d2b 50%, #1a0a2e 100%);
            border-radius: 16px;
            border: 1px solid rgba(255,255,255,0.06);
            position: relative;
            overflow: hidden;
        }
        .header::before {
            content: '';
            position: absolute;
            top: -50%; left: -50%;
            width: 200%; height: 200%;
            background: radial-gradient(circle, rgba(99,102,241,0.08) 0%, transparent 60%);
            animation: pulse 8s ease-in-out infinite;
        }
        @keyframes pulse {
            0%, 100% { transform: scale(1); opacity: 0.5; }
            50% { transform: scale(1.1); opacity: 1; }
        }
        .header h1 {
            font-size: 28px; font-weight: 700;
            background: linear-gradient(135deg, #818cf8, #c084fc, #f472b6);
            -webkit-background-clip: text; -webkit-text-fill-color: transparent;
            position: relative;
        }
        .header .date {
            color: #9ca3af; font-size: 15px; margin-top: 8px;
            position: relative;
        }

        /* Stats Grid */
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }
        .stat-card {
            background: linear-gradient(135deg, #1e1e3a, #161630);
            border: 1px solid rgba(255,255,255,0.06);
            border-radius: 12px;
            padding: 20px;
            text-align: center;
        }
        .stat-card .stat-number {
            font-size: 36px; font-weight: 700;
            background: linear-gradient(135deg, #60a5fa, #818cf8);
            -webkit-background-clip: text; -webkit-text-fill-color: transparent;
        }
        .stat-card .stat-label {
            font-size: 13px; color: #9ca3af; margin-top: 4px;
            text-transform: uppercase; letter-spacing: 0.5px;
        }

        /* Cards */
        .card {
            background: linear-gradient(135deg, #1e1e3a, #161630);
            border: 1px solid rgba(255,255,255,0.06);
            border-radius: 12px;
            padding: 24px;
            margin-bottom: 24px;
        }
        .card h2 {
            font-size: 18px; font-weight: 600;
            margin-bottom: 20px;
            color: #c4b5fd;
        }

        /* Chart */
        .chart-row {
            display: flex; align-items: center;
            margin-bottom: 10px; gap: 12px;
        }
        .chart-label {
            width: 160px; min-width: 160px;
            font-size: 13px; font-weight: 500;
            white-space: nowrap; overflow: hidden;
            text-overflow: ellipsis;
            color: #d1d5db;
        }
        .chart-bar-container {
            flex: 1; height: 28px;
            background: rgba(255,255,255,0.04);
            border-radius: 6px; overflow: hidden;
        }
        .chart-bar {
            height: 100%; border-radius: 6px;
            background: linear-gradient(90deg, #6366f1, #818cf8);
            display: flex; align-items: center;
            justify-content: flex-end; padding-right: 8px;
            min-width: 40px;
            transition: width 0.8s ease;
        }
        .chart-bar.cat-games { background: linear-gradient(90deg, #ef4444, #f87171); }
        .chart-bar.cat-social { background: linear-gradient(90deg, #f59e0b, #fbbf24); }
        .chart-bar.cat-vpn { background: linear-gradient(90deg, #dc2626, #991b1b); }
        .chart-bar.cat-torrent { background: linear-gradient(90deg, #9333ea, #a855f7); }
        .chart-value {
            font-size: 11px; font-weight: 600; color: #fff;
        }
        .chart-duration {
            width: 120px; min-width: 120px;
            font-size: 12px; color: #9ca3af; text-align: right;
        }

        /* Table */
        table {
            width: 100%; border-collapse: collapse;
            font-size: 13px;
        }
        th {
            text-align: left; padding: 12px 10px;
            border-bottom: 2px solid rgba(99,102,241,0.3);
            color: #a5b4fc; font-weight: 600;
            text-transform: uppercase; font-size: 11px;
            letter-spacing: 0.5px;
        }
        td {
            padding: 10px; border-bottom: 1px solid rgba(255,255,255,0.04);
        }
        tr:hover { background: rgba(99,102,241,0.06); }
        .app-name { font-weight: 500; color: #e5e7eb; }

        /* Badges */
        .badge {
            display: inline-block; padding: 2px 8px;
            border-radius: 10px; font-size: 11px;
            font-weight: 600; text-transform: uppercase;
        }
        .badge-games { background: rgba(239,68,68,0.2); color: #fca5a5; }
        .badge-social { background: rgba(245,158,11,0.2); color: #fde68a; }
        .badge-vpn { background: rgba(220,38,38,0.2); color: #fca5a5; }
        .badge-torrent { background: rgba(147,51,234,0.2); color: #d8b4fe; }

        /* Alerts */
        .alerts-card { border-color: rgba(239,68,68,0.3); }
        .alerts-card h2 { color: #fca5a5; }
        .alert-item {
            padding: 8px 12px; margin-bottom: 6px;
            background: rgba(239,68,68,0.08);
            border-left: 3px solid #ef4444;
            border-radius: 4px; font-size: 12px;
            font-family: 'Courier New', monospace;
            word-break: break-all;
        }

        .stat-item { margin-bottom: 6px; }

        /* Footer */
        .footer {
            text-align: center; padding: 20px;
            color: #4b5563; font-size: 12px;
        }

        /* Responsive */
        @media (max-width: 768px) {
            body { padding: 12px; }
            .chart-label { width: 100px; min-width: 100px; }
            .chart-duration { width: 80px; min-width: 80px; }
            .stats-grid { grid-template-columns: repeat(2, 1fr); }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Bahga Tracker - Daily Report</h1>
            <div class="date">$todayStr</div>
        </div>

        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-number">$($sortedStats.Count)</div>
                <div class="stat-label">Unique Apps</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">$totalLaunches</div>
                <div class="stat-label">Total Launches</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">$($catCounts.Count)</div>
                <div class="stat-label">Flagged Categories</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">$(if (Test-Path $alertFile) { (Get-Content $alertFile -Encoding UTF8 | Where-Object { $_ -like "*$todayStr*" -and $_ -like "*CRITICAL*" }).Count } else { 0 })</div>
                <div class="stat-label">Alerts Today</div>
            </div>
        </div>

        <div class="card">
            <h2>📊 Top 10 Applications</h2>
$chartBarsHtml
        </div>

$alertsSectionHtml

        $(if ($catCounts.Count -gt 0) {
@"
        <div class="card">
            <h2>🏷️ Flagged Categories Summary</h2>
$catStatsHtml
        </div>
"@
        })

        <div class="card">
            <h2>📋 Full Application List</h2>
            <div style="overflow-x: auto;">
                <table>
                    <thead>
                        <tr>
                            <th>#</th>
                            <th>Application</th>
                            <th>Launches</th>
                            <th>Duration</th>
                            <th>Category</th>
                            <th>Users</th>
                        </tr>
                    </thead>
                    <tbody>
$tableRowsHtml
                    </tbody>
                </table>
            </div>
        </div>

        <div class="footer">
            Generated by Bahga Tracker &bull; $todayStr $(Get-Date -Format 'HH:mm:ss')
        </div>
    </div>
</body>
</html>
"@

# Add System.Web for HtmlEncode (available in .NET Framework on Windows)
try { Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue } catch {}

$htmlContent | Out-File -FilePath $htmlFile -Encoding UTF8
