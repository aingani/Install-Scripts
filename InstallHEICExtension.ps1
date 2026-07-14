# Install-HEVC.ps1

$Owner = "aingani"
$Repo  = "Install-Scripts"

Write-Host "Checking for HEVC Extension..."

$Installed = Get-AppxPackage -Name Microsoft.HEVCVideoExtension -ErrorAction SilentlyContinue

if ($Installed) {
    Write-Host ""
    Write-Host "HEVC Video Extension is already installed."
    Write-Host "Version: $($Installed.Version)"
    return
}

Write-Host "HEVC Extension not found. Downloading latest release..."

try {

    # Get latest GitHub release
    $Release = Invoke-RestMethod `
        -Uri "https://api.github.com/repos/$Owner/$Repo/releases/latest"

    # Find APPX asset
    $Asset = $Release.assets | Where-Object {
        $_.name -like "*.appx"
    } | Select-Object -First 1

    if (-not $Asset) {
        throw "No APPX asset found in the latest release."
    }

    $DownloadPath = Join-Path $env:TEMP $Asset.name

    Write-Host "Downloading $($Asset.name)..."

    Invoke-WebRequest `
        -Uri $Asset.browser_download_url `
        -OutFile $DownloadPath

    Write-Host "Installing..."

    Add-AppxPackage `
        -Path $DownloadPath `
        -ErrorAction Stop

    Write-Host ""
    Write-Host "Installation completed successfully."

}
catch {
    Write-Host ""
    Write-Host "Installation failed!"
    Write-Host $_.Exception.Message
    exit 1
}