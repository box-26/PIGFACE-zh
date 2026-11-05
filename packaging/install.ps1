param([string]$TargetPath, [switch]$All)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
. (Join-Path $here 'Pigface.Common.ps1')

Write-Host ""
Write-Host "  PIGFACE 中文汉化 - 安装程序" -ForegroundColor Cyan
Write-Host "  ----------------------------------------" -ForegroundColor DarkGray
Write-Host ""

# ---- 找游戏 ----
$targets = @(Resolve-PigfaceTargets -Hint $TargetPath -MemoFile (Join-Path $here 'game_path.txt') -All:$All)
if ($targets.Count -eq 0) {
    Write-Host "  没自动找到游戏。" -ForegroundColor Yellow
    Write-Host "  请在 Steam 库里右键 PIGFACE -> 管理 -> 浏览本地文件，把地址栏的路径复制下来。"
    Write-Host ""
    $p = Read-Host "  把路径粘贴到这里，然后回车"
    if ($p) { $targets = @($p.Trim().Trim('"')) }
}

$games = New-Object System.Collections.Generic.List[string]
foreach ($t in $targets) {
    if (Test-GameDir $t) { $games.Add($t) }
    else {
        Write-Host ""
        Write-Host ("  {0} 里没有 Pigface.exe，跳过。" -f $t) -ForegroundColor Red
    }
}
if ($games.Count -eq 0) {
    Write-Host ""
    Write-Host "  没有可安装的游戏目录，安装已取消。" -ForegroundColor Red
    Write-Host ""
    Read-Host "  按回车关闭"
    exit 1
}

Write-Host ""
foreach ($g in $games) { Write-Host ("  目标：{0}" -f $g) -ForegroundColor Green }
Write-Host ""

# ---- 环境自检（只提示，不阻断）----
$warn = New-Object System.Collections.Generic.List[string]
try {
    $os = [System.Environment]::OSVersion.Version
    if ($os.Major -lt 10) { $warn.Add("系统不是 Windows 10/11（检测到 $($os.Major).$($os.Minor)），本补丁未在该系统验证过。") }
} catch { }
$fontsDir = Join-Path $env:WINDIR 'Fonts'
$cjk = @('simhei.ttf', 'msyh.ttc', 'msyh.ttf', 'simsun.ttc', 'Deng.ttf') | Where-Object { Test-Path (Join-Path $fontsDir $_) }
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

# ---- 逐个安装 ----
$ok = New-Object System.Collections.Generic.List[string]
$bad = New-Object System.Collections.Generic.List[string]

foreach ($game in $games) {
    Write-Host ("  [{0}] 正在处理…" -f $game) -ForegroundColor DarkGray

    $existing = Join-Path $game 'BepInEx'
    if (Test-Path $existing) {
        $ours = Test-Path (Join-Path $existing 'plugins\PigfaceCN\PigfaceCN.dll')
        if (-not $ours) {
            Write-Host "    这个目录里已有一个别的 BepInEx（可能是别的 mod），为了不弄坏它，跳过。" -ForegroundColor Yellow
            $bad.Add($game + "（已有其它 mod）")
            continue
        }
        Write-Host "    检测到旧版汉化，会就地更新。" -ForegroundColor DarkGray
    }

    $probe = Join-Path $game ('.cn_write_test_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $canWrite = $true
    try {
        Set-Content -LiteralPath $probe -Value 'x' -ErrorAction Stop
        Remove-Item -LiteralPath $probe -Force
    } catch { $canWrite = $false }
    if (-not $canWrite) {
        Write-Host "    没有写入权限（可能在 Program Files），跳过。" -ForegroundColor Red
        Write-Host "    需要的话：关掉本窗口，右键 安装汉化.bat -> 以管理员身份运行。" -ForegroundColor Yellow
        $bad.Add($game + "（没有写入权限）")
        continue
    }

    Write-Host "    正在复制文件…" -NoNewline
    try {
        Copy-Item (Join-Path $here 'winhttp.dll') $game -Force -ErrorAction Stop
        Copy-Item (Join-Path $here 'doorstop_config.ini') $game -Force -ErrorAction Stop
        Copy-Item (Join-Path $here '.doorstop_version') $game -Force -ErrorAction Stop
        Copy-Item (Join-Path $here 'BepInEx') $game -Recurse -Force -ErrorAction Stop
    } catch {
        Write-Host " 失败" -ForegroundColor Red
        Write-Host ("    原因: {0}" -f $_.Exception.Message)
        Write-Host "    常见原因: 杀毒软件拦截 / 游戏正在运行 / 磁盘空间不足。"
        $bad.Add($game + "（复制失败）")
        continue
    }

    $dll = Join-Path $game 'BepInEx\plugins\PigfaceCN\PigfaceCN.dll'
    $dict = Join-Path $game 'BepInEx\plugins\PigfaceCN\zh.tsv'
    if ((Test-Path $dll) -and (Test-Path $dict)) {
        Write-Host " 完成" -ForegroundColor Green
        $ok.Add($game)
    } else {
        Write-Host " 校验失败" -ForegroundColor Red
        $bad.Add($game + "（复制后校验失败）")
    }
}

# 记住最后一个安装成功的目录，供 检查缺词 / 卸载 参考
if ($ok.Count -gt 0) {
    Set-Content -LiteralPath (Join-Path $here 'game_path.txt') -Value $ok[$ok.Count - 1] -Encoding UTF8
}

Write-Host ""
if ($ok.Count -gt 0) {
    Write-Host ("  安装成功 {0} 份：" -f $ok.Count) -ForegroundColor Green
    foreach ($g in $ok) { Write-Host ("   - {0}" -f $g) -ForegroundColor Green }
    Write-Host ""
    Write-Host "  以后从 Steam 正常启动游戏就是中文了。"
    Write-Host ""
    Write-Host "  项目主页：https://github.com/box-26/PIGFACE-zh" -ForegroundColor Cyan
    Write-Host '  漏翻/错译请到上面的 Issues 反馈：双击 检查缺词.bat 生成 缺词报告.txt 附上即可。' -ForegroundColor DarkGray
}
if ($bad.Count -gt 0) {
    Write-Host ""
    Write-Host ("  没有装成 {0} 份：" -f $bad.Count) -ForegroundColor Yellow
    foreach ($b in $bad) { Write-Host ("   - {0}" -f $b) -ForegroundColor Yellow }
}

if ($ok.Count -eq 1) {
    Write-Host ""
    $ans = Read-Host "  现在启动游戏看看？(Y/N)"
    if ($ans -match '^(y|Y)') { Start-Process (Join-Path $ok[0] 'Pigface.exe') }
}

Write-Host ""
Read-Host "  按回车关闭"
