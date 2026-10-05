# Store-Eintrag Google Play (de-DE)

Quelle für `scripts/play_listing.py` (überträgt Texte und Bilder per
Play-Developer-API). Bilder liegen unter `store/`; wie sie entstehen, steht
unten. Überarbeitet am 2026-10-05 (vorher: kurzer Text aus der Testphase,
übermalte Bildschirmfotos).

## App-Name

    Notizblock AW – Notizen & Sync

## Kurzbeschreibung

    Bunte Notizen, Widgets & Einkaufslisten – synchron mit Windows und Linux

## Vollständige Beschreibung

```
Notizblock AW – deine Notizen, schlicht und schön.

Schnell etwas aufschreiben, wiederfinden und auf jedem Gerät dabeihaben: Notizblock AW ist ein werbefreier Notizblock ohne Schnickschnack – für Gedanken, Bibelverse, Andachten, Einkaufslisten und alles, was du dir merken willst.

★ Das kann Notizblock AW
• Notizen in 25 Farben – anheften, archivieren und wiederherstellen
• Ordner für Ordnung, z. B. Bibelverse, Andacht und Alltag
• Einkaufslisten mit Mengen und Häkchen – Erledigtes wandert nach unten und kommt mit einem Tipp zurück
• Tabellen für Listen mit mehreren Spalten, z. B. Leseplan oder Geräteliste
• Widgets für den Startbildschirm: eine Notiz immer im Blick oder einen Ordner mit einem Tipp öffnen
• Schnelle Suche in Titeln und Inhalten
• Rückgängig und Wiederholen beim Schreiben
• Frühere Versionen einer Notiz wiederherstellen
• Text aus anderen Apps teilen und als Notiz speichern
• Drucken oder als PDF, Text- und Word-Datei speichern
• Hell oder dunkel – folgt deinem System
• 13 Sprachen, Deutsch als Standard

☁ Synchron auf allen Geräten
Über dein eigenes Google Drive gleicht Notizblock AW deine Notizen zwischen Android, Windows und Linux ab. Es gibt keinen eigenen Server: Deine Notizen liegen nur auf deinen Geräten und – wenn du willst – in deinem Google Drive. Der Abgleich ist freiwillig, ohne Anmeldung funktioniert die App vollständig offline.

Notizblock AW gibt es auch für Windows (Microsoft Store) und Linux (Snap Store) – dort mit Notizzetteln direkt auf dem Desktop.

✔ Kostenlos und ohne Werbung
Keine Werbung, keine Abos, kein Konto nötig.

Datenschutz: https://andreaswurzer110-hub.github.io/notizblock-privacy/

Entwickelt von Andreas Wurzer mit Claude Code. Code und Texte sind teilweise KI-generiert und vom Entwickler geprüft.
Bibelverse in den Vorschaubildern: Schlachter-Übersetzung 1951.
```

## Bilder

| Datei | Inhalt |
|-------|--------|
| `store/telefon_01.png` … `_08.png` | Handy, 1080×1920: Übersicht, Widgets, Ordner, Editor, Einkaufsliste, Suche, Farben, Dunkel |
| `store/tablet_01.png` … `_04.png` | Tablet, 1600×2560 – als 7- UND 10-Zoll-Bilder |
| `store/vorstellungsgrafik.png` | 1024×500 |
| Symbol | bleibt (`assets/icon/icon_full.png`, 512 px) – Play verlangt dasselbe Symbol wie in der App |

**So entstanden (2026-10-05):** Emulator `Medium_Phone_API_36.1` ohne Fenster,
x64-**Profil**-Build (debugfähig → Demo-DB per `run-as` einspielbar, kleiner
als Debug). Demo-Notizen mit Bibelversen nach Schlachter 1951 (Wortlaut gegen
getbible.net `schlachter` geprüft; bei Phil 4,13 steht dort v12 mit drin → nur
den Satz „Ich vermag alles …“ zitieren). Für das nicht durchgestrichene
Sync-Symbol lief ein Vorführ-Build mit `--dart-define=STORE_DEMO=true` und
einer **lokalen, nicht committeten** Zeile in `GoogleDriveService.isSignedIn`;
im Widget dazu `app_flutter/drive_state.json` = `{"signedIn":true}`. Display
1080×1920 / Dichte 380 (Tablet 1600×2560 / 320), Demo-Statusleiste 9:41.
Gestaltung (Verlauf im App-Blau, Roboto aus dem Flutter-SDK, Handyrahmen) per
Python/PIL.
