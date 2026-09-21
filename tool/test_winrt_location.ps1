$ErrorActionPreference = 'Stop'
try {
  Add-Type -AssemblyName System.Runtime.WindowsRuntime
  [void][Windows.Devices.Geolocation.Geolocator, Windows.Devices.Geolocation, ContentType = WindowsRuntime]

  $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
    Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]

  function Await($WinRtTask, $ResultType) {
    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
    $netTask = $asTask.Invoke($null, @($WinRtTask))
    $netTask.Wait(30000) | Out-Null
    $netTask.Result
  }

  $locator = New-Object Windows.Devices.Geolocation.Geolocator
  Write-Output ("Status before: " + $locator.LocationStatus)

  try {
    $accessOp = [Windows.Devices.Geolocation.Geolocator]::RequestAccessAsync()
    $access = Await $accessOp ([Windows.Devices.Geolocation.GeolocationAccessStatus])
    Write-Output ("RequestAccessAsync: " + $access)
  } catch {
    $e = $_.Exception
    while ($e.InnerException) { $e = $e.InnerException }
    Write-Output ("RequestAccessAsync FAILED: " + $e.Message + " HR=" + ('0x{0:X}' -f $e.HResult))
  }

  try {
    $op = $locator.GetGeopositionAsync()
    $pos = Await $op ([Windows.Devices.Geolocation.Geoposition])
    Write-Output ("OK lat=" + $pos.Coordinate.Point.Position.Latitude + " lng=" + $pos.Coordinate.Point.Position.Longitude)
  } catch {
    $e = $_.Exception
    while ($e.InnerException) { $e = $e.InnerException }
    Write-Output ("GetGeopositionAsync FAILED: " + $e.Message + " HR=" + ('0x{0:X}' -f $e.HResult))
  }

  Write-Output ("Status after: " + $locator.LocationStatus)
}
catch {
  Write-Output ("FAILED: " + $_.Exception.Message)
}
