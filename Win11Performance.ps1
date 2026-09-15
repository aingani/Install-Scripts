<# *************************************************
   Windows 11 - Performance & Cleanup Tweaks

   Disables consumer feature ads, widgets/news, LLMNR,
   SMBv1, and a set of idle-running scheduled tasks.
   Enables Storage Sense and sets visual effects to
   "best performance" while preserving font smoothing.
   Power plan / hibernation are handled by PowerSettings.ps1.

   Quantech Corp.
   Alfred Ingani and Claude
   Ver 1.0.3
    - REMOVED dmwappushservice from $servicesToDisable.
      Despite the "WAP Push" display name this is the
      OMA-DM client transport. Disabling it breaks Intune
      MDM sync: scheduled tasks under \EnterpriseMgmt\
      still fire but fail 0x800706D9 (EPT_S_NOT_REGISTERED)
      because no RPC endpoint is listening. Device stops
      reporting; per-policy compliance freezes at its last
      known state and "Is active" flips Not compliant once
      the compliance status validity period lapses.
    - REMOVED DiagTrack from $servicesToDisable. It is the
      transport for the Defender for Endpoint sensor,
      Windows Update for Business reporting, Endpoint
      analytics, and device inventory upload.
    - Added Section 1a: $servicesToRestore. Dropping the two
      services from the disable list is not sufficient - the
      script takes no action on services it no longer names,
      so machines already broken by <=1.0.2 need an explicit
      restore. Only touches services currently Disabled.
    - Restore section triggers an immediate OMA-DM session so
      the device reports in without waiting for the 8-hour
      Schedule #3 cycle.
    - Version bumped to 1.0.3 so machines sitting at 1.0.2
      re-run and pick up the restore. DEPLOY VIA CONNECTWISE,
      NOT INTUNE - affected endpoints have no working DM
      channel, so an Intune Platform Script or Remediation
      cannot reach them.
   Ver 1.0.2
    - Added #Requires -RunAsAdministrator admin guard
    - Added Set-RegistryKeyOwner helper (takes ownership of
      TrustedInstaller-locked policy keys)
    - Set-RegistryValue now throws on failure instead of
      silently returning; callers wrap in try/catch so the
      green "done" message only prints on actual success
    - Sections 2 (CloudContent) and 3 (Dsh) now attempt
      ownership takeover before writing, fixing the
      "Attempted to perform an unauthorized operation"
      error on Widgets / News & Interests
    - Bumped version key to 1.0.2 so existing machines
      re-run with the fixes
   Ver 1.0.1
    - Removed hibernation (moved to PowerSettings.ps1)
    - Removed orphan powercfg /SetActive (now in PowerSettings)
    - Header description and Section 5 label cleaned up
   09/15/2026
   ************************************************* #>

#Requires -RunAsAdministrator

$QCKey = "HKLM:\Software\QuantechCorp\Win11Perf"
$ver = "Version"
$currentVersion = "1.0.3"

# -----------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------

# Services to disable.
#
# DO NOT add dmwappushservice or DiagTrack here - see header.
# WSearch is intentionally absent; add only if users do not rely
# on Start menu / Explorer search.
$servicesToDisable = @(
    "MapsBroker",           # Downloaded Maps Manager
    "RetailDemo"            # Retail Demo Service
)

# Services disabled by earlier versions of this script that must be
# put back. Only acted on when currently Disabled, so this is a
# no-op on machines that never ran <=1.0.2.
$servicesToRestore = @(
    @{ Name = "dmwappushservice"; StartupType = "Automatic" },  # OMA-DM transport (Intune sync)
    @{ Name = "DiagTrack";        StartupType = "Automatic" }   # MDE sensor / WUfB reporting / Endpoint analytics
)

# Scheduled tasks to disable (telemetry / CEIP / compatibility appraiser)
$tasksToDisable = @(
    @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "Microsoft Compatibility Appraiser" },
    @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "ProgramDataUpdater" },
    @{ Path = "\Microsoft\Windows\Autochk\";                Name = "Proxy" },
    @{ Path = "\Microsoft\Windows\Customer Experience Improvement Program\"; Name = "Consolidator" },
    @{ Path = "\Microsoft\Windows\Customer Experience Improvement Program\"; Name = "UsbCeip" },
    @{ Path = "\Microsoft\Windows\Feedback\Siuf\";          Name = "DmClient" },
    @{ Path = "\Microsoft\Windows\Feedback\Siuf\";          Name = "DmClientOnScenarioDownload" }
)

# Policy keys that are often owned by TrustedInstaller and need
# ownership taken before HKLM writes will succeed. Listed as
# @{ Hive = "LocalMachine"; SubKey = "SOFTWARE\..." } pairs.
$keysNeedingOwnership = @(
    @{ Hive = "LocalMachine"; SubKey = "SOFTWARE\Policies\Microsoft\Windows\CloudContent" },
    @{ Hive = "LocalMachine"; SubKey = "SOFTWARE\Policies\Microsoft\Dsh" }
)

# -----------------------------------------------------------------
# Functions
# -----------------------------------------------------------------

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord"
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
    }
    # -ErrorAction Stop so failures surface as exceptions and the
    # caller's try/catch can react instead of printing a misleading
    # success line.
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
}

function Set-RegistryKeyOwner {
    <#
        Takes ownership of an HKLM registry key and grants
        BUILTIN\Administrators FullControl. Required for policy
        keys whose ACLs are locked down to TrustedInstaller /
        SYSTEM, which would otherwise fail with
        "Attempted to perform an unauthorized operation"
        even when the script is elevated.

        Caveat: if the key is being pushed by GPO or MDM, the
        policy engine will re-lock it on the next refresh.
    #>
    param(
        [Parameter(Mandatory=$true)] [string]$Hive,    # "LocalMachine"
        [Parameter(Mandatory=$true)] [string]$SubKey   # "SOFTWARE\Policies\..."
    )

    # P/Invoke shim to enable the privileges we need on the
    # current process token. Compiled once per session.
    $sig = @'
using System;
using System.Runtime.InteropServices;
public class QcPriv {
    [DllImport("advapi32.dll", SetLastError=true)]
    public static extern bool OpenProcessToken(IntPtr h, int acc, out IntPtr tok);
    [DllImport("advapi32.dll", SetLastError=true)]
    public static extern bool LookupPrivilegeValue(string s, string n, ref long luid);
    [DllImport("advapi32.dll", SetLastError=true)]
    public static extern bool AdjustTokenPrivileges(IntPtr tok, bool d, ref TOKPRIV n, int l, IntPtr p, IntPtr r);
    [DllImport("kernel32.dll")] public static extern IntPtr GetCurrentProcess();
    [StructLayout(LayoutKind.Sequential, Pack=1)]
    public struct TOKPRIV { public int Count; public long Luid; public int Attr; }
}
'@
    if (-not ("QcPriv" -as [type])) { Add-Type $sig }

    foreach ($privName in 'SeTakeOwnershipPrivilege','SeRestorePrivilege','SeBackupPrivilege') {
        $tok = [IntPtr]::Zero
        [QcPriv]::OpenProcessToken([QcPriv]::GetCurrentProcess(), 0x28, [ref]$tok) | Out-Null
        $luid = 0
        [QcPriv]::LookupPrivilegeValue($null, $privName, [ref]$luid) | Out-Null
        $tp = New-Object QcPriv+TOKPRIV
        $tp.Count = 1; $tp.Luid = $luid; $tp.Attr = 2  # SE_PRIVILEGE_ENABLED
        [QcPriv]::AdjustTokenPrivileges($tok, $false, [ref]$tp, 0, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
    }

    $key = [Microsoft.Win32.Registry]::$Hive.OpenSubKey(
        $SubKey,
        [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
        [System.Security.AccessControl.RegistryRights]::TakeOwnership)

    if (-not $key) {
        throw "Could not open $Hive\$SubKey for ownership change."
    }

    $admins = New-Object System.Security.Principal.SecurityIdentifier(
        [System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)

    # Set owner first, then grant FullControl on the new ACL.
    $acl = $key.GetAccessControl()
    $acl.SetOwner($admins)
    $key.SetAccessControl($acl)

    $acl = $key.GetAccessControl()
    $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
        $admins, "FullControl", "ContainerInherit", "None", "Allow")
    $acl.SetAccessRule($rule)
    $key.SetAccessControl($acl)
    $key.Close()
}

function Invoke-PerformanceTweaks {

    # ------------------------------------------------------------
    # 0. Take ownership of any TrustedInstaller-locked policy keys
    # ------------------------------------------------------------
    Write-Host "*********************************" -ForegroundColor Red
    Write-Host "Preparing Policy Keys (Ownership)" -ForegroundColor Red
    Write-Host "*********************************" -ForegroundColor Red

    foreach ($k in $keysNeedingOwnership) {
        $fullPath = "HKLM:\$($k.SubKey)"
        if (Test-Path $fullPath) {
            try {
                Set-RegistryKeyOwner -Hive $k.Hive -SubKey $k.SubKey
                Write-Host "  Ownership secured: $fullPath" -ForegroundColor Yellow
            } catch {
                Write-Host "  Could not take ownership of $fullPath - $($_.Exception.Message)" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "  $fullPath does not yet exist (will be created)." -ForegroundColor DarkGray
        }
    }
    Write-Host

    # ------------------------------------------------------------
    # 1a. Restore services wrongly disabled by <=1.0.2
    #
    # Runs before the disable loop so a machine can never end a
    # run in the broken state. Only acts on services currently
    # Disabled - untouched machines fall straight through.
    # ------------------------------------------------------------
    Write-Host "*********************************" -ForegroundColor Red
    Write-Host "Restoring MDM/Telemetry Services" -ForegroundColor Red
    Write-Host "*********************************" -ForegroundColor Red

    $restored = 0
    foreach ($s in $servicesToRestore) {
        $svc = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
        if (-not $svc) {
            Write-Host "  $($s.Name) not present." -ForegroundColor DarkGray
            continue
        }
        if ($svc.StartType -eq 'Disabled') {
            try {
                Set-Service -Name $s.Name -StartupType $s.StartupType -ErrorAction Stop
                Start-Service -Name $s.Name -ErrorAction SilentlyContinue
                $now = Get-Service -Name $s.Name
                Write-Host "  Restored: $($s.Name) -> $($now.StartType) / $($now.Status)" -ForegroundColor Yellow
                $restored++
            } catch {
                Write-Host "  Could not restore $($s.Name) - $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "  $($s.Name) already $($svc.StartType) / $($svc.Status)." -ForegroundColor DarkGray
        }
    }

    # If we just repaired the DM transport, kick an OMA-DM session
    # now rather than waiting up to 8 hours for Schedule #3.
    if ($restored -gt 0) {
        $syncTasks = Get-ScheduledTask -TaskPath "\Microsoft\Windows\EnterpriseMgmt\*" `
                        -TaskName "Schedule #3 created by enrollment client" -ErrorAction SilentlyContinue
        if ($syncTasks) {
            $syncTasks | Start-ScheduledTask
            Write-Host "  Triggered OMA-DM sync ($($syncTasks.Count) enrollment folder(s))." -ForegroundColor Yellow
            Write-Host "  Verify: LastTaskResult 0x00000000 and LastSyncDateTime in Intune." -ForegroundColor DarkGray
        } else {
            Write-Host "  No EnterpriseMgmt sync task found - device may need re-enrollment." -ForegroundColor Red
        }
    }
    Write-Host

    # ------------------------------------------------------------
    # 1. Disable unneeded services
    # ------------------------------------------------------------
    Write-Host "*********************************" -ForegroundColor Red
    Write-Host "Disabling Unused Services" -ForegroundColor Red
    Write-Host "*********************************" -ForegroundColor Red

    foreach ($svc in $servicesToDisable) {
        $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($service) {
            Write-Host "Processing service: $svc" -ForegroundColor Cyan
            try {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svc -StartupType Disabled -ErrorAction Stop
                Write-Host "  Disabled: $svc" -ForegroundColor Yellow
            } catch {
                Write-Host "  Could not disable $svc - $($_.Exception.Message)" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "  $svc not present." -ForegroundColor DarkGray
        }
    }
    Write-Host

    # ------------------------------------------------------------
    # 2. Disable consumer features / Spotlight / Tips
    # ------------------------------------------------------------
    Write-Host "*********************************" -ForegroundColor Red
    Write-Host "Disabling Consumer Features & Tips" -ForegroundColor Red
    Write-Host "*********************************" -ForegroundColor Red

    $cdm = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    $cdmValues = @(
        @{ Name = "DisableWindowsConsumerFeatures";  Value = 1 },
        @{ Name = "DisableSoftLanding";              Value = 1 },
        @{ Name = "DisableWindowsSpotlightFeatures"; Value = 1 },
        @{ Name = "DisableCloudOptimizedContent";    Value = 1 }
    )
    $cdmFailures = 0
    foreach ($v in $cdmValues) {
        try {
            Set-RegistryValue -Path $cdm -Name $v.Name -Value $v.Value
        } catch {
            $cdmFailures++
            Write-Host "  Failed to set $($v.Name) - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    if ($cdmFailures -eq 0) {
        Write-Host "  Consumer features, Spotlight, and Tips disabled." -ForegroundColor Green
    } else {
        Write-Host "  $cdmFailures of $($cdmValues.Count) CloudContent values failed." -ForegroundColor Red
    }
    Write-Host

    # ------------------------------------------------------------
    # 3. Disable Widgets / News & Interests
    # ------------------------------------------------------------
    Write-Host "*********************************" -ForegroundColor Red
    Write-Host "Disabling Widgets / News & Interests" -ForegroundColor Red
    Write-Host "*********************************" -ForegroundColor Red

    $dsh = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
    try {
        Set-RegistryValue -Path $dsh -Name "AllowNewsAndInterests" -Value 0
        Write-Host "  Widgets / News & Interests disabled." -ForegroundColor Green
    } catch {
        Write-Host "  Failed to disable Widgets - $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  (If this key is GPO/MDM-managed, change it at the policy source.)" -ForegroundColor DarkGray
    }
    Write-Host

    # ------------------------------------------------------------
    # 4. Visual effects -> Best Performance (preserve ClearType)
    #
    # NOTE: HKCU writes apply to the user running the script.
    # If you deploy this via SCCM/Intune as SYSTEM, these land
    # in the SYSTEM profile and end users will not see them.
    # Run this section in the user context (logon script / Active
    # Setup) for real-world deployment.
    # ------------------------------------------------------------
    Write-Host "*********************************" -ForegroundColor Red
    Write-Host "Setting Visual Effects: Performance" -ForegroundColor Red
    Write-Host "*********************************" -ForegroundColor Red

    $vfx = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
    try {
        Set-RegistryValue -Path $vfx -Name "VisualFXSetting" -Value 3

        # Re-enable font smoothing (ClearType) - looks awful without it
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothing"     -Value "2" -Force -ErrorAction Stop
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothingType" -Value 2   -Force -ErrorAction Stop

        Write-Host "  Visual effects set to Best Performance (ClearType preserved)." -ForegroundColor Green
    } catch {
        Write-Host "  Failed to apply visual effects - $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host

    # ------------------------------------------------------------
    # 5. Storage Sense ON (also HKCU - see note in Section 4)
    # ------------------------------------------------------------
    Write-Host "*********************************" -ForegroundColor Red
    Write-Host "Storage Sense" -ForegroundColor Red
    Write-Host "*********************************" -ForegroundColor Red

    $ss = "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
    $ssValues = @(
        @{ Name = "01";   Value = 1  },  # Storage Sense ON
        @{ Name = "04";   Value = 1  },  # Run during low disk space
        @{ Name = "08";   Value = 1  },  # Clean temp files
        @{ Name = "32";   Value = 30 },  # Recycle bin: 30 days
        @{ Name = "2048"; Value = 30 }   # Downloads cleanup threshold (days)
    )
    $ssFailures = 0
    foreach ($v in $ssValues) {
        try {
            Set-RegistryValue -Path $ss -Name $v.Name -Value $v.Value
        } catch {
            $ssFailures++
            Write-Host "  Failed to set $($v.Name) - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    if ($ssFailures -eq 0) {
        Write-Host "  Storage Sense enabled." -ForegroundColor Green
    } else {
        Write-Host "  $ssFailures of $($ssValues.Count) Storage Sense values failed." -ForegroundColor Red
    }
    Write-Host

    # ------------------------------------------------------------
    # 6. LLMNR off + SMBv1 off
    # ------------------------------------------------------------
    Write-Host "*********************************" -ForegroundColor Red
    Write-Host "Network Hardening (LLMNR / SMBv1)" -ForegroundColor Red
    Write-Host "*********************************" -ForegroundColor Red

    $llmnr = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"
    try {
        Set-RegistryValue -Path $llmnr -Name "EnableMulticast" -Value 0
        Write-Host "  LLMNR disabled." -ForegroundColor Green
    } catch {
        Write-Host "  Failed to disable LLMNR - $($_.Exception.Message)" -ForegroundColor Red
    }

    $smb1 = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction SilentlyContinue
    if ($smb1 -and $smb1.State -eq "Enabled") {
        Write-Host "  Disabling SMBv1 (no reboot)..." -ForegroundColor Yellow
        Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null
        Write-Host "  SMBv1 disabled (reboot required to fully unload)." -ForegroundColor Green
    } else {
        Write-Host "  SMBv1 already disabled or not present." -ForegroundColor DarkGray
    }
    Write-Host

    # ------------------------------------------------------------
    # 7. Disable telemetry / CEIP scheduled tasks
    #
    # NOTE: Tasks under \Microsoft\Windows\Application Experience\
    # are sometimes owned by TrustedInstaller and Disable-ScheduledTask
    # fails with access denied. If you see that, fall back to:
    #   schtasks.exe /Change /TN "<full path>" /DISABLE
    #
    # NOTE: Microsoft Compatibility Appraiser and ProgramDataUpdater
    # feed Windows Update feature-update compatibility assessment.
    # Disabling them means WUfB targets these machines without
    # compatibility data. Drop them from $tasksToDisable if you rely
    # on WUfB for feature updates.
    # ------------------------------------------------------------
    Write-Host "*********************************" -ForegroundColor Red
    Write-Host "Disabling Telemetry Scheduled Tasks" -ForegroundColor Red
    Write-Host "*********************************" -ForegroundColor Red

    foreach ($task in $tasksToDisable) {
        try {
            $existing = Get-ScheduledTask -TaskPath $task.Path -TaskName $task.Name -ErrorAction SilentlyContinue
            if ($existing) {
                Disable-ScheduledTask -TaskPath $task.Path -TaskName $task.Name -ErrorAction Stop | Out-Null
                Write-Host "  Disabled: $($task.Path)$($task.Name)" -ForegroundColor Yellow
            } else {
                Write-Host "  Not found: $($task.Path)$($task.Name)" -ForegroundColor DarkGray
            }
        } catch {
            Write-Host "  Could not disable $($task.Name) - $($_.Exception.Message)" -ForegroundColor DarkGray
        }
    }
    Write-Host

    # Power plan / hibernation handled by PowerSettings.ps1
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

        Invoke-PerformanceTweaks

        Set-ItemProperty -Path $QCKey -Name $ver -Value $currentVersion -Force
        Write-Host "Version updated to $currentVersion." -ForegroundColor Green
    } else {
        Write-Host
        Write-Host "Version is already $currentVersion. No action needed." -ForegroundColor Green
    }
} else {
    Write-Host
    Write-Host "Win11Perf Key Not Here. Proceeding with tweaks..." -ForegroundColor Green
    Write-Host

    Invoke-PerformanceTweaks

    New-Item -Path $QCKey -Force | Out-Null
    New-ItemProperty -Path $QCKey -Name $ver -Value $currentVersion -PropertyType STRING -Force | Out-Null
    Write-Host "Registry key created and version set to $currentVersion." -ForegroundColor Green
}
