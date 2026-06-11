# Notizblock AW

Notizblock AW – eine schlichte, mehrsprachige Notiz-App mit Home-Screen-Widgets und Google-Drive-Synchronisierung. Verfügbar für **Android, Windows und Linux**.

## Download

- **Windows** – Microsoft Store: https://apps.microsoft.com/detail/9N8MGP7GQV4L
- **Linux** – Snap Store: https://snapcraft.io/notizblock-aw
  (Installation: `sudo snap install notizblock-aw`)
- **Android** – Google Play (derzeit geschlossener Test, Zugang auf Anfrage per E-Mail an andi-w-apps@tuta.com): https://play.google.com/store/apps/details?id=at.aw.notizblock

## Features

- ✏️ **Notizen erstellen, bearbeiten, löschen** - Einfache Textnotizen
- 📌 **Anheften** - Wichtige Notizen oben fixieren
- 🎨 **Farbauswahl** - 8 verschiedene Post-it Farben
- 🔍 **Suche** - Notizen schnell finden
- 📱 **Home-Screen Widgets** - Einzelne Notizen als Post-it auf dem Startbildschirm (Android)
- ☁️ **Google Drive Backup** - Automatische und manuelle Sicherung
- 🔄 **Plattformübergreifende Synchronisierung** - Zwischen Android, Windows und Linux
- 🌍 **Mehrsprachig** - Deutsch, Englisch, Spanisch, Französisch, Italienisch
- 🌗 **Dark Mode** - Hell, Dunkel oder System

## Systemanforderungen

- Flutter SDK 3.0.0 oder höher
- Dart SDK 3.0.0 oder höher
- Android: minSdkVersion 21 (Android 5.0)
- Windows: Windows 10 oder höher
- Linux: Ubuntu 20.04 oder kompatible Distribution

## Installation & Einrichtung

### 1. Flutter installieren

Falls noch nicht installiert: [Flutter Installation Guide](https://docs.flutter.dev/get-started/install)

### 2. Projekt klonen/kopieren

```bash
cd notizblock_app
```

### 3. Abhängigkeiten installieren

```bash
flutter pub get
```

### 4. Lokalisierung generieren

```bash
flutter gen-l10n
```

### 5. Google Cloud Projekt einrichten (für Google Drive Sync)

1. Gehe zu [Google Cloud Console](https://console.cloud.google.com)
2. Erstelle ein neues Projekt oder wähle ein bestehendes
3. Aktiviere die **Google Drive API**
4. Erstelle OAuth 2.0 Anmeldedaten:
   - **Android**: OAuth-Client-ID für Android
     - Package name: `com.notizblock.app`
     - SHA-1 Fingerprint deines Signing Keys
   - **Desktop (Windows/Linux)**: OAuth-Client-ID für Desktop-App

5. Für Android: Füge die Client-ID in `android/app/src/main/res/values/strings.xml` hinzu:
   ```xml
   <string name="default_web_client_id">DEINE_CLIENT_ID</string>
   ```

### 6. App bauen und ausführen

**Android:**
```bash
flutter run
```

**Windows:**
```bash
flutter run -d windows
```

**Linux:**
```bash
flutter run -d linux
```

## Projektstruktur

```
notizblock_app/
├── lib/
│   ├── main.dart                 # App-Einstiegspunkt
│   ├── models/
│   │   └── note.dart             # Notiz-Datenmodell
│   ├── providers/
│   │   ├── notes_provider.dart   # State Management für Notizen
│   │   └── settings_provider.dart # Einstellungen
│   ├── screens/
│   │   ├── home_screen.dart      # Hauptbildschirm
│   │   ├── note_editor_screen.dart # Notiz-Editor
│   │   └── settings_screen.dart  # Einstellungen
│   ├── services/
│   │   ├── database_service.dart # SQLite Datenbank
│   │   ├── google_drive_service.dart # Google Drive API
│   │   └── widget_service.dart   # Home Widget Service
│   ├── widgets/
│   │   ├── note_card.dart        # Notiz-Karten
│   │   └── color_picker.dart     # Farbauswahl
│   └── l10n/
│       ├── app_de.arb            # Deutsche Übersetzungen
│       └── app_en.arb            # Englische Übersetzungen
├── android/                       # Android-spezifischer Code
├── windows/                       # Windows-spezifischer Code
├── linux/                         # Linux-spezifischer Code
├── pubspec.yaml                   # Abhängigkeiten
└── l10n.yaml                      # Lokalisierungskonfiguration
```

## Widget (Android)

Das Widget zeigt eine einzelne Notiz im Post-it Stil auf dem Startbildschirm an.

**So fügst du ein Widget hinzu:**
1. Halte lange auf dem Startbildschirm
2. Wähle "Widgets"
3. Suche nach "Notizblock"
4. Ziehe das Widget auf den Startbildschirm
5. Tippe auf das Widget um eine Notiz auszuwählen

Das Widget passt sich der Größe an und zeigt Titel und Inhalt der Notiz.

## Google Drive Synchronisierung

Die App unterstützt bidirektionale Synchronisierung:

- **Manuelles Backup**: Erstellt eine Sicherung aller Notizen
- **Manuelles Restore**: Stellt Notizen aus der Sicherung wieder her
- **Synchronisieren**: Merged lokale und Cloud-Notizen (neuere Version gewinnt)
- **Auto-Sync**: Automatische Synchronisierung beim App-Start (optional)

Die Daten werden als JSON-Datei im Ordner "Notizblock Backup" in Google Drive gespeichert.

## Plattformübergreifende Nutzung

1. Installiere die App auf allen Geräten (Android, Windows, Linux)
2. Melde dich auf jedem Gerät mit demselben Google-Konto an
3. Nutze "Synchronisieren" um Notizen zwischen Geräten zu teilen

## Weitere Sprachen hinzufügen

1. Erstelle eine neue ARB-Datei in `lib/l10n/` (z.B. `app_fr.arb`)
2. Kopiere den Inhalt von `app_en.arb` und übersetze
3. Füge die Locale in `lib/providers/settings_provider.dart` hinzu
4. Führe `flutter gen-l10n` aus

## Release Build

**Android APK:**
```bash
flutter build apk --release
```

**Android App Bundle (für Play Store):**
```bash
flutter build appbundle --release
```

**Windows:**
```bash
flutter build windows --release
```

**Linux:**
```bash
flutter build linux --release
```

## Lizenz

MIT License - Frei verwendbar für persönliche und kommerzielle Projekte.

## Bekannte Einschränkungen

- Widgets sind nur auf Android verfügbar
- Google Sign-In auf Desktop erfordert manuelle OAuth-Konfiguration
- Bilder und Anhänge werden aktuell nicht unterstützt

## Beitragen

Pull Requests und Issues sind willkommen!
