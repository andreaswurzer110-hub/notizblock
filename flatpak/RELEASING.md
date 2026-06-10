# Notizblock auf Flathub aktualisieren (von Windows aus)

Ziel: Routine-Updates komplett von Windows auslösen, ohne die Linux-/Zorin-Kiste.
Der Linux-only-Teil (Offline-Sources + Flatpak-Build) läuft in GitHub Actions auf
einem Ubuntu-Runner; Flathubs Buildbot veröffentlicht danach selbst.

## Der laufende Release-Ablauf (von Windows)

1. Code-Änderungen wie immer machen.
2. **Version bumpen** in `pubspec.yaml` (`version: X.Y.Z+N`).
3. **Release-Notes** in `flatpak/io.github.andreaswurzer110_hub.Notizblock.metainfo.xml`:
   neuen `<release version="X.Y.Z" date="YYYY-MM-DD">`-Eintrag oben einfügen.
4. Committen, **Tag pushen**:
   ```powershell
   git add -A; git commit -m "X.Y.Z: <kurz>"
   git tag vX.Y.Z
   git push origin main --tags
   ```
5. Fertig. Der Workflow **Flathub-Update** (`.github/workflows/flathub-update.yml`)
   läuft auf den Tag an: regeneriert die Offline-Sources, baut testweise, und
   pusht Manifest + `generated/` ins Flathub-Repo → Buildbot baut & veröffentlicht.
   Die Software-Center der Nutzer (GNOME Software / Discover / Zorin) ziehen das
   Update automatisch.

Status/Logs des Laufs: GitHub → Actions → „Flathub-Update". Manuell auslösbar
über „Run workflow" (mit optionalem Tag).

## Einmaliges Setup (nach Merge von Flathub-PR #8944)

1. **Flathub-Repo** existiert dann: `flathub/io.github.andreaswurzer110_hub.Notizblock`.
2. **Schreib-Token anlegen:** GitHub → Settings → Developer settings →
   **Fine-grained PAT**, Resource owner `flathub`, nur dieses eine Repo,
   Permission **Contents: Read and write**. (Falls fine-grained für die
   flathub-Org nicht wählbar ist: klassischer PAT mit Scope `repo`.)
3. Im **App-Repo** (`andreaswurzer110-hub/notizblock`) → Settings → Secrets and
   variables → Actions → **New repository secret**: Name `FLATHUB_TOKEN`, Wert =
   der Token.
4. App-ID einmalig auf der Flathub-Website verifizieren (Login mit dem
   GitHub-Account `andreaswurzer110-hub`).

## Beim allerersten CI-Lauf zu verifizieren

Die Pipeline ist ein Erstentwurf – drei Stellen können je nach Umgebung haken
(im Workflow als `[V1]/[V2]/[V3]` markiert):

- **[V1] Container-Image:** `bilelmoussaoui/flatpak-github-actions:gnome-49` muss
  als Image existieren. Falls nicht: aktuell verfügbaren `gnome-XX`-Tag nehmen
  (und `runtime-version` im Manifest entsprechend).
- **[V2] flatpak-flutter-CLI:** Die Zeile
  `python3 /opt/flatpak-flutter/flatpak-flutter.py flatpak-flutter.yml` muss exakt
  dem entsprechen, was auf Zorin funktioniert hat. Falls dort eine andere Syntax
  lief (z.B. mit `--app-module`), die hier eintragen.
- **[V3] Flathub-Default-Branch:** meist `master` (im Workflow gesetzt). Falls das
  Flathub-Repo `main` nutzt → `FLATHUB_BRANCH` anpassen.

Tipp: vor dem ersten echten Release den Workflow per „Run workflow" mit dem schon
existierenden Tag `v1.25.0` testen – baut/pusht dasselbe wie der Erst-PR und deckt
[V1]–[V3] auf, ohne ein neues Release zu „verbrennen".

## Wann doch noch Linux/Zorin nötig ist

- **Größere GUI-Änderungen** (Sticky-Positionen, Portale, Drive-Login): Der
  CI-Build verifiziert nur *Baubarkeit*, nicht das Verhalten. Solche Releases
  vorher einmal auf Zorin durchklicken (Checkliste in `README.md`).
- **Berechtigungs-/`finish-args`-Änderungen:** lösen bei Flathub ein erneutes
  Review aus (kein reiner Auto-Build).

## Wie es technisch zusammenhängt (Kurz)

- Zwei Repos: **App-Repo** (Code, Tags, MetaInfo) + **Flathub-Repo** (nur
  Manifest + `generated/`). Die CI synct Letzteres.
- Der Build im Flathub-Repo zieht Code via Git-Source (Tag+Commit) aus dem
  App-Repo; `metainfo`/`desktop`/`icon`/`google_drive_config.dart` kommen aus
  dieser Git-Source, nur `generated/` + Manifest liegen im Flathub-Repo.
- Quelle der Wahrheit fürs Manifest ist die Vorlage `flatpak/flatpak-flutter.yml`;
  daraus generiert flatpak-flutter `io.github…yml` + `generated/`. Lokal zeigt die
  Vorlage auf `file://` – die CI biegt das je Lauf auf die GitHub-URL + Tag um.
