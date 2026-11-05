param([string]$GamePath, [switch]$All)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
. (Join-Path $here 'Pigface.Common.ps1')

Write-Host ""
Write-Host "  PIGFACE 中文汉化 - 缺词检查" -ForegroundColor Cyan
Write-Host "  ----------------------------------------" -ForegroundColor DarkGray

$targets = @(Resolve-PigfaceTargets -Hint $GamePath -MemoFile (Join-Path $here 'game_path.txt') -All:$All)
if ($targets.Count -eq 0) {
    Write-Host "  没找到游戏目录，请粘贴 PIGFACE 的安装路径：" -ForegroundColor Yellow
    $p = (Read-Host "  路径").Trim().Trim('"')
    if ($p) { $targets = @($p) }
}
if ($targets.Count -eq 0) {
    Write-Host "  没有可检查的目录。" -ForegroundColor Red
    Read-Host "  按回车关闭"
    exit 1
}

function New-Report([string]$GamePath, [switch]$NoEnv) {
$miss = Join-Path $GamePath 'BepInEx\PigfaceCN\miss.log'
$dict = Join-Path $GamePath 'BepInEx\plugins\PigfaceCN\zh.tsv'
if (-not (Test-Path $dict)) { $dict = Join-Path $GamePath 'BepInEx\PigfaceCN\zh.tsv' }

$ver = 'unknown'
$vf = Join-Path $PSScriptRoot 'VERSION.txt'
if (Test-Path $vf) { $ver = (Get-Content -LiteralPath $vf -Encoding UTF8 | Select-Object -First 1).Trim() }
$dictCount = 0
if (Test-Path $dict) { $dictCount = (Get-Content -LiteralPath $dict -Encoding UTF8 | Where-Object { $_.Trim() -ne '' }).Count }
$gameVer = '无 Steam 记录（副本）'
try {
    $acf = Join-Path (Split-Path (Split-Path $GamePath -Parent) -Parent) 'appmanifest_3341650.acf'
    if (Test-Path $acf) {
        $m = [regex]::Match((Get-Content $acf -Raw), '"buildid"\s+"(\d+)"')
        if ($m.Success) { $gameVer = 'Steam build ' + $m.Groups[1].Value }
    }
} catch { }

# ---- 环境信息（只取不含隐私的项）----
$osLine = (($os.Caption -replace '^Microsoft\s+', '') + ' ' + $(if ($os.OSArchitecture -like '*64*') { '64 位' } else { '32 位' }))
try {
    $osv = [System.Environment]::OSVersion.Version
    $cap = ''
    try { $cap = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption } catch { $cap = 'Windows' }
    $arch = if ($env:PROCESSOR_ARCHITECTURE -like '*64*') { '64 位' } else { '32 位' }
    $osLine = (($cap -replace '^Microsoft\s+', '') + ' ' + $arch)
} catch { }

$resLine = 'unknown'
try {
    $modes = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | Where-Object { $_.CurrentHorizontalResolution -gt 0 })
    if ($modes.Count -gt 0) {
        $best = $modes | Sort-Object { $_.CurrentHorizontalResolution * $_.CurrentVerticalResolution } -Descending | Select-Object -First 1
        $resLine = "$($best.CurrentHorizontalResolution)x$($best.CurrentVerticalResolution)"
    } else {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        $vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $resLine = "$($vs.Width)x$($vs.Height)（DPI 缩放后的逻辑值）"
    }
} catch { }

$fontLine = 'unknown'
$log = Join-Path $GamePath 'BepInEx\LogOutput.log'
if (Test-Path $log) {
    $m = [regex]::Match((Get-Content -LiteralPath $log -Raw -Encoding UTF8), 'font:\s*([^\r\n]+)')
    if ($m.Success) { $fontLine = $m.Groups[1].Value.Trim() }
}

$others = @()
$pd = Join-Path $GamePath 'BepInEx\plugins'
if (Test-Path $pd) {
    $others = @(Get-ChildItem -LiteralPath $pd -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'PigfaceCN' } | ForEach-Object { $_.Name })
}
$otherLine = if ($others.Count -eq 0) { '无' } else { "$($others.Count) 个（$($others -join ', ')）" }

$avLine = 'unknown'
try {
    $avNames = @()
    foreach ($a in (Get-CimInstance -Namespace 'root\SecurityCenter2' -ClassName AntiVirusProduct -ErrorAction Stop)) {
        $exe = [string]$a.pathToSignedProductExe
        # 卸载后仍残留在“安全中心”登记里的杀软，用“程序文件还在不在”剔除
        if ($exe -like 'windowsdefender://*' -or (Test-Path -LiteralPath $exe)) { $avNames += $a.displayName }
    }
    if ($avNames.Count -eq 0) { $avLine = '未检测到' } else { $avLine = ($avNames -join ', ') }
} catch { $avLine = '无法读取' }

$flagCjk = if ($GamePath -match '[\u4e00-\u9fff]') { '是' } else { '否' }
$flagSpc = if ($GamePath.Contains(' ')) { '是' } else { '否' }
$flagPf  = if ($GamePath -like '*\Program Files*') { '是' } else { '否' }

# ---- 读 miss.log ----
$entries = @()
if (Test-Path $miss) {
    foreach ($ln in [System.IO.File]::ReadAllLines($miss, [System.Text.Encoding]::UTF8)) {
        if (-not $ln) { continue }
        $i = $ln.IndexOf("`t")
        if ($i -lt 0) { $entries += ,@('(unknown)', $ln.Trim()); continue }
        $entries += ,@($ln.Substring(0, $i).Trim(), $ln.Substring($i + 1).Trim())
    }
}

# 词库已经收录的句子不必再报：按键图标统一按 <sprite> 比较，换行统一。
function N([string]$s) {
    if (-not $s) { return '' }
    $x = $s -replace '<sprite[^>]*>', '<sprite>'
    $x = $x -replace '\\n', "`n" -replace '\\r', "`r"
    $x = ($x -replace '\s+', ' ').Trim().ToLowerInvariant()
    return $x
}
$dictSet = @{}
if (Test-Path $dict) {
    foreach ($ln in [System.IO.File]::ReadAllLines($dict, [System.Text.Encoding]::UTF8)) {
        if (-not $ln) { continue }
        $tab = $ln.IndexOf("`t")
        if ($tab -lt 1) { continue }
        $dictSet[(N $ln.Substring(0, $tab))] = 1
    }
}
# 这些是插件按模式翻译的（键位提示、拾取提示、任务提示……），词库里没有整句，跳过。
$patternSkip = @(
    '^press .*to assign it to',
    '^now press .*to assign it to',
    'is already in use\. do you want to replace it',
    '^\d[\d,]* .+ picked up$',
    '.+ job accepted$',
    '.+ mask found!$',
    '^.+ \(x\d+\)$',
    '^\+ .+ (blueprints?|schematics?) unlocked!$',
    '^[^<]+<br>\s*<br>'
)
$skipped = 0
$skippedPattern = 0
$byText = @{}
foreach ($e in $entries) {
    $t = $e[1]
    $tn = (N $t)
    if ($dictSet.Count -gt 0 -and $dictSet.ContainsKey($tn)) { $skipped++; continue }
    $hit = $false
    foreach ($ps in $patternSkip) { if ($tn -match $ps) { $hit = $true; break } }
    if ($hit) { $skippedPattern++; continue }
    if (-not $byText.ContainsKey($t)) { $byText[$t] = @{ n = 0; path = $e[0] } }
    $byText[$t].n = $byText[$t].n + 1
}

# ---- 生成报告 ----
$out = New-Object System.Collections.Generic.List[string]
$out.Add('PIGFACE 汉化 缺词报告')
$out.Add('')
if (-not $NoEnv) {
    $out.Add("系统     $osLine")
    $out.Add("屏幕     $resLine")
    $out.Add("字体     $fontLine")
    $out.Add("杀软     $avLine")
    $out.Add("其它插件 $otherLine")
    $out.Add("安装位置 含中文=$flagCjk 含空格=$flagSpc 在ProgramFiles=$flagPf")
    $out.Add('')
}
$out.Add("补丁     v$ver（词库 $dictCount 条）")
$out.Add("游戏     $gameVer")
$out.Add("记录     $($entries.Count) 条，去重后 $($byText.Count) 条")
$out.Add("         其中 $skipped 条词库已收录、$skippedPattern 条按规则处理")
$out.Add('')
if ($byText.Count -eq 0) {
    $out.Add('没有发现漏翻的句子。')
} else {
    $out.Add('漏翻清单（按出现次数排序）')
    $out.Add('')
    $n = 0
    foreach ($k in ($byText.Keys | Sort-Object { -$byText[$_].n })) {
        $n++
        $out.Add("$n. [$($byText[$k].n) 次] $k")
        $out.Add("   位置 $($byText[$k].path)")
    }
}
$out.Add('')
$out.Add('说明：只列插件没翻出来的句子。人名（allow.txt）、')
$out.Add('版本号、分辨率这类在写日志前就跳过了；个别界面')
$out.Add('元素仍可能被误判，看到忽略即可。')
$out.Add('')
$out.Add('发不发都行：发出来能帮作者补词，不发不影响使用。')
$out.Add('报告不含用户名、电脑名、完整路径和存档内容。')
$out.Add('')
$out.Add('—— 原始 miss.log ——')
foreach ($e in $entries) { $out.Add("$($e[0])`t$($e[1])") }
return [pscustomobject]@{ Lines = $out; Count = $byText.Count; Dict = $dictCount; Ver = $ver; Game = $GamePath }
}

$reports = New-Object System.Collections.Generic.List[object]
foreach ($g in $targets) { $reports.Add((New-Report -GamePath $g -NoEnv:($reports.Count -gt 0))) }

$merged = New-Object System.Collections.Generic.List[string]
$merged.Add('PIGFACE 汉化 缺词报告')
$merged.Add('')
foreach ($r in $reports) {
    if ($reports.Count -gt 1) {
        $merged.Add("【第 $($reports.IndexOf($r) + 1) 份】")
        $merged.Add("路径 $($r.Game)")
        $merged.Add('')
    }
    foreach ($line in ($r.Lines | Select-Object -Skip 2)) { $merged.Add($line) }
    $merged.Add('')
}

$save = Join-Path $PSScriptRoot '缺词报告.txt'
try {
    [System.IO.File]::WriteAllLines($save, $merged, (New-Object System.Text.UTF8Encoding($true)))
} catch {
    $save = Join-Path $PSScriptRoot ('缺词报告_' + [guid]::NewGuid().ToString('N').Substring(0, 6) + '.txt')
    [System.IO.File]::WriteAllLines($save, $merged, (New-Object System.Text.UTF8Encoding($true)))
}

Write-Host ''
foreach ($r in $reports) {
    Write-Host ("  补丁 v{0}，词库 {1} 条" -f $r.Ver, $r.Dict) -ForegroundColor DarkGray
    if ($reports.Count -gt 1) { Write-Host ("  {0}" -f $r.Game) -ForegroundColor DarkGray }
    Write-Host ("  发现 {0} 条没翻译的句子" -f $r.Count) -ForegroundColor Cyan
}
Write-Host ("  报告已保存到：{0}" -f $save) -ForegroundColor Green
Write-Host '  路径已复制到剪贴板，可以直接粘贴发出去。' -ForegroundColor DarkGray
Write-Host '  报告不含用户名、电脑名、完整路径等隐私信息；不发也不影响使用。' -ForegroundColor DarkGray
try { Set-Clipboard -Value $save } catch { }
Read-Host '  按回车关闭'
