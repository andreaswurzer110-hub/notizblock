# Baut Notizblock für Windows und packt einen Inno-Setup-Installer.
#
# Schritte: flutter build windows --release -> Staging (Build + VC++-Runtime)
#           -> ISCC kompiliert installer\notizblock.iss -> output\Notizblock-Setup-<ver>.exe
#
# Nutzung (aus dem Projektordner ODER von überall):
#   powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1
#   optional: -SkipBuild     (nutzt vorhandenen Release-Build, baut nicht neu)
#             -Version 1.2.0 (überschreibt die Version im .iss für diesen Lauf)
param(
    [switch]$SkipBuild,
    [string]$Version
)

$ErrorActionPreference = 'Stop'

# --- Pfade ---
$installerDir = $PSScriptRoot
$projectDir   = Split-Path $installerDir -Parent
$releaseDir   = Join-Path $projectDir 'build\windows\x64\runner\Release'
$stageDir     = Join-Path $installerDir 'stage'
$issFile      = Join-Path $installerDir 'notizblock.iss'

Write-Host "Projekt:   $projectDir" -ForegroundColor Cyan
Write-Host "Installer: $installerDir" -ForegroundColor Cyan

# --- 1) ISCC (Inno Setup Compiler) finden ---
$isccCandidates = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe"
)
$iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
    throw "ISCC.exe (Inno Setup) nicht gefunden. Installieren mit: winget install --id JRSoftware.InnoSetup -e"
}
Write-Host "ISCC:      $iscc" -ForegroundColor Cyan

# --- 2) flutter finden ---
$flutter = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if (-not $flutter) {
    $flutter = "C:\Users\awurz\Flutter\flutter\bin\flutter.bat"
}
if (-not (Test-Path $flutter)) { throw "flutter nicht gefunden ($flutter)." }

# --- 3) Release-Build ---
if (-not $SkipBuild) {
    Write-Host "`n== flutter build windows --release ==" -ForegroundColor Yellow
    Push-Location $projectDir
    try {
        & $flutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw "flutter build fehlgeschlagen (Exit $LASTEXITCODE)." }
    } finally { Pop-Location }
} else {
    Write-Host "`n== Build übersprungen (-SkipBuild) ==" -ForegroundColor Yellow
}
if (-not (Test-Path (Join-Path $releaseDir 'notizblock.exe'))) {
    throw "Release-Build fehlt: $releaseDir\notizblock.exe"
}

# --- 4) VC++-Runtime-Redist-DLLs finden (architektur-rein x64) ---
$needed = @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')
$crtDir = Get-ChildItem "C:\Program Files\Microsoft Visual Studio\*\*\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT" `
            -Directory -ErrorAction SilentlyContinue |
          Sort-Object FullName -Descending | Select-Object -First 1
if (-not $crtDir) {
    # Fallback: System32 (sind auf x64-Windows die 64-bit-Versionen)
    Write-Host "VC++-Redist nicht gefunden, nutze System32 als Fallback." -ForegroundColor DarkYellow
    $crtPath = "$env:WINDIR\System32"
} else {
    $crtPath = $crtDir.FullName
}
foreach ($d in $needed) {
    if (-not (Test-Path (Join-Path $crtPath $d))) {
        throw "VC++-Runtime-DLL fehlt: $d (in $crtPath)"
    }
}
Write-Host "VC++ CRT:  $crtPath" -ForegroundColor Cyan

# --- 5) Staging neu aufbauen ---
Write-Host "`n== Staging ==" -ForegroundColor Yellow
if (Test-Path $stageDir) { Remove-Item $stageDir -Recurse -Force }
New-Item -ItemType Directory -Path $stageDir -Force | Out-Null
Copy-Item (Join-Path $releaseDir '*') $stageDir -Recurse -Force
foreach ($d in $needed) { Copy-Item (Join-Path $crtPath $d) $stageDir -Force }

$stageSize = (Get-ChildItem $stageDir -Recurse | Measure-Object -Property Length -Sum).Sum
Write-Host ("Staging:   {0:N1} MB" -f ($stageSize / 1MB)) -ForegroundColor Cyan

# --- 6) Installer kompilieren ---
Write-Host "`n== ISCC ==" -ForegroundColor Yellow
$isccArgs = @($issFile)
if ($Version) { $isccArgs = @("/DMyAppVersion=$Version", $issFile) }
& $iscc @isccArgs
if ($LASTEXITCODE -ne 0) { throw "ISCC fehlgeschlagen (Exit $LASTEXITCODE)." }

# --- 7) Ergebnis ---
$outDir = Join-Path $installerDir 'output'
$setup  = Get-ChildItem $outDir -Filter 'Notizblock-Setup-*.exe' -ErrorAction SilentlyContinue |
          Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($setup) {
    Write-Host "`nFERTIG:" -ForegroundColor Green
    Write-Host ("  {0}  ({1:N2} MB)" -f $setup.FullName, ($setup.Length / 1MB)) -ForegroundColor Green
} else {
    throw "Setup.exe wurde nicht erzeugt (output-Ordner leer)."
}
