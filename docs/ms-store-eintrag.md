# Store-Eintrag (Microsoft Store)

Stand 2026-10-06, Sprache Deutsch (de-DE). Partner Center: **Notizblock AW**,
Store-ID `9N8MGP7GQV4L` (https://apps.microsoft.com/detail/9N8MGP7GQV4L),
Paketfamilie `AndreasWurzer.NotizblockAW`. Das Store-Paket baut
`Release.ps1 -Plattform Windows` (`build\msix\Notizblock-<ver>-Store.msix`);
einreichen macht Andi im Partner Center (Submission-API für Einzelperson-Konten
nicht verfügbar, siehe `docs/store-upload.md`). Texte passend zu
`docs/store-eintrag.md` (Play) und `snap/snapcraft.yaml` (Snap).

## Beschreibung (max. 10.000 Zeichen)

```
Notizblock AW – deine Notizen, schlicht und schön.

Schnell etwas aufschreiben, wiederfinden und auf jedem Gerät dabeihaben: Notizblock AW ist ein werbefreier Notizblock ohne Schnickschnack – für Gedanken, Bibelverse, Andachten, Einkaufslisten und alles, was du dir merken willst.

Notizzettel direkt auf dem Desktop
Jede Notiz lässt sich als eigener Notizzettel auf den Desktop heften. Die Zettel merken sich Größe und Position, starten auf Wunsch automatisch mit Windows und sind nach einem Neustart oder Update von selbst wieder da.

Das kann Notizblock AW:
• Notizen in 25 Farben – anheften, archivieren und wiederherstellen
• Ordner für Ordnung, z. B. Bibelverse, Andacht und Alltag
• Einkaufslisten mit Mengen und Häkchen – Erledigtes wandert nach unten und kommt mit einem Klick zurück
• Tabellen für Listen mit mehreren Spalten, z. B. Leseplan oder Geräteliste
• Schnelle Suche in Titeln und Inhalten
• Rückgängig und Wiederholen beim Schreiben
• Frühere Versionen einer Notiz wiederherstellen
• Drucken oder als PDF, Text- und Word-Datei speichern
• Hell oder dunkel – folgt deinem System
• 13 Sprachen, Deutsch als Standard

Synchron auf allen Geräten
Über dein eigenes Google Drive gleicht Notizblock AW deine Notizen zwischen Windows, Android und Linux ab. Es gibt keinen eigenen Server: Deine Notizen liegen nur auf deinen Geräten und – wenn du willst – in deinem Google Drive. Der Abgleich ist freiwillig, ohne Anmeldung funktioniert die App vollständig offline.

Auch erhältlich für Android (Google Play) und Linux (Snap Store).

Kostenlos und ohne Werbung – keine Abos, kein Konto nötig.

Entwickelt von Andreas Wurzer mit Claude Code. Code und Texte sind teilweise KI-generiert und vom Entwickler geprüft. Bibelverse in den Bildern: Schlachter-Übersetzung 1951.
```

## Kurzbeschreibung (max. 1.000 Zeichen)

```
Bunte Notizen und Notizzettel direkt auf dem Desktop – mit Ordnern, Einkaufslisten und Suche. Synchron mit Android und Linux über dein eigenes Google Drive, kostenlos und ohne Werbung.
```

## Neuigkeiten in dieser Version (max. 1.500 Zeichen)

```
• Tabellen-Notizen: Zeilen lassen sich jetzt mit einem Klick duplizieren
• Kleinere Verbesserungen und Fehlerbehebungen
```

## Produktmerkmale (bis zu 20, je max. 200 Zeichen)

```
Notizzettel direkt auf dem Desktop – merken sich Größe und Position
Notizzettel starten auf Wunsch mit Windows und kommen nach Updates von selbst wieder
Notizen in 25 Farben, anheften, archivieren und wiederherstellen
Ordner für Ordnung, z. B. Bibelverse, Andacht und Alltag
Einkaufslisten mit Mengen, Häkchen und alphabetischem Sortieren
Tabellen für Listen mit mehreren Spalten
Schnelle Suche in Titeln und Inhalten
Rückgängig und Wiederholen beim Schreiben
Frühere Versionen einer Notiz wiederherstellen
Drucken oder als PDF, Text- und Word-Datei speichern
Freiwilliger Abgleich mit Android und Linux über das eigene Google Drive
Hell oder dunkel, 13 Sprachen
Keine Werbung, kein Tracking, kein Konto nötig
```

## Suchbegriffe (max. 7, je max. 40 Zeichen)

```
Notizen
Notizblock
Notizzettel
Haftnotizen
Einkaufsliste
Merkzettel
Notiz-App
```

## Weitere Felder

- **Copyright:** © 2026 Andreas Wurzer
- **Entwickelt von:** Andreas Wurzer
- **Datenschutzerklärung:** https://andreaswurzer110-hub.github.io/notizblock-privacy/
- **Support-Kontakt:** andi-w-apps@tuta.com
- **Kurztitel / Sortiertitel / Sprachtitel:** leer lassen

## Bildschirmfotos

Desktop mindestens 1366 × 768, PNG – hier 1920 × 1080. Aufgenommen am
2026-10-06 per `PrintWindow` von einer Vorführ-Kopie mit eigenem Datenordner
(siehe unten), Fenster auf den sichtbaren Rahmen zugeschnitten und auf ein
Hintergrundbild gesetzt. Bildunterschriften (je max. 200 Zeichen):

| Deutsch (`store/windows/`) | Bildunterschrift |
|-------|------------------|
| `windows_1.png` | Notizzettel direkt auf dem Desktop |
| `windows_2.png` | Ordnung mit Ordnern |
| `windows_3.png` | Einkaufslisten zum Abhaken |
| `windows_4.png` | Alles schnell gefunden |
| `windows_5.png` | Hell oder dunkel |

| Englisch (`store/windows/en/`) | Caption |
|-------|------------------|
| `windows_en_1.png` | Sticky notes right on your desktop |
| `windows_en_2.png` | Organized in folders |
| `windows_en_3.png` | Find anything fast |
| `windows_en_4.png` | Light or dark |

Kein englisches Einkaufslisten-Bild: Die Notizzettel-Fenster sind fest auf
Deutsch (`StickyNoteApp`, `locale: de`) – ein Einkaufszettel zeigte im
englischen Bild „Artikel hinzufügen“/„Erledigt“. Englische Verse: King James
Version (gemeinfrei), Wortlaut gegen getbible.net `kjv` geprüft.

**So entstanden:** Projektkopie im Scratchpad, darin NUR `CompanyName` in
`windows/runner/Runner.rc` auf `notizblock-demo` geändert → path_provider legt
alles unter `%APPDATA%\notizblock-demo\notizblock` ab (eigene DB, eigene
Notizzettel, keine Anmeldedaten – Andis Daten und Drive bleiben unberührt),
dazu die Vorführ-Zeile `STORE_DEMO` für das nicht durchgestrichene Sync-Symbol.
Bauen nur über einen kurzen Pfad (`subst N:`) – im Scratchpad überschritt der
Header-Pfad von `screen_retriever_windows` 260 Zeichen. Die kopierten
`*/flutter/ephemeral`-Ordner vorher entfernen (sonst „Cannot create link“).
Die nicht paketierte Kopie zeigte bei manchen Fenstern ein Warndreieck statt
des App-Symbols in der Titelleiste; im Bild durch das echte Symbol ersetzt.
Die Fenster erscheinen auf Andis Bildschirm, Klicks brauchen den Vordergrund →
vorher fragen.

---

# Store listing (English, en-US)

## Description

```
Notizblock AW – your notes, simple and beautiful.

Jot things down quickly, find them again and have them on every device: Notizblock AW is an ad-free notepad without the clutter – for thoughts, Bible verses, devotions, shopping lists and everything you want to remember.

Sticky notes right on your desktop
Pin any note to your desktop as its own sticky note. Sticky notes remember their size and position, can start automatically with Windows and come back on their own after a restart or update.

What Notizblock AW can do:
• Notes in 25 colors – pin, archive and restore
• Folders to stay organized, e.g. Bible verses, devotions and everyday notes
• Shopping lists with quantities and checkboxes – checked items move down and come back with one click
• Tables for lists with several columns, e.g. a reading plan or an equipment list
• Fast search across titles and contents
• Undo and redo while writing
• Restore earlier versions of a note
• Print or save as PDF, text or Word file
• Light or dark – follows your system
• 13 languages

In sync on all your devices
Notizblock AW syncs your notes between Windows, Android and Linux through your own Google Drive. There is no server of our own: your notes live only on your devices and – if you want – in your Google Drive. Syncing is optional; without signing in, the app works completely offline.

Also available for Android (Google Play) and Linux (Snap Store).

Free and without ads – no subscriptions, no account required.

Developed by Andreas Wurzer with Claude Code. Code and texts are partly AI-generated and reviewed by the developer. Bible verses in the screenshots: King James Version.
```

## Short description

```
Colorful notes and sticky notes right on your desktop – with folders, shopping lists and search. In sync with Android and Linux through your own Google Drive, free and without ads.
```

## What's new in this version

```
• Table notes: duplicate a row with one click
• Minor improvements and bug fixes
```

## Product features

```
Sticky notes right on your desktop – they remember their size and position
Sticky notes can start with Windows and come back on their own after updates
Notes in 25 colors – pin, archive and restore
Folders to stay organized, e.g. Bible verses, devotions and everyday notes
Shopping lists with quantities, checkboxes and alphabetical sorting
Tables for lists with several columns
Fast search across titles and contents
Undo and redo while writing
Restore earlier versions of a note
Print or save as PDF, text or Word file
Optional sync with Android and Linux through your own Google Drive
Light or dark mode, 13 languages
No ads, no tracking, no account required
```

## Search terms

```
notes
notepad
sticky notes
shopping list
note taking
desktop notes
memo
```

## Other fields

- **Copyright:** © 2026 Andreas Wurzer
- **Developed by:** Andreas Wurzer
- **Privacy policy:** https://andreaswurzer110-hub.github.io/notizblock-privacy/
- **Support contact:** andi-w-apps@tuta.com
