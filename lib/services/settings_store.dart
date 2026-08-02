import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prozesssicherer Schlüssel-Wert-Speicher für NUTZER-EINSTELLUNGEN
/// (Sprache, Theme, Standardfarbe, Ansicht, Auto-Sync, Hauptfenster-beim-Start,
/// Schriftgröße).
///
/// Hintergrund: Auf Desktop laufen die Hauptapp UND jedes Sticky-Note-Fenster
/// als EIGENE Prozesse. `shared_preferences` schreibt immer die GANZE Datei aus
/// dem In-Memory-Snapshot des schreibenden Prozesses → ein Sticky-Prozess kippt
/// mit veraltetem Snapshot die Einstellungen der Hauptapp zurück (Theme/Sprache
/// springen zurück, „Abmelden" hält nicht). Das ist exakt der CLAUDE.md-
/// Stolperstein „kein shared_preferences für prozessübergreifende Writes";
/// widget_ids/bounds liegen aus demselben Grund schon in eigenen Dateien.
///
/// Lösung: Auf Desktop liegen die Einstellungen in EINER eigenen Datei
/// `settings.json` (im AppSupport-Ordner, neben `sticky_state/`). EINZIGER
/// Schreiber ist die Hauptapp (über [SettingsProvider]); Sticky-Prozesse LESEN
/// nur (Schriftgröße, Auto-Sync) und schreiben nie. Auf Android/iOS gibt es
/// keinen konkurrierenden Settings-Schreiber → dort weiterhin
/// `shared_preferences` mit denselben Keys (damit u.a. der Hintergrund-Sync-
/// Isolate unverändert mitliest).
class SettingsStore {
  SettingsStore._();

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static const String _fileName = 'settings.json';

  // Die von diesem Store verwalteten Keys – nötig für die einmalige Migration
  // der Alt-Werte aus shared_preferences in die neue Datei.
  static const List<String> _managedKeys = [
    'locale',
    'theme_mode',
    'default_note_color',
    'grid_view',
    'auto_sync',
    'show_main_window_on_start',
    'note_font_scale',
  ];

  static Map<String, dynamic>? _cache;
  static File? _file;

  static Future<File> _settingsFile() async {
    if (_file != null) return _file!;
    final base = await getApplicationSupportDirectory();
    _file = File(join(base.path, _fileName));
    return _file!;
  }

  /// Werte in den Cache laden (einmalig). Vor dem ersten Lesen aufrufen.
  static Future<void> load() async {
    if (_cache != null) return;
    await reload();
  }

  /// Cache zwingend frisch von der Quelle lesen. Im Sticky-Fenster vor jedem
  /// Lesen aufrufen, um prozessübergreifend frische Werte zu bekommen (analog
  /// `prefs.reload()`).
  static Future<void> reload() async {
    if (_isDesktop) {
      await _reloadFromFile();
    } else {
      await _reloadFromPrefs();
    }
  }

  // --- Desktop: eigene Datei ---

  static Future<void> _reloadFromFile() async {
    try {
      final f = await _settingsFile();
      if (await f.exists()) {
        try {
          final data = jsonDecode(await f.readAsString());
          if (data is Map) {
            _cache = data.map((k, v) => MapEntry(k.toString(), v));
            return;
          }
          debugPrint('settings.json hat ein unerwartetes Format – neu aufbauen.');
        } catch (e) {
          // Unlesbar – etwa wenn ein Absturz/hartes Ausschalten die Datei mit
          // Nullbytes hinterlassen hat (dasselbe Muster wie bei der kaputten
          // shared_preferences-Datei, s. PrefsRepairService). Dann wie eine
          // FEHLENDE Datei behandeln und neu aufbauen, statt bei jedem Start
          // stumm mit leeren Einstellungen weiterzulaufen: sonst stünde z.B.
          // der Auto-Sync-Schalter dauerhaft auf „aus".
          debugPrint('settings.json unlesbar ($e) – wird neu aufgebaut.');
        }
      }
      // Datei fehlt (erster Start nach Update) oder war unlesbar → Alt-Werte
      // einmalig aus shared_preferences übernehmen und in die Datei schreiben.
      _cache = await _readManagedFromPrefs();
      await _flush();
    } catch (e) {
      debugPrint('Einstellungen lesen fehlgeschlagen: $e');
      _cache ??= <String, dynamic>{};
    }
  }

  static Future<void> _flush() async {
    final f = await _settingsFile();
    await f.writeAsString(jsonEncode(_cache ?? <String, dynamic>{}));
  }

  // --- Mobil: shared_preferences (gleiche Keys wie früher) ---

  static Future<void> _reloadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    _cache = await _readManagedFromPrefs(prefs);
  }

  static Future<Map<String, dynamic>> _readManagedFromPrefs(
      [SharedPreferences? prefsIn]) async {
    final out = <String, dynamic>{};
    try {
      final prefs = prefsIn ?? await SharedPreferences.getInstance();
      for (final key in _managedKeys) {
        final v = prefs.get(key);
        if (v != null) out[key] = v;
      }
    } catch (_) {}
    return out;
  }

  // --- Lesen (synchron, nach load()/reload()) ---

  static String? getString(String key) => _cache?[key] as String?;
  static int? getInt(String key) => (_cache?[key] as num?)?.toInt();
  static double? getDouble(String key) => (_cache?[key] as num?)?.toDouble();
  static bool? getBool(String key) => _cache?[key] as bool?;

  // --- Schreiben (nur Hauptapp) ---

  static Future<void> setString(String key, String value) =>
      _set(key, value, (p) => p.setString(key, value));
  static Future<void> setInt(String key, int value) =>
      _set(key, value, (p) => p.setInt(key, value));
  static Future<void> setDouble(String key, double value) =>
      _set(key, value, (p) => p.setDouble(key, value));
  static Future<void> setBool(String key, bool value) =>
      _set(key, value, (p) => p.setBool(key, value));

  static Future<void> _set(String key, dynamic value,
      Future<bool> Function(SharedPreferences) writePrefs) async {
    (_cache ??= <String, dynamic>{})[key] = value;
    if (_isDesktop) {
      await _flush();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await writePrefs(prefs);
    }
  }
}
