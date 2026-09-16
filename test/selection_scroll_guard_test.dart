import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notizblock/widgets/selection_scroll_guard.dart';

/// Sichert das Bändigen des Mitscrollens beim Markieren ab (siehe
/// `widgets/selection_scroll_guard.dart`). Jeder Test misst zuerst die
/// UNGESCHÜTZTE Variante derselben Seite – absolute Pixelwerte hängen von
/// Schrift und Testtakt ab, der Unterschied zur ungeschützten Seite nicht.
void main() {
  // Nur Touch-Plattformen sind betroffen (der Wächter greift nur dort). Über
  // `variant` statt setUp/tearDown, sonst meckert das Testgerüst über die
  // gesetzte Debug-Variable.
  final androidOnly = TargetPlatformVariant.only(TargetPlatform.android);

  const viewportHeight = 320.0;
  // Ein Bildschirmtakt: Der Wächter rechnet zeitabhängig, deshalb muss die
  // Testuhr wie im echten Betrieb weiterlaufen.
  const frame = Duration(milliseconds: 16);
  // So viele Zieh-Schritte pro Test (= so viele Bildschirmtakte).
  const steps = 30;
  final longText =
      List.generate(200, (i) => 'Zeile $i mit etwas Text darin').join('\n');

  /// Baut die Editor-Seite: hohes Textfeld (`maxLines: null`) in einer
  /// Scrollfläche, wahlweise mit dem Wächter dazwischen. Die Fläche liegt am
  /// Bildschirmursprung, Bildschirm- und Flächenkoordinaten sind also gleich.
  Future<ScrollController> pumpPage(
    WidgetTester tester, {
    required bool withGuard,
  }) async {
    final text = TextEditingController(text: longText);
    addTearDown(text.dispose);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final field = TextField(controller: text, maxLines: null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              height: viewportHeight,
              child: SingleChildScrollView(
                controller: scroll,
                child: withGuard
                    ? SelectionScrollGuard(controller: scroll, child: field)
                    : field,
              ),
            ),
          ),
        ),
      ),
    );
    return scroll;
  }

  RenderEditable findRenderEditable(WidgetTester tester) {
    final root = tester.renderObject(find.byType(EditableText));
    RenderEditable? found;
    void search(RenderObject child) {
      if (found != null) return;
      if (child is RenderEditable) {
        found = child;
        return;
      }
      child.visitChildren(search);
    }

    root.visitChildren(search);
    return found!;
  }

  /// Bildschirmpunkte der beiden Auswahl-Enden (Anfasser hängen knapp darunter).
  List<Offset> endpoints(WidgetTester tester, TextSelection selection) {
    final editable = findRenderEditable(tester);
    return editable
        .getEndpointsForSelection(selection)
        .map((p) => editable.localToGlobal(p.point))
        .toList();
  }

  /// Wort bei [pressAt] markieren (das erzeugt die Anfasser), dann den unteren
  /// (`end: true`) bzw. oberen Anfasser in kleinen Schritten ziehen – wie ein
  /// Finger, der über den sichtbaren Bereich hinaus markieren will.
  Future<void> dragHandle(
    WidgetTester tester, {
    required bool end,
    required Offset pressAt,
    required double stepY,
    int dragSteps = steps,
  }) async {
    await tester.longPressAt(pressAt);
    await tester.pumpAndSettle();

    final selection =
        tester.widget<TextField>(find.byType(TextField)).controller!.selection;
    expect(selection.isCollapsed, isFalse,
        reason: 'Long-Press muss ein Wort markieren');

    final points = endpoints(tester, selection);
    final gesture =
        await tester.startGesture(points[end ? 1 : 0] + const Offset(0, 2));
    await tester.pump(frame);
    for (var i = 0; i < dragSteps; i++) {
      await gesture.moveBy(Offset(0, stepY));
      await tester.pump(frame);
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('Markieren nach unten läuft nicht davon', (tester) async {
    // Ohne Wächter: Flutter bläht das sichtbar zu machende Rechteck pro
    // Touch-Event um scrollPadding + Anfasserhöhe auf -> die Seite rast weg.
    final ungeschuetzt = await pumpPage(tester, withGuard: false);
    final ohneStart = ungeschuetzt.offset;
    await dragHandle(tester,
        end: true, pressAt: const Offset(40, 60), stepY: 14);
    final ohne = ungeschuetzt.offset - ohneStart;

    final geschuetzt = await pumpPage(tester, withGuard: true);
    // Der zweite pumpWidget-Durchlauf übernimmt die Scrollposition des ersten
    // (gleicher Baum) -> gemessen wird der Weg, nicht der absolute Stand.
    final mitStart = geschuetzt.offset;
    await dragHandle(tester,
        end: true, pressAt: const Offset(40, 60), stepY: 14);
    final mit = geschuetzt.offset - mitStart;

    // Gezogen wird rund eine halbe Sekunde -> der Wächter darf höchstens
    // speedPxPerSecond * 0,5 s scrollen; ungebremst ist es ein Vielfaches.
    const erlaubt =
        RenderSelectionScrollGuard.speedPxPerSecond * (steps + 1) * 0.016;
    expect(ohne, greaterThan(erlaubt * 2),
        reason: "Ausgangslage: ungebremst scrollt es weit ($ohne px)");
    expect(mit, lessThanOrEqualTo(erlaubt + 1),
        reason: "mit Wächter höchstens Tempolimit ($mit von $erlaubt px)");
    expect(mit, greaterThan(50),
        reason: 'es muss aber mitscrollen, sonst kommt man nicht weiter');
  }, variant: androidOnly);

  testWidgets('Markieren nach oben springt nicht nach unten zurück',
      (tester) async {
    // Ohne Wächter macht Flutter beim OBEREN Anfasser trotzdem das Auswahl-ENDE
    // sichtbar -> die Seite springt nach unten, man kommt nicht nach oben.
    final ungeschuetzt = await pumpPage(tester, withGuard: false);
    ungeschuetzt.jumpTo(400);
    await tester.pump();
    await dragHandle(tester,
        end: false, pressAt: const Offset(40, 250), stepY: -14);
    final ohne = ungeschuetzt.offset - 400;

    final geschuetzt = await pumpPage(tester, withGuard: true);
    geschuetzt.jumpTo(400);
    await tester.pump();
    await dragHandle(tester,
        end: false, pressAt: const Offset(40, 250), stepY: -14);
    final mit = geschuetzt.offset - 400;

    // Ungebremst folgt die Seite dem oberen Anfasser NICHT (Flutter hält das
    // Auswahl-Ende im Bild) – mit Wächter läuft sie sauber nach oben mit.
    expect(ohne, greaterThan(-50),
        reason: "Ausgangslage: ungebremst folgt es nicht nach oben ($ohne px)");
    expect(mit, lessThan(-100),
        reason: "mit Wächter läuft die Seite nach oben mit ($mit px)");
  }, variant: androidOnly);
}
