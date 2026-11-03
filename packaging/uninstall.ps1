param([string]$TargetPath)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
Write-Host ""
Write-Host "  PIGFACE 中文汉化 - 卸载程序" -ForegroundColor Cyan
Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
Write-Host ""

function Find-Pigface {
    if ($TargetPath -and (Test-Path (Join-Path $TargetPath 'Pigface.exe'))) { return $TargetPath }
    if ($TargetPath -and (Test-Path (Join-Path $TargetPath 'Pigface.exe'))) { return $TargetPath }
    $cands = New-Object System.Collections.Generic.List[string]
    $cands.Add("E:\SteamLibrary\steamapps\common\PIGFACE")
    $cands.Add("D:\SteamLibrary\steamapps\common\PIGFACE")
    $cands.Add("C:\SteamLibrary\steamapps\common\PIGFACE")
    $cands.Add("C:\Program Files (x86)\Steam\steamapps\common\PIGFACE")
    $cands.Add("C:\Program Files\Steam\steamapps\common\PIGFACE")

    $steam = $null
    try { $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction Stop).SteamPath } catch { }
    if ($steam) {
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            foreach ($line in Get-Content $vdf) {
                $m = [regex]::Match($line, '"path"\s+"([^"]+)"')
                if ($m.Success) {
                    $p = $m.Groups[1].Value.Replace('\\', '\')
                    $cands.Add((Join-Path $p 'steamapps\common\PIGFACE'))
                }
            }
        }
        $cands.Add((Join-Path $steam 'steamapps\common\PIGFACE'))
    }

    foreach ($c in $cands) {
        if (Test-Path (Join-Path $c 'Pigface.exe')) { return $c }
    }
    return $null
}

$game = Find-Pigface
if (-not $game) {
    Write-Host "  没自动找到游戏，请把 PIGFACE 文件夹路径粘贴进来。"
    $game = Read-Host "  路径"
    if ($game) { $game = $game.Trim().Trim('"') }
}
if (-not $game -or -not (Test-Path (Join-Path $game 'Pigface.exe'))) {
    Write-Host "  路径里没有 Pigface.exe，已取消。" -ForegroundColor Red
    Read-Host "  按回车关闭"
    exit 1
}

Write-Host "  游戏目录: $game" -ForegroundColor Green

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $env:TEMP ("PIGFACE_CN_removed_" + $stamp)
$moved = $false

if (Test-Path (Join-Path $game 'BepInEx')) {
    New-Item -ItemType Directory -Force -Path $backup | Out-Null
    Move-Item (Join-Path $game 'BepInEx') $backup -Force
    $moved = $true
}
foreach ($f in @('winhttp.dll', 'doorstop_config.ini', '.doorstop_version')) {
    $p = Join-Path $game $f
    if (Test-Path $p) {
        if (-not (Test-Path $backup)) { New-Item -ItemType Directory -Force -Path $backup | Out-Null }
        Move-Item $p $backup -Force
        $moved = $true
    }
}

Write-Host ""
if ($moved) {
    Write-Host "  卸载完成，游戏已恢复原版（英文）。" -ForegroundColor Green
    Write-Host "  删掉的东西先放在这里，确认没问题后可以自己删：" -ForegroundColor DarkGray
    Write-Host "  $backup" -ForegroundColor DarkGray
} else {
    Write-Host "  这个目录里没有汉化文件，可能已经卸载过了。" -ForegroundColor Yellow
}
Write-Host ""
Read-Host "  按回车关闭"
