# Installiert/aktualisiert das MSIX-TEST-Paket lokal zum Ausprobieren.
#
# Ablauf: (1) Test-Zertifikat vertrauen (nur beim ERSTEN Mal noetig -> Admin),
#         (2) evtl. vorhandene Installation entfernen (gleiche Version laesst
#             sich sonst nicht neu installieren), (3) Paket installieren.
#
# Erstes Mal als ADMINISTRATOR ausfuehren (Zertifikat -> LocalMachine):
#   powershell -ExecutionPolicy Bypass -File installer\msix\Install-TestMsix.ps1
# Spaetere Neu-Builds: Zertifikat ist schon vertraut -> laeuft auch OHNE Admin.
#
# Voraussetzung: vorher `dart run msix:create` (erzeugt build\msix\*.msix).
# Deinstallieren: Get-AppxPackage *NotizblockAW* | Remove-AppxPackage
$ErrorActionPreference = 'Stop'

# Projektwurzel = zwei Ebenen ueber diesem Skript (installer\msix\..\..)
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$cer  = Join-Path $root 'certs\notizblock_test.cer'

# Neueste lokale Test-MSIX nehmen. Die Store-Variante (*-Store.msix) ist
# ausgeschlossen: unsigniert + Partner-Center-Identitaet -> nicht sideloadbar.
$msixItem = Get-ChildItem (Join-Path $root 'build\msix\Notizblock-*.msix') -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -notlike '*-Store*' } |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $msixItem) { throw "Keine Test-MSIX in build\msix gefunden (zuerst: dart run msix:create)" }
$msix = $msixItem.FullName
Write-Host "Paket: $msix" -ForegroundColor Cyan

# (1) Zertifikat vertrauen. Schlaegt der Import fehl (kein Admin) und ist das
# Zertifikat bereits vertraut, klappt die Installation trotzdem.
try {
  Import-Certificate -FilePath $cer -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' -ErrorAction Stop | Out-Null
  Write-Host "Test-Zertifikat vertraut." -ForegroundColor Cyan
} catch {
  Write-Host "Zertifikat-Import uebersprungen ($($_.Exception.Message))." -ForegroundColor DarkYellow
  Write-Host "Falls die Installation gleich an fehlendem Vertrauen scheitert: einmalig als Administrator ausfuehren." -ForegroundColor DarkYellow
}

# (2) IN-PLACE-Update bevorzugen (KEIN vorheriges Remove): nur so bleibt der
# Taskleisten-/Startmenue-Pin erhalten. Voraussetzung: hoehere Version als die
# installierte (Revision .x in pubspec hochzaehlen). Faellt das fehl, mit
# -ForceUpdateFromAnyVersion versuchen; erst als letzter Ausweg Remove+Add
# (verliert den Pin).
Write-Host "Installiere Paket (In-Place-Update) ..." -ForegroundColor Cyan
try {
  Add-AppxPackage -Path $msix -ForceApplicationShutdown -ErrorAction Stop
} catch {
  Write-Host "  In-Place fehlgeschlagen, versuche -ForceUpdateFromAnyVersion ..." -ForegroundColor DarkYellow
  try {
    Add-AppxPackage -Path $msix -ForceUpdateFromAnyVersion -ForceApplicationShutdown -ErrorAction Stop
  } catch {
    Write-Host "  Auch das schlug fehl -> Remove+Add (Pin geht verloren)." -ForegroundColor DarkYellow
    Get-AppxPackage -Name 'AW.NotizblockAW' -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
    Add-AppxPackage -Path $msix
  }
}

$pkg = Get-AppxPackage -Name 'AW.NotizblockAW'
Write-Host "`nFERTIG:" -ForegroundColor Green
Write-Host ("  {0}  {1}" -f $pkg.Name, $pkg.Version) -ForegroundColor Green
Write-Host ("  PackageFamilyName: {0}" -f $pkg.PackageFamilyName) -ForegroundColor Green
Write-Host "  Start ueber Startmenue: 'Notizblock AW'." -ForegroundColor Green
Write-Host "`n  Autostart testen: In der App Einstellungen -> 'Automatisch starten'" -ForegroundColor Green
Write-Host "  einschalten, dann pruefen unter Windows-Einstellungen -> Apps -> Autostart." -ForegroundColor Green
