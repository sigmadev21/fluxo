<#
.SYNOPSIS
  Fluxo installer for Windows. Installs Docker Desktop (if missing), downloads Fluxo
  and runs it in a container.

.EXAMPLE
  .\install.ps1
  .\install.ps1 -Port 3000
  .\install.ps1 -Https
  .\install.ps1 -Update
  .\install.ps1 -Uninstall
#>
[CmdletBinding()]
param(
  [int]$Port = 8080,
  [int]$HttpsPort = 8443,
  [switch]$Https,
  [string]$Dir = (Join-Path $HOME "fluxo"),
  [switch]$Update,
  [switch]$Status,
  [switch]$Uninstall,
  [switch]$Yes
)

$ErrorActionPreference = "Stop"
$App   = "fluxo"
$Image = "fluxo:latest"
$ZipUrl = "https://codeload.github.com/sigmadev21/fluxo/zip/HEAD"

function Log($m)  { Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[ok] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "[x] $m" -ForegroundColor Red; exit 1 }

# Runs a docker command and stops the script if it fails.
function Invoke-Docker {
  & docker @args
  if ($LASTEXITCODE -ne 0) { Die "docker $($args -join ' ') failed." }
}
function Test-Docker {
  cmd /c "docker info >nul 2>nul"
  return ($LASTEXITCODE -eq 0)
}
function Test-PortBusy([int]$p) {
  return [bool](Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue)
}
function Get-LanIp {
  try {
    (Get-NetIPAddress -AddressFamily IPv4 |
      Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" -and $_.PrefixOrigin -ne "WellKnown" } |
      Select-Object -First 1).IPAddress
  } catch { "" }
}
function Remove-App { cmd /c "docker rm -f $App >nul 2>nul" }

foreach ($p in @($Port, $HttpsPort)) { if ($p -lt 1 -or $p -gt 65535) { Die "Invalid port: $p" } }

Write-Host "`nFluxo installer`n" -ForegroundColor Magenta

# ---- Docker -----------------------------------------------------------------
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  if ($Status -or $Uninstall) { Die "Docker is not installed." }
  if (-not $Yes) {
    $a = Read-Host "Docker was not found. Install Docker Desktop now? [y/N]"
    if ($a -notmatch "^[Yy]") { Die "Docker is required. Aborting." }
  }
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Log "Installing Docker Desktop with winget..."
    winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
    Warn "Docker Desktop was installed. Open it once, finish its setup (it may ask to enable WSL 2 and restart),"
    Warn "then run this script again."
    exit 0
  } else {
    Start-Process "https://www.docker.com/products/docker-desktop/"
    Die "winget not found. Install Docker Desktop from the page that just opened, then run this script again."
  }
}

if (-not (Test-Docker)) {
  Log "Starting Docker Desktop..."
  $exe = Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe"
  if (Test-Path $exe) { Start-Process $exe }
  $ready = $false
  for ($i = 0; $i -lt 90; $i++) { if (Test-Docker) { $ready = $true; break }; Start-Sleep -Seconds 2 }
  if (-not $ready) { Die "The Docker daemon is not responding. Open Docker Desktop and run this script again." }
}
Ok "Docker is ready."

if ($Status) {
  Invoke-Docker ps -a --filter "name=^$App$" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
  exit 0
}
if ($Uninstall) {
  Remove-App
  cmd /c "docker rmi $Image >nul 2>nul"
  Ok "Container and image removed. (Your data lives in your browser and was not touched.)"
  exit 0
}

# ---- Source -----------------------------------------------------------------
if ((Test-Path ".\index.html") -and (Test-Path ".\Dockerfile") -and (Select-String -Path ".\index.html" -Pattern "Fluxo" -Quiet)) {
  $Src = (Get-Location).Path
  Log "Using the current folder: $Src"
} else {
  $Src = $Dir
  Log "Downloading Fluxo into $Src..."
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("fluxo-" + [guid]::NewGuid())
  New-Item -ItemType Directory -Path $tmp | Out-Null
  Invoke-WebRequest -Uri $ZipUrl -OutFile (Join-Path $tmp "fluxo.zip") -UseBasicParsing
  Expand-Archive -Path (Join-Path $tmp "fluxo.zip") -DestinationPath $tmp -Force
  $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
  New-Item -ItemType Directory -Path $Src -Force | Out-Null
  Copy-Item -Path (Join-Path $inner.FullName "*") -Destination $Src -Recurse -Force
  Remove-Item $tmp -Recurse -Force
}
if (-not (Test-Path (Join-Path $Src "Dockerfile"))) { Die "Dockerfile not found in $Src." }

# ---- Build and run ----------------------------------------------------------
Log "Building the image..."
Invoke-Docker build -q -t $Image $Src | Out-Null
Ok "Image built."

Remove-App
$runArgs = @("run", "-d", "--name", $App, "--restart", "unless-stopped", "--security-opt", "no-new-privileges")

if ($Https) {
  if (Test-PortBusy $HttpsPort) { Die "Port $HttpsPort is already in use. Try: .\install.ps1 -Https -HttpsPort 9443" }
  $certs = Join-Path $Src "certs"
  New-Item -ItemType Directory -Path $certs -Force | Out-Null
  if (-not (Test-Path (Join-Path $certs "fluxo.crt"))) {
    Log "Creating a self-signed certificate..."
    $ip = Get-LanIp
    $san = "DNS:localhost,DNS:fluxo.local,IP:127.0.0.1"
    if ($ip) { $san += ",IP:$ip" }
    Invoke-Docker run --rm -v "${certs}:/certs" alpine/openssl req -x509 -nodes -newkey rsa:2048 -days 825 `
      -keyout /certs/fluxo.key -out /certs/fluxo.crt -subj "/CN=fluxo.local" -addext "subjectAltName=$san" | Out-Null
  }
  $runArgs += @("-p", "${HttpsPort}:443",
                "-v", "$(Join-Path $Src 'nginx-ssl.conf'):/etc/nginx/conf.d/default.conf:ro",
                "-v", "${certs}:/etc/nginx/certs:ro")
  $scheme = "https"; $shown = $HttpsPort
} else {
  if (Test-PortBusy $Port) { Die "Port $Port is already in use. Try: .\install.ps1 -Port 3000" }
  $runArgs += @("-p", "${Port}:80")
  $scheme = "http"; $shown = $Port
}
Invoke-Docker @runArgs $Image | Out-Null

Log "Starting Fluxo..."
$healthy = $false
for ($i = 0; $i -lt 30; $i++) {
  # Ask nginx directly instead of waiting for Docker's slower periodic health check.
  cmd /c "docker exec $App wget -qO- http://127.0.0.1/healthz >nul 2>nul"
  if ($LASTEXITCODE -eq 0) { $healthy = $true; break }
  Start-Sleep -Seconds 1
}
if (-not $healthy) { & docker logs --tail 30 $App; Die "Fluxo did not respond in time." }

# ---- Done -------------------------------------------------------------------
$lan = Get-LanIp
Write-Host "`nFluxo is running!`n" -ForegroundColor Green
Write-Host "   On this computer:  ${scheme}://localhost:$shown" -ForegroundColor White
if ($lan) {
  Write-Host "   On your network:   ${scheme}://${lan}:$shown"
  if ($scheme -eq "http") {
    Warn "Sign-in needs a secure context. Over plain HTTP it only works on localhost."
    Warn "For other devices, reinstall with: .\install.ps1 -Https"
  } else {
    Warn "The certificate is self-signed: accept the browser warning once per device."
  }
}
Write-Host "`n   Update:     .\install.ps1 -Update`n   Status:     .\install.ps1 -Status`n   Uninstall:  .\install.ps1 -Uninstall`n"
Write-Host "   Your data stays in your browser (Local Storage), not in the container.`n"
