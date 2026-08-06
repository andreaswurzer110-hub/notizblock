import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notizblock/widgets/sheet_body.dart';

/// Regressionsschutz für „Sprachauswahl abgeschnitten" (1.31.0):
/// Der Dialog enthielt die 13 Sprachen als einfache Spalte. Ein Dialog wächst
/// nur bis zum verfügbaren Platz und schneidet danach ab – die letzten
/// Sprachen waren auf Windows nicht erreichbar. [DialogBody] macht den Inhalt
/// scrollbar.
void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => AlertDialog(
              title: const Text('Sprache'),
              content: child,
            ),
          ),
        ),
      );

  testWidgets('lange Liste im Dialog ist scrollbar und vollständig erreichbar',
      (tester) async {
    // Kleines Fenster erzwingen, damit 13 Einträge sicher nicht hineinpassen.
    tester.view.physicalSize = const Size(500, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(
      DialogBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 13; i++) ListTile(title: Text('Sprache $i')),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Ohne Scrollmöglichkeit gäbe es hier einen Overflow-Fehler statt eines
    // Scrollable.
    expect(find.byType(Scrollbar), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Der letzte Eintrag ist zunächst außerhalb des Sichtbereichs, lässt sich
    // aber heranscrollen.
    await tester.scrollUntilVisible(find.text('Sprache 12'), 100,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Sprache 12'), findsOneWidget);
  });
}
