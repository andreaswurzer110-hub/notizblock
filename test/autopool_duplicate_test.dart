import 'dart:convert';

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';
import 'package:notizblock/widgets/autopool_table.dart';

/// „Zeile duplizieren" im Zeilen-Kontextmenü der Autopool-Tabelle: die Kopie
/// muss DIREKT unter der Vorlage landen und ihr exakt gleichen – Zellinhalt,
/// Feldanzahl (verkürzte Zeile bleibt verkürzt), Markierung und Zeilenfarbe.
void main() {
  testWidgets('Duplizieren fügt eine exakte Kopie direkt darunter ein',
      (tester) async {
    // Im Test rendert Flutter mit einer Platzhalter-Schrift, in der JEDES
    // Zeichen ein Quadrat der Schriftgröße ist – die Menütexte (auch das alte
    // „Markieren / Markierung entfernen") laufen dadurch über die Menübreite.
    // Das sagt nichts über die echte App und ist hier nicht Gegenstand.
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed')) return;
      oldOnError?.call(details);
    };
    try {
      await _duplicateFirstRow(tester);
    } finally {
      FlutterError.onError = oldOnError;
    }
  });
}

Future<void> _duplicateFirstRow(WidgetTester tester) async {
  const data = '['
      '{"cells":["Laptop","DS 12 / Win 11"],"marked":true,'
      '"color":"#FFCDD2","cols":2},'
      '{"cells":["Drucker","DS 3","Raum 4","INV-7","SN-1","01.10."],'
      '"marked":false}'
      ']';
  String? json;
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('de'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: AutopoolTable(
          initialData: data,
          onChanged: (j) => json = j,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();

  // Rechtsklick auf den Anfasser der ERSTEN Zeile öffnet das Zeilenmenü.
  await tester.tap(find.byIcon(Icons.drag_indicator).first,
      buttons: kSecondaryButton);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Zeile duplizieren'));
  await tester.pumpAndSettle();

  expect(json, isNotNull);
  final rows = jsonDecode(json!) as List;
  expect(rows, hasLength(3));
  expect(rows[1], rows[0]);
  expect(rows[1], {
    'cells': ['Laptop', 'DS 12 / Win 11'],
    'marked': true,
    'color': '#FFCDD2',
    'cols': 2,
  });
  expect((rows[2] as Map)['cells'][0], 'Drucker');

  // Die Kopie ist ein eigenes Textfeld: Tippen darin ändert die Vorlage nicht.
  expect(find.text('Laptop'), findsNWidgets(2));
  await tester.enterText(find.text('Laptop').last, 'Laptop 2');
  await tester.pump();
  final after = jsonDecode(json!) as List;
  expect((after[0] as Map)['cells'][0], 'Laptop');
  expect((after[1] as Map)['cells'][0], 'Laptop 2');
}
