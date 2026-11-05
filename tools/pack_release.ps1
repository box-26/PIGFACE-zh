param(
    # Folder that will become the zip root. Must contain BepInEx\plugins\PigfaceCN\.
    [string]$Source = (Join-Path $PSScriptRoot '..\dist'),
    # Output zip. Default: out\PIGFACE-zh.zip next to this repo.
    [string]$Out    = (Join-Path $PSScriptRoot '..\out\PIGFACE-zh.zip')
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path (Join-Path $Source 'BepInEx\plugins\PigfaceCN\PigfaceCN.dll'))) {
    Write-Host ("Source folder does not look like a release payload: " + $Source)
    Write-Host "Pass -Source <folder containing BepInEx\plugins\PigfaceCN\PigfaceCN.dll>"
    exit 1
}
$Source = (Resolve-Path -LiteralPath $Source).Path
$outDir = Split-Path -Parent $Out
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
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

# Debug features must not exist in the shipped DLL at all (they are compiled out
# with #if PIGFACE_DEBUG). If any of these symbols is present, the build is wrong.
$dll = Join-Path $Source 'BepInEx\plugins\PigfaceCN\PigfaceCN.dll'
if (-not (Test-Path $dll)) { Write-Host "MISSING PigfaceCN.dll"; exit 1 }
$ascii = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($dll))
$debugSymbols = @('CompleteObjectives', 'DumpObjectives', 'DumpScreen', 'TestRender', 'PIGFACE_DEBUG')
$leaked = @($debugSymbols | Where-Object { $ascii.Contains($_) })
if ($leaked.Count -gt 0) {
    Write-Host ("DEBUG SYMBOLS IN RELEASE BUILD: " + ($leaked -join ', ') + " -> rebuild without -p:DefineConstants=PIGFACE_DEBUG")
    exit 1
}
Write-Host ("packed " + $count + " files -> " + $Out)
Write-Host ("size " + (Get-Item $Out).Length)
Write-Host ("sha256 " + (Get-FileHash $Out -Algorithm SHA256).Hash)