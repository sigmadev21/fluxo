<#
.SYNOPSIS
  Fluxo updater for Windows. Downloads the latest version, rebuilds the image and
  restarts the container, keeping the ports and HTTP/HTTPS mode you installed with.

.EXAMPLE
  .\update.ps1
#>
[CmdletBinding()]
param([string]$Dir = (Join-Path $HOME "fluxo"))

$ErrorActionPreference = "Stop"
$App = "fluxo"; $Image = "fluxo:latest"
$InstallerUrl = "https://raw.githubusercontent.com/sigmadev21/fluxo/main/install.ps1"

function Log($m)  { Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[ok] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "[x] $m" -ForegroundColor Red; exit 1 }

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { Die "Docker is not installed. Run install.ps1 first." }
cmd /c "docker info >nul 2>nul"
if ($LASTEXITCODE -ne 0) { Die "Docker is not running. Open Docker Desktop and try again." }

$params = @{}
cmd /c "docker inspect $App >nul 2>nul"
if ($LASTEXITCODE -eq 0) {
  $http  = ((& docker port $App 80/tcp  2>$null) | Select-Object -First 1) -replace '.*:', ''
  $https = ((& docker port $App 443/tcp 2>$null) | Select-Object -First 1) -replace '.*:', ''
  if ($https) { $params["Https"] = $true; $params["HttpsPort"] = [int]$https; Log "Keeping HTTPS on port $https" }
  elseif ($http) { $params["Port"] = [int]$http; Log "Keeping HTTP on port $http" }
} else {
  Warn "No existing Fluxo container found. A fresh install with default settings will be done."
}

$installer = Join-Path $Dir "install.ps1"
if (-not (Test-Path $installer) -and $PSScriptRoot) { $installer = Join-Path $PSScriptRoot "install.ps1" }
if (-not (Test-Path $installer)) {
  $installer = Join-Path ([IO.Path]::GetTempPath()) "fluxo-install.ps1"
  Invoke-WebRequest -Uri $InstallerUrl -OutFile $installer -UseBasicParsing
}

$oldId = (& docker image inspect -f "{{.Id}}" $Image 2>$null)

Log "Updating Fluxo in $Dir..."
Push-Location ([IO.Path]::GetTempPath())   # neutral folder, so the installer fetches the latest source
try { & $installer -Update -Yes -Dir $Dir @params } finally { Pop-Location }

$newId = (& docker image inspect -f "{{.Id}}" $Image 2>$null)
if ($oldId -and $oldId -eq $newId) { Ok "You were already on the latest version." } else { Ok "Fluxo updated." }
Write-Host "   Your accounts and transactions live in your browser, so nothing was lost."
