# Notizblock im Snap Store

Snap-Packaging für die Veröffentlichung im **Snap Store** (echte, durchsuchbare
Store-Präsenz in Ubuntu/Zorin-„Software" und über `snap find`).

Aktueller Bauweg: `base: core22` + `gnome`-Extension + `flutter`-Plugin
(die alte `flutter`-Extension ist veraltet/core18-only).

## Dateien

| Datei | Zweck |
|-------|-------|
| `snapcraft.yaml` | Build-Rezept |
| `gui/notizblock.desktop` | Desktop-Eintrag |
| `gui/notizblock.png` | Icon (256px, aus `flatpak/icons/`) |

Der Build spielt denselben dedizierten, bewusst öffentlichen Linux-OAuth-Client
ein wie der Flatpak-Build (`flatpak/google_drive_config.dart` → `lib/services/`).

## Einmaliges Setup

1. **Ubuntu-One-Account** (snapcraft.io) – kostenlos.
2. **Snap-Name:** Registriert als **`notizblock-aw`** (`notizblock` war vergeben);
   passt zu `name:`/App-Name in `snapcraft.yaml`.

## Bauen & veröffentlichen

Snap baut **nur auf Linux** – für „von Windows aus" baut die GitHub-Actions-
Pipeline `.github/workflows/snap.yml` in GitHubs Cloud-Linux und lädt hoch.
(Die GitHub-Build-Verknüpfung im Store-Dashboard erscheint erst nach der ersten
Revision – darum der CI-Weg.)

### Einmalig: Store-Token erzeugen (braucht einmal Linux/Zorin)
```bash
sudo snap install snapcraft --classic
snapcraft login                       # Browser-Login
snapcraft export-login --snaps=notizblock-aw \
  --acls package_access,package_push,package_update,package_release exported.txt
cat exported.txt                      # gesamten Inhalt kopieren
```
Inhalt als Repo-Secret hinterlegen: GitHub → Repo → **Settings → Secrets and
variables → Actions → New repository secret** → Name
**`SNAPCRAFT_STORE_CREDENTIALS`**, Wert = der kopierte Inhalt.
(Das Token läuft per Default nach ~1 Jahr ab → dann neu erzeugen.)

### Releasen (von Windows)
- **Testen:** GitHub → Actions → „Snap-Build" → **Run workflow** (Channel `edge`)
  → baut + veröffentlicht nach edge. Test auf Zorin: `sudo snap install notizblock-aw --edge`.
- **Live:** Tag pushen → Pipeline veröffentlicht nach **stable**:
  `git tag vX.Y.Z; git push origin vX.Y.Z`. Danach für alle via `snap install notizblock-aw`.
- Ohne gesetztes Secret läuft nur der **Build** (Validierung), Veröffentlichen wird
  übersprungen – praktisch für den ersten Probelauf.

### Alternative: alles lokal auf Zorin
```bash
sudo snap install snapcraft --classic
snapcraft            # baut die .snap (nutzt LXD)
sudo snap install ./notizblock-aw_*.snap --dangerous   # lokal testen
snapcraft login
snapcraft upload --release=edge notizblock-aw_*.snap
```

### Channel hochstufen (Release scharf schalten)
Wenn edge getestet ist:
```bash
snapcraft release notizblock-aw <revision> stable
```
oder im Dashboard per Klick. Nutzer bekommen Updates dann automatisch.

> Hinweis: Canonical prüft Uploads seit 2026 (nach Fake-Crypto-Apps) teils
> **manuell** → die erste Freigabe kann etwas dauern. Es gibt **keinen**
> KI-Einreichungs-Bann wie bei Flathub.

## Vor dem ersten echten Build zu testen (Linux-Desktop)

Dieselben app-spezifischen Risiken wie beim Flatpak – Snap baut sie nur,
verifiziert aber nicht das Verhalten:

- [ ] Start + DB legt unter den Snap-Datenpfaden an (`~/snap/notizblock-aw/...`)
- [ ] Drive-Login: Browser öffnet, Loopback `127.0.0.1` empfängt Token
- [ ] Sticky-Fenster (eigene Prozesse) öffnen und **Position bleibt** nach
      Neustart (X11/XWayland)
- [ ] Taskleisten-Gruppierung (Haupt + Stickys unter einem Eintrag)
- [ ] Autostart-Schalter

## Bekannte Anpassungspunkte (Snap-spezifisch, ggf. nach Erst-Test)

- **Autostart:** Unter strenger Confinement kann nicht direkt in
  `~/.config/autostart` geschrieben werden. Snap startet Desktop-Dateien aus
  `$SNAP_USER_DATA/.config/autostart` über `snapd` – `AutostartService` braucht
  dafür evtl. einen Snap-Zweig (analog zum Flatpak-Portal). Kein Blocker für die
  Store-Aufnahme.
- **Multi-Prozess-Stickys:** `Process.start(Platform.resolvedExecutable, …)`
  läuft im Snap im selben Confinement-Kontext (Env wird vererbt) – beim Erst-Test
  prüfen, dass die Sticky-Prozesse Libraries finden.
- **X11-Positionierung:** wie beim Flatpak nur unter X11/XWayland zuverlässig.
