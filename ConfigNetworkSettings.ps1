<#  ************************************
    Configure Network Settings 
    to run out of Github
        Disable NETBios
        Disable ip6 on Interfaces

    Quantech Corp.
    Alfred Ingani
    Ver 1.0.0
    10/31/2025
    *************************************
#>


<#  *******************************
    Disable NETBios on all adapters
    *******************************
#>
# Read interfaces key
$IFKey = "HKLM:SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces"
# Get all interaces
Write-Host "*********************************" -ForegroundColor Red
Write-Host "Disabling NETBios on all Adapters" -ForegroundColor Red
Write-Host "*********************************" -ForegroundColor Red
$interfaces = Get-ChildItem $IFKey | Select-Object -ExpandProperty PSChildName
# Turn NETBios Off
        foreach($interface in $interfaces) {
            Set-ItemProperty -Path "$IFKey\$interface" -Name "NetbiosOptions" -Value 2
        }
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

<#  *******************************
Disable ipv6 on All insterfaces
*******************************
#>
# Disable ip6
Write-Host
Write-Host "********************************" -ForegroundColor Red
Write-Host "Disabling IPv6 on all Adapters" -ForegroundColor Red
Write-Host "********************************" -ForegroundColor Red
Get-NetAdapterBinding -ComponentID ms_tcpip6 | Disable-NetAdapterBinding
Get-NetAdapterBinding -ComponentID ms_tcpip6
Write-Host






