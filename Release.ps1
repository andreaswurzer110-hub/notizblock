# Release-Routine fuer Notizblock - haengt die Einzelschritte aneinander.
#
#   bauen  ->  lokal installieren  ->  GitHub-Release anlegen
#                                       |
#                                       +-> Play  : interner Test (store-upload.yml)
#                                       +-> Snap  : Kanal edge     (snap.yml)
#
# WARUM in dieser Reihenfolge: Die Version laeuft zuerst auf DIESEM PC, bevor sie
# irgendwo hochgeladen wird. Faellt beim lokalen Start etwas auf, bricht man ab,
# bevor ein Release existiert.
#
# AUFRUF (aus dem Projektordner):
#   powershell -ExecutionPolicy Bypass -File Release.ps1
#   powershell -ExecutionPolicy Bypass -File Release.ps1 -SkipBuild   # vorhandenen Build nehmen
#   powershell -ExecutionPolicy Bypass -File Release.ps1 -Force       # ohne Rueckfrage
#
# VORHER die Version an ALLEN drei Stellen hochzaehlen (sonst bricht das Skript ab):
#   pubspec.yaml  version:      1.31.9+13109     <- Build-Nummer MUSS streng steigen
#   pubspec.yaml  msix_version: 1.31.9.0
#   lib/app_info.dart

param(
  [switch]$SkipBuild,
  [switch]$SkipInstall,
  [switch]$SkipRelease,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
Set-Location $root

function Schritt($n, $text) { Write-Host "`n[$n] $text" -ForegroundColor Cyan }
function Warnung($text)     { Write-Host "  ! $text" -ForegroundColor DarkYellow }

# ---------------------------------------------------------------- Version lesen
$pubspec = Get-Content 'pubspec.yaml' -Raw
if ($pubspec -notmatch '(?m)^\s*msix_version:\s*([\d.]+)') { throw "msix_version nicht in pubspec.yaml gefunden" }
$ver = $Matches[1]
if ($pubspec -notmatch '(?m)^version:\s*([\d.]+)\+(\d+)')  { throw "version: nicht in pubspec.yaml gefunden" }
$buildName = $Matches[1]; $buildCode = $Matches[2]
$tag = "v$ver"

Write-Host "Notizblock Release $ver  (Tag $tag, versionCode $buildCode)" -ForegroundColor White

# ------------------------------------------------- Vorpruefung: Git und Werkzeuge
Schritt 1 'Vorpruefung'

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw "gh (GitHub CLI) nicht gefunden" }

# WICHTIG: Bei einem release-Event liest GitHub den Workflow aus dem Commit, auf
# den der TAG zeigt - nicht aus main. Ein Release auf ungepushtem Stand wuerde
# also alte Workflows fahren. Genau daran ist 1.31.6 schon einmal gescheitert.
$dirty = git status --porcelain
if ($dirty) {
  Warnung "Arbeitsverzeichnis ist NICHT sauber:"
  $dirty | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkYellow }
  Warnung "Der Tag wuerde auf den letzten COMMIT zeigen, nicht auf diese Aenderungen."
  if (-not $Force) { throw "Erst committen, dann releasen. (Oder -Force, wenn das gewollt ist.)" }
}

$ahead = git rev-list --count '@{u}..HEAD' 2>$null
if ($LASTEXITCODE -eq 0 -and [int]$ahead -gt 0) {
  Warnung "$ahead Commit(s) noch nicht gepusht - der Tag zeigt auf einen Stand, den GitHub nicht kennt."
  if (-not $Force) { throw "Erst 'git push', dann releasen." }
}

# Existiert der Tag schon? Dann waere es kein neues Release.
git rev-parse "$tag" *> $null
if ($LASTEXITCODE -eq 0) { Warnung "Tag $tag existiert bereits - gh haengt das Release an den vorhandenen Tag." }

Write-Host "  ok" -ForegroundColor Green

# ----------------------------------------------------------------------- Bauen
if (-not $SkipBuild) {
  Schritt 2 'Bauen'

  # Laufende App sperrt die .exe -> LNK1104 bzw. CMake-INSTALL schlaegt fehl.
  $laufend = Get-Process notizblock -ErrorAction SilentlyContinue
  if ($laufend) {
    Write-Host "  laufende notizblock-Prozesse werden beendet ($($laufend.Count))" -ForegroundColor DarkYellow
    $laufend | Stop-Process -Force
    Start-Sleep -Seconds 2
  }

  Write-Host "  flutter analyze" -ForegroundColor Gray
  flutter analyze
  if ($LASTEXITCODE -ne 0) { throw "flutter analyze meldet Fehler - Release abgebrochen." }

  Write-Host "  AAB (Android)" -ForegroundColor Gray
  flutter build appbundle --release --build-name=$buildName --build-number=$buildCode
  if ($LASTEXITCODE -ne 0) { throw "AAB-Build fehlgeschlagen" }

  Write-Host "  Windows-Release + Test-MSIX" -ForegroundColor Gray
  flutter build windows --release
  if ($LASTEXITCODE -ne 0) { throw "Windows-Build fehlgeschlagen" }
  dart run msix:create
  if ($LASTEXITCODE -ne 0) { throw "msix:create fehlgeschlagen" }
} else {
  Schritt 2 'Bauen uebersprungen (-SkipBuild)'
}

# AAB einsammeln. NICHT nach E: kopieren (Ansage Andi) - Temp reicht, die Datei
# haengt gleich am Release und ist damit dauerhaft gesichert.
$aabQuelle = Join-Path $root 'build\app\outputs\bundle\release\app-release.aab'
if (-not (Test-Path $aabQuelle)) { throw "AAB nicht gefunden: $aabQuelle" }
$aab = Join-Path $env:TEMP "Notizblock-$ver.aab"
Copy-Item $aabQuelle $aab -Force

# Store-MSIX ist optional: der MS-Store-Job ueberspringt mangels Secrets ohnehin
# (Konto Typ "Einzelperson" -> Submission-API nicht autorisierbar). Wenn eine
# Store-MSIX vorliegt, kommt sie als Archiv mit ans Release.
$storeMsix = Get-ChildItem (Join-Path $root 'build\msix\*-Store.msix') -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1

# ------------------------------------------------------------ Lokal installieren
if (-not $SkipInstall) {
  Schritt 3 'Lokal installieren (Test-MSIX)'
  & (Join-Path $root 'installer\msix\Install-TestMsix.ps1')

  # Nach dem Update App neu starten, sonst kommen die angehefteten Widgets nicht
  # zurueck. Soll-Zahl steht in sticky_state\widget_ids.json.
  $pfn = (Get-AppxPackage -Name 'AW.NotizblockAW').PackageFamilyName
  Write-Host "  starte App neu (Widgets)" -ForegroundColor Gray
  Start-Process "shell:AppsFolder\$pfn!notizblock"
} else {
  Schritt 3 'Lokale Installation uebersprungen (-SkipInstall)'
}

# ------------------------------------------------------------------- Release
if ($SkipRelease) { Schritt 4 'Release uebersprungen (-SkipRelease)'; Write-Host "`nFertig." -ForegroundColor Green; exit 0 }

Schritt 4 'GitHub-Release anlegen'
Write-Host ""
Write-Host "  Tag      : $tag" -ForegroundColor White
Write-Host "  AAB      : $aab" -ForegroundColor White
if ($storeMsix) { Write-Host "  StoreMSIX: $($storeMsix.FullName)" -ForegroundColor White }
Write-Host ""
Write-Host "  Das loest AUTOMATISCH aus:" -ForegroundColor Yellow
Write-Host "    - Google Play : Upload in den INTERNEN TEST (nur du)" -ForegroundColor Yellow
Write-Host "    - Snap Store  : Veroeffentlichung im Kanal EDGE" -ForegroundColor Yellow
Write-Host "    stable erreicht man nur von Hand ueber Actions -> Snap-Build." -ForegroundColor Yellow
Write-Host ""

if (-not $Force) {
  $antwort = Read-Host "  Release jetzt anlegen? (j/N)"
  if ($antwort -notmatch '^[jJyY]') { Write-Host "Abgebrochen - es wurde nichts hochgeladen." -ForegroundColor DarkYellow; exit 0 }
}

$dateien = @($aab)
if ($storeMsix) { $dateien += $storeMsix.FullName }

gh release create $tag @dateien --title $tag --notes "Release $ver"
if ($LASTEXITCODE -ne 0) { throw "gh release create fehlgeschlagen" }

Write-Host "`nFERTIG." -ForegroundColor Green
Write-Host "  Laufende Workflows ansehen:  gh run list --limit 5" -ForegroundColor Gray
Write-Host "  Snap-Stand pruefen:          gh run watch" -ForegroundColor Gray
