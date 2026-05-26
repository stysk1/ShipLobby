#Requires -Version 5
<#
.SYNOPSIS
    Build the mod and deploy it to an r2modman profile for local testing.
.DESCRIPTION
    Copies the DLL to BepInEx\plugins\stysk1-ShipLobby\ and upserts the mod entry in
    mods.yml so r2modman recognises the mod.
.EXAMPLE
    ./deploy.ps1
.EXAMPLE
    ./deploy.ps1 -Profile "MyTestProfile"
.EXAMPLE
    ./deploy.ps1 -ProfileRoot "C:\custom\r2modmanPlus-local\LethalCompany\profiles\MyProfile"
#>
[CmdletBinding()]
param(
    [string]$Profile     = "Default",
    [string]$ProfileRoot = "",
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

# Resolve profile root from name, or use the explicit override.
$r2Base = "$env:APPDATA\r2modmanPlus-local\LethalCompany\profiles"
if (-not $ProfileRoot) { $ProfileRoot = Join-Path $r2Base $Profile }
if (-not (Test-Path $ProfileRoot)) { throw "Profile folder not found: $ProfileRoot" }

$pluginDir = Join-Path $ProfileRoot "BepInEx\plugins\stysk1-ShipLobby"
$modsYmlPath = Join-Path $ProfileRoot "mods.yml"

# Read manifest for metadata
$manifest = Get-Content (Join-Path $root "manifest.json") -Raw | ConvertFrom-Json

# ── Build ────────────────────────────────────────────────────────────────────
Write-Host "Restoring tools..." -ForegroundColor Cyan
dotnet tool restore
if ($LASTEXITCODE -ne 0) { throw "dotnet tool restore failed." }

Write-Host "Building ($Configuration)..." -ForegroundColor Cyan
dotnet build ShipLobby/ShipLobby.csproj -c $Configuration
if ($LASTEXITCODE -ne 0) { throw "Build failed." }

# ── Deploy ────────────────────────────────────────────────────────────────────
Write-Host ""
New-Item -ItemType Directory -Force -Path $pluginDir | Out-Null
Copy-Item -Path "ShipLobby/bin/$($manifest.name).dll" -Destination $pluginDir -Force
Write-Host "Deployed $($manifest.name).dll -> $pluginDir" -ForegroundColor Green

# Update mods.yml: upsert entry, keeping file format intact
$versionParts = $manifest.version_number -split '\.'

# Build dependency list lines from manifest.json
$depLines = ($manifest.dependencies | ForEach-Object { "    - $_" }) -join "`n"

$installedAt = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

$yamlBlock = @"
- manifestVersion: 1
  name: stysk1-ShipLobby
  authorName: stysk1
  websiteUrl: $($manifest.website_url)
  displayName: ShipLobby
  description: $($manifest.description)
  gameVersion: '0'
  networkMode: both
  packageType: other
  installMode: managed
  installedAtTime: $installedAt
  loaders: []
  dependencies:
$depLines
  incompatibilities: []
  optionalDependencies: []
  versionNumber:
    major: $($versionParts[0])
    minor: $($versionParts[1])
    patch: $($versionParts[2])
  enabled: true
"@

if (-not (Test-Path $modsYmlPath) -or ((Get-Content $modsYmlPath -Raw).Trim() -match '^\[?\]?$')) {
    [System.IO.File]::WriteAllText($modsYmlPath, $yamlBlock, [System.Text.Encoding]::UTF8)
} else {
    $existing = [System.IO.File]::ReadAllText($modsYmlPath)
    $blocks   = ($existing -split '(?m)(?=^- manifestVersion:)') |
                Where-Object { $_.Trim() -ne '' -and $_ -notmatch '  name: (?:tinyhoot|stysk1)-ShipLobby\b' } |
                ForEach-Object { $_.TrimEnd() + "`n" }
    [System.IO.File]::WriteAllText($modsYmlPath, (($blocks + $yamlBlock) -join '').TrimStart(), [System.Text.Encoding]::UTF8)
}
Write-Host "Updated mods.yml  -> $modsYmlPath" -ForegroundColor Green
