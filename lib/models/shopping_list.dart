import 'dart:convert';

/// Ein Artikel einer Einkaufsliste: Bezeichnung, Menge und ob bereits erledigt
/// (eingekauft). `done == true` blendet den Artikel in die „Erledigt"-Sektion
/// unterhalb der aktiven Liste – von dort per Häkchen wieder in die Einkaufsliste
/// zurückholbar, ohne ihn neu eintippen zu müssen (man kauft meist immer wieder
/// fast dasselbe ein).
class ShoppingItem {
  final String name;
  final int quantity; // immer >= 1
  final bool done;

  ShoppingItem(this.name, {int quantity = 1, this.done = false})
      : quantity = quantity < 1 ? 1 : quantity;

  ShoppingItem copyWith({String? name, int? quantity, bool? done}) =>
      ShoppingItem(
        name ?? this.name,
        quantity: quantity ?? this.quantity,
        done: done ?? this.done,
      );

  /// Serialisierung. `qty` nur bei ≠1 und `done` nur bei true schreiben, damit
  /// das JSON knapp bleibt (Standardartikel = nur `{"name":…}`).
  Map<String, dynamic> toJson() => {
        'name': name,
        if (quantity != 1) 'qty': quantity,
        if (done) 'done': true,
      };
}

/// Strukturierte Daten einer Einkaufslisten-Notiz. Serialisiert als JSON-Array
/// in `Note.autopoolData` (das generische Struktur-Datenfeld wird für den
/// Notiz-Typ `'shopping'` wiederverwendet – kein neues DB-/Sync-Feld nötig, und
/// ältere App-Versionen, die den Typ nicht rendern, bewahren das Feld beim
/// Sync-Round-Trip). Der lesbare `content` der Notiz wird zusätzlich aus
/// [toDisplayText] erzeugt (für Liste/Suche/Widget/Sticky-Anzeige).
///
/// Format: `[{"name":"Milch","qty":2}, {"name":"Butter","done":true}, …]`.
/// Die Reihenfolge im Array ist die Anzeigereihenfolge; `done` steuert nur, in
/// welcher der beiden Sektionen (aktiv / erledigt) der Artikel erscheint.
class ShoppingListData {
  final List<ShoppingItem> items;

  ShoppingListData(this.items);

  factory ShoppingListData.empty() => ShoppingListData([]);

  /// Aus dem in der Notiz gespeicherten JSON-String. Robust gegen kaputtes JSON
  /// (-> leere Liste), gegen fehlende Felder (qty -> 1, done -> false) und gegen
  /// ein simples Altformat, bei dem eine Zeile nur der Artikelname (String) ist.
  /// Objekte ohne `name` werden übersprungen (Platz für spätere Meta-Einträge,
  /// analog zum Autopool-Format).
  factory ShoppingListData.fromJsonString(String source) {
    if (source.trim().isEmpty) return ShoppingListData.empty();
    try {
      final decoded = jsonDecode(source);
      final items = <ShoppingItem>[];
      if (decoded is List) {
        for (final e in decoded) {
          if (e is Map) {
            if (!e.containsKey('name')) continue; // z.B. künftiger Meta-Eintrag
            final name = (e['name'] ?? '').toString();
            var qty = 1;
            final q = e['qty'];
            if (q is num && q.toInt() >= 1) qty = q.toInt();
            items.add(ShoppingItem(name, quantity: qty, done: e['done'] == true));
          } else if (e is String) {
            items.add(ShoppingItem(e)); // simples Altformat: reiner Name
          }
        }
      }
      return ShoppingListData(items);
    } catch (_) {
      return ShoppingListData.empty();
    }
  }

  String toJsonString() => jsonEncode([for (final i in items) i.toJson()]);

  /// Noch zu kaufende Artikel (obere Liste), in Array-Reihenfolge.
  List<ShoppingItem> get active => [for (final i in items) if (!i.done) i];

  /// Bereits erledigte Artikel (untere Liste), in Array-Reihenfolge.
  List<ShoppingItem> get completed => [for (final i in items) if (i.done) i];

  /// „Leer" = keine Artikel mit Text. Steuert (wie beim Autopool), ob eine neue
  /// Notiz überhaupt angelegt bzw. eine bestehende beim Verlassen gelöscht wird.
  bool get isEmpty => items.every((i) => i.name.trim().isEmpty);

  /// Lesbare Textfassung (für Liste/Suche/Widget/Sticky-Anzeige und für ältere
  /// App-Versionen, die die Struktur nicht kennen). Aktive Artikel zuerst,
  /// erledigte mit vorangestelltem ✓ darunter; Menge > 1 als „N× " davor.
  String toDisplayText() {
    String line(ShoppingItem i, {bool done = false}) {
      final qty = i.quantity > 1 ? '${i.quantity}× ' : '';
      return '${done ? '✓ ' : ''}$qty${i.name.trim()}';
    }

    final lines = <String>[
      for (final i in active)
        if (i.name.trim().isNotEmpty) line(i),
      for (final i in completed)
        if (i.name.trim().isNotEmpty) line(i, done: true),
    ];
    return lines.join('\n');
  }
}

/// Vergleichsschlüssel fürs alphabetische Sortieren: klein geschrieben und ohne
/// diakritische Zeichen.
///
/// Dart vergleicht Strings nach Code-Einheiten – „Äpfel" landete damit HINTER
/// „Zwiebeln", weil Ä (U+00C4) hinter Z steht. Für eine Einkaufsliste ist das
/// sichtbar falsch, deshalb hier eine einfache Faltung der im Deutschen,
/// Französischen, Spanischen und Skandinavischen üblichen Zeichen.
String shoppingSortKey(String name) {
  final lower = name.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final ch in lower.split('')) {
    buffer.write(_diacriticFolding[ch] ?? ch);
  }
  return buffer.toString();
}

const Map<String, String> _diacriticFolding = {
  'ä': 'a', 'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'å': 'a', 'æ': 'ae',
  'ö': 'o', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ø': 'o',
  'ü': 'u', 'ù': 'u', 'ú': 'u', 'û': 'u',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ç': 'c', 'ñ': 'n', 'ß': 'ss',
};

/// Vergleichsfunktion fürs Sortieren einer Einkaufsliste nach [name].
///
/// Namenlose Einträge (leere UI-Platzhalterzeile) landen IMMER am Ende – auch
/// bei Z–A. Sonst rutschte die leere Tippzeile mitten in die Liste.
int compareShoppingNames(String a, String b, {required bool ascending}) {
  final ka = shoppingSortKey(a);
  final kb = shoppingSortKey(b);
  if (ka.isEmpty || kb.isEmpty) {
    if (ka.isEmpty && kb.isEmpty) return 0;
    return ka.isEmpty ? 1 : -1;
  }
  final cmp = ka.compareTo(kb);
  return ascending ? cmp : -cmp;
}

/// Umsortieren per Drag&Drop innerhalb der AKTIVEN Teilliste.
///
/// Die Indizes stammen aus der gefilterten Ansicht (nur nicht-erledigte),
/// gespeichert wird aber EINE flache Liste. Ergebnis ist deshalb „aktive in
/// neuer Reihenfolge, danach erledigte". Das ist verlustfrei: die Anzeige trennt
/// ohnehin nach `done`, und [ShoppingListData.toDisplayText] listet ebenfalls
/// erst die aktiven, dann die erledigten Artikel.
///
/// [newIndex] muss bereits um die entnommene Zeile korrigiert sein – das
/// erledigt Flutters `onReorderItem` (das ältere `onReorder` tat das NICHT und
/// ist deshalb abgekündigt).
List<T> reorderActiveItems<T>(
  List<T> all,
  bool Function(T) isDone,
  int oldIndex,
  int newIndex,
) {
  final active = [for (final e in all) if (!isDone(e)) e];
  if (oldIndex < 0 || oldIndex >= active.length) return List<T>.from(all);
  final completed = [for (final e in all) if (isDone(e)) e];
  final moved = active.removeAt(oldIndex);
  active.insert(newIndex.clamp(0, active.length), moved);
  return [...active, ...completed];
}
