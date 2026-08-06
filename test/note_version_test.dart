import 'package:flutter_test/flutter_test.dart';
import 'package:notizblock/services/google_drive_service.dart';

/// Der Versionsverlauf liest Zeitpunkt und Titel aus dem Dateinamen der
/// Drive-Snapshots (`<id>__<zeitstempel>__<titel>.json`). Stimmt das Parsen
/// nicht, stehen im Verlauf falsche Zeiten – und man stellt den falschen Stand
/// wieder her. Deshalb hier abgesichert.
void main() {
  const id = '63254759-b8e9-40f9-b44c-02a2d039b182';

  test('Zeitpunkt und Titel werden aus dem Dateinamen gelesen (Altformat)', () {
    final v = NoteVersion.fromFileName(
      '${id}__2026-08-04T18-30-05.123Z__Einkauf.json',
      fileId: 'abc',
    );
    expect(v.fileId, 'abc');
    expect(v.title, 'Einkauf');
    expect(v.device, isEmpty); // vor 1.30.1 gab es die Angabe noch nicht
    expect(v.deleted, isFalse);
    expect(v.savedAt.toUtc(), DateTime.utc(2026, 8, 4, 18, 30, 5, 123));
  });

  test('Gerät wird gelesen (Format ab 1.30.1)', () {
    final v = NoteVersion.fromFileName(
      '${id}__2026-08-04T18-30-05.123Z__Einkauf__Windows - ANDI-PC.json',
      fileId: 'abc',
    );
    expect(v.title, 'Einkauf');
    expect(v.device, 'Windows - ANDI-PC');
    expect(v.deleted, isFalse);
  });

  test('gelöschte Notizen sind als solche erkennbar (Altformat)', () {
    final v = NoteVersion.fromFileName(
      '${id}__2026-08-04T18-30-05.123Z__Alte Notiz__geloescht.json',
      fileId: 'abc',
    );
    expect(v.deleted, isTrue);
    expect(v.title, 'Alte Notiz');
    expect(v.device, isEmpty); // „geloescht" ist kein Gerätename
  });

  test('gelöschte Notiz mit Gerät', () {
    final v = NoteVersion.fromFileName(
      '${id}__2026-08-04T18-30-05.123Z__Alte Notiz__Android - Pixel 7__geloescht.json',
      fileId: 'abc',
    );
    expect(v.deleted, isTrue);
    expect(v.device, 'Android - Pixel 7');
    expect(v.title, 'Alte Notiz');
  });

  test('unlesbarer Zeitstempel fällt auf die Drive-Zeit zurück', () {
    final fallback = DateTime.utc(2026, 1, 2, 3, 4);
    final v = NoteVersion.fromFileName(
      '${id}__kaputt__Titel.json',
      fileId: 'abc',
      fallbackTime: fallback,
    );
    expect(v.savedAt.toUtc(), fallback);
    expect(v.title, 'Titel');
  });

  test('Titel mit Leerzeichen bleibt erhalten', () {
    final v = NoteVersion.fromFileName(
      '${id}__2026-08-04T09-00-00.000Z__Autopool Geräte Liste.json',
      fileId: 'x',
    );
    expect(v.title, 'Autopool Geräte Liste');
  });
}
