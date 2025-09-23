<#  ============================================================================
    build.ps1 – simple task runner
    Usage:
        ./build.ps1               # default (= help)
        ./build.ps1 help          # list tasks
        ./build.ps1 publish       # dotnet publish
        ./build.ps1 clean         # dotnet clean
============================================================================ #>

param(
    [Parameter(Position = 0)]
    [ValidateSet('help','publish','clean')]
    [string]$Task = 'help'
)

function Get-Rid 
{
    $os  = if ($IsWindows) { 'win' }
           elseif ($IsLinux) { 'linux' }
           elseif ($IsMacOS) { 'osx' }

    $arch = switch ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture) {
        'X64'   { 'x64' }
        'X86'   { 'x86' }
        'Arm64' { 'arm64' }
        'Arm'   { 'arm' }
    }

    # WORKAROUND: gRPC.Core doesn't have native ARM64 libraries for macOS
    # Use x64 instead to run under Rosetta 2 translation
    if ($IsMacOS -and $arch -eq 'arm64') {
        Write-Host "→ ARM64 macOS detected: Using osx-x64 target for gRPC compatibility (runs under Rosetta 2)"
        $arch = 'x64'
    }

    return "$os-$arch"
}

function Show-Help 
{
    $tasks = @{
        help    = 'Show this list'
        publish = 'Publish the project'
        clean   = 'Clean build output'
    }
    $tasks.GetEnumerator() |
        Sort-Object Name |
        ForEach-Object {
            # cyan label + white description (fits 30-char width like the Makefile)
            Write-Host ('{0,-30}' -f $_.Key) -ForegroundColor Cyan -NoNewline
            Write-Host $_.Value
        }
}




switch ($Task) 
{
    'publish' {
        Write-Host '→ Publishing…'
        $rid = Get-Rid          # e.g. win-x64, linux-arm64, osx-x64
        Write-Host "→ Target RID: $rid"
        # Use full path to dotnet on macOS
        $dotnetCmd = if ($IsMacOS) { '/usr/local/share/dotnet/dotnet' } else { 'dotnet' }
        & $dotnetCmd publish dstream-dotnet-test.csproj -c Release -r $rid -p:DebugType=none -o out
        # dotnet publish dstream-dotnet-test.csproj -c Release -r win-x64 -p:DebugType=none -o out
    }
    'clean' {
        Write-Host '→ Cleaning…'
        # Force remove problematic cache directories first
        Remove-Item -Recurse -Force obj, bin, out -ErrorAction SilentlyContinue
        $dotnetCmd = if ($IsMacOS) { '/usr/local/share/dotnet/dotnet' } else { 'dotnet' }
        & $dotnetCmd clean
    }
    default {
        Show-Help
    }
}
