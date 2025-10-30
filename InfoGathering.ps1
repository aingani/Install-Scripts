<#  
   *************************************************
   Workstation Info Gathering Script 

   Quantech Corp.
   Alfred Ingani
   Ver 1.1.0
      - Added local disk information
   Ver 1.0.1
      - Get Windows Join Status
      - Check NetBIOS Setting
      - Check IP 6 
      - Check Bitlocker Status
   10/28/2025
   *************************************************
#>

Clear-Host
# transcript Settings
$computer = $env:COMPUTERNAME
$TranscriptDirectory = ".\"
$transcriptFile = "$($Computer)_Info_$(Get-Date -Format 'MMddyyyy').log"
$TranscriptPath = Join-Path -Path $TranscriptDirectory -ChildPath $transcriptFile
# Start Transcript
Start-Transcript -path $TranscriptPath

# Checking Windows Join Status  
$dsregStatus = dsregcmd /status
# Display all relevant join statuses
$aadJoined = ($dsregStatus | Select-String "AzureAdJoined").ToString().Split(":")[1].Trim()
$aadDomainJoined = ($dsregStatus | Select-String "DomainJoined").ToString().Split(":")[1].Trim()
$workplaceJoined = ($dsregStatus | Select-String "WorkplaceJoined").ToString().Split(":")[1].Trim()
$deviceId = ($dsregStatus | Select-String "DeviceId").ToString().Split(":")[1].Trim()
$tenantName = ($dsregStatus | Select-String "TenantName").ToString().Split(":")[1].Trim()
$tenantId = ($dsregStatus | Select-String "TenantId").ToString().Split(":")[1].Trim()
# Output the results
Write-Host
Write-Host "********************************" -ForegroundColor Blue
Write-Host "Checking Workstation Join Status" -ForegroundColor Blue
Write-Host "********************************" -ForegroundColor Blue
Write-Host "Computer Name: $computer" -ForegroundColor Green
Write-Host "Tenant Name: $tenantName" -ForegroundColor Green
Write-Host "Tenant ID: $tenantId" -ForegroundColor Green
Write-Host "Azure AD Joined: $aadJoined" -ForegroundColor Green
Write-Host "Domain Joined: $aadDomainJoined" -ForegroundColor Green
Write-Host "Workplace Joined: $workplaceJoined" -ForegroundColor Green
Write-Host "*******************************" -ForegroundColor Blue
Write-Host

# Checking NETBios Settings 
Write-Host "*******************************" -ForegroundColor Blue
Write-Host "Checking NETBios Settings" -ForegroundColor Blue
Write-Host "*******************************" -ForegroundColor Blue
Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true } | ForEach-Object {
    $netbiosSetting = switch ($_.TcpipNetbiosOptions) {
        0 { "Use NetBIOS setting from the DHCP server" }
        1 { "Enable NetBIOS over TCP/IP" }
        2 { "Disable NetBIOS over TCP/IP" }
        default { "Unknown setting" }
    }
Write-Host "Interface: $($_.Description)" -ForegroundColor Green
Write-Host "NetBIOS Setting: $netbiosSetting" -ForegroundColor Green
Write-Host "*******************************" -ForegroundColor Blue
}

# Checking IPv6 Settings 
Write-Host "*******************************" -ForegroundColor Blue
Write-Host "Checking IPv6 Settings" -ForegroundColor Blue
Write-Host "*******************************" -ForegroundColor Blue
Get-NetAdapterBinding -ComponentID ms_tcpip6
Write-Host "*******************************" -ForegroundColor Blue
Write-Host

# Getting Storage information
Write-Host "********************************" -ForegroundColor Blue
Write-Host "Checking Disk Information" -ForegroundColor Blue
Write-Host "********************************" -ForegroundColor Blue
# Print table header
Write-Host ("{0,-8} {1,-20} {2,10} {3,15}" -f "Drive", "Volume Name", "Size (GB)", "Free Space (GB)") -ForegroundColor Yellow
Write-Host ("{0,-8} {1,-20} {2,10} {3,15}" -f "-----", "------------", "----------", "---------------") -ForegroundColor Yellow
# Print each disk's info
Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $drive = $_.DeviceID
    $volume = $_.VolumeName
    $sizeGB = "{0:N2}" -f ($_.Size / 1GB)
    $freeGB = "{0:N2}" -f ($_.FreeSpace / 1GB)
    Write-Host ("{0,-8} {1,-20} {2,10} {3,15}" -f $drive, $volume, $sizeGB, $freeGB) -ForegroundColor White
}
Write-Host "*******************************" -ForegroundColor Blue
Write-Host

# Checking BitLocker Status
Write-Host "*******************************" -ForegroundColor Blue
Write-Host "Checking Bitlocker Settings" -ForegroundColor Blue
Write-Host "*******************************" -ForegroundColor Blue
Get-BitLockerVolume | Format-Table VolumeType, MountPoint, CapacityGB, EncryptionPercentage, KeyProtector, ProtectionStatus
Write-Host "*******************************" -ForegroundColor Blue
Write-Host

# Stopping Transcript
Stop-Transcript

# Sending E-mail Notification    
$tenantId = "c44e4c5f-d470-47cf-8491-08643bf37095"
$clientId = "f66f4241-bec9-40ff-aa8d-19a6091d18ae"
$clientSecret = "aPs8Q~HN5LjDNsBuxB8LBPTJGp5UvOnowUtLKaU6"
$tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

$body = @{
    client_id     = $clientId
    scope         = "https://graph.microsoft.com/.default"
    client_secret = $clientSecret
    grant_type    = "client_credentials"
}
$tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body
$accessToken = $tokenResponse.access_token
$tempPath = "$env:TEMP\$transcriptFile"
Copy-Item $TranscriptPath $tempPath -Force
$contentBytes = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($tempPath))
$emailBody = @{
    message = @{
        subject = "Info Gathered for $computer"
        body = @{
            contentType = "HTML"
            content = "Info Gathered for $computer <br /> See Attached <br />"
        }
        toRecipients = @(
            @{
                emailAddress = @{
                    address = "alerts@quantech.net"
                }
            }
        )
        attachments = @(
            @{
                "@odata.type" = "#microsoft.graph.fileAttachment"
                name = $transcriptFile
                contentBytes = $contentBytes
            }
        )
    }
    saveToSentItems = $true
}
$jsonBody = $emailBody | ConvertTo-Json -Depth 5
$uri = "https://graph.microsoft.com/v1.0/users/noreply@quantech.net/sendMail"
Invoke-RestMethod -Uri $uri -Method Post -Headers @{Authorization = "Bearer $accessToken"} -Body $jsonBody -ContentType "application/json"