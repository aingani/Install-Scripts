<#
   *************************************************
   Install Adobe Acrobat Pro Unified as Reader

   Quantech Corp.
   Alfred Ingani
   Ver 1.0.3
   04/13/2026
   *************************************************
#>

Clear-Host

# Download Variables
$downloadUrl = 'https://trials.adobe.com/AdobeProducts/APRO/Acrobat_HelpX/win32/Acrobat_DC_Web_x64_WWMUI.zip'
$zipPath     = "$env:TEMP\Acrobat_DC_Web_WWMUI.zip"
$extractPath = "$env:TEMP\AcrobatInstaller"

Write-Host "********************************************" -ForegroundColor Blue
Write-Host "** Starting Adobe Acrobat unified install **" -ForegroundColor Blue
Write-Host "********************************************" -ForegroundColor Blue
Write-Host

# -------------------------
# Download the installer ZIP (FAST: WebClient)
# -------------------------
try {
    Write-Host "*******************************************" -ForegroundColor Green
    Write-Host "Downloading Adobe Acrobat Unified installer" -ForegroundColor Green
    Write-Host "Please Wait..." -ForegroundColor Green

    # Ensure modern TLS is enabled for download reliability
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    }
    catch {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }

    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($downloadUrl, $zipPath)

    Write-Host "Download completed successfully." -ForegroundColor Green
    Write-Host
}
catch {
    Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Verify ZIP exists
if (-not (Test-Path $zipPath)) {
    Write-Host "ZIP file not found after download." -ForegroundColor Red
    exit 1
}

# -------------------------
# Prepare extraction folder
# -------------------------
try {
    if (Test-Path $extractPath) {
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
}
catch {
    Write-Host "Failed to prepare extraction folder: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# -------------------------
# Extract ZIP
# -------------------------
try {
    Write-Host "Extracting installer files" -ForegroundColor Green
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Write-Host
}
catch {
    Write-Host "Extraction failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# -------------------------
# Locate setup.exe dynamically (fixes folder structure changes)
# -------------------------

# Preferred: match typical Adobe layout if present
$installerExe = Get-ChildItem -Path $extractPath -Filter "setup.exe" -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\Adobe Acrobat\\setup\.exe$" } |
    Select-Object -First 1 -ExpandProperty FullName

# Fallback: take the first setup.exe found anywhere
if (-not $installerExe) {
    $installerExe = Get-ChildItem -Path $extractPath -Filter "setup.exe" -Recurse -File -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}

if (-not $installerExe -or -not (Test-Path $installerExe)) {
    Write-Host "Installer executable not found in extracted files." -ForegroundColor Red
    Write-Host

    Write-Host "Debug info (top-level extracted folders):" -ForegroundColor Yellow
    Get-ChildItem -Path $extractPath -Directory -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName

    Write-Host
    Write-Host "Debug info (any setup.exe found):" -ForegroundColor Yellow
    Get-ChildItem -Path $extractPath -Filter "setup.exe" -Recurse -File -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName

    exit 1
}

Write-Host "Found installer: $installerExe" -ForegroundColor Green
Write-Host

# -------------------------
# Install
# -------------------------
try {
    Write-Host "Starting Silent installation Please Wait..." -ForegroundColor Green
    Start-Process -FilePath $installerExe -ArgumentList "/sAll /rs /rps /msi EULA_ACCEPT=YES" -Wait
    Write-Host

    Write-Host "Creating No Logon Registry Keys" -ForegroundColor Green
    $featureLockDownKey = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown"
    $cIPMKey            = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown\cIPM"

    reg.exe add "$featureLockDownKey" /v "bIsSCReducedModeEnforcedEx" /t REG_DWORD /d 00000001 /f /reg:64
    reg.exe add "$cIPMKey"            /v "bDontShowMsgWhenViewingDoc" /t REG_DWORD /d 00000000 /f /reg:64

    Write-Host "Acrobat Install completed successfully." -ForegroundColor Green
    Write-Host
}
catch {
    Write-Host "Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# -------------------------
# Cleanup
# -------------------------
Write-Host "*******************************************" -ForegroundColor Green
Write-Host "Removing Downloaded & Unzipped Files" -ForegroundColor Green

try {
    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Removal Completed" -ForegroundColor Green
    Write-Host "*******************************************" -ForegroundColor Green
}
catch {
    Write-Host "Cleanup failed: $($_.Exception.Message)" -ForegroundColor Red
}