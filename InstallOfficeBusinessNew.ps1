<#
.SYNOPSIS
    Installs Microsoft 365 Apps for Business using ODT + Office365-Business.xml
    from the Install-Scripts GitHub release.

.DESCRIPTION
    Safe for both file execution and Invoke-Expression (IEX). No top-level
    param() block, no `exit` statements - failures return cleanly.

    Detection is SKU-aware:
      - Stub/no-op products (OneNoteFreeRetail, TeamsRetail) never block.
      - Target product already present  -> exit unless $global:OfficeForce.
      - Consumer/retail SKUs present    -> ODT removal pass, then install.
      - Platform (x86/x64) mismatch     -> removal pass is mandatory.

.NOTES
    Globals honored (set BEFORE running via IEX):
        $global:OfficeVersion   = 'v1.0.0'  # release tag, default 'latest'
        $global:OfficeForce     = $true     # reinstall even if target present
        $global:OfficeRemoveAll = $true     # Remove All="TRUE" instead of targeted
        $global:OfficeNoRemove  = $true     # never auto-remove; report and exit

.EXAMPLE
    & .\InstallOfficeBusiness-08202026.ps1

    $global:OfficeForce = $true
    iex (irm "https://raw.githubusercontent.com/aingani/Install-Scripts/main/InstallOfficeBusiness.ps1")
#>

& {
    # ---------- Resolve options ----------
    $Version   = if ($global:OfficeVersion) { $global:OfficeVersion } else { 'latest' }
    $Force     = [bool]$global:OfficeForce
    $RemoveAll = [bool]$global:OfficeRemoveAll
    $NoRemove  = [bool]$global:OfficeNoRemove

    # ---------- Fixed sources ----------
    $TargetProduct  = 'O365BusinessRetail'
    $TargetPlatform = '64'   # must match OfficeClientEdition in Office365-Business.xml

    if ($Version -eq 'latest') {
        $ConfigUrl = "https://github.com/aingani/Install-Scripts/releases/latest/download/Office365-Business.xml"
    } else {
        $ConfigUrl = "https://github.com/aingani/Install-Scripts/releases/download/$Version/Office365-Business.xml"
    }

    # Products that are stubs / never a reason to abort
    $IgnoreSkus = @('OneNoteFreeRetail','TeamsRetail','MondoRetail_Bypass')

    # Consumer + retail perpetual SKUs that cannot coexist with M365 Apps for Business
    $ConflictSkus = @(
        'O365HomePremRetail','O365PersonalRetail','O365SmallBusPremRetail',
        'HomeBusinessRetail','HomeBusiness2019Retail','HomeBusiness2021Retail','HomeBusiness2024Retail',
        'HomeStudentRetail','HomeStudent2019Retail','HomeStudent2021Retail','HomeStudent2024Retail',
        'ProfessionalRetail','Professional2019Retail','Professional2021Retail','Professional2024Retail',
        'Personal2019Retail','Personal2021Retail','Personal2024Retail'
    )

    # ---------- 1. Require Administrator ----------
    $currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "ERROR: This script must be run as Administrator." -ForegroundColor Red
        return
    }

    # ---------- 2. Working directory ----------
    $WorkDir = Join-Path $env:TEMP "ODTInstall"
    if (-not (Test-Path $WorkDir)) { New-Item -Path $WorkDir -ItemType Directory -Force | Out-Null }
    Write-Host "Working directory: $WorkDir"      -ForegroundColor Cyan
    Write-Host "Config source    : $ConfigUrl"    -ForegroundColor Cyan
    Write-Host "Version          : $Version"      -ForegroundColor Cyan
    Write-Host "Force            : $Force"        -ForegroundColor Cyan

    # ---------- 3. Inventory existing Click-to-Run install ----------
    $c2rKey          = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
    $installed       = @()
    $installedPlat   = $null
    $clientCulture   = 'en-us'
    $needRemoval     = $false
    $removalReason   = @()

    if (Test-Path $c2rKey) {
        $c2r = Get-ItemProperty -Path $c2rKey -ErrorAction SilentlyContinue
        if ($c2r.ProductReleaseIds) {
            $installed = $c2r.ProductReleaseIds -split ',' |
                         ForEach-Object { $_.Trim() } |
                         Where-Object { $_ }
        }
        if ($c2r.Platform)      { $installedPlat = if ($c2r.Platform -eq 'x64') { '64' } else { '32' } }
        if ($c2r.ClientCulture) { $clientCulture = $c2r.ClientCulture }
    }

    $relevant   = $installed | Where-Object { $IgnoreSkus -notcontains $_ }
    $conflicts  = $relevant  | Where-Object { $ConflictSkus -contains $_ }
    $hasTarget  = $relevant  -contains $TargetProduct
    $otherSkus  = $relevant  | Where-Object { $_ -ne $TargetProduct -and $ConflictSkus -notcontains $_ }

    if ($installed.Count) {
        Write-Host "Detected Click-to-Run products: $($installed -join ', ')" -ForegroundColor Yellow
        Write-Host "Installed platform            : $(if ($installedPlat) { "x$installedPlat" } else { 'unknown' })" -ForegroundColor Yellow
        Write-Host "Client culture                : $clientCulture" -ForegroundColor Yellow
    } else {
        Write-Host "No existing Click-to-Run Office detected." -ForegroundColor Green
    }

    # Target already present, nothing else in the way
    if ($hasTarget -and -not $conflicts -and -not $Force) {
        Write-Host "$TargetProduct is already installed. Set `$global:OfficeForce = `$true to reinstall. Exiting." -ForegroundColor Yellow
        return
    }

    # Conflicting consumer/retail SKUs
    if ($conflicts) {
        $needRemoval = $true
        $removalReason += "conflicting SKU(s): $($conflicts -join ', ')"
    }

    # Bitness mismatch - ODT cannot install x64 over an existing x86 install
    if ($relevant.Count -and $installedPlat -and $installedPlat -ne $TargetPlatform) {
        $needRemoval = $true
        $removalReason += "platform mismatch (installed x$installedPlat, target x$TargetPlatform)"
    }

    # Unknown/unhandled products - do not silently steamroll them
    if ($otherSkus -and -not $Force) {
        Write-Host "Unrecognized Office product(s) present: $($otherSkus -join ', ')" -ForegroundColor Yellow
        Write-Host "Review manually, or set `$global:OfficeForce = `$true to proceed anyway. Exiting." -ForegroundColor Yellow
        return
    }

    if ($needRemoval -and $NoRemove) {
        Write-Host "Removal required ($($removalReason -join '; ')) but `$global:OfficeNoRemove is set. Exiting." -ForegroundColor Yellow
        return
    }

    # ---------- 4. Download the Office Deployment Tool ----------
    $odtExe   = Join-Path $WorkDir "ODTSetup.exe"
    $setupExe = Join-Path $WorkDir "setup.exe"

    Write-Host "Resolving latest ODT download URL from Microsoft..." -ForegroundColor Cyan
    $OdtUrl = $null
    try {
        $confirmPage = "https://www.microsoft.com/en-us/download/details.aspx?id=49117"
        $html = (Invoke-WebRequest -Uri $confirmPage -UseBasicParsing -ErrorAction Stop).Content
        $rx   = [regex]'https://download\.microsoft\.com/download/[^"'']+officedeploymenttool_[\d\-]+\.exe'
        $m    = $rx.Match($html)
        if ($m.Success) { $OdtUrl = $m.Value }
    } catch {
        Write-Host "WARN: Could not query Microsoft download page: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    if (-not $OdtUrl) {
        Write-Host "Falling back to hardcoded ODT URL." -ForegroundColor Yellow
        $OdtUrl = "https://download.microsoft.com/download/6c1eeb25-cf8b-41d9-8d0d-cc1dbc032140/officedeploymenttool_20026-20112.exe"
    }

    Write-Host "ODT URL: $OdtUrl" -ForegroundColor Cyan
    Write-Host "Downloading Office Deployment Tool..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $OdtUrl -OutFile $odtExe -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "ERROR: Failed to download ODT: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    # ---------- 5. Extract setup.exe ----------
    Write-Host "Extracting setup.exe from ODT..." -ForegroundColor Cyan
    Start-Process -FilePath $odtExe -ArgumentList "/quiet /extract:`"$WorkDir`"" -Wait
    if (-not (Test-Path $setupExe)) {
        Write-Host "ERROR: setup.exe not found after ODT extraction." -ForegroundColor Red
        return
    }

    # ---------- 6. Removal pass (only if required) ----------
    if ($needRemoval) {
        Write-Host "Removal required - $($removalReason -join '; ')" -ForegroundColor Yellow

        $removeConfig = Join-Path $WorkDir "Remove-ConflictingOffice.xml"
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine('<Configuration>')

        if ($RemoveAll -or ($installedPlat -and $installedPlat -ne $TargetPlatform)) {
            [void]$sb.AppendLine('  <Remove All="TRUE" />')
        } else {
            [void]$sb.AppendLine('  <Remove>')
            foreach ($sku in ($conflicts + ($IgnoreSkus | Where-Object { $installed -contains $_ }) | Select-Object -Unique)) {
                [void]$sb.AppendLine("    <Product ID=`"$sku`">")
                [void]$sb.AppendLine("      <Language ID=`"$clientCulture`" />")
                [void]$sb.AppendLine('    </Product>')
            }
            [void]$sb.AppendLine('  </Remove>')
        }

        [void]$sb.AppendLine('  <Display Level="None" AcceptEULA="TRUE" />')
        [void]$sb.AppendLine('  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />')
        [void]$sb.AppendLine('  <Logging Level="Standard" Path="%TEMP%\ODTInstall" />')
        [void]$sb.AppendLine('</Configuration>')

        Set-Content -Path $removeConfig -Value $sb.ToString() -Encoding UTF8
        Write-Host "Removal configuration written to $removeConfig" -ForegroundColor Cyan
        Write-Host "Removing conflicting Office products (Office apps will be force-closed)..." -ForegroundColor Yellow

        $rm = Start-Process -FilePath $setupExe -ArgumentList "/configure `"$removeConfig`"" -Wait -PassThru
        if ($rm.ExitCode -ne 0) {
            Write-Host "ERROR: Removal returned exit code $($rm.ExitCode). Check logs in $WorkDir." -ForegroundColor Red
            Write-Host "If removal keeps failing, run the Microsoft SaRA Office uninstall tool, then re-run this script." -ForegroundColor Yellow
            return
        }
        Write-Host "Removal completed." -ForegroundColor Green
    }

    # ---------- 7. Download configuration XML ----------
    $localConfig = Join-Path $WorkDir "Office365-Business.xml"
    Write-Host "Downloading configuration XML from GitHub release ($Version)..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $ConfigUrl -OutFile $localConfig -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "ERROR: Failed to download config XML: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    # ---------- 8. Install ----------
    Write-Host "Starting Office installation. This can take 10-30 minutes depending on bandwidth..." -ForegroundColor Green
    $proc = Start-Process -FilePath $setupExe -ArgumentList "/configure `"$localConfig`"" -Wait -PassThru

    if ($proc.ExitCode -eq 0) {
        Write-Host "Office installation completed successfully." -ForegroundColor Green
    } else {
        Write-Host "Office installation returned exit code $($proc.ExitCode). Check logs in $WorkDir and %TEMP%." -ForegroundColor Red
        return
    }

    # ---------- 9. Verify ----------
    $post = (Get-ItemProperty -Path $c2rKey -ErrorAction SilentlyContinue).ProductReleaseIds
    Write-Host "Post-install ProductReleaseIds: $post" -ForegroundColor Cyan

    # ---------- 10. Cleanup ----------
    Remove-Item -Path $odtExe -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name OfficeVersion, OfficeForce, OfficeRemoveAll, OfficeNoRemove -Scope Global -ErrorAction SilentlyContinue
    Write-Host "Done." -ForegroundColor Cyan
}
