#Requires -Version 5.1
<#
.SYNOPSIS
    Self-contained menu-driven winget installer/upgrader with an embedded package list.

.DESCRIPTION
    The package list is baked into this script (see $EmbeddedJson below), so it runs
    standalone with no external file. It queries which packages are already installed
    (tagging each as NotInstalled / Current / UpdateAvailable), presents an interactive
    menu to choose which to act on, and for each SELECTED package:
        * INSTALLS it if not installed
        * UPGRADES it if an update is available
        * SKIPS   it if already current

    To update the app list, edit the $EmbeddedJson here-string (same schema as
    'winget export'). Or pass -JsonPath to load an external export file instead.

.PARAMETER JsonPath
    Optional. Path to an external winget export JSON. Overrides the embedded list.

.PARAMETER Grid
    Use the Out-GridView graphical multi-select picker (desktop SKUs only).

.PARAMETER InstallMode
    Installer UX: Silent (default) or Interactive.

.PARAMETER DryRun
    Report the planned action for each selected package but make no changes.

.EXAMPLE
    .\Select-WingetApps-Standalone-07132026.ps1

.EXAMPLE
    .\Select-WingetApps-Standalone-07132026.ps1 -Grid -DryRun

.NOTES
    Run elevated. Per-machine packages (VC++ redists, VirtualBox, NetExtender,
    WireGuard, WSL, etc.) will fail or no-op without admin rights.
#>
[CmdletBinding()]
param(
    [string]$JsonPath,
    [switch]$Grid,

    [ValidateSet('Silent','Interactive')]
    [string]$InstallMode = 'Silent',

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# ===========================================================================
# EMBEDDED PACKAGE LIST  --  edit here to change what the menu offers.
# Same schema as 'winget export'. Add/remove PackageIdentifier lines as needed.
# ===========================================================================
$EmbeddedJson = @'
{
    "$schema" : "https://aka.ms/winget-packages.schema.2.0.json",
    "CreationDate" : "2026-07-13T16:19:37.474-00:00",
    "Sources" :
    [
        {
            "Packages" :
            [
                { "PackageIdentifier" : "7zip.7zip" },
                { "PackageIdentifier" : "Git.Git" },
                { "PackageIdentifier" : "ShiningLight.OpenSSL.Dev" },
                { "PackageIdentifier" : "VideoLAN.VLC" },
                { "PackageIdentifier" : "SonicWall.NetExtender" },
                { "PackageIdentifier" : "Microsoft.AzureCLI" },
                { "PackageIdentifier" : "GitHub.cli" },
                { "PackageIdentifier" : "Oracle.VirtualBox" },
                { "PackageIdentifier" : "Microsoft.VCRedist.2008.x64" },
                { "PackageIdentifier" : "Microsoft.Azure.StorageExplorer" },
                { "PackageIdentifier" : "Microsoft.PowerShell" },
                { "PackageIdentifier" : "WireGuard.WireGuard" },
                { "PackageIdentifier" : "LastPass.LastPass" },
                { "PackageIdentifier" : "Microsoft.RemoteDesktopClient" },
                { "PackageIdentifier" : "Microsoft.VisualStudioCode" },
                { "PackageIdentifier" : "PuTTY.PuTTY" },
                { "PackageIdentifier" : "LIGHTNINGUK.ImgBurn" },
                { "PackageIdentifier" : "Insecure.Nmap" },
                { "PackageIdentifier" : "Microsoft.VCRedist.2015+.x86" },
                { "PackageIdentifier" : "Famatech.AdvancedIPScanner" },
                { "PackageIdentifier" : "Zoom.Zoom.EXE" },
                { "PackageIdentifier" : "Balena.Etcher" },
                { "PackageIdentifier" : "WinSCP.WinSCP" },
                { "PackageIdentifier" : "Microsoft.WindowsApp" },
                { "PackageIdentifier" : "Notepad++.Notepad++" },
                { "PackageIdentifier" : "JAMSoftware.TreeSize.Free" }, 
                { "PackageIdentifier" : "Rufus.Rufus" },
                { "PackageIdentifier" : "Microsoft.WSL" }
            ],
            "SourceDetails" :
            {
                "Argument" : "https://cdn.winget.microsoft.com/cache",
                "Identifier" : "Microsoft.Winget.Source_8wekyb3d8bbwe",
                "Name" : "winget",
                "Type" : "Microsoft.PreIndexed.Package"
            }
        }
    ],
    "WinGetVersion" : "1.29.280"
}
'@

# ---------------------------------------------------------------------------
# 1. Module bootstrap
# ---------------------------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name Microsoft.WinGet.Client)) {
    Write-Host "Installing Microsoft.WinGet.Client (CurrentUser scope)..." -ForegroundColor Cyan
    Install-Module Microsoft.WinGet.Client -Scope CurrentUser -Force -Repository PSGallery
}
Import-Module Microsoft.WinGet.Client
try { $null = Get-WinGetVersion } catch {
    Write-Host "Repairing winget package manager bootstrap..." -ForegroundColor Yellow
    Repair-WinGetPackageManager -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# 2. Load package identifiers (external file overrides embedded list)
# ---------------------------------------------------------------------------
if ($JsonPath) {
    if (-not (Test-Path -LiteralPath $JsonPath)) { throw "Export file not found: $JsonPath" }
    Write-Host "Using external package list: $JsonPath" -ForegroundColor DarkGray
    $rawJson = Get-Content -LiteralPath $JsonPath -Raw
    $source  = $JsonPath
}
else {
    $rawJson = $EmbeddedJson
    $source  = 'embedded list'
}

$ids = ($rawJson | ConvertFrom-Json).Sources.Packages.PackageIdentifier |
        Where-Object { $_ } | Sort-Object -Unique
if (-not $ids) { throw "No PackageIdentifier entries found in $source" }

# ---------------------------------------------------------------------------
# 3. One-shot installed inventory, then tag each package
# ---------------------------------------------------------------------------
Write-Host "Querying installed packages..." -ForegroundColor Cyan
$installedMap = @{}
Get-WinGetPackage | Where-Object { $_.Id } | ForEach-Object { $installedMap[$_.Id] = $_ }

$items = foreach ($id in $ids) {
    $pkg = $installedMap[$id]
    $status =
        if (-not $pkg)                 { 'NotInstalled' }
        elseif ($pkg.IsUpdateAvailable){ 'UpdateAvailable' }
        else                           { 'Current' }
    [pscustomobject]@{
        Id        = $id
        Status    = $status
        Installed = if ($pkg) { $pkg.InstalledVersion } else { '' }
    }
}

# ---------------------------------------------------------------------------
# 4. Selection UI
# ---------------------------------------------------------------------------
function Convert-SelectionTokens {
    param([string]$Text, [int]$Max)
    $out = New-Object System.Collections.Generic.List[int]
    foreach ($tok in ($Text -split '[,\s]+' | Where-Object { $_ })) {
        if ($tok -match '^\d+$') {
            $n = [int]$tok
            if ($n -ge 1 -and $n -le $Max) { $out.Add($n - 1) }
        }
        elseif ($tok -match '^(\d+)-(\d+)$') {
            $a = [int]$Matches[1]; $b = [int]$Matches[2]
            if ($a -gt $b) { $a, $b = $b, $a }
            for ($i = $a; $i -le $b; $i++) { if ($i -ge 1 -and $i -le $Max) { $out.Add($i - 1) } }
        }
    }
    $out
}

function Get-StatusColor {
    param([string]$Status)
    switch ($Status) {
        'NotInstalled'    { 'Yellow' }
        'UpdateAvailable' { 'Green' }
        'Current'         { 'DarkGray' }
        default           { 'Gray' }
    }
}

$selected = @{}

if ($Grid) {
    $picked = $items |
        Select-Object Id, Status, Installed |
        Out-GridView -Title "Select winget packages to install/upgrade (Ctrl-click for multiple)" -PassThru
    $chosen = @($picked.Id)
}
else {
    while ($true) {
        Clear-Host
        Write-Host "Select packages to install / upgrade" -ForegroundColor Cyan
        Write-Host ("Source: {0}`n" -f $source) -ForegroundColor DarkGray

        for ($i = 0; $i -lt $items.Count; $i++) {
            $mark = if ($selected[$i]) { 'x' } else { ' ' }
            $it   = $items[$i]
            $line = "  [{0}] {1,3}) {2,-38} {3}" -f $mark, ($i + 1), $it.Id, $it.Status
            Write-Host $line -ForegroundColor (Get-StatusColor $it.Status)
        }

        $count = ($selected.Values | Where-Object { $_ }).Count
        Write-Host ("`n{0} selected." -f $count) -ForegroundColor Cyan
        Write-Host "Toggle: numbers/ranges (e.g. 1,3,5-8)   a=all  n=none  i=invert  u=updates+missing  q=quit" -ForegroundColor DarkGray
        $entry = Read-Host "Enter selection (blank = proceed)"

        if ([string]::IsNullOrWhiteSpace($entry)) { break }

        switch -Regex ($entry.Trim().ToLower()) {
            '^q$' { Write-Host "Cancelled."; return }
            '^a$' { for ($i=0;$i -lt $items.Count;$i++){ $selected[$i]=$true }; continue }
            '^n$' { $selected = @{}; continue }
            '^i$' { for ($i=0;$i -lt $items.Count;$i++){ $selected[$i]= -not $selected[$i] }; continue }
            '^u$' { for ($i=0;$i -lt $items.Count;$i++){ $selected[$i] = ($items[$i].Status -ne 'Current') }; continue }
            default {
                foreach ($idx in (Convert-SelectionTokens -Text $entry -Max $items.Count)) {
                    $selected[$idx] = -not $selected[$idx]
                }
            }
        }
    }
    $chosen = for ($i=0;$i -lt $items.Count;$i++){ if ($selected[$i]) { $items[$i].Id } }
}

if (-not $chosen) { Write-Host "`nNothing selected. Exiting." -ForegroundColor Yellow; return }

# ---------------------------------------------------------------------------
# 5. Process the selection
# ---------------------------------------------------------------------------
Write-Host ("`nProcessing {0} selected package(s)...`n" -f @($chosen).Count) -ForegroundColor Cyan
$report       = New-Object System.Collections.Generic.List[object]
$rebootNeeded = $false

foreach ($id in $chosen) {

    $installed = $installedMap[$id]

    if (-not $installed) {
        if ($DryRun) {
            Write-Host "[WOULD INSTALL] $id" -ForegroundColor Yellow
            $report.Add([pscustomobject]@{ Package=$id; Action='WouldInstall'; Version=''; Status='DryRun' }); continue
        }
        Write-Host "[INSTALL] $id" -ForegroundColor Yellow
        $r = Install-WinGetPackage -Id $id -MatchOption Equals -Source winget -Mode $InstallMode
        if ($r.RebootRequired) { $rebootNeeded = $true }
        $report.Add([pscustomobject]@{ Package=$id; Action='Install'; Version='(new)'; Status=$r.Status }); continue
    }

    if ($installed.IsUpdateAvailable) {
        if ($DryRun) {
            Write-Host ("[WOULD UPGRADE] {0}  (installed {1})" -f $id,$installed.InstalledVersion) -ForegroundColor Green
            $report.Add([pscustomobject]@{ Package=$id; Action='WouldUpgrade'; Version=$installed.InstalledVersion; Status='DryRun' }); continue
        }
        Write-Host ("[UPGRADE] {0}  (from {1})" -f $id,$installed.InstalledVersion) -ForegroundColor Green
        $r = Update-WinGetPackage -Id $id -MatchOption Equals -Source winget -Mode $InstallMode
        if ($r.RebootRequired) { $rebootNeeded = $true }
        $report.Add([pscustomobject]@{ Package=$id; Action='Upgrade'; Version=$installed.InstalledVersion; Status=$r.Status }); continue
    }

    Write-Host ("[CURRENT] {0}  ({1})" -f $id,$installed.InstalledVersion) -ForegroundColor DarkGray
    $report.Add([pscustomobject]@{ Package=$id; Action='Skip'; Version=$installed.InstalledVersion; Status='AlreadyCurrent' })
}

# ---------------------------------------------------------------------------
# 6. Summary
# ---------------------------------------------------------------------------
Write-Host "`n===================== Summary =====================" -ForegroundColor Cyan
$report | Format-Table Package, Action, Version, Status -AutoSize

$failed = $report | Where-Object { $_.Status -and $_.Status -notin @('Ok','AlreadyCurrent','DryRun') }
if ($failed) {
    Write-Host "`n$($failed.Count) package(s) reported a non-OK status:" -ForegroundColor Red
    $failed | Format-Table Package, Action, Status -AutoSize
}
if ($rebootNeeded) {
    Write-Host "`nOne or more packages requested a reboot to complete installation." -ForegroundColor Yellow
}
