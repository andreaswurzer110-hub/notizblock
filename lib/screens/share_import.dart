import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../providers/notes_provider.dart';
import 'note_editor_screen.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';

/// Übernahme von Text, den eine andere App per „Teilen" geschickt hat
/// (Android, `ACTION_SEND` mit `text/plain` – siehe AndroidManifest und
/// MainActivity). Typischer Fall: In einer App/Browser Text markieren →
/// Teilen → Notizblock; der geteilte Text enthält meist auch den Link.
///
/// Ablauf: neue oder bestehende Notiz? → bei „bestehende" die Notiz wählen →
/// oberhalb oder unterhalb des vorhandenen Inhalts einfügen.
Future<void> showSharedTextImport(
  BuildContext context, {
  required String text,
  String subject = '',
}) async {
  final l10n = AppLocalizations.of(context)!;
  final block = _block(text, subject);
  if (block.isEmpty) return;

  final target = await showModalBottomSheet<_ShareTarget>(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.shareImportTitle,
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                // Vorschau des geteilten Textes, damit klar ist, was ankommt.
                Text(
                  block,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(sheetContext).hintColor),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.note_add_outlined),
            title: Text(l10n.shareImportNewNote),
            subtitle: Text(l10n.shareImportNewNoteSubtitle),
            onTap: () => Navigator.pop(sheetContext, _ShareTarget.newNote),
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: Text(l10n.shareImportExisting),
            subtitle: Text(l10n.shareImportExistingSubtitle),
            onTap: () => Navigator.pop(sheetContext, _ShareTarget.existing),
          ),
        ],
      ),
    ),
  );

  if (target == null || !context.mounted) return;

  if (target == _ShareTarget.newNote) {
    // Betreff (z.B. Seitentitel aus dem Browser) als Titel vorschlagen; der
    // Link/Text steht ohnehin im Inhalt.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          initialTitle: subject.trim(),
          initialContent: text.trim(),
        ),
      ),
    );
    return;
  }

  final note = await _pickNote(context);
  if (note == null || !context.mounted) return;

  final atTop = await _pickPosition(context);
  if (atTop == null || !context.mounted) return;

  final provider = context.read<NotesProvider>();
  // Frischen Stand aus dem Provider holen (die Notiz kann zwischenzeitlich per
  // Sync aktualisiert worden sein).
  final current = provider.getNoteById(note.id) ?? note;
  final existing = current.content;
  final String combined;
  if (existing.trim().isEmpty) {
    combined = block;
  } else if (atTop) {
    combined = '$block\n\n${existing.trimLeft()}';
  } else {
    combined = '${existing.trimRight()}\n\n$block';
  }
  await provider.updateNote(current.copyWith(content: combined));
  if (!context.mounted) return;

  final updated = provider.getNoteById(current.id) ?? current;
  final messenger = ScaffoldMessenger.of(context);
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => NoteEditorScreen(note: updated)),
  );
  messenger.showSnackBar(SnackBar(
    content: Text(l10n.shareInsertedSnack(
        updated.title.trim().isEmpty ? l10n.emptyNote : updated.title.trim())),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 3),
  ));
}

enum _ShareTarget { newNote, existing }

/// Einzufügender Textblock: Betreff (falls die sendende App einen mitschickt und
/// er nicht ohnehin im Text steht) als erste Zeile, darunter der geteilte Text
/// mit Link.
String _block(String text, String subject) {
  final t = text.trim();
  final s = subject.trim();
  if (s.isEmpty || t.contains(s)) return t;
  return t.isEmpty ? s : '$s\n$t';
}

/// Auswahl der Ziel-Notiz. Bewusst nur Textnotizen: bei Autopool-/Einkaufslisten-
/// Notizen wird `content` aus der strukturierten Fassung neu erzeugt – dort
/// eingefügter Text ginge beim nächsten Bearbeiten verloren.
Future<Note?> _pickNote(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final provider = context.read<NotesProvider>();
  // Beim Kaltstart über „Teilen" kann die Liste noch leer sein (loadNotes läuft
  // parallel) – dann kurz nachladen, sonst stünde hier „keine Notizen".
  if (provider.allNotes.isEmpty) await provider.loadNotes(silent: true);
  if (!context.mounted) return null;
  final all = provider.allNotes
      .where((n) => !n.isAutopool && !n.isShopping)
      .toList();
  var query = '';

  return showModalBottomSheet<Note>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
        ),
        child: StatefulBuilder(
          builder: (stCtx, setSheetState) {
            final q = query.toLowerCase();
            final notes = q.isEmpty
                ? all
                : all
                    .where((n) =>
                        n.title.toLowerCase().contains(q) ||
                        n.content.toLowerCase().contains(q))
                    .toList();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.shareImportChooseNote,
                      style: Theme.of(stCtx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setSheetState(() => query = v),
                  ),
                ),
                const Divider(height: 1),
                if (notes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(l10n.noNotes,
                        style: TextStyle(color: Theme.of(stCtx).hintColor)),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: notes.length,
                      itemBuilder: (ctx, i) {
                        final n = notes[i];
                        final preview = n.content.trim().replaceAll('\n', ' ');
                        return ListTile(
                          leading: const Icon(Icons.notes),
                          title: Text(
                            n.title.trim().isNotEmpty
                                ? n.title.trim()
                                : l10n.emptyNote,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: preview.isEmpty
                              ? null
                              : Text(preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                          onTap: () => Navigator.pop(sheetContext, n),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

/// Oberhalb (true) oder unterhalb (false) des vorhandenen Inhalts einfügen.
Future<bool?> _pickPosition(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet<bool>(
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
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.shareInsertPositionTitle,
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.vertical_align_top),
            title: Text(l10n.shareInsertTop),
            onTap: () => Navigator.pop(sheetContext, true),
          ),
          ListTile(
            leading: const Icon(Icons.vertical_align_bottom),
            title: Text(l10n.shareInsertBottom),
            onTap: () => Navigator.pop(sheetContext, false),
          ),
        ],
      ),
    ),
  );
}
