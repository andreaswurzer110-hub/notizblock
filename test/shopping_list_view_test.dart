import 'package:flutter/gestures.dart' show kLongPressTimeout, kPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';
import 'package:notizblock/widgets/shopping_list_view.dart';

/// Die Einkaufsliste läuft auch im **Sticky-Fenster**, das nur ein paar hundert
/// Pixel breit ist. Seit dem Anfasser fürs Umsortieren steht in einer Zeile
/// mehr nebeneinander (Anfasser, Name, Menge, Häkchen, Löschen) – passt das
/// nicht, meldet Flutter einen RenderFlex-Overflow und die Zeile ist im
/// Release nur ein gelb-schwarzer Balken. Deshalb hier festgenagelt.
///
/// ACHTUNG bei der Breiten-Wahl: Im Test rendert Flutter mit einer
/// Platzhalter-Schrift, in der JEDES Zeichen ein Quadrat der Schriftgröße ist –
/// „Artikel hinzufügen" misst hier ~256 px statt ~120 px. Ein Überlauf, der nur
/// an Text hängt, sagt also nichts über die echte App. Aussagekräftig ist
/// dagegen die Artikelzeile: sie besteht aus Symbolen fester Pixelgröße plus
/// dem Namensfeld, das den Rest bekommt.
void main() {
  Widget wrap(Widget child, double width) => MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      );

  const data = '['
      '{"name":"Zwiebeln"},'
      '{"name":"Äpfel","qty":3},'
      '{"name":"Butter","done":true}'
      ']';

  testWidgets('schmales Sticky-Fenster: keine Überläufe', (tester) async {
    await tester.pumpWidget(wrap(
      ShoppingListView(initialData: data, onChanged: (_) {}),
      260,
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Anfasser für jeden AKTIVEN Artikel (erledigte lassen sich nicht ziehen).
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));
    expect(find.byIcon(Icons.sort_by_alpha), findsOneWidget);
    // Für den Artikelnamen muss trotz Anfasser noch brauchbar Platz bleiben.
    expect(tester.getSize(find.byType(TextField).first).width,
        greaterThan(60.0));
  });

  group('Touch (Android)', () {
    setUp(() => ShoppingListViewState.debugForceDesktop = false);
    tearDown(() => ShoppingListViewState.debugForceDesktop = null);

    testWidgets('Anfasser hat KEINEN Tooltip', (tester) async {
      // Flutter loest Tooltips auf Touch per LANGEM DRUCK aus. Ein Tooltip am
      // Anfasser gewann damit gegen den Drag-Listener: statt zu ziehen kam nur
      // die Sprechblase "Verschieben", die wie ein toter Knopf wirkte (war real
      // ein Bug in 1.31.2).
      await tester.pumpWidget(wrap(
        ShoppingListView(initialData: data, onChanged: (_) {}),
        400,
      ));
      await tester.pumpAndSettle();

      expect(
        find.ancestor(
          of: find.byIcon(Icons.drag_indicator).first,
          matching: find.byType(Tooltip),
        ),
        findsNothing,
      );
    });

    testWidgets('langer Druck zieht die Zeile direkt', (tester) async {
      String? emitted;
      await tester.pumpWidget(wrap(
        ShoppingListView(initialData: data, onChanged: (j) => emitted = j),
        400,
      ));
      await tester.pumpAndSettle();

      final handles = find.byIcon(Icons.drag_indicator);
      final from = tester.getCenter(handles.at(0));
      final to = tester.getCenter(handles.at(1));

      final gesture = await tester.startGesture(from);
      // Erst nach der Long-Press-Verzoegerung greift der Drag-Listener.
      await tester.pump(kLongPressTimeout + kPressTimeout);
      // In Schritten ziehen: der MultiDrag-Erkenner braucht Bewegung, die
      // ueber mehrere Frames ankommt.
      await gesture.moveBy(Offset(0, (to.dy - from.dy) / 2));
      await tester.pump(kPressTimeout);
      await gesture.moveBy(Offset(0, (to.dy - from.dy) / 2 + 20));
      await tester.pump(kPressTimeout);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(emitted, isNotNull,
          reason: 'Ziehen hat keine Aenderung gemeldet - Geste kam nicht an');
      expect(emitted!.indexOf('Äpfel') < emitted!.indexOf('Zwiebeln'), isTrue,
          reason: 'Zwiebeln sollte hinter Äpfel liegen, war: $emitted');
    });
  });

  testWidgets('Sortier-Knopf erscheint erst ab zwei Artikeln', (tester) async {
    await tester.pumpWidget(wrap(
      ShoppingListView(initialData: '[{"name":"Milch"}]', onChanged: (_) {}),
      400,
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.sort_by_alpha), findsNothing);
  });

  testWidgets('Sortieren ordnet die Liste und meldet den neuen Stand',
      (tester) async {
    String? emitted;
    await tester.pumpWidget(wrap(
      ShoppingListView(initialData: data, onChanged: (j) => emitted = j),
      400,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.sort_by_alpha));
    await tester.pumpAndSettle();

    // A–Z, Umlaut beim Grundbuchstaben: Äpfel, Butter, Zwiebeln.
    expect(emitted, isNotNull);
    expect(
      emitted!.indexOf('Äpfel') < emitted!.indexOf('Butter') &&
          emitted!.indexOf('Butter') < emitted!.indexOf('Zwiebeln'),
      isTrue,
      reason: 'Erwartete Reihenfolge A–Z, war: $emitted',
    );

    // Zweiter Druck dreht auf Z–A.
    await tester.tap(find.byIcon(Icons.sort_by_alpha));
    await tester.pumpAndSettle();
    expect(
      emitted!.indexOf('Zwiebeln') < emitted!.indexOf('Äpfel'),
      isTrue,
      reason: 'Erwartete Reihenfolge Z–A, war: $emitted',
    );
  });
}
