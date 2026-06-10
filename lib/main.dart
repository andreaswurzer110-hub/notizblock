import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';
import 'models/note.dart';
import 'providers/notes_provider.dart';
import 'providers/settings_provider.dart';
import 'services/widget_service.dart';
import 'services/background_sync_service.dart';
import 'services/google_drive_service.dart';
import 'services/database_service.dart';
import 'services/sticky_note_service.dart';
import 'screens/home_screen.dart';
import 'screens/note_editor_screen.dart';
import 'screens/autopool_editor_screen.dart';
import 'screens/sticky_note_screen.dart';
import 'screens/settings_screen.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prüfen ob dies ein Sticky Note Fenster ist
  if (args.isNotEmpty && args[0] == '--sticky-note' && args.length > 1) {
    final noteId = args[1];
    if (_isDesktop) {
      await _initStickyWindow(noteId, _parsePosArg(args));
      // Stiller Login, damit der Sync-Button im Sticky-Fenster funktioniert
      // (auch wenn das Hauptfenster geschlossen ist).
      await GoogleDriveService.instance.signInSilently();
    }
    runApp(StickyNoteApp(noteId: noteId));
    return;
  }

  // Hauptfenster
  if (Platform.isAndroid) {
    await WidgetService.instance.initialize();
    // Hintergrund-Sync (WorkManager) initialisieren und – falls Auto-Sync schon
    // aktiv ist – den periodischen 1-h-Job (re)registrieren. So zieht das Gerät
    // auch bei geschlossener App von Drive und das Widget bleibt aktuell.
    await BackgroundSyncService.initialize();
    final prefs0 = await SharedPreferences.getInstance();
    if (prefs0.getBool(SettingsProvider.autoSyncKey) ?? false) {
      await BackgroundSyncService.enable();
    }
  }

  // Autostart-Modus (Verknüpfung mit --widgets) bzw. erzwungenes Hauptfenster
  // (Home-Button eines Widgets startet die App mit --show-main; der
  // Einstellungen-Button eines Sticky-Fensters mit --show-settings).
  final isAutostart = args.contains('--widgets');
  final openSettings = args.contains('--show-settings');
  final forceMainWindow = args.contains('--show-main') || openSettings;

  if (_isDesktop) {
    await windowManager.ensureInitialized();

    // Angeheftete Widgets öffnen (gibt Anzahl NEU geöffneter Fenster zurück).
    final widgetIds = await StickyNoteService.instance.getWidgetNoteIds();
    final hasWidgets = widgetIds.isNotEmpty;
    final openedCount = await StickyNoteService.instance.openAllWidgets();

    // Standard: beim Start nur die angehefteten Widgets. Das Hauptfenster
    // erscheint nur, wenn:
    //  - per --show-main erzwungen (Home-Button eines Widgets),
    //  - die Einstellung "Hauptfenster beim Start öffnen" aktiv ist,
    //  - keine Widgets angeheftet sind (sonst käme gar nichts),
    //  - ODER manuell gestartet und die Widgets liefen bereits (sonst liefe
    //    der Klick auf das App-Icon ins Leere).
    final prefs = await SharedPreferences.getInstance();
    final showMainSetting =
        prefs.getBool(SettingsProvider.showMainWindowOnStartKey) ?? false;
    final showMain = forceMainWindow ||
        showMainSetting ||
        !hasWidgets ||
        (!isAutostart && openedCount == 0);

    if (!showMain) {
      // Hauptprozess wird nicht gebraucht: Die Widget-Fenster laufen als eigene
      // (detached) Prozesse weiter und syncen selbst. Das Hauptfenster lässt
      // sich jederzeit über den Home-Button eines Widgets öffnen.
      await windowManager.setSkipTaskbar(true);
      await windowManager.hide();
      exit(0);
    }

    await windowManager.waitUntilReadyToShow(
      const WindowOptions(title: 'Notizblock AW'),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  // Stiller Login: Desktop nutzt gespeicherte OAuth-Token, Mobil google_sign_in.
  // Service entscheidet plattformabhängig; Fehler werden intern abgefangen.
  await GoogleDriveService.instance.signInSilently();

  // Wurde die App per Homescreen-Widget gestartet? Dann die Ziel-Notiz JETZT
  // (vor runApp) laden und den Editor direkt als erste Seite bauen. So ist der
  // allererste Frame bereits das Bearbeiten-Fenster – kein weißer Platzhalter
  // und kein nachträglicher Push mehr, also auch kein Flackern.
  Note? initialNote;
  if (Platform.isAndroid) {
    try {
      final noteId = await const MethodChannel('notizblock/deeplink')
          .invokeMethod<String>('getInitialNoteId');
      if (noteId != null && noteId.isNotEmpty) {
        initialNote = await DatabaseService.instance.getNoteById(noteId);
      }
    } catch (_) {}
  }

  runApp(NotizblockApp(initialNote: initialNote, openSettings: openSettings));
}

/// Fenster eines Sticky-Note-Prozesses einrichten: gespeicherte Bounds
/// wiederherstellen, sonst eine sinnvolle Standardgröße verwenden.
Future<void> _initStickyWindow(String noteId, [Offset? fallbackPos]) async {
  await windowManager.ensureInitialized();
  final bounds = await StickyNoteService.instance.loadBounds(noteId);
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      size: bounds?.size ?? const Size(320, 340),
      title: 'Notiz',
      skipTaskbar: false,
    ),
    () async {
      if (bounds != null) {
        // Bereits positioniert -> gespeicherte Lage wiederherstellen.
        await windowManager.setBounds(bounds);
      } else if (fallbackPos != null) {
        // Neu angeheftet -> nahe dem Hauptfenster (gleicher Monitor) öffnen.
        await windowManager.setPosition(fallbackPos);
      } else {
        await windowManager.center();
      }
      await windowManager.show();
      await windowManager.focus();
    },
  );
}

/// Liest eine optionale `--pos <x> <y>`-Startposition aus den Prozess-Argumenten.
Offset? _parsePosArg(List<String> args) {
  final i = args.indexOf('--pos');
  if (i == -1 || args.length <= i + 2) return null;
  final x = double.tryParse(args[i + 1]);
  final y = double.tryParse(args[i + 2]);
  if (x == null || y == null) return null;
  return Offset(x, y);
}

// Sticky Note App (kleines Fenster)
class StickyNoteApp extends StatelessWidget {
  final String noteId;

  const StickyNoteApp({super.key, required this.noteId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      // WICHTIG: Lokalisierung auch im Sticky-Fenster bereitstellen. Sonst ist
      // AppLocalizations.of(context) null und Widgets, die l10n nutzen (z.B. die
      // Autopool-Tabelle), stürzen beim Aufbau ab -> im Release nur ein graues
      // Feld. Sprache fest Deutsch (passt zu den hartkodierten Sticky-Texten).
      locale: const Locale('de'),
      supportedLocales: SettingsProvider.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: StickyNoteScreen(noteId: noteId),
    );
  }
}

// Haupt App
class NotizblockApp extends StatefulWidget {
  // Beim Start per Homescreen-Widget bereits in main() geladene Ziel-Notiz.
  // Ist sie gesetzt, wird der Editor direkt als erste Seite gebaut (kein
  // Platzhalter, kein nachträglicher Push -> kein Flackern).
  final Note? initialNote;
  // true, wenn die App vom Einstellungen-Button eines Sticky-Fensters
  // (--show-settings) gestartet wurde -> nach dem Start direkt Einstellungen.
  final bool openSettings;

  const NotizblockApp({super.key, this.initialNote, this.openSettings = false});

  @override
  State<NotizblockApp> createState() => _NotizblockAppState();
}

class _NotizblockAppState extends State<NotizblockApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  static const _channel = MethodChannel('notizblock/deeplink');

  @override
  void initState() {
    super.initState();
    // Warmstart: Läuft die App schon und das Widget wird getippt, schickt
    // MainActivity per onNewIntent ein 'openNote' über diesen Channel.
    if (Platform.isAndroid) {
      _setupDeepLinkListener();
    }

    // Vom Sticky-Einstellungen-Button gestartet -> Einstellungen über die
    // Notizliste legen (einmal Zurück führt zur Liste, nicht zum leeren Stack).
    if (widget.openSettings) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      });
    }
  }

  void _setupDeepLinkListener() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openNote') {
        final noteId = call.arguments as String?;
        if (noteId != null) {
          _openNoteEditor(noteId);
        }
      }
    });
  }

  // Warmstart-Pfad: Editor über den laufenden Navigator öffnen.
  Future<void> _openNoteEditor(String noteId) async {
    final note = await DatabaseService.instance.getNoteById(noteId);
    if (note != null && _navigatorKey.currentState != null) {
      // Editor als einzigen Screen setzen, damit ein einmaliges Zurück direkt
      // zum Homescreen führt. Ohne Slide-Animation (Duration.zero) für einen
      // nahtlosen Wechsel.
      _navigatorKey.currentState!.pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => note.isAutopool
              ? AutopoolEditorScreen(note: note, openedFromWidget: true)
              : NoteEditorScreen(note: note, openedFromWidget: true),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..loadSettings()),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'Notizblock AW',
            debugShowCheckedModeBanner: false,
            locale: settings.locale,
            supportedLocales: SettingsProvider.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: settings.themeMode,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            // Kaltstart per Widget: Editor ist direkt die erste Seite (kein
            // Flackern). Sonst normale Notizliste.
            home: widget.initialNote != null
                ? (widget.initialNote!.isAutopool
                    ? AutopoolEditorScreen(
                        note: widget.initialNote!, openedFromWidget: true)
                    : NoteEditorScreen(
                        note: widget.initialNote!, openedFromWidget: true))
                : const HomeScreen(),
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5C6BC0), brightness: Brightness.light),
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0, scrolledUnderElevation: 1, systemOverlayStyle: SystemUiOverlayStyle.dark),
      cardTheme: CardThemeData(elevation: 2, shadowColor: Colors.black12, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      floatingActionButtonTheme: FloatingActionButtonThemeData(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      bottomSheetTheme: const BottomSheetThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24)))),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C8FD9), brightness: Brightness.dark),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0, scrolledUnderElevation: 1, systemOverlayStyle: SystemUiOverlayStyle.light),
      cardTheme: CardThemeData(elevation: 2, shadowColor: Colors.black26, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      floatingActionButtonTheme: FloatingActionButtonThemeData(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.grey.shade900, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      bottomSheetTheme: const BottomSheetThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24)))),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }
}