param(
    [ValidateSet('dev', 'release')]
    [string]$Mode = 'dev',
    [string]$GamePath = (Join-Path $PSScriptRoot '..\..\PIGFACE-zh'),
    # Both DLLs come from the build commands in docs/DEV.md (-o out-debug / -o out-release).
    [string]$DevDll = (Join-Path $PSScriptRoot '..\out-debug\PigfaceCN.dll'),
    [string]$RelDll = (Join-Path $PSScriptRoot '..\out-release\PigfaceCN.dll')
)

$ErrorActionPreference = 'Stop'
$plug = Join-Path $GamePath 'BepInEx\plugins\PigfaceCN'
if (-not (Test-Path $plug)) { throw "PigfaceCN 插件目录不存在：$plug" }

$src = if ($Mode -eq 'dev') { $DevDll } else { $RelDll }
if (-not (Test-Path $src)) { throw "找不到 DLL：$src（先按 docs/DEV.md 编译）" }

Get-Process Pigface -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 800
Copy-Item $src (Join-Path $plug 'PigfaceCN.dll') -Force

$b = [System.IO.File]::ReadAllBytes((Join-Path $plug 'PigfaceCN.dll'))
$s = [System.Text.Encoding]::ASCII.GetString($b)
$hasDebug = $s.Contains('CompleteObjectives')

$size = $b.Length
$state = if ($hasDebug) { 'F7/F8 可用' } else { 'F7/F8 不存在（发布版）' }
Write-Host "已切换到 $Mode：$size 字节，$state"
