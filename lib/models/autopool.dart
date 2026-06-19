import 'dart:convert';

/// Maximale (und Standard-)Spaltenanzahl einer Autopool-Zeile (Bezeichnung,
/// Dienststelle&Version, Ort, Inventarnummer, Seriennummer, Datum).
const int kAutopoolColCount = 6;

/// Erlaubte Feldanzahlen einer Zeile: volle Zeile (6) oder verkürzt (4/2).
/// Eine verkürzte Zeile rendert nur die ersten N Spalten (siehe AutopoolTable):
/// auf dem Handy weniger gestapelte Unterzeilen, auf dem Desktop füllen die
/// Felder die Breite. Aufsteigend gehalten.
const List<int> kAutopoolRowSizes = [2, 4, 6];

/// Eine beliebige Feldanzahl auf die nächste erlaubte Größe (2/4/6) einrasten.
int snapAutopoolRowSize(int n) {
  if (n <= 2) return 2;
  if (n <= 4) return 4;
  return kAutopoolColCount;
}

/// Eine Zeile der Autopool-Tabelle: die Text-Zellen + Markierungs-Flag + eine
/// optionale eigene Zeilenfarbe.
/// Die Zellenanzahl ([colCount]) ist 2, 4 oder 6 – eine verkürzte Zeile hat nur
/// die ersten Spalten (z.B. nur Bezeichnung + DS&Version).
/// `marked` streicht den Text der Zeile im Editor durch (z.B. „voraussichtlich
/// morgen verwenden") – die Zeile bleibt aber normal vorhanden.
/// `color` (Hex `#RRGGBB`, optional) färbt die einzelne Zeile ein; null = die
/// abwechselnde Zebra-Standardfärbung.
class AutopoolRow {
  final List<String> cells; // Länge ∈ kAutopoolRowSizes (2/4/6)
  final bool marked;
  final String? color;

  AutopoolRow(this.cells, {this.marked = false, this.color});

  int get colCount => cells.length;

  factory AutopoolRow.emptyRow({int cols = kAutopoolColCount}) =>
      AutopoolRow(List<String>.filled(cols, ''), marked: false);

  /// Serialisierung. `color` nur bei gesetztem Wert schreiben – so bleibt das
  /// Format identisch zu älteren App-Versionen, solange keine Zeilenfarbe genutzt
  /// wird (und ältere Versionen ignorieren den `color`-Schlüssel ohnehin).
  /// `cols` nur bei verkürzten Zeilen (≠6) schreiben: volle Zeilen bleiben damit
  /// byte-identisch zum alten Format. Ältere App-Versionen ignorieren `cols` und
  /// füllen kürzere `cells` beim Lesen auf 6 auf → kein Datenverlust, sie zeigen
  /// nur wieder alle 6 Felder (dokumentierte Abwärtskompatibilität).
  Map<String, dynamic> toJson() => {
        'cells': cells,
        'marked': marked,
        if (color != null) 'color': color,
        if (cells.length != kAutopoolColCount) 'cols': cells.length,
      };
}

/// Strukturierte Daten einer Autopool-Tabellen-Notiz. Serialisiert als JSON in
/// `Note.autopoolData`; der lesbare `content` der Notiz wird zusätzlich aus
/// [toDisplayText] erzeugt (für Liste/Suche/Widget/Sticky-Anzeige).
///
/// `headers` (optional, Länge [kAutopoolColCount]) hält benutzerdefinierte
/// Spaltenüberschriften; ein null-Eintrag bedeutet „lokalisierte Standard-
/// überschrift verwenden". Gespeichert wird das als zusätzlicher Listen-Eintrag
/// `{"headers":[…]}` OHNE `cells`-Schlüssel – ältere App-Versionen überspringen
/// Einträge ohne `cells` (siehe [fromJsonString]), also bleibt das Format
/// abwärtskompatibel (kein Datenverlust auf Geräten mit älterer Version).
class AutopoolData {
  final List<AutopoolRow> rows;
  final List<String?>? headers;

  AutopoolData(this.rows, {this.headers});

  factory AutopoolData.empty() => AutopoolData([AutopoolRow.emptyRow()]);

  /// Aus dem in der Notiz gespeicherten JSON-String. Robust gegen fehlende/zu
  /// viele Zellen (Feldanzahl rastet auf 2/4/6 ein, fehlende werden aufgefüllt),
  /// gegen kaputtes JSON (-> leere Tabelle) und gegen das alte Format ohne
  /// Markierung (Zeile = reine Zell-Liste statt {cells, marked}). Erkennt
  /// zusätzlich den optionalen Meta-Eintrag `{"headers":[…]}` für eigene
  /// Spaltenüberschriften.
  factory AutopoolData.fromJsonString(String source) {
    if (source.trim().isEmpty) return AutopoolData.empty();
    try {
      final decoded = jsonDecode(source);
      final rows = <AutopoolRow>[];
      List<String?>? headers;
      if (decoded is List) {
        for (final r in decoded) {
          // Meta-Eintrag mit benutzerdefinierten Spaltenüberschriften. Hat kein
          // `cells` -> ältere App-Versionen überspringen ihn (rawCells == null).
          if (r is Map && r['headers'] is List && r['cells'] == null) {
            final raw = r['headers'] as List;
            final h = <String?>[];
            for (var i = 0; i < kAutopoolColCount; i++) {
              final v = i < raw.length ? raw[i] : null;
              final s = v?.toString();
              h.add((s == null || s.isEmpty) ? null : s);
            }
            headers = h.any((e) => e != null) ? h : null;
            continue;
          }
          List<dynamic>? rawCells;
          var marked = false;
          String? color;
          int? cols;
          if (r is Map) {
            rawCells = r['cells'] as List<dynamic>?;
            marked = r['marked'] == true;
            final c = r['color'];
            if (c is String && c.isNotEmpty) color = c;
            final cv = r['cols'];
            if (cv is num && kAutopoolRowSizes.contains(cv.toInt())) {
              cols = cv.toInt();
            }
          } else if (r is List) {
            rawCells = r; // Altformat: Zeile war eine reine Zell-Liste
          }
          if (rawCells == null) continue;
          final all =
              rawCells.map((e) => e == null ? '' : e.toString()).toList();
          // Feldanzahl: expliziter `cols`-Schlüssel (neue Versionen) hat Vorrang,
          // sonst aus der Zellenanzahl ableiten (alte Versionen / volle Zeilen).
          final n = cols ?? snapAutopoolRowSize(all.length);
          final cells = <String>[
            for (var i = 0; i < n; i++) i < all.length ? all[i] : '',
          ];
          rows.add(AutopoolRow(cells, marked: marked, color: color));
        }
      }
      if (rows.isEmpty) {
        return AutopoolData([AutopoolRow.emptyRow()], headers: headers);
      }
      return AutopoolData(rows, headers: headers);
    } catch (_) {
      return AutopoolData.empty();
    }
  }

  String toJsonString() {
    final list = <dynamic>[];
    if (headers != null && headers!.any((h) => h != null)) {
      list.add({'headers': headers});
    }
    for (final r in rows) {
      list.add(r.toJson());
    }
    return jsonEncode(list);
  }

  /// Lesbare Textfassung (für Liste/Suche/Widget/Sticky-Anzeige). Pro Gerät wird
  /// die gleiche Gruppierung wie im Editor genutzt (je zwei Spalten eine Zeile),
  /// Geräte durch eine Leerzeile getrennt – so erkennt man im Widget direkt, wie
  /// viele Geräte es sind und was zusammengehört (statt einer durchlaufenden Zeile).
  String toDisplayText() {
    final devices = <String>[];
    for (final r in rows) {
      if (r.cells.every((c) => c.trim().isEmpty)) continue;
      final lines = <String>[];
      for (var i = 0; i < r.cells.length; i += 2) {
        final pair = [
          r.cells[i].trim(),
          if (i + 1 < r.cells.length) r.cells[i + 1].trim(),
        ].where((c) => c.isNotEmpty).join(' · ');
        if (pair.isNotEmpty) lines.add(pair);
      }
      if (lines.isNotEmpty) devices.add(lines.join('\n'));
    }
    return devices.join('\n\n');
  }

  bool get isEmpty =>
      rows.every((r) => r.cells.every((c) => c.trim().isEmpty));
}
