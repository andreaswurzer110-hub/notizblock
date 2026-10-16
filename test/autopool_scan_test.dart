import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';
import 'package:notizblock/models/autopool.dart';
import 'package:notizblock/screens/autopool_scan_screen.dart';
import 'package:notizblock/widgets/autopool_table.dart';

/// Autopool „Scannen": Serien- und Inventarnummer per Kamera erfassen und als
/// neue Zeile in die Tabelle übernehmen. Die Kamera ersetzt hier eine Fake-
/// Plattform, die Barcodes auf Zuruf liefert.
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

      key.currentState!.addScannedRow(serial: 'SN-1', inventory: 'INV-1');
      await tester.pumpAndSettle();
      var rows = jsonDecode(json!) as List;
      expect(rows, hasLength(1), reason: 'leere Startzeile wird befüllt');
      expect((rows[0] as Map)['cells'], ['', '', '', 'INV-1', 'SN-1', '']);

      key.currentState!.addScannedRow(serial: 'SN-2', inventory: '');
      await tester.pumpAndSettle();
      rows = jsonDecode(json!) as List;
      expect(rows, hasLength(2));
      expect((rows[1] as Map)['cells'], ['', '', '', '', 'SN-2', '']);
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

      key.currentState!.addScannedRow(serial: 'SN-9', inventory: 'INV-9');
      await tester.pumpAndSettle();
      final rows = jsonDecode(json!) as List;
      expect(rows, hasLength(3));
      expect((rows[2] as Map)['cells'], ['', '', '', 'INV-9', 'SN-9', '']);
    });
  });

  group('AutopoolScanScreen', () {
    late MobileScannerPlatform original;
    setUp(() => original = MobileScannerPlatform.instance);
    tearDown(() => MobileScannerPlatform.instance = original);

    testWidgets('erst Serien-, dann Inventarnummer; Doppeltes zählt nicht',
        (tester) async {
      final camera = _FakeScannerPlatform();
      MobileScannerPlatform.instance = camera;
      final results = <AutopoolScanResult?>[];
      await _openScanner(tester, results.add);

      expect(_applyButton(tester).enabled, isFalse);
      expect(find.text('Barcode für „Seriennummer“ in den Rahmen halten'),
          findsOneWidget);

      await _scan(tester, camera, ['  SN-4711 \n']);
      expect(find.text('SN-4711'), findsOneWidget);
      expect(find.text('Barcode für „Inv.-Nr.“ in den Rahmen halten'),
          findsOneWidget);
      expect(_applyButton(tester).enabled, isTrue);

      // Kurz nach einem Treffer zählt nichts (Zeit zum Weiterschwenken).
      await _scan(tester, camera, ['INV-1']);
      expect(find.text('INV-1'), findsNothing);
      await tester.pump(const Duration(seconds: 2));

      // Derselbe Code steht noch im Bild → landet nicht im zweiten Feld.
      await _scan(tester, camera, ['SN-4711']);
      expect(find.text('SN-4711'), findsOneWidget);
      expect(find.text('–'), findsOneWidget);

      // Mehrere Codes in einem Bild: der erste noch nicht erfasste zählt.
      await _scan(tester, camera, ['SN-4711', 'INV-0815']);
      expect(find.text('INV-0815'), findsOneWidget);
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
      final camera = _FakeScannerPlatform();
      MobileScannerPlatform.instance = camera;
      await _openScanner(tester, (_) {});

      await _scan(tester, camera, ['FALSCH']);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('FALSCH'), findsOneWidget);

      // Seriennummer wieder zum Ziel machen und richtig scannen.
      await tester.tap(find.text('Seriennummer'));
      await tester.pump();
      await _scan(tester, camera, ['SN-RICHTIG']);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('SN-RICHTIG'), findsOneWidget);
      expect(find.text('FALSCH'), findsNothing);
      expect(find.text('Barcode für „Inv.-Nr.“ in den Rahmen halten'),
          findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.text('SN-RICHTIG'), findsNothing);
      expect(_applyButton(tester).enabled, isFalse);
      expect(find.text('Barcode für „Seriennummer“ in den Rahmen halten'),
          findsOneWidget);
    });

    testWidgets('Zurück ohne Übernehmen liefert nichts', (tester) async {
      final camera = _FakeScannerPlatform();
      MobileScannerPlatform.instance = camera;
      final results = <AutopoolScanResult?>[];
      await _openScanner(tester, results.add);

      await _scan(tester, camera, ['SN-1']);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(results, [null]);
    });

    testWidgets('verweigerte Kamera zeigt einen Hinweis', (tester) async {
      MobileScannerPlatform.instance = _FakeScannerPlatform(
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

// Öffnet den Scanner wie die Tabelle (mit umbenannter Inventar-Spalte).
Future<void> _openScanner(WidgetTester tester,
    void Function(AutopoolScanResult?) onResult) async {
  await tester.pumpWidget(_app(Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async => onResult(await showAutopoolScanner(
            context,
            serialLabel: 'Seriennummer',
            inventoryLabel: 'Inv.-Nr.',
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
Future<void> _scan(WidgetTester tester, _FakeScannerPlatform camera,
    List<String> codes) async {
  camera.emit(codes);
  await tester.pump(Duration.zero);
}

ButtonStyleButton _applyButton(WidgetTester tester) =>
    tester.widget<ButtonStyleButton>(find.ancestor(
      of: find.text('Übernehmen'),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    ));

/// Kamera-Ersatz: startet sofort und liefert Barcodes über [emit].
class _FakeScannerPlatform extends MobileScannerPlatform {
  _FakeScannerPlatform({this.startError});

  final MobileScannerException? startError;
  final _barcodes = StreamController<BarcodeCapture?>.broadcast();

  void emit(List<String> codes) => _barcodes.add(BarcodeCapture(
        barcodes: [for (final c in codes) Barcode(rawValue: c)],
      ));

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodes.stream;

  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    if (startError != null) throw startError!;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(1080, 1920),
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<void> dispose() async {}
}
