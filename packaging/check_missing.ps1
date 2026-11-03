param([string]$GamePath)
$ErrorActionPreference = 'Stop'
$out = @()
if (-not $GamePath) {
    $gp = Join-Path $PSScriptRoot 'game_path.txt'
    if (Test-Path $gp) { $GamePath = (Get-Content -LiteralPath $gp -Encoding UTF8 | Select-Object -First 1).Trim() }
}
if (-not $GamePath) {
    foreach ($c in @('E:\SteamLibrary\steamapps\common\PIGFACE','D:\SteamLibrary\steamapps\common\PIGFACE','C:\SteamLibrary\steamapps\common\PIGFACE','C:\Program Files (x86)\Steam\steamapps\common\PIGFACE')) {
        if (Test-Path (Join-Path $c 'Pigface.exe')) { $GamePath = $c; break }
    }
}
if (-not $GamePath) {
    Write-Host "  No game folder found. Paste the PIGFACE install path:" -ForegroundColor Yellow
    $GamePath = (Read-Host "  path").Trim().Trim('"')
}
$seen = Join-Path $GamePath 'BepInEx\PigfaceCN\seen.txt'
$dict = Join-Path $GamePath 'BepInEx\plugins\PigfaceCN\zh.tsv'
if (-not (Test-Path $seen)) { Write-Host "没找到 seen.txt，请先玩一会儿游戏再来检查。" -ForegroundColor Yellow; Read-Host "按回车关闭"; exit }
if (-not (Test-Path $dict)) { Write-Host "没找到 zh.tsv，安装可能不完整。" -ForegroundColor Red; Read-Host "按回车关闭"; exit }

$keys = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($ln in [System.IO.File]::ReadAllLines($dict, [System.Text.Encoding]::UTF8)) {
    if (-not $ln) { continue }
    $k = ($ln -split "`t")[0]
    if (-not $k) { continue }
    $k = ($k -replace '\s+', ' ').Trim().ToLower()
    [void]$keys.Add($k)
}

$missing = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($ln in [System.IO.File]::ReadAllLines($seen, [System.Text.Encoding]::UTF8)) {
    if (-not $ln) { continue }
    $s = $ln.Trim()
    if ($s -notmatch '[A-Za-z]{3,}') { continue }
    $core = $s -replace '^[»>]+\s*', ''
    $core = $core -replace '^\(optional\)\s*', ''
    $core = $core -replace '^（可选）\s*', ''
    $core = $core -replace '\s*\(\d+\s*/\s*\d+\)\s*$', ''
    $k = ($core -replace '\s+', ' ').Trim().ToLower()
    if ($keys.Contains($k)) { continue }
    if ($core -match '^(FPS|SSAO)$') { continue }
    [void]$missing.Add($core)
}

Write-Host ""
Write-Host ("  发现 " + $missing.Count + " 条可能没翻译的句子") -ForegroundColor Cyan
Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
$i = 0
foreach ($m in $missing) {
    $i++
    if ($i -le 60) { Write-Host ("  " + $i + ". " + $m) }
}
if ($missing.Count -gt 60) { Write-Host ("  ... 还有 " + ($missing.Count - 60) + " 条") }

$save = Join-Path $GamePath 'BepInEx\PigfaceCN\missing_report.txt'
[System.IO.File]::WriteAllLines($save, $missing, (New-Object System.Text.UTF8Encoding($true)))
Write-Host ""
Write-Host ("  完整清单已保存到: " + $save) -ForegroundColor Green
Read-Host "  按回车关闭"