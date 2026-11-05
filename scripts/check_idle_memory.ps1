param(
    [string]$DeviceId='emulator-5554',
    [string]$Package='com.example.app_ho_tro_nguoi_khiem_thi'
)
$ErrorActionPreference='Stop'
$adb=Join-Path $env:LOCALAPPDATA 'Android\sdk\platform-tools\adb.exe'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
function Read-AppMemory([string]$Phase) {
    $pidText=(& $adb -s $DeviceId shell pidof $Package) -join ''
    $memory=(& $adb -s $DeviceId shell dumpsys meminfo $Package) -join [Environment]::NewLine
    $camera=(& $adb -s $DeviceId shell dumpsys media.camera) -join [Environment]::NewLine
    $pss=[regex]::Match($memory,'TOTAL PSS:\s*(\d+)')
    $rss=[regex]::Match($memory,'TOTAL RSS:\s*(\d+)')
    $clients=[regex]::Match($camera,'(?s)Active Camera Clients:(.*?)(?:Active Client listener PIDs|Camera service events log)')
    [pscustomobject]@{
        phase=$Phase
        captured_utc=[DateTime]::UtcNow.ToString('o')
        pid=$pidText.Trim()
        total_pss_kib=if ($pss.Success) { [int]$pss.Groups[1].Value } else { $null }
        total_rss_kib=if ($rss.Success) { [int]$rss.Groups[1].Value } else { $null }
        camera_active=$clients.Success -and $clients.Groups[1].Value.Contains($Package)
        meminfo=$memory
    }
}
& $adb -s $DeviceId shell am start -n "$Package/.MainActivity"
if ($LASTEXITCODE -ne 0) { throw 'Could not open app.' }
$startClock=[Diagnostics.Stopwatch]::StartNew()
do {
    Start-Sleep -Seconds 2
    $active=Read-AppMemory 'active_before_background'
    if ($active.camera_active) { break }
} while ($startClock.Elapsed.TotalSeconds -lt 45)
if (-not $active.camera_active) { throw 'Camera must be active before measuring background release.' }
Start-Sleep -Seconds 8
$active=Read-AppMemory 'active_before_background'
if (-not $active.camera_active) { throw 'Camera stopped before background measurement.' }

& $adb -s $DeviceId shell input keyevent KEYCODE_HOME
if ($LASTEXITCODE -ne 0) { throw 'Could not background app.' }
Start-Sleep -Seconds 18
$background=Read-AppMemory 'background_after_18_seconds'
& $adb -s $DeviceId shell am start -n "$Package/.MainActivity"
if ($LASTEXITCODE -ne 0) { throw 'Could not resume app.' }
$resumeClock=[Diagnostics.Stopwatch]::StartNew()
Start-Sleep -Seconds 5
do {
    $resumed=Read-AppMemory 'resumed_camera_ready'
    if ($resumed.camera_active) { break }
    Start-Sleep -Seconds 2
} while ($resumeClock.Elapsed.TotalSeconds -lt 30)
$resumed | Add-Member -NotePropertyName resume_elapsed_seconds -NotePropertyValue $resumeClock.Elapsed.TotalSeconds
$result=[pscustomobject]@{
    device_id=$DeviceId
    build_mode='debug'
    limitations='Within-version lifecycle check on emulator; not a controlled before/after RAM or battery benchmark.'
    samples=@($active,$background,$resumed)
}
$output=Join-Path $root 'reports/SauKhiToiUu/after/idle-memory.json'
[IO.File]::WriteAllText($output,($result|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
$result.samples | Select-Object phase,pid,total_pss_kib,total_rss_kib,camera_active | Format-Table
Write-Host "Saved: $output"
if (-not $resumed.camera_active) { throw 'Camera did not resume within 30 seconds. Inspect the saved lifecycle result.' }
