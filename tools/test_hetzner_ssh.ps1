# Loads non-secret Hetzner SSH metadata and runs a harmless diagnostic command.
$ErrorActionPreference = "Stop"

$localConfig = Join-Path $PSScriptRoot "hetzner_connection.local.ps1"
if (Test-Path $localConfig) {
    . $localConfig
}

if (-not $HETZNER_HOST) { $HETZNER_HOST = $env:HETZNER_HOST }
if (-not $HETZNER_USER) { $HETZNER_USER = $env:HETZNER_USER }
if (-not $SSH_PORT) { $SSH_PORT = $env:SSH_PORT }
if (-not $HETZNER_SSH_KEY) { $HETZNER_SSH_KEY = $env:HETZNER_SSH_KEY }
if (-not $HETZNER_SSH_ALIAS) { $HETZNER_SSH_ALIAS = $env:HETZNER_SSH_ALIAS }

if (-not $HETZNER_USER) { $HETZNER_USER = "root" }
if (-not $SSH_PORT) { $SSH_PORT = 22 }

$sshArgs = @(
    "-o", "BatchMode=yes",
    "-o", "ConnectTimeout=10",
    "-o", "StrictHostKeyChecking=accept-new"
)

if ($HETZNER_SSH_KEY) {
    if (-not (Test-Path $HETZNER_SSH_KEY)) {
        Write-Error "HETZNER_SSH_KEY does not exist: $HETZNER_SSH_KEY"
        exit 1
    }
    $sshArgs += @("-i", $HETZNER_SSH_KEY)
}

if ($HETZNER_SSH_ALIAS) {
    $target = $HETZNER_SSH_ALIAS
} else {
    if (-not $HETZNER_HOST) {
        Write-Error "Set HETZNER_HOST or HETZNER_SSH_ALIAS."
        exit 1
    }
    $sshArgs += @("-p", [string]$SSH_PORT)
    $target = "$HETZNER_USER@$HETZNER_HOST"
}

$remoteCommand = "uname -a; whoami; hostname; python3 --version; nvidia-smi 2>/dev/null || true"
Write-Host "Testing SSH target: $target"
& ssh @sshArgs $target $remoteCommand
$exitCode = $LASTEXITCODE
if ($exitCode -eq 0) {
    Write-Host "Hetzner SSH diagnostic succeeded."
} else {
    Write-Error "Hetzner SSH diagnostic failed with exit code $exitCode."
}
exit $exitCode
