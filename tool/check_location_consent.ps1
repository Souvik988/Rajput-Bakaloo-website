$ErrorActionPreference = 'SilentlyContinue'
Write-Output '=== HKCU NonPackaged root ==='
(Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\NonPackaged').Value
Write-Output '=== HKCU NonPackaged subkeys (per-app) ==='
Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\NonPackaged' | ForEach-Object {
  $val = (Get-ItemProperty $_.PSPath).Value
  Write-Output ("{0} => {1}" -f $_.PSChildName, $val)
}
Write-Output '=== HKLM NonPackaged root ==='
(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\NonPackaged').Value
Write-Output '=== HKLM NonPackaged subkeys (per-app) ==='
Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\NonPackaged' | ForEach-Object {
  $val = (Get-ItemProperty $_.PSPath).Value
  Write-Output ("{0} => {1}" -f $_.PSChildName, $val)
}
