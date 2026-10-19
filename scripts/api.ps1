param(
    [ValidateSet('start', 'stop', 'logs', 'reset')]
    [string]$Action = 'start',
    [ValidateSet('auto', 'docker', 'node')]
    [string]$Mode = 'auto'
)
$ErrorActionPreference = 'Stop'
$apiRoot = Split-Path $PSScriptRoot -Parent
$backendRoot = Join-Path $apiRoot 'backend'
Push-Location $apiRoot
try {
    $dockerAvailable = $false
    if ($Mode -ne 'node' -and (Get-Command docker -ErrorAction SilentlyContinue)) {
        try {
            & docker info *> $null
            $dockerAvailable = $LASTEXITCODE -eq 0
        } catch {
            # Windows PowerShell treats native stderr as an exception under Stop.
            $dockerAvailable = $false
        }
    }
    if ($Mode -eq 'docker' -and -not $dockerAvailable) {
        throw 'Docker is unavailable. Start Docker Desktop or use -Mode node.'
    }
    if ($Action -eq 'reset') {
        if ($dockerAvailable) {
            & docker compose stop api
            if ($LASTEXITCODE -ne 0) { throw 'Could not stop the Docker API before reset.' }
        }
        $apiPort = if ($env:PORT -and -not $dockerAvailable) { [int]$env:PORT } elseif ($env:API_PORT) { [int]$env:API_PORT } else { 3000 }
        $probe = New-Object System.Net.Sockets.TcpClient
        try {
            $pending = $probe.ConnectAsync('127.0.0.1', $apiPort)
            $null = $pending.Wait(500)
            if ($probe.Connected) { throw 'An API is still running. Stop the foreground Node process with Ctrl+C before reset.' }
        } catch [System.AggregateException] {
            # Connection refused means there is no listener to stop.
        } finally { $probe.Dispose() }
        & node (Join-Path $backendRoot 'scripts/reset.cjs') --reset
        if ($LASTEXITCODE -ne 0) { throw 'Database reset failed.' }
        Write-Host 'Reset complete. Run scripts/api.ps1 -Action start to start the API.'
    } elseif ($dockerAvailable) {
        switch ($Action) {
            'start' { & docker compose up -d --build api }
            'stop' { & docker compose stop api }
            'logs' { & docker compose logs -f api }
        }
        if ($LASTEXITCODE -ne 0) { throw "Docker API $Action failed." }
    } elseif ($Action -eq 'start') {
        if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw 'Install Node.js 20+ or Docker Desktop first.' }
        $nodePort = if ($env:PORT) { [int]$env:PORT } else { 3000 }
        $nodeProbe = New-Object System.Net.Sockets.TcpClient
        try {
            $pending = $nodeProbe.ConnectAsync('127.0.0.1', $nodePort)
            $null = $pending.Wait(500)
            if ($nodeProbe.Connected) { throw "Port $nodePort is already in use. Stop that server or set PORT to an unused port and update API_BASE_URL." }
        } catch [System.AggregateException] {
            # Connection refused: safe to start the API on this port.
        } finally { $nodeProbe.Dispose() }
        Push-Location $backendRoot
        try {
            if (-not (Test-Path -LiteralPath 'node_modules/json-server/package.json')) {
                & npm.cmd ci
                if ($LASTEXITCODE -ne 0) { throw 'npm ci failed.' }
            }
            Write-Host 'Running Node API in the foreground. Press Ctrl+C to stop; writes persist in backend/runtime/db.json.'
            & node scripts/start.cjs
            if ($LASTEXITCODE -ne 0) { throw 'Node API exited with an error.' }
        } finally { Pop-Location }
    } else {
        Write-Host 'Node mode runs in the foreground: use Ctrl+C in its terminal to stop it; logs appear in that terminal.'
    }
} finally { Pop-Location }
