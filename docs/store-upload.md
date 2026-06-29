# Automatischer Store-Upload (Google Play + Microsoft Store)

Der Workflow [`.github/workflows/store-upload.yml`](../.github/workflows/store-upload.yml)
lädt die an ein **GitHub-Release** angehängten Artefakte automatisch hoch:

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

1. Lokal bauen wie gehabt (Version in `app_info.dart` + `pubspec.yaml`/`msix_version`):
   - `flutter build appbundle --release --build-name=<ver> --build-number=<code>` → AAB nach `E:\`
   - Store-MSIX (`dart run msix:create --store …`) → `E:\…-Store.msix`
2. Release mit beiden Dateien anlegen (löst zugleich den Snap-stable-Build aus):
   ```powershell
   gh release create v<ver> "E:\Notizblock-<ver>.aab" "E:\Notizblock-<ver>-Store.msix" `
     --title "v<ver>" --notes "Release <ver>"
   ```
   Existiert der Tag schon (z.B. weil er fürs Snap-Release vorab gepusht wurde),
   legt `gh release create v<ver> …` trotzdem das Release **am vorhandenen Tag** an.
3. Fertig – der Workflow lädt zu Play (Track `internal`) und zum MS Store hoch.
   Manuell nachstoßen geht über **Actions → Store-Upload → Run workflow** (Tag angeben).

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
