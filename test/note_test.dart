// Unit-Tests für das Note-Model (reines Dart, keine DB/Flutter-Bindings nötig).
// Decken die kritischen Pfade ab: Defaults, copyWith, SQLite-Map- und
// JSON-Roundtrip sowie Gleichheit über die id.

import 'package:flutter_test/flutter_test.dart';
import 'package:notizblock/models/note.dart';

void main() {
  group('Note', () {
    test('Default-Werte: generierte id, Standardfarbe, Flags false', () {
      final note = Note(title: 'Titel', content: 'Inhalt');

      expect(note.id, isNotEmpty);
      expect(note.color, '#FFFDE7'); // Post-it-Gelb
      expect(note.isPinned, isFalse);
      expect(note.isArchived, isFalse);
    });

    test('copyWith ändert nur übergebene Felder, behält id/createdAt', () {
      final original = Note(
        title: 'Alt',
        content: 'Text',
        createdAt: DateTime(2024, 1, 1),
        modifiedAt: DateTime(2024, 1, 1),
      );

      final copy = original.copyWith(title: 'Neu', isPinned: true);

      expect(copy.id, original.id);
      expect(copy.createdAt, original.createdAt);
      expect(copy.title, 'Neu');
      expect(copy.content, 'Text'); // unverändert
      expect(copy.isPinned, isTrue);
      // copyWith setzt modifiedAt ohne Argument auf jetzt -> muss neuer sein.
      expect(copy.modifiedAt.isAfter(original.modifiedAt), isTrue);
    });

    test('toMap/fromMap Roundtrip erhält alle Werte', () {
      final note = Note(
        title: 'Map',
        content: 'Inhalt',
        createdAt: DateTime(2024, 5, 6, 7, 8, 9),
        modifiedAt: DateTime(2024, 5, 6, 7, 8, 10),
        color: '#FFF176',
        isPinned: true,
        isArchived: true,
      );

      final restored = Note.fromMap(note.toMap());

      expect(restored.id, note.id);
      expect(restored.title, note.title);
      expect(restored.content, note.content);
      expect(restored.createdAt, note.createdAt);
      expect(restored.modifiedAt, note.modifiedAt);
      expect(restored.color, note.color);
      expect(restored.isPinned, isTrue);
      expect(restored.isArchived, isTrue);
    });

    test('toMap kodiert Bools als 0/1 (SQLite)', () {
      final map = Note(title: 't', content: 'c', isPinned: true).toMap();
      expect(map['isPinned'], 1);
      expect(map['isArchived'], 0);
    });

    test('toJson/fromJson Roundtrip erhält alle Werte', () {
      final note = Note(
        title: 'Json',
        content: 'Inhalt',
        color: '#E3F2FD',
        isPinned: true,
      );

      final restored = Note.fromJson(note.toJson());

      expect(restored.id, note.id);
      expect(restored.title, note.title);
      expect(restored.content, note.content);
      expect(restored.color, note.color);
      expect(restored.isPinned, isTrue);
      expect(restored.isArchived, isFalse);
    });

    test('toJson hält Bools als echte Booleans', () {
      final json = Note(title: 't', content: 'c').toJson();
      expect(json['isPinned'], isFalse);
      expect(json['isArchived'], isFalse);
    });

    test('Gleichheit basiert nur auf der id', () {
      final a = Note(id: 'gleiche-id', title: 'A', content: '1');
      final b = Note(id: 'gleiche-id', title: 'B', content: '2');
      final c = Note(id: 'andere-id', title: 'A', content: '1');

      expect(a, equals(b)); // gleiche id -> gleich
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });
  });
}
