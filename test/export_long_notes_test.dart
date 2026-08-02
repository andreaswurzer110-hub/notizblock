import 'package:flutter_test/flutter_test.dart';
import 'package:notizblock/models/note.dart';
import 'package:notizblock/services/export_service.dart';

/// Regressionsschutz für den Fehler „Drucken geht nicht, wenn die Notiz zu lang
/// ist" (1.29.0): Der Inhalt lag als EIN `pw.Text` in der `MultiPage`. Ohne
/// `overflow: TextOverflow.span` kann so ein Text nicht über Seiten umbrochen
/// werden → Notizen, die länger als eine Seite sind, scheiterten mit
/// „Widget won't fit into the page"; im Release-Build (dort ist die
/// Seitenzahl-Bremse der MultiPage per assert deaktiviert) endete das in einer
/// Endlosschleife mit „Out of Memory" auf dem Handy.
///
/// Diese Tests bauen bewusst Notizen, die mehrere Seiten füllen.
void main() {
  const headers = [
    'Bezeichnung',
    'DS & Version',
    'Ort',
    'Inventarnummer',
    'Seriennummer',
    'Datum',
  ];

  Future<void> expectPdf(Note note) async {
    final bytes = await ExportService.buildPdf(note, autopoolHeaders: headers);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    // Mehrere Seiten -> deutlich größer als ein Einzeiler-PDF.
    expect(bytes.length, greaterThan(3000));
  }

  test('lange Textnotiz mit vielen Zeilen', () async {
    final content =
        List.generate(400, (i) => 'Zeile $i mit etwas Text drin.').join('\n');
    await expectPdf(Note(title: 'Lange Notiz', content: content));
  });

  test('ein einziger sehr langer Absatz ohne Zeilenumbrüche', () async {
    await expectPdf(Note(title: 'Absatz', content: 'Wort ' * 8000));
  });

  test('Autopool-Tabelle über mehrere Seiten', () async {
    final rows = List.generate(
      300,
      (i) => '{"cells":["Gerät $i","DS $i","Ort $i","INV$i","SN$i",'
          '"1.1.2026"],"marked":false}',
    );
    await expectPdf(Note(
      title: 'Geräteliste',
      content: '',
      type: 'autopool',
      autopoolData: '[${rows.join(',')}]',
    ));
  });

  test('Einkaufsliste über mehrere Seiten', () async {
    final items = List.generate(400, (i) => '{"name":"Artikel $i"}');
    await expectPdf(Note(
      title: 'Großeinkauf',
      content: '',
      type: 'shopping',
      autopoolData: '[${items.join(',')}]',
    ));
  });
}
