import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';
import '../services/database_service.dart';
import '../services/sticky_note_service.dart';
import '../services/google_drive_service.dart';
import '../providers/settings_provider.dart';

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
  Note? _note;
  bool _isLoading = true;
  bool _syncing = false;
  double _fontScale = 1.0;
  Timer? _saveTimer;
  Timer? _pollTimer;
  Timer? _stickyAutoSyncTimer;
  Timer? _stickyPullTimer;

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
    }
    _loadNote();
    _loadFontScale();
  }

  Future<void> _loadFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final scale = prefs.getDouble(SettingsProvider.noteFontScaleKey) ?? 1.0;
    if (mounted && scale != _fontScale) setState(() => _fontScale = scale);
  }

  // Automatischer Sync aus dem Sticky-Fenster (nur bei aktivem Auto-Sync).
  Future<void> _runStickyAutoSync() async {
    if (!_isDesktop || _syncing) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!(prefs.getBool(SettingsProvider.autoSyncKey) ?? false)) return;
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
    final note = await DatabaseService.instance.getNoteById(widget.noteId);
    if (!mounted) return;

    // Notiz wurde extern gelöscht (z.B. via Sync) -> Fenster schließen.
    if (note == null) {
      _pollTimer?.cancel();
      if (_isDesktop) await windowManager.close();
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
        selection: TextSelection.collapsed(offset: note.content.length),
      );
      // Undo-Basis an externen Stand angleichen (kein Rückspringen auf Vor-Sync).
      _lastCheckpoint = note.content;
    }
    // Titel-Controller (nicht sichtbar) für korrektes Speichern aktuell halten.
    if (titleChanged) _titleController.text = note.title;

    setState(() => _note = note); // Hintergrundfarbe aktualisieren
    if (_isDesktop) {
      await windowManager.setTitle(note.title.isNotEmpty ? note.title : 'Notiz');
    }
  }

  Future<void> _loadNote() async {
    try {
      _note = await DatabaseService.instance.getNoteById(widget.noteId);
      if (_note != null) {
        _titleController.text = _note!.title;
        _contentController.text = _note!.content;
        _lastCheckpoint = _note!.content;
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

  // Fensterposition/-größe merken
  Future<void> _saveBounds() async {
    if (!_isDesktop) return;
    try {
      final bounds = await windowManager.getBounds();
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
    _stickyAutoSyncTimer = Timer(const Duration(seconds: 2), _runStickyAutoSync);
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

  // Aktuellen Stand als Undo-Schritt ablegen (vorigen Checkpoint stapeln).
  void _commitCheckpoint() {
    final current = _contentController.text;
    if (current == _lastCheckpoint) return;
    _undoStack.add(_lastCheckpoint);
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _lastCheckpoint = current;
    if (mounted) setState(() {});
  }

  bool get _canUndo =>
      _undoStack.isNotEmpty || _contentController.text != _lastCheckpoint;

  bool get _canRedo => _redoStack.isNotEmpty;

  // Letzte Änderung rückgängig machen: zuerst noch nicht gestapelte Eingaben bis
  // zum letzten Checkpoint, danach Schritt für Schritt den Stapel hinunter.
  // Der jeweils verlassene Stand wandert auf den Wiederholen-Stapel.
  void _undo() {
    _undoCheckpointTimer?.cancel();
    final current = _contentController.text;
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
    _contentController.value = TextEditingValue(
      text: target,
      selection: TextSelection.collapsed(offset: target.length),
    );
    _onTextChanged();
    _restoringSnapshot = false;
  }

  Future<void> _saveNote() async {
    if (_note == null) return;
    final newTitle = _titleController.text;
    final newContent = _contentController.text;
    // Ohne echte Änderung NICHT speichern – sonst würde modifiedAt unnötig auf
    // "jetzt" gesetzt (verfälscht die Änderungszeit und gewinnt fälschlich beim
    // Sync gegen Änderungen anderer Geräte).
    if (newTitle == _note!.title && newContent == _note!.content) return;
    final updatedNote = _note!.copyWith(title: newTitle, content: newContent);
    await DatabaseService.instance.updateNote(updatedNote);
    _note = updatedNote;
  }

  // Öffnet die Hauptapp (Notizliste) als eigenen Prozess. `--show-main` erzwingt
  // das Hauptfenster, sonst würde der neue Prozess sich gemäß Start-Logik (nur
  // Widgets) sofort wieder beenden.
  Future<void> _openMainApp() async {
    if (!_isDesktop) return;
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: TextField(
                controller: _contentController,
                focusNode: _contentFocus,
                style: TextStyle(
                  fontSize: 14 * _fontScale,
                  color: _textColor,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Notiz schreiben...',
                  hintStyle:
                      TextStyle(color: _textColor.withValues(alpha: 0.35)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: null,
                expands: true,
                onChanged: (_) => _onTextChanged(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Obere Leiste: Home, Rückgängig (links) – Zeit, Sync (rechts).
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      child: Row(
        children: [
          _toolButton(Icons.home_outlined, 'Hauptmenü öffnen', _openMainApp),
          _toolButton(Icons.undo, 'Rückgängig', _canUndo ? _undo : null),
          _toolButton(Icons.redo, 'Wiederholen', _canRedo ? _redo : null),
          const Spacer(),
          Text(
            DateFormat('d.M. HH:mm').format(_note!.modifiedAt),
            style: TextStyle(
              fontSize: 13,
              color: _textColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 6),
          _buildSyncButton(),
          // Einstellungen ganz rechts (öffnet die Hauptapp-Einstellungen).
          _toolButton(Icons.settings, 'Einstellungen', _openSettings),
        ],
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
      tooltip: 'Synchronisieren',
      onPressed: _syncing ? null : _syncNow,
      icon: _syncing
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _textColor.withValues(alpha: 0.7)),
            )
          : Icon(Icons.sync,
              size: 22, color: _textColor.withValues(alpha: 0.7)),
    );
  }
}