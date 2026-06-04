#!/usr/bin/env bash
# Baut die Linux-Version und installiert sie für den aktuellen Benutzer
# (Bundle + Icon + Startmenü-Eintrag). Getestet für Zorin OS / Ubuntu.
#
# Voraussetzungen (einmalig):
#   sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev
#   (Flutter SDK installiert und im PATH)
#
# Aufruf im Projektroot (Ordner mit pubspec.yaml):
#   bash scripts/install_linux.sh
set -euo pipefail

APP_NAME="notizblock"
PRETTY_NAME="Notizblock AW"
INSTALL_DIR="$HOME/.local/opt/$APP_NAME"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"

echo "==> Flutter-Abhängigkeiten holen"
flutter pub get

echo "==> Linux-Release bauen"
flutter build linux --release

# Bundle-Pfad (x64 oder arm64) ermitteln
BUNDLE=""
for arch in x64 arm64; do
  cand="build/linux/$arch/release/bundle"
  if [ -d "$cand" ]; then BUNDLE="$cand"; break; fi
done
if [ -z "$BUNDLE" ]; then
  echo "FEHLER: Bundle nicht gefunden unter build/linux/*/release/bundle" >&2
  exit 1
fi
echo "==> Bundle: $BUNDLE"

echo "==> Installiere nach $INSTALL_DIR"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -r "$BUNDLE"/. "$INSTALL_DIR/"

echo "==> Icon installieren"
mkdir -p "$ICON_DIR"
if [ -f "assets/icon/icon_full.png" ]; then
  cp "assets/icon/icon_full.png" "$ICON_DIR/$APP_NAME.png"
else
  echo "  (assets/icon/icon_full.png nicht gefunden – Icon übersprungen)"
fi

echo "==> Startmenü-Eintrag schreiben"
mkdir -p "$DESKTOP_DIR"
cat > "$DESKTOP_DIR/$APP_NAME.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$PRETTY_NAME
Comment=Plattformübergreifende Notizblock-App
Exec="$INSTALL_DIR/$APP_NAME" %U
Icon=$APP_NAME
Terminal=false
Categories=Utility;TextEditor;
StartupWMClass=$APP_NAME
EOF
chmod +x "$DESKTOP_DIR/$APP_NAME.desktop"

echo "==> Caches aktualisieren"
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo ""
echo "Fertig. Start über das Anwendungsmenü ('$PRETTY_NAME') oder direkt:"
echo "  $INSTALL_DIR/$APP_NAME"
echo "Autostart/Widgets lassen sich danach in den Einstellungen aktivieren."
