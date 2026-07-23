import 'dart:async';
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
import 'services/main_instance_service.dart';
import 'services/settings_store.dart';
import 'services/autostart_service.dart';
import 'services/restart_on_update_service.dart';
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
      // Sticky-/Sekundärprozess: darf KEINE Credentials persistieren (sonst
      // schreibt ein still erneuerter Token eine Abmeldung der Hauptapp wieder
      // zurück) – siehe GoogleDriveService.
      GoogleDriveService.isSecondaryProcess = true;
      await _initStickyWindow(noteId, _parsePosArg(args));
      // Nach einem App-Update (Windows/MSIX) dieses Sticky-Fenster automatisch
      // wieder öffnen – mit derselben Notiz, gespeicherte Lage wird beim Start
      // wiederhergestellt. (Nur Windows; sonst no-op.)
      RestartOnUpdateService.register(['--sticky-note', noteId]);
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
  // Vom Restart Manager nach einem App-Update neu gestartet (siehe
  // RestartOnUpdateService): Die Sticky-Fenster starten sich dann einzeln selbst
  // neu → der Hauptprozess darf sie NICHT zusätzlich öffnen (sonst Doppel-Fenster).
  final restartedByUpdate = args.contains('--updated');
  final forceMainWindow = args.contains('--show-main') || openSettings;

  // Verzögerter Start (Desktop): Aus Performance-Gründen wird das Hauptfenster
  // erst gezeigt und werden Login/Widget-Öffnen erst erledigt, NACHDEM Flutter
  // den ersten Frame gezeichnet hat (erster Post-Frame-Callback in
  // NotizblockApp). Sonst stünde ein schwarzes „reagiert nicht"-Fenster, während
  // der stille Login (inkl. Netzwerk) den ersten Frame blockiert – auf schwacher
  // Hardware ein 10–15-s-Hänger beim Öffnen von Hauptmenü/Einstellungen aus einem
  // Widget.
  var showWindowAfterFirstFrame = false;
  var openWidgetsAfterFirstFrame = false;

  if (_isDesktop) {
    await windowManager.ensureInitialized();

    // settings.json anlegen/lesen, BEVOR Sticky-Prozesse gespawnt werden (die
    // lesen daraus Schriftgröße/Auto-Sync) – siehe SettingsStore.
    await SettingsStore.load();

    // Einmalig nach einem Update die Autostart-Verknüpfung neu schreiben, damit
    // der Task-Manager/Autostart-Dialog den korrekten Anzeigenamen zeigt
    // (AppUserModelID statt „explorer"). Tut nur etwas, wenn Autostart aktiv und
    // noch nicht aufgefrischt ist (Flag) – sonst praktisch kostenlos.
    await AutostartService.instance.refreshShortcutIfNeeded();

    // Linux: Soll dieser Start ein Hauptfenster zeigen (Home-/Einstellungen-
    // Button eines Widgets) und läuft schon eine warme Hauptinstanz, holt diese
    // ihr Fenster sofort nach vorne → dieser Prozess wird nicht gebraucht (kein
    // Kaltstart, kein Doppel-Fenster). Sofort prüfen, noch vor jedem
    // Fensteraufbau. Auf Windows/macOS ist signalShow ein no-op (false) → dort
    // unverändert ein neuer Prozess pro Fenster (ist dort schnell genug).
    if (forceMainWindow &&
        await MainInstanceService.instance.signalShow(settings: openSettings)) {
      exit(0);
    }

    final widgetIds = await StickyNoteService.instance.getWidgetNoteIds();
    final hasWidgets = widgetIds.isNotEmpty;

    // Angeheftete Widgets öffnen. forceMainWindow (Home-/Einstellungen-Button
    // eines Widgets): die Widgets laufen bereits → openAllWidgets erst NACH dem
    // ersten Frame (die Prozess-Checks würden sonst den Fensteraufbau verzögern).
    // Sonst (Autostart/manuell) jetzt, weil das Ergebnis in die showMain-/
    // exit-Entscheidung einfließt. Nach einem Update-Neustart NICHT öffnen – die
    // Sticky-Prozesse starten sich selbst neu (RestartOnUpdateService).
    var openedCount = 0;
    if (forceMainWindow) {
      openWidgetsAfterFirstFrame = !restartedByUpdate;
    } else {
      openedCount = restartedByUpdate
          ? 0
          : await StickyNoteService.instance.openAllWidgets();
    }

    // Standard: beim Start nur die angehefteten Widgets. Das Hauptfenster
    // erscheint nur, wenn:
    //  - per --show-main erzwungen (Home-Button eines Widgets),
    //  - die Einstellung "Hauptfenster beim Start öffnen" aktiv ist,
    //  - keine Widgets angeheftet sind (sonst käme gar nichts),
    //  - ODER manuell gestartet und die Widgets liefen bereits (sonst liefe
    //    der Klick auf das App-Icon ins Leere).
    final showMainSetting =
        SettingsStore.getBool(SettingsProvider.showMainWindowOnStartKey) ?? false;
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

    // Linux: Auch im manuellen Start-Pfad (App-Icon) eine schon laufende warme
    // Instanz wiederverwenden, statt ein zweites Hauptfenster zu öffnen.
    // (forceMainWindow wurde bereits oben geprüft.)
    if (!forceMainWindow &&
        await MainInstanceService.instance.signalShow(settings: false)) {
      exit(0);
    }

    // Wir zeigen jetzt das Hauptfenster → auf Linux zur warmen Instanz werden
    // (PID registrieren, damit künftige Öffnen-Wünsche hierher signalisiert
    // werden statt einen neuen Prozess kalt zu starten). No-op außer auf Linux.
    await MainInstanceService.instance.registerSelf();

    // Fensteroptionen anwenden, aber NICHT vorzeitig zeigen – beide Desktop-
    // Runner zeigen das Fenster selbst beim ersten Frame; show()/focus() folgen
    // im Post-Frame-Callback (NotizblockApp), damit kein schwarzes Fenster
    // erscheint und das Fenster trotzdem in den Vordergrund kommt.
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(title: 'Notizblock AW'),
      () async {},
    );
    showWindowAfterFirstFrame = true;

    // Bleibt das Hauptfenster offen, soll es nach einem App-Update ebenfalls
    // wiederkommen. `--updated` lässt den neu gestarteten Hauptprozess das
    // erneute Öffnen der Widgets überspringen (die starten sich selbst neu).
    RestartOnUpdateService.register(['--show-main', '--updated']);
  }

  // Stiller Login: Auf DESKTOP nicht mehr vor runApp – der Netzwerk-GET
  // (userinfo) blockierte sonst den ersten Frame (schwarzes Fenster); er läuft
  // im ersten Post-Frame-Callback von NotizblockApp, die UI zieht über
  // GoogleDriveService.signedInNotifier nach. Auf MOBIL weiterhin vor runApp
  // (kein Fenster → kein Schwarzbild; der Login-Status soll ab dem ersten Frame
  // stimmen).
  if (!_isDesktop) {
    await GoogleDriveService.instance.signInSilently();
  }

  // Wurde die App per Homescreen-Widget gestartet? Dann die Ziel-Notiz JETZT
  // (vor runApp) laden und den Editor direkt als erste Seite bauen. So ist der
  // allererste Frame bereits das Bearbeiten-Fenster – kein weißer Platzhalter
  // und kein nachträglicher Push mehr, also auch kein Flackern.
  Note? initialNote;
  // Per Ordner-Widget gestartet? Dann diesen Ordner beim Start vorselektieren.
  String? initialFolder;
  if (Platform.isAndroid) {
    try {
      const channel = MethodChannel('notizblock/deeplink');
      final noteId = await channel.invokeMethod<String>('getInitialNoteId');
      if (noteId != null && noteId.isNotEmpty) {
        initialNote = await DatabaseService.instance.getNoteById(noteId);
      }
      final folder = await channel.invokeMethod<String>('getInitialFolder');
      if (folder != null && folder.isNotEmpty) {
        initialFolder = folder;
      }
    } catch (_) {}
  }

  runApp(NotizblockApp(
    initialNote: initialNote,
    initialFolder: initialFolder,
    openSettings: openSettings,
    showWindowAfterFirstFrame: showWindowAfterFirstFrame,
    openWidgetsAfterFirstFrame: openWidgetsAfterFirstFrame,
    // Linux + zeigt das Hauptfenster → warme Instanz: Fenster beim Schließen nur
    // verstecken (Prozess bleibt am Leben) und Öffnen-Kommandos von Widgets
    // entgegennehmen. Nur Linux (Windows behält „schließen = beenden").
    warmMainInstance: Platform.isLinux && showWindowAfterFirstFrame,
  ));
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
  // Beim Start per Ordner-Widget: dieser Ordner wird nach dem ersten Frame in der
  // Notizliste vorselektiert (Home zeigt dann direkt den Ordnerinhalt).
  final String? initialFolder;
  // true, wenn die App vom Einstellungen-Button eines Sticky-Fensters
  // (--show-settings) gestartet wurde -> nach dem Start direkt Einstellungen.
  final bool openSettings;
  // Desktop: Fenster erst nach dem ersten Frame zeigen/fokussieren (kein
  // schwarzes Fenster) – siehe main().
  final bool showWindowAfterFirstFrame;
  // Desktop: angeheftete Widgets erst nach dem ersten Frame öffnen (nur im
  // „aus Widget geöffnet"-Pfad, wo die Widgets ohnehin schon laufen).
  final bool openWidgetsAfterFirstFrame;
  // Linux: Diese Instanz ist die „warme" Hauptinstanz – beim Schließen nur
  // verstecken (Prozess bleibt am Leben) und Öffnen-Kommandos von Widgets über
  // MainInstanceService entgegennehmen, damit das nächste Öffnen sofort da ist.
  final bool warmMainInstance;

  const NotizblockApp({
    super.key,
    this.initialNote,
    this.initialFolder,
    this.openSettings = false,
    this.showWindowAfterFirstFrame = false,
    this.openWidgetsAfterFirstFrame = false,
    this.warmMainInstance = false,
  });

  @override
  State<NotizblockApp> createState() => _NotizblockAppState();
}

class _NotizblockAppState extends State<NotizblockApp> with WindowListener {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  static const _channel = MethodChannel('notizblock/deeplink');
  // Linux (warme Instanz): pollt Öffnen-Kommandos von Widget-Prozessen.
  Timer? _mainCmdTimer;

  @override
  void initState() {
    super.initState();
    // Warmstart: Läuft die App schon und das Widget wird getippt, schickt
    // MainActivity per onNewIntent ein 'openNote' über diesen Channel.
    if (Platform.isAndroid) {
      _setupDeepLinkListener();
    }

    // Warme Hauptinstanz (Linux): Fenster beim Schließen nur verstecken statt
    // den Prozess zu beenden, und Öffnen-Kommandos von Widgets entgegennehmen.
    if (widget.warmMainInstance) {
      windowManager.setPreventClose(true);
      windowManager.addListener(this);
      _mainCmdTimer = Timer.periodic(
        const Duration(milliseconds: 300),
        (_) => _checkMainCommand(),
      );
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

    // Verzögerter Start NACH dem ersten Frame (siehe main()): Fenster zeigen +
    // fokussieren (Desktop), stiller Login und ggf. angeheftete Widgets öffnen.
    // Bewusst nicht vor runApp – das blockierte sonst den ersten Frame (schwarzes
    // Fenster / „reagiert nicht").
    WidgetsBinding.instance.addPostFrameCallback((_) => _runDeferredStartup());
  }

  Future<void> _runDeferredStartup() async {
    // Fenster jetzt – mit fertig gezeichnetem Inhalt – in den Vordergrund holen.
    if (widget.showWindowAfterFirstFrame) {
      try {
        await windowManager.show();
        await windowManager.focus();
      } catch (_) {}
    }
    // Desktop: stiller Login erst JETZT (nach dem ersten Frame). Der Netzwerk-GET
    // (userinfo) würde sonst vor runApp den Frame blockieren → schwarzes Fenster.
    // Mobil ist der Login bereits vor runApp passiert. Die UI zieht über
    // GoogleDriveService.signedInNotifier nach.
    if (_isDesktop) {
      await GoogleDriveService.instance.signInSilently();
    }
    // Angeheftete Widgets (nur im „aus Widget"-Pfad zurückgestellt) öffnen.
    if (widget.openWidgetsAfterFirstFrame) {
      await StickyNoteService.instance.openAllWidgets();
    }
    // Kaltstart per Ordner-Widget: den gewählten Ordner in der Notizliste
    // vorselektieren (HomeScreen ist bereits gebaut -> NotesProvider existiert).
    if (widget.initialFolder != null && widget.initialFolder!.isNotEmpty) {
      final ctx = _navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        Provider.of<NotesProvider>(ctx, listen: false)
            .selectFolder(widget.initialFolder!);
      }
    }
  }

  @override
  void dispose() {
    _mainCmdTimer?.cancel();
    if (widget.warmMainInstance) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  // Warme Instanz: Ein Widget hat „Hauptmenü/Einstellungen öffnen" angefordert
  // (Kommandodatei via MainInstanceService). Fenster sofort nach vorne holen –
  // kein neuer Prozess, kein Kaltstart.
  Future<void> _checkMainCommand() async {
    final cmd = await MainInstanceService.instance.pollCommand();
    if (cmd == null) return;
    await _bringToFront(settings: cmd == 'settings');
  }

  Future<void> _bringToFront({required bool settings}) async {
    try {
      await windowManager.setSkipTaskbar(false);
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    // Auf die Notizliste zurück (deterministisch), dann ggf. Einstellungen.
    nav.popUntil((route) => route.isFirst);
    if (settings) {
      nav.push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    }
  }

  @override
  void onWindowClose() async {
    // Warme Instanz: NICHT beenden, nur verstecken → das nächste Öffnen aus
    // einem Widget ist sofort da (kein Kaltstart). setPreventClose(true) (in
    // initState) verhindert, dass window_manager das Fenster zerstört.
    if (!widget.warmMainInstance) return;
    try {
      await windowManager.setSkipTaskbar(true);
      await windowManager.hide();
    } catch (_) {}
  }

  void _setupDeepLinkListener() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openNote') {
        final noteId = call.arguments as String?;
        if (noteId != null) {
          _openNoteEditor(noteId);
        }
      } else if (call.method == 'openFolder') {
        final folder = call.arguments as String?;
        if (folder != null) {
          _openFolder(folder);
        }
      }
    });
  }

  // Warmstart-Pfad (Ordner-Widget): zur Notizliste zurück und den Ordner wählen.
  void _openFolder(String folder) {
    final ctx = _navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    Provider.of<NotesProvider>(ctx, listen: false).selectFolder(folder);
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