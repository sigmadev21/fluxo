<#
.SYNOPSIS
  Fluxo uninstaller for Windows. Removes the container and the image.
  Docker Desktop itself is left untouched.

.EXAMPLE
  .\uninstall.ps1
  .\uninstall.ps1 -Purge     # also deletes the downloaded folder
#>
[CmdletBinding()]
param(
  [string]$Dir = (Join-Path $HOME "fluxo"),
  [switch]$Purge,
  [switch]$KeepImage,
  [switch]$Yes
)

$ErrorActionPreference = "Stop"
$App = "fluxo"; $Image = "fluxo:latest"

function Ok($m)   { Write-Host "[ok] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "[x] $m" -ForegroundColor Red; exit 1 }
function Confirm-Action($q) {
  if ($Yes) { return $true }
  return ((Read-Host "$q [y/N]") -match "^[Yy]")
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { Die "Docker is not installed, so there is no Fluxo container to remove." }
cmd /c "docker info >nul 2>nul"
if ($LASTEXITCODE -ne 0) { Die "Docker is not running. Open Docker Desktop and try again." }

$what = if ($KeepImage) { "container" } else { "container and image" }
if (-not (Confirm-Action "Remove the Fluxo $what?")) { Warn "Cancelled."; exit 0 }

cmd /c "docker inspect $App >nul 2>nul"
if ($LASTEXITCODE -eq 0) { cmd /c "docker rm -f $App >nul 2>nul"; Ok "Container removed." } else { Warn "No container named '$App' was found." }

if (-not $KeepImage) {
  cmd /c "docker image inspect $Image >nul 2>nul"
  if ($LASTEXITCODE -eq 0) { cmd /c "docker rmi $Image >nul 2>nul"; Ok "Image removed." }
}

if ($Purge) {
  if (Test-Path $Dir) {
    if ((Test-Path (Join-Path $Dir "index.html")) -and (Test-Path (Join-Path $Dir "Dockerfile"))) {
      if (Confirm-Action "Delete the folder $Dir (including certificates)?") { Remove-Item $Dir -Recurse -Force; Ok "Deleted $Dir" }
    } else { Warn "$Dir doesn't look like a Fluxo folder. Skipping." }
  } else { Warn "Folder $Dir not found." }
}

Write-Host "`n   Your accounts and transactions are stored in your browser (Local Storage) and were NOT deleted."
Write-Host "   To erase them too, clear this site's data in your browser settings.`n"
