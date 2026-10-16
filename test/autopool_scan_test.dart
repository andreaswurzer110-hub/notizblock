import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';
import 'package:notizblock/models/autopool.dart';
import 'package:notizblock/screens/autopool_scan_screen.dart';
import 'package:notizblock/utils/date_display.dart';
import 'package:notizblock/widgets/autopool_table.dart';

import 'fake_scanner_platform.dart';

/// Autopool „Scannen": erst Inventar-, dann Seriennummer per Kamera erfassen
/// und mit dem heutigen Datum als neue Zeile in die Tabelle übernehmen. Die
/// Kamera ersetzt hier eine Fake-Plattform, die Barcodes auf Zuruf liefert.
void main() {
  group('cleanScannedCode', () {
    test('trimmt und fasst Leerraum/Steuerzeichen zusammen', () {
      expect(cleanScannedCode(null), '');
      expect(cleanScannedCode('  SN-4711 \n'), 'SN-4711');
      expect(cleanScannedCode('INV\t0815\r\nA'), 'INV 0815 A');
      expect(cleanScannedCode('A\u0000B\u001DC'), 'A B C');
    });
  });

  group('AutopoolTable.addScannedRow', () {
    testWidgets('befüllt die leere Startzeile, danach neue Zeilen',
        (tester) async {
      final key = GlobalKey<AutopoolTableState>();
      String? json;
      await _pumpTable(tester, key, '', (j) => json = j);

      key.currentState!.addScannedRow(
          inventory: 'INV-1', serial: 'SN-1', date: '16.10.26');
      await tester.pumpAndSettle();
      var rows = jsonDecode(json!) as List;
      expect(rows, hasLength(1), reason: 'leere Startzeile wird befüllt');
      expect((rows[0] as Map)['cells'],
          ['', '', '', 'INV-1', 'SN-1', '16.10.26']);

      key.currentState!.addScannedRow(
          inventory: '', serial: 'SN-2', date: '16.10.26');
      await tester.pumpAndSettle();
      rows = jsonDecode(json!) as List;
      expect(rows, hasLength(2));
      expect((rows[1] as Map)['cells'], ['', '', '', '', 'SN-2', '16.10.26']);
      // Die Werte stehen sichtbar in den Feldern.
      expect(find.text('INV-1'), findsOneWidget);
      expect(find.text('SN-2'), findsOneWidget);
    });

    testWidgets('verkürzte, markierte oder gefärbte Zeile bleibt unangetastet',
        (tester) async {
      final key = GlobalKey<AutopoolTableState>();
      String? json;
      const data = '['
          '{"cells":["",""],"marked":false,"cols":2},'
          '{"cells":["","","","","",""],"marked":false,"color":"#FFCDD2"}'
          ']';
      await _pumpTable(tester, key, data, (j) => json = j);

      key.currentState!.addScannedRow(
          inventory: 'INV-9', serial: 'SN-9', date: '16.10.26');
      await tester.pumpAndSettle();
      final rows = jsonDecode(json!) as List;
      expect(rows, hasLength(3));
      expect((rows[2] as Map)['cells'],
          ['', '', '', 'INV-9', 'SN-9', '16.10.26']);
    });
  });

  // Datum für die neue Zeile: Jahr nur zweistellig (Andis Wunsch), Reihenfolge
  // und Trenner wie in der Sprache der App üblich.
  for (final (lang, expected) in [
    ('de', ['16.10.26', '6.1.27']),
    ('en', ['10/16/26', '1/6/27']),
  ]) {
    testWidgets('DateDisplay.date ($lang): zweistelliges Jahr', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        locale: Locale(lang),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          ctx = context;
          return const SizedBox();
        }),
      ));
      expect(DateDisplay.date(ctx, DateTime(2026, 10, 16)), expected[0]);
      expect(DateDisplay.date(ctx, DateTime(2027, 1, 6)), expected[1]);
    });
  }

  group('Zeilenmenü „Scannen“ überschreibt die Zeile', () {
    const laptop = ['Laptop', 'IT', 'Wien', 'INV-1', 'SN-1', '1.9.26'];
    // Zeile + ihr Duplikat (gleiches Gerät, neue Nummern kommen per Scan) und
    // eine verkürzte Zeile ohne Serien-/Datumsspalte.
    final data = jsonEncode([
      {'cells': laptop, 'marked': false},
      {'cells': laptop, 'marked': false},
      {'cells': ['Drucker', 'IT'], 'marked': false, 'cols': 2},
    ]);
    List<dynamic> cells(String? json, int row) =>
        ((jsonDecode(json!) as List)[row] as Map)['cells'] as List;

    testWidgets('scanIntoRow: Nummern + Datum, Nicht-Gescanntes bleibt',
        (tester) async {
      final key = GlobalKey<AutopoolTableState>();
      String? json;
      await _pumpTable(tester, key, data, (j) => json = j);

      key.currentState!.scanIntoRow(1,
          inventory: 'INV-2', serial: 'SN-2', date: '16.10.26');
      await tester.pumpAndSettle();
      expect(jsonDecode(json!) as List, hasLength(3),
          reason: 'keine neue Zeile');
      expect(cells(json, 0), laptop);
      expect(cells(json, 1),
          ['Laptop', 'IT', 'Wien', 'INV-2', 'SN-2', '16.10.26']);

      // Nur die Inventarnummer neu gescannt: die Seriennummer bleibt stehen.
      key.currentState!
          .scanIntoRow(1, inventory: 'INV-3', serial: '', date: '17.10.26');
      await tester.pumpAndSettle();
      expect(cells(json, 1),
          ['Laptop', 'IT', 'Wien', 'INV-3', 'SN-2', '17.10.26']);

      // Verkürzte Zeile hat keine Serien-/Datumsspalte → unverändert.
      key.currentState!.scanIntoRow(2, inventory: 'X', serial: 'Y', date: 'Z');
      await tester.pumpAndSettle();
      expect(cells(json, 2), ['Drucker', 'IT']);
    });

    testWidgets('über das Zeilenmenü: Kamera auf, Duplikat überschrieben',
        (tester) async {
      final original = MobileScannerPlatform.instance;
      final camera = FakeScannerPlatform();
      MobileScannerPlatform.instance = camera;
      addTearDown(() => MobileScannerPlatform.instance = original);
      final key = GlobalKey<AutopoolTableState>();
      String? json;
      await _pumpTable(tester, key, data, (j) => json = j);

      await _openRowMenu(tester, 1);
      await tester.tap(_menuEntry('Scannen'));
      await tester.pumpAndSettle();
      expect(find.byType(AutopoolScanScreen), findsOneWidget);

      for (final code in ['INV-2', 'SN-2']) {
        await _scan(tester, camera, [code]);
        await tester.pump(const Duration(seconds: 2));
      }
      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();

      expect(jsonDecode(json!) as List, hasLength(3),
          reason: 'keine neue Zeile');
      expect(cells(json, 0), laptop);
      expect(cells(json, 1).sublist(0, 5),
          ['Laptop', 'IT', 'Wien', 'INV-2', 'SN-2']);
      expect(cells(json, 1)[5], matches(RegExp(r'^\d{1,2}\.\d{1,2}\.\d{2}$')));
    });

    testWidgets('verkürzte Zeile bietet kein „Scannen“ an', (tester) async {
      final key = GlobalKey<AutopoolTableState>();
      await _pumpTable(tester, key, data, (_) {});

      await _openRowMenu(tester, 0);
      expect(_menuEntry('Scannen'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5)); // Menü schließen
      await tester.pumpAndSettle();

      await _openRowMenu(tester, 2);
      expect(_menuEntry('Zeile duplizieren'), findsOneWidget);
      expect(_menuEntry('Scannen'), findsNothing);
    });
  });

  group('AutopoolScanScreen', () {
    late MobileScannerPlatform original;
    setUp(() => original = MobileScannerPlatform.instance);
    tearDown(() => MobileScannerPlatform.instance = original);

    testWidgets('erst Inventar-, dann Seriennummer; Doppeltes zählt nicht',
        (tester) async {
      final camera = FakeScannerPlatform();
      MobileScannerPlatform.instance = camera;
      final results = <AutopoolScanResult?>[];
      await _openScanner(tester, results.add);

      expect(_applyButton(tester).enabled, isFalse);
      expect(find.text('Barcode für „Inv.-Nr.“ in den Rahmen halten'),
          findsOneWidget);
      // Das Datum kommt von selbst und steht schon da.
      expect(find.textContaining('16.10.26', findRichText: true),
          findsOneWidget);

      await _scan(tester, camera, ['  INV-0815 \n']);
      expect(find.text('INV-0815'), findsOneWidget);
      expect(find.text('Barcode für „Seriennummer“ in den Rahmen halten'),
          findsOneWidget);
      expect(_applyButton(tester).enabled, isTrue);

      // Kurz nach einem Treffer zählt nichts (Zeit zum Weiterschwenken).
      await _scan(tester, camera, ['SN-1']);
      expect(find.text('SN-1'), findsNothing);
      await tester.pump(const Duration(seconds: 2));

      // Derselbe Code steht noch im Bild → landet nicht im zweiten Feld.
      await _scan(tester, camera, ['INV-0815']);
      expect(find.text('INV-0815'), findsOneWidget);
      expect(find.text('–'), findsOneWidget);

      // Mehrere Codes in einem Bild: der erste noch nicht erfasste zählt.
      await _scan(tester, camera, ['INV-0815', 'SN-4711']);
      expect(find.text('SN-4711'), findsOneWidget);
      expect(
          find.text('Beide Nummern erfasst – mit „Übernehmen“ eintragen'),
          findsOneWidget);

      // Beide voll → Scan ruht.
      await tester.pump(const Duration(seconds: 2));
      await _scan(tester, camera, ['XYZ']);
      expect(find.text('XYZ'), findsNothing);

      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();
      expect(results, hasLength(1));
      expect(results.single!.serial, 'SN-4711');
      expect(results.single!.inventory, 'INV-0815');
    });

    testWidgets('Feld antippen scannt es neu, ✕ leert es', (tester) async {
      final camera = FakeScannerPlatform();
      MobileScannerPlatform.instance = camera;
      await _openScanner(tester, (_) {});

      await _scan(tester, camera, ['FALSCH']);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('FALSCH'), findsOneWidget);

      // Inventarnummer wieder zum Ziel machen und richtig scannen.
      await tester.tap(find.text('Inv.-Nr.'));
      await tester.pump();
      await _scan(tester, camera, ['INV-RICHTIG']);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('INV-RICHTIG'), findsOneWidget);
      expect(find.text('FALSCH'), findsNothing);
      expect(find.text('Barcode für „Seriennummer“ in den Rahmen halten'),
          findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.text('INV-RICHTIG'), findsNothing);
      expect(_applyButton(tester).enabled, isFalse);
      expect(find.text('Barcode für „Inv.-Nr.“ in den Rahmen halten'),
          findsOneWidget);
    });

    testWidgets('Zurück ohne Übernehmen liefert nichts', (tester) async {
      final camera = FakeScannerPlatform();
      MobileScannerPlatform.instance = camera;
      final results = <AutopoolScanResult?>[];
      await _openScanner(tester, results.add);

      await _scan(tester, camera, ['SN-1']);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(results, [null]);
    });

    testWidgets('verweigerte Kamera zeigt einen Hinweis', (tester) async {
      MobileScannerPlatform.instance = FakeScannerPlatform(
        startError: const MobileScannerException(
            errorCode: MobileScannerErrorCode.permissionDenied),
      );
      await _openScanner(tester, (_) {});

      expect(
          find.text('Kein Zugriff auf die Kamera. Bitte in den '
              'Android-Einstellungen für Notizblock AW erlauben.'),
          findsOneWidget);
      expect(_applyButton(tester).enabled, isFalse);
    });
  });
}

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

Future<void> _pumpTable(WidgetTester tester, GlobalKey<AutopoolTableState> key,
    String data, ValueChanged<String> onChanged) async {
  await tester.pumpWidget(_app(Scaffold(
    body: SingleChildScrollView(
      child: AutopoolTable(key: key, initialData: data, onChanged: onChanged),
    ),
  )));
  await tester.pumpAndSettle();
}

// Zeilenmenü per Rechtsklick auf den Anfasser links öffnen.
Future<void> _openRowMenu(WidgetTester tester, int row) async {
  await tester.tap(find.byIcon(Icons.drag_indicator).at(row),
      buttons: kSecondaryButton);
  await tester.pumpAndSettle();
}

Finder _menuEntry(String label) => find.descendant(
    of: find.byWidgetPredicate((w) => w is PopupMenuItem),
    matching: find.text(label));

// Öffnet den Scanner wie die Tabelle (mit umbenannter Inventar-Spalte).
Future<void> _openScanner(WidgetTester tester,
    void Function(AutopoolScanResult?) onResult) async {
  await tester.pumpWidget(_app(Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async => onResult(await showAutopoolScanner(
            context,
            inventoryLabel: 'Inv.-Nr.',
            serialLabel: 'Seriennummer',
            dateLabel: 'Datum',
            date: '16.10.26',
          )),
          child: const Text('öffnen'),
        ),
      ),
    ),
  )));
  await tester.tap(find.text('öffnen'));
  await tester.pumpAndSettle();
}

// Barcode „vor die Kamera halten“ und das Ereignis zustellen lassen, bevor der
// nächste Frame gezeichnet wird (pump() ohne Dauer zeichnet sonst zuerst).
Future<void> _scan(WidgetTester tester, FakeScannerPlatform camera,
    List<String> codes) async {
  camera.emit(codes);
  await tester.pump(Duration.zero);
}

ButtonStyleButton _applyButton(WidgetTester tester) =>
    tester.widget<ButtonStyleButton>(find.ancestor(
      of: find.text('Übernehmen'),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    ));
