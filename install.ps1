[CmdletBinding()]
param(
  [int]$Port = 8080,
  [int]$HttpsPort = 8443,
  [switch]$Https,
  [switch]$Update,
  [string]$Dir = (Join-Path $HOME "fluxo")
)
$ErrorActionPreference = "Stop"
$App = "fluxo"
$Image = "fluxo:latest"
$ZipUrl = "https://codeload.github.com/sigmadev21/fluxo/zip/HEAD"
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Error "Docker Desktop is required. Install it from https://www.docker.com/products/docker-desktop/ and try again."
}
docker info *> $null
if ($LASTEXITCODE -ne 0) { Write-Error "Start Docker Desktop and try again." }
if ((Test-Path ".\index.html") -and (Test-Path ".\Dockerfile")) {
  $Source = (Get-Location).Path
} else {
  $Temp = Join-Path ([IO.Path]::GetTempPath()) ("fluxo-" + [guid]::NewGuid())
  New-Item -ItemType Directory -Path $Temp | Out-Null
  try {
    Invoke-WebRequest -Uri $ZipUrl -OutFile (Join-Path $Temp "fluxo.zip")
    Expand-Archive -Path (Join-Path $Temp "fluxo.zip") -DestinationPath $Temp
    $Inner = Get-ChildItem $Temp -Directory | Select-Object -First 1
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    Copy-Item (Join-Path $Inner.FullName "*") $Dir -Recurse -Force
  } finally { Remove-Item $Temp -Recurse -Force -ErrorAction SilentlyContinue }
  $Source = $Dir
}
docker build -t $Image $Source
if ($LASTEXITCODE -ne 0) { throw "Docker image build failed." }
docker rm -f $App *> $null
$DockerArgs = @("run","-d","--name",$App,"--restart","unless-stopped","--security-opt","no-new-privileges")
if ($Https) {
  $Certs = Join-Path $Source "certs"
  New-Item -ItemType Directory -Path $Certs -Force | Out-Null
  if (-not (Test-Path (Join-Path $Certs "fluxo.crt"))) {
    docker run --rm -v "${Certs}:/certs" alpine/openssl req -x509 -nodes -newkey rsa:2048 -days 825 -keyout /certs/fluxo.key -out /certs/fluxo.crt -subj "/CN=fluxo.local" -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
  }
  $DockerArgs += @("-p","${HttpsPort}:443","-v","$(Join-Path $Source 'nginx-ssl.conf'):/etc/nginx/conf.d/default.conf:ro","-v","${Certs}:/etc/nginx/certs:ro")
  $Url = "https://localhost:$HttpsPort"
} else {
  $DockerArgs += @("-p","${Port}:80")
  $Url = "http://localhost:$Port"
}
docker @args $Image
if ($LASTEXITCODE -ne 0) { throw "Could not start the Fluxo container." }
Write-Host "Fluxo is running at $Url" -ForegroundColor Green
Write-Host "Update: .\update.ps1 | Uninstall: .\uninstall.ps1"
