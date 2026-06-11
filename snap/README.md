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
2. **Snap-Namen registrieren:** auf einem Linux-Host `snapcraft login` und
   `snapcraft register notizblock`. Ist der Name vergeben → anderen wählen
   (z.B. `notizblock-aw`) und in `snapcraft.yaml` (`name:`) angleichen.

## Bauen & veröffentlichen

Snap baut **nur auf Linux** – aber für „von Windows aus" gibt es zwei gute Wege:

### Weg A (empfohlen): Store-Build aus GitHub (kein Linux nötig)
Im Snap-Store-Dashboard (snapcraft.io/snaps → dein Snap → „Builds") das
GitHub-Repo verbinden. Canonical baut dann **in der Cloud** bei jedem Push und
veröffentlicht automatisch in den **edge**-Channel. Danach von Windows aus nur
noch: Code pushen → testen → Channel hochstufen.

### Weg B: lokal auf Zorin
```bash
sudo snap install snapcraft --classic
snapcraft            # baut die .snap (nutzt LXD)
sudo snap install ./notizblock_*.snap --dangerous   # lokal testen
snapcraft login
snapcraft upload --release=edge notizblock_*.snap
```

### Channel hochstufen (Release scharf schalten)
Wenn edge getestet ist:
```bash
snapcraft release notizblock <revision> stable
```
oder im Dashboard per Klick. Nutzer bekommen Updates dann automatisch.

> Hinweis: Canonical prüft Uploads seit 2026 (nach Fake-Crypto-Apps) teils
> **manuell** → die erste Freigabe kann etwas dauern. Es gibt **keinen**
> KI-Einreichungs-Bann wie bei Flathub.

## Vor dem ersten echten Build zu testen (Linux-Desktop)

Dieselben app-spezifischen Risiken wie beim Flatpak – Snap baut sie nur,
verifiziert aber nicht das Verhalten:

- [ ] Start + DB legt unter den Snap-Datenpfaden an (`~/snap/notizblock/...`)
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
