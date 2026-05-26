#Requires -Version 5
<#
.SYNOPSIS
    Build the mod and deploy it to an r2modman profile for local testing.
.DESCRIPTION
    Copies the DLL to BepInEx\plugins\tinyhoot-ShipLobby\ and upserts the mod entry in
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

$pluginDir = Join-Path $ProfileRoot "BepInEx\plugins\tinyhoot-ShipLobby"
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
$modsYmlContent = if (Test-Path $modsYmlPath) { Get-Content $modsYmlPath -Raw } else { "" }

$versionParts = $manifest.version_number -split '\.'
$yamlBlock = @"
- manifestVersion: 1
  name: tinyhoot-ShipLobby
  versionNumber:
    Major: $($versionParts[0])
    Minor: $($versionParts[1])
    Patch: $($versionParts[2])
  dependencies: []
"@

# Split and rebuild: remove old entry, prepend new one
$pattern = "(?m)(?=^- manifestVersion:.*?^(?=- |$))"
$newContent = if ($modsYmlContent -match "tinyhoot-ShipLobby") {
    $modsYmlContent -replace "(?ms)^- manifestVersion:.*?(?=^- |$)", ""
} else {
    $modsYmlContent
}

$newContent = $yamlBlock + "`n" + $newContent

[System.IO.File]::WriteAllText($modsYmlPath, $newContent, [System.Text.Encoding]::UTF8)
Write-Host "Updated mods.yml  -> $modsYmlPath" -ForegroundColor Green
