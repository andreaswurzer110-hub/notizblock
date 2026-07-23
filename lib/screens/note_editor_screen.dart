import 'dart:async';
import 'dart:io';
import 'dart:ui' show BoxWidthStyle;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../services/google_drive_service.dart';
import '../services/sticky_note_service.dart';
import '../widgets/color_picker.dart';
import '../widgets/note_context_menu.dart';
import '../widgets/folder_picker.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'archive_screen.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  // true, wenn der Editor direkt aus einem (Android-)Widget geöffnet wurde:
  // dann ist er der einzige Screen -> Zurück verlässt die App, Menü-Button führt
  // zur Hauptansicht.
  final bool openedFromWidget;

  const NoteEditorScreen({super.key, this.note, this.openedFromWidget = false});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen>
    with WidgetsBindingObserver {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late String _selectedColor;
  late bool _isPinned;
  // Ordner der Notiz (lokaler Zustand wie Farbe/Anheften). Beim Speichern
  // geschrieben. Neue Notiz startet im aktuell gewählten Ordner.
  late String _folder;
  bool _hasChanges = false;
  bool _syncing = false;
  bool _applyingExternal = false;
  Timer? _saveDebounce;
  DateTime? _lastShownModified;
  // Die tatsächlich in der DB liegende Notiz. Für neue Notizen anfangs null;
  // nach dem ersten Speichern gesetzt, damit weitere Speichervorgänge die
  // gleiche Notiz AKTUALISIEREN statt neu anzulegen (verhindert Duplikate).
  Note? _currentNote;
  // Serialisiert Speichervorgänge, damit zwei schnelle Auslöser nicht beide
  // eine neue Notiz anlegen.
  Future<void>? _saveChain;
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _contentFocus = FocusNode();
  NotesProvider? _notesProvider;

  // Lokale Rückgängig-Funktion: nur für die offene Notiz, nicht persistent.
  // Checkpoints werden beim Tipp-Pausen gesetzt (eine Pause = ein Undo-Schritt).
  final List<_EditorSnapshot> _undoStack = [];
  // Wiederholen-Stapel: rückgängig gemachte Stände, um sie erneut anzuwenden.
  final List<_EditorSnapshot> _redoStack = [];
  late _EditorSnapshot _lastCheckpoint;
  Timer? _undoCheckpointTimer;
  bool _restoringSnapshot = false;

  bool get isNewNote => widget.note == null;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _selectedColor = widget.note?.color ?? '#FFFDE7';
    _isPinned = widget.note?.isPinned ?? false;
    _folder = widget.note?.folder ??
        context.read<NotesProvider>().selectedFolder;
    _lastShownModified = widget.note?.modifiedAt;
    _currentNote = widget.note;
    _lastCheckpoint =
        _EditorSnapshot(_titleController.text, _contentController.text);

    WidgetsBinding.instance.addObserver(this);
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App geht in den Hintergrund/wird beendet -> ungesicherte Änderungen noch
    // schreiben (sonst gehen neue Notizen verloren, wenn der Editor nicht über
    // den Zurück-Pfad verlassen wird).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      if (_hasChanges) _saveNote();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Standard-Farbe für neue Notizen aus Einstellungen
    if (isNewNote && _selectedColor == '#FFFDE7') {
      final settings = context.read<SettingsProvider>();
      _selectedColor = settings.defaultNoteColor;
    }

    // Live-Aktualisierung bei externen Änderungen (z.B. aus Sticky-Fenstern)
    final provider = context.read<NotesProvider>();
    if (provider != _notesProvider) {
      _notesProvider?.removeListener(_onExternalNoteChange);
      _notesProvider = provider;
      _notesProvider!.addListener(_onExternalNoteChange);
    }
  }

  // Übernimmt externe Änderungen an dieser Notiz, ohne aktives Tippen zu stören.
  void _onExternalNoteChange() {
    if (isNewNote || !mounted) return;
    final note = _notesProvider?.getNoteById(widget.note!.id);
    if (note == null) return;

    // Titel/Inhalt nur ersetzen, wenn das Feld nicht fokussiert ist
    // (sonst würde es die gerade getippte Eingabe überschreiben).
    _applyingExternal = true;
    if (!_titleFocus.hasFocus && note.title != _titleController.text) {
      _titleController.value = TextEditingValue(
        text: note.title,
        selection: TextSelection.collapsed(offset: note.title.length),
      );
    }
    if (!_contentFocus.hasFocus && note.content != _contentController.text) {
      _contentController.value = TextEditingValue(
        text: note.content,
        selection: TextSelection.collapsed(offset: note.content.length),
      );
    }
    _applyingExternal = false;
    // Undo-Basis an den externen Stand angleichen, damit Rückgängig nicht auf
    // einen veralteten Vor-Sync-Stand zurückspringt.
    _lastCheckpoint =
        _EditorSnapshot(_titleController.text, _contentController.text);
    final colorChanged = note.color != _selectedColor && !_hasChanges;
    // Neu rendern, wenn sich Farbe ODER die angezeigte Änderungszeit ändert.
    if (colorChanged || note.modifiedAt != _lastShownModified) {
      _lastShownModified = note.modifiedAt;
      setState(() {
        if (colorChanged) _selectedColor = note.color;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDebounce?.cancel();
    _undoCheckpointTimer?.cancel();
    _notesProvider?.removeListener(_onExternalNoteChange);
    _titleController.removeListener(_onTextChanged);
    _contentController.removeListener(_onTextChanged);
    _titleController.dispose();
    _contentController.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Externe Übernahme (Sync/anderes Fenster) markiert die Notiz NICHT als
    // geändert – sonst würde sie beim Schließen unnötig neu gespeichert (bump).
    if (_applyingExternal) return;
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
    // Schon beim Tippen automatisch speichern (entprellt), damit der Auto-Sync
    // zeitnah hochlädt und nichts verloren geht. Auch neue Notizen: nach dem
    // ersten Speichern merkt sich `_currentNote` die Notiz -> kein Duplikat.
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) _saveNote();
    });
    // Undo-Checkpoint nach kurzer Tipp-Pause setzen (nicht bei jedem Zeichen).
    // Beim Wiederherstellen selbst keinen neuen Checkpoint anlegen.
    if (!_restoringSnapshot) {
      // Echte Eingabe verwirft die Wiederholen-Historie.
      if (_redoStack.isNotEmpty) _redoStack.clear();
      _undoCheckpointTimer?.cancel();
      _undoCheckpointTimer =
          Timer(const Duration(milliseconds: 600), _commitCheckpoint);
    }
  }

  // Aktuellen Stand als Undo-Schritt ablegen (vorigen Checkpoint stapeln).
  void _commitCheckpoint() {
    final current =
        _EditorSnapshot(_titleController.text, _contentController.text);
    if (current == _lastCheckpoint) return;
    _undoStack.add(_lastCheckpoint);
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _lastCheckpoint = current;
    if (mounted) setState(() {}); // Undo-Button-Status aktualisieren
  }

  bool get _canUndo {
    if (_undoStack.isNotEmpty) return true;
    return _titleController.text != _lastCheckpoint.title ||
        _contentController.text != _lastCheckpoint.content;
  }

  bool get _canRedo => _redoStack.isNotEmpty;

  // Letzte Änderung rückgängig machen: zuerst noch nicht gestapelte Eingaben
  // bis zum letzten Checkpoint, danach Schritt für Schritt den Stapel hinunter.
  // Der jeweils verlassene Stand wandert auf den Wiederholen-Stapel.
  void _undo() {
    _undoCheckpointTimer?.cancel();
    final current =
        _EditorSnapshot(_titleController.text, _contentController.text);
    _EditorSnapshot? target;
    if (current != _lastCheckpoint) {
      target = _lastCheckpoint;
      _redoStack.add(current);
    } else if (_undoStack.isNotEmpty) {
      target = _undoStack.removeLast();
      _redoStack.add(_lastCheckpoint);
      _lastCheckpoint = target;
    }
    if (target == null) return;
    _applySnapshot(target);
  }

  // Rückgängig gemachte Änderung wiederherstellen (Gegenstück zu _undo).
  void _redo() {
    _undoCheckpointTimer?.cancel();
    if (_redoStack.isEmpty) return;
    final target = _redoStack.removeLast();
    _undoStack.add(_lastCheckpoint);
    _lastCheckpoint = target;
    _applySnapshot(target);
  }

  // Wiederhergestellten/zurückgenommenen Stand in die Felder schreiben und
  // persistieren (Save-Debounce lief über _onTextChanged bereits an).
  void _applySnapshot(_EditorSnapshot target) {
    _restoringSnapshot = true;
    _titleController.value = TextEditingValue(
      text: target.title,
      selection: TextSelection.collapsed(offset: target.title.length),
    );
    _contentController.value = TextEditingValue(
      text: target.content,
      selection: TextSelection.collapsed(offset: target.content.length),
    );
    _restoringSnapshot = false;
    setState(() => _hasChanges = true);
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    // Leere Notiz
    if (_titleController.text.isEmpty && _contentController.text.isEmpty) {
      return true;
    }

    // Automatisch speichern
    await _saveNote();
    return true;
  }

  // Zurück: erst speichern, dann je nach Stack zurück oder App verlassen.
  // Aus einem Widget geöffnet ist der Editor der einzige Screen -> einmal Zurück
  // führt direkt zum Homescreen (App in den Hintergrund).
  Future<void> _handleBack() async {
    await _onWillPop();
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      await SystemNavigator.pop();
    }
  }

  // Zur Hauptansicht (Notizliste) wechseln – als neuer Wurzel-Screen.
  Future<void> _goToMainMenu() async {
    await _onWillPop();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  // Hinweis, wenn nicht bei Drive angemeldet (Sync-Button/Zeit sind dann
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

  // Manueller Sync aus dem Editor (Absicherung).
  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    if (_hasChanges) await _saveNote();
    final result = await GoogleDriveService.instance.synchronize();
    if (!mounted) return;
    setState(() => _syncing = false);
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.success ? l10n.syncSuccess : '${l10n.syncFailed}: ${result.message}'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: result.success ? 3 : 6),
      ),
    );
  }

  // Speichern serialisieren: ein laufender Speichervorgang wird erst beendet,
  // bevor der nächste startet. So legt ein zweiter schneller Auslöser keine
  // zweite neue Notiz an (er sieht dann das bereits gesetzte `_currentNote`).
  Future<void> _saveNote() {
    final pending = _saveChain ?? Future<void>.value();
    final next = pending.then((_) => _doSaveNote());
    // Kette nicht durch einen Fehler dauerhaft blockieren.
    _saveChain = next.catchError((_) {});
    return next;
  }

  Future<void> _doSaveNote() async {
    // Text ungetrimmt speichern, damit bewusst gesetzte Leerzeilen (auch oben)
    // erhalten bleiben – wie beim Windows-Sticky. (Android löschte führende
    // Leerzeilen früher durch das trim().) Für „leer?"/„geändert?" trotzdem
    // getrimmt prüfen.
    final title = _titleController.text;
    final content = _contentController.text;
    final notesProvider = _notesProvider ?? context.read<NotesProvider>();

    // Leere Notiz: bestehende löschen, neue gar nicht erst anlegen.
    if (title.trim().isEmpty && content.trim().isEmpty) {
      if (_currentNote != null) {
        await notesProvider.deleteNote(_currentNote!.id);
        _currentNote = null;
      }
      _hasChanges = false;
      return;
    }

    if (_currentNote == null) {
      // Erstes Speichern -> anlegen und merken (danach Update-Modus).
      final created = await notesProvider.addNote(
        title: title,
        content: content,
        color: _selectedColor,
        folder: _folder,
      );
      if (created != null) _currentNote = created;
    } else {
      // Nichts wirklich geändert? Dann nicht speichern (sonst unnötiger
      // modifiedAt-Bump).
      if (title == _currentNote!.title &&
          content == _currentNote!.content &&
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
        folder: _folder,
      );
      await notesProvider.updateNote(updated);
      _currentNote = updated;
    }

    _hasChanges = false;
  }

  void _showColorPicker() async {
    final newColor = await showColorPickerSheet(
      context,
      currentColor: _selectedColor,
    );
    if (newColor != null) {
      setState(() {
        _selectedColor = newColor;
        _hasChanges = true;
      });
    }
  }

  void _togglePin() {
    setState(() {
      _isPinned = !_isPinned;
      _hasChanges = true;
    });
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

  // Notiz als Desktop-Widget anheften/lösen (nur Desktop). Beim Anheften öffnet
  // sich direkt das Sticky-Fenster, beim Lösen wird ein offenes geschlossen.
  Future<void> _toggleWidget() async {
    final note = _currentNote ?? widget.note;
    if (note == null) return;
    // Aktuellen Stand sichern, damit ein frisch geöffnetes Sticky-Fenster den
    // neuesten Inhalt zeigt.
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

  // Notiz archivieren und den Editor schließen (sie verschwindet aus der Liste).
  Future<void> _archiveNote() async {
    // Anstehenden Auto-Save abbrechen, sonst könnte er nach dem Archivieren den
    // (im Speicher noch un-archivierten) Stand zurückschreiben.
    _saveDebounce?.cancel();
    final note = _currentNote ?? widget.note;
    if (note == null) return;
    if (_hasChanges) await _saveNote();
    final id = (_currentNote ?? note).id;
    await (_notesProvider ?? context.read<NotesProvider>()).archiveNote(id);
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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
              if (!isNewNote) {
                context.read<NotesProvider>().deleteNote(widget.note!.id);
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

  Future<void> _showMoreOptions() async {
    final l10n = AppLocalizations.of(context)!;
    // Widget-Status (nur Desktop) vorab ermitteln, um „anheften/lösen" korrekt
    // zu beschriften. showModalBottomSheet baut synchron -> vorher awaiten.
    final noteId = _currentNote?.id ?? widget.note?.id;
    var isWidgetPinned = false;
    if (_isDesktop && !isNewNote && noteId != null) {
      isWidgetPinned = await StickyNoteService.instance.isWidget(noteId);
    }
    if (!mounted) return;

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
                // Anheften (aus der oberen Leiste hierher verschoben)
                ListTile(
                  leading: Icon(
                    _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  ),
                  title: Text(_isPinned ? l10n.unpin : l10n.pin),
                  onTap: () {
                    Navigator.pop(context);
                    _togglePin();
                  },
                ),

                // Als Widget anheften/lösen (nur Desktop, nur bestehende Notiz)
                if (_isDesktop && !isNewNote)
                  ListTile(
                    leading: Icon(
                      isWidgetPinned ? Icons.widgets : Icons.widgets_outlined,
                    ),
                    title: Text(
                        isWidgetPinned ? l10n.unpinWidget : l10n.pinAsWidget),
                    onTap: () {
                      Navigator.pop(context);
                      _toggleWidget();
                    },
                  ),

                // Farbe
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

                // In Ordner verschieben
                ListTile(
                  leading: const Icon(Icons.drive_file_move_outlined),
                  title: Text(l10n.moveToFolder),
                  onTap: () {
                    Navigator.pop(context);
                    _moveToFolder();
                  },
                ),

                // Einstellungen direkt aus dem Editor öffnen
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(l10n.settings),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),

                // Archivieren (nur bestehende Notiz)
                if (!isNewNote)
                  ListTile(
                    leading: const Icon(Icons.archive_outlined),
                    title: Text(l10n.archive),
                    onTap: () {
                      Navigator.pop(context);
                      _archiveNote();
                    },
                  ),

                // Archiv & Wiederherstellen (Liste der archivierten/gelöschten)
                ListTile(
                  leading: const Icon(Icons.unarchive_outlined),
                  title: Text(l10n.archiveAndRestore),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ArchiveScreen(),
                      ),
                    );
                  },
                ),

                // Löschen
                if (!isNewNote)
                  ListTile(
                    leading: const Icon(Icons.delete_outlined, color: Colors.red),
                    title: Text(
                      l10n.delete,
                      style: const TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _confirmDelete();
                    },
                  ),

                // Info
                if (!isNewNote && widget.note != null) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.createdAt(_formatDateTime(widget.note!.createdAt)),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.modifiedAt(
                              _formatDateTime(widget.note!.modifiedAt)),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // Aktuellste bekannte Änderungszeit: bevorzugt der Provider-Stand (zieht nach
  // Speichern/Sync nach), sonst der Stand beim Öffnen.
  DateTime get _currentModifiedAt {
    final id = _currentNote?.id ?? widget.note?.id;
    if (id != null) {
      final current = _notesProvider?.getNoteById(id);
      if (current != null) return current.modifiedAt;
    }
    return _currentNote?.modifiedAt ?? widget.note?.modifiedAt ?? DateTime.now();
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('d. MMMM yyyy, HH:mm', 'de').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final noteColor = _parseColor(_selectedColor);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    // Schriftgröße der Notiztexte aus den Einstellungen.
    final fontScale = context.watch<SettingsProvider>().noteFontScale;
    // Textfarbe je nach Helligkeit der Notizfarbe (kräftige/dunkle Farben ->
    // heller Text), damit es immer lesbar bleibt.
    final noteTextColor =
        ThemeData.estimateBrightnessForColor(noteColor) == Brightness.dark
            ? Colors.white
            : Colors.black87;
    final noteHintColor = noteTextColor.withValues(alpha: 0.4);

    // Im Dark Mode: Scaffold dunkel, Notizbereich in Notizfarbe
    // Im Light Mode: Alles in Notizfarbe
    final scaffoldColor = isDarkMode ? theme.scaffoldBackgroundColor : noteColor;
    final appBarColor = isDarkMode ? theme.appBarTheme.backgroundColor : noteColor;
    final foregroundColor = isDarkMode ? Colors.white : noteTextColor;

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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          actions: [
            // Rückgängig: letzte Änderung der offenen Notiz lokal zurücknehmen.
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: l10n.undo,
              onPressed: _canUndo ? _undo : null,
            ),
            // Wiederholen: zurückgenommene Änderung erneut anwenden.
            IconButton(
              icon: const Icon(Icons.redo),
              tooltip: l10n.redo,
              onPressed: _canRedo ? _redo : null,
            ),
            // Letzte Änderungs-/Sync-Zeit (nur bei bestehenden Notizen).
            // Bei angemeldetem Drive ist die Zeit zugleich Sync-Auslöser
            // (gleiche Funktion wie der Sync-Button rechts).
            if (!isNewNote)
              Center(
                child: Builder(
                  builder: (context) {
                    final signedIn = GoogleDriveService.instance.isSignedIn;
                    // Zeit/Datum durchgestrichen, wenn nicht angemeldet – damit
                    // der abgemeldete Zustand sofort auffällt.
                    final timeText = Text(
                      DateFormat('d.M. HH:mm', 'de').format(_currentModifiedAt),
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
            // Aus Widget geöffnet: Button zur Hauptansicht (Notizliste)
            if (widget.openedFromWidget)
              IconButton(
                icon: const Icon(Icons.home_outlined),
                tooltip: l10n.appTitle,
                onPressed: _goToMainMenu,
              ),
            // Manueller Sync (Absicherung). Bleibt immer sichtbar; nicht
            // angemeldet -> durchgestrichenes Icon (sync_disabled) + Hinweis.
            IconButton(
              icon: _syncing
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
              onPressed: _syncing
                  ? null
                  : (GoogleDriveService.instance.isSignedIn
                      ? _syncNow
                      : _showNotSignedIn),
            ),
            // Mehr-Optionen (inkl. Anheften – spart oben Platz, v.a. auf Android)
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: _showMoreOptions,
            ),
          ],
        ),
        body: Container(
          margin: isDarkMode ? const EdgeInsets.all(12) : EdgeInsets.zero,
          decoration: isDarkMode
              ? BoxDecoration(
                  color: noteColor,
                  borderRadius: BorderRadius.circular(16),
                )
              : null,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titel
                TextField(
                  controller: _titleController,
                  focusNode: _titleFocus,
                  style: TextStyle(
                    fontSize: 24 * fontScale,
                    fontWeight: FontWeight.bold,
                    color: noteTextColor,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.titleHint,
                    hintStyle: TextStyle(
                      color: noteHintColor,
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  // Markierung eng an den Text legen (Flutter-Default auf
                  // Android/Desktop ist .max → markiert sonst die ganze Zeile
                  // bis zum rechten Rand mit, sobald ein Zeilenumbruch im
                  // markierten Bereich liegt).
                  selectionWidthStyle: BoxWidthStyle.tight,
                  contextMenuBuilder: buildNoteContextMenu,
                ),

                const SizedBox(height: 16),

                // Inhalt
                TextField(
                  controller: _contentController,
                  focusNode: _contentFocus,
                  style: TextStyle(
                    fontSize: 16 * fontScale,
                    height: 1.6,
                    color: noteTextColor,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.contentHint,
                    hintStyle: TextStyle(
                      color: noteHintColor,
                    ),
                    border: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: null,
                  minLines: 10,
                  textCapitalization: TextCapitalization.sentences,
                  // s. Titel: enge Markierung statt voller Zeilenbreite.
                  selectionWidthStyle: BoxWidthStyle.tight,
                  contextMenuBuilder: buildNoteContextMenu,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Momentaufnahme von Titel/Inhalt für die lokale Rückgängig-Funktion.
class _EditorSnapshot {
  final String title;
  final String content;
  const _EditorSnapshot(this.title, this.content);

  @override
  bool operator ==(Object other) =>
      other is _EditorSnapshot &&
      other.title == title &&
      other.content == content;

  @override
  int get hashCode => Object.hash(title, content);
}