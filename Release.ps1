# Release-Routine fuer Notizblock - haengt die Einzelschritte aneinander.
#
#   bauen  ->  lokal installieren (Windows)  ->  hochladen
#
#   Android : AAB -> GitHub-Release -> Play interner Test (store-upload.yml)
#   Windows : Release-Build + Test-MSIX (lokal installiert) + Store-MSIX
#             (Microsoft Store reicht Andi selbst ein; der Store-Job der Aktion
#             ueberspringt mangels API-Zugang ohnehin)
#   Linux   : Snap in WSL bauen -> Kanal edge (scripts/snap_bauen.sh)
#
# NUR DIE BETROFFENEN PLATTFORMEN (Andi, 2026-10-05): Betrifft eine Aenderung nur
# Android, wird auch nur Android aktualisiert - Windows/Linux bleiben, wie sie
# sind (keine geschlossenen Fenster, kein Neu-Installieren). Ebenso umgekehrt.
# Versionsnummer ist trotzdem EINE gemeinsame (pubspec.yaml), sie steigt bei
# jedem Release; die nicht aktualisierten Plattformen bleiben auf ihrer alten.
#   Fehlerbehebung  -> Patch (1.31.12 -> 1.31.13), nur betroffene Plattformen
#   neue Funktion   -> Minor (1.32.0) fuer ALLE Plattformen
#
# WARUM in dieser Reihenfolge: Die Version laeuft zuerst auf DIESEM PC, bevor sie
# irgendwo hochgeladen wird. Faellt beim lokalen Start etwas auf, bricht man ab,
# bevor ein Release existiert.
#
# GitHub-Release NUR mit Android: Das Release ist der Ausloeser fuer den
# Play-Upload und braucht das AAB (ohne AAB scheitert der Play-Job). Windows- oder
# Linux-Updates allein bekommen deshalb kein Release.
#
# SNAP seit 2026-10-05 LOKAL in WSL (Ubuntu-24.04, Benutzer andi), wie bei Wetter AW.
# Der Tag-Push loest KEINEN Snap-Bau mehr aus (snap.yml nur noch von Hand als Notweg).
#
# AUFRUF (aus dem Projektordner):
#   powershell -ExecutionPolicy Bypass -File Release.ps1                       # alle Plattformen
#   powershell -ExecutionPolicy Bypass -File Release.ps1 -Plattform Android    # nur Android
#   powershell -ExecutionPolicy Bypass -File Release.ps1 -Plattform "Windows,Linux"
#     (Kombination in Anfuehrungszeichen - aus PowerShell heraus wird
#      Windows,Linux sonst als zwei Argumente weitergereicht)
#   ... -SkipBuild    vorhandenen Build nehmen
#   ... -SkipInstall  Windows nicht lokal installieren
#   ... -SkipRelease  nur bauen/installieren, nichts hochladen
#   ... -Force        ohne Rueckfrage (aus Claude heraus noetig, sonst haengt Read-Host)
#   (-SkipSnap gibt es weiter: wie Linux abwaehlen.)
#
# VORHER die Version an ALLEN drei Stellen hochzaehlen (sonst bricht das Skript ab):
#   pubspec.yaml  version:      1.31.9+13109     <- Build-Nummer MUSS streng steigen
#   pubspec.yaml  msix_version: 1.31.9.0
#   lib/app_info.dart

param(
  # Kommagetrennt: Android, Windows, Linux - oder "alle". Als EIN Text, weil
  # "powershell -File" keine Arrays uebergibt.
  [string]$Plattform = 'alle',
  [switch]$SkipBuild,
  [switch]$SkipInstall,
  [switch]$SkipRelease,
  [switch]$SkipSnap,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
Set-Location $root

function Schritt($n, $text) { Write-Host "`n[$n] $text" -ForegroundColor Cyan }
function Warnung($text)     { Write-Host "  ! $text" -ForegroundColor DarkYellow }

# ---------------------------------------------------------- Plattformen waehlen
$alle = @('android', 'windows', 'linux')
if ($Plattform -match '^\s*(alle|all)\s*$') { $wahl = $alle }
else { $wahl = @($Plattform.ToLower() -split '[,+;\s]+' | Where-Object { $_ }) }
foreach ($p in $wahl) {
  if ($alle -notcontains $p) { throw "Unbekannte Plattform '$p' - erlaubt: Android, Windows, Linux (oder alle)" }
}
if ($SkipSnap) { $wahl = @($wahl | Where-Object { $_ -ne 'linux' }) }
$android = $wahl -contains 'android'
$windows = $wahl -contains 'windows'
$linux   = $wahl -contains 'linux'
if (-not ($android -or $windows -or $linux)) { throw "Keine Plattform gewaehlt." }

# Snap baut und laedt scripts/snap_bauen.sh IN WSL hoch (Projektpfad als /mnt/c/...).
$wslDistro = 'Ubuntu-24.04'
$wslSnapSkript = '/mnt/' + $root.Substring(0, 1).ToLower() + ($root.Substring(2) -replace '\\', '/') + '/scripts/snap_bauen.sh'

# ---------------------------------------------------------------- Version lesen
$pubspec = Get-Content 'pubspec.yaml' -Raw
if ($pubspec -notmatch '(?m)^\s*msix_version:\s*([\d.]+)') { throw "msix_version nicht in pubspec.yaml gefunden" }
$ver = $Matches[1]
if ($pubspec -notmatch '(?m)^version:\s*([\d.]+)\+(\d+)')  { throw "version: nicht in pubspec.yaml gefunden" }
$buildName = $Matches[1]; $buildCode = $Matches[2]
$tag = "v$ver"

$namen = @(); if ($android) { $namen += 'Android' }; if ($windows) { $namen += 'Windows' }; if ($linux) { $namen += 'Linux' }
Write-Host "Notizblock Release $ver  (versionCode $buildCode)  -  Plattformen: $($namen -join ', ')" -ForegroundColor White

# ------------------------------------------------- Vorpruefung: Git und Werkzeuge
Schritt 1 'Vorpruefung'

if ($android -and -not (Get-Command gh -ErrorAction SilentlyContinue)) { throw "gh (GitHub CLI) nicht gefunden" }

# WICHTIG: Bei einem release-Event liest GitHub den Workflow aus dem Commit, auf
# den der TAG zeigt - nicht aus main. Ein Release auf ungepushtem Stand wuerde
# also alte Workflows fahren. Genau daran ist 1.31.6 schon einmal gescheitert.
# (Auch ohne Android sinnvoll: gebaut wird der Arbeitsstand, er soll im Repo stehen.)
$dirty = git status --porcelain
if ($dirty) {
  Warnung "Arbeitsverzeichnis ist NICHT sauber:"
  $dirty | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkYellow }
  Warnung "Gebaut wird der Arbeitsstand, der Tag zeigt aber auf den letzten COMMIT."
  if (-not $Force) { throw "Erst committen, dann releasen. (Oder -Force, wenn das gewollt ist.)" }
}

$ahead = git rev-list --count '@{u}..HEAD' 2>$null
if ($LASTEXITCODE -eq 0 -and [int]$ahead -gt 0) {
  Warnung "$ahead Commit(s) noch nicht gepusht - der Tag zeigt auf einen Stand, den GitHub nicht kennt."
  if (-not $Force) { throw "Erst 'git push', dann releasen." }
}

# Existiert der Tag schon? Dann waere es kein neues Release.
# NICHT per `git rev-parse <tag> *> $null`: Unter Windows PowerShell 5.1 macht
# die Umleitung aus gits stderr-Meldung ("unknown revision") einen
# NativeCommandError, und $ErrorActionPreference='Stop' bricht das Skript ab -
# ausgerechnet im Normalfall, wenn es den Tag noch nicht gibt (so beim ersten
# Lauf fuer 1.31.9.0). `git tag --list` schreibt nie nach stderr.
if ($android -and (git tag --list "$tag")) { Warnung "Tag $tag existiert bereits - gh haengt das Release an den vorhandenen Tag." }

Write-Host "  ok" -ForegroundColor Green

$storeMsixName = "Notizblock-$ver-Store"

# ----------------------------------------------------------------------- Bauen
if (-not $SkipBuild) {
  Schritt 2 'Bauen'

  # Laufende App sperrt die .exe -> LNK1104 bzw. CMake-INSTALL schlaegt fehl.
  # Nur noetig, wenn Windows gebaut wird - sonst bleiben Andis Fenster offen.
  if ($windows) {
    $laufend = Get-Process notizblock -ErrorAction SilentlyContinue
    if ($laufend) {
      Write-Host "  laufende notizblock-Prozesse werden beendet ($($laufend.Count))" -ForegroundColor DarkYellow
      $laufend | Stop-Process -Force
      Start-Sleep -Seconds 2
    }
  }

  # --no-fatal-infos: Ohne den Schalter endet `flutter analyze` schon bei reinen
  # INFO-Hinweisen (prefer_const, deprecated ...) mit Code 1 - das Gate brach so
  # beim ersten echten Lauf (1.31.9.0) an 21 alten Hinweisen ab. Abbrechen soll
  # es bei Fehlern und Warnungen, dafuer bleibt --fatal-warnings (Standard) an.
  Write-Host "  flutter analyze" -ForegroundColor Gray
  flutter analyze --no-fatal-infos
  if ($LASTEXITCODE -ne 0) { throw "flutter analyze meldet Fehler - Release abgebrochen." }

  if ($android) {
    Write-Host "  AAB (Android)" -ForegroundColor Gray
    flutter build appbundle --release --build-name=$buildName --build-number=$buildCode
    if ($LASTEXITCODE -ne 0) { throw "AAB-Build fehlgeschlagen" }
  }

  if ($windows) {
    Write-Host "  Windows-Release + Test-MSIX + Store-MSIX" -ForegroundColor Gray
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "Windows-Build fehlgeschlagen" }
    dart run msix:create
    if ($LASTEXITCODE -ne 0) { throw "msix:create fehlgeschlagen" }
    # Store-Variante (andere Identitaet/Publisher, vom Store signiert) aus
    # demselben Build - frueher ein Handgriff nach dem Skript.
    dart run msix:create --store --build-windows false --identity-name AndreasWurzer.NotizblockAW --publisher "CN=8931876D-7B1F-44B7-8CE7-B81EAAF9533B" --publisher-display-name "Andreas Wurzer" --output-name $storeMsixName
    if ($LASTEXITCODE -ne 0) { throw "Store-MSIX fehlgeschlagen" }
  }

  # Snap jetzt schon bauen (nicht erst beim Hochladen): scheitert er, ist noch
  # nichts hochgeladen. Erster Bau ~10 min (LXD-Container + Flutter-SDK).
  if ($linux) {
    Write-Host "  Snap (Linux) in WSL" -ForegroundColor Gray
    & wsl.exe -d $wslDistro -u andi -- bash $wslSnapSkript
    if ($LASTEXITCODE -ne 0) { throw "Snap-Bau in WSL fehlgeschlagen (Log oben). Ohne Linux weiter: -Plattform ohne Linux" }
  }
} else {
  Schritt 2 'Bauen uebersprungen (-SkipBuild)'
}

# AAB einsammeln. NICHT nach E: kopieren (Ansage Andi) - Temp reicht, die Datei
# haengt gleich am Release und ist damit dauerhaft gesichert.
$aab = $null
if ($android) {
  $aabQuelle = Join-Path $root 'build\app\outputs\bundle\release\app-release.aab'
  if (-not (Test-Path $aabQuelle)) { throw "AAB nicht gefunden: $aabQuelle" }
  $aab = Join-Path $env:TEMP "Notizblock-$ver.aab"
  Copy-Item $aabQuelle $aab -Force
}

# Store-MSIX: NUR die zur Version passende (frueher griff das Skript die neueste
# im Ordner - bei 1.31.9.0 waere so die alte 1.31.8.0 ans Release gehaengt worden).
$storeMsix = $null
if ($windows) {
  $storeMsix = Get-Item (Join-Path $root "build\msix\$storeMsixName.msix") -ErrorAction SilentlyContinue
  if (-not $storeMsix) { Warnung "Keine Store-MSIX fuer $ver gefunden (build\msix\$storeMsixName.msix)." }
}

# ------------------------------------------------------------ Lokal installieren
if ($windows -and -not $SkipInstall) {
  Schritt 3 'Lokal installieren (Test-MSIX)'
  & (Join-Path $root 'installer\msix\Install-TestMsix.ps1')

  # Nach dem Update App neu starten, sonst kommen die angehefteten Widgets nicht
  # zurueck. Soll-Zahl steht in sticky_state\widget_ids.json.
  $pfn = (Get-AppxPackage -Name 'AW.NotizblockAW').PackageFamilyName
  Write-Host "  starte App neu (Widgets)" -ForegroundColor Gray
  Start-Process "shell:AppsFolder\$pfn!notizblock"
} elseif ($windows) {
  Schritt 3 'Lokale Installation uebersprungen (-SkipInstall)'
} else {
  Schritt 3 'Windows nicht betroffen - nichts installiert, App laeuft weiter'
}

# ------------------------------------------------------------------- Hochladen
if ($SkipRelease) { Schritt 4 'Hochladen uebersprungen (-SkipRelease)'; Write-Host "`nFertig." -ForegroundColor Green; exit 0 }

Schritt 4 'Hochladen'
Write-Host ""
if ($android) {
  Write-Host "  GitHub-Release $tag mit AAB$(if ($storeMsix) { ' + Store-MSIX' })" -ForegroundColor White
  Write-Host "    -> Google Play: Upload in den INTERNEN TEST (nur du), per GitHub-Aktion" -ForegroundColor Yellow
}
if ($linux) {
  Write-Host "  Snap $ver -> Kanal EDGE, direkt aus WSL" -ForegroundColor Yellow
  Write-Host "    stable nur von Hand: snapcraft release notizblock-aw <Revision> stable (snap/README.md)" -ForegroundColor Yellow
}
if ($windows -and -not $android) {
  Write-Host "  Windows: kein GitHub-Release (nur Android loest eins aus)." -ForegroundColor White
}
if ($storeMsix) {
  Write-Host "  Store-MSIX fuer den Microsoft Store (Einreichen von Hand): $($storeMsix.FullName)" -ForegroundColor White
}
Write-Host ""

if (($android -or $linux) -and -not $Force) {
  $antwort = Read-Host "  Jetzt hochladen? (j/N)"
  if ($antwort -notmatch '^[jJyY]') { Write-Host "Abgebrochen - es wurde nichts hochgeladen." -ForegroundColor DarkYellow; exit 0 }
}

if ($android) {
  $dateien = @($aab)
  if ($storeMsix) { $dateien += $storeMsix.FullName }
  gh release create $tag @dateien --title $tag --notes "Release $ver ($($namen -join ', '))"
  if ($LASTEXITCODE -ne 0) { throw "gh release create fehlgeschlagen" }
}

# Snap nach EDGE - die .snap stammt aus dem Bau-Schritt (auch bei -SkipBuild
# eines frueheren Laufs; das Skript prueft, dass sie zur Version passt).
if ($linux) {
  Schritt 5 'Snap nach edge hochladen (WSL)'
  & wsl.exe -d $wslDistro -u andi -- bash $wslSnapSkript --nur-hochladen
  if ($LASTEXITCODE -ne 0) {
    Warnung "Snap-Upload fehlgeschlagen. Nachholen:"
    Warnung "  wsl.exe -d $wslDistro -u andi -- bash $wslSnapSkript --nur-hochladen"
  }
}

Write-Host "`nFERTIG." -ForegroundColor Green
if ($android) { Write-Host "  Play-Upload ansehen:  gh run list --limit 3" -ForegroundColor Gray }
if ($linux)   { Write-Host "  Snap-Stand pruefen:   curl -s -H 'Snap-Device-Series: 16' https://api.snapcraft.io/v2/snaps/info/notizblock-aw" -ForegroundColor Gray }
