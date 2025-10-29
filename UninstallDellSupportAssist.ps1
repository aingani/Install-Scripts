# List of Dell apps to uninstall
$appsToRemove = @(
    "Dell SupportAssist",
    "Dell SupportAssist OS Recovery Plugin for Dell Update",
    "Dell SupportAssist Remediation"
    "Dell Optimizer"
)

# Registry paths to check
$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

foreach ($app in $appsToRemove) {
    $found = $false
    foreach ($path in $registryPaths) {
        $keys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
        foreach ($key in $keys) {
            $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
            if ($props.DisplayName -like "*$app*") {
                $found = $true
                $guid = $props.PSChildName
                Write-Host "Uninstalling $app using msiexec with GUID: $guid"
                Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $guid /quiet /norestart" -Wait

                # Remove leftover registry entry
                Remove-Item -Path $key.PSPath -Force -ErrorAction SilentlyContinue
                Write-Host "Removed leftover registry entry for $app"
                break
            }
        }
        if ($found) { break }
    }

    # Appx fallback cleanup
    if ($app -eq "Dell SupportAssist") {
        $appxMatch = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*SupportAssist*" }
        foreach ($pkg in $appxMatch) {
            Write-Host "Removing Appx package: $($pkg.Name)"
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        }
    }

    if (-not $found) {
        Write-Host "$app not found in registry. It may not be installed via MSI."
    }
}