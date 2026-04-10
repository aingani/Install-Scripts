# Run-InstallScriptsMenu.ps1
# ---------------------------------------------------------------
# Description : Presents an interactive console menu to run
#               PowerShell scripts hosted in the GitHub repository
#               https://github.com/aingani/Install-Scripts
#               Scripts are executed directly from GitHub (raw URL)
#               without being saved locally first.
#
# Usage       : Run this script in an elevated PowerShell session
#               (Run as Administrator). Most target scripts need
#               admin privileges to install software or change
#               system settings.
#
# Customising : To add or remove menu items, edit the $scripts
#               array below. Each entry is a hashtable with two
#               keys:
#                 Name  – the label shown in the menu
#                 Url   – the raw GitHub URL of the .ps1 file
#                 Note  – (optional) extra info shown beside the
#                         menu item
# ---------------------------------------------------------------

# --- Ensure TLS 1.2 for secure GitHub connections ---------------
# Older Windows PowerShell versions default to TLS 1.0/1.1, which
# GitHub no longer accepts. PowerShell 6+ uses TLS 1.2 by default.
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {
    # Safe to ignore on PowerShell Core / 7+
}

# --- Warn if the session is not elevated -----------------------
if (-not ([Security.Principal.WindowsPrincipal] `
          [Security.Principal.WindowsIdentity]::GetCurrent()
         ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Warning "This menu should be run in an elevated PowerShell session (Run as Administrator)."
}

# ================================================================
# MENU ITEMS — edit this array to add, remove, or reorder scripts.
# ================================================================
$scripts = @(
    @{
        Name = "Install Google Chrome"
        Url  = "https://raw.githubusercontent.com/aingani/install-scripts/main/install-chrome.ps1"
        Note = ""
    },
    @{
        Name = "Install Adobe Acrobat (Unified)"
        Url  = "https://raw.githubusercontent.com/aingani/install-scripts/main/InstallAcrobatAdobe.ps1"
        Note = ""
    },
    @{
        Name = "Remove Windows 11 Bloatware (Win11Unclutter)"
        Url  = "https://raw.githubusercontent.com/aingani/install-scripts/main/Win11unclutter.ps1"
        Note = ""
    },
    @{
        Name = "Uninstall Dell SupportAssist"
        Url  = "https://raw.githubusercontent.com/aingani/install-scripts/main/UninstallDellSupportAssist.ps1"
        Note = "Run at least TWICE to get all components removed"
    },
    @{
        Name = "Run System Info Gathering"
        Url  = "https://raw.githubusercontent.com/aingani/install-scripts/main/InfoGathering.ps1"
        Note = ""
    },
    @{
        Name = "Configure Network Settings (disable NetBIOS & IPv6)"
        Url  = "https://raw.githubusercontent.com/aingani/install-scripts/main/ConfigNetworkSettings.ps1"
        Note = "Sets NetBIOS & IPv6 to Disabled"
    },
    @{
        Name = "Apply Recommended Power Settings"
        Url  = "https://raw.githubusercontent.com/aingani/install-scripts/main/PowerSettings.ps1"
        Note = ""
    },
    @{
        Name = "Disable Windows Hello Features"
        Url  = "https://raw.githubusercontent.com/aingani/install-scripts/main/disablehello.ps1"
        Note = ""
    }
)

# ================================================================
# MAIN LOOP — display the menu, accept input, execute selection
# ================================================================
while ($true) {
    Write-Host "`n***************************** Install-Scripts Menu ********************************" -ForegroundColor Blue

    for ($i = 0; $i -lt $scripts.Count; $i++) {
        $label = "{0}. {1}" -f ($i + 1), $scripts[$i].Name
        if ($scripts[$i].Note) {
            $label += "  ** $($scripts[$i].Note) **"
        }
        Write-Host $label
    }
    Write-Host "Q. Quit"

    $choice = Read-Host "`nEnter the number of the script to run (or Q to quit)"

    # --- handle empty input ---
    if ([string]::IsNullOrWhiteSpace($choice)) { continue }

    # --- handle quit ---
    if ($choice.Trim().ToUpper() -eq 'Q') {
        Write-Host "Exiting menu." -ForegroundColor Yellow
        break
    }

    # --- validate numeric input ---
    if (-not ($choice -match '^[0-9]+$')) {
        Write-Host "Invalid selection. Please enter a number or Q." -ForegroundColor Red
        continue
    }

    $index = [int]$choice - 1
    if ($index -lt 0 -or $index -ge $scripts.Count) {
        Write-Host "Selection out of range. Choose 1-$($scripts.Count) or Q." -ForegroundColor Red
        continue
    }

    # --- download and execute the selected script ---
    $selectedName = $scripts[$index].Name
    $scriptUrl    = $scripts[$index].Url

    Write-Host "`n>> Running: $selectedName" -ForegroundColor Cyan
    Write-Host "   Source : $scriptUrl" -ForegroundColor DarkCyan

    try {
        # Download the script content from GitHub
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            # PowerShell 6+ (Core/7): -UseBasicParsing is not needed
            $scriptContent = (Invoke-WebRequest -Uri $scriptUrl).Content
        } else {
            # Windows PowerShell 5.1 or earlier: -UseBasicParsing avoids
            # loading the Internet Explorer DOM engine
            $scriptContent = (Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing).Content
        }
    } catch {
        Write-Host "ERROR: Could not download script from GitHub.`n       $($_)" -ForegroundColor Red
        continue
    }

    try {
        # Execute the downloaded script in the current session
        Invoke-Expression $scriptContent
    } catch {
        Write-Host "ERROR: '$selectedName' threw an exception:`n       $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host
    Write-Host
    Write-Host "`nDone running '$selectedName'. Press any key to return to the menu..." -ForegroundColor Yellow
    [void][System.Console]::ReadKey($true)
}