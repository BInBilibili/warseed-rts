$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$launcher = Join-Path $projectRoot "START_WARSEED.vbs"
if (-not (Test-Path -LiteralPath $launcher)) {
    throw "Launcher not found: $launcher"
}

$protocolKey = "HKCU:\Software\Classes\warseed"
$commandKey = Join-Path $protocolKey "shell\open\command"
New-Item -Path $commandKey -Force | Out-Null
Set-ItemProperty -Path $protocolKey -Name "(Default)" -Value "URL:WARSEED Launcher"
New-ItemProperty -Path $protocolKey -Name "URL Protocol" -Value "" -PropertyType String -Force | Out-Null
$cmd = '"{0}" //B //NoLogo "{1}"' -f (Join-Path $env:SystemRoot "System32\wscript.exe"), $launcher
Set-ItemProperty -Path $commandKey -Name "(Default)" -Value $cmd
Write-Output "Registered warseed://launch -> $launcher (hidden)"
