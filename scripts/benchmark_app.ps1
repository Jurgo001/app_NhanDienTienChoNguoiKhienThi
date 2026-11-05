param(
    [ValidateSet('before','after')][string]$Label,
    [string]$DeviceId = 'emulator-5554',
    [string]$FlutterSdk = 'D:\sdk_flutter\flutter'
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$flutterBat = Join-Path $FlutterSdk 'bin\flutter.bat'
$adb = Join-Path $env:LOCALAPPDATA 'Android\sdk\platform-tools\adb.exe'
$runId = [DateTime]::UtcNow.ToString('yyyyMMddHHmmss')
$remotePath = "app_flutter/benchmark_${Label}_$runId.json"
$outputDirectory = Join-Path $projectRoot "reports/SauKhiToiUu/$Label"
[void](New-Item -ItemType Directory -Path $outputDirectory -Force)
Push-Location -LiteralPath $projectRoot
try {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $flutterBat run -d $DeviceId -t lib/main_benchmark.dart --no-resident "--dart-define=BENCHMARK_LABEL=$Label" "--dart-define=BENCHMARK_RUN_ID=$runId" 2>&1 |
            Tee-Object -FilePath (Join-Path $outputDirectory 'benchmark-build.log')
        $flutterExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($flutterExit -ne 0) { throw "Benchmark build failed: $flutterExit" }
    $deadline = [DateTime]::UtcNow.AddMinutes(4)
    do {
        & $adb -s $DeviceId shell run-as com.example.app_ho_tro_nguoi_khiem_thi test -f $remotePath
        if ($LASTEXITCODE -eq 0) { break }
        Start-Sleep -Seconds 2
    } while ([DateTime]::UtcNow -lt $deadline)
    if ($LASTEXITCODE -ne 0) { throw 'Benchmark did not produce results. Check BENCHMARK_ERROR in logcat.' }
    $raw = & $adb -s $DeviceId exec-out run-as com.example.app_ho_tro_nguoi_khiem_thi cat $remotePath
    if ($LASTEXITCODE -ne 0) { throw 'Could not read benchmark result.' }
    $result = $raw | ConvertFrom-Json
    if ($result.run_id -ne $runId) { throw 'Stale benchmark output.' }
    $outputPath = Join-Path $outputDirectory 'detector-benchmark.json'
    [IO.File]::WriteAllText($outputPath, ($raw -join [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
    Write-Host "Results: $outputPath"
    $result.rounds | Select-Object round,median_ms,p95_ms,rss_bytes | Format-Table
} finally { Pop-Location }
