import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../models/shopping_list.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../services/google_drive_service.dart';
import '../services/sticky_note_service.dart';
import '../widgets/shopping_list_view.dart';
import '../widgets/color_picker.dart';
import '../widgets/folder_picker.dart';
import '../widgets/print_menu.dart';
import '../widgets/sheet_body.dart';
import 'archive_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';

/// Vollbild-Editor für eine Einkaufslisten-Notiz. Nutzt das wiederverwendbare
/// [ShoppingListView]-Widget. Speichern verhält sich wie beim Text-/Autopool-
/// Editor (entprellt beim Tippen + beim Verlassen); `content` wird aus der Liste
/// als lesbarer Text erzeugt, die Struktur liegt in `autopoolData` (dem
/// generischen Struktur-Datenfeld, das für den Typ `'shopping'` mitgenutzt wird).
class ShoppingListEditorScreen extends StatefulWidget {
  final Note? note;
  final bool openedFromWidget;

  const ShoppingListEditorScreen({
    super.key,
    this.note,
    this.openedFromWidget = false,
  });

  @override
  State<ShoppingListEditorScreen> createState() =>
      _ShoppingListEditorScreenState();
}

class _ShoppingListEditorScreenState extends State<ShoppingListEditorScreen> {
  final GlobalKey<ShoppingListViewState> _listKey =
      GlobalKey<ShoppingListViewState>();
  late TextEditingController _titleController;
  late String _selectedColor;
  late String _shoppingJson;
  bool _isPinned = false;
  // Ordner der Notiz (lokaler Zustand wie Farbe/Anheften). Neue Notiz startet im
  // aktuell gewählten Ordner.
  late String _folder;
  bool _hasChanges = false;
  bool _syncing = false;
  Timer? _saveDebounce;
  Note? _currentNote;
  Future<void>? _saveChain;

  bool get isNewNote => widget.note == null;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _selectedColor = widget.note?.color ?? '#FFFDE7';
    _isPinned = widget.note?.isPinned ?? false;
    _shoppingJson = widget.note?.autopoolData ?? '';
    _folder = widget.note?.folder ??
        context.read<NotesProvider>().selectedFolder;
    _currentNote = widget.note;
    _titleController.addListener(_onChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (isNewNote && _selectedColor == '#FFFDE7') {
      _selectedColor = context.read<SettingsProvider>().defaultNoteColor;
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _titleController.removeListener(_onChanged);
    _titleController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) _saveNote();
    });
  }

  void _onListChanged(String json) {
    _shoppingJson = json;
    _onChanged();
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  // Speichern serialisieren, damit zwei schnelle Auslöser nicht zwei neue
  // Notizen anlegen (gleiche Logik wie im Text-/Autopool-Editor).
  Future<void> _saveNote() {
    final pending = _saveChain ?? Future<void>.value();
    final next = pending.then((_) => _doSaveNote());
    _saveChain = next.catchError((_) {});
    return next;
  }

  Future<void> _doSaveNote() async {
    final json = _listKey.currentState?.currentJson ?? _shoppingJson;
    _shoppingJson = json;
    final data = ShoppingListData.fromJsonString(json);
    final title = _titleController.text;
    final content = data.toDisplayText();
    final notesProvider = context.read<NotesProvider>();

    // Komplett leer (kein Titel, keine Artikel): bestehende löschen, neue gar
    // nicht erst anlegen.
    if (title.trim().isEmpty && data.isEmpty) {
      if (_currentNote != null) {
        await notesProvider.deleteNote(_currentNote!.id);
        _currentNote = null;
      }
      _hasChanges = false;
      return;
    }

    if (_currentNote == null) {
      final created = await notesProvider.addNote(
        title: title,
        content: content,
        color: _selectedColor,
        type: 'shopping',
        autopoolData: json,
        folder: _folder,
      );
      if (created != null) _currentNote = created;
    } else {
      if (title == _currentNote!.title &&
          json == _currentNote!.autopoolData &&
          _selectedColor == _currentNote!.color &&
          _isPinned == _currentNote!.isPinned &&
          _folder == _currentNote!.folder) {
        _hasChanges = false;
        return;
      }
      final updated = _currentNote!.copyWith(
        title: title,
        content: content,
        color: _selectedColor,
        isPinned: _isPinned,
        autopoolData: json,
        folder: _folder,
      );
      await notesProvider.updateNote(updated);
      _currentNote = updated;
    }
    _hasChanges = false;
  }

  Future<void> _handleBack() async {
    if (_hasChanges) await _saveNote();
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      await SystemNavigator.pop();
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    if (_hasChanges) await _saveNote();
    final result = await GoogleDriveService.instance.synchronize();
    if (!mounted) return;
    setState(() => _syncing = false);
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.success
            ? l10n.syncSuccess
            : '${l10n.syncFailed}: ${result.message}'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: result.success ? 3 : 6),
      ),
    );
  }

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

  void _showColorPicker() async {
    final newColor =
        await showColorPickerSheet(context, currentColor: _selectedColor);
    if (newColor != null) {
      setState(() {
        _selectedColor = newColor;
        _hasChanges = true;
      });
      _onChanged();
    }
  }

  // Notiz einem Ordner zuordnen (lokaler Zustand, beim Speichern geschrieben).
  Future<void> _moveToFolder() async {
    final target = await showFolderPicker(context, currentFolder: _folder);
    if (target == null || !mounted) return;
    setState(() {
      _folder = target;
      _hasChanges = true;
    });
    _saveNote();
  }

  // Drucken/Exportieren (die Einkaufsliste wird als Kästchenliste gedruckt).
  // Vorher speichern, damit der Ausdruck den aktuellen Stand enthält.
  Future<void> _printNote() async {
    if (_hasChanges) await _saveNote();
    final note = _currentNote ?? widget.note;
    if (note == null || !mounted) return;
    final current = context.read<NotesProvider>().getNoteById(note.id) ?? note;
    await showPrintMenu(context, current);
  }

  Future<void> _archiveNote() async {
    _saveDebounce?.cancel();
    final note = _currentNote ?? widget.note;
    if (note == null) return;
    final notesProvider = context.read<NotesProvider>();
    if (_hasChanges) await _saveNote();
    final id = (_currentNote ?? note).id;
    await notesProvider.archiveNote(id);
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      await SystemNavigator.pop();
    }
  }

  void _confirmDelete() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.deleteNote),
        content: Text(l10n.deleteNoteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final id = _currentNote?.id ?? widget.note?.id;
              if (id != null) {
                context.read<NotesProvider>().deleteNote(id);
              }
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleWidget() async {
    final note = _currentNote ?? widget.note;
    if (note == null) return;
    if (_hasChanges) await _saveNote();
    final current = _currentNote ?? note;
    final isWidget = await StickyNoteService.instance.isWidget(current.id);
    await StickyNoteService.instance.setWidget(current.id, !isWidget);
    if (!isWidget) {
      await StickyNoteService.instance.openStickyNote(current);
    } else {
      await StickyNoteService.instance.closeStickyNote(current.id);
    }
  }

  Future<void> _showMoreOptions() async {
    final l10n = AppLocalizations.of(context)!;
    final noteId = _currentNote?.id ?? widget.note?.id;
    var isWidgetPinned = false;
    if (_isDesktop && !isNewNote && noteId != null) {
      isWidgetPinned = await StickyNoteService.instance.isWidget(noteId);
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      // Scrollbar + volle Höhe erlauben (Desktop-Fenster kann klein sein).
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SheetBody(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                      _isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                  title: Text(_isPinned ? l10n.unpin : l10n.pin),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _isPinned = !_isPinned;
                      _hasChanges = true;
                    });
                    _onChanged();
                  },
                ),
                if (_isDesktop && !isNewNote)
                  ListTile(
                    leading: Icon(
                        isWidgetPinned ? Icons.widgets : Icons.widgets_outlined),
                    title: Text(
                        isWidgetPinned ? l10n.unpinWidget : l10n.pinAsWidget),
                    onTap: () {
                      Navigator.pop(context);
                      _toggleWidget();
                    },
                  ),
                ListTile(
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _parseColor(_selectedColor),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
                  title: Text(l10n.color),
                  onTap: () {
                    Navigator.pop(context);
                    _showColorPicker();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.drive_file_move_outlined),
                  title: Text(l10n.moveToFolder),
                  onTap: () {
                    Navigator.pop(context);
                    _moveToFolder();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: Text(l10n.printExport),
                  onTap: () {
                    Navigator.pop(context);
                    _printNote();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(l10n.settings),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                if (!isNewNote)
                  ListTile(
                    leading: const Icon(Icons.archive_outlined),
                    title: Text(l10n.archive),
                    onTap: () {
                      Navigator.pop(context);
                      _archiveNote();
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.unarchive_outlined),
                  title: Text(l10n.archiveAndRestore),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ArchiveScreen()),
                    );
                  },
                ),
                if (!isNewNote)
                  ListTile(
                    leading:
                        const Icon(Icons.delete_outlined, color: Colors.red),
                    title: Text(l10n.delete,
                        style: const TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      _confirmDelete();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _goToMainMenu() async {
    if (_hasChanges) await _saveNote();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  // Aktuellste bekannte Änderungszeit (Provider-Stand bevorzugt).
  DateTime _currentModifiedAt() {
    final id = _currentNote?.id ?? widget.note?.id;
    if (id != null) {
      final current = context.read<NotesProvider>().getNoteById(id);
      if (current != null) return current.modifiedAt;
    }
    return _currentNote?.modifiedAt ?? widget.note?.modifiedAt ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final noteColor = _parseColor(_selectedColor);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final fontScale = context.watch<SettingsProvider>().noteFontScale;

    final noteTextColor =
        ThemeData.estimateBrightnessForColor(noteColor) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    final scaffoldColor = isDarkMode ? theme.scaffoldBackgroundColor : noteColor;
    final appBarColor = isDarkMode ? theme.appBarTheme.backgroundColor : noteColor;
    final foregroundColor = isDarkMode ? Colors.white : noteTextColor;
    final signedIn = GoogleDriveService.instance.isSignedIn;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: scaffoldColor,
        appBar: AppBar(
          backgroundColor: appBarColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: Text(l10n.shoppingList,
              style: TextStyle(fontSize: 16, color: foregroundColor)),
          actions: [
            // Letzte Änderungs-/Sync-Zeit (tippbar = synchronisieren).
            if (!isNewNote)
              Center(
                child: Builder(
                  builder: (context) {
                    final timeText = Text(
                      DateFormat('d.M. HH:mm', 'de')
                          .format(_currentModifiedAt()),
                      style: TextStyle(
                        fontSize: 12,
                        color: foregroundColor.withValues(alpha: 0.6),
                        decoration:
                            signedIn ? null : TextDecoration.lineThrough,
                      ),
                    );
                    return Tooltip(
                      message: signedIn ? l10n.syncNow : l10n.notSignedIn,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: _syncing
                            ? null
                            : (signedIn ? _syncNow : _showNotSignedIn),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 8),
                          child: timeText,
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (widget.openedFromWidget)
              IconButton(
                icon: const Icon(Icons.home_outlined),
                tooltip: l10n.appTitle,
                onPressed: _goToMainMenu,
              ),
            IconButton(
              icon: _syncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(signedIn ? Icons.sync : Icons.sync_disabled),
              tooltip: signedIn ? l10n.syncNow : l10n.notSignedIn,
              onPressed: _syncing
                  ? null
                  : (signedIn ? _syncNow : _showNotSignedIn),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: _showMoreOptions,
            ),
          ],
        ),
        // Im Dark Mode den Notizbereich mit der Notizfarbe hinterlegen, sonst
        // stünde dunkler Text auf dunklem Grund.
        body: Container(
          margin: isDarkMode ? const EdgeInsets.all(8) : EdgeInsets.zero,
          decoration: isDarkMode
              ? BoxDecoration(
                  color: noteColor,
                  borderRadius: BorderRadius.circular(16),
                )
              : null,
          child: SingleChildScrollView(
            // Unten um die System-Navigationsleiste einrücken, sonst verschwindet
            // der „Artikel hinzufügen"-Button hinter den System-Buttons.
            padding: EdgeInsets.fromLTRB(
                10, 8, 10, 12 + MediaQuery.of(context).viewPadding.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  style: TextStyle(
                    fontSize: 22 * fontScale,
                    fontWeight: FontWeight.bold,
                    color: noteTextColor,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.titleHint,
                    hintStyle: TextStyle(
                      color: noteTextColor.withValues(alpha: 0.4),
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 8),
                ShoppingListView(
                  key: _listKey,
                  initialData: _shoppingJson,
                  onChanged: _onListChanged,
                  textColor: noteTextColor,
                  fontScale: fontScale,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
