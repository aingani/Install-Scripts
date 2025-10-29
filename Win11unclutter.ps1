<# *************************************************
   Windows 11 Unclutter

   Quantech Corp.
   Alfred Ingani
   Ver 1.5.0
    - Added as listed apps
    - added check version #
   10/29/2025
   ************************************************* #>

$QCKey = "HKLM:\Software\QuantechCorp\Win11Clutter"
$ver = "Version"
$currentVersion = "1.5.0"

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
        Write-Output "Version mismatch detected. Updating to $currentVersion..."

        foreach ($app in $appPackages) {
            Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $app } | Remove-AppxProvisionedPackage -Online
        }

        Set-ItemProperty -Path $QCKey -Name $ver -Value $currentVersion -Force
        Write-Output "Version updated to $currentVersion."
    } else {
        Write-Output "Version is already $currentVersion. No action needed."
    }
} else {
    Write-Output "Win11Clutter Key Not Here. Proceeding with cleanup..."

    foreach ($app in $appPackages) {
        Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $app } | Remove-AppxProvisionedPackage -Online
    }

    New-Item -Path $QCKey -Force
    New-ItemProperty -Path $QCKey -Name $ver -Value $currentVersion -PropertyType STRING -Force 
    Write-Output "Registry key created and version set to $currentVersion."
}