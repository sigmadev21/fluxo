[CmdletBinding()]
param(
  [switch]$Purge,
  [switch]$KeepImage,
  [string]$Dir = (Join-Path $HOME "fluxo")
)
$ErrorActionPreference = "Stop"
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw "Docker is not installed." }
docker rm -f fluxo 2>$null
if (-not $KeepImage) { docker rmi fluxo:latest 2>$null }
Write-Host "Fluxo container removed. Docker and browser data were not changed." -ForegroundColor Green
if ($Purge -and (Test-Path (Join-Path $Dir "Dockerfile")) -and (Test-Path (Join-Path $Dir "index.html"))) {
  Remove-Item $Dir -Recurse -Force
  Write-Host "Deleted $Dir"
}
