import 'dart:async';
import 'dart:io';

/// Startet [programm] mit [argumente] als eigenständigen Prozess, der den
/// Aufrufer überlebt (Notizzettel, Hauptfenster, Einstellungen).
///
/// Windows/macOS: wie bisher `ProcessStartMode.detached`.
///
/// Linux: über eine kurzlebige Shell. Dart lässt beim detached-Start unter
/// Linux den Zwischenprozess als Zombie unter dem Aufrufer stehen – einen pro
/// Start, sichtbar als „notizblock" in der Prozessliste, bis der Aufrufer endet
/// (gemessen 2026-10-08: jeder Haus-Klick eines Notizzettels ließ einen mehr
/// zurück). Die Shell startet die App im Hintergrund (Ein-/Ausgabe nach
/// /dev/null, wie beim detached-Start) und beendet sich sofort; Dart räumt die
/// Shell ab, die App hängt danach am System und wird dort abgeräumt.
/// Bewusst ohne `setsid`: das lässt die Snap-Sandbox nicht zu (snapds
/// AppArmor-Vorlage erlaubt `/bin/sh` = dash, `setsid` nicht).
Future<void> starteEigenstaendig(String programm, List<String> argumente) async {
  if (!Platform.isLinux) {
    await Process.start(programm, argumente, mode: ProcessStartMode.detached);
    return;
  }
  final shell = await Process.start('/bin/sh', [
    '-c',
    r'"$@" </dev/null >/dev/null 2>&1 &',
    'sh',
    programm,
    ...argumente,
  ]);
  unawaited(shell.stdout.drain<void>());
  unawaited(shell.stderr.drain<void>());
  unawaited(shell.stdin.close());
  await shell.exitCode;
}
