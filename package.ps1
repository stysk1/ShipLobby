#Requires -Version 5
<#
.SYNOPSIS
    Build the mod and assemble a Thunderstore-format zip in ./dist for sharing or upload.
.DESCRIPTION
    Produces dist/<name>-<version>.zip (name + version from manifest.json), flat layout:
    manifest.json, icon.png, README.md, CHANGELOG.md, ShipLobby.dll.
.EXAMPLE
    ./package.ps1
#>
[CmdletBinding()]
param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

$manifest = Get-Content (Join-Path $root "manifest.json") -Raw | ConvertFrom-Json
$name = $manifest.name
$version = $manifest.version_number
$zipName = "$name-$version.zip"
$distDir = Join-Path $root "dist"
$buildDir = Join-Path $root "ShipLobby" "bin"

Write-Host "Packaging $name v$version..." -ForegroundColor Cyan

# ── Build ────────────────────────────────────────────────────────────────────
Write-Host "Restoring tools..." -ForegroundColor Cyan
dotnet tool restore
if ($LASTEXITCODE -ne 0) { throw "dotnet tool restore failed." }

Write-Host "Building ($Configuration)..." -ForegroundColor Cyan
dotnet build ShipLobby/ShipLobby.csproj -c $Configuration
if ($LASTEXITCODE -ne 0) { throw "Build failed." }

# ── Package ───────────────────────────────────────────────────────────────────
Write-Host "Creating distribution zip..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $distDir | Out-Null

# Create zip contents
$zipContent = @(
    @{ Src = "manifest.json"; Dst = "manifest.json" }
    @{ Src = "icon.png"; Dst = "icon.png" }
    @{ Src = "README.md"; Dst = "README.md" }
    @{ Src = "CHANGELOG.md"; Dst = "CHANGELOG.md" }
    @{ Src = (Join-Path $buildDir "$name.dll"); Dst = "$name.dll" }
)

# Build archive
$zipPath = Join-Path $distDir $zipName
$tempDir = Join-Path $env:TEMP "ShipLobby_pkg_$([guid]::NewGuid())"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

try {
    foreach ($item in $zipContent) {
        $src = Join-Path $root $item.Src
        if (-not (Test-Path $src)) {
            Write-Host "Warning: $($item.Src) not found" -ForegroundColor Yellow
            continue
        }
        Copy-Item -Path $src -Destination (Join-Path $tempDir $item.Dst) -Force
    }

    # Create zip using System.IO.Compression
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $zipPath)

    Write-Host "Packaged $zipName -> $distDir" -ForegroundColor Green
}
finally {
    Remove-Item -Recurse -Force -Path $tempDir -ErrorAction SilentlyContinue
}
