import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Bändigt das Mitscrollen beim Markieren von Text mit dem Finger.
///
/// **Das Problem (Android, gemeldet 2026-09-16):** Ein mehrzeiliges `TextField`
/// (`maxLines: null`) in einer `SingleChildScrollView` scrollt nicht selbst –
/// es scrollt die ganze Seite. Flutter ruft bei jeder Auswahl-Änderung
/// `renderEditable.showOnScreen(...)` auf, um die Auswahl im Bild zu halten;
/// mangels eigenem Scrollbereich landet das in der äußeren Fläche und hat zwei
/// üble Folgen:
///
///  * Das sichtbar zu machende Rechteck wird um `scrollPadding` + Anfasserhöhe
///    (~40 px) aufgeblasen. Jedes einzelne Touch-Event scrollt also ein gutes
///    Stück, und weil der Finger danach über ganz anderem Text steht, springt
///    die Auswahl gleich mit → „auf einmal geht es viel zu weit nach unten".
///    Weil Flutter pro Auswahl-Änderung `HapticFeedback.selectionClick()`
///    auslöst, wird daraus zugleich ein Dauer-Rütteln.
///  * Sichtbar gemacht wird immer das **Ende** der Auswahl
///    (`selectionBoxes.last`) – auch wenn der Finger am OBEREN Anfasser zieht.
///    Nach oben markieren scrollt deshalb gar nicht mit bzw. springt zurück.
///
/// Für das Ziehen an den Anfassern hat Flutter kein eigenes Auto-Scrollen
/// (anders als `SelectableRegion`, das dafür `EdgeDraggingAutoScroller` nutzt) –
/// dieses Aufblasen IST sein Auto-Scrollen. Deshalb übernimmt dieser Wächter es:
/// Er fängt `showOnScreen` ab, solange genau ein Auswahl-Ende wandert (= der
/// Finger zieht an einem Anfasser), hält **dieses** Ende im Bild und scrollt
/// dabei höchstens mit [RenderSelectionScrollGuard.speedPxPerSecond] – also
/// zeitabhängig statt pro Touch-Event.
///
/// Muss INNERHALB der Scrollfläche liegen (zwischen Viewport und Textfeld) und
/// bekommt deren [ScrollController]. Alles andere (Schreibmarke beim Tippen,
/// Tastatur-Ausweichen) läuft unverändert über Flutter.
class SelectionScrollGuard extends SingleChildRenderObjectWidget {
  const SelectionScrollGuard({
    super.key,
    required this.controller,
    required super.child,
  });

  /// Controller der umgebenden Scrollfläche (dieselbe Instanz wie dort).
  final ScrollController controller;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderSelectionScrollGuard(controller);

  @override
  void updateRenderObject(
      BuildContext context, RenderSelectionScrollGuard renderObject) {
    renderObject.controller = controller;
  }
}

class RenderSelectionScrollGuard extends RenderProxyBox {
  RenderSelectionScrollGuard(this._controller);

  ScrollController _controller;
  set controller(ScrollController value) => _controller = value;

  // Zuletzt gesehene Auswahl. Daraus ergibt sich, welches Ende der Finger zieht;
  // es kann immer nur an EINEM Textfeld gezogen werden, darum reicht ein Paar.
  RenderEditable? _lastEditable;
  TextSelection? _lastSelection;
  bool _dragging = false;
  int _unchangedCalls = 0;
  Duration _lastStep = Duration.zero;

  /// Höchsttempo des Mitscrollens beim Markieren (gut 15 Zeilen/s).
  static const double speedPxPerSecond = 420;

  /// Zeitfenster, das ein einzelner Schritt höchstens gutschreiben darf – ohne
  /// die Deckelung würde nach einer Pause der nächste Schritt weit springen.
  static const double _maxStepSeconds = 0.05;

  /// So viele Aufrufe mit unveränderter Auswahl gelten noch als „Ziehen läuft".
  /// Pro Touch-Event kommen zwei Aufrufe (einer davon ohne Änderung); bleibt es
  /// länger unverändert, ist das Ziehen vorbei und Flutter darf wieder ran.
  static const int _maxUnchangedCalls = 4;

  /// Nur auf Touch-Plattformen: Auf dem Desktop zieht die Maus die Auswahl
  /// direkt (ohne Anfasser), dort ist Flutters Verhalten in Ordnung.
  /// `defaultTargetPlatform` statt `Platform.isAndroid`, damit Widget-Tests die
  /// Plattform setzen können.
  static bool get _isTouchPlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    if (_handleSelectionDrag(descendant)) return;
    super.showOnScreen(
      descendant: descendant,
      rect: rect,
      duration: duration,
      curve: curve,
    );
  }

  /// true = übernommen (Flutters eigenes Scrollen unterbleibt).
  bool _handleSelectionDrag(RenderObject? descendant) {
    if (!_isTouchPlatform) return false;
    if (descendant is! RenderEditable || !descendant.attached) return false;

    final selection = descendant.selection;
    final previous = identical(descendant, _lastEditable) ? _lastSelection : null;
    _lastEditable = descendant;
    _lastSelection = selection;

    // Schreibmarke (keine Auswahl): Tippen/Tastatur – Flutter-Verhalten behalten.
    if (selection == null || !selection.isValid || selection.isCollapsed) {
      _dragging = false;
      return false;
    }

    final movedOffset = _movedEnd(previous, selection);
    if (movedOffset != null) {
      _dragging = true;
      _unchangedCalls = 0;
      _followCaret(descendant, movedOffset);
      return true;
    }

    // Gleiche Auswahl wie eben, mitten im Ziehen: Flutter würde hier trotzdem
    // das Auswahl-ENDE ins Bild holen – genau der Rücksprung. Schlucken.
    if (_dragging && previous == selection) {
      if (++_unchangedCalls <= _maxUnchangedCalls) return true;
      _dragging = false;
      return false;
    }

    // Wort-Antippen, „Alles auswählen", Tastatur – nicht unser Fall.
    _dragging = false;
    return false;
  }

  /// Offset des Auswahl-Endes, an dem der Finger zieht – oder null, wenn sich
  /// nicht genau ein Ende bewegt hat.
  static int? _movedEnd(TextSelection? previous, TextSelection current) {
    if (previous == null || !previous.isValid || previous.isCollapsed) {
      return null;
    }
    final baseMoved = previous.baseOffset != current.baseOffset;
    final extentMoved = previous.extentOffset != current.extentOffset;
    if (baseMoved == extentMoved) return null; // beide oder keiner
    return baseMoved ? current.baseOffset : current.extentOffset;
  }

  /// Das gezogene Ende im Bild halten – aber nur mit gedeckeltem Tempo.
  void _followCaret(RenderEditable editable, int offset) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    // Als RenderObject? deklariert, damit Dart auf RenderBox verengen kann
    // (RenderBox ist kein Untertyp von RenderAbstractViewport).
    final RenderObject? viewport = RenderAbstractViewport.maybeOf(this);
    if (viewport is! RenderBox || !viewport.attached) return;

    final caretLocal =
        editable.getLocalRectForCaret(TextPosition(offset: offset));
    final caret =
        MatrixUtils.transformRect(editable.getTransformTo(null), caretLocal);
    final view = viewport.localToGlobal(Offset.zero) & viewport.size;

    // Rand, ab dem mitgescrollt wird: gut eine Zeile, damit man sieht, wohin die
    // Markierung läuft – aber nie mehr als ein Drittel der Höhe.
    final margin = math.min(editable.preferredLineHeight * 1.5, view.height / 3);

    double want = 0;
    if (caret.bottom > view.bottom - margin) {
      want = caret.bottom - (view.bottom - margin);
    } else if (caret.top < view.top + margin) {
      want = caret.top - (view.top + margin); // negativ = nach oben
    }
    if (want == 0) return;

    // Zeit über den Frame-Zeitstempel messen (nicht über eine Stoppuhr): pro
    // Frame gibt es so genau einen Schritt, und Widget-Tests können die Zeit
    // über `pump(Dauer)` steuern.
    final stamp = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    final elapsed = stamp - _lastStep;
    _lastStep = stamp;
    if (elapsed <= Duration.zero) return; // selber Frame -> schon gescrollt
    final seconds = math.min(
      elapsed.inMicroseconds / Duration.microsecondsPerSecond,
      _maxStepSeconds,
    );

    final maxStep = speedPxPerSecond * seconds;
    final delta =
        want.abs() <= maxStep ? want : (want.isNegative ? -maxStep : maxStep);
    final target = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() > 0.5) position.jumpTo(target);
  }

  @override
  void detach() {
    _lastEditable = null;
    _lastSelection = null;
    _dragging = false;
    super.detach();
  }
}
