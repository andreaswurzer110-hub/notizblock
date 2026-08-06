import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import '../models/note.dart';
import 'autostart_service.dart';
import 'database_service.dart';

/// Verwaltet die Sticky-Note-Fenster auf Desktop (Windows/Linux/macOS).
///
/// Jedes Sticky-Note-Fenster ist ein eigener Prozess (`--sticky-note <id>`).
/// - Der "Widget"-Status (welche Notizen beim Start erscheinen) liegt in
///   SharedPreferences – schreibt NUR die Hauptapp, daher unkritisch.
/// - Fenster-Bounds und die offen-PID liegen in EINER Datei PRO Notiz
///   (`sticky_<id>.json`). Wichtig, weil mehrere Sticky-Prozesse gleichzeitig
///   schreiben: SharedPreferences schreibt immer die ganze Datei und würde sich
///   prozessübergreifend gegenseitig überschreiben. Pro-Notiz-Datei = pro Datei
///   nur ein Schreiber (das Sticky-Fenster dieser Notiz).
/// Alles lokal, bewusst NICHT über Drive synchronisiert (pro Gerät).
class StickyNoteService {
  static final StickyNoteService instance = StickyNoteService._();
  StickyNoteService._();

  // Alter SharedPreferences-Key – nur noch für die einmalige Migration.
  static const String _widgetIdsKey = 'widget_note_ids';
  // Angeheftete Widget-IDs liegen jetzt in EINER eigenen Datei (nur die Hauptapp
  // schreibt sie). NICHT in SharedPreferences: dort schreiben auch die
  // Sticky-Prozesse (last_sync_timestamp etc.), und da prefs immer die GANZE
  // Datei schreibt, kippte ein Sticky-Prozess mit veraltetem Snapshot die
  // Anheft-Änderungen der Hauptapp zurück (gelöste Widgets kamen wieder, neue
  // verschwanden). Siehe Stolperstein „kein shared_preferences für
  // prozessübergreifende Writes".
  static const String _widgetIdsFileName = 'widget_ids.json';

  Directory? _stateDirCache;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  // --- Fenster oeffnen ---

  Future<void> openStickyNote(Note note) async {
    if (!_isDesktop) return;

    try {
      final exePath = Platform.resolvedExecutable;
      final args = ['--sticky-note', note.id];
      // Position des aktuellen Hauptfensters mitgeben, damit ein neu angeheftetes
      // Widget auf demselben Monitor erscheint (statt auf dem primären). Greift
      // nur, wenn die Notiz noch keine gespeicherten Bounds hat.
      final origin = await _currentWindowOrigin();
      if (origin != null) {
        args.addAll(['--pos', '${origin.dx.round()}', '${origin.dy.round()}']);
      }
      await Process.start(
        exePath,
        args,
        mode: ProcessStartMode.detached,
      );
    } catch (e) {
      debugPrint('Fehler beim Oeffnen des Sticky Note: $e');
    }
  }

  /// Linke obere Ecke des aktuellen Hauptfensters (leicht versetzt). Dient als
  /// Startposition neuer Sticky-Fenster, damit sie auf dem aktiven Monitor
  /// erscheinen. window_manager-Koordinaten -> passt zu setPosition im Sticky.
  Future<Offset?> _currentWindowOrigin() async {
    try {
      final b = await windowManager.getBounds();
      if (b.width <= 0 || b.height <= 0) return null;
      return b.topLeft + const Offset(60, 60);
    } catch (_) {
      return null;
    }
  }

  /// Oeffnet alle als Widget angehefteten Notizen. Wird bei JEDEM Desktop-Start
  /// aufgerufen (nicht nur Autostart), damit angeheftete Widgets immer erscheinen.
  /// Bereits offene Fenster werden anhand der gespeicherten, noch lebenden
  /// Prozess-ID übersprungen, um Doppel-Fenster zu vermeiden.
  /// Gibt die Anzahl der tatsächlich NEU geöffneten Fenster zurück.
  Future<int> openAllWidgets() async {
    if (!_isDesktop) return 0;

    var opened = 0;
    final ids = await getWidgetNoteIds();
    for (final id in ids) {
      if (await _isStickyOpen(id)) continue;
      final note = await DatabaseService.instance.getNoteById(id);
      if (note != null) {
        await openStickyNote(note);
        opened++;
      } else {
        // Notiz existiert nicht mehr -> aus Widget-Liste entfernen
        await setWidget(id, false);
      }
    }
    return opened;
  }

  /// Schließt das offene Sticky-Fenster einer Notiz (z.B. beim „Widget lösen").
  /// Nutzt die in der Zustandsdatei hinterlegte PID und schickt dem Prozess ein
  /// reguläres Schließen-Signal (taskkill ohne /F → WM_CLOSE), damit das Fenster
  /// seine dispose-Logik (Speichern/Bounds) noch ausführt.
  Future<void> closeStickyNote(String noteId) async {
    if (!_isDesktop) return;
    final data = await _readState(noteId);
    final storedPid = data['pid'];
    if (storedPid is! int) return;
    if (!await _isProcessAlive(storedPid)) return;
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/PID', '$storedPid']);
      } else {
        // SIGTERM -> Fenster schließt sich regulär.
        await Process.run('kill', ['$storedPid']);
      }
    } catch (e) {
      debugPrint('Sticky-Fenster schließen fehlgeschlagen: $e');
    }
  }

  /// Vom Sticky-Note-Prozess beim Start aufrufen: merkt sich die eigene PID,
  /// damit die Hauptapp erkennt, dass dieses Widget bereits offen ist.
  Future<void> markStickyOpen(String noteId) async {
    final data = await _readState(noteId);
    data['pid'] = pid;
    await _writeState(noteId, data);
  }

  /// Ist für diese Notiz bereits ein (lebendes) Sticky-Fenster offen?
  Future<bool> _isStickyOpen(String noteId) async {
    final data = await _readState(noteId);
    final storedPid = data['pid'];
    if (storedPid is! int) return false;
    return _isProcessAlive(storedPid);
  }

  Future<bool> _isProcessAlive(int processId) async {
    // Linux: /proc/<pid> existiert solange der Prozess lebt (kein Subprozess).
    if (Platform.isLinux) {
      return Directory('/proc/$processId').existsSync();
    }
    // macOS: kein /proc -> kill -0 (Signal 0 prüft nur die Existenz).
    if (Platform.isMacOS) {
      try {
        final r = await Process.run('kill', ['-0', '$processId']);
        return r.exitCode == 0;
      } catch (_) {
        return false;
      }
    }
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run(
        'tasklist',
        ['/FI', 'PID eq $processId', '/NH', '/FO', 'CSV'],
      );
      return result.stdout.toString().contains('"$processId"');
    } catch (_) {
      return false;
    }
  }

  // --- Widget-Status (eigene Datei, nur Hauptapp schreibt) ---

  Future<File> _widgetIdsFile() async {
    final dir = await _stateDir();
    return File(join(dir.path, _widgetIdsFileName));
  }

  Future<Set<String>> getWidgetNoteIds() async {
    try {
      final file = await _widgetIdsFile();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        if (data is Map && data['ids'] is List) {
          return (data['ids'] as List).map((e) => e.toString()).toSet();
        }
        return <String>{};
      }
      // Einmalige Migration vom alten SharedPreferences-Key.
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final legacy = prefs.getStringList(_widgetIdsKey);
      if (legacy != null) {
        final ids = legacy.toSet();
        await _writeWidgetNoteIds(ids);
        await prefs.remove(_widgetIdsKey);
        return ids;
      }
    } catch (e) {
      debugPrint('Widget-IDs lesen fehlgeschlagen: $e');
    }
    return <String>{};
  }

  Future<void> _writeWidgetNoteIds(Set<String> ids) async {
    final file = await _widgetIdsFile();
    await file.writeAsString(jsonEncode({'ids': ids.toList()}));
  }

  Future<bool> isWidget(String noteId) async {
    final ids = await getWidgetNoteIds();
    return ids.contains(noteId);
  }

  Future<void> setWidget(String noteId, bool enabled) async {
    final ids = await getWidgetNoteIds();
    if (enabled) {
      ids.add(noteId);
    } else {
      ids.remove(noteId);
    }
    await _writeWidgetNoteIds(ids);
    // Beim Anheften eines Widgets den Desktop-Autostart automatisch aktivieren,
    // damit das angeheftete Widget nach einem Neustart von selbst wieder
    // erscheint (auf Android bleiben Homescreen-Widgets ohnehin erhalten). Nur
    // einschalten, wenn noch nicht aktiv – spart den wiederholten PowerShell-/
    // Datei-Aufruf bei jedem erneuten Anheften.
    if (enabled && !await AutostartService.instance.isEnabled()) {
      await AutostartService.instance.setEnabled(true);
    }
  }

  // --- Fenster-Bounds (Position + Groesse), pro-Notiz-Datei ---

  /// Ist diese Fensterlage brauchbar – oder Unsinn, den wir weder speichern noch
  /// wiederherstellen dürfen?
  ///
  /// **WICHTIG (war real ein Bug, 1.29.2):** Windows meldet für ein
  /// **minimiertes** Fenster die Platzhalter-Lage **-32000/-32000** mit
  /// Titelleisten-Größe (ca. 160x39). Der 2-Sekunden-Poll in
  /// `StickyNoteScreen._saveBounds` hat genau das einmal erwischt und in die
  /// Zustandsdatei geschrieben. Danach öffnete das Widget bei JEDEM Start
  /// unsichtbar weit außerhalb des Bildschirms und winzig – und ließ sich auch
  /// durch neues Anheften oder Task-Beenden nicht zurückholen, weil die kaputte
  /// Lage immer wieder angewendet wurde. Solche Werte deshalb hier abfangen:
  /// beim Speichern gar nicht erst schreiben und beim Laden ignorieren
  /// (Letzteres repariert bereits kaputte Dateien automatisch – das Fenster
  /// öffnet dann mit der Standardgröße).
  static bool isPlausibleBounds(Rect b) {
    for (final v in [b.left, b.top, b.width, b.height]) {
      if (v.isNaN || !v.isFinite) return false;
    }
    // Kleiner als das kann ein Notizfenster sinnvoll nie sein.
    if (b.width < 120 || b.height < 80) return false;
    // Weit außerhalb jedes realen Monitors (u.a. die -32000-Platzhalterlage).
    if (b.left <= -20000 || b.top <= -20000) return false;
    if (b.left >= 20000 || b.top >= 20000) return false;
    return true;
  }

  Future<void> saveBounds(String noteId, Rect bounds) async {
    if (!isPlausibleBounds(bounds)) return;
    final data = await _readState(noteId);
    data['bounds'] = {
      'x': bounds.left,
      'y': bounds.top,
      'w': bounds.width,
      'h': bounds.height,
    };
    await _writeState(noteId, data);
  }

  Future<Rect?> loadBounds(String noteId) async {
    final data = await _readState(noteId);
    final b = data['bounds'];
    if (b is! Map) return null;
    try {
      final rect = Rect.fromLTWH(
        (b['x'] as num).toDouble(),
        (b['y'] as num).toDouble(),
        (b['w'] as num).toDouble(),
        (b['h'] as num).toDouble(),
      );
      // Unbrauchbare Lage (z.B. aus einer älteren Version gespeichert, als das
      // Fenster minimiert war) verwerfen -> Standardgröße statt unsichtbar.
      if (!isPlausibleBounds(rect)) {
        debugPrint('Unbrauchbare Fensterlage für $noteId verworfen: $rect');
        return null;
      }
      return rect;
    } catch (_) {
      return null;
    }
  }

  // --- Pro-Notiz-Zustandsdatei ---

  Future<Directory> _stateDir() async {
    if (_stateDirCache != null) return _stateDirCache!;
    final base = await getApplicationSupportDirectory();
    final dir = Directory(join(base.path, 'sticky_state'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _stateDirCache = dir;
    return dir;
  }

  Future<File> _stateFile(String noteId) async {
    final dir = await _stateDir();
    return File(join(dir.path, 'sticky_$noteId.json'));
  }

  Future<Map<String, dynamic>> _readState(String noteId) async {
    try {
      final file = await _stateFile(noteId);
      if (!await file.exists()) return <String, dynamic>{};
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeState(String noteId, Map<String, dynamic> data) async {
    try {
      final file = await _stateFile(noteId);
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Sticky-Zustand speichern fehlgeschlagen: $e');
    }
  }
}
