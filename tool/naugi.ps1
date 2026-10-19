param(
    [ValidateSet('run', 'test', 'analyze', 'build', 'integration')]
    [string]$Action = 'run',
    [string]$DeviceId,
    [switch]$Cloud
)
$ErrorActionPreference = 'Stop'
$naugiRoot = Split-Path $PSScriptRoot -Parent
Push-Location $naugiRoot
try {
    $naugiFlutter = Join-Path $naugiRoot '.tools/flutter/bin/flutter.bat'
    if (-not (Test-Path -LiteralPath $naugiFlutter)) {
        $naugiFlutter = (Get-Command flutter -ErrorAction Stop).Source
    }
    if (-not $env:ANDROID_HOME -and (Test-Path -LiteralPath 'D:/Android/SDK')) {
        $env:ANDROID_HOME = 'D:/Android/SDK'
    }
    if (-not $env:JAVA_HOME -and (Test-Path -LiteralPath 'D:/Android/Android Studio/jbr')) {
        $env:JAVA_HOME = 'D:/Android/Android Studio/jbr'
    }
    $env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
    $naugiTemp = Join-Path $naugiRoot '.tools/tmp'
    New-Item -ItemType Directory -Force -Path $naugiTemp | Out-Null
    if ($env:JAVA_TOOL_OPTIONS -notmatch 'jdk.net.unixdomain.tmpdir') {
        $env:JAVA_TOOL_OPTIONS = ($env:JAVA_TOOL_OPTIONS + ' "-Djdk.net.unixdomain.tmpdir=' + $naugiTemp + '"').Trim()
    }
    [string[]]$naugiArgs = switch ($Action) {
        'run' { @('run') }
        'test' { @('test') }
        'analyze' { @('analyze') }
        'build' { @('build', 'apk', '--release') }
        'integration' { @('test', 'integration_test/guest_flow_test.dart') }
    }
    if ($Cloud -and $Action -in @('run', 'build')) {
        if (-not (Test-Path -LiteralPath 'config/dev.json')) { throw 'Copy config/dev.example.json to config/dev.json and fill Supabase settings first.' }
        $naugiArgs += '--dart-define-from-file=config/dev.json'
    }
    if ($DeviceId -and $Action -in @('run', 'integration')) { $naugiArgs += @('-d', $DeviceId) }
    & $naugiFlutter @naugiArgs
    $naugiExitCode = $LASTEXITCODE
} finally { Pop-Location }
exit $naugiExitCode
