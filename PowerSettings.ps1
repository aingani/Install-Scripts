<# *************************************************
   Set Power and Sleep Settings

   Activates the High Performance power plan, applies
   monitor / standby timeouts, and disables hibernation.

   Quantech Corp.
   Alfred Ingani
   Ver 1.1.0
    - Added powercfg /SetActive for High Performance plan
      (previously announced in header but never executed)
    - Added version-gate logic matching other QC scripts
    - Switched Write-Output to colored Write-Host
    - Piped New-Item / New-ItemProperty to Out-Null
    - Fixed $Ver case + hibernation line indentation
   06/17/2026
   ************************************************* #>

$QCKey = "HKLM:\Software\QuantechCorp\PWRCFG"
$ver = "Version"
$currentVersion = "1.1.0"

# High Performance plan GUID (same across Windows versions)
$HighPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"

# -----------------------------------------------------------------
# Functions
# -----------------------------------------------------------------

function Invoke-PowerTweaks {

    # ------------------------------------------------------------
    # 1. Activate High Performance plan
    #    (Must run BEFORE the timeouts, otherwise the timeouts
    #     get written to whatever plan is currently active.)
    # ------------------------------------------------------------
    Write-Host "*********************************" -ForegroundColor Red
    Write-Host "Setting High Performance Power Plan" -ForegroundColor Red
    Write-Host "*********************************" -ForegroundColor Red
    Powercfg /SetActive $HighPerfGuid
    Write-Host "  High Performance plan active." -ForegroundColor Green
    Write-Host

    # ------------------------------------------------------------
    # 2. Apply monitor / standby timeouts to active plan
    # ------------------------------------------------------------
    Write-Host "*********************************" -ForegroundColor Red
    Write-Host "Applying Monitor / Standby Timeouts" -ForegroundColor Red
    Write-Host "*********************************" -ForegroundColor Red
    Powercfg /Change monitor-timeout-ac 60
    Powercfg /Change monitor-timeout-dc 30
    Powercfg /Change standby-timeout-ac 0
    Powercfg /Change standby-timeout-dc 240
    Write-Host "  Monitor: AC=60m / DC=30m" -ForegroundColor Green
    Write-Host "  Standby: AC=Never / DC=240m" -ForegroundColor Green
    Write-Host

    # ------------------------------------------------------------
    # 3. Disable hibernation (reclaims hiberfil.sys disk space)
    # ------------------------------------------------------------
    Write-Host "*********************************" -ForegroundColor Red
    Write-Host "Disabling Hibernation" -ForegroundColor Red
    Write-Host "*********************************" -ForegroundColor Red
    Powercfg /Hibernate off
    Write-Host "  Hibernation disabled (hiberfil.sys removed)." -ForegroundColor Green
    Write-Host
}

# -----------------------------------------------------------------
# Version-gated main
# -----------------------------------------------------------------

If (Test-Path $QCKey) {
    $existingVersion = Get-ItemPropertyValue -Path $QCKey -Name $ver -ErrorAction SilentlyContinue
    if ($existingVersion -ne $currentVersion) {
        Write-Host
        Write-Host "Checking Version. Updating to $currentVersion..." -ForegroundColor Green
        Write-Host

        Invoke-PowerTweaks

        Set-ItemProperty -Path $QCKey -Name $ver -Value $currentVersion -Force
        Write-Host "Version updated to $currentVersion." -ForegroundColor Green
    } else {
        Write-Host
        Write-Host "Version is already $currentVersion. No action needed." -ForegroundColor Green
    }
} else {
    Write-Host
    Write-Host "PWRCFG Key Not Here. Proceeding with power settings..." -ForegroundColor Green
    Write-Host

    Invoke-PowerTweaks

    New-Item -Path $QCKey -Force | Out-Null
    New-ItemProperty -Path $QCKey -Name $ver -Value $currentVersion -PropertyType STRING -Force | Out-Null
    Write-Host "Registry key created and version set to $currentVersion." -ForegroundColor Green
}
