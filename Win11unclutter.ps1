<# *************************************************
   Windows 11 Unclutter

   Quantech Corp.
   Alfred Ingani
   Ver 1.5.1
    - Added as listed apps
    - added check script version #
   11/03/2025
   ************************************************* #>

$QCKey = "HKLM:\Software\QuantechCorp\Win11Clutter"
$ver = "Version"
$currentVersion = "1.5.1"

# List of app package names to remove
$appPackages = @(
    "Microsoft.OutlookForWindows",
    "MicrosoftTeams",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.M365Companions",
    "Microsoft.YourPhone",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxGameCallableUI"
)

If (Test-Path $QCKey) {
    $existingVersion = Get-ItemPropertyValue -Path $QCKey -Name $ver -ErrorAction SilentlyContinue
    if ($existingVersion -ne $currentVersion) {
        Write-Host
        Write-Host "Checking Version. Updating to $currentVersion..." -ForegroundColor Green 

        foreach ($app in $appPackages) {
            Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $app } | Remove-AppxProvisionedPackage -Online
        }

        Set-ItemProperty -Path $QCKey -Name $ver -Value $currentVersion -Force
        Write-Host
        Write-Host "Version updated to $currentVersion." -ForegroundColor Green
    } else {
        Write-Host
        Write-Host "Version is already $currentVersion. No action needed." -ForegroundColor Green
    }
} else {
    Write-Host
    Write-Host "Win11Clutter Key Not Here. Proceeding with cleanup..." -ForegroundColor Green

    foreach ($app in $appPackages) {
        Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $app } | Remove-AppxProvisionedPackage -Online
    }

    New-Item -Path $QCKey -Force
    New-ItemProperty -Path $QCKey -Name $ver -Value $currentVersion -PropertyType STRING -Force
    Write-Host
    Write-Host "Registry key created and version set to $currentVersion." -ForegroundColor Green
}