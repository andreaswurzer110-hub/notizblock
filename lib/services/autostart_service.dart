import 'dart:async';
import 'dart:io';
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Voller Name, damit der Autostart-Ordner/Task-Manager „Notizblock AW" zeigt.
  static const String _shortcutName = 'Notizblock AW.lnk';
  // Frühere Verknüpfungsnamen (werden beim Aktivieren/Auffrischen aufgeräumt,
  // sonst gäbe es nach der Umbenennung zwei Autostart-Einträge).
  static const List<String> _legacyShortcutNames = ['Notizblock.lnk'];
  static const String _desktopFileName = 'notizblock.desktop';

  // Application-Id der Paket-App – MUSS `<Application Id="…">` im MSIX-Manifest
  // entsprechen (die der msix-Build aus der Exe `notizblock.exe` ableitet).
  // Zusammen mit dem PackageFamilyName ergibt das die AppUserModelID.
  static const String _appUserModelAppId = 'notizblock';

  // Einmal-Flag: bei Format-Änderungen der Verknüpfung (z.B. AppUserModelID für
  // den korrekten Anzeigenamen) wird die bestehende .lnk einmalig neu
  // geschrieben. Bei künftigen Format-Änderungen den Suffix hochzählen.
  static const String _shortcutRefreshFlag = 'autostart_shortcut_refresh_v4';

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

  // Läuft die App als Snap?
  bool get _isSnap =>
      Platform.isLinux && Platform.environment.containsKey('SNAP');

  // Autostart-Datei für snapd: muss exakt der `autostart:`-Property im
  // snapcraft.yaml entsprechen und unter SNAP_USER_DATA liegen. snapd liest sie
  // beim Login, schreibt das Exec sandbox-sicher um und startet die App.
  static const String _snapAutostartFileName = 'notizblock-aw.desktop';

  String? get _snapAutostartPath {
    final base = Platform.environment['SNAP_USER_DATA'] ??
        Platform.environment['HOME'];
    if (base == null) return null;
    return p.join(base, '.config', 'autostart', _snapAutostartFileName);
  }

  // --- Pfade ---

  String? get _startupDir {
    final appData = Platform.environment['APPDATA'];
    if (appData == null) return null;
    return p.join(appData, 'Microsoft', 'Windows', 'Start Menu', 'Programs',
        'Startup');
  }

  String? get _shortcutPath {
    final dir = _startupDir;
    if (dir == null) return null;
    return p.join(dir, _shortcutName);
  }

  // Pfade früherer Verknüpfungsnamen (zum Aufräumen nach Umbenennung).
  List<String> get _legacyShortcutPaths {
    final dir = _startupDir;
    if (dir == null) return const [];
    return [for (final n in _legacyShortcutNames) p.join(dir, n)];
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
    if (_isSnap) {
      final path = _snapAutostartPath;
      if (path == null) return false;
      return File(path).exists();
    }
    if (Platform.isWindows) {
      final path = _shortcutPath;
      if (path != null && await File(path).exists()) return true;
      // Auch eine noch nicht migrierte Alt-Verknüpfung gilt als „aktiv".
      for (final legacy in _legacyShortcutPaths) {
        if (await File(legacy).exists()) return true;
      }
      return false;
    }
    final path = _desktopFilePath;
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
      } else if (_isSnap) {
        await _enableSnap();
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
    if (_isSnap) {
      final path = _snapAutostartPath;
      if (path != null) {
        try {
          final f = File(path);
          if (await f.exists()) await f.delete();
        } catch (e) {
          debugPrint('Autostart deaktivieren (Snap) fehlgeschlagen: $e');
        }
      }
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
    if (Platform.isWindows) {
      await _removeLegacyShortcuts();
      await _removeLegacyRegistryEntry();
    }
  }

  // Frühere (umbenannte) Verknüpfungen entfernen – verhindert Doppel-Einträge.
  Future<void> _removeLegacyShortcuts() async {
    for (final legacy in _legacyShortcutPaths) {
      try {
        final f = File(legacy);
        if (await f.exists()) await f.delete();
      } catch (e) {
        debugPrint('Alte Autostart-Verknüpfung entfernen fehlgeschlagen: $e');
      }
    }
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

  // --- Linux (Snap) ---

  Future<void> _enableSnap() async {
    final path = _snapAutostartPath;
    if (path == null) return;
    // snapd nutzt nur die Exec-Argumente; den Befehl ersetzt es sandbox-sicher
    // durch den App-Wrapper. Dateiname muss zur `autostart:`-Property passen.
    const content = '''
[Desktop Entry]
Type=Application
Name=Notizblock AW
Comment=Notizblock startet mit den angehefteten Widgets
Exec=notizblock-aw --widgets
Icon=notizblock-aw
Terminal=false
X-GNOME-Autostart-enabled=true
''';
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
    } catch (e) {
      debugPrint('Autostart aktivieren (Snap) fehlgeschlagen: $e');
    }
  }

  // --- Windows ---

  Future<void> _enableWindows() async {
    final path = _shortcutPath;
    if (path == null) return;

    String target;
    String args;
    String workDir;
    // Bei der Paket-Variante zeigt die Verknüpfung als Ziel `explorer.exe` – der
    // Task-Manager/Autostart-Dialog würde sie sonst als „explorer" listen.
    // Damit dort der Paket-Anzeigename („Notizblock AW") erscheint, wird die
    // AppUserModelID des Pakets auf die .lnk geschrieben (s.u.).
    String? aumid;
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
      aumid = '$pfn!$_appUserModelAppId';
    } else {
      final exe = Platform.resolvedExecutable;
      target = exe;
      args = '--widgets';
      workDir = File(exe).parent.path;
    }

    // App-Icon herausschreiben und als Verknüpfungs-Icon setzen, damit der
    // Eintrag (besonders bei der Paket-Variante mit explorer.exe als Ziel) das
    // Notizblock-Icon statt des Explorer-Icons zeigt.
    final iconPath = await _ensureAutostartIcon();

    await _writeShortcut(path, target, args, workDir, iconPath);
    if (aumid != null) await _setShortcutAppUserModelId(path, aumid);
    // Verknüpfung umbenannt (früher „Notizblock.lnk") → Alt-Eintrag entfernen.
    await _removeLegacyShortcuts();
    await _removeLegacyRegistryEntry();
  }

  /// Schreibt das gebündelte App-Icon (`assets/icon/app_icon.ico`) in einen
  /// festen, lesbaren Pfad und gibt ihn zurück (für `IconLocation` der .lnk).
  /// Version-unabhängig (im App-Support-Ordner), überlebt App-Updates.
  Future<String?> _ensureAutostartIcon() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final icoPath = p.join(dir.path, 'autostart_icon.ico');
      final data = await rootBundle.load('assets/icon/app_icon.ico');
      await File(icoPath)
          .writeAsBytes(data.buffer.asUint8List(), flush: true);
      return icoPath;
    } catch (e) {
      debugPrint('Autostart-Icon schreiben fehlgeschlagen: $e');
      return null;
    }
  }

  /// Setzt die AppUserModelID (`PKEY_AppUserModel_ID`) auf die Verknüpfung.
  /// Ohne sie zeigt der Task-Manager/Autostart-Dialog für die Paket-Variante
  /// „explorer" (das Verknüpfungsziel) statt des Paket-Anzeigenamens
  /// „Notizblock AW". Best effort – schlägt es fehl, bleibt nur der Name falsch,
  /// der Autostart funktioniert trotzdem. Setzt die Eigenschaft via Shell-COM
  /// (`IShellLink`-Objekt → `IPropertyStore`), das WScript.Shell nicht kann.
  Future<void> _setShortcutAppUserModelId(String lnkPath, String aumid) async {
    // Skript in eine temporäre .ps1 schreiben und mit -File ausführen – robuster
    // als ein riesiges, mehrzeiliges -Command (kein Quoting des Skriptkörpers).
    // Pfad/AUMID werden sicher als PowerShell-Literale eingebettet. Der C#-Block
    // liegt in einem single-quoted Here-String (`'@` MUSS am Zeilenanfang stehen).
    final script = '''
\$ErrorActionPreference = 'Stop'
\$lnk = ${_psQuote(lnkPath)}
\$aumid = ${_psQuote(aumid)}
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class NbShortcut {
  [StructLayout(LayoutKind.Sequential)]
  public struct PROPERTYKEY { public Guid fmtid; public uint pid; }
  [StructLayout(LayoutKind.Sequential)]
  public struct PROPVARIANT { public ushort vt; public ushort r1; public ushort r2; public ushort r3; public IntPtr p; public IntPtr p2; }
  [ComImport, Guid("0000010b-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IPersistFile {
    void GetClassID(out Guid pClassID);
    [PreserveSig] int IsDirty();
    void Load([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, int dwMode);
    void Save([MarshalAs(UnmanagedType.LPWStr)] string pszFileName, [MarshalAs(UnmanagedType.Bool)] bool fRemember);
    void SaveCompleted([MarshalAs(UnmanagedType.LPWStr)] string pszFileName);
    void GetCurFile([MarshalAs(UnmanagedType.LPWStr)] out string ppszFileName);
  }
  [ComImport, Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IPropertyStore {
    void GetCount(out uint cProps);
    void GetAt(uint iProp, out PROPERTYKEY pkey);
    void GetValue(ref PROPERTYKEY key, out PROPVARIANT pv);
    void SetValue(ref PROPERTYKEY key, ref PROPVARIANT pv);
    void Commit();
  }
  [DllImport("ole32.dll")]
  static extern int PropVariantClear(ref PROPVARIANT pvar);
  const ushort VT_LPWSTR = 31;
  public static void SetAumid(string lnkPath, string aumid) {
    Type t = Type.GetTypeFromCLSID(new Guid("00021401-0000-0000-C000-000000000046"));
    object link = Activator.CreateInstance(t);
    IPersistFile pf = (IPersistFile)link;
    pf.Load(lnkPath, 2);
    IPropertyStore store = (IPropertyStore)link;
    PROPERTYKEY key = new PROPERTYKEY();
    key.fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3");
    key.pid = 5;
    // PROPVARIANT (VT_LPWSTR) manuell aufbauen. InitPropVariantFromString ist
    // nicht zuverlaessig aus propsys.dll exportiert (EntryPointNotFound auf
    // Win11) -> stattdessen Zeiger selbst setzen. SetValue kopiert den Wert,
    // unser PROPVARIANT wird danach freigegeben.
    PROPVARIANT pv = new PROPVARIANT();
    pv.vt = VT_LPWSTR;
    pv.p = Marshal.StringToCoTaskMemUni(aumid);
    store.SetValue(ref key, ref pv);
    store.Commit();
    PropVariantClear(ref pv);
    pf.Save(lnkPath, true);
  }
}
'@
[NbShortcut]::SetAumid(\$lnk, \$aumid)
''';
    File? scriptFile;
    try {
      final dir = await Directory.systemTemp.createTemp('nb_aumid');
      scriptFile = File(p.join(dir.path, 'set_aumid.ps1'));
      await scriptFile.writeAsString(script);
      final r = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          scriptFile.path,
        ],
      );
      if (r.exitCode != 0) {
        debugPrint('Autostart AppUserModelID setzen fehlgeschlagen: ${r.stderr}');
      }
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    } catch (e) {
      debugPrint('Autostart AppUserModelID setzen fehlgeschlagen: $e');
    }
  }

  /// Schreibt die Autostart-Verknüpfung einmalig neu, falls Autostart aktiv ist.
  /// Nötig nach einem Update, das das Verknüpfungsformat ändert (z.B. die
  /// AppUserModelID für den korrekten Anzeigenamen): eine schon bestehende .lnk
  /// aus einer Altinstallation wird sonst nicht angefasst. Läuft dank Flag nur
  /// einmal pro Format-Version. Nur Windows.
  Future<void> refreshShortcutIfNeeded() async {
    if (!Platform.isWindows) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_shortcutRefreshFlag) ?? false) return;
      if (await isEnabled()) {
        await _enableWindows();
      }
      await prefs.setBool(_shortcutRefreshFlag, true);
    } catch (e) {
      debugPrint('Autostart-Verknüpfung auffrischen fehlgeschlagen: $e');
    }
  }

  // Legt die Autostart-Verknüpfung via WScript.Shell an (kein Admin nötig).
  Future<void> _writeShortcut(String path, String target, String args,
      String workDir, [String? iconPath]) async {
    final ps = StringBuffer()
      ..writeln(r'$ws = New-Object -ComObject WScript.Shell')
      ..writeln('\$s = \$ws.CreateShortcut(${_psQuote(path)})')
      ..writeln('\$s.TargetPath = ${_psQuote(target)}')
      ..writeln('\$s.Arguments = ${_psQuote(args)}')
      ..writeln('\$s.WorkingDirectory = ${_psQuote(workDir)}')
      // Tooltip im Autostart-Ordner/auf der Verknüpfung.
      ..writeln('\$s.Description = ${_psQuote('Notizblock AW')}');
    if (iconPath != null) {
      ps.writeln('\$s.IconLocation = ${_psQuote('$iconPath,0')}');
    }
    ps.writeln('\$s.Save()');
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
