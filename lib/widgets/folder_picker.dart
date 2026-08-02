import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notes_provider.dart';
import 'sheet_body.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';

// Sentinel-Rückgabewert des internen Sheets für „Neuer Ordner".
// Führendes Leerzeichen -> nie ein echter Ordnername (die werden getrimmt).
const String _newFolderValue = ' __new_folder__';

/// Dialog zum Eingeben/Bearbeiten eines Ordnernamens. Gibt den eingegebenen Text
/// oder null (abgebrochen) zurück. Wiederverwendet von Home-Screen (anlegen/
/// umbenennen) und dem Ordner-Auswahl-Sheet (neuer Ordner).
Future<String?> showFolderNameDialog(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  final l10n = AppLocalizations.of(context)!;
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: l10n.folderName),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
        TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(l10n.save)),
      ],
    ),
  ).whenComplete(ctrl.dispose);
}

/// Zeigt das Ordner-Auswahl-Sheet (kein Ordner / bestehende Ordner / neuer
/// Ordner) und gibt den gewählten Ordner ZURÜCK:
///  - `null`  = abgebrochen (keine Änderung)
///  - `''`    = „Kein Ordner"
///  - sonst   = Ordnername (ein neu angelegter Ordner wird dabei direkt erstellt)
///
/// [currentFolder] markiert den aktuell zugewiesenen Ordner mit einem Häkchen.
/// Der Aufrufer entscheidet, was mit dem Rückgabewert passiert – die Notizliste
/// verschiebt direkt (siehe [showMoveToFolderSheet]), die Editoren übernehmen ihn
/// in ihren lokalen Ordner-Zustand.
Future<String?> showFolderPicker(
  BuildContext context, {
  required String currentFolder,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final provider = context.read<NotesProvider>();
  final folders = provider.folders;

  final selected = await showModalBottomSheet<String>(
    context: context,
    // Viele Ordner passen sonst nicht ins Sheet (v.a. kleines Desktop-Fenster).
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SheetBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(l10n.moveToFolder,
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.folder_off_outlined),
            title: Text(l10n.noFolder),
            trailing: currentFolder.isEmpty
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () => Navigator.pop(ctx, ''),
          ),
          for (final f in folders)
            ListTile(
              leading: Icon(
                  currentFolder == f ? Icons.folder : Icons.folder_outlined),
              title: Text(f, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: currentFolder == f
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () => Navigator.pop(ctx, f),
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: Text(l10n.newFolder),
            onTap: () => Navigator.pop(ctx, _newFolderValue),
          ),
        ],
      ),
    ),
  );

  if (selected == null || !context.mounted) return null;
  if (selected == _newFolderValue) {
    final name = await showFolderNameDialog(context, title: l10n.newFolder);
    if (name == null || name.trim().isEmpty) return null;
    await provider.createFolder(name.trim());
    return name.trim();
  }
  return selected;
}

/// Ordner-Auswahl-Sheet, das die Notiz [noteId] direkt zuordnet (für die
/// Notizliste, wo keine offene Editor-Instanz den Ordner-Zustand hält).
Future<void> showMoveToFolderSheet(
  BuildContext context, {
  required String noteId,
  required String currentFolder,
}) async {
  final provider = context.read<NotesProvider>();
  // Messenger + l10n VOR dem await greifen (danach ist context evtl. nicht mehr
  // gültig – Lint use_build_context_synchronously).
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context)!;
  final target = await showFolderPicker(context, currentFolder: currentFolder);
  if (target == null) return;
  final ok = await provider.setNoteFolder(noteId, target);
  if (!ok) return;
  // Kurze Rückmeldung „wurde hinzugefügt / entfernt".
  messenger.showSnackBar(
    SnackBar(
      content: Text(target.isEmpty
          ? l10n.removedFromFolderSnack
          : l10n.addedToFolderSnack(target)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}
