$ErrorActionPreference = 'SilentlyContinue'
Write-Output '=== ALL HKCU location consent entries (recursive) ==='
function Walk($path, $indent) {
  $k = Get-Item $path
  $v = (Get-ItemProperty $path).Value
  if ($v) { Write-Output ("$indent" + $k.PSChildName + " = " + $v) }
  foreach ($child in Get-ChildItem $path) {
    Write-Output ("$indent" + $child.PSChildName)
    Walk $child.PSPath ($indent + '    ')
  }
}
Walk 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' '  '
Write-Output '=== HKLM NonPackaged subkeys ==='
Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\NonPackaged' | ForEach-Object {
  $v = (Get-ItemProperty $_.PSPath).Value
  Write-Output ("{0} = {1}" -f $_.PSChildName, $v)
}
Write-Output '=== Sensor devices ==='
Get-PnpDevice -Class Sensor | Select-Object FriendlyName, Status | Format-Table -AutoSize | Out-String
