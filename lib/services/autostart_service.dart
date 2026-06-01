import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Registriert die App im Desktop-Autostart (Windows + Linux).
///
/// - **Windows:** Verknüpfung (.lnk) im Autostart-Ordner
///   (`%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`) statt HKCU-Run-Key
///   (der wird auf manchen Systemen ignoriert).
/// - **Linux:** `.desktop`-Datei in `~/.config/autostart/` (XDG-Autostart).
///
/// Gestartet wird jeweils mit `--widgets`, damit beim Systemstart nur die
/// angehefteten Widget-Notizen erscheinen und das Hauptfenster verborgen bleibt.
class AutostartService {
  static final AutostartService instance = AutostartService._();
  AutostartService._();

  static const String _shortcutName = 'Notizblock.lnk';
  static const String _desktopFileName = 'notizblock.desktop';

  // Alter Windows-Registry-Eintrag (Altlast) – beim Umschalten mit aufgeräumt.
  static const String _legacyRunKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const String _legacyValueName = 'Notizblock';

  bool get _supported => Platform.isWindows || Platform.isLinux;

  // --- Pfade ---

  String? get _shortcutPath {
    final appData = Platform.environment['APPDATA'];
    if (appData == null) return null;
    return p.join(appData, 'Microsoft', 'Windows', 'Start Menu', 'Programs',
        'Startup', _shortcutName);
  }

  String? get _desktopFilePath {
    final home = Platform.environment['HOME'];
    if (home == null) return null;
    return p.join(home, '.config', 'autostart', _desktopFileName);
  }

  // --- API ---

  /// Ist der Autostart aktiv?
  Future<bool> isEnabled() async {
    if (!_supported) return false;
    final path = Platform.isWindows ? _shortcutPath : _desktopFilePath;
    if (path == null) return false;
    return File(path).exists();
  }

  Future<void> setEnabled(bool enabled) async {
    if (!_supported) return;
    if (enabled) {
      await _enable();
    } else {
      await _disable();
    }
  }

  Future<void> _enable() async {
    if (Platform.isLinux) {
      await _enableLinux();
    } else {
      await _enableWindows();
    }
  }

  Future<void> _disable() async {
    final path = Platform.isWindows ? _shortcutPath : _desktopFilePath;
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (e) {
        debugPrint('Autostart deaktivieren fehlgeschlagen: $e');
      }
    }
    if (Platform.isWindows) await _removeLegacyRegistryEntry();
  }

  // --- Linux ---

  Future<void> _enableLinux() async {
    final path = _desktopFilePath;
    if (path == null) return;
    final exe = Platform.resolvedExecutable;
    final file = File(path);
    final content = '''
[Desktop Entry]
Type=Application
Name=Notizblock
Comment=Notizblock startet mit den angehefteten Widgets
Exec="$exe" --widgets
Icon=notizblock
Terminal=false
X-GNOME-Autostart-enabled=true
''';
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
    } catch (e) {
      debugPrint('Autostart aktivieren (Linux) fehlgeschlagen: $e');
    }
  }

  // --- Windows ---

  Future<void> _enableWindows() async {
    final path = _shortcutPath;
    if (path == null) return;
    final exe = Platform.resolvedExecutable;
    final workDir = File(exe).parent.path;
    // Verknüpfung via WScript.Shell anlegen (kein Admin nötig).
    final ps = StringBuffer()
      ..writeln(r'$ws = New-Object -ComObject WScript.Shell')
      ..writeln('\$s = \$ws.CreateShortcut(${_psQuote(path)})')
      ..writeln('\$s.TargetPath = ${_psQuote(exe)}')
      ..writeln("\$s.Arguments = '--widgets'")
      ..writeln('\$s.WorkingDirectory = ${_psQuote(workDir)}')
      ..writeln('\$s.Save()');
    try {
      await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', ps.toString()],
      );
    } catch (e) {
      debugPrint('Autostart aktivieren fehlgeschlagen: $e');
    }
    await _removeLegacyRegistryEntry();
  }

  // Besteht noch ein alter Run-Key-Eintrag, entfernen (Best effort).
  Future<void> _removeLegacyRegistryEntry() async {
    try {
      await Process.run(
        'reg',
        ['delete', _legacyRunKey, '/v', _legacyValueName, '/f'],
      );
    } catch (_) {
      // Eintrag existiert nicht mehr -> egal.
    }
  }

  // Einfaches PowerShell-Single-Quote-Escaping ('' = ein ').
  String _psQuote(String value) => "'${value.replaceAll("'", "''")}'";
}
