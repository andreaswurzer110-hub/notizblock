import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/note_card.dart';
import '../widgets/color_picker.dart';
import '../services/sticky_note_service.dart';
import '../services/google_drive_service.dart';
import 'note_editor_screen.dart';
import 'autopool_editor_screen.dart';
import 'settings_screen.dart';
import 'archive_screen.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isSyncing = false;
  // Welche Notizen sind als Desktop-Widget angeheftet (Windows/Linux). Wird für
  // den Karten-Indikator gebraucht; nur die Hauptapp schreibt diese Liste.
  Set<String> _widgetIds = {};

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotesProvider>().loadNotes();
    });
    _loadWidgetIds();
    // Der stille Login läuft auf Desktop erst NACH dem ersten Frame (siehe
    // main.dart) – die AppBar baut also zunächst mit isSignedIn==false. Ohne
    // diesen Listener bliebe das Sync-Icon dauerhaft „nicht angemeldet"
    // durchgestrichen, obwohl der Login längst durch ist (war real ein Bug auf
    // Linux). Bei Statuswechsel neu bauen.
    GoogleDriveService.instance.signedInNotifier.addListener(_onSignInChanged);
  }

  void _onSignInChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadWidgetIds() async {
    if (!_isDesktop) return;
    final ids = await StickyNoteService.instance.getWidgetNoteIds();
    if (mounted) setState(() => _widgetIds = ids);
  }

  @override
  void dispose() {
    GoogleDriveService.instance.signedInNotifier
        .removeListener(_onSignInChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() => _isSearching = true);
  }

  void _stopSearch() {
    setState(() => _isSearching = false);
    _searchController.clear();
    context.read<NotesProvider>().clearSearch();
  }

  void _openNote(Note note) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => note.isAutopool
            ? AutopoolEditorScreen(note: note)
            : NoteEditorScreen(note: note),
      ),
    );
  }

  void _openArchive() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ArchiveScreen()),
    );
  }

  // Beim + zuerst den Notiz-Typ wählen: normale Notiz oder Autopool-Tabelle.
  void _createNote() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.createNoteTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.notes),
                title: Text(l10n.noteTypeNote),
                subtitle: Text(l10n.noteTypeNoteSubtitle),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const NoteEditorScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: Text(l10n.autopool),
                subtitle: Text(l10n.noteTypeAutopoolSubtitle),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AutopoolEditorScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAsStickyNote(Note note) {
    StickyNoteService.instance.openStickyNote(note);
  }

  Future<void> _syncNow() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSyncing = true);
    final result = await GoogleDriveService.instance.synchronize();
    if (!mounted) return;
    setState(() => _isSyncing = false);
    if (result.success) {
      context.read<NotesProvider>().refreshNotes();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? '${l10n.syncSuccess} – ${l10n.uploaded(result.uploadedCount)}, ${l10n.downloaded(result.downloadedCount)}'
              : '${l10n.syncFailed}: ${result.message}',
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: result.success ? 4 : 8),
      ),
    );
  }

  // Hinweis, wenn nicht bei Drive angemeldet (Sync-Button ist dann
  // durchgestrichen). Macht den abgemeldeten Zustand sichtbar.
  void _showNotSignedIn() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.notSignedIn),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Notiz als Desktop-Widget anheften/lösen
  Future<void> _toggleWidget(Note note) async {
    final isWidget = await StickyNoteService.instance.isWidget(note.id);
    await StickyNoteService.instance.setWidget(note.id, !isWidget);
    if (!isWidget) {
      // Neu angeheftet -> direkt als Fenster öffnen
      await StickyNoteService.instance.openStickyNote(note);
    } else {
      // Gelöst -> offenes Sticky-Fenster schließen
      await StickyNoteService.instance.closeStickyNote(note.id);
    }
    await _loadWidgetIds(); // Karten-Indikator aktualisieren
  }

  // Rechtsklick-Kontextmenü (Desktop)
  Future<void> _showContextMenu(Note note, Offset position) async {
    final l10n = AppLocalizations.of(context)!;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final isWidget = await StickyNoteService.instance.isWidget(note.id);
    if (!mounted) return;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        if (_isDesktop)
          PopupMenuItem(
            value: 'widget',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(isWidget ? Icons.widgets : Icons.widgets_outlined),
              title: Text(isWidget ? l10n.unpinWidget : l10n.pinAsWidget),
            ),
          ),
        PopupMenuItem(
          value: 'pin',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
                note.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
            title: Text(note.isPinned ? l10n.unpin : l10n.pin),
          ),
        ),
        PopupMenuItem(
          value: 'color',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.color),
          ),
        ),
        PopupMenuItem(
          value: 'archive',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.archive_outlined),
            title: Text(l10n.archive),
          ),
        ),
        PopupMenuItem(
          value: 'archiveRestore',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.unarchive_outlined),
            title: Text(l10n.archiveAndRestore),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_outlined, color: Colors.red),
            title: Text(l10n.delete,
                style: const TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );

    if (!mounted || selected == null) return;
    switch (selected) {
      case 'widget':
        _toggleWidget(note);
        break;
      case 'pin':
        context.read<NotesProvider>().togglePin(note.id);
        break;
      case 'color':
        final newColor =
            await showColorPickerSheet(context, currentColor: note.color);
        if (newColor != null && mounted) {
          context.read<NotesProvider>().changeColor(note.id, newColor);
        }
        break;
      case 'archive':
        context.read<NotesProvider>().archiveNote(note.id);
        break;
      case 'archiveRestore':
        _openArchive();
        break;
      case 'delete':
        _confirmDelete(note);
        break;
    }
  }

  void _showNoteOptions(Note note) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    note.title.isNotEmpty ? note.title : l10n.emptyNote,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),

                // Sticky Note (Desktop)
                if (_isDesktop)
                  ListTile(
                    leading: const Icon(Icons.open_in_new),
                    title: const Text('Als Sticky Note öffnen'),
                    subtitle: const Text('Öffnet in eigenem Fenster'),
                    onTap: () {
                      Navigator.pop(context);
                      _openAsStickyNote(note);
                    },
                  ),

                ListTile(
                  leading: Icon(note.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
                  title: Text(note.isPinned ? l10n.unpin : l10n.pin),
                  onTap: () {
                    Navigator.pop(context);
                    context.read<NotesProvider>().togglePin(note.id);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(l10n.color),
                  onTap: () async {
                    Navigator.pop(context);
                    final newColor = await showColorPickerSheet(context, currentColor: note.color);
                    if (newColor != null && mounted) {
                      context.read<NotesProvider>().changeColor(note.id, newColor);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.archive_outlined),
                  title: Text(l10n.archive),
                  onTap: () {
                    Navigator.pop(context);
                    context.read<NotesProvider>().archiveNote(note.id);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.unarchive_outlined),
                  title: Text(l10n.archiveAndRestore),
                  onTap: () {
                    Navigator.pop(context);
                    _openArchive();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outlined, color: Colors.red),
                  title: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(note);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(Note note) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.deleteNote),
        content: Text(l10n.deleteNoteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<NotesProvider>().deleteNote(note.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(hintText: l10n.searchHint, border: InputBorder.none),
                onChanged: (value) => context.read<NotesProvider>().search(value),
              )
            : Text(l10n.appTitle),
        actions: [
          if (_isSearching)
            IconButton(icon: const Icon(Icons.close), onPressed: _stopSearch)
          else ...[
            IconButton(icon: const Icon(Icons.search), onPressed: _startSearch),
            // Sync-Button bleibt immer sichtbar. Nicht angemeldet ->
            // durchgestrichenes Icon (sync_disabled) + Hinweis statt Sync, damit
            // ein versehentliches Abmelden auffällt.
            IconButton(
              icon: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(GoogleDriveService.instance.isSignedIn
                      ? Icons.sync
                      : Icons.sync_disabled),
              tooltip: GoogleDriveService.instance.isSignedIn
                  ? l10n.syncNow
                  : l10n.notSignedIn,
              onPressed: _isSyncing
                  ? null
                  : (GoogleDriveService.instance.isSignedIn
                      ? _syncNow
                      : _showNotSignedIn),
            ),
            IconButton(
              icon: Icon(settings.isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
              onPressed: () => settings.toggleViewMode(),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsScreen())),
            ),
          ],
        ],
      ),
      body: Consumer<NotesProvider>(
        builder: (context, notesProvider, child) {
          if (notesProvider.isLoading) return const Center(child: CircularProgressIndicator());
          if (notesProvider.notes.isEmpty) return _buildEmptyState(l10n, notesProvider.searchQuery.isNotEmpty);
          return settings.isGridView ? _buildGridView(notesProvider.notes) : _buildListView(notesProvider.notes);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNote,
        icon: const Icon(Icons.add),
        label: Text(l10n.newNote),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, bool isSearchResult) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSearchResult ? Icons.search_off : Icons.note_add_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              isSearchResult ? l10n.noSearchResults : l10n.noNotes,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            if (!isSearchResult) ...[
              const SizedBox(height: 8),
              Text(l10n.noNotesHint, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(List<Note> notes) {
    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      padding: const EdgeInsets.all(16),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return GestureDetector(
          onSecondaryTapDown: (d) => _showContextMenu(note, d.globalPosition),
          child: NoteCard(note: note, onTap: () => _openNote(note), onLongPress: () => _showNoteOptions(note), isWidget: _widgetIds.contains(note.id)),
        );
      },
    );
  }

  Widget _buildListView(List<Note> notes) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return GestureDetector(
          onSecondaryTapDown: (d) => _showContextMenu(note, d.globalPosition),
          child: NoteListTile(note: note, onTap: () => _openNote(note), onLongPress: () => _showNoteOptions(note), isWidget: _widgetIds.contains(note.id)),
        );
      },
    );
  }
}