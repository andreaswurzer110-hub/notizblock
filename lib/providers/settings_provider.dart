import 'package:flutter/material.dart';
import '../services/background_sync_service.dart';
import '../services/settings_store.dart';

class SettingsProvider with ChangeNotifier {
  static const String _localeKey = 'locale';
  static const String _themeKey = 'theme_mode';
  static const String _defaultColorKey = 'default_note_color';
  static const String _gridViewKey = 'grid_view';
  static const String autoSyncKey = 'auto_sync';
  // Desktop: ob beim Start zusätzlich zum Widget-Öffnen das Hauptfenster
  // erscheint. Standard false -> nur angeheftete Widgets (siehe main.dart).
  static const String showMainWindowOnStartKey = 'show_main_window_on_start';
  // Skalierungsfaktor für die Schriftgröße der Notiztexte (Editor + Sticky).
  static const String noteFontScaleKey = 'note_font_scale';

  Locale _locale = const Locale('de');
  ThemeMode _themeMode = ThemeMode.system;
  String _defaultNoteColor = '#FFFDE7';
  bool _isGridView = true;
  bool _autoSync = false;
  bool _showMainWindowOnStart = false;
  double _noteFontScale = 1.0;

  // Getters
  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  String get defaultNoteColor => _defaultNoteColor;
  bool get isGridView => _isGridView;
  bool get autoSync => _autoSync;
  bool get showMainWindowOnStart => _showMainWindowOnStart;
  double get noteFontScale => _noteFontScale;

  // Unterstützte Sprachen
  static const List<Locale> supportedLocales = [
    Locale('de'), // Deutsch
    Locale('en'), // Englisch
    Locale('es'), // Spanisch
    Locale('fr'), // Französisch
    Locale('it'), // Italienisch
  ];

  static String getLanguageName(String code) {
    switch (code) {
      case 'de':
        return 'Deutsch';
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      case 'it':
        return 'Italiano';
      default:
        return code;
    }
  }

  // Einstellungen laden
  Future<void> loadSettings() async {
    // Auf Desktop aus der eigenen settings.json (prozesssicher), auf Mobil aus
    // shared_preferences – siehe SettingsStore.
    await SettingsStore.load();

    // Sprache
    final localeCode = SettingsStore.getString(_localeKey) ?? 'de';
    _locale = Locale(localeCode);

    // Theme
    final themeIndex = SettingsStore.getInt(_themeKey) ?? 0;
    _themeMode = ThemeMode.values[themeIndex];

    // Standard-Notizfarbe
    _defaultNoteColor = SettingsStore.getString(_defaultColorKey) ?? '#FFFDE7';

    // Ansicht
    _isGridView = SettingsStore.getBool(_gridViewKey) ?? true;

    // Auto-Sync
    _autoSync = SettingsStore.getBool(autoSyncKey) ?? false;

    // Hauptfenster beim Start (Desktop)
    _showMainWindowOnStart =
        SettingsStore.getBool(showMainWindowOnStartKey) ?? false;

    // Schriftgröße der Notizen
    _noteFontScale = SettingsStore.getDouble(noteFontScaleKey) ?? 1.0;

    notifyListeners();
  }

  // Sprache ändern
  Future<void> setLocale(Locale locale) async {
    if (!supportedLocales.contains(locale)) return;

    _locale = locale;
    await SettingsStore.setString(_localeKey, locale.languageCode);
    notifyListeners();
  }

  // Theme ändern
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await SettingsStore.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  // Standard-Notizfarbe ändern
  Future<void> setDefaultNoteColor(String color) async {
    _defaultNoteColor = color;
    await SettingsStore.setString(_defaultColorKey, color);
    notifyListeners();
  }

  // Ansicht umschalten
  Future<void> toggleViewMode() async {
    _isGridView = !_isGridView;
    await SettingsStore.setBool(_gridViewKey, _isGridView);
    notifyListeners();
  }

  // Auto-Sync umschalten
  Future<void> setAutoSync(bool value) async {
    _autoSync = value;
    await SettingsStore.setBool(autoSyncKey, value);
    notifyListeners();
    // Android-Hintergrund-Sync passend mitschalten (no-op auf anderen Plattformen).
    if (value) {
      await BackgroundSyncService.enable();
    } else {
      await BackgroundSyncService.disable();
    }
  }

  // Hauptfenster beim Start umschalten (Desktop)
  Future<void> setShowMainWindowOnStart(bool value) async {
    _showMainWindowOnStart = value;
    await SettingsStore.setBool(showMainWindowOnStartKey, value);
    notifyListeners();
  }

  // Schriftgröße der Notizen setzen (0.8–1.8)
  Future<void> setNoteFontScale(double value) async {
    _noteFontScale = value.clamp(0.8, 1.8);
    await SettingsStore.setDouble(noteFontScaleKey, _noteFontScale);
    notifyListeners();
  }
}
