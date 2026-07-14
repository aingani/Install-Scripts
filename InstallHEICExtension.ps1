# Install-HEVC.ps1
# Downloads and installs the latest HEVC codec release asset from GitHub
# Exits if an HEVC codec is already installed

$Owner = "aingani"
$Repo  = "Install-Scripts"

Write-Host ""
Write-Host "Checking for existing HEVC codec installation..." -ForegroundColor Cyan

# Detect any installed HEVC codec package
$Installed = Get-AppxPackage *HEVC* -ErrorAction SilentlyContinue

if ($Installed) {
    Write-Host ""
    Write-Host "An HEVC codec is already installed:" -ForegroundColor Green

    $Installed | ForEach-Object {
        Write-Host "$($_.Name) - Version $($_.Version)"
    }

    exit 0
}

try {

    Write-Host ""
    Write-Host "Retrieving latest GitHub release..." -ForegroundColor Cyan

    $Release = Invoke-RestMethod `
        -Uri "https://api.github.com/repos/$Owner/$Repo/releases/latest"

    # Locate HEVC APPX asset
    $Asset = $Release.assets | Where-Object {
        $_.name -like "Microsoft.HEVCVideoExtension*.appx"
    } | Select-Object -First 1

    if (-not $Asset) {
        throw "Microsoft HEVC APPX asset was not found in the latest GitHub release."
    }

    $DownloadPath = Join-Path $env:TEMP $Asset.name

    Write-Host ""
    Write-Host "Downloading $($Asset.name)..." -ForegroundColor Yellow

    Invoke-WebRequest `
        -Uri $Asset.browser_download_url `
        -OutFile $DownloadPath `
        -UseBasicParsing

    Write-Host ""
    Write-Host "Installing HEVC codec..." -ForegroundColor Yellow

    Add-AppxPackage `
        -Path $DownloadPath `
        -ErrorAction Stop

    Write-Host ""
    Write-Host "Installation completed successfully." -ForegroundColor Green

}
catch {

    Write-Host ""
    Write-Host "Installation failed." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    Write-Host ""
    Write-Host "If troubleshooting is required, run:" -ForegroundColor Yellow
    Write-Host "Get-AppPackageLog -ActivityID <ActivityID shown in the error>" -ForegroundColor Yellow

    exit 1
}