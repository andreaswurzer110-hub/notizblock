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
$msix = Join-Path $root 'build\msix\Notizblock-1.24.0.msix'

if (-not (Test-Path $msix)) { throw "MSIX fehlt: $msix  (zuerst: dart run msix:create)" }

# (1) Zertifikat vertrauen. Schlaegt der Import fehl (kein Admin) und ist das
# Zertifikat bereits vertraut, klappt die Installation trotzdem.
try {
  Import-Certificate -FilePath $cer -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' -ErrorAction Stop | Out-Null
  Write-Host "Test-Zertifikat vertraut." -ForegroundColor Cyan
} catch {
  Write-Host "Zertifikat-Import uebersprungen ($($_.Exception.Message))." -ForegroundColor DarkYellow
  Write-Host "Falls die Installation gleich an fehlendem Vertrauen scheitert: einmalig als Administrator ausfuehren." -ForegroundColor DarkYellow
}

# (2) Vorhandene Installation entfernen (idempotent).
Get-AppxPackage -Name 'AW.NotizblockAW' -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue

# (3) Frisch installieren.
Write-Host "Installiere Paket ..." -ForegroundColor Cyan
Add-AppxPackage -Path $msix

$pkg = Get-AppxPackage -Name 'AW.NotizblockAW'
Write-Host "`nFERTIG:" -ForegroundColor Green
Write-Host ("  {0}  {1}" -f $pkg.Name, $pkg.Version) -ForegroundColor Green
Write-Host ("  PackageFamilyName: {0}" -f $pkg.PackageFamilyName) -ForegroundColor Green
Write-Host "  Start ueber Startmenue: 'Notizblock AW'." -ForegroundColor Green
Write-Host "`n  Autostart testen: In der App Einstellungen -> 'Automatisch starten'" -ForegroundColor Green
Write-Host "  einschalten, dann pruefen unter Windows-Einstellungen -> Apps -> Autostart." -ForegroundColor Green
