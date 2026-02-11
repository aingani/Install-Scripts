<# *************************************************
   Windows 11 Unclutter

   Quantech Corp.
   Alfred Ingani
   Ver 1.5.1
    - Added as listed apps
    - added check script version #
    Ver 1.5.2
    - Added additioal app
    Ver 1.6.0
    - Added onscreen Outputs
   02-11-2026
   ************************************************* #>

$QCKey = "HKLM:\Software\QuantechCorp\Win11Clutter"
$ver = "Version"
$currentVersion = "1.6.0"

# List of app package names to remove
$appPackages = @(
    "Microsoft.OutlookForWindows",
    "MicrosoftTeams",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.M365Companions",
    "Microsoft.YourPhone",
    "Microsoft.GamingApp",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.BingWeather",
    "Microsoft.WindowsMaps",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.MixedReality.Portal",
    "Microsoft.SkypeApp",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.Wallet",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.Print3D",
    "Microsoft.People",
    "Microsoft.OneConnect",
    # "Clipchamp.Clipchamp",                
    "Microsoft.XboxApp",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxGameCallableUI",
    "Microsoft.XboxGameOverlay"       
    
)

If (Test-Path $QCKey) {
    $existingVersion = Get-ItemPropertyValue -Path $QCKey -Name $ver -ErrorAction SilentlyContinue
    if ($existingVersion -ne $currentVersion) {
        Write-Host
        Write-Host "Checking Version. Updating to $currentVersion..." -ForegroundColor Green
        Write-Host

        foreach ($app in $appPackages) {

            Write-Host "Processing: $app" -ForegroundColor Cyan

            # Remove installed AppX packages (existing profiles)
            $installed = Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue
            if ($installed) {
                foreach ($pkg in $installed) {
                    Write-Host "  Removing AppX (installed): $($pkg.PackageFullName)" -ForegroundColor Yellow
                    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
                }
            } else {
                Write-Host "  Not found (installed)." -ForegroundColor DarkGray
            }

            # Remove provisioned packages (prevents install for new profiles)
            $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $app }
            if ($prov) {
                foreach ($p in $prov) {
                    Write-Host "  Removing Provisioned (future users): $($p.PackageName)" -ForegroundColor Magenta
                    Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction SilentlyContinue | Out-Null
                }
            } else {
                Write-Host "  Not found (provisioned)." -ForegroundColor DarkGray
            }

            Write-Host
        }

        Set-ItemProperty -Path $QCKey -Name $ver -Value $currentVersion -Force
        Write-Host "Version updated to $currentVersion." -ForegroundColor Green
    } else {
        Write-Host
        Write-Host "Version is already $currentVersion. No action needed." -ForegroundColor Green
    }
} else {
    Write-Host
    Write-Host "Win11Clutter Key Not Here. Proceeding with cleanup..." -ForegroundColor Green
    Write-Host

    foreach ($app in $appPackages) {

        Write-Host "Processing: $app" -ForegroundColor Cyan

        # Remove installed AppX packages (existing profiles)
        $installed = Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue
        if ($installed) {
            foreach ($pkg in $installed) {
                Write-Host "  Removing AppX (installed): $($pkg.PackageFullName)" -ForegroundColor Yellow
                Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
            }
        } else {
            Write-Host "  Not found (installed)." -ForegroundColor DarkGray
        }

        # Remove provisioned packages (prevents install for new profiles)
        $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $app }
        if ($prov) {
            foreach ($p in $prov) {
                Write-Host "  Removing Provisioned (future users): $($p.PackageName)" -ForegroundColor Magenta
                Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction SilentlyContinue | Out-Null
            }
        } else {
            Write-Host "  Not found (provisioned)." -ForegroundColor DarkGray
        }

        Write-Host
    }

    New-Item -Path $QCKey -Force | Out-Null
    New-ItemProperty -Path $QCKey -Name $ver -Value $currentVersion -PropertyType STRING -Force | Out-Null
    Write-Host "Registry key created and version set to $currentVersion." -ForegroundColor Green
}
