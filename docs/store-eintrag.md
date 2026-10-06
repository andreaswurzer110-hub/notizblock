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

# Snap Store (Linux) – Bilder

| Datei | Inhalt |
|-------|--------|
| `store/snap/snap_1.png` … `_5.png` | 1920×1080: Notizzettel auf dem Desktop, Ordner, Einkaufsliste, Suche, Dunkel |
| `store/snap/banner.png` | Featured Banner 1920×640 (3:1) |

Vorgaben (snapcraft.io): höchstens 5 Bilder, je ≤ 2 MB, Seitenverhältnis
1:2 bis 2:1; Banner genau 3:1 (720×240 bis 4320×1440), ≤ 2 MB. Hochladen geht
nur im Dashboard (snapcraft.io → notizblock-aw → Listing), das macht Andi.

**So entstanden (2026-10-06):** nativer Linux-Build in WSL (Kopie `~/nbdemo`,
Vorführ-Zeile `STORE_DEMO` NUR dort) auf Xvfb `:97` mit `metacity` als
Fenstermanager (echte Titelleisten wie die Server-Decorations von Zorin im
Snap). Demo-Daten wie bei Play, Notizzettel-Lage über
`sticky_state/sticky_<id>.json` + `widget_ids.json`, Einstellung
`show_main_window_on_start` → Hauptfenster und Zettel starten zusammen.
Programme per `setsid -f` starten, sonst beendet WSL sie mit der Sitzung.
Fensterlage samt Rahmen (`_NET_FRAME_EXTENTS`) per python3-xlib, dann mit
PIL auf ein selbst erzeugtes Hintergrundbild mit weichen Schatten gesetzt –
das Wurzelfenster von Xvfb hält kein Hintergrundbild.
