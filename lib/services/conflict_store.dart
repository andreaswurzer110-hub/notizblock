import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Ein noch nicht bestätigter Sync-Konflikt: dieselbe Notiz wurde seit dem
/// letzten Abgleich auf zwei Geräten geändert.
class PendingConflict {
  final String noteId;
  final String title;

  /// true = die Fassung des anderen Geräts hat gewonnen (die hiesige wurde
  /// ersetzt), false = die hiesige Fassung hat gewonnen.
  final bool remoteWon;
  final DateTime detectedAt;

  PendingConflict({
    required this.noteId,
    required this.title,
    required this.remoteWon,
    required this.detectedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': noteId,
        'title': title,
        'remoteWon': remoteWon,
        'at': detectedAt.toIso8601String(),
      };

  static PendingConflict? fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    if (id is! String || id.isEmpty) return null;
    return PendingConflict(
      noteId: id,
      title: (j['title'] ?? '').toString(),
      remoteWon: j['remoteWon'] == true,
      detectedAt:
          DateTime.tryParse((j['at'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

/// Merkt sich erkannte Sync-Konflikte, bis der Nutzer sie gesehen hat.
///
/// **Warum eine Datei und nicht nur Speicher (war real ein Mangel in 1.30.0):**
/// Ein Konflikt fällt genau dort auf, wo er entsteht – und das ist oft NICHT
/// die Notizliste: der Abgleich läuft auch aus dem Editor heraus, aus einem
/// Sticky-Fenster (eigener Prozess), aus dem Android-Hintergrund-Isolate und
/// beim Wechsel in den Hintergrund (`paused`). Ein Hinweis, der nur im
/// Arbeitsspeicher steht bzw. als kurze SnackBar erscheint, geht dabei
/// verloren – beim Testen kam deshalb nie eine Warnung an. Über diese Datei
/// meldet JEDER Sync-Pfad den Konflikt, und die Notizliste zeigt ihn beim
/// nächsten Blick als bleibenden Hinweis.
class ConflictStore {
  ConflictStore._();

  static const String _fileName = 'conflicts.json';
  static const int _maxEntries = 20;

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  /// Konflikte ergänzen (pro Notiz nur der jüngste Eintrag).
  static Future<void> add(Iterable<PendingConflict> conflicts) async {
    if (conflicts.isEmpty) return;
    try {
      final current = await load();
      final byId = <String, PendingConflict>{
        for (final c in current) c.noteId: c,
        for (final c in conflicts) c.noteId: c,
      };
      final list = byId.values.toList()
        ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
      await _write(list.take(_maxEntries).toList());
    } catch (e) {
      debugPrint('Konflikt merken fehlgeschlagen: $e');
    }
  }

  static Future<List<PendingConflict>> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is! List) return [];
      final out = <PendingConflict>[];
      for (final e in decoded) {
        if (e is Map) {
          final c = PendingConflict.fromJson(e.cast<String, dynamic>());
          if (c != null) out.add(c);
        }
      }
      return out;
    } catch (e) {
      // Unlesbare Datei (z.B. nach einem Absturz) einfach verwerfen – es geht
      // nur um einen Hinweis, die Daten selbst liegen im Versionsverlauf.
      debugPrint('Konflikte lesen fehlgeschlagen: $e');
      return [];
    }
  }

  /// Einen erledigten Hinweis entfernen (Nutzer hat ihn gesehen).
  static Future<void> remove(String noteId) async {
    final current = await load();
    await _write(current.where((c) => c.noteId != noteId).toList());
  }

  static Future<void> clearAll() => _write(const []);

  static Future<void> _write(List<PendingConflict> list) async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode([for (final c in list) c.toJson()]));
    } catch (e) {
      debugPrint('Konflikte schreiben fehlgeschlagen: $e');
    }
  }
}
