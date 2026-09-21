$ErrorActionPreference = 'Continue'
$log = 'C:\Users\sayan\Desktop\bakaloo_flutter_web\tool\enable_location_result.txt'
"broker restart at $(Get-Date)" | Out-File $log -Encoding utf8

# The registry consents are all Allow now, but the location broker caches
# consent state in memory. Restart the sensor + location services so the
# new consents are reloaded.
foreach ($svc in @('SensorService', 'lfsvc')) {
  try {
    Restart-Service $svc -Force
    "$(Get-Date) restarted $svc" | Out-File $log -Append -Encoding utf8
  } catch {
    "$(Get-Date) $svc restart failed: $($_.Exception.Message)" | Out-File $log -Append -Encoding utf8
  }
}

Start-Sleep -Seconds 2
Get-Service SensorService, lfsvc | ForEach-Object {
  "$($_.Name): $($_.Status)" | Out-File $log -Append -Encoding utf8
}
"done" | Out-File $log -Append -Encoding utf8
