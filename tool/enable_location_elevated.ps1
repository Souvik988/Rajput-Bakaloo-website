$ErrorActionPreference = 'Continue'
$log = 'C:\Users\sayan\Desktop\bakaloo_flutter_web\tool\enable_location_result.txt'
"run at $(Get-Date)" | Out-File $log -Encoding utf8

# Turn the device-level "Location services" master toggle back ON.
# Evidence: WinRT RequestAccessAsync => Denied / GetGeopositionAsync => 0x80070005
# while lfsvc runs and user-level consent is Allow — the signature of the
# device toggle (this exact registry value) being off.
try {
  reg add "HKLM\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration" /v Status /t REG_DWORD /d 1 /f 2>&1 | Out-String | Out-File $log -Append -Encoding utf8
} catch {
  $_ | Out-String | Out-File $log -Append -Encoding utf8
}

try {
  Restart-Service lfsvc -Force
  "lfsvc restarted" | Out-File $log -Append -Encoding utf8
} catch {
  "lfsvc restart skipped: $($_.Exception.Message)" | Out-File $log -Append -Encoding utf8
}

try {
  $v = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration'
  "Status now: $($v.Status)" | Out-File $log -Append -Encoding utf8
} catch {
  "verify failed: $($_.Exception.Message)" | Out-File $log -Append -Encoding utf8
}
"done" | Out-File $log -Append -Encoding utf8
