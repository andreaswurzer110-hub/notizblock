import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repariert eine unlesbar gewordene `shared_preferences`-Datei (nur Desktop).
///
/// **Warum das nötig ist (war real ein Bug, 1.29.1):** Auf Windows/Linux legt
/// das Plugin ALLE Werte in EINER Datei `<AppSupport>/shared_preferences.json`
/// ab und liest sie mit `json.decode`. Stürzt der PC ab bzw. wird er hart
/// ausgeschaltet, während die Datei geschrieben wird, bleibt sie mit korrekter
/// Größe, aber komplett mit **Nullbytes** gefüllt zurück (übliches NTFS-
/// Verhalten). Ab da wirft **jeder** Zugriff auf SharedPreferences eine
/// `FormatException: Unexpected character (at character 1)`.
///
/// Weil `GoogleDriveService._doSynchronize()` als Erstes die Sync-Zeitstempel
/// aus den Prefs liest, schlug damit **jeder** Sync fehl – dauerhaft, denn die
/// kaputte Datei bleibt ja liegen. Sichtbar war das als
/// „Synchronisierung fehlgeschlagen: FormatException: Unexpected character
/// (at character 1)" gefolgt von einer langen Reihe leerer Kästchen (= die
/// Nullbytes).
///
/// Deshalb beim Start einmal prüfen und eine unlesbare Datei löschen. Verloren
/// gehen dabei nur die Sync-Koordinaten (`last_sync_timestamp`,
/// `last_remote_sync_time`, `delta_migrated`) – die stehen in der kaputten
/// Datei ohnehin nicht mehr. Folge: Der nächste Sync gleicht einmalig alles
/// komplett ab (last-write-wins über `modifiedAt`) – dauert länger, verliert
/// aber nichts. Die Nutzer-Einstellungen sind NICHT betroffen, die liegen in
/// `settings.json` ([SettingsStore]).
class PrefsRepairService {
  PrefsRepairService._();

  static const String _fileName = 'shared_preferences.json';

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Stellt sicher, dass SharedPreferences benutzbar ist. Im Normalfall kostet
  /// das nichts (die Instanz wird ohnehin gebraucht und ist danach gecacht).
  static Future<void> ensureUsable() async {
    if (!_isDesktop) return; // Android/iOS nutzen kein JSON-File
    try {
      await SharedPreferences.getInstance();
      return; // alles in Ordnung
    } catch (e) {
      debugPrint('shared_preferences unlesbar ($e) – Datei wird verworfen.');
    }
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, _fileName));
      if (await file.exists()) await file.delete();
      // Erneut laden: getInstance() setzt seinen Cache bei einem Fehler zurück,
      // der zweite Aufruf liest also frisch (jetzt ohne Datei = leere Prefs).
      await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('shared_preferences reparieren fehlgeschlagen: $e');
    }
  }
}
