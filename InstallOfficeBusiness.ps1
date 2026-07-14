<#
.SYNOPSIS
    Installs Microsoft 365 Apps for Business using the Office Deployment Tool (ODT)
    with Office365-Business.xml pulled from the Install-Scripts GitHub release.

.DESCRIPTION
    - Requires Administrator
    - Detects existing Click-to-Run Office (skips unless -Force)
    - Downloads the Office Deployment Tool from Microsoft
    - Downloads Office365-Business.xml from a GitHub release asset
    - Runs setup.exe /configure and reports status

.PARAMETER Version
    Release tag to pull the config from. Defaults to "latest".
    Example: -Version v1.0.0

.PARAMETER Force
    Reinstalls Office even if a Click-to-Run install is already present.

.EXAMPLE
    .\InstallOfficeBusiness.ps1

.EXAMPLE
    .\InstallOfficeBusiness.ps1 -Version v1.0.0

.EXAMPLE
    .\InstallOfficeBusiness.ps1 -Force
#>

[CmdletBinding()]
param(
    [string]$Version = "latest",
    [switch]$Force
)

# ---------- Fixed sources ----------
if ($Version -eq "latest") {
    $ConfigUrl = "https://github.com/aingani/Install-Scripts/releases/latest/download/Office365-Business.xml"
} else {
    $ConfigUrl = "https://github.com/aingani/Install-Scripts/releases/download/$Version/Office365-Business.xml"
}

$OdtUrl = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_18827-20140.exe"

# ---------- 1. Require Administrator ----------
$currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator." -ForegroundColor Red
    exit 1
}

# ---------- 2. Working directory ----------
$WorkDir = Join-Path $env:TEMP "ODTInstall"
if (-not (Test-Path $WorkDir)) { New-Item -Path $WorkDir -ItemType Directory -Force | Out-Null }
Write-Host "Working directory: $WorkDir" -ForegroundColor Cyan
Write-Host "Config source   : $ConfigUrl" -ForegroundColor Cyan

# ---------- 3. Check for existing Office (Click-to-Run) ----------
$c2rKey = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
if (Test-Path $c2rKey) {
    $installedProducts = (Get-ItemProperty -Path $c2rKey -ErrorAction SilentlyContinue).ProductReleaseIds
    if ($installedProducts) {
        Write-Host "Detected existing Click-to-Run Office install: $installedProducts" -ForegroundColor Yellow
        if (-not $Force) {
            Write-Host "Use -Force to reinstall. Exiting." -ForegroundColor Yellow
            exit 0
        }
        Write-Host "-Force specified