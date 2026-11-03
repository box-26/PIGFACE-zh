param([string]$GamePath)
$ErrorActionPreference = 'Stop'
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
    Write-Host "  没找到游戏目录，请粘贴 PIGFACE 的安装路径：" -ForegroundColor Yellow
    $GamePath = (Read-Host "  路径").Trim().Trim('"')
}
$seen  = Join-Path $GamePath 'BepInEx\PigfaceCN\seen.txt'
$dict  = Join-Path $GamePath 'BepInEx\plugins\PigfaceCN\zh.tsv'
$allow = Join-Path $GamePath 'BepInEx\plugins\PigfaceCN\allow.txt'
if (-not (Test-Path $allow)) { $allow = Join-Path $GamePath 'BepInEx\PigfaceCN\allow.txt' }
if (-not (Test-Path $seen)) { Write-Host "  没找到 seen.txt，请先玩一会儿游戏再来检查。" -ForegroundColor Yellow; Read-Host "  按回车关闭"; exit }
if (-not (Test-Path $dict)) { Write-Host "  没找到 zh.tsv，安装可能不完整。" -ForegroundColor Red; Read-Host "  按回车关闭"; exit }

function Normalize([string]$s) {
    $s = $s -replace '\\n', ' ' -replace '\\r', ' '
    return (($s -replace '\s+', ' ').Trim().ToLower())
}

function Test-Technical([string]$t) {
    if ($t -match '^\d+(\.\d+)?\s+\d+\s*bit$') { return $true }
    if ($t -match '^\d+\s*[x\u00d7]\s*\d+\s*\d+\s*Hz$') { return $true }
    $letters = @($t.ToCharArray() | Where-Object { [char]::IsLetter($_) })
    if ($letters.Count -ge 2) {
        $lower = @($letters | Where-Object { [char]::IsLower($_) })
        if ($lower.Count -eq 0 -and $t.Length -le 12) { return $true }
    }
    return $false
}

$keys = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($ln in [System.IO.File]::ReadAllLines($dict, [System.Text.Encoding]::UTF8)) {
    if (-not $ln) { continue }
    $k = ($ln -split "`t")[0]
    if (-not $k) { continue }
    [void]$keys.Add((Normalize $k))
}

$allowSet = New-Object 'System.Collections.Generic.HashSet[string]'
if (Test-Path $allow) {
    foreach ($ln in [System.IO.File]::ReadAllLines($allow, [System.Text.Encoding]::UTF8)) {
        $t = $ln.Trim()
        if (-not $t -or $t.StartsWith('#')) { continue }
        [void]$allowSet.Add((Normalize $t))
    }
}

$missing = New-Object 'System.Collections.Generic.HashSet[string]'
$skipped = 0
foreach ($ln in [System.IO.File]::ReadAllLines($seen, [System.Text.Encoding]::UTF8)) {
    if (-not $ln) { continue }
    $s = $ln.Trim()
    if ($s -notmatch '[A-Za-z]{3,}') { continue }
    $core = $s -replace '^[»>]+\s*', ''
    $core = $core -replace '^\(optional\)\s*', ''
    $core = $core -replace '^（可选）\s*', ''
    $core = $core -replace '\s*\(\d+\s*/\s*\d+\)\s*$', ''
    $k = Normalize $core
    if ($keys.Contains($k)) { continue }
    if ($allowSet.Contains($k)) { $skipped++; continue }
    if (Test-Technical $core) { $skipped++; continue }
    [void]$missing.Add($core)
}

Write-Host ""
Write-Host ("  发现 " + $missing.Count + " 条可能没翻译的句子") -ForegroundColor Cyan
if ($skipped -gt 0) { Write-Host ("  （已跳过 " + $skipped + " 条人名/技术串）") -ForegroundColor DarkGray }
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
Write-Host ("  完整清单已保存到：" + $save) -ForegroundColor Green
Write-Host "  把这份清单发到 GitHub Issue，或放进 待翻译.tsv 的第 4 列。" -ForegroundColor DarkGray
Read-Host "  按回车关闭"
