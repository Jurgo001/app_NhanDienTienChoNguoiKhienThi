param(
    [string]$FlutterSdk = 'D:\sdk_flutter\flutter',
    [string]$ScratchRoot = (Join-Path ([IO.Path]::GetTempPath()) 'money_app_build')
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$flutterBat = Join-Path $FlutterSdk 'bin\flutter.bat'
if (-not (Test-Path -LiteralPath $flutterBat -PathType Leaf)) {
    throw "Khong tim thay Flutter: $flutterBat. Truyen -FlutterSdk duong_dan_sdk."
}
if ($FlutterSdk -match '[^\x00-\x7F]') {
    throw 'Flutter SDK can nam trong thu muc khong dau.'
}
$scratchBase = [IO.Path]::GetFullPath($ScratchRoot).TrimEnd('\')
if ($scratchBase -notmatch '^[A-Za-z]:\\' -or $scratchBase -match '[^\x00-\x7F]') {
    throw 'Truyen -ScratchRoot thu muc tren o dia cuc bo, khong dau, vi du D:\flutter_build.'
}
$buildToken = [Guid]::NewGuid().ToString('N')
$stagingPath = Join-Path $scratchBase $buildToken
$encoding = [Text.UTF8Encoding]::new($false)

function Copy-SourceTree([string]$Source, [string]$Destination) {
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    foreach ($entry in Get-ChildItem -LiteralPath $Source -Force) {
        if ($entry.PSIsContainer) {
            if ($entry.Name -in @('.git','.dart_tool','build','.gradle','.kotlin','.idea','.vscode')) { continue }
            Copy-SourceTree $entry.FullName (Join-Path $Destination $entry.Name)
        } else {
            if ($entry.Name -in @('local.properties','GeneratedPluginRegistrant.java','.flutter-plugins','.flutter-plugins-dependencies')) { continue }
            Copy-Item -LiteralPath $entry.FullName -Destination (Join-Path $Destination $entry.Name)
        }
    }
}
function Invoke-Flutter([string[]]$Arguments) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $flutterBat @Arguments
        $flutterExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($flutterExit -ne 0) { throw "Flutter that bai ($flutterExit): $Arguments" }
}
try {
    New-Item -ItemType Directory -Force -Path $stagingPath | Out-Null
    Write-Host "Build tam: $stagingPath"
    foreach ($directory in @('lib','assets','android')) {
        Copy-SourceTree (Join-Path $projectRoot $directory) (Join-Path $stagingPath $directory)
    }
    foreach ($name in @('pubspec.yaml','pubspec.lock','.metadata','analysis_options.yaml','l10n.yaml')) {
        $sourceFile = Join-Path $projectRoot $name
        if (Test-Path -LiteralPath $sourceFile -PathType Leaf) {
            Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $stagingPath $name)
        }
    }
    # Khong giu Gradle daemon/lock cua workspace tam sau khi build xong.
    [IO.File]::AppendAllText((Join-Path $stagingPath 'android\gradle.properties'),
        [Environment]::NewLine + 'org.gradle.daemon=false' + [Environment]::NewLine, $encoding)
    Push-Location -LiteralPath $stagingPath
    try {
        Invoke-Flutter @('pub','get')
        Invoke-Flutter @('build','apk','--release','--no-pub')
    } finally {
        Pop-Location
    }
    $apkSource = Join-Path $stagingPath 'build\app\outputs\flutter-apk\app-release.apk'
    $outputDirectory = Join-Path $projectRoot 'build\app\outputs\flutter-apk'
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
    $apkTarget = Join-Path $outputDirectory 'app-release.apk'
    Copy-Item -LiteralPath $apkSource -Destination $apkTarget -Force
    Write-Host "APK: $apkTarget" -ForegroundColor Green
    Write-Host ("SHA256: " + (Get-FileHash -LiteralPath $apkTarget -Algorithm SHA256).Hash)
} finally {
    # Chi xoa DUNG workspace GUID vua tao, khong xoa project hay thu muc ScratchRoot.
    $resolvedStage = [IO.Path]::GetFullPath($stagingPath).TrimEnd('\')
    if ([IO.Path]::GetDirectoryName($resolvedStage) -ne $scratchBase -or
        [IO.Path]::GetFileName($resolvedStage) -ne $buildToken) {
        throw "Tu choi don thu muc ngoai workspace tam: $resolvedStage"
    }
    if (Test-Path -LiteralPath $resolvedStage) {
        # Extended-length path de don duoc cache Gradle co ten dai tren Windows.
        [IO.Directory]::Delete(('\\?\' + $resolvedStage), $true)
        Write-Host 'Da don workspace tam.'
    }
}