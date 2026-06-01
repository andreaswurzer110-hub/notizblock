import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../providers/settings_provider.dart';
import 'google_drive_service.dart';

/// Hintergrund-Synchronisierung über Android `WorkManager`.
///
/// Zieht periodisch (Standard 1 h) auch dann von Google Drive, wenn die App
/// komplett geschlossen ist – so aktualisiert sich das Homescreen-Widget mit
/// Änderungen von anderen Geräten, ohne dass man die App öffnen muss. Im
/// Vordergrund läuft weiterhin der schnellere 15-s-Pull im `NotesProvider`.
///
/// Nur Android: iOS hat ein anderes Background-Modell, Desktop hat keinen
/// WorkManager (dort hält das laufende Hauptfenster den Sync ohnehin aktuell).

/// Eindeutiger Name des periodischen Jobs (zum Registrieren/Abbrechen).
const String _periodicSyncUniqueName = 'notizblock_periodic_sync';
const String _periodicSyncTaskName = 'periodicSync';

/// Top-Level-Einsprungpunkt, den WorkManager im Hintergrund-Isolate aufruft.
/// MUSS top-level + `@pragma('vm:entry-point')` sein, damit der AOT-Compiler ihn
/// nicht wegoptimiert.
@pragma('vm:entry-point')
void backgroundSyncCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      // Läuft in einem eigenen Isolate -> Bindings + Plugins initialisieren.
      WidgetsFlutterBinding.ensureInitialized();

      // Nur arbeiten, wenn der Nutzer Auto-Sync aktiviert hat.
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(SettingsProvider.autoSyncKey) ?? false)) {
        return true;
      }

      // Frischer stiller Login (Isolate teilt keinen Zustand mit der App).
      final signedIn = await GoogleDriveService.instance.signInSilently();
      if (!signedIn) return true;

      // Delta-Sync. Schreibt bei Änderungen notes.json neu und feuert über
      // DatabaseService._updateWidgetJsonFile den Widget-Refresh-Broadcast.
      await GoogleDriveService.instance.synchronize();
      return true;
    } catch (e) {
      debugPrint('Hintergrund-Sync fehlgeschlagen: $e');
      // true statt false: kein sofortiger Retry mit Backoff – wir warten einfach
      // auf den nächsten regulären Durchlauf.
      return true;
    }
  });
}

class BackgroundSyncService {
  BackgroundSyncService._();

  /// Plugin initialisieren (einmal beim App-Start, vor enable/disable).
  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    await Workmanager().initialize(backgroundSyncCallbackDispatcher);
  }

  /// Periodischen Hintergrund-Sync aktivieren (1 h, beliebiges Netz inkl. mobiler
  /// Daten). Android-Minimum für periodische Jobs ist 15 min; 1 h ist akkuschonend.
  static Future<void> enable() async {
    if (!Platform.isAndroid) return;
    await Workmanager().registerPeriodicTask(
      _periodicSyncUniqueName,
      _periodicSyncTaskName,
      frequency: const Duration(hours: 1),
      // Erster Lauf nicht sofort – im Vordergrund synct die App eh selbst.
      initialDelay: const Duration(minutes: 15),
      // Bestehenden Job behalten, nicht bei jedem Start neu takten.
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      // connected = irgendein Netz (WLAN ODER mobile Daten), nicht nur WLAN.
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  /// Hintergrund-Sync abschalten (Auto-Sync aus).
  static Future<void> disable() async {
    if (!Platform.isAndroid) return;
    await Workmanager().cancelByUniqueName(_periodicSyncUniqueName);
  }
}
