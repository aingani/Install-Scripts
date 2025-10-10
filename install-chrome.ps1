# Install Google Chrome for Azure Image Builder
$chromeInstallerUrl = "https://dl.google.com/chrome/install/latest/chrome_installer.exe"
$chromeInstallerPath = "$env:TEMP\chrome_installer.exe"

# Download the installer
Invoke-WebRequest -Uri $chromeInstallerUrl -OutFile $chromeInstallerPath

# Install Chrome silently
Start-Process -FilePath $chromeInstallerPath -ArgumentList "/silent /install" -Wait

# Clean up
Remove-Item $chromeInstallerPath

# Optional: Verify installation
$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (Test-Path $chromePath) {
    Write-Output "Chrome installed successfully at $chromePath"
} else {
    Write-Output "Chrome installation failed."
}
