import 'package:flutter/material.dart';

/// So weit wächst die Schrift höchstens mit der Systemeinstellung mit („ganz
/// groß“ am Handy bzw. Textgröße unter Windows). Gesetzt in beiden
/// `MaterialApp.builder` (Hauptapp und Notizzettel), geprüft durch
/// `test/text_scale_test.dart`.
const maxTextScale = 1.5;

/// Text, der lieber etwas kleiner wird, als ein Wort mitten drin umzubrechen
/// („Telefonnu-mmern“ im Kartentitel). Passt das längste Wort in die Breite,
/// ist es ein ganz normaler [Text]. Vorlage: Sabbatschul-App.
///
/// Anders als dort nie kleiner als [minSize] × die normale Schriftgröße (ohne
/// Systemvergrößerung): Titel sind Nutzertext – ein langer Link würde sonst
/// unlesbar klein, dann lieber doch umbrechen.
class WordSafeText extends StatelessWidget {
  const WordSafeText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.minSize = 0.75,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final double minSize;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final base = DefaultTextStyle.of(context).style.merge(style);
    return LayoutBuilder(
      builder: (context, box) {
        var shrink = 1.0;
        if (box.hasBoundedWidth && box.maxWidth > 0) {
          var longest = 0.0;
          for (final word in text.split(RegExp(r'\s+'))) {
            if (word.isEmpty) continue;
            final p = TextPainter(
              text: TextSpan(text: word, style: base),
              textScaler: scaler,
              textDirection: Directionality.of(context),
              maxLines: 1,
            )..layout();
            if (p.width > longest) longest = p.width;
            p.dispose();
          }
          if (longest > box.maxWidth) {
            final size = base.fontSize ?? 14;
            final floor = (minSize * size / scaler.scale(size)).clamp(0.0, 1.0);
            shrink = (box.maxWidth / longest * 0.98).clamp(floor, 1.0);
          }
        }
        return Text(
          text,
          style: style,
          maxLines: maxLines,
          overflow: overflow,
          textScaler: shrink < 1 ? TimesTextScaler(scaler, shrink) : null,
        );
      },
    );
  }
}

/// Eine Schriftskalierung mal einem festen Faktor (für [WordSafeText]).
class TimesTextScaler extends TextScaler {
  const TimesTextScaler(this.inner, this.factor);
  final TextScaler inner;
  final double factor;

  @override
  double scale(double fontSize) => inner.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => inner.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is TimesTextScaler &&
      other.inner == inner &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(inner, factor);
}
