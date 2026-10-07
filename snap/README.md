# Notizblock im Snap Store

Snap-Packaging für die Veröffentlichung im **Snap Store** (echte, durchsuchbare
Store-Präsenz in Ubuntu/Zorin-„Software" und über `snap find`).

Aktueller Bauweg: `base: core22` + `gnome`-Extension + `plugin: nil` mit fest
eingestelltem Flutter-SDK (`FLUTTER_VERSION`, Begründung im Rezept) und
`compression: lzo` (schnellerer Kaltstart, siehe unten „Start-Performance").

## Dateien

| Datei | Zweck |
|-------|-------|
| `snapcraft.yaml` | Build-Rezept |
| `gui/notizblock-aw.desktop` | Desktop-Eintrag |
| `gui/notizblock-aw.png` | Icon (256px, aus `flatpak/icons/`); der Linux-Runner lädt es im Snap auch als Fenstersymbol |
| `../scripts/snap_bauen.sh` | lokaler Bau + Upload in WSL |

Der Build spielt denselben dedizierten, bewusst öffentlichen Linux-OAuth-Client
ein wie der Flatpak-Build (`flatpak/google_drive_config.dart` → `lib/services/`).

## Einmaliges Setup

1. **Ubuntu-One-Account** (snapcraft.io) – kostenlos.
2. **Snap-Name:** Registriert als **`notizblock-aw`** (`notizblock` war vergeben);
   passt zu `name:`/App-Name in `snapcraft.yaml`.

## Bauen & veröffentlichen – lokal in WSL (seit 2026-10-05)

Wie bei Wetter AW wird der Snap **lokal in WSL** gebaut (Ubuntu-24.04, Benutzer
`andi`), nicht mehr in GitHub Actions: Baufehler sieht man sofort, und der
Snap lässt sich vor dem Hochladen testen. `Release.ps1` erledigt beides – Bau
im Bau-Schritt, Upload nach **edge** nach dem GitHub-Release (`-SkipSnap`
lässt beides weg). Ein Tag-Push baut **keinen** Snap mehr.

Von Hand (Git Bash; `MSYS_NO_PATHCONV=1`, sonst verbiegt Git Bash den Pfad):

```bash
S=/mnt/c/Users/awurz/Apps/notizblock_app/notizblock_app/scripts/snap_bauen.sh
MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-24.04 -u andi -- bash $S                 # nur bauen
MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-24.04 -u andi -- bash $S --hochladen     # bauen + edge
MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-24.04 -u andi -- bash $S --nur-hochladen # vorhandene .snap
MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-24.04 -u root -- snap install --dangerous   /home/andi/notizblock-aw/notizblock-aw_<msix_version>_amd64.snap             # lokal testen
```

Das Skript kopiert das Projekt per `rsync` nach `~/notizblock-aw` (auf `/mnt/c`
baut snapcraft sehr langsam) und ruft dort `snapcraft pack` auf – gebaut wird
im LXD-Container. Der erste Bau dauert ~10 min (Container + Flutter-SDK).

**Einmalig in WSL eingerichtet** (gilt für alle Apps, Details in der README von
Wetter AW): `snap install snapcraft --classic`, `snap install lxd`,
`lxd init --auto`, `andi` in der Gruppe `lxd`, die systemd-Einheit
`wsl-mount-shared.service` gegen die WSL-Namensraum-Falle. Store-Zugang:

```bash
snapcraft export-login --snaps=wetter-aw,notizblock-aw   --acls package_access,package_push,package_update,package_release ~/.snapcraft-login
chmod 600 ~/.snapcraft-login      # NIE ausgeben; läuft nach ~1 Jahr ab
```

### Notweg: GitHub Actions
`.github/workflows/snap.yml` läuft nur noch **von Hand** (Actions → „Snap-Build"
→ Run workflow, Channel wählbar; oder `promote_revision`, um eine bestehende
Revision umzuhängen). Braucht das Repo-Secret `SNAPCRAFT_STORE_CREDENTIALS`.

### Channel hochstufen (Release scharf schalten)
Wenn edge getestet ist (in WSL):
```bash
SNAPCRAFT_STORE_CREDENTIALS=$(cat ~/.snapcraft-login) snapcraft release notizblock-aw <revision> stable
```
Revision steht in der Ausgabe von `snapcraft upload` bzw.
`curl -s -H 'Snap-Device-Series: 16' "https://api.snapcraft.io/v2/snaps/info/notizblock-aw?fields=revision,version"`.
Nutzer bekommen Updates dann automatisch.

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

## Start-Performance im Snap (gemessen 2026-10-05 in WSL)

Gegenüber einem normalen Linux-Build startete der Snap deutlich langsamer,
vor allem beim ersten Öffnen nach dem Hochfahren. Messung: Zeit bis zum
sichtbaren Hauptfenster auf einem unsichtbaren X-Bildschirm (Xvfb), echte
Notizen-DB, schneller Desktop-Prozessor – auf einem Notebook-i5 ein Vielfaches.

| Fall | Zeit |
|------|------|
| nativer Build, warm | 0,22 s |
| Snap 1.31.10, warm | 0,72 s (0,2 s Snap-Hülle + 0,52 s App) |
| Snap 1.31.10, warm, GNOME-Header-Bar | 0,82–0,88 s |
| Snap 1.31.10, wie nach dem Hochfahren | 3,4 s (1,85 s bis die App startet) |
| **Snap 1.31.11**, warm | **0,50 s** |
| **Snap 1.31.11**, warm, GNOME-Kennung | **0,50–0,54 s** (keine Header Bar mehr im Snap) |
| **Snap 1.31.11**, wie nach dem Hochfahren | **2,7 s** (App-Teil 0,85 statt 1,5 s) |

Andis Notebook (i5-7200U, 8 GB, Zorin) brauchte mit 1.31.10 ~8–10 s, bis das
Hauptfenster bedienbar war – grob Faktor 2,5–3 gegenüber dieser Messung.

Ursachen, nach Größe:
1. **Symbolsuche in veralteten Caches (behoben in 1.31.11).** Die Symbol-Themes
   im Snap (gtk-common-themes, gnome-42-2204) haben `icon-theme.cache`-Dateien,
   die älter sind als ihre Ordner → GTK verwirft sie und liest ~1.800 Ordner
   einzeln ein, **bevor** die Flutter-Engine startet. Ausgelöst durch das
   Fenstersymbol per Name und die GTK-Header-Bar (deren Knöpfe sind Symbole).
   Fix im Linux-Runner: im Snap unter X11 keine Header Bar (der Fenstermanager
   zeichnet die Titelleiste) und das Fenstersymbol direkt aus
   `$SNAP/meta/gui/notizblock-aw.png`. Trifft jeden Prozess, also auch jedes
   Sticky-Fenster.
2. **Snap-Namensraum** (~0,8 s): snapd baut ihn beim ersten Start nach dem
   Hochfahren auf. Nicht beeinflussbar.
3. **Entpacken beim Kaltstart:** App-Teil 1,5 s mit xz, 1,15–1,3 s mit lzo →
   `compression: lzo` (behoben in 1.31.11).
4. **desktop-launch** der gnome-Extension: ~0,2 s bei jedem Start über Symbol
   oder Autostart (655 Zeilen Bash). Sticky-Fenster und das Hauptfenster aus
   einem Widget starten direkt (`Process.start`) und zahlen das nicht.

Messskripte lagen im Scratchpad der Sitzung; das Vorgehen: Snap-Namensraum
verwerfen (`/usr/lib/snapd/snap-discard-ns notizblock-aw`) + Seitencache leeren
(`echo 3 > /proc/sys/vm/drop_caches`), dann starten und per
`xdotool search --onlyvisible --name '^Notizblock AW$'` auf das Fenster warten.

### Offen: ~2,7 s bis die Notizen erscheinen (Zorin, ab 1.31.11)

Messung Andi (Zorin-18-VM, Snap-Rev. 49 mit Zeitstempeln, 9 Durchgänge): Fenster
nach 0,4 s, Notizen nach 15–30 ms aus der DB gelesen – das **Bild mit den
Notizen** kommt aber erst ~2,9 s nach dem Dart-Start (±15 ms). Danach meldet
GTK einmal `Timed out waiting for OpenGL frame of size 1024x680 (have 1280x720)`.
Auf dem i5-7200U ~10 s inkl. „reagiert nicht"-Dialog → der GTK-Hauptthread ist
blockiert. **Wichtig:** Seit Flutter 3.44 läuft Dart unter Linux auf dem
GTK-Hauptthread (`FL_UI_THREAD_POLICY_DEFAULT` = Plattform-Thread, siehe
`fl_engine.cc`), jede Dart-Rechenpause friert also auch das Fenster ein. Die
`Timed out`-Meldung selbst kostet nur 100 ms (`kCompositorRenderTimeoutMicroseconds`)
und ist Folge, nicht Ursache.

**Am 2026-10-07 in einer Cloud-Sitzung NICHT nachstellbar** (überall < 0,15 s
von „Notizen geladen" bis Bild), getestet mit nativem Build unter:
GNOME Shell 46 headless + XWayland bei 1024×768 (Fenster wird wie bei Andi
automatisch maximiert/verkleinert), Titelleiste vom Fenstermanager wie im Snap,
Ubuntu-22.04-Bibliotheken wie core22 (GTK 3.24.33, Mesa 23.2 llvmpipe,
fontconfig 2.13), 2.700–2.900 Schriften inkl. Noto/CJK/Emoji, Notizen mit Emoji
und 5×20 KB Text, AT-SPI-Bus aktiv, Google-Anmeldung mit echtem Netzverkehr,
Auto-Sync an, zwei laufende Notizzettel, ohne Mesa-Shader-Cache (+0,2 s),
veralteter fontconfig-Cache (+0,55 s, aber VOR dem ersten Fenster und
selbstheilend). → Bleibt: echte Snap-Hülle (AppArmor/seccomp, Portale,
gnome-42-2204-Bibliotheken) oder Zorin-spezifisches.

**Nächster Schritt:** `scripts/linux_threads_messen.py` auf Zorin laufen lassen
(kein root, keine Pakete nötig). Zeigt je Viertelsekunde, welcher Thread CPU
verbraucht: rechnet der Hauptthread (`*notizblock`) die ganzen 2,7 s → Profil
mit `perf`; ist er untätig → die App wartet auf etwas → `snap run --strace`.
