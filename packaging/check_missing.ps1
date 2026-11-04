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

# ---- 环境信息（只取不含隐私的项）----
$osLine = 'Windows (unknown)'
try {
    $osv = [System.Environment]::OSVersion.Version
    $cap = ''
    try { $cap = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption } catch { $cap = 'Windows' }
    $osLine = "$cap $($osv.Major).$($osv.Minor).$($osv.Build) [$env:PROCESSOR_ARCHITECTURE]"
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

$byText = @{}
foreach ($e in $entries) {
    $t = $e[1]
    if (-not $byText.ContainsKey($t)) { $byText[$t] = @{ n = 0; path = $e[0] } }
    $byText[$t].n = $byText[$t].n + 1
}

# ---- 生成报告 ----
$out = New-Object System.Collections.Generic.List[string]
$out.Add('PIGFACE 简体中文汉化 - 缺词报告')
$out.Add('====================================================')
$out.Add('')
$out.Add('【这份报告包含什么】')
$out.Add('  Windows 版本与位数、屏幕分辨率、补丁版本与词库条数、游戏 Steam buildid、')
$out.Add('  插件实际加载的字体、是否装了其它 BepInEx 插件、杀毒软件产品名（只读取名字，已卸载但残留登记的会被剔除）、')
$out.Add('  漏翻句子的原文，以及它出现在哪个界面。')
$out.Add('')
$out.Add('【这份报告不包含什么】')
$out.Add('  你的用户名、电脑名、IP/MAC 地址、Steam 账号、邮箱、游戏完整路径、存档内容。')
$out.Add('  安装位置只记录三个“是/否”：路径含中文、含空格、在 Program Files。')
$out.Add('')
$out.Add('【发不发都行】')
$out.Add('  发出来能帮作者补词；不发也不影响补丁正常使用，删掉本文件即可。')
$out.Add('')
$out.Add('----------------------------------------------------')
$out.Add("补丁版本：v$ver（词库 $dictCount 条）")
$out.Add("游戏版本：$gameVer")
$out.Add("生成时间：" + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
$out.Add("系统：$osLine")
$out.Add("分辨率：$resLine")
$out.Add("字体：$fontLine")
$out.Add("其它 BepInEx 插件：$otherLine")
$out.Add("杀毒软件：$avLine")
$out.Add("安装位置：路径含中文=$flagCjk，含空格=$flagSpc，在 Program Files=$flagPf")
$out.Add("注意：以上环境信息由系统接口自动读取，可能不完全准确（例如杀软卸载后仍有残留登记），仅供参考。")
$out.Add("记录条数：$($entries.Count) 条（去重后 $($byText.Count) 条）")
$out.Add('')
$out.Add('说明：这里只记录“插件真的没翻出来”的句子。人名（allow.txt）和技术串')
$out.Add('      （版本号、分辨率、SSAO/FPS）已被排除，正常情况下不会有误报。')
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

$save = Join-Path $PSScriptRoot '缺词报告.txt'
try {
    [System.IO.File]::WriteAllLines($save, $out, (New-Object System.Text.UTF8Encoding($true)))
} catch {
    $save = Join-Path $GamePath 'BepInEx\PigfaceCN\缺词报告.txt'
    [System.IO.File]::WriteAllLines($save, $out, (New-Object System.Text.UTF8Encoding($true)))
}

Write-Host ''
Write-Host ("  补丁 v" + $ver + "，词库 " + $dictCount + " 条") -ForegroundColor DarkGray
Write-Host ("  发现 " + $byText.Count + " 条没翻译的句子") -ForegroundColor Cyan
Write-Host ("  报告已保存到：" + $save) -ForegroundColor Green
Write-Host '  路径已复制到剪贴板，可以直接粘贴发出去。' -ForegroundColor DarkGray
Write-Host '  报告不含用户名、电脑名、完整路径等隐私信息；不发也不影响使用。' -ForegroundColor DarkGray
try { Set-Clipboard -Value $save } catch { }
Read-Host '  按回车关闭'
