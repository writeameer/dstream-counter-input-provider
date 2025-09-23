#!/usr/bin/env pwsh
param(
    [string]$Tag = ""
)

$ErrorActionPreference = "Stop"

$REPO = "katasec/dstream-counter-input-provider"

# ---------------------------------------------------------------------------
# Work out the tag to push (last git tag by default)
# Allow override via parameter, e.g. ./push.ps1 -Tag "v0.1.0"
# ---------------------------------------------------------------------------
if (-not $Tag) {
    try {
        $Tag = git describe --tags --abbrev=0 2>$null
    }
    catch {
        $Tag = "v0.1.0"
    }
}

$TmpDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_.FullName }
$CleanupTmpDir = {
    if (Test-Path $TmpDir) {
        Remove-Item $TmpDir -Recurse -Force
    }
}
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action $CleanupTmpDir

Write-Host "🔧 Building cross-platform .NET binaries …" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Build matrix - .NET runtime identifiers
# ---------------------------------------------------------------------------
$targets = @(
    "linux-x64",
    "linux-arm64",
    "osx-x64",
    "osx-arm64",
    "win-x64"
)

foreach ($runtime in $targets) {
    $outfile = "provider.$runtime"
    if ($runtime -like "win-*") {
        $outfile += ".exe"
    }
    
    Write-Host "   • $outfile" -ForegroundColor Yellow
    
    & /usr/local/share/dotnet/dotnet publish `
        --configuration Release `
        --runtime $runtime `
        --self-contained true `
        --output "$TmpDir/$runtime" `
        /p:PublishSingleFile=true `
        /p:PublishTrimmed=false
    
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed for $runtime"
    }
    
    # Copy the published binary to standardized name
    if ($runtime -like "win-*") {
        Copy-Item "$TmpDir/$runtime/counter-input-provider.exe" "$TmpDir/$outfile"
    } else {
        Copy-Item "$TmpDir/$runtime/counter-input-provider" "$TmpDir/$outfile"
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

# ---------------------------------------------------------------------------
# Push as OCI artifact (SKIP AUTHENTICATION - assumes already authenticated)
# ---------------------------------------------------------------------------
Push-Location $TmpDir

Write-Host "📦 Pushing to ghcr.io/$REPO`:$Tag (assuming already authenticated)" -ForegroundColor Cyan

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