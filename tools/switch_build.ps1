param(
    [ValidateSet('dev', 'release')]
    [string]$Mode = 'dev',
    [string]$GamePath = 'D:\AI-Workspace\PIGFACE-zh'
)

$ErrorActionPreference = 'Stop'
$plug = Join-Path $GamePath 'BepInEx\plugins\PigfaceCN'
if (-not (Test-Path $plug)) { throw "PigfaceCN 插件目录不存在：$plug" }

$devDll = 'D:\AI-Workspace\work\plugin\out-debug\PigfaceCN.dll'
$relDll = 'D:\AI-Workspace\release\PIGFACE-汉化\BepInEx\plugins\PigfaceCN\PigfaceCN.dll'

$src = if ($Mode -eq 'dev') { $devDll } else { $relDll }
if (-not (Test-Path $src)) { throw "找不到 DLL：$src" }

Get-Process Pigface -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 800
Copy-Item $src (Join-Path $plug 'PigfaceCN.dll') -Force

$b = [System.IO.File]::ReadAllBytes((Join-Path $plug 'PigfaceCN.dll'))
$s = [System.Text.Encoding]::ASCII.GetString($b)
$hasDebug = $s.Contains('CompleteObjectives')

$size = $b.Length
$state = if ($hasDebug) { 'F7/F8 可用' } else { 'F7/F8 不存在（发布版）' }
Write-Host "已切换到 $Mode：$size 字节，$state"
