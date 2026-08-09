import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/note_card.dart';
import '../widgets/color_picker.dart';
import '../widgets/folder_picker.dart';
import '../widgets/print_menu.dart';
import '../widgets/sheet_body.dart';
import '../widgets/version_history.dart';
import '../services/sticky_note_service.dart';
import '../services/google_drive_service.dart';
import 'note_editor_screen.dart';
import 'autopool_editor_screen.dart';
import 'shopping_list_editor_screen.dart';
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
  // Mehrfachauswahl: im Auswahlmodus wählt ein Tipp die Notiz aus, statt sie zu
  // öffnen. Die Sammelaktionen liegen in der Leiste unten.
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

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

  // HINWEIS: Der Konflikt-Hinweis steht bewusst NICHT mehr hier. In der
  // Notizliste war er wirkungslos – man kann dort nichts damit anfangen. Er
  // erscheint jetzt an der betroffenen Notiz selbst (siehe ConflictBanner):
  // im Editor und im Sticky-Fenster.

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
            : note.isShopping
                ? ShoppingListEditorScreen(note: note)
                : NoteEditorScreen(note: note),
      ),
    );
  }

  // --- Mehrfachauswahl ----------------------------------------------------

  void _startSelection([Note? first]) {
    setState(() {
      _selectionMode = true;
      _selectedIds.clear();
      if (first != null) _selectedIds.add(first.id);
    });
  }

  void _endSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(Note note) {
    setState(() {
      if (!_selectedIds.remove(note.id)) _selectedIds.add(note.id);
    });
  }

  // Die ausgewählten Notizen in der Reihenfolge der Liste (für Druck/Export).
  List<Note> _selectedNotes() {
    final notes = context.read<NotesProvider>().notes;
    return [for (final n in notes) if (_selectedIds.contains(n.id)) n];
  }

  Future<void> _selectAllVisible() async {
    final notes = context.read<NotesProvider>().notes;
    setState(() {
      if (_selectedIds.length == notes.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(notes.map((n) => n.id));
      }
    });
  }

  // Sammelaktion: ausgewählte Notizen in einen Ordner verschieben.
  Future<void> _bulkMoveToFolder() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<NotesProvider>();
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final target = await showFolderPicker(context, currentFolder: '');
    if (target == null || !mounted) return;
    for (final id in ids) {
      await provider.setNoteFolder(id, target);
    }
    if (!mounted) return;
    _endSelection();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.notesMovedSnack(ids.length)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // Sammelaktion: alle ausgewählten Notizen in EIN Dokument drucken/exportieren.
  Future<void> _bulkPrint() async {
    final notes = _selectedNotes();
    if (notes.isEmpty) return;
    await showPrintMenuForNotes(context, notes);
    if (mounted) _endSelection();
  }

  Future<void> _bulkArchive() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<NotesProvider>();
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    for (final id in ids) {
      await provider.archiveNote(id);
    }
    if (!mounted) return;
    _endSelection();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.notesArchivedSnack(ids.length)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _bulkDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<NotesProvider>();
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.deleteNote),
        content: Text(l10n.deleteNotesConfirm(ids.length)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    for (final id in ids) {
      await provider.deleteNote(id);
    }
    if (mounted) _endSelection();
  }

  // Aktionsleiste im Auswahlmodus (unten, damit sie auf dem Handy erreichbar
  // ist). Ohne Auswahl sind die Aktionen deaktiviert.
  Widget _buildSelectionBar() {
    final l10n = AppLocalizations.of(context)!;
    final enabled = _selectedIds.isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.drive_file_move_outlined),
              tooltip: l10n.moveToFolder,
              onPressed: enabled ? _bulkMoveToFolder : null,
            ),
            IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: l10n.printExport,
              onPressed: enabled ? _bulkPrint : null,
            ),
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              tooltip: l10n.archive,
              onPressed: enabled ? _bulkArchive : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outlined, color: Colors.red),
              tooltip: l10n.delete,
              onPressed: enabled ? _bulkDelete : null,
            ),
          ],
        ),
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
    // Steht man in einem Ordner, zusätzlich „vorhandene Notiz hinzufügen"
    // anbieten (nicht nur eine neue Notiz erstellen).
    final folder = context.read<NotesProvider>().selectedFolder;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SheetBody(
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
              if (folder.isNotEmpty) ...[
                ListTile(
                  leading: const Icon(Icons.playlist_add),
                  title: Text(l10n.addExistingNote),
                  subtitle: Text(folder,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    Navigator.pop(context);
                    _addExistingNotesToFolder(folder);
                  },
                ),
                const Divider(height: 1),
              ],
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
                leading: const Icon(Icons.shopping_cart_outlined),
                title: Text(l10n.shoppingList),
                subtitle: Text(l10n.noteTypeShoppingSubtitle),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ShoppingListEditorScreen()));
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

  // Vorhandene Notizen in den [folder] verschieben (Mehrfachauswahl). Kandidaten
  // sind alle nicht archivierten Notizen, die nicht schon in diesem Ordner sind.
  Future<void> _addExistingNotesToFolder(String folder) async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<NotesProvider>();
    final candidates =
        provider.allNotes.where((n) => n.folder != folder).toList();
    final selectedIds = <String>{};

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
          child: StatefulBuilder(
            builder: (stCtx, setSheetState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.addNotesToFolderTitle(folder),
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const Divider(height: 1),
                if (candidates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(l10n.noNotesToAdd,
                        style:
                            TextStyle(color: Theme.of(sheetContext).hintColor)),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: candidates.length,
                      itemBuilder: (ctx, i) {
                        final n = candidates[i];
                        return CheckboxListTile(
                          controlAffinity: ListTileControlAffinity.leading,
                          value: selectedIds.contains(n.id),
                          onChanged: (v) => setSheetState(() {
                            if (v == true) {
                              selectedIds.add(n.id);
                            } else {
                              selectedIds.remove(n.id);
                            }
                          }),
                          title: Text(
                            n.title.isNotEmpty ? n.title : l10n.emptyNote,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: n.folder.isNotEmpty
                              ? Text(n.folder,
                                  maxLines: 1, overflow: TextOverflow.ellipsis)
                              : null,
                        );
                      },
                    ),
                  ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: Text(l10n.cancel),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: selectedIds.isEmpty
                            ? null
                            : () => Navigator.pop(sheetContext, true),
                        child: Text(l10n.add),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true || selectedIds.isEmpty || !mounted) return;
    for (final id in selectedIds) {
      await provider.setNoteFolder(id, folder);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.addedToFolderSnack(folder)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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
          value: 'folder',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.drive_file_move_outlined),
            title: Text(l10n.moveToFolder),
          ),
        ),
        PopupMenuItem(
          value: 'print',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.print_outlined),
            title: Text(l10n.printExport),
          ),
        ),
        PopupMenuItem(
          value: 'history',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history),
            title: Text(l10n.versionHistory),
          ),
        ),
        PopupMenuItem(
          value: 'select',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.checklist),
            title: Text(l10n.selectNotes),
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
      case 'folder':
        showMoveToFolderSheet(context,
            noteId: note.id, currentFolder: note.folder);
        break;
      case 'print':
        showPrintMenu(context, note);
        break;
      case 'history':
        showVersionHistory(context, note);
        break;
      case 'select':
        _startSelection(note);
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

    // WICHTIG: Der Builder-Context des Sheets ist NACH Navigator.pop nicht mehr
    // gemountet. Zum Schließen daher `sheetContext`, für Folgeaktionen aber den
    // Screen-Context (`context` dieses States). Sonst bricht z.B. der
    // context.mounted-Check in showFolderPicker ab und die Verschiebung passiert
    // nicht – das war der Android-„erst nach ein paar Versuchen"-Bug (Desktop war
    // nie betroffen, weil das Rechtsklick-Menü schon den Screen-Context nutzt).
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SheetBody(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    note.title.isNotEmpty ? note.title : l10n.emptyNote,
                    style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                      Navigator.pop(sheetContext);
                      _openAsStickyNote(note);
                    },
                  ),

                ListTile(
                  leading: Icon(note.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
                  title: Text(note.isPinned ? l10n.unpin : l10n.pin),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.read<NotesProvider>().togglePin(note.id);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(l10n.color),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final newColor = await showColorPickerSheet(context, currentColor: note.color);
                    if (newColor != null && mounted) {
                      context.read<NotesProvider>().changeColor(note.id, newColor);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.drive_file_move_outlined),
                  title: Text(l10n.moveToFolder),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showMoveToFolderSheet(context,
                        noteId: note.id, currentFolder: note.folder);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: Text(l10n.printExport),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showPrintMenu(context, note);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(l10n.versionHistory),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showVersionHistory(context, note);
                  },
                ),
                // Mehrere Notizen gemeinsam bearbeiten – diese Notiz ist schon
                // ausgewählt.
                ListTile(
                  leading: const Icon(Icons.checklist),
                  title: Text(l10n.selectNotes),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _startSelection(note);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.archive_outlined),
                  title: Text(l10n.archive),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.read<NotesProvider>().archiveNote(note.id);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.unarchive_outlined),
                  title: Text(l10n.archiveAndRestore),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openArchive();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outlined, color: Colors.red),
                  title: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(sheetContext);
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
    final selectedFolder = context.watch<NotesProvider>().selectedFolder;

    // Auswahlmodus: eigene Leiste (Anzahl + Alle auswählen), kein Drawer/FAB.
    if (_selectionMode) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.cancel,
            onPressed: _endSelection,
          ),
          title: Text(l10n.selectedCount(_selectedIds.length)),
          actions: [
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: l10n.selectAllNotes,
              onPressed: _selectAllVisible,
            ),
          ],
        ),
        body: Consumer<NotesProvider>(
          builder: (context, notesProvider, child) {
            if (notesProvider.notes.isEmpty) {
              return _buildEmptyState(l10n, notesProvider.searchQuery.isNotEmpty,
                  notesProvider.selectedFolder);
            }
            return settings.isGridView
                ? _buildGridView(notesProvider.notes)
                : _buildListView(notesProvider.notes);
          },
        ),
        bottomNavigationBar: _buildSelectionBar(),
      );
    }

    return Scaffold(
      // Beim Suchen keinen Drawer (das Suchfeld nutzt den Platz links).
      drawer: _isSearching ? null : _buildDrawer(context),
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(hintText: l10n.searchHint, border: InputBorder.none),
                onChanged: (value) => context.read<NotesProvider>().search(value),
              )
            : Text(selectedFolder.isEmpty ? l10n.appTitle : selectedFolder),
        actions: [
          if (_isSearching)
            IconButton(icon: const Icon(Icons.close), onPressed: _stopSearch)
          else ...[
            IconButton(icon: const Icon(Icons.search), onPressed: _startSearch),
            // Mehrfachauswahl starten (Sammelaktionen: verschieben, drucken,
            // archivieren, löschen).
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: l10n.selectNotes,
              onPressed: () => _startSelection(),
            ),
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
          final Widget list;
          if (notesProvider.isLoading) {
            list = const Center(child: CircularProgressIndicator());
          } else if (notesProvider.notes.isEmpty) {
            list = _buildEmptyState(l10n, notesProvider.searchQuery.isNotEmpty,
                notesProvider.selectedFolder);
          } else {
            list = settings.isGridView
                ? _buildGridView(notesProvider.notes)
                : _buildListView(notesProvider.notes);
          }
          return list;
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNote,
        icon: const Icon(Icons.add),
        label: Text(l10n.newNote),
      ),
    );
  }

  // Seitenmenü: „Alle Notizen", Ordnerliste (mit Zähler), neuer Ordner, Archiv.
  Widget _buildDrawer(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notesProvider = context.watch<NotesProvider>();
    final folders = notesProvider.folders;
    final selected = notesProvider.selectedFolder;
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.sticky_note_2_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.appTitle,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _drawerFolderTile(
                    context,
                    icon: Icons.notes_rounded,
                    label: l10n.allNotes,
                    count: notesProvider.totalCount,
                    selected: selected.isEmpty,
                    onTap: () {
                      notesProvider.selectFolder('');
                      Navigator.pop(context);
                    },
                  ),
                  if (folders.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                      child: Text(
                        l10n.folders.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.hintColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  for (final f in folders)
                    _drawerFolderTile(
                      context,
                      icon: Icons.folder_outlined,
                      label: f,
                      count: notesProvider.folderCount(f),
                      selected: selected == f,
                      onTap: () {
                        notesProvider.selectFolder(f);
                        Navigator.pop(context);
                      },
                      onManage: () => _showFolderOptions(f),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(l10n.newFolder),
              onTap: () {
                Navigator.pop(context);
                _createFolderDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: Text(l10n.archiveAndRestore),
              onTap: () {
                Navigator.pop(context);
                _openArchive();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerFolderTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
    VoidCallback? onManage,
  }) {
    final theme = Theme.of(context);
    final color = selected ? theme.colorScheme.primary : null;
    return GestureDetector(
      onSecondaryTap: onManage, // Rechtsklick (Desktop) -> verwalten
      child: ListTile(
        dense: true,
        selected: selected,
        leading: Icon(icon, color: color),
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: Text('$count',
            style: TextStyle(color: theme.hintColor, fontSize: 13)),
        onTap: onTap,
        onLongPress: onManage, // Long-Press (Touch) -> verwalten
      ),
    );
  }

  // Ordner verwalten (umbenennen/löschen) – Long-Press/Rechtsklick im Drawer.
  void _showFolderOptions(String folder) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
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
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(folder,
                        style: Theme.of(ctx)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: Text(l10n.renameFolder),
              onTap: () {
                Navigator.pop(ctx);
                _renameFolderDialog(folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(l10n.deleteFolder,
                  style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteFolderDialog(folder);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createFolderDialog() async {
    final provider = context.read<NotesProvider>();
    final name = await showFolderNameDialog(context,
        title: AppLocalizations.of(context)!.newFolder);
    if (name == null || name.trim().isEmpty) return;
    await provider.createFolder(name.trim());
    provider.selectFolder(name.trim());
  }

  Future<void> _renameFolderDialog(String folder) async {
    final provider = context.read<NotesProvider>();
    final name = await showFolderNameDialog(context,
        title: AppLocalizations.of(context)!.renameFolder, initial: folder);
    if (name == null || name.trim().isEmpty || name.trim() == folder) return;
    await provider.renameFolder(folder, name.trim());
  }

  Future<void> _deleteFolderDialog(String folder) async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<NotesProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.deleteFolder),
        content: Text(l10n.deleteFolderConfirm(folder)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await provider.deleteFolder(folder);
  }

  Widget _buildEmptyState(
      AppLocalizations l10n, bool isSearchResult, String folder) {
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
            // In einem (z.B. neu angelegten, leeren) Ordner: vorhandene Notiz
            // hinzufügen, nicht nur eine neue erstellen.
            if (!isSearchResult && folder.isNotEmpty) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: () => _addExistingNotesToFolder(folder),
                icon: const Icon(Icons.playlist_add),
                label: Text(l10n.addExistingNote),
              ),
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
          onSecondaryTapDown: _selectionMode
              ? null
              : (d) => _showContextMenu(note, d.globalPosition),
          child: NoteCard(
            note: note,
            // Im Auswahlmodus wählt ein Tipp aus, statt die Notiz zu öffnen.
            onTap: _selectionMode
                ? () => _toggleSelected(note)
                : () => _openNote(note),
            onLongPress: _selectionMode
                ? () => _toggleSelected(note)
                : () => _showNoteOptions(note),
            isWidget: _widgetIds.contains(note.id),
            selectable: _selectionMode,
            selected: _selectedIds.contains(note.id),
          ),
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
          onSecondaryTapDown: _selectionMode
              ? null
              : (d) => _showContextMenu(note, d.globalPosition),
          child: NoteListTile(
            note: note,
            onTap: _selectionMode
                ? () => _toggleSelected(note)
                : () => _openNote(note),
            onLongPress: _selectionMode
                ? () => _toggleSelected(note)
                : () => _showNoteOptions(note),
            isWidget: _widgetIds.contains(note.id),
            selectable: _selectionMode,
            selected: _selectedIds.contains(note.id),
          ),
        );
      },
    );
  }
}