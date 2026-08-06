import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/autopool.dart';
import '../models/note.dart';
import '../models/shopping_list.dart';
import '../providers/notes_provider.dart';
import '../services/google_drive_service.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';

/// Versionsverlauf einer Notiz: die in Google Drive liegenden früheren Stände
/// ansehen und bei Bedarf wiederherstellen.
///
/// Die Snapshots schreibt der Sync ohnehin bei jedem Hochladen (`history/`,
/// die neuesten 30 je Notiz). Sichtbar gemacht sind sie vor allem für den Fall,
/// dass zwei Geräte dieselbe Notiz geändert haben: dabei gewinnt die neuere
/// Fassung, die andere ist hier zu finden.
/// [onRestore] wird gebraucht, wenn kein [NotesProvider] verfügbar ist – etwa
/// im Sticky-Fenster, das ein eigener Prozess ohne Provider ist. Dort schreibt
/// der Aufrufer den Stand selbst (über den DatabaseService) und aktualisiert
/// seine Anzeige. Ohne Angabe läuft das Wiederherstellen über den Provider.
Future<void> showVersionHistory(
  BuildContext context,
  Note note, {
  Future<void> Function(Note version)? onRestore,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);

  if (!GoogleDriveService.instance.isSignedIn) {
    messenger.showSnackBar(SnackBar(
      content: Text(l10n.notSignedIn),
      behavior: SnackBarBehavior.floating,
    ));
    return;
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _VersionList(note: note, onRestore: onRestore),
  );
}

class _VersionList extends StatefulWidget {
  final Note note;
  final Future<void> Function(Note version)? onRestore;

  const _VersionList({required this.note, this.onRestore});

  @override
  State<_VersionList> createState() => _VersionListState();
}

class _VersionListState extends State<_VersionList> {
  late Future<List<NoteVersion>> _future;

  @override
  void initState() {
    super.initState();
    _future = GoogleDriveService.instance.getNoteVersions(widget.note.id);
  }

  String _formatDate(DateTime d) =>
      DateFormat('d. MMMM yyyy, HH:mm', 'de').format(d);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: Row(
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.versionHistory,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.versionHistoryHint,
                    style: TextStyle(fontSize: 12, color: theme.hintColor)),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: FutureBuilder<List<NoteVersion>>(
                future: _future,
                builder: (ctx, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(l10n.versionHistoryFailed,
                          style: TextStyle(color: theme.hintColor)),
                    );
                  }
                  final versions = snapshot.data ?? const <NoteVersion>[];
                  if (versions.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(l10n.versionHistoryEmpty,
                          style: TextStyle(color: theme.hintColor)),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: versions.length,
                    itemBuilder: (ctx, i) {
                      final v = versions[i];
                      // Untertitel: von welchem Gerät der Stand stammt (bei
                      // Konflikten die entscheidende Information) + Titel.
                      final details = <String>[
                        if (v.device.isNotEmpty) v.device,
                        if (v.title.isNotEmpty) v.title,
                        if (v.deleted) l10n.versionDeletedMarker,
                      ];
                      return ListTile(
                        leading: Icon(v.deleted
                            ? Icons.delete_outline
                            : Icons.schedule),
                        title: Text(_formatDate(v.savedAt)),
                        subtitle: details.isEmpty
                            ? null
                            : Text(
                                details.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        onTap: () => _openVersion(v),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Einen Stand laden und anzeigen; von dort aus wiederherstellbar.
  Future<void> _openVersion(NoteVersion version) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final note = await GoogleDriveService.instance.loadNoteVersion(version.fileId);
    if (!mounted) return;
    if (note == null) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.versionHistoryFailed),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final restore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_formatDate(version.savedAt)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (note.title.trim().isNotEmpty) ...[
                  Text(note.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                ],
                Text(_previewOf(note)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.close)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.versionRestore),
          ),
        ],
      ),
    );
    if (restore != true || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.versionRestore),
        content: Text(l10n.versionRestoreConfirm(_formatDate(version.savedAt))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.versionRestore),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Auf den aktuellen Notizstand anwenden. Der bisherige Inhalt geht dabei
    // NICHT verloren: Der nächste Sync legt ihn als eigenen Snapshot ab
    // (Push schreibt immer erst die Historie).
    if (widget.onRestore != null) {
      await widget.onRestore!(note); // z.B. Sticky-Fenster (kein Provider)
    } else {
      final provider = context.read<NotesProvider>();
      final current = provider.getNoteById(widget.note.id) ?? widget.note;
      await provider.updateNote(current.copyWith(
        title: note.title,
        content: note.content,
        autopoolData: note.autopoolData,
      ));
    }
    if (!mounted) return;
    Navigator.pop(context); // Verlaufsliste schließen
    messenger.showSnackBar(SnackBar(
      content: Text(l10n.versionRestored(_formatDate(version.savedAt))),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  /// Lesbare Vorschau des Standes – bei Tabelle/Einkaufsliste aus der
  /// strukturierten Fassung, sonst der Text.
  String _previewOf(Note note) {
    if (note.isAutopool) {
      return AutopoolData.fromJsonString(note.autopoolData).toDisplayText();
    }
    if (note.isShopping) {
      return ShoppingListData.fromJsonString(note.autopoolData).toDisplayText();
    }
    return note.content;
  }
}
