import 'package:flutter_test/flutter_test.dart';
import 'package:notizblock/utils/steuerzeichen.dart';

void main() {
  group('anzeigeText', () {
    test('Windows-Zeilenenden werden zu \\n', () {
      expect(anzeigeText('a\r\nb\r\n\r\nc'), 'a\nb\n\nc');
    });

    test('einzelnes \\r wird zu \\n', () {
      expect(anzeigeText('a\rb'), 'a\nb');
    });

    test('Text ohne \\r bleibt dasselbe Objekt (keine Kopie)', () {
      const text = 'Zeile 1\nZeile 2';
      expect(identical(anzeigeText(text), text), isTrue);
    });
  });
}
