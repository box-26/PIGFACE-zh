param([string]$TargetPath)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
Write-Host ""
Write-Host "  PIGFACE 中文汉化 - 卸载程序" -ForegroundColor Cyan
Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
Write-Host ""

function Test-SteamGame([string]$dir) {
    # A copy counts as "Steam" when an appmanifest for appid 3341650 sits in one
    # of its parent folders (i.e. inside steamapps), or next to the exe itself.
    $p = $dir
    for ($i = 0; $i -lt 4 -and $p; $i++) {
        if (Test-Path (Join-Path $p 'appmanifest_3341650.acf')) { return $true }
        $parent = Split-Path $p -Parent
        if (-not $parent -or $parent -eq $p) { break }
        $p = $parent
    }
    return $false
}

function Find-Pigface {
    # 1) explicit argument
    if ($TargetPath) {
        $t = $TargetPath.Trim().Trim('"')
        if (Test-Path (Join-Path $t 'Pigface.exe')) { return $t }
    }

    # 2) the path the user picked last time
    $memo = Join-Path $PSScriptRoot 'game_path.txt'
    if (Test-Path $memo) {
        $p = (Get-Content -LiteralPath $memo -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($p) { $p = $p.Trim() }
        if ($p -and (Test-Path (Join-Path $p 'Pigface.exe'))) { return $p }
    }

    $found = New-Object System.Collections.Generic.List[object]
    $add = {
        param([string]$dir)
        if (-not $dir) { return }
        if (-not (Test-Path (Join-Path $dir 'Pigface.exe'))) { return }
        try { $full = [System.IO.Path]::GetFullPath($dir).TrimEnd('\') } catch { return }
        foreach ($c in $found) { if ($c.Path -ieq $full) { return } }
        $found.Add([pscustomobject]@{ Path = $full; Steam = (Test-SteamGame $full) })
    }

    # 3) Steam libraries listed in the registry
    $steams = New-Object System.Collections.Generic.List[string]
    foreach ($k in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam')) {
        try {
            $v = Get-ItemProperty $k -ErrorAction Stop
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

    # 4) walk every fixed/removable drive, at most three levels down
    $skip = @('Windows', 'Program Files', 'Program Files (x86)', 'ProgramData',
              '$Recycle.Bin', 'System Volume Information', 'Recovery', 'PerfLogs',
              'Users', 'Windows.old', 'Config.Msi')
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

    if ($found.Count -eq 0) { return $null }

    # Steam-registered copies win outright. Only ask when there is a real tie.
    $steamOnes = @($found | Where-Object { $_.Steam })
    $pool = @(if ($steamOnes.Count -gt 0) { $steamOnes } else { $found })
    if ($pool.Count -eq 1) {
        if ($found.Count -gt 1) {
            Write-Host ("  已自动选中 Steam 库中的这份：{0}" -f $pool[0].Path) -ForegroundColor DarkGray
        }
        return $pool[0].Path
    }

    Write-Host ""
    Write-Host ("  找到 {0} 个 PIGFACE：" -f $pool.Count) -ForegroundColor Yellow
    for ($i = 0; $i -lt $pool.Count; $i++) {
        $tag = if ($pool[$i].Steam) { '  (Steam 库)' } else { '' }
        Write-Host ("    [{0}] {1}{2}" -f ($i + 1), $pool[$i].Path, $tag)
    }
    $ans = Read-Host "  输入编号，直接回车 = 1"
    $idx = 0
    if ($ans) { [void][int]::TryParse($ans.Trim(), [ref]$idx); $idx = $idx - 1 }
    if ($idx -lt 0 -or $idx -ge $pool.Count) { $idx = 0 }
    return $pool[$idx].Path
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
