import 'package:flutter_test/flutter_test.dart';
import 'package:notizblock/models/shopping_list.dart';

/// Sortieren und Umsortieren der Einkaufsliste.
///
/// Beides sind reine Listenoperationen – hier geprüft, damit die Reihenfolge
/// nicht nur „am Bildschirm plausibel" aussieht. Besonders die Umlaute: Dart
/// vergleicht nach Code-Einheiten, „Äpfel" landete damit hinter „Zwiebeln".
void main() {
  group('alphabetisch sortieren', () {
    List<String> sorted(List<String> names, {bool ascending = true}) {
      final list = [...names]
        ..sort((a, b) => compareShoppingNames(a, b, ascending: ascending));
      return list;
    }

    test('Umlaute stehen beim Grundbuchstaben, nicht hinter Z', () {
      expect(
        sorted(['Zwiebeln', 'Äpfel', 'Butter']),
        ['Äpfel', 'Butter', 'Zwiebeln'],
      );
    });

    test('Groß-/Kleinschreibung spielt keine Rolle', () {
      expect(sorted(['brot', 'Butter', 'Apfel']), ['Apfel', 'brot', 'Butter']);
    });

    test('absteigend dreht die Reihenfolge um', () {
      expect(
        sorted(['Äpfel', 'Butter', 'Zwiebeln'], ascending: false),
        ['Zwiebeln', 'Butter', 'Äpfel'],
      );
    });

    test('ß wird wie ss einsortiert', () {
      expect(sorted(['Süßes', 'Suppe', 'Salz']), ['Salz', 'Suppe', 'Süßes']);
    });

    test('leere Zeilen bleiben am Ende – auch absteigend', () {
      expect(sorted(['Brot', '', 'Apfel']), ['Apfel', 'Brot', '']);
      expect(
        sorted(['Brot', '', 'Apfel'], ascending: false),
        ['Brot', 'Apfel', ''],
      );
    });
  });

  group('umsortieren per Drag&Drop', () {
    // (Name, erledigt?)
    const milch = ('Milch', false);
    const brot = ('Brot', false);
    const butter = ('Butter', false);
    const eier = ('Eier', true);

    bool done((String, bool) e) => e.$2;
    List<String> names(List<(String, bool)> l) => [for (final e in l) e.$1];

    test('nach unten verschieben', () {
      final out = reorderActiveItems(
          [milch, brot, butter, eier], done, 0, 2);
      expect(names(out), ['Brot', 'Butter', 'Milch', 'Eier']);
    });

    test('nach oben verschieben', () {
      final out = reorderActiveItems(
          [milch, brot, butter, eier], done, 2, 0);
      expect(names(out), ['Butter', 'Milch', 'Brot', 'Eier']);
    });

    test('erledigte Artikel bleiben erhalten und rutschen ans Ende', () {
      final out = reorderActiveItems(
          [milch, eier, brot, butter], done, 0, 1);
      expect(names(out), ['Brot', 'Milch', 'Butter', 'Eier']);
      expect(out.where(done).length, 1);
    });

    test('unsinnige Indizes lassen die Liste unverändert', () {
      final input = [milch, brot, eier];
      expect(names(reorderActiveItems(input, done, 5, 0)), names(input));
      expect(names(reorderActiveItems(input, done, -1, 0)), names(input));
    });
  });
}
