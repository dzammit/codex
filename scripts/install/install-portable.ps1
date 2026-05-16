param(
    [Parameter(Position = 0)]
    [string]$PortableRoot = ".\codex-portable",

    [Parameter(Position = 1)]
    [string]$Version = "latest"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Step {
    param(
        [string]$Message
    )

    Write-Host "==> $Message"
}

function Normalize-Version {
    param(
        [string]$RawVersion
    )

    if ([string]::IsNullOrWhiteSpace($RawVersion) -or $RawVersion -eq "latest") {
        return "latest"
    }

    if ($RawVersion.StartsWith("rust-v")) {
        return $RawVersion.Substring(6)
    }

    if ($RawVersion.StartsWith("v")) {
        return $RawVersion.Substring(1)
    }

    return $RawVersion
}

function Resolve-Version {
    $normalizedVersion = Normalize-Version -RawVersion $Version
    if ($normalizedVersion -ne "latest") {
        return $normalizedVersion
    }

    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/openai/codex/releases/latest"
    if (-not $release.tag_name) {
        throw "Failed to resolve the latest Codex release version."
    }

    return (Normalize-Version -RawVersion $release.tag_name)
}

function Get-ReleaseUrl {
    param(
        [string]$AssetName,
        [string]$ResolvedVersion
    )

    return "https://github.com/openai/codex/releases/download/rust-v$ResolvedVersion/$AssetName"
}

function Get-LauncherContents {
    @'
@echo off
setlocal
set "PORTABLE_ROOT=%~dp0"
if "%PORTABLE_ROOT:~-1%"=="\" set "PORTABLE_ROOT=%PORTABLE_ROOT:~0,-1%"
set "BIN_DIR=%PORTABLE_ROOT%\bin"
set "DATA_DIR=%PORTABLE_ROOT%\data"

if not exist "%BIN_DIR%\codex.exe" (
    echo Error: "%BIN_DIR%\codex.exe" was not found.
    exit /b 1
)

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" >nul 2>nul
if not exist "%DATA_DIR%\log" mkdir "%DATA_DIR%\log" >nul 2>nul
if not exist "%DATA_DIR%\tmp" mkdir "%DATA_DIR%\tmp" >nul 2>nul

set "CODEX_HOME=%DATA_DIR%"
set "TMP=%DATA_DIR%\tmp"
set "TEMP=%DATA_DIR%\tmp"
set "PATH=%BIN_DIR%;%PATH%"
set "MODE_ARGS="

echo.
echo ========================================================
echo   Portable Codex
echo ========================================================
echo   Portable Root: %PORTABLE_ROOT%
echo   Data Path:     %DATA_DIR%
echo ========================================================
echo.
choice /C YN /N /M "Run in YOLO mode (dangerous: no approvals, no sandbox)? [Y/N]: "
if errorlevel 2 goto normal_mode
if errorlevel 1 goto yolo_mode

:yolo_mode
set "MODE_ARGS=--dangerously-bypass-approvals-and-sandbox"
goto run_codex

:normal_mode
set "MODE_ARGS="

:run_codex

call "%BIN_DIR%\codex.exe" %MODE_ARGS% %*
set "CODEX_EXIT=%ERRORLEVEL%"
endlocal & exit /b %CODEX_EXIT%
'@
}

function Get-ConfigContents {
    @'
cli_auth_credentials_store_mode = "file"
mcp_oauth_credentials_store_mode = "file"
'@
}

if ($env:OS -ne "Windows_NT") {
    throw "install-portable.ps1 supports Windows only."
}

if (-not [Environment]::Is64BitOperatingSystem) {
    throw "Codex requires a 64-bit version of Windows."
}

$architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
$target = $null
$platformLabel = $null
$npmTag = $null
switch ($architecture) {
    "Arm64" {
        $target = "aarch64-pc-windows-msvc"
        $platformLabel = "Windows (ARM64)"
        $npmTag = "win32-arm64"
    }
    "X64" {
        $target = "x86_64-pc-windows-msvc"
        $platformLabel = "Windows (x64)"
        $npmTag = "win32-x64"
    }
    default {
        throw "Unsupported architecture: $architecture"
    }
}

$portableRoot = [System.IO.Path]::GetFullPath($PortableRoot)
$binDir = Join-Path $portableRoot "bin"
$dataDir = Join-Path $portableRoot "data"
New-Item -ItemType Directory -Force -Path $portableRoot | Out-Null
New-Item -ItemType Directory -Force -Path $binDir | Out-Null
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
[System.IO.Directory]::CreateDirectory((Join-Path $dataDir "log")) | Out-Null
[System.IO.Directory]::CreateDirectory((Join-Path $dataDir "tmp")) | Out-Null

$resolvedVersion = Resolve-Version
$packageAsset = "codex-npm-$npmTag-$resolvedVersion.tgz"
$url = Get-ReleaseUrl -AssetName $packageAsset -ResolvedVersion $resolvedVersion

Write-Step "Preparing portable Codex installation"
Write-Step "Detected platform: $platformLabel"
Write-Step "Portable root: $portableRoot"
Write-Step "Resolved version: $resolvedVersion"

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-portable-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

try {
    $archivePath = Join-Path $tempDir $packageAsset
    $extractDir = Join-Path $tempDir "extract"

    Write-Step "Downloading portable package"
    Invoke-WebRequest -Uri $url -OutFile $archivePath

    New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
    tar -xzf $archivePath -C $extractDir

    $vendorRoot = Join-Path $extractDir "package/vendor/$target"
    $copyMap = @{
        "codex/codex.exe" = "codex.exe"
        "codex/codex-command-runner.exe" = "codex-command-runner.exe"
        "codex/codex-windows-sandbox-setup.exe" = "codex-windows-sandbox-setup.exe"
        "path/rg.exe" = "rg.exe"
    }

    Write-Step "Copying binaries"
    foreach ($relativeSource in $copyMap.Keys) {
        $sourcePath = Join-Path $vendorRoot $relativeSource
        $destinationPath = Join-Path $binDir $copyMap[$relativeSource]
        Copy-Item -Force $sourcePath $destinationPath
    }
} finally {
    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
}

$launcherPath = Join-Path $portableRoot "codex_portable.bat"
$configPath = Join-Path $dataDir "config.toml"

Write-Step "Writing launcher"
Set-Content -Path $launcherPath -Value (Get-LauncherContents) -NoNewline

if (-not (Test-Path $configPath)) {
    Write-Step "Writing portable config"
    Set-Content -Path $configPath -Value (Get-ConfigContents) -NoNewline
} else {
    Write-Step "Leaving existing data\\config.toml in place"
}

Write-Step "Portable Codex is ready"
Write-Host ""
Write-Host "Run: $launcherPath"
Write-Host "Portable state lives under: $dataDir"
Write-Host "ChatGPT/API auth, logs, sessions, and MCP OAuth fallbacks will stay in that folder."
