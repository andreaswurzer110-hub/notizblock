import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/export_service.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';

/// Auswahl hinter dem Kontextmenü-Eintrag „Drucken": PDF, Textdatei, Word oder
/// der System-Druckdialog. Wird aus der Notizliste (Rechtsklick/Long-Press) und
/// aus allen drei Editoren aufgerufen.
///
/// [context] muss der Screen-Context sein (nicht der Builder-Context eines
/// bereits geschlossenen Sheets) – sonst brechen die Folgeaktionen ab.
Future<void> showPrintMenu(BuildContext context, Note note) async {
  final l10n = AppLocalizations.of(context)!;
  final choice = await showModalBottomSheet<_PrintChoice>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                const Icon(Icons.print_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.printExportTitle,
                    style: Theme.of(sheetContext)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: Text(l10n.exportPdf),
            subtitle: const Text('.pdf'),
            onTap: () => Navigator.pop(sheetContext, _PrintChoice.pdf),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.exportTxt),
            subtitle: const Text('.txt'),
            onTap: () => Navigator.pop(sheetContext, _PrintChoice.txt),
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: Text(l10n.exportWord),
            subtitle: const Text('.docx'),
            onTap: () => Navigator.pop(sheetContext, _PrintChoice.docx),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.print),
            title: Text(l10n.printSystem),
            subtitle: Text(l10n.printSystemSubtitle),
            onTap: () => Navigator.pop(sheetContext, _PrintChoice.system),
          ),
        ],
      ),
    ),
  );

  if (choice == null || !context.mounted) return;
  await _run(context, note, choice);
}

enum _PrintChoice { pdf, txt, docx, system }

Future<void> _run(
    BuildContext context, Note note, _PrintChoice choice) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  // Spaltenüberschriften der Autopool-Tabelle in der App-Sprache mitgeben –
  // der ExportService kennt keinen BuildContext.
  final headers = <String>[
    l10n.autopoolColName,
    l10n.autopoolColOfficeVersion,
    l10n.autopoolColLocation,
    l10n.autopoolColInventory,
    l10n.autopoolColSerial,
    l10n.autopoolColDate,
  ];

  void snack(String text, {bool long = false}) {
    messenger.showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: long ? 6 : 3),
    ));
  }

  try {
    if (choice == _PrintChoice.system) {
      await ExportService.printNote(note, autopoolHeaders: headers);
      return;
    }
    final format = switch (choice) {
      _PrintChoice.pdf => ExportFormat.pdf,
      _PrintChoice.txt => ExportFormat.txt,
      _PrintChoice.docx => ExportFormat.docx,
      _PrintChoice.system => ExportFormat.pdf, // nicht erreichbar
    };
    final path = await ExportService.exportNote(note, format,
        autopoolHeaders: headers);
    if (path == null) return; // Abbruch im Speichern-Dialog
    snack(l10n.exportSaved(path));
  } catch (e) {
    snack(l10n.exportFailed(e.toString()), long: true);
  }
}
