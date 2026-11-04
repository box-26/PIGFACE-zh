param(
    [string]$Source = "D:\AI-Workspace\release\PIGFACE-汉化",
    [string]$Out    = "D:\AI-Workspace\release\PIGFACE-zh-v1.6.zip"
)
$ErrorActionPreference = 'Stop'
$forbidden = @('game_path.txt', 'seen.txt', 'miss.log', 'debug.flag', 'LogOutput.log', '缺词报告.txt', 'missing_report.txt')
foreach ($f in $forbidden) {
    $p = Join-Path $Source $f
    if (Test-Path $p) { Remove-Item $p -Force; Write-Host "removed $f" }
}
foreach ($pat in @('*.pdb', 'dump_*', 'atlas.raw')) {
    Get-ChildItem -LiteralPath $Source -Recurse -File -Filter $pat -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-Item $_.FullName -Force; Write-Host ("removed " + $_.Name) }
}

if (Test-Path $Out) { Remove-Item $Out -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($Source, $Out, [System.IO.Compression.CompressionLevel]::Optimal, $false)

$zip = [System.IO.Compression.ZipFile]::OpenRead($Out)
$bad = @($zip.Entries | Where-Object { $_.Name -match '^(game_path\.txt|seen\.txt|miss\.log|debug\.flag|LogOutput\.log)$' -or $_.Name -like '*.pdb' -or $_.Name -like 'dump_*' -or $_.Name -eq 'atlas.raw' })
$count = $zip.Entries.Count
$zip.Dispose()
if ($bad.Count -gt 0) { Write-Host ("FORBIDDEN FILES STILL PRESENT: " + ($bad.Name -join ', ')); exit 1 }
Write-Host ("packed " + $count + " files -> " + $Out)
Write-Host ("size " + (Get-Item $Out).Length)
Write-Host ("sha256 " + (Get-FileHash $Out -Algorithm SHA256).Hash)