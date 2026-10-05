#!/bin/bash
# Snap LOKAL in WSL bauen (seit 2026-10-05, wie bei Wetter AW) – statt über
# GitHub Actions. So sieht man Baufehler sofort und testet den Snap, bevor er
# hochgeladen wird.
#
# AUFRUF (in WSL als andi, oder von Windows aus – Release.ps1 macht das):
#   bash scripts/snap_bauen.sh                 # nur bauen
#   bash scripts/snap_bauen.sh --installieren  # bauen + lokal installieren (--dangerous)
#   bash scripts/snap_bauen.sh --hochladen     # bauen + nach EDGE hochladen
#   bash scripts/snap_bauen.sh --nur-hochladen # vorhandene .snap nach EDGE hochladen
#
#   von Windows (Git Bash):
#   MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-24.04 -u andi -- bash \
#     /mnt/c/Users/awurz/Apps/notizblock_app/notizblock_app/scripts/snap_bauen.sh --hochladen
#
# EINMALIG eingerichtet (siehe snap/README.md): snapcraft + LXD in WSL,
# Store-Zugang in ~/.snapcraft-login (NIE ausgeben).
#
# STABLE gibt es weiterhin nur bewusst und von Hand, nach dem Prüfen von edge:
#   SNAPCRAFT_STORE_CREDENTIALS=$(cat ~/.snapcraft-login) snapcraft release notizblock-aw <Revision> stable
set -euo pipefail

INSTALLIEREN=false; HOCHLADEN=false; BAUEN=true
for a in "$@"; do
  case "$a" in
    --installieren) INSTALLIEREN=true ;;
    --hochladen) HOCHLADEN=true ;;
    --nur-hochladen) HOCHLADEN=true; BAUEN=false ;;
    *) echo "Unbekannte Option: $a" >&2; exit 2 ;;
  esac
done

QUELLE="$(cd "$(dirname "$0")/.." && pwd)"   # Projektroot (pubspec.yaml)
ZIEL="$HOME/notizblock-aw"                   # Baukopie im Linux-Dateisystem
export PATH="/snap/bin:$PATH"

[ -f "$QUELLE/pubspec.yaml" ] || { echo "pubspec.yaml nicht gefunden unter $QUELLE" >&2; exit 1; }
VER=$(sed -n 's/^[[:space:]]*msix_version:[[:space:]]*\([0-9.]*\).*/\1/p' "$QUELLE/pubspec.yaml")
SNAP_DATEI="$ZIEL/notizblock-aw_${VER}_amd64.snap"
echo "Notizblock-Snap $VER"

if $BAUEN; then
  # Auf /mnt/c baut snapcraft sehr langsam -> Kopie in ~ (Wetter-AW-Erfahrung).
  # NICHT mitkopieren: Build-Reste, Windows/Android, Schlüssel und Zertifikate.
  # lib/services/google_drive_config.dart (Desktop-Client) kommt mit, wird im
  # Rezept aber durch den öffentlichen Linux-Client aus flatpak/ ersetzt.
  rsync -a --delete \
    --exclude /build/ --exclude .dart_tool/ --exclude /android/ --exclude /windows/ \
    --exclude /installer/ --exclude /certs/ --exclude .git/ --exclude .idea/ \
    --exclude '*.log' --exclude '*.snap' \
    "$QUELLE/" "$ZIEL/"
  # Windows-Zeilenenden würden die Shell-Teile des Rezepts zerlegen.
  sed -i 's/\r$//' "$ZIEL/snap/snapcraft.yaml"

  cd "$ZIEL"
  rm -f ./*.snap
  # Baut im LXD-Container (snapcraft 9). Der erste Bau lädt Abbild + Flutter-SDK
  # (~10 min); danach nutzt LXD den Container weiter, solange sich das Rezept
  # nicht ändert.
  snapcraft pack
  [ -f "$SNAP_DATEI" ] || { echo "Erwartete Datei fehlt: $SNAP_DATEI" >&2; ls -la "$ZIEL"/*.snap >&2 || true; exit 1; }
  echo "Gebaut: $SNAP_DATEI ($(du -h "$SNAP_DATEI" | cut -f1))"
fi

if $INSTALLIEREN; then
  # Lokal testen; braucht root. Aus Windows: wsl.exe -u root -- snap install --dangerous …
  sudo snap install --dangerous "$SNAP_DATEI"
fi

if $HOCHLADEN; then
  [ -f "$SNAP_DATEI" ] || { echo "Keine .snap für $VER: $SNAP_DATEI" >&2; exit 1; }
  [ -s "$HOME/.snapcraft-login" ] || { echo "Store-Zugang ~/.snapcraft-login fehlt (siehe snap/README.md)" >&2; exit 1; }
  # Nur EDGE (Testkanal, wie der interne Test bei Play). stable bewusst von Hand.
  SNAPCRAFT_STORE_CREDENTIALS="$(cat "$HOME/.snapcraft-login")" \
    snapcraft upload --release=edge "$SNAP_DATEI"
fi
