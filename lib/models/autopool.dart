import 'dart:convert';

/// Anzahl der Spalten einer Autopool-Zeile (Größe&Art, Model&CPU,
/// Inventarnummer&Dienststelle, Ort, Seriennummer, Windows-Version, Datum).
const int kAutopoolColCount = 7;

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

  /// Lesbare Textfassung: nicht-leere Zellen je Zeile mit " | " verbunden,
  /// Zeilen mit Zeilenumbruch. Komplett leere Zeilen werden ausgelassen.
  String toDisplayText() {
    return rows
        .where((r) => r.cells.any((c) => c.trim().isNotEmpty))
        .map((r) => r.cells
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .join('  |  '))
        .join('\n');
  }

  bool get isEmpty =>
      rows.every((r) => r.cells.every((c) => c.trim().isEmpty));
}
