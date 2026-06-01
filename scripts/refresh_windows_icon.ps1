# Leert den Windows-Icon-Cache und startet den Explorer neu.
#
# Hintergrund: Die notizblock.exe hat das richtige Icon eingebettet, Windows
# cached Icons aber aggressiv -> Verknüpfung/Taskleiste/Explorer zeigen weiter
# das alte oder ein leeres Icon. Dieses Skript erzwingt das Neuladen.
#
# Aufruf (kein Admin nötig):
#   powershell -ExecutionPolicy Bypass -File scripts\refresh_windows_icon.ps1

Write-Host "Beende Explorer..." -ForegroundColor Cyan
taskkill /f /im explorer.exe 2>$null | Out-Null

Start-Sleep -Milliseconds 500

Write-Host "Loesche Icon-Cache-Dateien..." -ForegroundColor Cyan
$localAppData = $env:LOCALAPPDATA

# Klassische IconCache.db
$iconCache = Join-Path $localAppData "IconCache.db"
if (Test-Path $iconCache) {
    Remove-Item $iconCache -Force -ErrorAction SilentlyContinue
    Write-Host "  geloescht: IconCache.db"
}

# Moderne iconcache_*.db im Explorer-Cache-Ordner
$explorerCache = Join-Path $localAppData "Microsoft\Windows\Explorer"
if (Test-Path $explorerCache) {
    Get-ChildItem -Path $explorerCache -Filter "iconcache_*.db" -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
        Write-Host "  geloescht: $($_.Name)"
    }
    # Auch Thumbnail-Cache mitnehmen (schadet nicht)
    Get-ChildItem -Path $explorerCache -Filter "thumbcache_*.db" -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
    }
}

Start-Sleep -Milliseconds 500

Write-Host "Starte Explorer neu..." -ForegroundColor Cyan
Start-Process explorer.exe

Write-Host "Fertig. Icon-Cache geleert." -ForegroundColor Green
Write-Host "Falls die Verknuepfung weiterhin das alte Icon zeigt: Verknuepfung loeschen und neu anlegen (sie cached das Icon separat)." -ForegroundColor Yellow
