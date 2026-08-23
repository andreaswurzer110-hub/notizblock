# Store-Upload (Google Play + Microsoft Store)

> **Seit 1.31.6 vom GitHub-Release ENTKOPPELT.** Das Release ist das **Archiv**:
> jede Version liegt dort mit AAB + Store-MSIX, damit die Artefakte gesichert
> sind – unabhängig von jedem Store. Der Upload nach Play läuft **nur noch
> manuell** (Actions → Store-Upload → Run workflow, Tag angeben). Vorher startete
> jedes veröffentlichte Release sofort den Play-Upload; man konnte also nichts
> archivieren, ohne zugleich zu veröffentlichen (Notlösung waren `test-*`-Tags).
> Die Freigabe in Play (geschlossener Test → Produktion) macht Andi in der
> Console selbst.

Der Workflow [`.github/workflows/store-upload.yml`](../.github/workflows/store-upload.yml)
lädt die an ein **GitHub-Release** angehängten Artefakte hoch:

| Store | Artefakt | Tool |
|---|---|---|
| Google Play | `Notizblock-<ver>.aab` | `r0adkll/upload-google-play` |
| Microsoft Store | `Notizblock-<ver>-Store.msix` | `microsoft/store-submission` |

**Signierung bleibt lokal** – du baust AAB + Store-MSIX wie bisher selbst (Upload-
Keystore bzw. Store-Identität müssen NICHT als Secret rein). Nur die *Upload-
Zugangsdaten* der Stores kommen als GitHub-Secrets dazu.

Ohne die jeweiligen Secrets wird der Store **übersprungen** (kein Fehlschlag) →
Play und Store lassen sich unabhängig scharf schalten.

---

## So läuft ein Release danach ab

**Der bequeme Weg (seit 2026-08-23):** `Release.ps1` im Projektroot macht alles
in einem Durchlauf – bauen → lokal als MSIX installieren → Release anlegen.
Vorher nur die Version in `app_info.dart` + `pubspec.yaml` (`version:` **und**
`msix_version:`) hochzählen.

```powershell
powershell -ExecutionPolicy Bypass -File Release.ps1
```

Das Skript bricht ab, wenn das Arbeitsverzeichnis nicht sauber oder nicht
gepusht ist – aus gutem Grund, siehe die Warnung unten zur Tag-Reihenfolge.

Von Hand geht es weiterhin so:

1. Lokal bauen (Version in `app_info.dart` + `pubspec.yaml`/`msix_version`):
   - `flutter build appbundle --release --build-name=<ver> --build-number=<code>`
   - Store-MSIX (`dart run msix:create --store …`)
2. Release mit den Dateien anlegen:
   ```powershell
   gh release create v<ver> "<pfad>\Notizblock-<ver>.aab" "<pfad>\Notizblock-<ver>-Store.msix" `
     --title "v<ver>" --notes "Release <ver>"
   ```
   Existiert der Tag schon (z.B. weil er fürs Snap-Release vorab gepusht wurde),
   legt `gh release create v<ver> …` trotzdem das Release **am vorhandenen Tag** an.
   Das AAB NICHT auf `E:` ablegen (Ansage Andi) – direkt aus
   `build/app/outputs/bundle/release/` oder aus einem Temp-Ordner anhängen.
3. **Das Release löst automatisch aus:** AAB → Google Play **interner Test**
   (`store-upload.yml`) und Snap → Kanal **edge** (`snap.yml`). Beides sind
   Testkanäle. Die Freigabe nach außen (geschlossener Test → Produktion bei
   Play, edge → stable beim Snap) macht Andi weiterhin von Hand.
   Anderer Play-Track bei Bedarf: **Actions → Store-Upload → Run workflow**.
4. **MS Store:** manuell in Partner Center (siehe Sackgasse unten).

> ⚠️ **Reihenfolge:** Bei einem `release`-Event liest GitHub den Workflow aus dem
> Commit, auf den der **Tag** zeigt – nicht aus `main`. Also immer: ändern →
> committen → pushen → **dann** taggen/releasen. Genau daran ist 1.31.6 schon
> einmal gescheitert (das Archiv-Release feuerte den alten Trigger doch noch).

> Upload ≠ Veröffentlichung: Play-Review bzw. Store-Zertifizierung laufen wie
> immer dazwischen. Automatisiert ist nur der Upload/die Einreichung.

---

## Einmalige Einrichtung

### A) Google Play  →  Secret `PLAY_SERVICE_ACCOUNT_JSON`

1. **Google Cloud Console** (console.cloud.google.com): Projekt wählen/anlegen →
   *APIs & Dienste* → **Google Play Android Developer API** aktivieren.
2. *IAM & Verwaltung → Dienstkonten* → **Dienstkonto erstellen** (z.B. `play-ci`).
   → beim erstellten Konto *Schlüssel → Schlüssel hinzufügen → JSON* → Datei laden.
3. **Play Console** (play.google.com/console) → *Nutzer und Berechtigungen* bzw.
   *Einrichtung → API-Zugriff*: das Google-Cloud-Projekt verknüpfen und dem
   Dienstkonto Zugriff geben. Berechtigung mind. **„Releases für Testtracks
   verwalten"** (für `internal`); für `production` zusätzlich „Produktionsreleases
   verwalten". (Wirkt teils erst nach einigen Minuten.)
4. **GitHub** → Repo *Settings → Secrets and variables → Actions → New repository
   secret*: Name `PLAY_SERVICE_ACCOUNT_JSON`, Wert = **kompletter JSON-Inhalt** der
   Schlüsseldatei.

> Voraussetzung „erste Version manuell" ist erfüllt (Play läuft bereits). Der
> Default-Track ist `internal`; beim manuellen Lauf per `play_track` änderbar.

### B) Microsoft Store  →  Secrets `STORE_*`

> ⚠️ **NICHT machbar mit einem „Einzelpersonen"-Store-Konto (real getestet 2026-06-29, Sackgasse).**
> Die Store-Submission-API verlangt, eine **Azure-AD-App** in Partner Center unter
> *Kontoeinstellungen → Benutzerverwaltung* mit **Manager-Rolle** zu verknüpfen.
> Bei **Kontotyp „Einzelperson"** bietet Partner Center diese Verknüpfung GAR NICHT
> an (nur „Neue Benutzer erstellen", kein „Azure AD-Anwendungen"). Selbst mit
> angelegtem Entra-Verzeichnis + App-Registrierung + Global-Admin schlägt die API
> dann mit 403 fehl. → **MS Store für dieses Konto manuell hochladen** (Store-MSIX
> liegt auf `E:`). Die Schritte unten gelten nur für ein **Unternehmenskonto**.
> NICHT erneut versuchen, solange das Konto „Einzelperson" ist.

1. **Partner Center** → *Account settings → User management →
   **Azure AD applications*** → Azure-AD-App hinzufügen/verknüpfen und ihr eine
   Rolle (mind. *Developer/Manager*) geben. Daraus: **Tenant-ID**, **Client-ID**;
   beim App-Eintrag ein **Client-Secret (Schlüssel)** erzeugen.
2. **Seller-ID**: Partner Center → *Account settings* (Account-/Verkäufer-ID).
   **Product-ID**: die Store-ID dieser App = `9N8MGP7GQV4L`.
3. **GitHub-Secrets** anlegen:
   | Secret | Wert |
   |---|---|
   | `STORE_TENANT_ID` | Azure-AD Verzeichnis-(Tenant-)ID |
   | `STORE_CLIENT_ID` | Azure-AD Anwendungs-(Client-)ID |
   | `STORE_CLIENT_SECRET` | erzeugtes Client-Secret |
   | `STORE_SELLER_ID` | Partner-Center Seller-/Account-ID |
   | `STORE_PRODUCT_ID` | `9N8MGP7GQV4L` |

#### Erstlauf prüfen (Microsoft Store)
Die Store-Submission-API ist fummeliger als Play. Beim ersten scharfen Lauf gegen
das README von `microsoft/store-submission` verifizieren:
- ob `command: publish` allein reicht oder vorher ein `command: update`
  (mit Paket-Pfad/`product-update`-JSON) nötig ist, um das neue MSIX an die
  Submission zu hängen;
- ob die Paketdatei der Action über einen Pfad-Eingang übergeben werden muss
  (dann den heruntergeladenen `dist/*-Store.msix`-Pfad ergänzen).
Alternative, falls die Action zickt: der `msstore`-CLI (Microsoft Store Developer
CLI) mit `msstore reconfigure …` + `msstore publish <msix> --id <ProductId>`.
Hinweis: Partner Center erlaubt **nur eine** Submission gleichzeitig in
Zertifizierung; eine laufende erst durchlassen/abbrechen.

---

## Voraussetzungen, die schon erfüllt sind
- Play: App existiert (1.25.3), versionCode steigt streng (Schema in `pubspec.yaml`).
- Store: App existiert (1.25.5.0), MSIX-Identität `AndreasWurzer.NotizblockAW`,
  Revision `.0` (Store-Pflicht) – wird vom `--store`-Build so erzeugt.
