param([int]$Sec = 30, [string]$Extra = "")
$ErrorActionPreference = 'SilentlyContinue'
$root = 'D:\AI-Workspace\PIGFACE-zh'
$exe = Join-Path $root 'Pigface.exe'
$log = Join-Path $root 'BepInEx\LogOutput.log'
if (Test-Path $log) { Remove-Item $log -Force }
Get-Process Pigface | Stop-Process -Force
Start-Sleep -Milliseconds 500
$args = @('-screen-width','1280','-screen-height','720','-screen-fullscreen','0')
$p = Start-Process -FilePath $exe -ArgumentList $args -WorkingDirectory $root -PassThru
Start-Sleep -Seconds $Sec
Get-Process Pigface | Stop-Process -Force
Start-Sleep -Milliseconds 800
"=== EXIT waited $Sec s ==="
