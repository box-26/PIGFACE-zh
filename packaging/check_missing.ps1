param([string]$GamePath)
$ErrorActionPreference = 'Stop'

function Find-Pigface {
    param([string]$Hint)
    if ($Hint -and (Test-Path (Join-Path $Hint 'Pigface.exe'))) { return $Hint }
    $gp = Join-Path $PSScriptRoot 'game_path.txt'
    if (Test-Path $gp) {
        $t = (Get-Content -LiteralPath $gp -Encoding UTF8 | Select-Object -First 1).Trim()
        if ($t -and (Test-Path (Join-Path $t 'Pigface.exe'))) { return $t }
    }
    foreach ($c in @('E:\SteamLibrary\steamapps\common\PIGFACE','D:\SteamLibrary\steamapps\common\PIGFACE','C:\SteamLibrary\steamapps\common\PIGFACE','C:\Program Files (x86)\Steam\steamapps\common\PIGFACE','C:\Program Files\Steam\steamapps\common\PIGFACE')) {
        if (Test-Path (Join-Path $c 'Pigface.exe')) { return $c }
    }
    foreach ($k in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
        try {
            $p = (Get-ItemProperty -Path $k -ErrorAction Stop).SteamPath
            if ($p) {
                $p = $p -replace '/','\'
                $cand = Join-Path $p 'steamapps\common\PIGFACE'
                if (Test-Path (Join-Path $cand 'Pigface.exe')) { return $cand }
                $vdf = Join-Path $p 'steamapps\libraryfolders.vdf'
                if (Test-Path $vdf) {
                    foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) {
                        $lib = $m.Groups[1].Value -replace '\\\\','\'
                        $cand = Join-Path $lib 'steamapps\common\PIGFACE'
                        if (Test-Path (Join-Path $cand 'Pigface.exe')) { return $cand }
                    }
                }
            }
        } catch { }
    }
    $seen = 0
    foreach ($d in [System.IO.DriveInfo]::GetDrives()) {
        if ($d.DriveType -ne 'Fixed' -and $d.DriveType -ne 'Removable') { continue }
        $root = $d.RootDirectory.FullName
        foreach ($sub in @('SteamLibrary\steamapps\common\PIGFACE','Steam\steamapps\common\PIGFACE','Program Files (x86)\Steam\steamapps\common\PIGFACE','Program Files\Steam\steamapps\common\PIGFACE','Games\PIGFACE','PIGFACE')) {
            $cand = Join-Path $root $sub
            if (Test-Path (Join-Path $cand 'Pigface.exe')) { return $cand }
        }
        foreach ($sub in @('SteamLibrary','Steam','Games')) {
            $base = Join-Path $root $sub
            if (-not (Test-Path $base)) { continue }
            $cand = Join-Path $base 'steamapps\common\PIGFACE'
            if (Test-Path (Join-Path $cand 'Pigface.exe')) { return $cand }
        }
        try {
            foreach ($hit in (Get-ChildItem -LiteralPath $root -Directory -Depth 2 -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'PIGFACE' })) {
                $seen++
                if ($seen -gt 4000) { break }
                if (Test-Path (Join-Path $hit.FullName 'Pigface.exe')) { return $hit.FullName }
            }
        } catch { }
    }
    return $null
}

$GamePath = Find-Pigface $GamePath
if (-not $GamePath) {
    Write-Host "  没找到游戏目录，请粘贴 PIGFACE 的安装路径：" -ForegroundColor Yellow
    $GamePath = (Read-Host "  路径").Trim().Trim('"')
}
$miss = Join-Path $GamePath 'BepInEx\PigfaceCN\miss.log'
$dict = Join-Path $GamePath 'BepInEx\plugins\PigfaceCN\zh.tsv'
if (-not (Test-Path $dict)) { $dict = Join-Path $GamePath 'BepInEx\PigfaceCN\zh.tsv' }
$exe  = Join-Path $GamePath 'Pigface.exe'

$ver = 'unknown'
$vf = Join-Path $PSScriptRoot 'VERSION.txt'
if (Test-Path $vf) { $ver = (Get-Content -LiteralPath $vf -Encoding UTF8 | Select-Object -First 1).Trim() }
$dictCount = 0
if (Test-Path $dict) { $dictCount = (Get-Content -LiteralPath $dict -Encoding UTF8 | Where-Object { $_.Trim() -ne '' }).Count }
$gameVer = 'unknown'
try {
    $acf = Join-Path (Split-Path (Split-Path $GamePath -Parent) -Parent) 'appmanifest_3341650.acf'
    if (Test-Path $acf) {
        $m = [regex]::Match((Get-Content $acf -Raw), '"buildid"\s+"(\d+)"')
        if ($m.Success) { $gameVer = 'Steam build ' + $m.Groups[1].Value }
    }
} catch { }

$entries = @()
if (Test-Path $miss) {
    foreach ($ln in [System.IO.File]::ReadAllLines($miss, [System.Text.Encoding]::UTF8)) {
        if (-not $ln) { continue }
        $i = $ln.IndexOf("`t")
        if ($i -lt 0) { $entries += ,@('(unknown)', $ln.Trim()); continue }
        $entries += ,@($ln.Substring(0, $i).Trim(), $ln.Substring($i + 1).Trim())
    }
}

$byText = @{}
foreach ($e in $entries) {
    $t = $e[1]
    if (-not $byText.ContainsKey($t)) { $byText[$t] = @{ n = 0; path = $e[0] } }
    $byText[$t].n = $byText[$t].n + 1
}

$out = New-Object System.Collections.Generic.List[string]
$out.Add('PIGFACE 简体中文汉化 - 缺词报告')
$out.Add('====================================================')
$out.Add("补丁版本：v$ver（词库 $dictCount 条）")
$out.Add("游戏版本：$gameVer")
$out.Add("生成时间：" + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
$out.Add("游戏路径：$GamePath")
$out.Add("记录条数：$($entries.Count) 条（去重后 $($byText.Count) 条）")
$out.Add('')
$out.Add('说明：这里只记录"插件真的没翻出来"的句子，已排除人名（allow.txt）')
$out.Add('      与版本号/分辨率等技术串，所以不会有误报。')
$out.Add('')
if ($byText.Count -eq 0) {
    $out.Add('恭喜：这次没有发现漏翻的句子。')
} else {
    $out.Add('---- 漏翻清单（按出现次数排序）----')
    $n = 0
    foreach ($k in ($byText.Keys | Sort-Object { -$byText[$_].n })) {
        $n++
        $out.Add("$n. [$($byText[$k].n) 次] $k")
        $out.Add("   位置：$($byText[$k].path)")
    }
}
$out.Add('')
$out.Add('---- 原始 miss.log ----')
foreach ($e in $entries) { $out.Add("$($e[0])`t$($e[1])") }

$save = Join-Path $PSScriptRoot 'missing_report.txt'
try {
    [System.IO.File]::WriteAllLines($save, $out, (New-Object System.Text.UTF8Encoding($true)))
} catch {
    $save = Join-Path $GamePath 'BepInEx\PigfaceCN\missing_report.txt'
    [System.IO.File]::WriteAllLines($save, $out, (New-Object System.Text.UTF8Encoding($true)))
}

Write-Host ''
Write-Host ("  补丁 v" + $ver + "，词库 " + $dictCount + " 条") -ForegroundColor DarkGray
Write-Host ("  发现 " + $byText.Count + " 条没翻译的句子") -ForegroundColor Cyan
Write-Host ("  报告已保存：" + $save) -ForegroundColor Green
Write-Host '  把这个文件发到 GitHub Issues 即可。' -ForegroundColor DarkGray
try { Start-Process explorer.exe -ArgumentList ('/select,"' + $save + '"') } catch { }
Read-Host '  按回车关闭'