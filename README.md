# DStream Counter Input Provider

A DStream input provider that generates incrementing counter values for testing and development purposes.

[![NuGet](https://img.shields.io/nuget/v/Katasec.DStream.SDK.Core.svg)](https://www.nuget.org/packages/Katasec.DStream.SDK.Core/)
[![OCI](https://img.shields.io/badge/OCI-ghcr.io-blue)](https://github.com/writeameer/dstream-counter-input-provider/pkgs/container/dstream-counter-input-provider)

## 🚀 Features

- ⏰ **Configurable Intervals**: Generate counters at custom millisecond intervals
- 🔢 **Bounded Generation**: Optional maximum count to prevent infinite streams
- 📦 **Cross-Platform**: Linux, macOS, Windows (x64/ARM64)
- 🐳 **OCI Distribution**: Available as semantic versioned OCI artifacts
- 🛠️ **DStream Native**: Built with DStream .NET SDK for optimal compatibility

## 📦 Quick Start

### Using OCI Artifacts (Production)

```hcl
task "counter-demo" {
  type = "providers"
  
  input {
    provider_ref = "ghcr.io/writeameer/dstream-counter-input-provider:v1.0.0"
    config {
      interval = 1000    # Generate counter every 1 second
      max_count = 10     # Stop after 10 counts (0 = infinite)
    }
  }
  
  output {
    provider_ref = "ghcr.io/writeameer/dstream-console-output-provider:v1.0.0"
    config {
      outputFormat = "simple"
    }
  }
}
```

### Using Local Binaries (Development)

```bash
# Build the provider
dotnet publish -c Release -r osx-arm64 --self-contained

# Test directly
echo '{"interval": 500, "max_count": 5}' | ./bin/Release/net9.0/osx-arm64/publish/counter-input-provider
```

## ⚙️ Configuration

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `interval` | integer | 1000 | Milliseconds between counter increments |
| `max_count` | integer | 0 | Maximum count before stopping (0 = infinite) |

### Example Configurations

**Fast Counter (Every 100ms)**:
```json
{"interval": 100, "max_count": 50}
```

**Slow Counter (Every 5 seconds)**:
```json
{"interval": 5000, "max_count": 0}
```

**Burst Test (Very Fast)**:
```json
{"interval": 10, "max_count": 1000}
```

## 📊 Data Output Format

The provider generates JSON envelopes in DStream standard format:

```json
{
  "data": {
    "value": 42,
    "timestamp": "2025-09-23T10:30:45.123Z"
  },
  "metadata": {
    "seq": 42,
    "interval_ms": 1000,
    "provider": "counter-input-provider"
  }
}
```

## 🏗️ Development

### Prerequisites
- .NET 9.0 SDK
- PowerShell (for build scripts)
- ORAS (for OCI publishing)

### Build and Test
```bash
# Build for current platform
dotnet build

# Build for specific platform
dotnet publish -c Release -r linux-x64 --self-contained

# Test locally
echo '{"interval": 1000, "max_count": 3}' | dotnet run
```

### Publishing OCI Artifacts
```bash
# Build and push with semantic version
pwsh ./push.ps1 -Tag "v1.0.0"

# Auto-increment patch version
pwsh ../version.ps1 patch && pwsh ./push.ps1
```

## 🐳 Available Platforms

| Platform | Runtime ID | Binary Name |
|----------|------------|-------------|
| Linux x64 | linux-x64 | plugin.linux_amd64 |
| Linux ARM64 | linux-arm64 | plugin.linux_arm64 |
| macOS x64 | osx-x64 | plugin.darwin_amd64 |
| macOS ARM64 | osx-arm64 | plugin.darwin_arm64 |
| Windows x64 | win-x64 | plugin.windows_amd64.exe |

## 📚 Usage Examples

### Basic Pipeline
```hcl
task "basic-counter" {
  input {
    provider_ref = "ghcr.io/writeameer/dstream-counter-input-provider:latest"
    config {
      interval = 1000
      max_count = 5
    }
  }
  
  output {
    provider_path = "./my-custom-output-provider"
    config {
      # Your output config
    }
  }
}
```

### Performance Testing
```hcl
task "perf-test" {
  input {
    provider_ref = "ghcr.io/writeameer/dstream-counter-input-provider:latest"
    config {
      interval = 1        # 1ms intervals
      max_count = 100000  # 100k messages
    }
  }
  
  output {
    provider_ref = "ghcr.io/writeameer/dstream-kafka-output-provider:latest"
    config {
      topic = "perf-test"
    }
  }
}
```

## 🔧 Technical Details

- **Language**: C# / .NET 9.0
- **SDK**: [DStream .NET SDK](https://github.com/katasec/dstream-dotnet-sdk)
- **Communication**: JSON over stdin/stdout
- **Architecture**: Single-file executable, self-contained deployment
- **Logging**: Structured logging to stderr (DStream compatible)

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

**Part of the DStream ecosystem** 🌊
- **DStream CLI**: [katasec/dstream](https://github.com/katasec/dstream)
- **DStream .NET SDK**: [katasec/dstream-dotnet-sdk](https://github.com/katasec/dstream-dotnet-sdk)
- **Console Output Provider**: [writeameer/dstream-console-output-provider](https://github.com/writeameer/dstream-console-output-provider)