import 'package:flutter/material.dart';

/// Standard-Rahmen für die Bottom-Sheets der App (Optionen-Menüs, Auswahl-
/// Listen mit fester Länge).
///
/// Warum: Ein `showModalBottomSheet` begrenzt seine Höhe von Haus aus auf einen
/// Bruchteil des Fensters und schneidet längeren Inhalt einfach ab. Auf dem
/// Desktop fällt das schon bei normaler Fenstergröße auf – das Dreipunkte-Menü
/// im Editor war unten abgeschnitten und nicht erreichbar (war real ein Bug in
/// 1.29.0). Deshalb hier: Höhe auf [maxHeightFactor] der Fensterhöhe begrenzen,
/// Inhalt scrollbar machen und die **Scrollleiste dauerhaft** anzeigen, damit
/// sichtbar ist, dass es weitergeht.
///
/// WICHTIG: Das Sheet zusätzlich mit `isScrollControlled: true` öffnen, sonst
/// bleibt die Deckelung bei ~9/16 der Fensterhöhe bestehen.
///
/// NICHT für Sheets verwenden, die selbst eine `ListView`/`Flexible` mitbringen
/// (z.B. Notiz-Auswahl) – die scrollen bereits selbst.
class SheetBody extends StatefulWidget {
  final Widget child;
  final double maxHeightFactor;

  const SheetBody({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.85,
  });

  @override
  State<SheetBody> createState() => _SheetBodyState();
}

/// Dasselbe für den Inhalt eines [AlertDialog].
///
/// Ein Dialog wächst mit seinem Inhalt, bis der Platz ausgeht – danach wird
/// **abgeschnitten**, ohne Scrollmöglichkeit. Bei der Sprachauswahl mit 13
/// Einträgen waren die letzten dadurch auf Windows nicht mehr erreichbar (war
/// real ein Bug in 1.31.0). Also: Auswahllisten in Dialogen immer hier
/// einpacken – dann bleibt der Dialog innerhalb des Fensters und der Inhalt
/// scrollt mit sichtbarer Scrollleiste.
class DialogBody extends StatefulWidget {
  final Widget child;

  /// Feste Breite, damit der Dialog bei kurzen Einträgen nicht schmal wird.
  final double width;

  const DialogBody({super.key, required this.child, this.width = 320});

  @override
  State<DialogBody> createState() => _DialogBodyState();
}

class _DialogBodyState extends State<DialogBody> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _controller,
          child: widget.child,
        ),
      ),
    );
  }
}

class _SheetBodyState extends State<SheetBody> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight =
        MediaQuery.of(context).size.height * widget.maxHeightFactor;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _controller,
          child: SafeArea(child: widget.child),
        ),
      ),
    );
  }
}
