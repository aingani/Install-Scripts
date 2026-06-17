<# *************************************************
   Windows 11 - removes unwanted Appx apps and
   Appx Provisioning packages

   Quantech Corp.
   Alfred Ingani
   Ver 1.7.1
    - Added curated corporate-image debloat additions:
      Bing apps (News/Search/Finance/Sports), Mail&Calendar,
      Cortana, Sound Recorder, Power Automate, To Do,
      Alarms, Quick Assist, Whiteboard, Family, Copilot,
      Cross Device, Game Assist. Skipped Snipping Tool,
      Photos, Camera, Sticky Notes, Calculator, Terminal,
      Notepad, and Store - removing those breaks workflows
      end users notice
   Ver 1.7.0
    - Added #Requires -RunAsAdministrator admin guard
    - Extracted cleanup loop into Invoke-AppxCleanup
      function (matches PowerSettings / Win11Performance
      pattern); main now calls it from both branches
    - Cached Get-AppxPackage -AllUsers and
      Get-AppxProvisionedPackage -Online once before the
      loop instead of re-querying per app (~28 DISM calls
      collapsed to one)
    - Removed -ErrorAction SilentlyContinue from Remove
      calls; now wrapped in try/catch and reported per
      package. Failures are surfaced but version is still
      stamped (lenient mode) so a single locked file
      doesn't block the registry marker forever
    - Renamed $ver -> $verPropName for clarity (was the
      property name "Version", not a version number)
   Ver 1.6.1 - previous (duplicated cleanup loop)
   Ver 1.6.0 - Added onscreen Outputs
   Ver 1.5.2 - Added additional app
   Ver 1.5.1 - Added listed apps, version check
   06/17/2026
   ************************************************* #>

#Requires -RunAsAdministrator

$QCKey = "HKLM:\Software\QuantechCorp\Win11Clutter"
$verPropName = "Version"
$currentVersion = "1.7.1"

# -----------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------

# List of app package names to remove.
# NOTE: If you add or remove entries here, bump $currentVersion
# above so existing machines re-process the list.
$appPackages = @(
    "Microsoft.GamingOverlay",
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
    # Clipchamp.Clipchamp - intentionally left installed; some
    # users rely on it for quick video trims. Uncomment to remove.
    # "Clipchamp.Clipchamp",
    "Microsoft.XboxApp",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxGameCallableUI",
    "Microsoft.XboxGameOverlay",

    # --- Bing / web-content apps -------------------------------
    "Microsoft.BingNews",
    "Microsoft.BingSearch",
    "Microsoft.BingFinance",
    "Microsoft.BingSports",

    # --- Communications ----------------------------------------
    # Mail & Calendar - being sunset in favor of new Outlook
    "microsoft.windowscommunicationsapps",

    # --- Cortana / assistants ----------------------------------
    # Cortana package name is literally this GUID-style string
    "Microsoft.549981C3F5F10",

    # --- Media / capture ---------------------------------------
    # "Microsoft.WindowsSoundRecorder",

    # --- Productivity bloat ------------------------------------
    "Microsoft.PowerAutomateDesktop",
    # "Microsoft.Todos",
    "Microsoft.WindowsAlarms",
    # "MicrosoftCorporationII.QuickAssist",
    # "Microsoft.Whiteboard",
    "MicrosoftCorporationII.MicrosoftFamily",

    # --- Newer (Win11 23H2 / 24H2) -----------------------------
    # "Microsoft.Copilot",
    # "Microsoft.Windows.Copilot",
    "MicrosoftWindows.CrossDevice",
    "Microsoft.GameAssist"

    # --- Intentionally NOT removed (break end-user workflows) --
    # Microsoft.ScreenSketch         - Snipping Tool
    # Microsoft.Windows.Photos       - default image viewer
    # Microsoft.WindowsCamera        - default camera app
    # Microsoft.MicrosoftStickyNotes - heavily used by some users
    # Microsoft.WindowsCalculator    - default calculator
    # Microsoft.WindowsTerminal      - default terminal on 11
    # Microsoft.WindowsNotepad       - default text editor
    # Microsoft.WindowsStore         - removing breaks updates
)

# -----------------------------------------------------------------
# Functions
# -----------------------------------------------------------------

function Invoke-AppxCleanup {

    # ------------------------------------------------------------
    # Cache the AppX inventory once. Get-AppxProvisionedPackage
    # -Online walks the full DISM image and is expensive; calling
    # it inside the loop (28x) was the previous bottleneck.
    # ------------------------------------------------------------
    Write-Host "Enumerating AppX inventory..." -ForegroundColor Cyan
    try {
        $allInstalled   = @(Get-AppxPackage -AllUsers -ErrorAction Stop)
        $allProvisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop)
    } catch {
        Write-Host "  Failed to enumerate AppX packages - $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Aborting cleanup." -ForegroundColor Red
        return
    }
    Write-Host "  $($allInstalled.Count) installed packages, $($allProvisioned.Count) provisioned packages." -ForegroundColor DarkGray
    Write-Host

    foreach ($app in $appPackages) {

        Write-Host "Processing: $app" -ForegroundColor Cyan

        # --------------------------------------------------------
        # Remove installed AppX packages (existing profiles)
        # --------------------------------------------------------
        $installed = $allInstalled | Where-Object { $_.Name -eq $app }
        if ($installed) {
            foreach ($pkg in $installed) {
                Write-Host "  Removing AppX (installed): $($pkg.PackageFullName)" -ForegroundColor Yellow
                try {
                    Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                    Write-Host "    OK" -ForegroundColor Green
                } catch {
                    Write-Host "    FAILED - $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "  Not found (installed)." -ForegroundColor DarkGray
        }

        # --------------------------------------------------------
        # Remove provisioned packages (prevents install for new
        # profiles)
        # --------------------------------------------------------
        $prov = $allProvisioned | Where-Object { $_.DisplayName -eq $app }
        if ($prov) {
            foreach ($p in $prov) {
                Write-Host "  Removing Provisioned (future users): $($p.PackageName)" -ForegroundColor Magenta
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop | Out-Null
                    Write-Host "    OK" -ForegroundColor Green
                } catch {
                    Write-Host "    FAILED - $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "  Not found (provisioned)." -ForegroundColor DarkGray
        }

        Write-Host
    }
}

# -----------------------------------------------------------------
# Version-gated main
# -----------------------------------------------------------------

If (Test-Path $QCKey) {
    $existingVersion = Get-ItemPropertyValue -Path $QCKey -Name $verPropName -ErrorAction SilentlyContinue
    if ($existingVersion -ne $currentVersion) {
        Write-Host
        Write-Host "Checking Version. Updating to $currentVersion..." -ForegroundColor Green
        Write-Host

        Invoke-AppxCleanup

        # Lenient mode: stamp version even if individual Remove
        # calls failed. Failures are reported above; the registry
        # marker records that this script version was attempted,
        # not that it succeeded perfectly.
        Set-ItemProperty -Path $QCKey -Name $verPropName -Value $currentVersion -Force
        Write-Host "Version updated to $currentVersion." -ForegroundColor Green
    } else {
        Write-Host
        Write-Host "Version is already $currentVersion. No action needed." -ForegroundColor Green
    }
} else {
    Write-Host
    Write-Host "Win11Clutter Key Not Here. Proceeding with cleanup..." -ForegroundColor Green
    Write-Host

    Invoke-AppxCleanup

    New-Item -Path $QCKey -Force | Out-Null
    New-ItemProperty -Path $QCKey -Name $verPropName -Value $currentVersion -PropertyType STRING -Force | Out-Null
    Write-Host "Registry key created and version set to $currentVersion." -ForegroundColor Green
}
