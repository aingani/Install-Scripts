<# *************************************************
   Set Power and Sleep Settings

   Quantech Corp.
   Alfred Ingani
   Ver 1.0.1
   08/12/2024
   *************************************************
#>

$QCKey = "HKLM:\Software\QuantechCorp\PWRCFG"
$ver = "Version"
$PWCFGValue = "1.0.1"

If (Test-Path $QCKey){
    Write-Output "PWRCFG Key Here"
}else {
    Write-Output "PWRCFG Key Not Here"
    Powercfg /Change monitor-timeout-ac 60
    Powercfg /Change monitor-timeout-dc 30
    Powercfg /Change standby-timeout-ac 0
    Powercfg /Change standby-timeout-dc 240
    New-Item -Path $QCKey -Force
    New-ItemProperty -Path $QCKey -Name $Ver -Value $PWCFGValue -PropertyType STRING -Force 
}
     