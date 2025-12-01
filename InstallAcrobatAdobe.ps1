<#  
   *************************************************
   Install Adobe Acrobat Pro Unified as Reader

   Quantech Corp.
   Alfred Ingani
   Ver 1.0.0
   12/01/2025
   *************************************************
#>

Clear-Host
# Download Variables
$downloadUrl = 'https://trials.adobe.com/AdobeProducts/APRO/Acrobat_HelpX/win32/Acrobat_DC_Web_x64_WWMUI.zip'
$zipPath = "$env:TEMP\Acrobat_DC_Web_WWMUI.zip"
$extractPath = "$env:TEMP\AcrobatInstaller"
Write-Host "********************************************" -ForegroundColor Blue
Write-Host "** Starting Adobe Acrobat unified install **" -ForegroundColor Blue
Write-Host "********************************************" -ForegroundColor Blue
Write-Host
try {
    # Download the installer ZIP using WebClient
    Write-Host "*******************************************" -ForegroundColor Green
    Write-Host "Downloading Adobe Acrobat Unified installer" -ForegroundColor Green
    Write-Host "Please Wait..." -ForegroundColor Green
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($downloadUrl, $zipPath)
    Write-Host "Download completed successfully." -ForegroundColor Green
    Write-Host
}
catch {
    Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Verify ZIP file exists
if (Test-Path $zipPath) {
    # Create extraction folder if it doesn't exist
    if (!(Test-Path $extractPath)) {
        New-Item -ItemType Directory -Path $extractPath | Out-Null
        # Write-Host "Created extraction folder: $extractPath"
    }

    # Extract the ZIP file
    try {
        Write-Host "Extracting installer files" -ForegroundColor Green
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        # Write-Host "Extraction completed."
        Write-Host
    }
    catch {
        Write-Host "Extraction failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }

    # Locate the setup executable inside 'Adobe Acrobat' folder
    $installerExe = Join-Path $extractPath "Adobe Acrobat\setup.exe"

    if (Test-Path $installerExe) {
        try {
            Write-Host "Starting Silent installation Please Wait..." -ForegroundColor Green
            Start-Process -FilePath $installerExe -ArgumentList "/sAll /rs /rps /msi EULA_ACCEPT=YES" -Wait
            Write-Host 
            Write-Host "Creating No Logon Registry Keys" -ForegroundColor Green
            $featureLockDownKey = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown"
            $cIPMKey = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown\cIPM"
            # Set the string and DWORD values
            $featureLockDownStringValue = "bIsSCReducedModeEnforcedEx"
            $featureLockDownDwordValue = "00000001"
            $cIPMStringValue = "bDontShowMsgWhenViewingDoc"
            $cIPMDwordValue = "00000000"
            # Add the registry keys and values using reg.exe with /reg:64 switch
            reg.exe add "$featureLockDownKey" /v "$featureLockDownStringValue" /t REG_DWORD /d $featureLockDownDwordValue /f /reg:64
            reg.exe add "$cIPMKey" /v "$cIPMStringValue" /t REG_DWORD /d $cIPMDwordValue /f /reg:64
            Write-Host "Acrobat Install completed successfully." -ForegroundColor Green
            Write-Host
        }
        catch {
            Write-Host "Installation failed: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Installer executable not found in extracted files." -ForegroundColor Red
        exit 1
    }

    # Cleanup: Delete ZIP and extracted folder
    Write-Host "*******************************************" -ForegroundColor Green
    Write-Host "Removing Downloaded & Unzipped Files" -ForegroundColor Gree
    try {
        Remove-Item -Path $zipPath -Force
        Remove-Item -Path $extractPath -Recurse -Force
        Write-Host "Removal Completed" -ForegroundColor Green
        Write-Host "*******************************************" -ForegroundColor Green
    }
    catch {
        Write-Host "Cleanup failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "ZIP file not found after download."
    exit 1
}

