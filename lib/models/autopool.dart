import 'dart:convert';

/// Anzahl der Spalten einer Autopool-Zeile (Bezeichnung, Dienststelle&Version,
/// Ort, Inventarnummer, Seriennummer, Datum).
const int kAutopoolColCount = 6;

/// Eine Zeile der Autopool-Tabelle: die Text-Zellen + ein Markierungs-Flag.
/// `marked` streicht den Text der Zeile im Editor durch (z.B. „voraussichtlich
/// morgen verwenden") – die Zeile bleibt aber normal vorhanden.
class AutopoolRow {
  final List<String> cells; // Länge == kAutopoolColCount
  final bool marked;

  AutopoolRow(this.cells, {this.marked = false});

  factory AutopoolRow.emptyRow() =>
      AutopoolRow(List<String>.filled(kAutopoolColCount, ''), marked: false);

  Map<String, dynamic> toJson() => {'cells': cells, 'marked': marked};
}

/// Strukturierte Daten einer Autopool-Tabellen-Notiz. Serialisiert als JSON in
/// `Note.autopoolData`; der lesbare `content` der Notiz wird zusätzlich aus
/// [toDisplayText] erzeugt (für Liste/Suche/Widget/Sticky-Anzeige).
class AutopoolData {
  final List<AutopoolRow> rows;

  AutopoolData(this.rows);

  factory AutopoolData.empty() => AutopoolData([AutopoolRow.emptyRow()]);

  /// Aus dem in der Notiz gespeicherten JSON-String. Robust gegen fehlende/zu
  /// viele Zellen (wird auf [kAutopoolColCount] aufgefüllt/gekürzt), gegen
  /// kaputtes JSON (-> leere Tabelle) und gegen das alte Format ohne Markierung
  /// (Zeile = reine Zell-Liste statt {cells, marked}).
  factory AutopoolData.fromJsonString(String source) {
    if (source.trim().isEmpty) return AutopoolData.empty();
    try {
      final decoded = jsonDecode(source);
      final rows = <AutopoolRow>[];
      if (decoded is List) {
        for (final r in decoded) {
          List<dynamic>? rawCells;
          var marked = false;
          if (r is Map) {
            rawCells = r['cells'] as List<dynamic>?;
            marked = r['marked'] == true;
          } else if (r is List) {
            rawCells = r; // Altformat: Zeile war eine reine Zell-Liste
          }
          if (rawCells == null) continue;
          final cells =
              rawCells.map((e) => e == null ? '' : e.toString()).toList();
          while (cells.length < kAutopoolColCount) {
            cells.add('');
          }
          rows.add(AutopoolRow(cells.sublist(0, kAutopoolColCount),
              marked: marked));
        }
      }
      if (rows.isEmpty) return AutopoolData.empty();
      return AutopoolData(rows);
    } catch (_) {
      return AutopoolData.empty();
    }
  }

  String toJsonString() => jsonEncode([for (final r in rows) r.toJson()]);

  /// Lesbare Textfassung (für Liste/Suche/Widget/Sticky-Anzeige). Pro Gerät wird
  /// die gleiche Gruppierung wie im Editor genutzt (je zwei Spalten eine Zeile),
  /// Geräte durch eine Leerzeile getrennt – so erkennt man im Widget direkt, wie
  /// viele Geräte es sind und was zusammengehört (statt einer durchlaufenden Zeile).
  String toDisplayText() {
    final devices = <String>[];
    for (final r in rows) {
      if (r.cells.every((c) => c.trim().isEmpty)) continue;
      final lines = <String>[];
      for (var i = 0; i < kAutopoolColCount; i += 2) {
        final pair = [
          r.cells[i].trim(),
          if (i + 1 < kAutopoolColCount) r.cells[i + 1].trim(),
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
