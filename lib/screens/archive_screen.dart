import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../services/google_drive_service.dart';
import 'read_only_note_screen.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';

/// Archiv & Wiederherstellen: zwei Tabs – archivierte Notizen (lokal) und
/// gelöschte Notizen (aus dem Drive-Verlauf, geräteübergreifend, 30 Tage).
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  // Archiviert (lokal)
  List<Note> _archived = [];
  bool _archivedLoading = true;

  // Gelöscht (Drive)
  List<DeletedNote> _deleted = [];
  bool _deletedLoading = true;
  bool _deletedError = false;

  @override
  void initState() {
    super.initState();
    _loadArchived();
    _loadDeleted();
  }

  Future<void> _loadArchived() async {
    setState(() => _archivedLoading = true);
    final notes = await context.read<NotesProvider>().getArchivedNotes();
    if (!mounted) return;
    setState(() {
      _archived = notes;
      _archivedLoading = false;
    });
  }

  Future<void> _loadDeleted() async {
    if (!GoogleDriveService.instance.isSignedIn) {
      setState(() {
        _deleted = [];
        _deletedLoading = false;
        _deletedError = false;
      });
      return;
    }
    setState(() {
      _deletedLoading = true;
      _deletedError = false;
    });
    try {
      final deleted = await GoogleDriveService.instance.getDeletedNotes();
      if (!mounted) return;
      setState(() {
        _deleted = deleted;
        _deletedLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deletedLoading = false;
        _deletedError = true;
      });
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _restoreArchived(Note note) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await context.read<NotesProvider>().unarchiveNote(note.id);
    if (!mounted) return;
    if (ok) {
      setState(() => _archived.removeWhere((n) => n.id == note.id));
      _snack(l10n.noteRestored);
    }
  }

  Future<void> _deleteArchivedPermanently(Note note) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.deletePermanently),
        content: Text(l10n.deletePermanentlyConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await context.read<NotesProvider>().deleteNote(note.id);
    if (!mounted) return;
    if (ok) {
      setState(() => _archived.removeWhere((n) => n.id == note.id));
    }
  }

  // Notiz nur anzeigen (kein Bearbeiten) – archivierte wie gelöschte.
  void _openReadOnly(Note note) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReadOnlyNoteScreen(note: note)),
    );
  }

  Future<void> _restoreDeleted(DeletedNote item) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await context.read<NotesProvider>().restoreDeletedNote(item.note);
    if (!mounted) return;
    if (ok) {
      setState(() => _deleted.removeWhere((d) => d.note.id == item.note.id));
      _snack(l10n.noteRestored);
    } else {
      _snack(l10n.restoreFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.archiveAndRestore),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.archivedTab),
              Tab(text: l10n.deletedTab),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildArchivedTab(l10n),
            _buildDeletedTab(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildArchivedTab(AppLocalizations l10n) {
    if (_archivedLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_archived.isEmpty) {
      return _emptyState(Icons.archive_outlined, l10n.noArchivedNotes);
    }
    return RefreshIndicator(
      onRefresh: _loadArchived,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _archived.length,
        itemBuilder: (context, index) {
          final note = _archived[index];
          return _NoteRestoreCard(
            note: note,
            subtitle: l10n.modifiedAt(_formatDate(note.modifiedAt)),
            onOpen: () => _openReadOnly(note),
            onRestore: () => _restoreArchived(note),
            onDeletePermanently: () => _deleteArchivedPermanently(note),
            restoreTooltip: l10n.restore,
            deleteTooltip: l10n.deletePermanently,
          );
        },
      ),
    );
  }

  Widget _buildDeletedTab(AppLocalizations l10n) {
    if (!GoogleDriveService.instance.isSignedIn) {
      return _emptyState(Icons.cloud_off, l10n.deletedSignInHint);
    }
    if (_deletedLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_deletedError) {
      return _emptyState(
        Icons.error_outline,
        l10n.deletedLoadFailed,
        action: TextButton.icon(
          onPressed: _loadDeleted,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.restore),
        ),
      );
    }
    if (_deleted.isEmpty) {
      return _emptyState(Icons.delete_outline, l10n.noDeletedNotes);
    }
    return RefreshIndicator(
      onRefresh: _loadDeleted,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _deleted.length,
        itemBuilder: (context, index) {
          final item = _deleted[index];
          return _NoteRestoreCard(
            note: item.note,
            subtitle: l10n.deletedOn(_formatDate(item.deletedAt)),
            onOpen: () => _openReadOnly(item.note),
            onRestore: () => _restoreDeleted(item),
            restoreTooltip: l10n.restore,
          );
        },
      ),
    );
  }

  Widget _emptyState(IconData icon, String message, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action,
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('d. MMM yyyy, HH:mm', 'de').format(date);
  }
}

/// Karte für eine wiederherstellbare Notiz (Archiv oder Papierkorb).
class _NoteRestoreCard extends StatelessWidget {
  final Note note;
  final String subtitle;
  final VoidCallback onOpen;
  final VoidCallback onRestore;
  final VoidCallback? onDeletePermanently;
  final String restoreTooltip;
  final String? deleteTooltip;

  const _NoteRestoreCard({
    required this.note,
    required this.subtitle,
    required this.onOpen,
    required this.onRestore,
    required this.restoreTooltip,
    this.onDeletePermanently,
    this.deleteTooltip,
  });

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _parseColor(note.color);
    final isDark = ThemeData.estimateBrightnessForColor(backgroundColor) ==
        Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      color: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      // Tippen öffnet die Notiz im reinen Anzeige-Modus (kein Bearbeiten).
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title.isNotEmpty ? note.title : note.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  if (note.title.isNotEmpty && note.content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor.withValues(alpha: 0.85)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: subtitleColor),
                  ),
                ],
              ),
            ),
            // Wiederherstellen
            IconButton(
              icon: const Icon(Icons.restore),
              color: textColor,
              tooltip: restoreTooltip,
              onPressed: onRestore,
            ),
            // Endgültig löschen (nur Archiv)
            if (onDeletePermanently != null)
              IconButton(
                icon: const Icon(Icons.delete_forever),
                color: Colors.red.shade700,
                tooltip: deleteTooltip,
                onPressed: onDeletePermanently,
              ),
          ],
          ),
        ),
      ),
    );
  }
}
