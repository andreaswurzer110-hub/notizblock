import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';
import 'package:notizblock/models/note.dart';
import 'package:notizblock/screens/autopool_scan_screen.dart';
import 'package:notizblock/screens/sticky_note_screen.dart';
import 'package:notizblock/services/database_service.dart';
import 'package:notizblock/widgets/autopool_table.dart';
import 'package:notizblock/widgets/note_card.dart';
import 'package:notizblock/widgets/shopping_list_view.dart';
import 'package:notizblock/widgets/text_scale.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_scanner_platform.dart';

/// Wie Android ab Version 14 bei 200 %: kleine Schrift wächst stärker als
/// große (12 → 24, 24 → ~36, ab ~60 kaum noch).
class _Android14 extends TextScaler {
  const _Android14();
  @override
  double scale(double fontSize) =>
      fontSize * (2.0 - ((fontSize - 12) / 48).clamp(0.0, 1.0));
  @override
  double get textScaleFactor => 2.0;
}

/// Notizzettel-Test: DB und settings.json im Temp-Ordner statt in AppData.
class _TempPaths extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _TempPaths(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

/// Große Systemschrift (1.32.0): Bei der höchsten Stufe, die die App zulässt
/// (1,5-fach), passt auf einem schmalen Handy (360 Punkte) und im
/// Notizzettel-Fenster (320 px) alles. Gefunden mit einem Wegwerftest über alle
/// Hauptseiten: Werkzeugleiste im Notizzettel lief über (⋮ abgeschnitten),
/// „Artikel hi…“, Kartentitel „Telefonnu-mmern“.
void main() {
  final tmp = Directory.systemTemp.createTempSync('nb_textscale_');
  PathProviderPlatform.instance = _TempPaths(tmp.path);

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    for (final ch in ['window_manager', 'home_widget']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(ch), (_) async => null);
    }
  });

  // Echte Schrift, sonst meldet die klobige Testschrift Scheinüberläufe.
  Future<void> loadFonts(WidgetTester tester) async {
    final dir = '${Platform.environment['FLUTTER_ROOT']}'
        '/bin/cache/artifacts/material_fonts';
    if (!File('$dir/roboto-regular.ttf').existsSync()) return;
    await tester.runAsync(() async {
      final roboto = FontLoader('Roboto');
      for (final f in [
        'roboto-regular.ttf',
        'roboto-medium.ttf',
        'roboto-bold.ttf'
      ]) {
        roboto.addFont(Future.value(
            ByteData.sublistView(File('$dir/$f').readAsBytesSync())));
      }
      await roboto.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(
            File('$dir/materialicons-regular.otf').readAsBytesSync())));
      await icons.load();
    });
  }

  for (final (name, scaler) in [
    ('normal', TextScaler.noScaling),
    ('1,5-fach', const TextScaler.linear(maxTextScale)),
    ('Android 14 bei 200 %', const _Android14()),
  ]) {
    // Wie in der App: Systemschrift, dann auf maxTextScale begrenzt.
    Widget app(Widget home) => MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: scaler),
            child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: maxTextScale, child: child!),
          ),
          home: home,
        );

    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('$name: Kartentitel trennt kein Wort', (tester) async {
      await loadFonts(tester);
      phone(tester);
      Widget card(String title) => SizedBox(
            width: 170, // eine Spalte im Raster auf 360 Punkten
            child: NoteCard(
                note: Note(title: title, content: 'Arzt 01234'), onTap: () {}),
          );
      await tester.pumpWidget(app(Scaffold(
        body: Column(children: [card('Telefonnummern'), card('Kurz')]),
      )));
      expect(tester.takeException(), isNull);
      // Ganz in einer Zeile → nicht höher als ein kurzer einzeiliger Titel.
      final lang = tester.getSize(find.text('Telefonnummern')).height;
      final kurz = tester.getSize(find.text('Kurz')).height;
      expect(lang, lessThanOrEqualTo(kurz));
    });

    for (final (where, width) in [('Handy', 360.0), ('Notizzettel', 308.0)]) {
      testWidgets('$name: Einkaufsliste im $where ganz lesbar',
          (tester) async {
        await loadFonts(tester);
        phone(tester);
        await tester.pumpWidget(app(Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(
                child: ShoppingListView(
                  initialData: '[{"name":"Vollkornbrot","qty":2},'
                      '{"name":"Milch"},{"name":"Butter","done":true}]',
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        )));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Ganze Beschriftung, nicht „Artikel hi…“ (FittedBox verkleinert
        // höchstens), und der Sortierknopf bleibt im Bild.
        final label = find.text('Artikel hinzufügen');
        final p = tester.renderObject<RenderParagraph>(label);
        expect(p.size.width,
            greaterThanOrEqualTo(p.getMaxIntrinsicWidth(double.infinity) - 0.5));
        if (where == 'Handy') {
          // Auf dem Handy ist Platz genug: gar nicht verkleinert.
          expect(tester.getRect(label).width, closeTo(p.size.width, 0.5));
        }
        expect(tester.getRect(find.byIcon(Icons.sort_by_alpha)).right,
            lessThanOrEqualTo(width));
      });
    }

    testWidgets('$name: Autopool-Knöpfe unter der Tabelle ganz lesbar',
        (tester) async {
      await loadFonts(tester);
      phone(tester);
      await tester.pumpWidget(app(Scaffold(
        body: SingleChildScrollView(
          child: AutopoolTable(initialData: '', onChanged: (_) {}),
        ),
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // „Scannen“ rutscht notfalls in die nächste Zeile, abgeschnitten wird
      // keiner der beiden Knöpfe.
      for (final label in ['Zeile hinzufügen', 'Scannen']) {
        final p = tester.renderObject<RenderParagraph>(find.text(label));
        expect(p.size.width,
            greaterThanOrEqualTo(p.getMaxIntrinsicWidth(double.infinity) - 0.5));
        expect(tester.getRect(find.text(label)).right, lessThanOrEqualTo(360));
      }
    });

    testWidgets('$name: Autopool-Scanner passt aufs Handy', (tester) async {
      await loadFonts(tester);
      phone(tester);
      final camera = FakeScannerPlatform();
      final original = MobileScannerPlatform.instance;
      MobileScannerPlatform.instance = camera;
      addTearDown(() => MobileScannerPlatform.instance = original);
      await tester.pumpWidget(app(const AutopoolScanScreen(
        inventoryLabel: 'Inventarnummer',
        serialLabel: 'Seriennummer',
        dateLabel: 'Datum',
        date: '16.10.26',
      )));
      await tester.pumpAndSettle();
      // Beide Nummern erfasst: so voll wird die Feldleiste unten.
      for (final code in ['INV-2026-004711', 'SN-5CG1234XYZ']) {
        camera.emit([code]);
        await tester.pump(Duration.zero);
        await tester.pump(const Duration(seconds: 2));
      }
      expect(tester.takeException(), isNull);
      expect(find.text('SN-5CG1234XYZ'), findsOneWidget);
      // „Übernehmen“ ganz im Bild, und für die Kamera bleibt genug Platz.
      expect(tester.getRect(find.text('Übernehmen')).bottom,
          lessThanOrEqualTo(780));
      expect(tester.getSize(find.byType(MobileScanner)).height,
          greaterThan(250));
    });

    testWidgets('$name: Notizzettel-Leiste passt ins Fenster', (tester) async {
      await loadFonts(tester);
      tester.view.physicalSize = const Size(320, 340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final note = Note(title: '', content: 'Und was immer ihr tut');
      await tester.runAsync(() async {
        // Sicherung: nie in die echte Notizblock-DB unter AppData schreiben.
        expect((await getApplicationSupportDirectory()).path, tmp.path);
        await DatabaseService.instance.insertOrUpdateNotes([note]);
      });
      await tester.pumpWidget(app(StickyNoteScreen(noteId: note.id)));
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(tester.getRect(find.byIcon(Icons.more_vert)).right,
          lessThanOrEqualTo(320));
      // Abräumen: Timer des Fensters auslaufen lassen.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }

  test('Die App begrenzt die Systemschrift', () {
    expect(maxTextScale, 1.5);
    // Hauptapp und Notizzettel-Fenster.
    final main = File('lib/main.dart').readAsStringSync();
    final clamp =
        RegExp(r'withClampedTextScaling\(\s*maxScaleFactor: maxTextScale');
    expect(clamp.allMatches(main).length, 2);
  });
}
