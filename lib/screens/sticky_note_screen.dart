import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show BoxWidthStyle;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';
import '../models/autopool.dart';
import '../models/shopping_list.dart';
import '../services/database_service.dart';
import '../services/sticky_note_service.dart';
import '../services/main_instance_service.dart';
import '../services/google_drive_service.dart';
import '../services/settings_store.dart';
import '../providers/settings_provider.dart';
import '../providers/notes_provider.dart' show NotesProvider;
import '../widgets/autopool_table.dart';
import '../widgets/shopping_list_view.dart';
import '../widgets/color_picker.dart';
import '../widgets/note_context_menu.dart';
import '../widgets/print_menu.dart';
import '../widgets/sheet_body.dart';
import '../widgets/version_history.dart';

class StickyNoteScreen extends StatefulWidget {
  final String noteId;

  const StickyNoteScreen({super.key, required this.noteId});

  @override
  State<StickyNoteScreen> createState() => _StickyNoteScreenState();
}

class _StickyNoteScreenState extends State<StickyNoteScreen>
    with WindowListener {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final FocusNode _contentFocus = FocusNode();
  // Autopool-Tabelle (nur bei type=='autopool'). Über den Key liest/setzt das
  // Fenster den Tabellenstand (z.B. externe Sync-Änderungen einspielen).
  final GlobalKey<AutopoolTableState> _autopoolKey =
      GlobalKey<AutopoolTableState>();
  String _autopoolJson = '';
  // Einkaufsliste (nur bei type=='shopping'), analog zur Autopool-Tabelle:
  // gleiche Key-API (currentJson/setData/hasFocus). Beide strukturierten Typen
  // liegen im selben Feld note.autopoolData.
  final GlobalKey<ShoppingListViewState> _shoppingKey =
      GlobalKey<ShoppingListViewState>();
  String _shoppingJson = '';
  Note? _note;
  bool _isLoading = true;
  bool _syncing = false;
  // Drive-Login-Status; bei false werden Sync-Button und Zeit durchgestrichen.
  // Wird im 1-s-Poll aktualisiert (der stille Login läuft async beim Start).
  bool _isSignedIn = false;
  double _fontScale = 1.0;
  Timer? _saveTimer;
  Timer? _pollTimer;
  Timer? _stickyAutoSyncTimer;
  Timer? _stickyPullTimer;
  Timer? _boundsSaveTimer;
  // Zuletzt gespeicherte Fenster-Lage – um nur bei echter Änderung zu schreiben.
  Rect? _lastSavedBounds;

  // Lokale Rückgängig-Funktion (nur Inhalt; Titel steckt in der Fenstertitelleiste).
  final List<String> _undoStack = [];
  // Wiederholen-Stapel: rückgängig gemachte Stände, um sie erneut anzuwenden.
  final List<String> _redoStack = [];
  String _lastCheckpoint = '';
  Timer? _undoCheckpointTimer;
  bool _restoringSnapshot = false;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
    _isSignedIn = GoogleDriveService.instance.isSignedIn;
    if (_isDesktop) {
      windowManager.addListener(this);
      // Eigene PID hinterlegen, damit die Hauptapp dieses Widget nicht doppelt öffnet.
      StickyNoteService.instance.markStickyOpen(widget.noteId);
      // Externe Änderungen (Sync, Hauptfenster) live übernehmen.
      _pollTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _checkExternalUpdate(),
      );
      // Selbstständig von Drive ziehen (falls Hauptfenster geschlossen ist).
      _stickyPullTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _runStickyAutoSync(),
      );
      // Fenster-Lage periodisch sichern. Wichtig v.a. auf Linux: dort feuern die
      // onWindowMoved/onWindowResized/onWindowClose-Events nicht zuverlässig, und
      // beim Reboot wird der Prozess hart beendet (kein sauberes Close) → ohne
      // dieses Polling würde die zuletzt eingestellte Größe/Position nie gemerkt.
      _boundsSaveTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _saveBounds(),
      );
    }
    _loadNote();
    _loadFontScale();
  }

  Future<void> _loadFontScale() async {
    // Prozesssicher aus settings.json (Hauptapp ist der Schreiber). reload() für
    // den aktuellen Stand – die Hauptapp kann die Schriftgröße geändert haben.
    await SettingsStore.reload();
    final scale =
        SettingsStore.getDouble(SettingsProvider.noteFontScaleKey) ?? 1.0;
    if (mounted && scale != _fontScale) setState(() => _fontScale = scale);
  }

  // Automatischer Sync aus dem Sticky-Fenster (nur bei aktivem Auto-Sync).
  Future<void> _runStickyAutoSync() async {
    if (!_isDesktop || _syncing) return;
    await SettingsStore.reload();
    if (!(SettingsStore.getBool(SettingsProvider.autoSyncKey) ?? false)) return;
    if (!GoogleDriveService.instance.isSignedIn) return;
    await _saveNote();
    final result = await GoogleDriveService.instance.synchronize();
    if (result.success && mounted) {
      await _checkExternalUpdate();
    }
  }

  // Übernimmt externe Änderungen an dieser Notiz, ohne aktives Tippen zu stören.
  Future<void> _checkExternalUpdate() async {
    if (_isLoading) return;
    _loadFontScale(); // Schriftgröße-Änderung aus der Hauptapp live übernehmen
    // Login-Status live nachziehen (Durchstreichen von Sync-Button/Zeit).
    final signedIn = GoogleDriveService.instance.isSignedIn;
    if (mounted && signedIn != _isSignedIn) {
      setState(() => _isSignedIn = signedIn);
    }
    final note = await DatabaseService.instance.getNoteById(widget.noteId);
    if (!mounted) return;

    // Notiz wurde extern gelöscht (z.B. via Sync) -> Fenster schließen.
    if (note == null) {
      _pollTimer?.cancel();
      if (_isDesktop) await windowManager.close();
      return;
    }

    // Autopool: Tabellendaten extern übernehmen (nur wenn nicht gerade getippt),
    // plus Farbe/Titel. content ist abgeleitet -> nicht vergleichen.
    if (note.isAutopool) {
      final dataChanged = note.autopoolData != _note?.autopoolData;
      final colorChanged = note.color != _note?.color;
      final titleChanged = note.title != _note?.title;
      if (!dataChanged && !colorChanged && !titleChanged) return;
      if (dataChanged && !(_autopoolKey.currentState?.hasFocus ?? false)) {
        _autopoolJson = note.autopoolData;
        _autopoolKey.currentState?.setData(note.autopoolData);
      }
      if (titleChanged) _titleController.text = note.title;
      setState(() => _note = note);
      if (_isDesktop) {
        await windowManager
            .setTitle(note.title.isNotEmpty ? note.title : 'Notiz');
      }
      return;
    }

    // Einkaufsliste: analog zur Autopool-Tabelle die Struktur extern übernehmen
    // (nur wenn nicht gerade getippt), plus Farbe/Titel.
    if (note.isShopping) {
      final dataChanged = note.autopoolData != _note?.autopoolData;
      final colorChanged = note.color != _note?.color;
      final titleChanged = note.title != _note?.title;
      if (!dataChanged && !colorChanged && !titleChanged) return;
      if (dataChanged && !(_shoppingKey.currentState?.hasFocus ?? false)) {
        _shoppingJson = note.autopoolData;
        _shoppingKey.currentState?.setData(note.autopoolData);
      }
      if (titleChanged) _titleController.text = note.title;
      setState(() => _note = note);
      if (_isDesktop) {
        await windowManager
            .setTitle(note.title.isNotEmpty ? note.title : 'Notiz');
      }
      return;
    }

    final contentChanged = note.content != _contentController.text;
    final colorChanged = note.color != _note?.color;
    final titleChanged = note.title != _note?.title;
    if (!contentChanged && !colorChanged && !titleChanged) return;

    // Inhalt nur ersetzen, wenn nicht gerade getippt wird.
    if (contentChanged && !_contentFocus.hasFocus) {
      _contentController.value = TextEditingValue(
        text: note.content,
        // Schreibmarke NICHT ans Ende setzen – sonst scrollt eine lange Notiz
        // bei jeder Fremdänderung nach unten (siehe NoteEditorScreen).
        selection: _keptSelection(_contentController, note.content),
      );
      // Undo-Basis an externen Stand angleichen (kein Rückspringen auf Vor-Sync).
      _lastCheckpoint = note.content;
    }
    // Titel-Controller (nicht sichtbar) für korrektes Speichern aktuell halten.
    if (titleChanged) _titleController.text = note.title;

    setState(() => _note = note); // Hintergrundfarbe aktualisieren
    if (_isDesktop) {
      await windowManager
          .setTitle(note.title.isNotEmpty ? note.title : 'Notiz');
    }
  }

  Future<void> _loadNote() async {
    try {
      _note = await DatabaseService.instance.getNoteById(widget.noteId);
      if (_note != null) {
        _titleController.text = _note!.title;
        _contentController.text = _note!.content;
        // Schreibmarke an den Anfang (siehe _keptSelection): sonst setzt Flutter
        // sie beim Fokussieren ans Textende und scrollt dorthin.
        _contentController.selection = const TextSelection.collapsed(offset: 0);
        _autopoolJson = _note!.autopoolData;
        _shoppingJson = _note!.autopoolData;
        _lastCheckpoint = (_note!.isAutopool || _note!.isShopping)
            ? _note!.autopoolData
            : _note!.content;
        if (_isDesktop) {
          final title = _note!.title.isNotEmpty ? _note!.title : 'Notiz';
          await windowManager.setTitle(title);
        }
      }
    } catch (e) {
      debugPrint('Fehler beim Laden: $e');
    }
    setState(() => _isLoading = false);
  }

  // Fensterposition/-größe merken. Wird sowohl von den Fenster-Events als auch
  // vom periodischen Timer aufgerufen → nur bei echter Änderung schreiben.
  Future<void> _saveBounds() async {
    if (!_isDesktop) return;
    try {
      // Minimiertes Fenster NIE speichern: Windows liefert dafür die
      // Platzhalter-Lage -32000/-32000 in Titelleisten-Größe. Landet die in der
      // Zustandsdatei, öffnet das Widget künftig unsichtbar außerhalb des
      // Bildschirms (siehe StickyNoteService.isPlausibleBounds).
      if (await windowManager.isMinimized()) return;
      final bounds = await windowManager.getBounds();
      // Zusätzliche Absicherung, falls isMinimized() den Zustand verpasst.
      if (!StickyNoteService.isPlausibleBounds(bounds)) return;
      final last = _lastSavedBounds;
      if (last != null &&
          (last.left - bounds.left).abs() < 1 &&
          (last.top - bounds.top).abs() < 1 &&
          (last.width - bounds.width).abs() < 1 &&
          (last.height - bounds.height).abs() < 1) {
        return; // unverändert
      }
      _lastSavedBounds = bounds;
      await StickyNoteService.instance.saveBounds(widget.noteId, bounds);
    } catch (e) {
      debugPrint('Fenster-Bounds speichern fehlgeschlagen: $e');
    }
  }

  @override
  void onWindowMoved() => _saveBounds();

  @override
  void onWindowResized() => _saveBounds();

  @override
  void onWindowClose() => _saveBounds();

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    _pollTimer?.cancel();
    _stickyAutoSyncTimer?.cancel();
    _stickyPullTimer?.cancel();
    _boundsSaveTimer?.cancel();
    _saveTimer?.cancel();
    _undoCheckpointTimer?.cancel();
    _saveNote();
    _contentFocus.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveNote);
    // Nach dem Tippen automatisch syncen (entprellt).
    _stickyAutoSyncTimer?.cancel();
    _stickyAutoSyncTimer =
        Timer(const Duration(seconds: 2), _runStickyAutoSync);
    // Undo-Checkpoint nach kurzer Tipp-Pause (nicht bei jedem Zeichen).
    if (!_restoringSnapshot) {
      // Echte Eingabe verwirft die Wiederholen-Historie.
      if (_redoStack.isNotEmpty) _redoStack.clear();
      _undoCheckpointTimer?.cancel();
      _undoCheckpointTimer =
          Timer(const Duration(milliseconds: 600), _commitCheckpoint);
    }
    // Undo-Button-Status aktualisieren.
    if (mounted) setState(() {});
  }

  // Aktueller Stand für Undo: bei Autopool/Einkaufsliste die jeweilige JSON,
  // sonst der Text.
  String get _currentSnapshot {
    if (_note?.isAutopool == true) {
      return _autopoolKey.currentState?.currentJson ?? _autopoolJson;
    }
    if (_note?.isShopping == true) {
      return _shoppingKey.currentState?.currentJson ?? _shoppingJson;
    }
    return _contentController.text;
  }

  // Aktuellen Stand als Undo-Schritt ablegen (vorigen Checkpoint stapeln).
  void _commitCheckpoint() {
    final current = _currentSnapshot;
    if (current == _lastCheckpoint) return;
    _undoStack.add(_lastCheckpoint);
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _lastCheckpoint = current;
    if (mounted) setState(() {});
  }

  bool get _canUndo =>
      _undoStack.isNotEmpty || _currentSnapshot != _lastCheckpoint;

  bool get _canRedo => _redoStack.isNotEmpty;

  // Letzte Änderung rückgängig machen: zuerst noch nicht gestapelte Eingaben bis
  // zum letzten Checkpoint, danach Schritt für Schritt den Stapel hinunter.
  // Der jeweils verlassene Stand wandert auf den Wiederholen-Stapel.
  void _undo() {
    _undoCheckpointTimer?.cancel();
    final current = _currentSnapshot;
    String? target;
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

  // Stand in das Inhaltsfeld schreiben und speichern + syncen (onChanged feuert
  // bei programmatischer Änderung nicht von selbst).
  void _applySnapshot(String target) {
    _restoringSnapshot = true;
    if (_note?.isAutopool == true || _note?.isShopping == true) {
      // Autopool/Einkaufsliste: Struktur-Stand setzen (setData feuert kein
      // onChanged) und Speichern + Sync selbst anstoßen.
      if (_note?.isAutopool == true) {
        _autopoolJson = target;
        _autopoolKey.currentState?.setData(target);
      } else {
        _shoppingJson = target;
        _shoppingKey.currentState?.setData(target);
      }
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(milliseconds: 500), _saveNote);
      _stickyAutoSyncTimer?.cancel();
      _stickyAutoSyncTimer =
          Timer(const Duration(seconds: 2), _runStickyAutoSync);
      _restoringSnapshot = false;
      if (mounted) setState(() {});
      return;
    }
    _contentController.value = TextEditingValue(
      text: target,
      selection: TextSelection.collapsed(offset: target.length),
    );
    _onTextChanged();
    _restoringSnapshot = false;
  }

  /// Bisherige Schreibmarke beibehalten, auf die neue Textlänge begrenzt
  /// (siehe NoteEditorScreen – verhindert das Springen ans Textende).
  static TextSelection _keptSelection(
      TextEditingController controller, String newText) {
    final offset = controller.selection.baseOffset;
    if (offset < 0) return const TextSelection.collapsed(offset: 0);
    return TextSelection.collapsed(offset: offset.clamp(0, newText.length));
  }

  Future<void> _saveNote() async {
    if (_note == null) return;
    final newTitle = _titleController.text;
    // Autopool: Quelle ist die Tabelle (JSON); content wird daraus als lesbarer
    // Text erzeugt. Ohne echte Änderung NICHT speichern (kein modifiedAt-Bump).
    if (_note!.isAutopool) {
      final json = _autopoolKey.currentState?.currentJson ?? _autopoolJson;
      _autopoolJson = json;
      if (newTitle == _note!.title && json == _note!.autopoolData) return;
      final content = AutopoolData.fromJsonString(json).toDisplayText();
      final updated = _note!
          .copyWith(title: newTitle, content: content, autopoolData: json);
      await DatabaseService.instance.updateNote(updated);
      _note = updated;
      return;
    }
    // Einkaufsliste: Quelle ist die Liste (JSON); content wird daraus als
    // lesbarer Text erzeugt. Ohne echte Änderung NICHT speichern.
    if (_note!.isShopping) {
      final json = _shoppingKey.currentState?.currentJson ?? _shoppingJson;
      _shoppingJson = json;
      if (newTitle == _note!.title && json == _note!.autopoolData) return;
      final content = ShoppingListData.fromJsonString(json).toDisplayText();
      final updated = _note!
          .copyWith(title: newTitle, content: content, autopoolData: json);
      await DatabaseService.instance.updateNote(updated);
      _note = updated;
      return;
    }
    final newContent = _contentController.text;
    // Ohne echte Änderung NICHT speichern – sonst würde modifiedAt unnötig auf
    // "jetzt" gesetzt (verfälscht die Änderungszeit und gewinnt fälschlich beim
    // Sync gegen Änderungen anderer Geräte).
    if (newTitle == _note!.title && newContent == _note!.content) return;
    final updatedNote = _note!.copyWith(title: newTitle, content: newContent);
    await DatabaseService.instance.updateNote(updatedNote);
    _note = updatedNote;
  }

  // Tabellenänderung (Autopool): entprellt speichern + syncen + Undo-Checkpoint.
  void _onAutopoolChanged(String json) {
    _autopoolJson = json;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveNote);
    _stickyAutoSyncTimer?.cancel();
    _stickyAutoSyncTimer =
        Timer(const Duration(seconds: 2), _runStickyAutoSync);
    if (!_restoringSnapshot) {
      if (_redoStack.isNotEmpty) _redoStack.clear();
      _undoCheckpointTimer?.cancel();
      _undoCheckpointTimer =
          Timer(const Duration(milliseconds: 600), _commitCheckpoint);
    }
    if (mounted) setState(() {});
  }

  // Listenänderung (Einkaufsliste): identisch zu _onAutopoolChanged, nur die
  // Quelle ist die Einkaufsliste.
  void _onShoppingChanged(String json) {
    _shoppingJson = json;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveNote);
    _stickyAutoSyncTimer?.cancel();
    _stickyAutoSyncTimer =
        Timer(const Duration(seconds: 2), _runStickyAutoSync);
    if (!_restoringSnapshot) {
      if (_redoStack.isNotEmpty) _redoStack.clear();
      _undoCheckpointTimer?.cancel();
      _undoCheckpointTimer =
          Timer(const Duration(milliseconds: 600), _commitCheckpoint);
    }
    if (mounted) setState(() {});
  }

  // --- Optionen-Menü des Widget-Fensters ---------------------------------
  //
  // Gleiche Möglichkeiten wie das Dreipunkte-Menü des Editors in der Hauptapp.
  // Erreichbar über den ⋮-Knopf der Leiste und per Rechtsklick auf die Leiste.
  //
  // Achtung: Das Sticky-Fenster ist ein EIGENER Prozess ohne NotesProvider – es
  // schreibt direkt über den DatabaseService. Und es darf `settings.json` NICHT
  // schreiben (siehe CLAUDE.md), deshalb lässt sich hier nur in EXISTIERENDE
  // Ordner verschieben; neue Ordner legt man in der Hauptapp an.
  Future<void> _showMoreOptions() async {
    if (_note == null) return;
    // Anstehende Eingaben sichern, damit das Menü auf dem aktuellen Stand
    // arbeitet (z.B. Drucken).
    _saveTimer?.cancel();
    await _saveNote();
    if (!mounted) return;
    final note = _note!;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SheetBody(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  note.title.isNotEmpty ? note.title : 'Notiz',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                    note.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
                title: Text(note.isPinned ? 'Nicht anheften' : 'Anheften'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _togglePin();
                },
              ),
              ListTile(
                leading: const Icon(Icons.widgets),
                title: const Text('Widget lösen'),
                subtitle: const Text('Schließt dieses Fenster'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _unpinWidget();
                },
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Farbe'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickColor();
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined),
                title: const Text('In Ordner verschieben'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _moveToFolder();
                },
              ),
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: const Text('Drucken'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showPrintMenu(context, _note ?? note);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Frühere Versionen'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showVersions();
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Einstellungen'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openSettings();
                },
              ),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Hauptmenü öffnen'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openMainApp();
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('Archivieren'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _archiveNote();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outlined, color: Colors.red),
                title:
                    const Text('Löschen', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete();
                },
              ),
              const Divider(),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Erstellt: ${DateFormat('d. MMMM yyyy, HH:mm', 'de').format(note.createdAt)}',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Geändert: ${DateFormat('d. MMMM yyyy, HH:mm', 'de').format(note.modifiedAt)}',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Notiz-Eigenschaft ändern und speichern (Farbe/Anheften/Ordner/Archiv).
  // Der Sticky-Prozess schreibt direkt in die DB; der eigene Auto-Sync lädt die
  // Änderung anschließend hoch.
  Future<void> _applyNoteChange(Note updated) async {
    await DatabaseService.instance.updateNote(updated);
    if (!mounted) return;
    setState(() => _note = updated);
    _stickyAutoSyncTimer?.cancel();
    _stickyAutoSyncTimer =
        Timer(const Duration(seconds: 2), _runStickyAutoSync);
  }

  /// Frühere Versionen aus dem Drive-Verlauf. Das Sticky-Fenster ist ein
  /// eigener Prozess OHNE NotesProvider – deshalb wird das Wiederherstellen
  /// hier selbst erledigt (direkt über den DatabaseService) und die Anzeige
  /// danach aktualisiert.
  Future<void> _showVersions() async {
    final note = _note;
    if (note == null) return;
    await showVersionHistory(
      context,
      note,
      onRestore: (version) async {
        final current = _note ?? note;
        final restored = current.copyWith(
          title: version.title,
          content: version.content,
          autopoolData: version.autopoolData,
        );
        await _applyNoteChange(restored);
        if (!mounted) return;
        // Eingabefelder/Tabelle auf den wiederhergestellten Stand setzen.
        _titleController.text = restored.title;
        if (restored.isAutopool) {
          _autopoolJson = restored.autopoolData;
          _autopoolKey.currentState?.setData(restored.autopoolData);
        } else if (restored.isShopping) {
          _shoppingJson = restored.autopoolData;
          _shoppingKey.currentState?.setData(restored.autopoolData);
        } else {
          _contentController.text = restored.content;
        }
        _lastCheckpoint = (restored.isAutopool || restored.isShopping)
            ? restored.autopoolData
            : restored.content;
      },
    );
  }

  Future<void> _togglePin() async {
    final note = _note;
    if (note == null) return;
    await _applyNoteChange(note.copyWith(isPinned: !note.isPinned));
  }

  Future<void> _pickColor() async {
    final note = _note;
    if (note == null) return;
    final newColor =
        await showColorPickerSheet(context, currentColor: note.color);
    if (newColor == null || !mounted) return;
    await _applyNoteChange((_note ?? note).copyWith(color: newColor));
  }

  // Widget lösen: aus der Widget-Liste nehmen und das Fenster schließen.
  Future<void> _unpinWidget() async {
    await StickyNoteService.instance.setWidget(widget.noteId, false);
    await _closeWindow();
  }

  Future<void> _archiveNote() async {
    final note = _note;
    if (note == null) return;
    _saveTimer?.cancel();
    await DatabaseService.instance.updateNote(note.copyWith(isArchived: true));
    // Archivierte Notiz gehört nicht mehr auf den Desktop.
    await StickyNoteService.instance.setWidget(widget.noteId, false);
    await _runStickyAutoSync();
    await _closeWindow();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Notiz löschen'),
        content: const Text('Soll diese Notiz wirklich gelöscht werden?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _saveTimer?.cancel();
    await DatabaseService.instance.deleteNote(widget.noteId);
    await StickyNoteService.instance.setWidget(widget.noteId, false);
    await _runStickyAutoSync();
    await _closeWindow();
  }

  // Fenster schließen (der Poll-Timer würde es sonst gleich wieder tun, wenn die
  // Notiz weg ist – hier aber sofort und kontrolliert).
  Future<void> _closeWindow() async {
    _saveTimer?.cancel();
    _pollTimer?.cancel();
    try {
      await windowManager.destroy();
    } catch (e) {
      debugPrint('Fenster schließen fehlgeschlagen: $e');
    }
  }

  // In einen bestehenden Ordner verschieben. Die Ordnerliste kommt aus den
  // Einstellungen (nur gelesen!) plus den Ordnern, die in Notizen vorkommen.
  Future<void> _moveToFolder() async {
    final note = _note;
    if (note == null) return;
    final folders = <String>{};
    try {
      await SettingsStore.reload();
      final raw = SettingsStore.getString(NotesProvider.foldersKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          folders.addAll(
              decoded.map((e) => e.toString()).where((e) => e.isNotEmpty));
        }
      }
    } catch (e) {
      debugPrint('Ordnerliste lesen fehlgeschlagen: $e');
    }
    try {
      for (final n in await DatabaseService.instance.getAllNotes()) {
        if (n.folder.isNotEmpty) folders.add(n.folder);
      }
    } catch (e) {
      debugPrint('Ordner aus Notizen lesen fehlgeschlagen: $e');
    }
    final list = folders.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (!mounted) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('In Ordner verschieben',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('Kein Ordner'),
              trailing: note.folder.isEmpty ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final f in list)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(f, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: note.folder == f ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, f),
              ),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Noch keine Ordner. Neue Ordner legst du im Hauptfenster an.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final current = _note ?? note;
    if (selected == current.folder) return;
    await _applyNoteChange(current.copyWith(folder: selected));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(selected.isEmpty
          ? 'Aus Ordner entfernt'
          : 'Nach „$selected" verschoben'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // Öffnet die Hauptapp (Notizliste) als eigenen Prozess. `--show-main` erzwingt
  // das Hauptfenster, sonst würde der neue Prozess sich gemäß Start-Logik (nur
  // Widgets) sofort wieder beenden.
  Future<void> _openMainApp() async {
    if (!_isDesktop) return;
    // Linux: Läuft schon eine warme Hauptinstanz, holt sie ihr Fenster sofort
    // nach vorne (kein Kaltstart). Sonst (und auf Windows immer) neuen Prozess.
    if (await MainInstanceService.instance.signalShow(settings: false)) return;
    try {
      await Process.start(
        Platform.resolvedExecutable,
        const ['--show-main'],
        mode: ProcessStartMode.detached,
      );
    } catch (e) {
      debugPrint('Hauptfenster öffnen fehlgeschlagen: $e');
    }
  }

  // Öffnet die Einstellungen in der Hauptapp (eigener Prozess, --show-settings).
  // Bewusst NICHT im Sticky-Prozess anzeigen: ein Sticky-Prozess darf keine
  // Settings-Prefs schreiben (würde mit veraltetem prefs-Snapshot Werte der
  // Hauptapp überschreiben – siehe CLAUDE.md).
  Future<void> _openSettings() async {
    if (!_isDesktop) return;
    // Linux: schon laufende warme Hauptinstanz wiederverwenden (sofort, kein
    // Kaltstart). Sonst (und auf Windows immer) neuen Prozess mit --show-settings.
    if (await MainInstanceService.instance.signalShow(settings: true)) return;
    try {
      await Process.start(
        Platform.resolvedExecutable,
        const ['--show-settings'],
        mode: ProcessStartMode.detached,
      );
    } catch (e) {
      debugPrint('Einstellungen öffnen fehlgeschlagen: $e');
    }
  }

  // Hinweis, wenn nicht bei Drive angemeldet (Sync-Button/Zeit durchgestrichen).
  void _showNotSignedIn() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nicht bei Google Drive angemeldet'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Manueller Sync direkt aus dem Sticky-Fenster (z.B. wenn das Hauptfenster zu ist).
  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    _saveTimer?.cancel();
    await _saveNote(); // aktuellen Stand sichern, dann syncen
    final result = await GoogleDriveService.instance.synchronize();
    if (!mounted) return;
    await _checkExternalUpdate(); // ggf. neuen Stand übernehmen
    if (!mounted) return;
    setState(() => _syncing = false);
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  // Lesbare Textfarbe je nach Helligkeit der Notizfarbe.
  Color get _textColor =>
      ThemeData.estimateBrightnessForColor(_parseColor(_note!.color)) ==
              Brightness.dark
          ? Colors.white
          : Colors.black87;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_note == null) {
      return const Scaffold(
        body: Center(
          child: Text('Notiz nicht gefunden'),
        ),
      );
    }

    final backgroundColor = _parseColor(_note!.color);

    // Der Titel steht in der Fenster-Titelleiste (window_manager.setTitle),
    // daher hier nur Toolbar + Notiz-Inhalt – keine doppelte Überschrift.
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          if (_isDesktop) _buildToolbar(),
          Expanded(
            child: _note!.isAutopool
                ? SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                    child: AutopoolTable(
                      key: _autopoolKey,
                      initialData: _autopoolJson,
                      onChanged: _onAutopoolChanged,
                      textColor: _textColor,
                      fontScale: _fontScale,
                    ),
                  )
                : _note!.isShopping
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                        child: ShoppingListView(
                          key: _shoppingKey,
                          initialData: _shoppingJson,
                          onChanged: _onShoppingChanged,
                          textColor: _textColor,
                          fontScale: _fontScale,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        child: TextField(
                          controller: _contentController,
                          focusNode: _contentFocus,
                          style: TextStyle(
                            fontSize: 14 * _fontScale,
                            color: _textColor,
                            height: 1.5,
                          ),
                          // Zeilenhöhe an der eingestellten Schriftgröße festnageln
                          // (wie im Editor), damit eingefügter Text mit Fallback-
                          // Schrift-Zeichen die Zeilen nicht höher macht.
                          strutStyle: StrutStyle(
                            fontSize: 14 * _fontScale,
                            height: 1.5,
                            forceStrutHeight: true,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Notiz schreiben...',
                            hintStyle: TextStyle(
                                color: _textColor.withValues(alpha: 0.35)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          maxLines: null,
                          expands: true,
                          // Markierung eng an den Text legen (Flutter-Default ist
                          // .max → markiert sonst die ganze Zeile bis zum Rand mit).
                          selectionWidthStyle: BoxWidthStyle.tight,
                          contextMenuBuilder: buildNoteContextMenu,
                          onChanged: (_) => _onTextChanged(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // Obere Leiste: Rückgängig/Wiederholen (links) – Zeit, Sync, Einstellungen,
  // Hauptmenü (rechts). Das Haus-Symbol bewusst ganz rechts, damit die Leiste
  // einheitlich rechtsbündig zu den Aktions-Buttons der übrigen Ansichten ist.
  Widget _buildToolbar() {
    return GestureDetector(
      // Rechtsklick auf die Leiste öffnet dasselbe Optionen-Menü wie der
      // ⋮-Knopf. (Im Textfeld selbst bleibt das normale Text-Kontextmenü –
      // Ausschneiden/Kopieren/Einfügen – erhalten.)
      onSecondaryTap: _showMoreOptions,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
        child: Row(
          children: [
            // Rückgängig/Wiederholen (für Text und Autopool-Tabelle).
            _toolButton(Icons.undo, 'Rückgängig', _canUndo ? _undo : null),
            _toolButton(Icons.redo, 'Wiederholen', _canRedo ? _redo : null),
            const Spacer(),
            // Zeit-Anzeige ist zugleich Sync-Auslöser (wie der Sync-Button rechts).
            // Nicht angemeldet -> durchgestrichen + Hinweis statt Sync.
            Tooltip(
              message: _isSignedIn
                  ? 'Synchronisieren'
                  : 'Nicht bei Google Drive angemeldet',
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: _syncing
                    ? null
                    : (_isSignedIn ? _syncNow : _showNotSignedIn),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    DateFormat('d.M. HH:mm').format(_note!.modifiedAt),
                    style: TextStyle(
                      fontSize: 13,
                      color: _textColor.withValues(alpha: 0.6),
                      decoration:
                          _isSignedIn ? null : TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            _buildSyncButton(),
            // Hauptmenü (öffnet die Hauptapp-Notizliste).
            _toolButton(Icons.home_outlined, 'Hauptmenü öffnen', _openMainApp),
            // Alle weiteren Aktionen (wie das Dreipunkte-Menü im Editor):
            // Farbe, Ordner, Drucken, Archivieren, Löschen, Einstellungen …
            _toolButton(Icons.more_vert, 'Weitere Optionen', _showMoreOptions),
          ],
        ),
      ),
    );
  }

  // Einheitlicher Icon-Button für die Toolbar (etwas größer als zuvor).
  Widget _toolButton(IconData icon, String tooltip, VoidCallback? onPressed) {
    return IconButton(
      iconSize: 22,
      padding: const EdgeInsets.all(6),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(),
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon,
          size: 22,
          color: _textColor.withValues(alpha: onPressed == null ? 0.25 : 0.7)),
    );
  }

  Widget _buildSyncButton() {
    return IconButton(
      iconSize: 22,
      padding: const EdgeInsets.all(6),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(),
      tooltip:
          _isSignedIn ? 'Synchronisieren' : 'Nicht bei Google Drive angemeldet',
      onPressed: _syncing ? null : (_isSignedIn ? _syncNow : _showNotSignedIn),
      icon: _syncing
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _textColor.withValues(alpha: 0.7)),
            )
          // Nicht angemeldet -> durchgestrichenes Icon (sync_disabled).
          : Icon(_isSignedIn ? Icons.sync : Icons.sync_disabled,
              size: 22, color: _textColor.withValues(alpha: 0.7)),
    );
  }
}
