import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

/// Sorgt dafür, dass die App nach einem **Windows-Update der App** (MSIX-/Store-
/// Update) automatisch wieder startet, wenn sie vorher lief.
///
/// Hintergrund: Beim Aktualisieren des Pakets beendet Windows (über den Restart
/// Manager) alle laufenden Prozesse der App und startet sie danach NICHT von
/// selbst neu – die angehefteten Sticky-Widgets waren weg, bis man die App von
/// Hand öffnete. Mit der Win32-API `RegisterApplicationRestart` registriert sich
/// ein laufender Prozess für genau diesen Fall: Der Restart Manager startet ihn
/// nach dem Servicing mit der hier hinterlegten Kommandozeile neu.
///
/// Aufrufer:
/// - **Jeder Sticky-Note-Prozess** registriert sich mit `--sticky-note <id>` →
///   nach einem Update kommt jedes offene Widget einzeln mit gespeicherter Lage
///   wieder hoch (kein zentraler „Wieder-öffnen"-Lauf nötig, keine Doppel-Fenster).
/// - **Das Hauptfenster** (falls es offen bleibt) registriert sich mit
///   `--show-main --updated`; das `--updated` lässt den neu gestarteten
///   Hauptprozess das erneute Öffnen der Widgets überspringen (die starten sich
///   ja selbst neu).
///
/// Flags: NUR nach Update/Patch neu starten – nicht bei Absturz/Hänger (kein
/// Endlos-Neustart eines kaputten Fensters) und nicht beim System-Reboot (das
/// deckt bereits der Autostart-Eintrag ab). Nur Windows; sonst no-op.
class RestartOnUpdateService {
  // dwFlags-Bits aus winuser.h.
  static const int _restartNoCrash = 1; // RESTART_NO_CRASH
  static const int _restartNoHang = 2; // RESTART_NO_HANG
  static const int _restartNoReboot = 8; // RESTART_NO_REBOOT

  /// Registriert den AKTUELLEN Prozess für den Neustart nach einem App-Update.
  /// [args] sind die Argumente, mit denen er neu gestartet werden soll (ohne den
  /// Exe-Namen – den ergänzt Windows selbst).
  static void register(List<String> args) {
    if (!Platform.isWindows) return;
    Pointer<Utf16>? cmd;
    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final registerApplicationRestart = kernel32.lookupFunction<
          Int32 Function(Pointer<Utf16>, Uint32),
          int Function(Pointer<Utf16>, int)>('RegisterApplicationRestart');
      cmd = args.join(' ').toNativeUtf16();
      final hr = registerApplicationRestart(
          cmd, _restartNoCrash | _restartNoHang | _restartNoReboot);
      // S_OK == 0. Andernfalls nur protokollieren – Autostart-Funktionalität
      // hängt nicht davon ab.
      if (hr != 0) {
        debugPrint('RegisterApplicationRestart fehlgeschlagen: hr=$hr');
      }
    } catch (e) {
      debugPrint('RegisterApplicationRestart Aufruf fehlgeschlagen: $e');
    } finally {
      if (cmd != null) malloc.free(cmd);
    }
  }
}
