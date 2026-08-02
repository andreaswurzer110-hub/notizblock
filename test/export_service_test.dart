import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notizblock/models/note.dart';
import 'package:notizblock/services/export_service.dart';

/// Absicherung des Exports hinter „Drucken": Der .docx-Teil wird von Hand als
/// ZIP+XML gebaut – bricht dort etwas (fehlender Teil, unescapetes `&`), lässt
/// sich die Datei in Word gar nicht mehr öffnen. Das fällt sonst erst beim
/// Nutzer auf, deshalb hier geprüft.
void main() {
  const headers = [
    'Bezeichnung',
    'DS & Version',
    'Ort',
    'Inventarnummer',
    'Seriennummer',
    'Datum',
  ];

  Note textNote() => Note(
        title: 'Einkauf & Co',
        content: 'Zeile 1\nZeile <2>\nZeile "drei"',
      );

  test('Textfassung enthält Titel und Inhalt', () {
    final text = ExportService.buildPlainText(textNote(),
        autopoolHeaders: headers);
    expect(text, contains('Einkauf & Co'));
    expect(text, contains('Zeile <2>'));
  });

  test('Einkaufsliste: erledigte Artikel werden angehakt', () {
    final note = Note(
      title: 'Liste',
      content: '',
      type: 'shopping',
      autopoolData: '[{"name":"Milch","qty":2},{"name":"Butter","done":true}]',
    );
    final text =
        ExportService.buildPlainText(note, autopoolHeaders: headers);
    expect(text, contains('[ ] 2x Milch'));
    expect(text, contains('[x] Butter'));
  });

  test('docx ist ein ZIP mit den drei Pflicht-Teilen', () {
    final bytes = ExportService.buildDocx(textNote(), autopoolHeaders: headers);
    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((f) => f.name).toSet();
    expect(names, containsAll(<String>[
      '[Content_Types].xml',
      '_rels/.rels',
      'word/document.xml',
    ]));
  });

  test('docx: Sonderzeichen sind XML-escaped (sonst kaputte Datei)', () {
    final bytes = ExportService.buildDocx(textNote(), autopoolHeaders: headers);
    final archive = ZipDecoder().decodeBytes(bytes);
    final doc = archive.files.firstWhere((f) => f.name == 'word/document.xml');
    final xml = utf8.decode(doc.content as List<int>);
    expect(xml, contains('Einkauf &amp; Co'));
    expect(xml, contains('Zeile &lt;2&gt;'));
    expect(xml, isNot(contains('Zeile <2>')));
    // Jede Zeile wird ein eigener Absatz (Word kennt kein \n im Text-Run).
    expect('<w:p>'.allMatches(xml).length, greaterThanOrEqualTo(4));
  });

  test('docx der Autopool-Notiz enthält eine Tabelle mit Überschriften', () {
    final note = Note(
      title: 'Geräte',
      content: '',
      type: 'autopool',
      autopoolData: '[{"cells":["Laptop","DS 1","Wien","","",""],"marked":false}]',
    );
    final bytes = ExportService.buildDocx(note, autopoolHeaders: headers);
    final archive = ZipDecoder().decodeBytes(bytes);
    final doc = archive.files.firstWhere((f) => f.name == 'word/document.xml');
    final xml = utf8.decode(doc.content as List<int>);
    expect(xml, contains('<w:tbl>'));
    expect(xml, contains('DS &amp; Version'));
    expect(xml, contains('Laptop'));
  });

  test('PDF wird erzeugt und beginnt mit der PDF-Signatur', () async {
    final bytes =
        await ExportService.buildPdf(textNote(), autopoolHeaders: headers);
    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
