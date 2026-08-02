import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/autopool.dart';
import '../models/note.dart';
import '../models/shopping_list.dart';

/// Ausgabeformate des Kontextmenü-Eintrags „Drucken".
enum ExportFormat { pdf, txt, docx }

/// Erzeugt aus einer Notiz eine druck-/exportierbare Datei (PDF, TXT, Word)
/// und übergibt sie an den System-Druckdialog bzw. an einen „Speichern unter"-
/// Dialog.
///
/// Alle drei Notiz-Typen werden unterstützt: Textnotiz (Titel + Inhalt),
/// Autopool (echte Tabelle) und Einkaufsliste (Kästchen ☐/☑). Die Daten kommen
/// dabei IMMER aus der strukturierten Fassung (`autopoolData`), nicht aus der
/// `content`-Textfassung – so entspricht der Ausdruck der Bildschirmansicht.
///
/// Word (.docx) wird bewusst ohne Fremdpaket erzeugt: ein .docx ist ein ZIP mit
/// ein paar XML-Teilen ([Content_Types].xml, _rels/.rels, word/document.xml),
/// das reicht für Word/LibreOffice/Google Docs vollständig aus.
class ExportService {
  ExportService._();

  /// Spaltenüberschriften einer Autopool-Tabelle in der App-Sprache. Muss der
  /// Aufrufer mitgeben (der Service kennt keinen BuildContext/l10n).
  ///
  /// Für Text-/Einkaufslisten-Notizen irrelevant.
  static const int _maxHeaders = kAutopoolColCount;

  // --- Öffentliche API ---------------------------------------------------

  /// Notiz an den System-Druckdialog übergeben (Android/Windows/Linux).
  /// Liefert false, wenn der Nutzer abbricht.
  static Future<bool> printNote(
    Note note, {
    required List<String> autopoolHeaders,
  }) async {
    final bytes = await buildPdf(note, autopoolHeaders: autopoolHeaders);
    return Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: _baseFileName(note),
    );
  }

  /// Notiz in eine Datei exportieren. Zeigt den „Speichern unter"-Dialog des
  /// Systems und liefert den gespeicherten Pfad – oder null bei Abbruch.
  static Future<String?> exportNote(
    Note note,
    ExportFormat format, {
    required List<String> autopoolHeaders,
  }) async {
    final Uint8List bytes;
    switch (format) {
      case ExportFormat.pdf:
        bytes = await buildPdf(note, autopoolHeaders: autopoolHeaders);
        break;
      case ExportFormat.txt:
        bytes = Uint8List.fromList(
            utf8.encode(buildPlainText(note, autopoolHeaders: autopoolHeaders)));
        break;
      case ExportFormat.docx:
        bytes = buildDocx(note, autopoolHeaders: autopoolHeaders);
        break;
    }
    return _save(bytes, '${_baseFileName(note)}.${extensionOf(format)}', format);
  }

  static String extensionOf(ExportFormat f) {
    switch (f) {
      case ExportFormat.pdf:
        return 'pdf';
      case ExportFormat.txt:
        return 'txt';
      case ExportFormat.docx:
        return 'docx';
    }
  }

  // --- Speichern ---------------------------------------------------------

  /// „Speichern unter"-Dialog. Auf Desktop liefert der Dialog nur den Pfad –
  /// geschrieben wird hier selbst (verlässlicher als das optionale `bytes`-
  /// Verhalten des Plugins). Auf Android/iOS übernimmt das Plugin das Schreiben
  /// über den System-Dateidialog (SAF), dort MÜSSEN die Bytes mitgegeben werden.
  static Future<String?> _save(
      Uint8List bytes, String fileName, ExportFormat format) async {
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final path = await FilePicker.saveFile(
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extensionOf(format)],
      bytes: isDesktop ? null : bytes,
      lockParentWindow: true,
    );
    if (path == null) return null;
    if (isDesktop) {
      // Manche Dialoge liefern den Namen ohne Endung zurück -> ergänzen.
      final target =
          path.toLowerCase().endsWith('.${extensionOf(format)}')
              ? path
              : '$path.${extensionOf(format)}';
      await File(target).writeAsBytes(bytes, flush: true);
      return target;
    }
    return path;
  }

  /// Dateiname ohne Endung: Notiztitel, von Zeichen befreit, die Windows/Linux
  /// in Dateinamen verbieten.
  static String _baseFileName(Note note) {
    var name = note.title.trim();
    if (name.isEmpty) name = 'Notiz';
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (name.length > 60) name = name.substring(0, 60).trim();
    if (name.isEmpty) name = 'Notiz';
    return name;
  }

  // --- Inhalt aufbereiten ------------------------------------------------

  /// Kopfzeile unter dem Titel: Ordner + Änderungsdatum.
  static String _subtitle(Note note) {
    final date = DateFormat('d.M.yyyy, HH:mm').format(note.modifiedAt);
    return note.folder.isEmpty ? date : '${note.folder} · $date';
  }

  /// Reine Textfassung (auch die Grundlage des .txt-Exports).
  static String buildPlainText(
    Note note, {
    required List<String> autopoolHeaders,
  }) {
    final buf = StringBuffer();
    if (note.title.trim().isNotEmpty) {
      buf.writeln(note.title.trim());
      buf.writeln('=' * note.title.trim().length);
      buf.writeln();
    }
    if (note.isAutopool) {
      final data = AutopoolData.fromJsonString(note.autopoolData);
      final headers = _headers(data, autopoolHeaders);
      for (final row in data.rows) {
        if (row.cells.every((c) => c.trim().isEmpty)) continue;
        for (var i = 0; i < row.cells.length; i++) {
          final value = row.cells[i].trim();
          if (value.isEmpty) continue;
          buf.writeln('${i < headers.length ? headers[i] : ''}: $value');
        }
        buf.writeln();
      }
    } else if (note.isShopping) {
      final data = ShoppingListData.fromJsonString(note.autopoolData);
      for (final item in data.items) {
        if (item.name.trim().isEmpty) continue;
        final qty = item.quantity > 1 ? '${item.quantity}x ' : '';
        buf.writeln('${item.done ? '[x]' : '[ ]'} $qty${item.name.trim()}');
      }
    } else {
      buf.writeln(note.content);
    }
    return buf.toString().trimRight();
  }

  /// Überschriften einer Autopool-Tabelle: eigene, sonst die mitgegebenen
  /// Standardüberschriften der App-Sprache.
  static List<String> _headers(AutopoolData data, List<String> defaults) {
    return [
      for (var i = 0; i < _maxHeaders; i++)
        (data.headers != null && i < data.headers!.length
                ? data.headers![i]
                : null) ??
            (i < defaults.length ? defaults[i] : ''),
    ];
  }

  // --- PDF ---------------------------------------------------------------

  /// PDF der Notiz (A4). Wird auch fürs Drucken verwendet.
  static Future<Uint8List> buildPdf(
    Note note, {
    required List<String> autopoolHeaders,
  }) async {
    final base = await _pdfFont();
    final bold = await _pdfFont(bold: true);
    final theme = pw.ThemeData.withFont(base: base, bold: bold);
    final doc = pw.Document(title: _baseFileName(note), theme: theme);

    final content = <pw.Widget>[];
    if (note.isAutopool) {
      content.add(_pdfAutopool(note, autopoolHeaders, bold));
    } else if (note.isShopping) {
      content.addAll(_pdfShopping(note));
    } else if (note.content.trim().isNotEmpty) {
      content.add(pw.Text(note.content.trimRight(),
          style: const pw.TextStyle(fontSize: 11, lineSpacing: 3)));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Text(note.title.trim(),
                    style: pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey600, font: base)),
              ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ),
        build: (ctx) => [
          if (note.title.trim().isNotEmpty)
            pw.Text(note.title.trim(),
                style: pw.TextStyle(fontSize: 20, font: bold)),
          pw.SizedBox(height: 4),
          pw.Text(_subtitle(note),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.Divider(height: 16, color: PdfColors.grey400),
          ...content,
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _pdfAutopool(
      Note note, List<String> defaults, pw.Font bold) {
    final data = AutopoolData.fromJsonString(note.autopoolData);
    final headers = _headers(data, defaults);
    // Spaltenzahl = längste Zeile (verkürzte Zeilen füllen rechts mit '').
    var cols = 2;
    for (final r in data.rows) {
      if (r.cells.every((c) => c.trim().isEmpty)) continue;
      if (r.cells.length > cols) cols = r.cells.length;
    }
    final rows = <List<String>>[
      for (final r in data.rows)
        if (!r.cells.every((c) => c.trim().isEmpty))
          [
            for (var i = 0; i < cols; i++)
              i < r.cells.length ? r.cells[i].trim() : '',
          ],
    ];
    if (rows.isEmpty) return pw.SizedBox();
    return pw.TableHelper.fromTextArray(
      headers: headers.take(cols).toList(),
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
      headerStyle: pw.TextStyle(fontSize: 9, font: bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellHeight: 16,
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  static List<pw.Widget> _pdfShopping(Note note) {
    final data = ShoppingListData.fromJsonString(note.autopoolData);
    pw.Widget line(ShoppingItem i) {
      final qty = i.quantity > 1 ? '${i.quantity}x ' : '';
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Kästchen als Zeichnung statt Unicode-Zeichen – so ist es von der
            // verfügbaren Schrift unabhängig.
            pw.Container(
              width: 9,
              height: 9,
              margin: const pw.EdgeInsets.only(top: 2, right: 6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey700, width: 0.7),
                color: i.done ? PdfColors.grey500 : null,
              ),
            ),
            pw.Expanded(
              child: pw.Text('$qty${i.name.trim()}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    decoration:
                        i.done ? pw.TextDecoration.lineThrough : null,
                    color: i.done ? PdfColors.grey600 : null,
                  )),
            ),
          ],
        ),
      );
    }

    return [
      for (final i in data.active)
        if (i.name.trim().isNotEmpty) line(i),
      for (final i in data.completed)
        if (i.name.trim().isNotEmpty) line(i),
    ];
  }

  // Zwischengespeicherte PDF-Schriften (Laden kostet I/O).
  static final Map<bool, pw.Font> _fontCache = {};

  /// Schrift fürs PDF. Die eingebauten PDF-Standardschriften (Helvetica) können
  /// nur Latin-1 – Zeichen wie „•", „→" oder Emoji würden als Kästchen landen.
  /// Deshalb zuerst eine Systemschrift einbetten (die gibt es auf allen drei
  /// Zielplattformen); erst wenn keine gefunden wird, Helvetica.
  static Future<pw.Font> _pdfFont({bool bold = false}) async {
    final cached = _fontCache[bold];
    if (cached != null) return cached;
    for (final path in bold ? _boldFontPaths : _regularFontPaths) {
      try {
        final file = File(path);
        if (!await file.exists()) continue;
        final font = pw.Font.ttf(
            ByteData.sublistView(Uint8List.fromList(await file.readAsBytes())));
        _fontCache[bold] = font;
        return font;
      } catch (e) {
        debugPrint('PDF-Schrift $path nicht nutzbar: $e');
      }
    }
    final fallback = bold ? pw.Font.helveticaBold() : pw.Font.helvetica();
    _fontCache[bold] = fallback;
    return fallback;
  }

  static List<String> get _regularFontPaths {
    if (Platform.isAndroid) {
      return const [
        '/system/fonts/Roboto-Regular.ttf',
        '/system/fonts/NotoSans-Regular.ttf',
        '/system/fonts/DroidSans.ttf',
      ];
    }
    if (Platform.isWindows) {
      final dir = Platform.environment['WINDIR'] ?? r'C:\Windows';
      return ['$dir\\Fonts\\arial.ttf', '$dir\\Fonts\\segoeui.ttf'];
    }
    return const [
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
      '/usr/share/fonts/TTF/DejaVuSans.ttf',
      '/snap/notizblock-aw/current/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    ];
  }

  static List<String> get _boldFontPaths {
    if (Platform.isAndroid) {
      return const [
        '/system/fonts/Roboto-Bold.ttf',
        '/system/fonts/NotoSans-Bold.ttf',
        '/system/fonts/DroidSans-Bold.ttf',
      ];
    }
    if (Platform.isWindows) {
      final dir = Platform.environment['WINDIR'] ?? r'C:\Windows';
      return ['$dir\\Fonts\\arialbd.ttf', '$dir\\Fonts\\segoeuib.ttf'];
    }
    return const [
      '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
      '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
      '/usr/share/fonts/TTF/DejaVuSans-Bold.ttf',
      '/snap/notizblock-aw/current/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
    ];
  }

  // --- Word (.docx) ------------------------------------------------------

  /// Minimales, gültiges .docx (Open XML): ZIP aus [Content_Types].xml,
  /// _rels/.rels und word/document.xml. Word, LibreOffice und Google Docs
  /// öffnen das direkt; Bilder/Styles braucht eine reine Textnotiz nicht.
  static Uint8List buildDocx(
    Note note, {
    required List<String> autopoolHeaders,
  }) {
    final body = StringBuffer();
    if (note.title.trim().isNotEmpty) {
      body.write(_docxParagraph(note.title.trim(), bold: true, halfPt: 32));
    }
    body.write(_docxParagraph(_subtitle(note), halfPt: 16, grey: true));

    if (note.isAutopool) {
      final data = AutopoolData.fromJsonString(note.autopoolData);
      final headers = _headers(data, autopoolHeaders);
      var cols = 2;
      for (final r in data.rows) {
        if (r.cells.every((c) => c.trim().isEmpty)) continue;
        if (r.cells.length > cols) cols = r.cells.length;
      }
      final rows = <List<String>>[
        headers.take(cols).toList(),
        for (final r in data.rows)
          if (!r.cells.every((c) => c.trim().isEmpty))
            [
              for (var i = 0; i < cols; i++)
                i < r.cells.length ? r.cells[i].trim() : '',
            ],
      ];
      body.write(_docxTable(rows));
    } else if (note.isShopping) {
      final data = ShoppingListData.fromJsonString(note.autopoolData);
      for (final i in [...data.active, ...data.completed]) {
        if (i.name.trim().isEmpty) continue;
        final qty = i.quantity > 1 ? '${i.quantity}x ' : '';
        body.write(_docxParagraph(
            '${i.done ? '[x]' : '[  ]'} $qty${i.name.trim()}',
            strike: i.done));
      }
    } else {
      // Jede Zeile ein eigener Absatz (Word kennt kein „\n" innerhalb eines).
      for (final line in note.content.trimRight().split('\n')) {
        body.write(_docxParagraph(line));
      }
    }

    const contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>';
    const rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
        'Target="word/document.xml"/>'
        '</Relationships>';
    final document = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>$body'
        '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"/>'
        '</w:sectPr></w:body></w:document>';

    final archive = Archive()
      ..addFile(_zipEntry('[Content_Types].xml', contentTypes))
      ..addFile(_zipEntry('_rels/.rels', rels))
      ..addFile(_zipEntry('word/document.xml', document));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static ArchiveFile _zipEntry(String name, String xml) {
    final bytes = utf8.encode(xml);
    return ArchiveFile(name, bytes.length, bytes);
  }

  /// Ein Word-Absatz. [halfPt] = Schriftgröße in halben Punkt (Word-Einheit;
  /// 22 = 11 pt).
  static String _docxParagraph(String text,
      {bool bold = false,
      bool strike = false,
      bool grey = false,
      int halfPt = 22}) {
    final props = StringBuffer('<w:rPr>');
    if (bold) props.write('<w:b/>');
    if (strike) props.write('<w:strike/>');
    if (grey) props.write('<w:color w:val="777777"/>');
    props.write('<w:sz w:val="$halfPt"/><w:szCs w:val="$halfPt"/></w:rPr>');
    return '<w:p><w:pPr><w:spacing w:after="80"/></w:pPr>'
        '<w:r>$props<w:t xml:space="preserve">${_xml(text)}</w:t></w:r></w:p>';
  }

  static String _docxTable(List<List<String>> rows) {
    if (rows.isEmpty) return '';
    final buf = StringBuffer(
      '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
      '<w:tblBorders>'
      '<w:top w:val="single" w:sz="4" w:color="999999"/>'
      '<w:left w:val="single" w:sz="4" w:color="999999"/>'
      '<w:bottom w:val="single" w:sz="4" w:color="999999"/>'
      '<w:right w:val="single" w:sz="4" w:color="999999"/>'
      '<w:insideH w:val="single" w:sz="4" w:color="999999"/>'
      '<w:insideV w:val="single" w:sz="4" w:color="999999"/>'
      '</w:tblBorders></w:tblPr>',
    );
    for (var r = 0; r < rows.length; r++) {
      buf.write('<w:tr>');
      for (final cell in rows[r]) {
        buf.write('<w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/></w:tcPr>'
            '${_docxParagraph(cell, bold: r == 0, halfPt: 18)}</w:tc>');
      }
      buf.write('</w:tr>');
    }
    buf.write('</w:tbl>');
    return buf.toString();
  }

  static String _xml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
