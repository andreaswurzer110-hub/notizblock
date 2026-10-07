import 'dart:io';

import 'package:flutter/material.dart';

/// Hilfsschrift mit leeren Zeichen für Zeilenumbruch (LF) und Wagenrücklauf
/// (CR), siehe `scripts/steuerzeichen_schrift.py`.
const String kSteuerzeichenSchrift = 'NbSteuerzeichen';

/// Ersatzschriften für das Theme – NUR unter Linux, sonst `null` (Theme
/// unverändert).
///
/// Unter Linux sucht Flutter (Skia) für jedes Zeichen, das keine Schrift der
/// Liste enthält, per fontconfig eine Ersatzschrift. LF und CR stehen in keiner
/// Schrift → die Suche scheitert, wird nicht gemerkt und wiederholt sich bei
/// jedem Absatz. Im Snap (fontconfig 2.13.1) kostet das bei ~3.000
/// Systemschriften ~28 ms pro Suche auf dem Hauptthread: Die Übersicht stand
/// auf Zorin ~2,7 s leer da (89 Suchen), jeder Neuaufbau eines mehrzeiligen
/// Textes (Editor, Notizzettel) zahlt dasselbe. Messung: snap/README.md →
/// „Ursache gefunden: ~2,7 s bis die Notizen erscheinen".
///
/// Die Hilfsschrift hängt HINTER Flutters eigener Linux-Liste (Ubuntu, Adwaita
/// Sans, Cantarell, …), damit für alle sichtbaren Zeichen dieselbe Schrift wie
/// bisher gewählt wird; nur LF/CR landen jetzt bei ihr statt bei fontconfig.
List<String>? linuxErsatzschriften() {
  if (!Platform.isLinux) return null;
  final basis = Typography.material2021(platform: TargetPlatform.linux)
          .black
          .bodyMedium
          ?.fontFamilyFallback ??
      const <String>[];
  return [...basis, kSteuerzeichenSchrift];
}

/// Notiztext für die ANZEIGE (Karten, Liste, Archiv, Versionen): Windows-
/// Zeilenenden (`\r\n`) und einzelne `\r` werden zu `\n`.
///
/// Ein CR ist für das Layout ein normales Zeichen in der Zeile – über die
/// Hilfsschrift würde es deren Höhe einbringen; ohne sie löst es die teure
/// Ersatzschrift-Suche aus. Als `\n` fällt beides weg und das Bild bleibt
/// pixelgleich.
///
/// NUR für die Anzeige verwenden, nie zurückspeichern: Eine geänderte
/// Fassung würde `modifiedAt` ohne echte Änderung erhöhen (Sync-Konflikte).
String anzeigeText(String text) {
  if (!text.contains('\r')) return text;
  return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}
