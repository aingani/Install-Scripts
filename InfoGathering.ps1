<# 
    *************************************
    * Workstation Info Gathering Script *
    *
    *************************************

#>
Clear-Host
# Starting Transcript
$computer = $env:COMPUTERNAME
$TranscriptDirectory = ".\"
$transcriptFile = "$($Computer)_Info_$(Get-Date -Format 'MMddyyyy').log"
$TranscriptPath = Join-Path -Path $TranscriptDirectory -ChildPath $transcriptFile

Start-Transcript -path $TranscriptPath

<# *********************************
   * Checking Windows Join Status  *
   * *******************************
#>
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
Write-Host "*******************************" -ForegroundColor Blue
Write-Host "Checking Workstation Join Status" -ForegroundColor Blue
Write-Host "*******************************" -ForegroundColor Blue
Write-Host "Computer Name: $computer" -ForegroundColor Green
Write-Host "Tenant Name: $tenantName" -ForegroundColor Green
Write-Host "Tenant ID: $tenantId" -ForegroundColor Green
Write-Host "Azure AD Joined: $aadJoined" -ForegroundColor Green
Write-Host "Domain Joined: $aadDomainJoined" -ForegroundColor Green
Write-Host "Workplace Joined: $workplaceJoined" -ForegroundColor Green
Write-Host "*******************************" -ForegroundColor Blue
Write-Host


<# *****************************
   * Checking NETBios Settings *
   * ***************************
#>
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

<# ****************************
   * Checking IPv6 Settings   *
   * **************************
#>
Write-Host "*******************************" -ForegroundColor Blue
Write-Host "Checking IPv6 Settings" -ForegroundColor Blue
Write-Host "*******************************" -ForegroundColor Blue
Get-NetAdapterBinding -ComponentID ms_tcpip6
Write-Host "*******************************" -ForegroundColor Blue
Write-Host

<# ******************************
   * Checking BitLocker Status  *
   * ****************************
#>
Write-Host "*******************************" -ForegroundColor Blue
Write-Host "Checking Bitlocker Settings" -ForegroundColor Blue
Write-Host "*******************************" -ForegroundColor Blue
Get-BitLockerVolume | Format-Table VolumeType, MountPoint, CapacityGB, EncryptionPercentage, KeyProtector, ProtectionStatus
Write-Host "*******************************" -ForegroundColor Blue
Write-Host

Stop-Transcript
# Sending E-mail Notification    
# Acquire OAuth Token from M365
# === Authentication Setup ===
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

# === Email Payload ===
$emailBody = @{
    message = @{
        subject = "Info Gather for $computer"
        body = @{
            contentType = "HTML"
            content = "Info Gather for $computer <br /> See Attached <br />"
        }
        toRecipients = @(
            @{
                emailAddress = @{
                    address = "aingani@quantech.net"
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

# === Correct Endpoint for Application Permissions ===
$uri = "https://graph.microsoft.com/v1.0/users/aingani@quantech.net/sendMail"

# === Send Email ===
Invoke-RestMethod -Uri $uri -Method Post -Headers @{Authorization = "Bearer $accessToken"} -Body $jsonBody -ContentType "application/json"