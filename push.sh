#!/usr/bin/env bash
set -euo pipefail

# Add /usr/local/bin to PATH for oras
export PATH="/usr/local/bin:$PATH"

REPO="katasec/dstream-counter-input-provider"

# ---------------------------------------------------------------------------
# Work out the tag to push (last git tag by default)
# Allow override via env var, e.g. TAG=v0.1.0 ./push.sh
# ---------------------------------------------------------------------------
TAG="${TAG:-$(git describe --tags --abbrev=0 2>/dev/null || echo 'v0.1.0')}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "🔧 Building cross-platform .NET binaries …"

# ---------------------------------------------------------------------------
# Build matrix - .NET runtime identifiers
# ---------------------------------------------------------------------------
targets=(
  "linux-x64"
  "linux-arm64"
  "osx-x64"
  "osx-arm64"
  "win-x64"
)

for runtime in "${targets[@]}"; do
  outfile="provider.${runtime}"
  [[ $runtime == win-* ]] && outfile+=".exe"
  
  echo "   • $outfile"
  /usr/local/share/dotnet/dotnet publish \
    --configuration Release \
    --runtime "$runtime" \
    --self-contained true \
    --output "${TMP_DIR}/${runtime}" \
    /p:PublishSingleFile=true \
    /p:PublishTrimmed=false
  
  # Copy the published binary to standardized name
  if [[ $runtime == win-* ]]; then
    cp "${TMP_DIR}/${runtime}/counter-input-provider.exe" "${TMP_DIR}/${outfile}"
  else
    cp "${TMP_DIR}/${runtime}/counter-input-provider" "${TMP_DIR}/${outfile}"
  fi
done

# ---------------------------------------------------------------------------
# Create provider manifest
# ---------------------------------------------------------------------------
cat > "${TMP_DIR}/provider.json" << EOF
{
  "name": "dstream-counter-input-provider",
  "version": "${TAG}",
  "description": "DStream counter input provider for testing and development",
  "type": "input",
  "sdk_version": "0.1.1",
  "config_schema": {
    "interval": {
      "type": "integer",
      "description": "Interval in milliseconds between counter increments",
      "default": 1000
    },
    "max_count": {
      "type": "integer", 
      "description": "Maximum count before stopping (0 for infinite)",
      "default": 0
    }
  },
  "platforms": [
    "linux-x64",
    "linux-arm64", 
    "osx-x64",
    "osx-arm64",
    "win-x64"
  ]
}
EOF

# ---------------------------------------------------------------------------
# Push as OCI artifact
# ---------------------------------------------------------------------------
cd "$TMP_DIR"

# Authenticate with GHCR if GITHUB_TOKEN is available
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  echo "🔐 Authenticating with GitHub Container Registry..."
  echo "$GITHUB_TOKEN" | oras login ghcr.io --username writeameer --password-stdin
fi

echo "📦 Pushing to ghcr.io/${REPO}:${TAG}"
oras push "ghcr.io/${REPO}:${TAG}" \
  --artifact-type "application/vnd.dstream.provider" \
  --annotation "org.opencontainers.image.description=DStream counter input provider" \
  --annotation "org.opencontainers.image.source=https://github.com/katasec/dstream-providers" \
  --annotation "org.opencontainers.image.version=${TAG}" \
  provider.linux-x64 \
  provider.linux-arm64 \
  provider.osx-x64 \
  provider.osx-arm64 \
  provider.win-x64.exe \
  provider.json

echo "✅ Provider + manifest pushed: ${TAG}"