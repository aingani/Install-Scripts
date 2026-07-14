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
        Write-Host "-Force specified. Proceeding with reinstall." -ForegroundColor Yellow
    }
}

# ---------- 4. Download the Office Deployment Tool ----------
$odtExe   = Join-Path $WorkDir "ODTSetup.exe"
$setupExe = Join-Path $WorkDir "setup.exe"

Write-Host "Downloading Office Deployment Tool..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $OdtUrl -OutFile $odtExe -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Host "ERROR: Failed to download ODT: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ---------- 5. Extract setup.exe from ODT ----------
Write-Host "Extracting setup.exe from ODT..." -ForegroundColor Cyan
Start-Process -FilePath $odtExe -ArgumentList "/quiet /extract:`"$WorkDir`"" -Wait
if (-not (Test-Path $setupExe)) {
    Write-Host "ERROR: setup.exe not found after ODT extraction." -ForegroundColor Red
    exit 1
}

# ---------- 6. Download configuration XML from GitHub release ----------
$localConfig = Join-Path $WorkDir "Office365-Business.xml"
Write-Host "Downloading configuration XML from GitHub release ($Version)..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $ConfigUrl -OutFile $localConfig -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Host "ERROR: Failed to download config XML: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ---------- 7. Run the installation ----------
Write-Host "Starting Office installation. This can take 10-30 minutes depending on bandwidth..." -ForegroundColor Green
$proc = Start-Process -FilePath $setupExe -ArgumentList "/configure `"$localConfig`"" -Wait -PassThru

if ($proc.ExitCode -eq 0) {
    Write-Host "Office installation completed successfully." -ForegroundColor Green
} else {
    Write-Host "Office installation returned exit code $($proc.ExitCode). Check %TEMP% logs." -ForegroundColor Red
    exit $proc.ExitCode
}

# ---------- 8. Cleanup ----------
Remove-Item -Path $odtExe -Force -ErrorAction SilentlyContinue
Write-Host "Done." -ForegroundColor Cyan              