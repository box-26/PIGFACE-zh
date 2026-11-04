param([string]$TargetPath)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
Write-Host ""
Write-Host "  PIGFACE 中文汉化 - 安装程序" -ForegroundColor Cyan
Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
Write-Host ""

function Find-Pigface {
    if ($TargetPath) {
        $t = $TargetPath.Trim().Trim('"')
        if (Test-Path (Join-Path $t 'Pigface.exe')) { return $t }
    }

    # 上次运行时记下的路径
    $memo = Join-Path $PSScriptRoot 'game_path.txt'
    if (Test-Path $memo) {
        $p = (Get-Content -LiteralPath $memo -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($p) { $p = $p.Trim() }
        if ($p -and (Test-Path (Join-Path $p 'Pigface.exe'))) { return $p }
    }

    $cands = New-Object System.Collections.Generic.List[string]

    # Steam 自己登记过的库目录
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
        $cands.Add((Join-Path $steam 'steamapps\common\PIGFACE'))
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            foreach ($line in Get-Content -LiteralPath $vdf -ErrorAction SilentlyContinue) {
                $m = [regex]::Match($line, '"path"\s+"([^"]+)"')
                if ($m.Success) {
                    $lib = $m.Groups[1].Value.Replace('\\', '\')
                    $cands.Add((Join-Path $lib 'steamapps\common\PIGFACE'))
                }
            }
        }
    }

    # 所有盘：任何层级不超过 3 的目录，只要它下面有 steamapps\common\PIGFACE
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
            $cands.Add((Join-Path $root ($g + '\steamapps\common\PIGFACE')))
        }
        $lvl1 = @()
        try { $lvl1 = Get-ChildItem -LiteralPath $root -Directory -Force -ErrorAction SilentlyContinue } catch { }
        foreach ($a in $lvl1) {
            if ($skip -contains $a.Name) { continue }
            $visited++
            if ($visited -gt $limit -or (Get-Date) -gt $deadline) { break }
            if ($a.Name -ieq 'PIGFACE' -and (Test-Path (Join-Path $a.FullName 'Pigface.exe'))) { return $a.FullName }
            $cands.Add((Join-Path $a.FullName 'steamapps\common\PIGFACE'))
            $lvl2 = @()
            try { $lvl2 = Get-ChildItem -LiteralPath $a.FullName -Directory -Force -ErrorAction SilentlyContinue } catch { }
            foreach ($b in $lvl2) {
                $visited++
                if ($visited -gt $limit -or (Get-Date) -gt $deadline) { break }
                if ($b.Name -ieq 'PIGFACE' -and (Test-Path (Join-Path $b.FullName 'Pigface.exe'))) { return $b.FullName }
                $cands.Add((Join-Path $b.FullName 'steamapps\common\PIGFACE'))
                $lvl3 = @()
                try { $lvl3 = Get-ChildItem -LiteralPath $b.FullName -Directory -Force -ErrorAction SilentlyContinue } catch { }
                foreach ($c in $lvl3) {
                    $visited++
                    if ($visited -gt $limit -or (Get-Date) -gt $deadline) { break }
                    if ($c.Name -ieq 'PIGFACE' -and (Test-Path (Join-Path $c.FullName 'Pigface.exe'))) { return $c.FullName }
                    $cands.Add((Join-Path $c.FullName 'steamapps\common\PIGFACE'))
                }
            }
        }
    }

    foreach ($c in $cands) {
        if ($c -and (Test-Path (Join-Path $c 'Pigface.exe'))) { return $c }
    }
    return $null
}

$game = Find-Pigface
if (-not $game) {
    Write-Host "  没自动找到游戏。" -ForegroundColor Yellow
    Write-Host "  请在 Steam 库里右键 PIGFACE -> 管理 -> 浏览本地文件，把地址栏的路径复制下来。"
    Write-Host ""
    $game = Read-Host "  把路径粘贴到这里，然后回车"
    if ($game) { $game = $game.Trim().Trim('"') }
}

if (-not $game -or -not (Test-Path (Join-Path $game 'Pigface.exe'))) {
    Write-Host ""
    Write-Host "  这个路径里没有 Pigface.exe，安装已取消。" -ForegroundColor Red
    Write-Host ""
    Read-Host "  按回车关闭"
    exit 1
}

Set-Content -LiteralPath (Join-Path $here 'game_path.txt') -Value $game -Encoding UTF8
Write-Host "  游戏目录: $game" -ForegroundColor Green
Write-Host ""

# ---- environment self-check (warnings only, never blocks) ----
$warn = New-Object System.Collections.Generic.List[string]
try {
    $os = [System.Environment]::OSVersion.Version
    if ($os.Major -lt 10) { $warn.Add("系统不是 Windows 10/11（检测到 $($os.Major).$($os.Minor)），本补丁未在该系统验证过。") }
} catch { }
$fontsDir = Join-Path $env:WINDIR 'Fonts'
$cjk = @('simhei.ttf','msyh.ttc','msyh.ttf','simsun.ttc','Deng.ttf') | Where-Object { Test-Path (Join-Path $fontsDir $_) }
if ($cjk.Count -eq 0 -and -not (Test-Path (Join-Path $here 'BepInEx\plugins\PigfaceCN\font.ttf'))) {
    $warn.Add("系统里没找到中文字体，界面会保持英文原样（不会出现方块）。")
}
if (-not (Test-Path (Join-Path $here 'BepInEx\plugins\PigfaceCN\font.ttf'))) {
    $warn.Add("压缩包里缺少内置字体，英文版 Windows 上可能无法显示中文。")
}
if ($warn.Count -gt 0) {
    Write-Host "  环境提示：" -ForegroundColor Yellow
    foreach ($w in $warn) { Write-Host "   - $w" -ForegroundColor Yellow }
    Write-Host ""
}

$existing = Join-Path $game 'BepInEx'
if (Test-Path $existing) {
    $ours = Test-Path (Join-Path $existing 'plugins\PigfaceCN\PigfaceCN.dll')
    if (-not $ours) {
        Write-Host "  这个游戏目录里已经有一个别的 BepInEx（可能是别的 mod）。" -ForegroundColor Yellow
        Write-Host "  为了不弄坏你现有的东西，安装已停止。"
        Write-Host ""
        Read-Host "  按回车关闭"
        exit 1
    }
    Write-Host "  检测到旧版汉化，会就地更新。" -ForegroundColor DarkGray
}

# write test: the game may live under Program Files, where a normal double-click has no rights
$probe = Join-Path $game ('.cn_write_test_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
try {
    Set-Content -LiteralPath $probe -Value 'x' -ErrorAction Stop
    Remove-Item -LiteralPath $probe -Force
} catch {
    Write-Host ""
    Write-Host "  没有写入权限，安装已取消。" -ForegroundColor Red
    Write-Host "  这个游戏目录在受保护的位置（比如 C:\Program Files）。"
    Write-Host "  请关掉这个窗口，右键 安装汉化.bat -> 以管理员身份运行。"
    Write-Host ""
    Read-Host "  按回车关闭"
    exit 1
}

Write-Host "  正在复制文件..." -NoNewline
try {
    Copy-Item (Join-Path $here 'winhttp.dll') $game -Force -ErrorAction Stop
    Copy-Item (Join-Path $here 'doorstop_config.ini') $game -Force -ErrorAction Stop
    Copy-Item (Join-Path $here '.doorstop_version') $game -Force -ErrorAction Stop
    Copy-Item (Join-Path $here 'BepInEx') $game -Recurse -Force -ErrorAction Stop
} catch {
    Write-Host ""
    Write-Host "  复制失败，安装没有完成。" -ForegroundColor Red
    Write-Host "  原因: $($_.Exception.Message)"
    Write-Host "  常见原因: 杀毒软件拦截 / 游戏正在运行 / 磁盘空间不足。"
    Write-Host "  处理: 关掉游戏、把杀软弹窗点允许，再重试一次。"
    Write-Host ""
    Read-Host "  按回车关闭"
    exit 1
}
Write-Host " 完成" -ForegroundColor Green

$dll = Join-Path $game 'BepInEx\plugins\PigfaceCN\PigfaceCN.dll'
$dict = Join-Path $game 'BepInEx\plugins\PigfaceCN\zh.tsv'
if ((Test-Path $dll) -and (Test-Path $dict)) {
    Write-Host ""
    Write-Host "  安装成功！" -ForegroundColor Green
    Write-Host "  以后从 Steam 正常启动游戏就是中文了。" -ForegroundColor Green
    Write-Host ""
    Write-Host "  项目主页：https://github.com/box-26/PIGFACE-zh" -ForegroundColor Cyan
    Write-Host "  漏翻/错译请到上面的 Issues 反馈：双击「检查缺词.bat」生成 缺词报告.txt，附上即可。" -ForegroundColor DarkGray
    Write-Host ""
    $ans = Read-Host "  现在启动游戏看看？(Y/N)"
    if ($ans -match '^(y|Y)') { Start-Process (Join-Path $game 'Pigface.exe') }
} else {
    Write-Host ""
    Write-Host "  复制似乎没成功，请把上面的内容截图发给对方。" -ForegroundColor Red
}

Write-Host ""
Read-Host "  按回车关闭"
