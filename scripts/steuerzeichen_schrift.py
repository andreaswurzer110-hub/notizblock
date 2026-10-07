# Erzeugt assets/fonts/NbSteuerzeichen.ttf – eine winzige Hilfsschrift, die nur
# LEERE Zeichen (Breite 0, keine Kontur) für Zeilenumbruch (U+000A) und
# Wagenrücklauf (U+000D) enthält. Hintergrund und Messwerte: snap/README.md →
# „Ursache gefunden: ~2,7 s bis die Notizen erscheinen".
#
# Kurz: Unter Linux sucht Flutter (Skia) für Zeichen, die keine Schrift der
# Liste enthält, per fontconfig eine Ersatzschrift. Für LF/CR gibt es keine →
# die Suche scheitert, wird nicht gemerkt und wiederholt sich bei jedem Absatz.
# Mit der alten fontconfig im Snap (2.13.1) und ~3.000 Schriften kostet jede
# Suche ~28 ms auf dem Hauptthread. Steht diese Schrift am Ende der
# Ersatzschriften-Liste (nur Linux, lib/utils/steuerzeichen.dart), findet Skia
# LF/CR dort und fragt fontconfig gar nicht erst.
#
# Höhe wie Roboto (Ascender 1900, Descender 500 bei 2048/em): Zeilenumbrüche
# zählen ohnehin nicht zur Zeilenhöhe, ein CR schon – in der Anzeige wird CR aber
# entfernt (anzeigeText), und Editor/Notizzettel erzwingen die Zeilenhöhe per
# StrutStyle. Gemessen: Zeilenmaße und Zeichenpositionen bleiben identisch.
#
# Aufruf (braucht fontTools: pip install fonttools):
#   python scripts/steuerzeichen_schrift.py
import pathlib
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

ZIEL = pathlib.Path(__file__).resolve().parent.parent / "assets" / "fonts" / "NbSteuerzeichen.ttf"
FAMILIE = "NbSteuerzeichen"
EM = 2048
ASCENT, DESCENT = 1900, 500  # wie Roboto

zeichen = {0x000A: "lf", 0x000D: "cr"}
glyphen = [".notdef", "cr", "lf"]

fb = FontBuilder(unitsPerEm=EM, isTTF=True)
fb.setupGlyphOrder(glyphen)
fb.setupCharacterMap(zeichen)
leer = TTGlyphPen(None).glyph()
fb.setupGlyf({g: leer for g in glyphen})
fb.setupHorizontalMetrics({g: (0, 0) for g in glyphen})
fb.setupHorizontalHeader(ascent=ASCENT, descent=-DESCENT)
fb.setupNameTable({"familyName": FAMILIE, "styleName": "Regular"})
fb.setupOS2(sTypoAscender=ASCENT, sTypoDescender=-DESCENT, sTypoLineGap=0,
            usWinAscent=ASCENT, usWinDescent=DESCENT, fsType=0)
fb.setupPost()
ZIEL.parent.mkdir(parents=True, exist_ok=True)
fb.save(str(ZIEL))
print(f"geschrieben: {ZIEL} ({ZIEL.stat().st_size} Bytes)")
