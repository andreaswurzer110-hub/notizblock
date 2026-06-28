import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Einzelinstanz-/Warmhalten des Hauptfensters auf **Linux**.
///
/// Hintergrund: Auf Linux startet das Öffnen von Hauptmenü/Einstellungen aus
/// einem Widget bisher einen komplett neuen Flutter-Prozess (`--show-main` /
/// `--show-settings`) → voller Kaltstart (Dart-VM + Flutter-Engine +
/// GTK/XWayland + erster DB-Open), auf schwacher Hardware mehrere Sekunden mit
/// Lade-Spinner. Windows nutzt dieselbe Architektur, ist aber schnell genug.
///
/// Lösung (NUR Linux): Der Hauptprozess bleibt nach dem ersten Öffnen
/// **versteckt am Leben** (NotizblockApp versteckt das Fenster beim Schließen,
/// statt sich zu beenden) und registriert seine PID in `main_instance.json`.
/// Will ein Widget das Hauptfenster/​die Einstellungen öffnen, schreibt es ein
/// Kommando in `main_command.json`; der laufende Hauptprozess pollt diese Datei
/// und holt sein Fenster sofort nach vorne – kein Kaltstart. Läuft KEIN
/// Hauptprozess, wird wie bisher ein neuer gestartet (der dann zur warmen
/// Instanz wird → ab dem zweiten Öffnen ist es sofort da).
///
/// Dateibasiert (wie die übrigen Cross-Prozess-Zustände unter `sticky_state/`),
/// bewusst kein Socket. Auf Nicht-Linux sind alle Methoden no-ops bzw. liefern
/// false → Windows/macOS verhalten sich UNVERÄNDERT (neuer Prozess pro Fenster).
class MainInstanceService {
  static final MainInstanceService instance = MainInstanceService._();
  MainInstanceService._();

  // Nur auf Linux aktiv: dort ist der Kaltstart das Problem; Windows ist schnell
  // und soll sein bewährtes „neuer Prozess pro Fenster"-Verhalten behalten.
  bool get _enabled => Platform.isLinux;

  static const String _instanceFileName = 'main_instance.json';
  static const String _commandFileName = 'main_command.json';

  // Zeitstempel des zuletzt verarbeiteten Kommandos (im warmen Hauptprozess),
  // damit ein altes Kommando nicht erneut auslöst.
  int _lastSeenCmdTs = 0;

  Future<Directory> _stateDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'sticky_state'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _instanceFile() async =>
      File(p.join((await _stateDir()).path, _instanceFileName));

  Future<File> _commandFile() async =>
      File(p.join((await _stateDir()).path, _commandFileName));

  // Linux: /proc/<pid> existiert, solange der Prozess lebt.
  bool _isAlive(int processId) => Directory('/proc/$processId').existsSync();

  /// Läuft bereits ein lebender, FREMDER warmer Hauptprozess?
  Future<bool> isMainRunning() async {
    if (!_enabled) return false;
    try {
      final f = await _instanceFile();
      if (!await f.exists()) return false;
      final data = jsonDecode(await f.readAsString());
      final storedPid = (data is Map) ? data['pid'] : null;
      if (storedPid is! int) return false;
      if (storedPid == pid) return false; // wir selbst
      return _isAlive(storedPid);
    } catch (_) {
      return false;
    }
  }

  /// Diesen Prozess als warme Hauptinstanz registrieren (eigene PID ablegen) und
  /// ein evtl. vorhandenes Alt-Kommando als „bereits gesehen" markieren, damit es
  /// nicht sofort beim Start des Listeners auslöst.
  Future<void> registerSelf() async {
    if (!_enabled) return;
    try {
      final f = await _instanceFile();
      await f.writeAsString(jsonEncode({'pid': pid}));
      _lastSeenCmdTs = await _currentCommandTs();
    } catch (e) {
      debugPrint('Hauptinstanz registrieren fehlgeschlagen: $e');
    }
  }

  Future<int> _currentCommandTs() async {
    try {
      final f = await _commandFile();
      if (!await f.exists()) return 0;
      final data = jsonDecode(await f.readAsString());
      final ts = (data is Map) ? data['ts'] : null;
      return ts is int ? ts : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Vom Widget-Prozess: Läuft ein warmer Hauptprozess, ihm ein Anzeige-Kommando
  /// schicken und true zurückgeben (Aufrufer startet dann KEINEN neuen Prozess).
  /// Sonst false (Aufrufer startet wie bisher einen neuen `--show-main`/
  /// `--show-settings`-Prozess).
  Future<bool> signalShow({required bool settings}) async {
    if (!_enabled) return false;
    if (!await isMainRunning()) return false;
    try {
      final f = await _commandFile();
      await f.writeAsString(jsonEncode({
        'action': settings ? 'settings' : 'show',
        'ts': DateTime.now().millisecondsSinceEpoch,
      }));
      return true;
    } catch (e) {
      debugPrint('Hauptfenster-Kommando schreiben fehlgeschlagen: $e');
      return false;
    }
  }

  /// Vom warmen Hauptprozess gepollt: neues Kommando seit dem letzten Aufruf?
  /// Liefert 'show' bzw. 'settings' oder null.
  Future<String?> pollCommand() async {
    if (!_enabled) return null;
    try {
      final f = await _commandFile();
      if (!await f.exists()) return null;
      final data = jsonDecode(await f.readAsString());
      if (data is! Map) return null;
      final ts = data['ts'];
      if (ts is! int || ts <= _lastSeenCmdTs) return null;
      _lastSeenCmdTs = ts;
      return data['action'] == 'settings' ? 'settings' : 'show';
    } catch (_) {
      return null;
    }
  }
}
