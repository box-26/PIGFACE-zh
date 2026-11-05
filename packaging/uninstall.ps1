param([string]$TargetPath, [switch]$All)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
. (Join-Path $here 'Pigface.Common.ps1')

Write-Host ""
Write-Host "  PIGFACE 中文汉化 - 卸载程序" -ForegroundColor Cyan
Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
Write-Host ""

# ---- 找游戏 ----
$targets = @(Resolve-PigfaceTargets -Hint $TargetPath -MemoFile (Join-Path $here 'game_path.txt') -All:$All)
if ($targets.Count -eq 0) {
    Write-Host "  没自动找到游戏。" -ForegroundColor Yellow
    $p = Read-Host "  把 PIGFACE 文件夹路径粘贴进来"
    if ($p) { $targets = @($p.Trim().Trim('"')) }
}

$games = New-Object System.Collections.Generic.List[string]
foreach ($t in $targets) {
    if (Test-GameDir $t) { $games.Add($t) }
    else { Write-Host ("  {0} 里没有 Pigface.exe，跳过。" -f $t) -ForegroundColor Red }
}
if ($games.Count -eq 0) {
    Write-Host "  没有可卸载的游戏目录，已取消。" -ForegroundColor Red
    Write-Host ""
    Read-Host "  按回车关闭"
    exit 1
}

# 卸载是"移走文件"，多份时先确认一次
if ($games.Count -gt 1) {
    Write-Host ""
    Write-Host ("  即将从这 {0} 份里移除汉化：" -f $games.Count) -ForegroundColor Yellow
    foreach ($g in $games) { Write-Host ("   - {0}" -f $g) -ForegroundColor Yellow }
    Write-Host "  文件不会被删除，会移到 %TEMP% 下，随时可以拿回来。" -ForegroundColor DarkGray
    $ans = Read-Host "  继续？(Y/N)"
    if ($ans -notmatch '^(y|Y)') {
        Write-Host "  已取消。"
        Read-Host "  按回车关闭"
        exit 0
    }
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$removed = New-Object System.Collections.Generic.List[string]
$untouched = New-Object System.Collections.Generic.List[string]

foreach ($game in $games) {
    Write-Host ""
    Write-Host ("  [{0}]" -f $game) -ForegroundColor DarkGray
    $backup = Join-Path $env:TEMP ("PIGFACE_CN_removed_" + $stamp + "_" + [guid]::NewGuid().ToString('N').Substring(0, 6))
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

    if ($moved) {
        Write-Host "    已移除，原文件在：" -ForegroundColor Green
        Write-Host ("    {0}" -f $backup) -ForegroundColor DarkGray
        $removed.Add($game)
    } else {
        Write-Host "    这里没有汉化文件（可能已经卸载过）。" -ForegroundColor Yellow
        $untouched.Add($game)
    }
}

Write-Host ""
if ($removed.Count -gt 0) {
    Write-Host ("  卸载完成 {0} 份，游戏已恢复原版（英文）。" -f $removed.Count) -ForegroundColor Green
    Write-Host "  移走的东西都在 %TEMP%\PIGFACE_CN_removed_* 里，确认没问题后可以自己删。" -ForegroundColor DarkGray
}
if ($untouched.Count -gt 0) {
    Write-Host ("  另有 {0} 份本来就没有汉化文件。" -f $untouched.Count) -ForegroundColor Yellow
}
Write-Host ""
Read-Host "  按回车关闭"
