<# *************************************************
   Windows 11 Unclutter

   Quantech Corp.
   Alfred Ingani
   Ver 1.0.0
   08/26/2025
   *************************************************
#>

$QCKey = "HKLM:\Software\QuantechCorp\Win11Clutter"
$ver = "Version"
$PWCFGValue = "1.0.0"

If (Test-Path $QCKey)
{
    Write-Output "Win11Clutter Key Here"
}
else 
{
    Write-Output "Win11Clutter Key Not Here"
# Remove new Outlook
Get-AppxPackage -Name "Microsoft.OutlookForWindows" -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue 
Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq "Microsoft.OutlookForWindows"} | Remove-AppxProvisionedPackage -Online
# remove personal Teams
Get-AppxPackage -Name "MicrosoftTeams" -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq "MicrosoftTeams"} | Remove-AppxProvisionedPackage -Online
# Remove Office Hub
Get-AppxPackage -Name "Microsoft.MicrosoftOfficeHub" -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue 
Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq "Microsoft.MicrosoftOfficeHub"} | Remove-AppxProvisionedPackage -Online
# remove M365 Companions
Get-AppxPackage -Name "Microsoft.M365Companions" -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue
Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq "Microsoft.M365Companions"} | Remove-AppxProvisionedPackage -Online
# remove Phone Link app
Get-AppxPackage -Name "Microsoft.YourPhone" -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue 
Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq "Microsoft.YourPhone"} | Remove-AppxProvisionedPackage -Online
# Remove XBox apps
Get-AppxPackage -Name "Microsoft.XboxSpeechToTextOverlay" -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue
Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq "Microsoft.XboxSpeechToTextOverlay"} | Remove-AppxProvisionedPackage -Online
Get-AppxPackage -Name "Microsoft.XboxIdentityProvider" -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue
Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq "Microsoft.XboxIdentityProvider"} | Remove-AppxProvisionedPackage -Online
Get-AppxPackage -Name "Microsoft.Xbox.TCUI" -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue
Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq "Microsoft.Xbox.TCUI"} | Remove-AppxProvisionedPackage -Online
Get-AppxPackage -Name "Microsoft.XboxGamingOverlay" -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue 
Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq "Microsoft.XboxGamingOverlay"} | Remove-AppxProvisionedPackage -Online
Get-AppxPackage -Name "Microsoft.XboxGameCallableUI" -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue 
Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq "Microsoft.XboxGameCallableUI"} | Remove-AppxProvisionedPackage -Online

    New-Item -Path $QCKey -Force
    New-ItemProperty -Path $QCKey -Name $Ver -Value $PWCFGValue -PropertyType STRING -Force 
}
     
