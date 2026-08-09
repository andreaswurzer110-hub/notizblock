import 'package:flutter_test/flutter_test.dart';
import 'package:notizblock/services/google_drive_service.dart';

/// Wann darf der Abgleich einen Konflikt melden?
///
/// NUR wenn dabei tatsächlich eine Änderung übersprungen wird. Vorher reichte
/// „lokal geändert UND Remote-Datei neu in der Liste" – das traf auch auf die
/// EIGENE gerade hochgeladene Datei zu, weshalb ständig „Konflikt" kam, obwohl
/// alle Änderungen vom selben Gerät stammten. Diese Fälle sichern das ab.
void main() {
  // Zeitstempel = Fassungen der Notiz (modifiedAt, ISO).
  const v11 = '2026-08-09T11:00:00.000'; // gemeinsamer Stand
  const v12 = '2026-08-09T12:00:00.000'; // Änderung von Gerät A
  const v1220 = '2026-08-09T12:20:00.000'; // Änderung von Gerät B

  test('eigener Upload taucht erneut in der Remote-Liste auf -> kein Konflikt',
      () {
    // Basis == Remote-Fassung: die Drive-Datei ist genau die, die wir zuletzt
    // selbst hochgeladen haben. Lokal darf seither beliebig getippt worden sein.
    expect(
      GoogleDriveService.isSkippedChange(
        base: v12,
        local: v1220,
        remote: v12,
        remoteBasedOn: v11,
      ),
      isFalse,
    );
  });

  test('nur die fremde Seite hat geändert -> kein Konflikt (sauber nachziehen)',
      () {
    expect(
      GoogleDriveService.isSkippedChange(
        base: v11,
        local: v11,
        remote: v12,
        remoteBasedOn: v11,
      ),
      isFalse,
    );
  });

  test('beide Seiten seit dem gemeinsamen Stand geändert -> Konflikt', () {
    // Gerät B war auf dem 11-Uhr-Stand, ändert um 12:20 und überschreibt damit
    // die 12-Uhr-Änderung von Gerät A. Genau der Fall, der gemeldet werden soll.
    expect(
      GoogleDriveService.isSkippedChange(
        base: v11,
        local: v1220,
        remote: v12,
        remoteBasedOn: v11,
      ),
      isTrue,
    );
  });

  test('fremde Änderung setzt auf älterer Fassung auf -> Konflikt', () {
    // Gegenseite desselben Falls: Gerät A hat um 12 Uhr hochgeladen (Basis),
    // bekommt jetzt die 12:20-Fassung von Gerät B, die aber auf dem 11-Uhr-
    // Stand aufsetzt -> die eigene 12-Uhr-Änderung wird überschrieben.
    expect(
      GoogleDriveService.isSkippedChange(
        base: v12,
        local: v12,
        remote: v1220,
        remoteBasedOn: v11,
      ),
      isTrue,
    );
  });

  test('übersprungene Zwischenstände anderer Geräte sind kein Konflikt', () {
    // Wir hängen hinterher (Basis 11 Uhr) und holen die 12:20-Fassung, die auf
    // dem 12-Uhr-Stand aufsetzt. Uns geht nichts verloren – Drive hält pro
    // Notiz ohnehin nur die jüngste Datei.
    expect(
      GoogleDriveService.isSkippedChange(
        base: v11,
        local: v11,
        remote: v1220,
        remoteBasedOn: v12,
      ),
      isFalse,
    );
  });

  test('ohne Basis-Angabe der Gegenseite wird nicht gewarnt', () {
    // Ältere App-Version hat zuletzt hochgeladen -> Herkunft unbekannt.
    // Lieber keine Meldung als eine falsche.
    expect(
      GoogleDriveService.isSkippedChange(
        base: v12,
        local: v12,
        remote: v1220,
        remoteBasedOn: null,
      ),
      isFalse,
    );
  });

  test('unlesbare Zeitstempel führen nicht zu einer Meldung', () {
    expect(
      GoogleDriveService.isSkippedChange(
        base: v12,
        local: v12,
        remote: v1220,
        remoteBasedOn: 'kaputt',
      ),
      isFalse,
    );
  });
}
