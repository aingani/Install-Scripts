<#
**********************************************************
Disable PIN in Windows 10 w/ M365                                  
Script Version 1.0.0                             
Alfred Ingani - Quantech Corp
05/02/2019
APPLIES TO:
 - Windows 10
 - Office 365
**********************************************************
#> 

# Disable PIN Reguirement
$path = "HKLM:\SOFTWARE\Policies\Microsoft"
$key = "PassportForWork"
$name = "Enabled"
$value = "0"
 
New-Item -Path $path -Name $key -Force
 
New-ItemProperty -Path $path\$key -Name $name -Value $value -PropertyType DWORD -Force
 
# Delete existing PIN
$passportFolder = "C:\Windows\ServiceProfiles\LocalService\AppData\Local\Microsoft\Ngc"
 
if(Test-Path -Path $passportFolder)
{
Takeown /f $passportFolder /r /d "Y"
ICACLS $passportFolder /reset /T /C /L /Q
 
Remove-Item -Path $passportFolder -Recurse -force
}