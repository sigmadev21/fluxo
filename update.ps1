[CmdletBinding()]
param([string]$Dir = (Join-Path $HOME "fluxo"))
$ErrorActionPreference = "Stop"
$Installer = Join-Path ([IO.Path]::GetTempPath()) "fluxo-install.ps1"
$Url = "https://raw.githubusercontent.com/sigmadev21/fluxo/main/install.ps1"
Invoke-WebRequest -Uri $Url -OutFile $Installer
try {
  $Http = (docker port fluxo 80/tcp 2>$null | Select-Object -First 1) -replace '.*:', ''
  $Https = (docker port fluxo 443/tcp 2>$null | Select-Object -First 1) -replace '.*:', ''
  $DockerArgs = @("-Dir",$Dir,"-Update")
  if ($Https) { $DockerArgs += @("-Https","-HttpsPort",$Https) }
  elseif ($Http) { $DockerArgs += @("-Port",$Http) }
  & $Installer @Args
  if ($LASTEXITCODE -ne 0) { throw "Fluxo update failed." }
} finally { Remove-Item $Installer -Force -ErrorAction SilentlyContinue }
