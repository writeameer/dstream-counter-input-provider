#!/usr/bin/env pwsh
param(
    [string]$Tag = ""
)

$ErrorActionPreference = "Stop"

$REPO = "katasec/dstream-counter-input-provider"

# ---------------------------------------------------------------------------
# Work out the tag to push (last git tag by default)
# ---------------------------------------------------------------------------
if (-not $Tag) {
    try {
        $Tag = git describe --tags --abbrev=0 2>$null
    }
    catch {
        $Tag = "v0.1.0"
    }
}

Write-Host "📦 Creating OCI artifact for tag: $Tag" -ForegroundColor Cyan

# Create temp directory for OCI push
$TmpDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_.FullName }
$CleanupTmpDir = {
    if (Test-Path $TmpDir) {
        Remove-Item $TmpDir -Recurse -Force
    }
}
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action $CleanupTmpDir

# ---------------------------------------------------------------------------
# Copy pre-built binaries from out/ directory
# ---------------------------------------------------------------------------
$targets = @(
    "linux-x64",
    "linux-arm64",
    "osx-x64", 
    "osx-arm64",
    "win-x64"
)

Write-Host "🔄 Copying pre-built binaries..." -ForegroundColor Yellow

foreach ($runtime in $targets) {
    $outfile = "provider.$runtime"
    if ($runtime -like "win-*") {
        $outfile += ".exe"
        $sourceFile = "out/counter-input-provider.exe"
    } else {
        $sourceFile = "out/counter-input-provider"
    }
    
    if (Test-Path $sourceFile) {
        Copy-Item $sourceFile "$TmpDir/$outfile"
        Write-Host "   ✓ $outfile" -ForegroundColor Green
    } else {
        throw "Pre-built binary not found: $sourceFile. Please run the full build first."
    }
}

# ---------------------------------------------------------------------------
# Create provider manifest
# ---------------------------------------------------------------------------
$manifest = @{
    name = "dstream-counter-input-provider"
    version = $Tag
    description = "DStream counter input provider for testing and development"
    type = "input"
    sdk_version = "0.1.1"
    config_schema = @{
        interval = @{
            type = "integer"
            description = "Interval in milliseconds between counter increments"
            default = 1000
        }
        max_count = @{
            type = "integer"
            description = "Maximum count before stopping (0 for infinite)"
            default = 0
        }
    }
    platforms = $targets
}

$manifest | ConvertTo-Json -Depth 10 | Set-Content "$TmpDir/provider.json"
Write-Host "   ✓ provider.json created" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Push as OCI artifact (assumes already authenticated)
# ---------------------------------------------------------------------------
Push-Location $TmpDir

Write-Host "📦 Pushing to ghcr.io/$REPO`:$Tag" -ForegroundColor Cyan

& /usr/local/bin/oras push "ghcr.io/$REPO`:$Tag" `
    --artifact-type "application/vnd.dstream.provider" `
    --annotation "org.opencontainers.image.description=DStream counter input provider" `
    --annotation "org.opencontainers.image.source=https://github.com/katasec/dstream-providers" `
    --annotation "org.opencontainers.image.version=$Tag" `
    provider.linux-x64 `
    provider.linux-arm64 `
    provider.osx-x64 `
    provider.osx-arm64 `
    provider.win-x64.exe `
    provider.json

if ($LASTEXITCODE -ne 0) {
    throw "Failed to push OCI artifact"
}

Pop-Location

Write-Host "✅ Provider + manifest pushed: $Tag" -ForegroundColor Green

# Cleanup
& $CleanupTmpDir