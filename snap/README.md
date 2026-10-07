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

### Ursache gefunden: ~2,7 s bis die Notizen erscheinen (Zorin, Snap) – 2026-10-07

**Symptom:** Fenster nach 0,4 s, Notizen nach 15–30 ms aus der DB gelesen, das
Bild mit den Notizen aber erst ~2,9 s nach Dart-Start (i5-7200U: ~10 s inkl.
„reagiert nicht"-Dialog). Windows sofort, WSL/nativ schnell.

**Messkette (alles auf Andis Zorin-18-VM, Snap-Rev. 49):**
1. `scripts/linux_threads_messen.py`: Hauptthread `*notizblock` 0,5–3,0 s
   durchgehend 100 % eines Kerns (3,0 s CPU), Raster-Thread 50 ms → Rechenarbeit,
   kein Warten, keine Grafik. Seit Flutter 3.44 läuft Dart unter Linux auf dem
   GTK-Hauptthread (`FL_UI_THREAD_POLICY_DEFAULT`) → Fenster friert mit ein.
2. `perf record -a -g` (nach `--comm notizblock` gefiltert): **62 %
   libfontconfig.so.1.12.0, 32 % libc** (`strchr`), `libapp.so` 0,6 %.
   Aufgelöst mit den Ubuntu-Debug-Symbolen (libfontconfig1-dbgsym
   2.13.1-4.2ubuntu5, Build-ID 0bb435fd…): `FcCompareFamily` +
   `FcStrCaseWalkerNext` = Vergleich der Familiennamen beim Schriftabgleich.
   Der Snap bringt **fontconfig 2.13.1** (gnome-42-2204/core22) mit; ab 2.14
   (Zorin selbst: 2.15) ist dieser Vergleich per Hash-Tabelle viel schneller.
3. `FC_DEBUG=1` + `scripts/fc_auswertung.py`: **89 Ersatzschrift-Suchen mit je
   ~252 Familiennamen** über 2.995 Schriften (Host 2.843 + 152 aus
   gnome-platform), gesuchte Zeichen **U+000A (Zeilenumbruch) ×50, U+000D
   (Wagenrücklauf) ×39**. Zum Vergleich in der Cloud (nativ, Testdaten): 6 Suchen
   mit 90 Familien, nur für Emoji.

**Mechanismus:** Die Notizkarte (`widgets/note_card.dart`) gibt den kompletten
Notiztext inkl. `\n` bzw. `\r\n` an `Text(maxLines: …)`. Die Grundschrift
(Roboto, auf Zorin installiert; ebenso DejaVu/Liberation/Ubuntu) hat keine
Glyphen für LF/CR → Skias SkParagraph sucht per fontconfig eine Ersatzschrift.
Keine Schrift im Snap deckt LF/CR ab (lokal nur „Unifont") → die Suche schlägt
fehl, wird **nicht zwischengespeichert** und wiederholt sich je Absatz. Jede
Suche = `FcFontMatch` über ~3.000 Schriften × ~252 Familiennamen mit der alten
fontconfig → ~25–30 ms → 89 × ≈ 2,5 s auf dem Hauptthread. Langsamere CPU →
proportional länger.

**Lösung (1.31.13, 2026-10-08) – zwei Teile:**
- **Hilfsschrift `NbSteuerzeichen`** (`assets/fonts/NbSteuerzeichen.ttf`,
  640 Bytes, erzeugt von `scripts/steuerzeichen_schrift.py`): nur leere
  Glyphen (Breite 0) für U+000A und U+000D. Hängt **nur unter Linux** hinten an
  Flutters Linux-Ersatzschriften (Ubuntu, Adwaita Sans, Cantarell, …) –
  `linuxErsatzschriften()` in `lib/utils/steuerzeichen.dart`, eingebunden in
  alle drei Themes (Hauptfenster hell/dunkel, Notizzettel). Skia findet LF/CR
  dort und fragt fontconfig nicht mehr. Wirkt auch im Editor und in den
  Notizzetteln, die bei jedem Tastendruck neu umbrechen.
- **`anzeigeText()`**: `\r\n`/`\r` → `\n`, NUR in der Anzeige (Karte,
  Listenzeile, Archiv, Versionsverlauf), nie gespeichert (`modifiedAt` bleibt).
  Grund: Ein LF zählt nicht zur Zeilenhöhe, ein CR schon – über die
  Hilfsschrift würde ein CR deren Höhe in die Zeile bringen (gemessen bis
  0,8 px). Editor, Notizzettel und Lesemodus behalten den Text unverändert; dort
  erzwingt `StrutStyle(forceStrutHeight: true)` die Zeilenhöhe, die Hilfsschrift
  ändert nichts an Höhe oder Zeichenpositionen.

**Gemessen:**

| | vorher (Rev. 49) | nachher (Rev. 50, = 1.31.13) |
|---|---|---|
| Ersatzschrift-Suchen für Zeichen (FC_DEBUG, WSL-Snap) | 89 (LF ×50, CR ×39) | **0** |
| Zorin-VM: Übersicht mit Notizen nach Haus-Klick (`notizblock-aw.messen`, 9 Läufe) | 3,10–3,14 s | **0,49–0,50 s** |
| Zorin-VM: Fenster sichtbar | 0,40 s | 0,40–0,42 s |
| Übersicht Liste + Kacheln, Bildschirmfoto vorher/nachher (WSL) | – | **0 Pixel Unterschied** |

Layout-Probe (TextPainter, Roboto und Arial, mit/ohne `height`, mit
Hilfsschrift in absurden Maßen): mit vereinheitlichten Zeilenenden identische
Zeilenmaße und Zeichenpositionen; mit erzwungener Strut-Höhe auch bei CR.

**Nicht umgesetzt / offen:**
- Snap auf `base: core24` + gnome-46-2404 (fontconfig 2.15): würde jede noch
  verbleibende fontconfig-Abfrage verbilligen. Es bleiben pro Start ~3.500
  Abfragen mit je EINER Familie (Skias Auflösung von sans-serif-Aliassen) –
  um Größenordnungen billiger als die 89 großen Suchen, auf Zorin nach dem Fix
  nicht mehr spürbar. Nur angehen, falls auf langsamer Hardware noch etwas
  auffällt.
- `fl_dart_project_set_ui_thread_policy(…_RUN_ON_SEPARATE_THREAD)` hält das
  Fenster bei Rechenlast bedienbar (kein „reagiert nicht"), verkürzt aber
  nichts.
- Neue Zeichen ohne Schrift (z. B. Tabulator) lösen dieselbe Suche aus.
  Tabulator bewusst NICHT in der Hilfsschrift: Wie er heute gezeichnet wird,
  ist nicht geprüft – eine leere Glyphe der Breite 0 könnte die Darstellung
  ändern. In Andis Notizen kam er in der Messung nicht vor.

Nachmessen: `FC_DEBUG=1` + `scripts/fc_auswertung.py` (Zeile „Gesuchte
Zeichen" muss fehlen) und `scripts/linux_threads_messen.py`.

**In der Cloud nicht reproduzierbar**, weil dort (a) fontconfig 2.15 bzw. nur 90
Familien je Anfrage und (b) Unifont vorhanden war (LF-Suche erfolgreich). Dort
getestet und als Ursache ausgeschlossen: GNOME Shell 46 + XWayland 1024×768,
Titelleiste vom Fenstermanager, Ubuntu-22.04-Bibliotheken, Emoji, lange Notizen,
AT-SPI, Google-Login, Auto-Sync, Notizzettel, Shader-Cache, Schrift-Cache.
