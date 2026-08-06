import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:notizblock/services/sticky_note_service.dart';

/// Regressionsschutz für „Widget öffnet sich nicht mehr" (1.29.2):
/// Der 2-Sekunden-Poll hat die Fensterlage eines MINIMIERTEN Fensters
/// gespeichert. Windows meldet dafür -32000/-32000 in Titelleisten-Größe →
/// das Widget ging danach bei jedem Start unsichtbar außerhalb des Bildschirms
/// auf und war auch durch neues Anheften nicht zurückzuholen.
void main() {
  test('normale Fensterlagen werden akzeptiert', () {
    expect(
      StickyNoteService.isPlausibleBounds(const Rect.fromLTWH(76, 187, 362, 572)),
      isTrue,
    );
    // Zweiter Monitor links vom Hauptmonitor = negative X-Werte, völlig normal.
    expect(
      StickyNoteService.isPlausibleBounds(
          const Rect.fromLTWH(-1349, 19, 320, 827)),
      isTrue,
    );
  });

  test('minimiertes Fenster (Windows-Platzhalterlage) wird verworfen', () {
    expect(
      StickyNoteService.isPlausibleBounds(
          const Rect.fromLTWH(-32000, -32000, 160, 39)),
      isFalse,
    );
  });

  test('entartete Größen werden verworfen', () {
    expect(StickyNoteService.isPlausibleBounds(const Rect.fromLTWH(100, 100, 0, 0)),
        isFalse);
    expect(
        StickyNoteService.isPlausibleBounds(const Rect.fromLTWH(100, 100, 80, 400)),
        isFalse);
    expect(
        StickyNoteService.isPlausibleBounds(const Rect.fromLTWH(100, 100, 400, 40)),
        isFalse);
  });

  test('NaN/Unendlich werden verworfen', () {
    expect(
      StickyNoteService.isPlausibleBounds(
          Rect.fromLTWH(double.nan, 10, 300, 300)),
      isFalse,
    );
    expect(
      StickyNoteService.isPlausibleBounds(
          Rect.fromLTWH(10, 10, double.infinity, 300)),
      isFalse,
    );
  });
}
