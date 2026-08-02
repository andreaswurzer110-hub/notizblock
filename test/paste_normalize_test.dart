import 'package:flutter_test/flutter_test.dart';
import 'package:notizblock/widgets/note_context_menu.dart';

/// Eingefügter Text aus Web/PDF bringt regelmäßig unsichtbare Sonderzeichen mit
/// (geschützte Leerzeichen, Zero-Width-Space, Bidi-Steuerzeichen). Die brauchen
/// eine andere Schrift als der übrige Text → die Zeile wird höher, der
/// eingefügte Absatz wirkt größer als der Rest der Notiz. Deshalb wird beim
/// Einfügen normalisiert – hier abgesichert.
void main() {
  String c(int code) => String.fromCharCode(code);

  test('geschützte/exotische Leerzeichen werden normale Leerzeichen', () {
    final input = 'Hallo${c(0x00A0)}Welt${c(0x2009)}heute${c(0x3000)}!';
    expect(normalizePastedText(input), 'Hallo Welt heute !');
  });

  test('unsichtbare Steuerzeichen werden entfernt', () {
    final input =
        'Te${c(0x200B)}xt${c(0x00AD)} mit${c(0xFEFF)} Resten${c(0x202A)}';
    expect(normalizePastedText(input), 'Text mit Resten');
  });

  test('Zeilenenden werden vereinheitlicht', () {
    final input = 'eins\r\nzwei\rdrei${c(0x2028)}vier${c(0x2029)}fünf';
    expect(normalizePastedText(input), 'eins\nzwei\ndrei\nvier\nfünf');
  });

  test('Zero-Width-Joiner bleibt erhalten (zusammengesetzte Emoji)', () {
    // Familie = mehrere Emoji, durch ZWJ verbunden. Ohne ZWJ zerfällt das Zeichen.
    final family = '\u{1F468}${c(0x200D)}\u{1F469}${c(0x200D)}\u{1F467}';
    expect(normalizePastedText(family), family);
  });

  test('normaler Text bleibt unverändert', () {
    const input = 'Ganz normaler Text mit Umlauten: äöü ß – und Link\nhttps://a.b';
    expect(normalizePastedText(input), input);
  });
}
