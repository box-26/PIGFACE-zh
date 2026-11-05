param(
    [string]$GamePath = (Join-Path $PSScriptRoot '..\..\PIGFACE-zh'),
    [int]$Sec = 30,
    [string]$Extra = ""
)
$ErrorActionPreference = 'SilentlyContinue'
$root = (Resolve-Path -LiteralPath $GamePath).Path
$exe = Join-Path $root 'Pigface.exe'
if (-not (Test-Path $exe)) { throw "Pigface.exe not found: $exe  (pass -GamePath)" }
$log = Join-Path $root 'BepInEx\LogOutput.log'
if (Test-Path $log) { Remove-Item $log -Force }
Get-Process Pigface | Stop-Process -Force
Start-Sleep -Milliseconds 500
$args = @('-screen-width','1280','-screen-height','720','-screen-fullscreen','0')
if ($Extra) { $args += $Extra.Split(' ') }
$p = Start-Process -FilePath $exe -ArgumentList $args -WorkingDirectory $root -PassThru
Start-Sleep -Seconds $Sec
Get-Process Pigface | Stop-Process -Force
Start-Sleep -Milliseconds 800
"=== EXIT waited $Sec s ==="
