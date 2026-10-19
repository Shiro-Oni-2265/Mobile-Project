param(
    [ValidateSet('run', 'test', 'analyze', 'build', 'integration')]
    [string]$Action = 'run',
    [string]$DeviceId,
    [string]$ConfigPath,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)
$ErrorActionPreference = 'Stop'
$naugiRoot = Split-Path $PSScriptRoot -Parent
$repositoryRoot = Split-Path $naugiRoot -Parent
Push-Location $naugiRoot
try {
    $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
    $naugiFlutter = if ($flutterCommand) { $flutterCommand.Source } else { Join-Path $repositoryRoot '.tools/flutter/bin/flutter.bat' }
    if (-not (Test-Path -LiteralPath $naugiFlutter)) {
        throw 'Flutter was not found. Add Flutter to PATH or install it in repository .tools/flutter.'
    }
    $env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
    $naugiTemp = Join-Path $repositoryRoot '.tools/tmp'
    New-Item -ItemType Directory -Force -Path $naugiTemp | Out-Null
    if ($env:JAVA_TOOL_OPTIONS -notmatch 'jdk.net.unixdomain.tmpdir') {
        $env:JAVA_TOOL_OPTIONS = ($env:JAVA_TOOL_OPTIONS + ' "-Djdk.net.unixdomain.tmpdir=' + $naugiTemp + '"').Trim()
    }
    [string[]]$naugiArgs = switch ($Action) {
        'run' { @('run', '--flavor', 'demo', '-t', 'lib/main.dart') }
        'test' { @('test') }
        'analyze' { @('analyze') }
        'build' { @('build', 'apk', '--release', '--flavor', 'demo', '-t', 'lib/main.dart') }
        'integration' { @('test', 'integration_test/guest_flow_test.dart', '--flavor', 'demo') }
    }
    if ($Action -in @('run', 'build', 'integration')) {
        if (-not $ConfigPath) {
            $ConfigPath = if (Test-Path -LiteralPath 'config/dev.json') { 'config/dev.json' } else { 'config/dev.example.json' }
        }
        if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Configuration file not found: $ConfigPath" }
        $naugiArgs += "--dart-define-from-file=$ConfigPath"
    }
    if ($DeviceId -and $Action -in @('run', 'integration')) { $naugiArgs += @('-d', $DeviceId) }
    if ($FlutterArgs) { $naugiArgs += $FlutterArgs }
    & $naugiFlutter --no-version-check @naugiArgs
    $naugiExitCode = $LASTEXITCODE
} finally { Pop-Location }
exit $naugiExitCode
