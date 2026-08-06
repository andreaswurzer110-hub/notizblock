import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Alle Sprachdateien müssen denselben Schlüsselsatz haben wie die Vorlage
/// `app_de.arb`.
///
/// Fehlt ein Schlüssel, füllt `flutter gen-l10n` ihn still mit dem DEUTSCHEN
/// Text auf – in einer japanischen oder portugiesischen Oberfläche steht dann
/// plötzlich Deutsch, ohne dass irgendwo ein Fehler auftaucht. Bei 13 Sprachen
/// passiert das schnell, sobald jemand einen neuen Text nur in de/en ergänzt.
/// Dieser Test macht es sofort sichtbar.
void main() {
  final dir = Directory('lib/l10n');

  Map<String, dynamic> read(File f) =>
      jsonDecode(f.readAsStringSync().replaceFirst('﻿', ''))
          as Map<String, dynamic>;

  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  test('jede Sprachdatei hat exakt die Schlüssel der Vorlage', () {
    final template = messageKeys(read(File('${dir.path}/app_de.arb')));
    expect(template, isNotEmpty);

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.arb'))
        .toList();
    expect(files.length, greaterThanOrEqualTo(13),
        reason: 'Es sollten alle angebotenen Sprachen als .arb vorliegen');

    for (final f in files) {
      final name = f.uri.pathSegments.last;
      if (name == 'app_de.arb') continue;
      final keys = messageKeys(read(f));
      expect(template.difference(keys), isEmpty,
          reason: '$name: fehlende Schlüssel (würden auf Deutsch zurückfallen)');
      expect(keys.difference(template), isEmpty,
          reason: '$name: unbekannte Schlüssel');
    }
  });

  test('keine leeren Übersetzungen', () {
    for (final f in dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.arb'))) {
      final arb = read(f);
      for (final k in messageKeys(arb)) {
        expect((arb[k] as String).trim(), isNotEmpty,
            reason: '${f.uri.pathSegments.last}: „$k" ist leer');
      }
    }
  });
}
