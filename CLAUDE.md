# CLAUDE.md – Notizblock App

> Projektkontext für Claude Code. Kurz halten – wird in jeder Session komplett geladen.
> Wenn Claude etwas falsch macht und ich es korrigiere: hier eine Regel ergänzen, damit der Fehler nicht wiederkommt.

## Was das ist

Plattformübergreifende Notizblock-App in **Flutter (Dart)**.
Eine Codebasis für **Android, Windows und Linux**.

Kernfunktionen:
- Notiz-Typen: Text (kein Markdown/keine Bilder), Autopool-Tabelle (Geräteliste), Einkaufsliste (Artikel mit Menge + Abhaken)
- Notizen in Ordner sortieren (Seitenmenü/Drawer-Filter); optionales Android-Ordner-Widget öffnet die App direkt im Ordner
- Post-it-Style Widgets: auf Android Homescreen-Widgets (Notiz + Ordner), auf Windows „Sticky Notes"-Fenster
- Schlichtes Design, abgerundete Ecken
- Mehrsprachig, **Deutsch als Standard**, Sprache umschaltbar
- Google-Drive-Backup/Sync für plattformübergreifenden Abgleich

## Tech-Stack

- **State:** provider
- **Lokale DB:** sqflite (+ sqflite_common_ffi für Windows/Linux), path, path_provider
- **Google Drive:** googleapis, googleapis_auth, google_sign_in, http
- **Widgets (Android):** home_widget
- **Desktop-Fenster:** window_manager (Position/Größe der Sticky-Notes), url_launcher (OAuth-Browser)
- **UI:** flutter_staggered_grid_view, Material Design
- **Sonstiges:** uuid, intl, shared_preferences, flutter_localizations

## Architektur

```
lib/
  models/      # Note-Datenklasse
  providers/   # State (provider)
  screens/     # Bildschirme/Seiten
  widgets/     # wiederverwendbare UI-Komponenten
  services/    # database_service.dart, google_drive_service.dart, …
  l10n/        # Lokalisierung (de = Standard)
```

**Note-Model:** id (uuid), title, content, createdAt, modifiedAt, color (Default `#FFFDE7`), isPinned, isArchived, `type` (`text`/`autopool`/`shopping`), `autopoolData` (generisches Struktur-JSON, von autopool UND shopping genutzt), `folder` (Ordnername, leer = keiner; wird mit der Notiz synchronisiert).
**DatabaseService:** Singleton; auf Windows/Linux `sqfliteFfiInit()` + `databaseFactoryFfi`; Tabelle `notes` mit Indizes auf `modifiedAt` und `isPinned`. DB-Version aktuell **5** → Schema-Änderungen über `_onUpgrade` migrieren, nicht hart neu anlegen (v2 = `deletions`-Tabelle; v3 = Spalten `type`+`autopoolData`; v4 = Spalte `folder`; v5 = `sync_base`-Tabelle für die Konflikt-Erkennung). **DB-Speicherort:** Desktop (Windows/Linux) = `getApplicationSupportDirectory()` (`%APPDATA%\com.example\notizblock\` bzw. `~/.local/share/…`, neben `sticky_state/`); Android/iOS = `getApplicationDocumentsDirectory()` (dort liest das Home-Widget `notes.json`). Früher lag die DB auf Desktop im Dokumente-Ordner → einmalige Migration via `_migrateDbFromDocuments` (kopiert DB + WAL/SHM/Journal, falls am neuen Ort noch keine existiert).

## App-Icon

Design: **blaue Kachel (`#1E88E5`) + gelber Notizblock (`#FFEB3B`) + roter Stift**. Quelle: `assets/icon/icon_full.png` (Voll-Icon) + `assets/icon/icon_foreground.png` (transparenter Vordergrund für Android-Adaptive); beide via PowerShell/GDI+ erzeugt. Eingebunden via `flutter_launcher_icons` (Config in `pubspec.yaml`): Android (legacy mipmaps + adaptive, Hintergrund `#1E88E5`). Für **Windows** wird zusätzlich eine **Multi-Size-`.ico`** (16–256 px) per Skript nach `windows/runner/resources/app_icon.ico` geschrieben (flutter_launcher_icons macht nur eine Größe → kleine Icons sonst leer/„weißer Zettel").
- **Stolpersteine beim Icon:** (1) CMake verfolgt `app_icon.ico` nicht zuverlässig → nach Icon-Wechsel ggf. `flutter clean` vor dem Windows-Build, sonst bleibt das alte Icon eingebettet. Eingebettetes Icon prüfen via `[System.Drawing.Icon]::ExtractAssociatedIcon(exe)`. (2) Windows cached Icons → nach Wechsel Icon-Cache leeren (`IconCache.db` + `Explorer\iconcache_*.db` löschen, Explorer neu starten), sonst zeigt die Verknüpfung weiter das alte/leere Icon.

## Befehle

```powershell
flutter pub get              # Abhängigkeiten
flutter analyze              # Statische Analyse – vor jedem Commit
flutter run -d windows       # Lokal testen (Windows)
flutter build apk --release  # Android
flutter build windows --release

# Windows-Installer (Setup.exe) bauen – baut Release + bündelt VC++-Runtime,
# kompiliert via Inno Setup nach installer\output\Notizblock-Setup-<ver>.exe:
powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1
#   -SkipBuild      # nutzt vorhandenen Release-Build (kein Neu-Build)
#   -Version 1.2.0  # Versionsnummer für diesen Lauf überschreiben
```

Bei verkeiltem `flutter clean` (Datei in Verwendung): laufende `dart.exe`/App schließen, dann erneut.

## Konventionen

- Code-Kommentare und UI-Texte auf **Deutsch**.
- UI-Strings nicht hartkodieren → über l10n (de zuerst), damit Mehrsprachigkeit nicht bricht. **WICHTIG – `SettingsProvider.supportedLocales` MUSS zu den vorhandenen `lib/l10n/app_<locale>.arb` passen:** Bietet der Sprachwähler eine Locale ohne eigene `.arb` an, ist `AppLocalizations.of(context)` für sie **null** → `!`-Zugriff wirft → Haupt-/Einstellungsbildschirm wird **grau und unbedienbar** (war real ein Bug bis 1.25.8.0: es/fr/it wurden angeboten, aber nur de/en hatten Übersetzungen). Aktuell vollständig: de, en, es, fr, it. Neue Sprache = `app_<locale>.arb` (alle Keys) anlegen, `flutter gen-l10n`, in `supportedLocales` eintragen. Geschützt durch `test/l10n_locales_test.dart` (jede angebotene Locale muss laden). Apostrophe in fr/it als typografisches `’` schreiben (das straight `'` ist das ICU-Quote-Zeichen und kann in Strings MIT Platzhaltern Text verschlucken).
- Plattformabhängigen Code (Desktop vs. Android) sauber über `Platform.is…` bzw. bedingte Importe kapseln.

## Bekannte Stolpersteine → `docs/archiv/stolpersteine.md`

Rund 80 ausgemessene Fallstricke stehen **nicht mehr hier**, sondern in
`docs/archiv/stolpersteine.md` (83 KB). Diese Datei wird komplett in jede Session
geladen – deshalb nur der Wegweiser. **Vor Arbeit an einem dieser Bereiche dort
nachschlagen, nicht neu ausprobieren:**

- **Sync / Google Drive** – Delta-Sync-Layout, `last_sync_timestamp` = Sync-**Start**,
  Android-Access-Token lebt nur ~1 h, Konflikterkennung + Versionsverlauf, Uhr-Versatz,
  `modifiedAt` nie ohne echte Änderung bumpen, `ConflictStore` als Datei
- **DB & Prozessgrenzen** – `sqlite3.dll`-Laden, `busy_timeout` + WAL sind Pflicht,
  **kein `shared_preferences` für prozessübergreifende Writes**, `PrefsRepairService`
- **Widgets & Sticky Notes** – Android `home_widget` + Ordner-Widget, Windows-Stickys als
  eigene Prozesse, Fensterlage bei minimiertem Fenster nie speichern
- **Editor & UI** – Tipp-Entprellung, Schreibmarke bei Fremdänderungen, `SheetBody`,
  `DialogBody`, Mehrfachauswahl, PDF-Text braucht `TextOverflow.span`
- **Notiz-Typen** – Autopool-Format abwärtskompatibel halten, Einkaufsliste, Ordner (DB v4)
- **Windows/Linux-Betrieb** – Autostart, Neustart nach Update, MSIX-Reinstall,
  **nie die Build-Exe starten**, VS-C++-Workload, warme Hauptinstanz (Linux)
- **Packaging & Release** – Inno-Installer, Snap, Flatpak, `store-upload.yml`,
  Workflow-Änderungen greifen erst für **spätere** Tags, GitHub-Release ≠ Store-Upload
- **Sprachen & Datum** – 13 Sprachen, `utils/date_display.dart` statt `DateFormat(…,'de')`

Vollständige alte Fassung dieser Datei: `docs/archiv/CLAUDE.md.vollstaendig-2026-08-23.md`

## Offen fürs nächste Release

- **Linux/Snap: „In Datei drucken" über den System-Druckdialog scheitert** (gemeldet
  von Andi am 2026-08-23 auf Zorin, Snap-Build). Symptom: Der GTK-Speichern-Dialog
  kann den Zielordner nicht öffnen — `Error opening directory '/home/andi/Dokumente':
  Permission denied` — und die App meldet danach
  `Export fehlgeschlagen: Fehler beim Öffnen der Datei »/home/andi/Dokumente/Ausgabe.pdf«:
  Permission denied`.
  **Wichtig zur Abgrenzung:** Der *eigene* PDF-Export der App (Menü „Exportieren")
  funktioniert auf Linux normal — nur der Weg über den **System-Druckdialog**
  bricht ab. Deshalb ist es Andi lange nicht aufgefallen. Kein kritischer Fehler,
  aber beim nächsten Release beheben.
  **Erste Schritte zur Eingrenzung** (noch nicht gemacht, nicht raten):
  `snap connections notizblock-aw` → ist `home` verbunden? Dann in der Sandbox
  gegenprüfen (`snap run --shell notizblock-aw`, dort `ls /home/andi/Dokumente`),
  und testen, ob ein anderes Ziel (z. B. `~/Downloads`) klappt. Falls es an der
  strikten Confinement-Grenze liegt, ist der saubere Weg der
  xdg-desktop-portal-Dialog statt des GTK-Choosers **innerhalb** der Sandbox —
  vergleichbar zum zenity-Problem in [[pdf-zu-bild-projekt]].

## Anpassen / prüfen ‹von Andi›

- **applicationId / Package-Name:** **`at.aw.notizblock`** (finale Play-Store-Identität, in `android/app/build.gradle.kts`). Interner Kotlin-Namespace bleibt bewusst `com.example.notizblock` (die 3 Klassen unter `kotlin/com/example/notizblock/`) – für OAuth/Store zählt nur die applicationId.
- **Android Google-OAuth:** Cloud-Projekt `445597891658`, OAuth-Client Typ „Android" mit Paketname `at.aw.notizblock` + Debug-SHA-1 `61:7D:C8:19:42:12:32:FC:71:B4:48:16:26:B7:BD:BC:FE:D5:F0:60`. `google_sign_in` matcht über Paketname+SHA-1, KEIN client_id/secret in der App nötig. **Für Release/Play Store:** zusätzlich den Play-App-Signing-SHA-1 als weiteren Android-OAuth-Client (gleicher Paketname) anlegen (ein Android-Client = 1 Paket + 1 SHA-1, mehrere Zertifikate = mehrere Clients).
- **Play-Store-Onboarding (Internal Testing, kein 12-Tester-Zwang):** Upload-Keystore unter `C:\Users\awurz\keys\upload-keystore.jks` (Alias `upload`, Passwort nur in Andis Passwort-Manager – NICHT in Git/Docs), verdrahtet über `android/key.properties` (gitignored; build.gradle.kts fällt ohne die Datei auf Debug-Keys zurück). Upload-Key-SHA-1: `E3:C5:A3:8B:B7:99:10:1D:32:33:ED:D7:81:2C:4B:B3:AB:5B:62:CD`. Release: `flutter build appbundle --release` → AAB unter `build/app/outputs/bundle/release/app-release.aab` (Play will AAB, nicht APK). `versionCode` = die Build-Nummer `+N` in pubspec `version:` (eine reine Ganzzahl, **muss** pro Upload streng steigen, unabhängig vom Versionsnamen – kann also nicht „25.3" sein). **Schema ab 1.25.3:** `major*10000 + minor*100 + patch` → 1.25.3 = `12503`, 1.25.4 = `12504`, 1.26.0 = `12600` (so spiegelt der Code die Version wider). Davor lief eine fortlaufende Zählung (…, 25, 26); der Sprung auf 12503 ist ok, weil nur „größer als zuletzt" zählt. **Play App Signing:** Play re-signt mit eigenem Schlüssel (Zertifikat `CN=Android, O=Google Inc.`) → für den Login im Play-Build zählt der **Play-App-Signing-SHA-1** (Play Console → Test & Veröffentlichung → Einrichtung → App-Integrität), nicht der Upload-Key-SHA-1 (den nutzt kein installiertes App). Konkreter Play-App-Signing-SHA-1 dieser App: `83:7D:6A:A1:31:A2:2C:3D:06:93:3E:45:E3:26:7D:43:96:21:95:7C` (per `apksigner verify --print-certs` aus der vom Store gezogenen APK ausgelesen). **WICHTIG – Symptom bei fehlender/falscher Registrierung:** `PlatformException(..., UnregisteredOnApiConsole, ...)` beim ersten Drive-Request („Fehler beim Ordner erstellen" / „Sync Fehler"). Die Basis-Anmeldung (E-Mail/Profil) klappt trotzdem (lenient), nur der Drive-Scope-Token wird verweigert → Sync rot/durchgestrichen, sieht fälschlich nach „ausgeloggt" aus. Fix ist reine Cloud-Config: Android-OAuth-Client mit Paketname `at.aw.notizblock` + genau diesem SHA-1 anlegen (SHA-1 eines bestehenden Android-Clients ist nicht editierbar → ggf. neuen Client anlegen). NICHT mit dem 1-h-Access-Token-Bug verwechseln. Datenschutzerklärung (Play-Pflicht): https://andreaswurzer110-hub.github.io/notizblock-privacy/ (eigenes öffentliches Repo `notizblock-privacy`, Pages-Quelle Branch master/root; Verantwortlicher „Andreas Wurzer", Kontakt-E-Mail `andi-w-apps@tuta.com`). Scope `drive.file` = non-sensitive → keine Google-OAuth-Verifizierung nötig.
- Pfad-Hinweis: Projekt liegt verschachtelt unter `…\notizblock_app\notizblock_app` (innerer Ordner mit `pubspec.yaml` ist das Projektroot – die `CLAUDE.md` gehört dorthin).
