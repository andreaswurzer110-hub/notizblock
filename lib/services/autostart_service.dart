import 'dart:async';
import 'dart:io';
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Registriert die App im Desktop-Autostart (Windows + Linux).
///
/// - **Windows (klassisch/Win32):** Verknüpfung (.lnk) im Autostart-Ordner
///   (`%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`), Ziel = die Exe
///   mit `--widgets`.
/// - **Windows (MSIX/Store):** ebenfalls eine .lnk im Autostart-Ordner, aber sie
///   darf NICHT die Exe unter `…\WindowsApps\…` als Ziel haben (ACL-geschützt;
///   Windows ignoriert solche Startup-Verknüpfungen). Stattdessen wird die App
///   über ihre AppUserModelID via `explorer.exe shell:AppsFolder\<PFN>!<AppId>`
///   aktiviert. Bewusst KEINE `windows.startupTask`: die taucht auf manchen
///   Systemen weder im Task-Manager noch in den Einstellungen auf und lässt sich
///   dann nicht umschalten – der Startup-Ordner dagegen funktioniert dort.
/// - **Linux (klassisch):** `.desktop`-Datei in `~/.config/autostart/`
///   (XDG-Autostart).
/// - **Linux (Flatpak):** Der Sandbox darf NICHT in `~/.config/autostart`
///   schreiben → Autostart läuft über das XDG-`Background`-Portal
///   (`org.freedesktop.portal.Background.RequestBackground`). Das Portal legt
///   host-seitig die Autostart-`.desktop` an/entfernt sie; den UI-Zustand
///   spiegelt eine Marker-Datei im Sandbox-Config-Dir (das Portal bietet keine
///   Abfrage-API).
///
/// In allen Nicht-Flatpak-Fällen ist der Autostart rein über das An-/Abwählen
/// der .lnk (bzw. .desktop) steuerbar – unabhängig von etwaiger Betriebssystem-UI.
class AutostartService {
  static final AutostartService instance = AutostartService._();
  AutostartService._();

  static const String _shortcutName = 'Notizblock.lnk';
  static const String _desktopFileName = 'notizblock.desktop';

  // Application-Id der Paket-App – MUSS `<Application Id="…">` im MSIX-Manifest
  // entsprechen (die der msix-Build aus der Exe `notizblock.exe` ableitet).
  // Zusammen mit dem PackageFamilyName ergibt das die AppUserModelID.
  static const String _appUserModelAppId = 'notizblock';

  // Alter Windows-Registry-Eintrag (Altlast) – beim Umschalten mit aufgeräumt.
  static const String _legacyRunKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const String _legacyValueName = 'Notizblock';

  bool get _supported => Platform.isWindows || Platform.isLinux;

  // MSIX-/Store-Variante? Dann liegt die Exe im geschützten WindowsApps-Ordner.
  bool get _isPackaged =>
      Platform.isWindows &&
      Platform.resolvedExecutable.toLowerCase().contains(r'\windowsapps\');

  // Läuft die App als Flatpak? Dann ist der Host-Autostart-Ordner nicht
  // beschreibbar → Autostart muss übers XDG-Background-Portal laufen.
  bool get _isFlatpak =>
      Platform.isLinux && Platform.environment.containsKey('FLATPAK_ID');

  // Marker-Datei im Sandbox-Config-Dir, die den zuletzt bestätigten Autostart-
  // Zustand widerspiegelt (das Portal hat keine Abfrage-API).
  String? get _flatpakAutostartMarker {
    final cfg = Platform.environment['XDG_CONFIG_HOME'] ??
        (Platform.environment['HOME'] != null
            ? p.join(Platform.environment['HOME']!, '.config')
            : null);
    if (cfg == null) return null;
    return p.join(cfg, 'notizblock_autostart.enabled');
  }

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

  /// Ist der Autostart aktiv? (Existiert die .lnk/.desktop – gilt für Win32 wie
  /// MSIX gleichermaßen, da beide den Startup-Ordner nutzen.)
  Future<bool> isEnabled() async {
    if (!_supported) return false;
    if (_isFlatpak) {
      final marker = _flatpakAutostartMarker;
      if (marker == null) return false;
      return File(marker).exists();
    }
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
      if (_isFlatpak) {
        await _enableLinuxFlatpak();
      } else {
        await _enableLinux();
      }
    } else {
      await _enableWindows();
    }
  }

  Future<void> _disable() async {
    if (_isFlatpak) {
      await _disableLinuxFlatpak();
      return;
    }
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

  // --- Linux (Flatpak) ---

  Future<void> _enableLinuxFlatpak() async {
    final ok = await _requestBackgroundPortal(autostart: true);
    final marker = _flatpakAutostartMarker;
    if (ok && marker != null) {
      try {
        await File(marker).create(recursive: true);
      } catch (e) {
        debugPrint('Autostart-Marker schreiben fehlgeschlagen: $e');
      }
    }
  }

  Future<void> _disableLinuxFlatpak() async {
    await _requestBackgroundPortal(autostart: false);
    final marker = _flatpakAutostartMarker;
    if (marker != null) {
      try {
        final f = File(marker);
        if (await f.exists()) await f.delete();
      } catch (e) {
        debugPrint('Autostart-Marker löschen fehlgeschlagen: $e');
      }
    }
  }

  /// Ruft `org.freedesktop.portal.Background.RequestBackground` auf, um den
  /// Flatpak-Autostart zu (de)aktivieren. Das Portal legt host-seitig die
  /// `~/.config/autostart/<app-id>.desktop` an bzw. entfernt sie. Liefert true
  /// bei erfolgreicher Bestätigung (Response-Code 0); bei ausbleibender Antwort
  /// wird im Zweifel Erfolg angenommen (manche Backends senden kein Signal).
  Future<bool> _requestBackgroundPortal({required bool autostart}) async {
    final client = DBusClient.session();
    try {
      final token = 'notizblock_${DateTime.now().millisecondsSinceEpoch}';
      final portal = DBusRemoteObject(
        client,
        name: 'org.freedesktop.portal.Desktop',
        path: DBusObjectPath('/org/freedesktop/portal/desktop'),
      );
      final reply = await portal.callMethod(
        'org.freedesktop.portal.Background',
        'RequestBackground',
        [
          const DBusString(''), // parent_window
          DBusDict.stringVariant({
            'handle_token': DBusString(token),
            'reason': const DBusString(
                'Notizblock startet mit den angehefteten Widgets.'),
            'autostart': DBusBoolean(autostart),
            'commandline': DBusArray.string(const ['notizblock', '--widgets']),
          }),
        ],
        replySignature: DBusSignature('o'),
      );

      // Das Ergebnis kommt als Response-Signal auf dem zurückgegebenen
      // Request-Handle. (Kleines theoretisches Race: das Signal könnte vor dem
      // Abonnieren feuern – Portale antworten i.d.R. erst nach einem Tick, und
      // der Timeout fängt den Fall ab.)
      final handlePath = reply.returnValues.first as DBusObjectPath;
      final request = DBusRemoteObject(
        client,
        name: 'org.freedesktop.portal.Desktop',
        path: handlePath,
      );
      final responses = DBusRemoteObjectSignalStream(
        object: request,
        interface: 'org.freedesktop.portal.Request',
        name: 'Response',
      );
      try {
        final signal =
            await responses.first.timeout(const Duration(seconds: 20));
        return (signal.values.first as DBusUint32).value == 0;
      } on TimeoutException {
        debugPrint('Background-Portal: keine Response binnen Timeout '
            '– als Erfolg gewertet.');
        return true;
      }
    } catch (e) {
      debugPrint('Background-Portal-Aufruf fehlgeschlagen: $e');
      return false;
    } finally {
      await client.close();
    }
  }

  // --- Windows ---

  Future<void> _enableWindows() async {
    final path = _shortcutPath;
    if (path == null) return;

    String target;
    String args;
    String workDir;
    if (_isPackaged) {
      // Paket-App über die AppUserModelID via Explorer starten (NICHT die Exe
      // unter …\WindowsApps\… als Ziel – die ignoriert Windows beim Autostart).
      // Ohne Argumente: main() öffnet beim Logon nur die angehefteten Widgets
      // (kein Hauptfenster), identisch zum --widgets-Verhalten.
      final pfn = _packageFamilyName();
      if (pfn == null) {
        debugPrint('Autostart: PackageFamilyName nicht ermittelbar.');
        return;
      }
      final windir = Platform.environment['WINDIR'] ?? r'C:\Windows';
      target = p.join(windir, 'explorer.exe');
      args = 'shell:AppsFolder\\$pfn!$_appUserModelAppId';
      workDir = windir;
    } else {
      final exe = Platform.resolvedExecutable;
      target = exe;
      args = '--widgets';
      workDir = File(exe).parent.path;
    }

    await _writeShortcut(path, target, args, workDir);
    await _removeLegacyRegistryEntry();
  }

  // Legt die Autostart-Verknüpfung via WScript.Shell an (kein Admin nötig).
  Future<void> _writeShortcut(
      String path, String target, String args, String workDir) async {
    final ps = StringBuffer()
      ..writeln(r'$ws = New-Object -ComObject WScript.Shell')
      ..writeln('\$s = \$ws.CreateShortcut(${_psQuote(path)})')
      ..writeln('\$s.TargetPath = ${_psQuote(target)}')
      ..writeln('\$s.Arguments = ${_psQuote(args)}')
      ..writeln('\$s.WorkingDirectory = ${_psQuote(workDir)}')
      ..writeln('\$s.Save()');
    try {
      final r = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', ps.toString()],
      );
      if (r.exitCode != 0) {
        debugPrint('Autostart-Verknüpfung anlegen fehlgeschlagen: ${r.stderr}');
      }
    } catch (e) {
      debugPrint('Autostart-Verknüpfung anlegen fehlgeschlagen: $e');
    }
  }

  /// Leitet den PackageFamilyName aus dem Installationspfad ab:
  /// `…\WindowsApps\<Name>_<Version>_<Arch>__<PublisherId>\notizblock.exe`
  /// → PFN = `<Name>_<PublisherId>`. Funktioniert für Test- wie Store-Paket
  /// (kein Hardcoding der je nach Signatur unterschiedlichen PublisherId nötig).
  String? _packageFamilyName() {
    final parts = Platform.resolvedExecutable.split(Platform.pathSeparator);
    final idx = parts.indexWhere((s) => s.toLowerCase() == 'windowsapps');
    if (idx < 0 || idx + 1 >= parts.length) return null;
    final fullName = parts[idx + 1];
    final firstUs = fullName.indexOf('_');
    final doubleUs = fullName.indexOf('__');
    if (firstUs < 0 || doubleUs < 0) return null;
    final name = fullName.substring(0, firstUs);
    final publisherId = fullName.substring(doubleUs + 2);
    if (name.isEmpty || publisherId.isEmpty) return null;
    return '${name}_$publisherId';
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
