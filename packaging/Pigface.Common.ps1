# Pigface.Common.ps1
# 安装 / 卸载 / 检查缺词 共用："找到游戏目录" + "多份时让用户选（可多选）"。
# 由三个脚本 dot-source 加载，不要单独运行。

function Test-SteamGame([string]$dir) {
    # 上层目录里有 appid 清单 = 这份是 Steam 装的
    $p = $dir
    for ($i = 0; $i -lt 4 -and $p; $i++) {
        if (Test-Path (Join-Path $p 'appmanifest_3341650.acf')) { return $true }
        $parent = Split-Path $p -Parent
        if (-not $parent -or $parent -eq $p) { break }
        $p = $parent
    }
    return $false
}

function Test-GameDir([string]$dir) {
    if (-not $dir) { return $false }
    if (-not (Test-Path (Join-Path $dir 'Pigface.exe'))) { return $false }
    if (-not (Test-Path (Join-Path $dir 'Pigface_Data\Managed'))) { return $false }
    return $true
}

function Get-LastPlayed([string]$dir) {
    $best = [datetime]::MinValue
    foreach ($f in @('BepInEx\LogOutput.log', 'BepInEx\PigfaceCN\miss.log', 'Pigface_Data\output_log.txt')) {
        $p = Join-Path $dir $f
        if (Test-Path $p) {
            $t = (Get-Item -LiteralPath $p).LastWriteTime
            if ($t -gt $best) { $best = $t }
        }
    }
    return $best
}

function Get-PigfaceCandidates([string]$Hint, [string]$MemoFile) {
    $found = New-Object System.Collections.Generic.List[object]
    $seen = @{}

    $add = {
        param([string]$dir)
        if (-not $dir) { return }
        $dir = $dir.Trim().Trim('"')
        if (-not $dir) { return }
        try { $full = [System.IO.Path]::GetFullPath($dir).TrimEnd('\') } catch { return }
        if (-not (Test-GameDir $full)) { return }
        $key = $full.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { return }
        $seen[$key] = 1
        $found.Add([pscustomobject]@{
            Path = $full
            Steam = (Test-SteamGame $full)
            Time = (Get-LastPlayed $full)
        })
    }

    if ($Hint) { & $add $Hint }
    if ($MemoFile -and (Test-Path $MemoFile)) {
        $memo = (Get-Content -LiteralPath $MemoFile -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($memo) { & $add $memo }
    }

    # Steam 注册表里登记的库
    $steams = New-Object System.Collections.Generic.List[string]
    foreach ($k in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam')) {
        try {
            $v = Get-ItemProperty -Path $k -ErrorAction Stop
            foreach ($name in @('SteamPath', 'InstallPath')) {
                $sp = $v.$name
                if ($sp) { $steams.Add(($sp -replace '/', '\')) }
            }
        } catch { }
    }
    foreach ($steam in $steams) {
        & $add (Join-Path $steam 'steamapps\common\PIGFACE')
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            foreach ($line in Get-Content -LiteralPath $vdf -ErrorAction SilentlyContinue) {
                $m = [regex]::Match($line, '"path"\s+"([^"]+)"')
                if ($m.Success) {
                    $lib = $m.Groups[1].Value.Replace('\\', '\')
                    & $add (Join-Path $lib 'steamapps\common\PIGFACE')
                }
            }
        }
    }

    # 全盘扫（最多三层），任何含 Pigface.exe 的目录都算
    $skip = @('Windows', 'Program Files', 'Program Files (x86)', 'ProgramData', '$Recycle.Bin',
              'System Volume Information', 'Recovery', 'PerfLogs', 'Users', 'Windows.old', 'Config.Msi')
    $visited = 0
    $limit = 4000
    $deadline = (Get-Date).AddSeconds(12)

    foreach ($d in [System.IO.DriveInfo]::GetDrives()) {
        if (-not $d.IsReady) { continue }
        if ($d.DriveType -ne [System.IO.DriveType]::Fixed -and $d.DriveType -ne [System.IO.DriveType]::Removable) { continue }
        $root = $d.Name
        foreach ($g in @('SteamLibrary', 'Steam', 'Games', 'games')) {
            & $add (Join-Path $root ($g + '\steamapps\common\PIGFACE'))
        }
        $lvl1 = @()
        try { $lvl1 = Get-ChildItem -LiteralPath $root -Directory -Force -ErrorAction SilentlyContinue } catch { }
        foreach ($a in $lvl1) {
            if ($skip -contains $a.Name) { continue }
            $visited++
            if ($visited -gt $limit -or (Get-Date) -gt $deadline) { break }
            & $add $a.FullName
            & $add (Join-Path $a.FullName 'steamapps\common\PIGFACE')
            $lvl2 = @()
            try { $lvl2 = Get-ChildItem -LiteralPath $a.FullName -Directory -Force -ErrorAction SilentlyContinue } catch { }
            foreach ($b in $lvl2) {
                $visited++
                if ($visited -gt $limit -or (Get-Date) -gt $deadline) { break }
                & $add $b.FullName
                & $add (Join-Path $b.FullName 'steamapps\common\PIGFACE')
                $lvl3 = @()
                try { $lvl3 = Get-ChildItem -LiteralPath $b.FullName -Directory -Force -ErrorAction SilentlyContinue } catch { }
                foreach ($c in $lvl3) {
                    $visited++
                    if ($visited -gt $limit -or (Get-Date) -gt $deadline) { break }
                    & $add $c.FullName
                    & $add (Join-Path $c.FullName 'steamapps\common\PIGFACE')
                }
            }
        }
    }

    return @($found | Sort-Object -Property @{ Expression = 'Steam'; Descending = $true }, @{ Expression = 'Time'; Descending = $true }, @{ Expression = 'Path'; Descending = $false })
}

function Read-PigfaceChoice([object[]]$list) {
    $newest = ($list | Where-Object { $_.Time -gt [datetime]::MinValue } | Sort-Object -Property Time -Descending | Select-Object -First 1)

    Write-Host ""
    Write-Host ("  找到 {0} 份 PIGFACE：" -f $list.Count) -ForegroundColor Yellow
    for ($i = 0; $i -lt $list.Count; $i++) {
        $tags = @()
        if ($list[$i].Steam) { $tags += 'Steam 库' }
        if ($newest -and $list[$i].Path -eq $newest.Path) { $tags += '最近玩过' }
        $tag = if ($tags.Count -gt 0) { '   （' + ($tags -join '，') + '）' } else { '' }
        Write-Host ("    [{0}] {1}{2}" -f ($i + 1), $list[$i].Path, $tag)
    }
    Write-Host ""
    Write-Host "  可以多选，例如 1,2 或 all；直接回车 = 1。" -ForegroundColor DarkGray

    for ($try = 0; $try -lt 2; $try++) {
        $ans = Read-Host "  输入编号"
        if (-not $ans) { return @($list[0]) }
        $ans = $ans.Trim()
        if ($ans -match '^(all|ALL|All|\*)$') { return @($list) }

        $idxList = @()
        $badInput = $false
        foreach ($token in ($ans -split '[,，、\s]+')) {
            if (-not $token) { continue }
            $n = 0
            if (-not [int]::TryParse($token, [ref]$n)) { $badInput = $true; break }
            if ($n -lt 1 -or $n -gt $list.Count) { $badInput = $true; break }
            if ($idxList -notcontains $n) { $idxList += $n }
        }
        if (-not $badInput -and $idxList.Count -gt 0) {
            $picked = @()
            foreach ($n in $idxList) { $picked += $list[$n - 1] }
            return @($picked)
        }
        Write-Host "  没看懂，请输入 1 到 $($list.Count) 之间的编号，或用逗号分隔多个。" -ForegroundColor Yellow
    }
    return @($list[0])
}

# 主入口：返回 Path 字符串数组（可能是 1 个，也可能是多个）
function Resolve-PigfaceTargets {
    param(
        [string]$Hint,
        [string]$MemoFile,
        [switch]$All
    )
    # 明确指定了目录就用它，不再扫描、不再询问（避免"指定了 A 却装到 B"）。
    if ($Hint) {
        $h = $Hint.Trim().Trim('"')
        if (Test-GameDir $h) {
            Write-Host ("  使用指定的目录：{0}" -f $h) -ForegroundColor DarkGray
            return @($h)
        }
    }
    $list = @(Get-PigfaceCandidates -Hint $null -MemoFile $MemoFile)
    if ($list.Count -eq 0) { return @() }
    if ($All -or $list.Count -eq 1) {
        if ($list.Count -eq 1) { Write-Host ("  使用：{0}" -f $list[0].Path) -ForegroundColor DarkGray }
        return @($list | ForEach-Object { $_.Path })
    }
    $chosen = Read-PigfaceChoice $list
    return @($chosen | ForEach-Object { $_.Path })
}
