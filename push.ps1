#!/usr/bin/env pwsh
param(
    [string]$Tag = ""
)

$ErrorActionPreference = "Stop"

$REPO = "writeameer/dstream-counter-input-provider"

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
# Map .NET RIDs to Go runtime.GOOS/GOARCH format expected by DStream CLI
# ---------------------------------------------------------------------------
$targets = @(
    @{ rid = "linux-x64"; platform = "linux_amd64" },
    @{ rid = "linux-arm64"; platform = "linux_arm64" },
    @{ rid = "osx-x64"; platform = "darwin_amd64" },
    @{ rid = "osx-arm64"; platform = "darwin_arm64" },
    @{ rid = "win-x64"; platform = "windows_amd64" }
)

foreach ($target in $targets) {
    $rid = $target.rid
    $platform = $target.platform
    $outfile = "plugin.$platform"
    if ($platform -like "windows_*") {
        $outfile += ".exe"
    }
    
    Write-Host "   • $outfile" -ForegroundColor Yellow
    
    & /usr/local/share/dotnet/dotnet publish `
        --configuration Release `
        --runtime $rid `
        --self-contained true `
        --output "$TmpDir/$rid" `
        /p:PublishSingleFile=true `
        /p:PublishTrimmed=false
    
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed for $rid"
    }
    
    # Copy the published binary to DStream CLI expected name
    if ($rid -like "win-*") {
        Copy-Item "$TmpDir/$rid/counter-input-provider.exe" "$TmpDir/$outfile"
    } else {
        Copy-Item "$TmpDir/$rid/counter-input-provider" "$TmpDir/$outfile"
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
    platforms = $targets | ForEach-Object { $_.platform }
}

$manifest | ConvertTo-Json -Depth 10 | Set-Content "$TmpDir/provider.json"

# ---------------------------------------------------------------------------
# Push as OCI artifact
# ---------------------------------------------------------------------------
Push-Location $TmpDir

# Authenticate with GHCR using GITHUB_TOKEN from PowerShell profile
if ($env:GITHUB_TOKEN) {
    Write-Host "🔐 Authenticating with GitHub Container Registry..." -ForegroundColor Green
    $env:GITHUB_TOKEN | /usr/local/bin/oras login ghcr.io --username writeameer --password-stdin --registry-config ~/.oras-config
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to authenticate with GHCR"
    }
} else {
    Write-Warning "GITHUB_TOKEN not found in environment. Make sure your PowerShell profile is loaded."
}

Write-Host "📦 Pushing to ghcr.io/$REPO`:$Tag" -ForegroundColor Cyan

& /usr/local/bin/oras push "ghcr.io/$REPO`:$Tag" `
    --registry-config ~/.oras-config `
    --artifact-type "application/vnd.dstream.provider" `
    --annotation "org.opencontainers.image.description=DStream counter input provider" `
    --annotation "org.opencontainers.image.source=https://github.com/katasec/dstream-providers" `
    --annotation "org.opencontainers.image.version=$Tag" `
    plugin.linux_amd64 `
    plugin.linux_arm64 `
    plugin.darwin_amd64 `
    plugin.darwin_arm64 `
    plugin.windows_amd64.exe `
    provider.json

if ($LASTEXITCODE -ne 0) {
    throw "Failed to push OCI artifact"
}

Pop-Location

Write-Host "✅ Provider + manifest pushed: $Tag" -ForegroundColor Green

# Cleanup
& $CleanupTmpDir