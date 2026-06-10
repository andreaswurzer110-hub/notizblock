# Notizblock → Flathub (Flatpak)

Packaging-Dateien für die Veröffentlichung im Linux-App-Store (Flathub).
**Bauen und Testen geht ausschließlich auf einem Linux-Host** (Flatpak ist
nicht von Windows aus baubar).

## Dateien hier

| Datei | Zweck |
|-------|-------|
| `io.github.andreaswurzer110_hub.Notizblock.yml` | Flatpak-Manifest (Build-Rezept) |
| `io.github.andreaswurzer110_hub.Notizblock.metainfo.xml` | AppStream-Metadaten = Store-Eintrag |
| `io.github.andreaswurzer110_hub.Notizblock.desktop` | Desktop-Eintrag |
| `google_drive_config.dart` | Dedizierter, bewusst öffentlicher Linux-OAuth-Client (wird in den Build kopiert) |
| `screenshots/` | **TODO** – mind. 1 Screenshot-PNG hier ablegen |

## App-ID

`io.github.andreaswurzer110_hub.Notizblock` – das `io.github.*`-Schema, weil die
Domain `aw.at` nicht uns gehört. Verifizierbar über die bestehende GitHub-Pages
(`andreaswurzer110-hub.github.io`); der Bindestrich im User wird zu `_`.

Die App-ID ist **nur im Flatpak-Build** anders: `linux/CMakeLists.txt` liest sie
aus der Env-Variable `NOTIZBLOCK_APP_ID` (Default `at.aw.notizblock` für Windows /
manuelle Linux-Installation). Das Manifest exportiert die io.github-ID → GTK
application-id, Fenster-Icon und Taskleisten-Gruppierung passen zur Store-App.

## Voraussetzungen (Linux, einmalig)

```bash
sudo apt install flatpak flatpak-builder
flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub org.gnome.Platform//48 org.gnome.Sdk//48
# Offline-Vendoring-Tool:
git clone https://github.com/TheAppgineer/flatpak-flutter.git
```
> Runtime-Version (`48`) ggf. auf die aktuelle stabile GNOME-Runtime anheben –
> dann auch im Manifest (`runtime-version`) und oben angleichen.

## Schritt 1 – Repo öffentlich + Release-Tag

Flathub baut **aus dem Quellcode**, also muss `github.com/andreaswurzer110-hub/notizblock`
**öffentlich** sein, und es braucht einen festen Tag/Commit (kein Branch):

```bash
git tag v1.25.0
git push origin v1.25.0
```
> Hinweis: Mit dem öffentlichen Repo wird der dedizierte Linux-OAuth-Client in
> `flatpak/google_drive_config.dart` öffentlich – das ist **so gewollt** (separater,
> sperr-/rotierbarer Client, getrennt von Windows/Android).

## Schritt 2 – Offline-Sources erzeugen (das eigentliche Flutter-Problem)

Flathub-Builds haben **kein Netz**. `flatpak-flutter` löst das, indem es das
Flutter-SDK + alle pub-Pakete vorab als Sources mit sha256 auflistet:

```bash
cd flatpak-flutter
python3 flatpak-flutter.py \
  --app-module notizblock \
  ../notizblock/flatpak/io.github.andreaswurzer110_hub.Notizblock.yml
```
Ergebnis: `flutter-sdk.json` und `pubspec-sources.json` (und ein offline-fähiges
Manifest). Diese Dateien neben das Manifest legen – sie sind im Manifest bereits
als `sources` referenziert (aktuell als TODO-Platzhalter).

> Exakte Aufrufsyntax variiert je nach flatpak-flutter-Version – siehe dessen
> README. Alternative: `flatpak-builder-tools`’ Flutter/pub-Generator. Kern bleibt:
> SDK + pub-cache vorab vendoren.

## Schritt 3 – Lokal bauen, installieren, testen

```bash
cd notizblock/flatpak
flatpak-builder --user --install --force-clean build-dir \
  io.github.andreaswurzer110_hub.Notizblock.yml
flatpak run io.github.andreaswurzer110_hub.Notizblock
```

**Testcheckliste (das sind die App-spezifischen Risiken):**
- [ ] DB legt unter `~/.var/app/io.github.andreaswurzer110_hub.Notizblock/` an
- [ ] Drive-Login: Browser öffnet (OpenURI-Portal), Loopback `127.0.0.1` empfängt Token
- [ ] Sync läuft beidseitig
- [ ] Sticky-Fenster (eigene Prozesse) öffnen via Rechtsklick → „anheften"
- [ ] Sticky-**Position/Größe** bleibt nach Neustart erhalten (X11/XWayland)
- [ ] Taskleiste gruppiert Haupt- + Sticky-Fenster unter EINEM Eintrag
- [ ] Autostart-Schalter (Einstellungen): Dialog des Background-Portals erscheint,
      nach Re-Login startet die App mit angehefteten Widgets

## Schritt 4 – Validieren (vor dem PR)

```bash
appstreamcli validate io.github.andreaswurzer110_hub.Notizblock.metainfo.xml
desktop-file-validate io.github.andreaswurzer110_hub.Notizblock.desktop
# Flathub-Linter (via flatpak):
flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest \
  io.github.andreaswurzer110_hub.Notizblock.yml
```

## Schritt 5 – Bei Flathub einreichen

1. `github.com/flathub/flathub` forken.
2. Neuer Branch `new-pr` (genau dieser Name ist Flathub-Konvention).
3. Manifest + die generierten Source-JSONs + `.desktop` + `.metainfo.xml`
   (+ ggf. `google_drive_config.dart`) hinzufügen, committen, pushen.
4. PR gegen `flathub/flathub` Branch `new-pr` öffnen → Review.
5. Nach Merge bekommst du ein eigenes Repo `flathub/io.github.andreaswurzer110_hub.Notizblock`.
   Beim ersten Veröffentlichen die App-ID auf der Flathub-Website verifizieren
   (Login mit dem GitHub-Account `andreaswurzer110-hub`).

## Schritt 6 – Updates ausliefern

**Automatisiert über CI – siehe [`RELEASING.md`](RELEASING.md).** Kurzfassung:
Version + `<release>` in der MetaInfo bumpen, Tag `vX.Y.Z` pushen → die
GitHub-Actions-Pipeline `.github/workflows/flathub-update.yml` regeneriert die
Offline-Sources, baut testweise und pusht Manifest + `generated/` ins Flathub-Repo
→ Flathubs Buildbot veröffentlicht. Damit von Windows aus auslösbar, kein
Linux-Host nötig (außer bei größeren GUI-Änderungen zum Durchklicken).

## Offene Punkte (vor dem PR erledigen)

- **Lizenz:** `project_license` in der MetaInfo steht auf Platzhalter `MIT`. An die
  tatsächliche Lizenz anpassen **und** eine `LICENSE`-Datei ins App-Repo legen.
  (Build-from-source auf Flathub setzt eine FOSS-Lizenz voraus.)
- **Screenshots:** mind. ein erreichbares PNG (URL in der MetaInfo). Vorschlag:
  `flatpak/screenshots/overview.png` ins Repo, URL zeigt schon dorthin.
- **Runtime-Version** auf den aktuellen GNOME-Stand bringen.
- **Release-Tag** muss existieren (Schritt 1).

## Trade-offs / Notizen

- **X11 statt fallback-x11:** Die App braucht absolute Fensterpositionen (Stickys)
  und erzwingt XWayland → `--socket=x11` muss in jeder Session greifen. Etwas
  breiterer X11-Zugriff als ideal, aber für die Positionslogik nötig.
- **Eigener Datenpfad:** Flatpak-Daten liegen unter `~/.var/app/<id>/`, getrennt
  von einer manuellen `~/.local/share/notizblock`-Installation. Kein Datenverlust,
  aber zwei getrennte Stände – Abgleich läuft über Drive-Sync (einmal einloggen).
- **Autostart:** im Sandbox via XDG-Background-Portal (kein Schreiben in
  `~/.config/autostart`), umgesetzt in `lib/services/autostart_service.dart`.
