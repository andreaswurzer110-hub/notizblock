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
      return Scaffold(
        body: Center(
          child: Text('Notiz nicht gefunden'),
        ),
      );
    }

    final backgroundColor = _parseColor(_note!.color);

    // Der Titel steht in der Fenster-Titelleiste (window_manager.setTitle),
    // daher hier nur der Notiz-Inhalt – keine doppelte Überschrift.
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
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
                hintStyle: TextStyle(color: _textColor.withValues(alpha: 0.35)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              maxLines: null,
              expands: true,
              onChanged: (_) => _onTextChanged(),
            ),
          ),
          if (_isDesktop)
            Positioned(
              right: 4,
              bottom: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildHomeButton(),
                  const SizedBox(width: 2),
                  Text(
                    DateFormat('d.M. HH:mm').format(_note!.modifiedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: _textColor.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildSyncButton(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeButton() {
    return Opacity(
      opacity: 0.45,
      child: IconButton(
        iconSize: 18,
        padding: const EdgeInsets.all(6),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(),
        tooltip: 'Hauptmenü öffnen',
        onPressed: _openMainApp,
        icon: Icon(Icons.home_outlined,
            size: 18, color: _textColor.withValues(alpha: 0.7)),
      ),
    );
  }

  Widget _buildSyncButton() {
    return Opacity(
      opacity: 0.45,
      child: IconButton(
        iconSize: 18,
        padding: const EdgeInsets.all(6),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(),
        tooltip: 'Synchronisieren',
        onPressed: _syncing ? null : _syncNow,
        icon: _syncing
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _textColor.withValues(alpha: 0.7)),
              )
            : Icon(Icons.sync,
                size: 18, color: _textColor.withValues(alpha: 0.7)),
      ),
    );
  }
}