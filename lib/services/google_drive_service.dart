import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/note.dart';
import 'database_service.dart';
import 'google_drive_config.dart';
import 'settings_store.dart';
import 'conflict_store.dart';
import 'device_info_service.dart';

/// Maximale Dauer eines einzelnen Drive-HTTP-Requests (Verbindung + Senden +
/// Antwort-Header) bzw. einer Stillstands-Pause im Download-Stream. Schutz gegen
/// endloses Hängen bei stockendem Netz (Standby/Resume, Netzwechsel): die Notiz-/
/// Backup-Dateien sind klein (KB), 30 s sind reichlich. Bei Stillstand bricht der
/// Request ab → der Sync scheitert SAUBER (als Fehler-Result, _inFlight wird im
/// finally aufgeräumt) und der nächste Auto-Sync versucht es erneut, statt
/// unendlich zu warten (war real ein „Sync hängt"-Fall).
const Duration _netTimeout = Duration(seconds: 30);

/// http.Client, der jeden Request nach [_netTimeout] abbricht. Wird als
/// zugrundeliegender Client für ALLE Drive-Aufrufe genutzt – mobil über
/// [GoogleAuthClient], auf Desktop über `autoRefreshingClient` /
/// `clientViaUserConsent` –, damit ein hängender Request nicht den ganzen Sync
/// (und über die Reentrancy alle weiteren Syncs desselben Prozesses) blockiert.
class _TimeoutClient extends http.BaseClient {
  final http.Client _inner;
  _TimeoutClient(this._inner);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request).timeout(_netTimeout);
  @override
  void close() => _inner.close();
}

/// HTTP-Client für google_sign_in (Mobil), der die Auth-Header PRO REQUEST frisch
/// aus dem aktuell angemeldeten Konto holt – NICHT einmal beim Login einfriert.
/// Grund: das Google-Access-Token lebt nur ~1 h. Ein eingefrorener Header lieferte
/// danach 401 und die App loggte sich fälschlich aus (war real ein Bug). So zieht
/// auch ein zwischenzeitlicher clearAuthCache()-Refresh sofort beim nächsten Request.
class GoogleAuthClient extends http.BaseClient {
  final GoogleSignIn _signIn;
  final http.Client _client = _TimeoutClient(http.Client());

  GoogleAuthClient(this._signIn);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final headers = await _signIn.currentUser?.authHeaders;
    if (headers != null) request.headers.addAll(headers);
    return _client.send(request);
  }
}

class GoogleDriveService {
  static const String _folderName = 'Notizblock Backup';
  static const String _backupFileName = 'notizblock_backup.json';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _lastRemoteSyncKey = 'last_remote_sync_time';
  static const String _migratedKey = 'delta_migrated';
  // Alter prefs-Key – nur noch für die einmalige Migration in die eigene Datei.
  static const String _credentialsKey = 'drive_desktop_credentials';
  // Desktop-OAuth-Credentials liegen in EINER eigenen Datei (NICHT in
  // shared_preferences). Grund: jeder Prozess (Hauptapp + Sticky-Fenster)
  // schreibt prefs (Sync-Zeitstempel, Token-Refresh) und kippt dabei mit
  // seinem veralteten Gesamt-Snapshot z.B. eine Abmeldung wieder zurück
  // („Abmelden hält nicht"). Schreiber ist NUR die Hauptapp; siehe
  // [isSecondaryProcess]. (CLAUDE.md: „kein shared_preferences für
  // prozessübergreifende Writes".)
  static const String _credentialsFileName = 'drive_credentials.json';

  /// Zusatzfeld in `notes/<id>.json`: `modifiedAt` der Fassung, auf der die
  /// hochgeladene Änderung aufsetzt (der Vorgänger-Stand). KEIN Feld der Notiz
  /// selbst – `Note.fromJson` ignoriert es, ältere App-Versionen ebenso.
  static const String _basedOnKey = 'basedOn';

  /// true in Sticky-Note-Prozessen. Solche Prozesse dürfen Credentials NICHT
  /// persistieren – sonst würde ein laufendes Sticky-Fenster eine Abmeldung der
  /// Hauptapp durch einen still erneuerten Token wieder zurückschreiben. Wird in
  /// `main()` für den `--sticky-note`-Zweig gesetzt.
  static bool isSecondaryProcess = false;

  /// Login-Status als beobachtbarer Wert. Nötig, weil der stille Login seit der
  /// Start-Performance-Optimierung NICHT mehr vor `runApp` abgewartet wird
  /// (siehe main.dart) – die UI (v.a. der Einstellungen-Screen) zieht über
  /// diesen Notifier nach, sobald die Anmeldung asynchron fertig ist.
  final ValueNotifier<bool> signedInNotifier = ValueNotifier<bool>(false);

  // Unterordner im Backup-Ordner
  static const String _notesFolderName = 'notes';
  static const String _tombstonesFolderName = 'tombstones';
  static const String _historyFolderName = 'history';

  // Ordnerliste als eigene Datei im Backup-Root (last-write-wins per Zeitstempel).
  // Ohne sie erscheinen LEERE Ordner nie auf anderen Geräten (bisher zeigte sich
  // ein Ordner nur, wenn eine synchronisierte Notiz ihn referenziert). Keys müssen
  // zu NotesProvider.foldersKey/foldersModifiedAtKey passen.
  static const String _foldersFileName = 'folders.json';
  static const String _foldersKey = 'folders';
  static const String _foldersModifiedKey = 'folders_modified_at';

  // Historie-Aufbewahrung
  static const int _historyPerNote = 30; // Versionen pro Notiz
  static const int _deletedRetentionDays = 30; // Gelöschte so lange behalten

  // OAuth-Scopes: nur von der App erstellte Dateien + Basis-Profil.
  static const List<String> _scopes = [
    drive.DriveApi.driveFileScope,
    'email',
    'profile',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);

  GoogleSignInAccount? _mobileUser;
  http.Client? _authClient;
  drive.DriveApi? _driveApi;
  String? _userEmail;
  String? _userName;
  Future<SyncResult>? _inFlight;

  // Singleton
  GoogleDriveService._privateConstructor();
  static final GoogleDriveService instance =
      GoogleDriveService._privateConstructor();

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  bool get isSignedIn => _driveApi != null;
  String? get userEmail => _userEmail;
  String? get userName => _userName;

  // Interaktive Anmeldung (Button "Anmelden")
  Future<bool> signIn() async {
    try {
      if (_isDesktop) {
        return await _desktopSignIn(interactive: true);
      }
      return await _mobileSignIn(silent: false);
    } catch (e) {
      debugPrint('Google Sign-In Fehler: $e');
      return false;
    }
  }

  // Stille Anmeldung (beim App-Start)
  Future<bool> signInSilently() async {
    try {
      if (_isDesktop) {
        return await _desktopSignIn(interactive: false);
      }
      return await _mobileSignIn(silent: true);
    } catch (e) {
      debugPrint('Stille Anmeldung fehlgeschlagen: $e');
      return false;
    }
  }

  // Abmelden
  Future<void> signOut() async {
    if (_isDesktop) {
      await _deleteStoredCredentials();
    } else {
      await _googleSignIn.signOut();
      _mobileUser = null;
    }
    _authClient?.close();
    _authClient = null;
    _driveApi = null;
    _userEmail = null;
    _userName = null;
    signedInNotifier.value = false;
  }

  // Erkennt Auth-/Token-Fehler: abgelaufenes Refresh-Token (im OAuth-"Testing"-
  // Status laufen Desktop-Refresh-Tokens nach 7 Tagen ab), widerrufener Zugriff
  // oder 401. Solche Fehler heilen nicht von selbst – der Nutzer muss sich neu
  // anmelden. Der stille Desktop-Login baut den Client offline aus gespeicherten
  // Credentials (ohne Token-Prüfung); erst der erste echte Request scheitert.
  bool _isAuthError(Object e) {
    if (e is drive.DetailedApiRequestError && e.status == 401) return true;
    final s = e.toString().toLowerCase();
    return s.contains('invalid_grant') ||
        s.contains('invalid_token') ||
        s.contains('invalid_rapt');
  }

  // Tote Credentials verwerfen und Login-Status zurücksetzen, damit die UI sauber
  // zum Neu-Anmelden auffordert statt denselben kryptischen Fehler zu wiederholen.
  Future<void> _handleAuthFailure() async {
    debugPrint('Auth-Fehler erkannt – Anmeldung wird zurückgesetzt.');
    if (_isDesktop) {
      await _deleteStoredCredentials();
    } else {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      _mobileUser = null;
    }
    _authClient?.close();
    _authClient = null;
    _driveApi = null;
    _userEmail = null;
    _userName = null;
    signedInNotifier.value = false;
  }

  // Mobil: abgelaufenes Access-Token (~1 h) still erneuern, statt den Nutzer
  // sichtbar auszuloggen. google_sign_in cached das Token lokal; laut Plugin-Doku
  // bei 401 clearAuthCache() aufrufen – danach holt GoogleAuthClient beim nächsten
  // Request automatisch ein frisches Token. Gibt true zurück, wenn wieder ein
  // gültiges Konto verbunden ist (dann lohnt ein erneuter Versuch).
  Future<bool> _refreshMobileToken() async {
    if (_isDesktop) return false;
    try {
      // Konto evtl. nach langem Hintergrund verloren -> still neu verbinden.
      _mobileUser ??= await _googleSignIn.signInSilently();
      if (_mobileUser == null) return false;
      await _mobileUser!.clearAuthCache();
      return true;
    } catch (e) {
      debugPrint('Token-Refresh fehlgeschlagen: $e');
      return false;
    }
  }

  // --- Mobil (Android/iOS) via google_sign_in ---
  Future<bool> _mobileSignIn({required bool silent}) async {
    _mobileUser = silent
        ? await _googleSignIn.signInSilently()
        : await _googleSignIn.signIn();
    if (_mobileUser == null) return false;

    // Client holt die Header pro Request frisch (siehe GoogleAuthClient), daher
    // hier nur die GoogleSignIn-Instanz übergeben statt eines Header-Schnappschusses.
    _authClient = GoogleAuthClient(_googleSignIn);
    _userEmail = _mobileUser!.email;
    _userName = _mobileUser!.displayName ?? _mobileUser!.email;
    _driveApi = drive.DriveApi(_authClient!);
    signedInNotifier.value = true;
    return true;
  }

  // --- Desktop (Windows/Linux/macOS) via OAuth-Loopback ---
  Future<bool> _desktopSignIn({required bool interactive}) async {
    if (!GoogleDriveConfig.isDesktopConfigured) {
      debugPrint(
        'Desktop-OAuth nicht konfiguriert – bitte google_drive_config.dart ausfüllen.',
      );
      return false;
    }

    final clientId = auth.ClientId(
      GoogleDriveConfig.desktopClientId,
      GoogleDriveConfig.desktopClientSecret,
    );

    // 1) Gespeicherte Credentials → stiller Login ohne Browser
    final stored = await _readStoredCredentials();
    if (stored != null) {
      try {
        final credentials = auth.AccessCredentials.fromJson(
          jsonDecode(stored) as Map<String, dynamic>,
        );
        final client = auth.autoRefreshingClient(
            clientId, credentials, _TimeoutClient(http.Client()));
        client.credentialUpdates.listen(_saveCredentials);
        await _finishDesktopSignIn(client);
        return true;
      } catch (e) {
        debugPrint('Gespeicherte Credentials ungültig, neu anmelden: $e');
        await _deleteStoredCredentials();
      }
    }

    // 2) Ohne interaktiven Wunsch hier aufhören (App-Start)
    if (!interactive) return false;

    // 3) Interaktiver Browser-Consent-Flow (lokaler Loopback-Server)
    final client = await auth.clientViaUserConsent(
      clientId,
      _scopes,
      (url) {
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
      baseClient: _TimeoutClient(http.Client()),
    );
    client.credentialUpdates.listen(_saveCredentials);
    await _saveCredentials(client.credentials);
    await _finishDesktopSignIn(client);
    return true;
  }

  Future<void> _finishDesktopSignIn(auth.AutoRefreshingAuthClient client) async {
    _authClient = client;
    _driveApi = drive.DriveApi(client);
    await _loadUserInfo(client);
    // Erst jetzt melden (E-Mail/Name stehen) → reaktive UI zeigt sie sofort.
    signedInNotifier.value = true;
  }

  Future<void> _saveCredentials(auth.AccessCredentials credentials) async {
    // Sticky-/Sekundärprozesse persistieren Token-Refreshs NICHT – sonst würde
    // ein laufendes Sticky-Fenster eine Abmeldung der Hauptapp durch einen still
    // erneuerten Token wieder zurückschreiben. Der Refresh-Token bleibt gültig;
    // die Hauptapp aktualisiert die Datei beim nächsten Refresh selbst.
    if (isSecondaryProcess) return;
    await _writeStoredCredentials(jsonEncode(credentials.toJson()));
  }

  // --- Desktop-Credentials in eigener Datei (siehe _credentialsFileName) ---

  Future<File> _credentialsFile() async {
    final base = await getApplicationSupportDirectory();
    return File(p.join(base.path, _credentialsFileName));
  }

  /// Gespeicherte Credentials lesen. Einmalige Migration: liegen sie noch im
  /// alten prefs-Key, in die Datei übernehmen und aus prefs entfernen.
  Future<String?> _readStoredCredentials() async {
    try {
      final f = await _credentialsFile();
      if (await f.exists()) return await f.readAsString();
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_credentialsKey);
      if (legacy != null) {
        await f.writeAsString(legacy);
        await prefs.remove(_credentialsKey);
        return legacy;
      }
    } catch (e) {
      debugPrint('Credentials lesen fehlgeschlagen: $e');
    }
    return null;
  }

  Future<void> _writeStoredCredentials(String json) async {
    try {
      final f = await _credentialsFile();
      await f.writeAsString(json);
    } catch (e) {
      debugPrint('Credentials speichern fehlgeschlagen: $e');
    }
  }

  Future<void> _deleteStoredCredentials() async {
    try {
      final f = await _credentialsFile();
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('Credentials löschen fehlgeschlagen: $e');
    }
    // Auch einen evtl. noch vorhandenen Alt-prefs-Key aufräumen.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_credentialsKey);
    } catch (_) {}
  }

  Future<void> _loadUserInfo(http.Client client) async {
    try {
      final response = await client
          .get(Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _userEmail = data['email'] as String?;
        _userName = (data['name'] ?? data['email']) as String?;
      }
    } catch (e) {
      debugPrint('Userinfo konnte nicht geladen werden: $e');
    }
  }

  // Backup-Ordner finden oder erstellen
  Future<String?> _getOrCreateBackupFolder() async {
    if (_driveApi == null) return null;

    try {
      // Nach existierendem Ordner suchen
      final folderList = await _driveApi!.files.list(
        q: "name='$_folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
        spaces: 'drive',
      );

      if (folderList.files != null && folderList.files!.isNotEmpty) {
        return folderList.files!.first.id;
      }

      // Neuen Ordner erstellen
      final folder = drive.File()
        ..name = _folderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await _driveApi!.files.create(folder);
      return createdFolder.id;
    } catch (e) {
      // Echten Fehler durchreichen (z.B. abgelaufenes Token), statt ihn als
      // nichtssagendes null/"Ordner konnte nicht erstellt werden" zu maskieren.
      debugPrint('Fehler beim Ordner erstellen: $e');
      rethrow;
    }
  }

  // Voll-Backup: alle Notizen als per-Notiz-Dateien + eine Gesamt-JSON.
  Future<bool> createBackup({bool allowAuthRetry = true}) async {
    if (_driveApi == null) {
      debugPrint('Nicht angemeldet');
      return false;
    }

    try {
      final rootId = await _getOrCreateBackupFolder();
      if (rootId == null) return false;
      final notesFolderId =
          await _getOrCreateSubfolder(rootId, _notesFolderName);
      if (notesFolderId == null) return false;

      final notes =
          await DatabaseService.instance.getAllNotes(includeArchived: true);

      // Jede Notiz als eigene Datei
      for (final note in notes) {
        await _putFile(
          notesFolderId,
          '${note.id}.json',
          jsonEncode(_notePayload(
              note, await DatabaseService.instance.getSyncBase(note.id))),
        );
        // Basis nachziehen, sonst meldet der nächste Sync den eigenen Upload
        // als fremde Änderung.
        await DatabaseService.instance
            .setSyncBase(note.id, note.modifiedAt.toIso8601String());
      }

      // Zusätzliche Gesamt-Datei als Fallback
      final backupData = {
        'version': 2,
        'createdAt': DateTime.now().toIso8601String(),
        'notes': notes.map((n) => n.toJson()).toList(),
      };
      await _putFile(rootId, _backupFileName, jsonEncode(backupData));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

      return true;
    } catch (e) {
      debugPrint('Backup Fehler: $e');
      if (_isAuthError(e)) {
        if (allowAuthRetry && !_isDesktop && await _refreshMobileToken()) {
          return createBackup(allowAuthRetry: false);
        }
        await _handleAuthFailure();
      }
      return false;
    }
  }

  // Voll-Wiederherstellung: alle per-Notiz-Dateien (und ggf. Alt-Backup) laden.
  Future<bool> restoreBackup({bool allowAuthRetry = true}) async {
    if (_driveApi == null) {
      debugPrint('Nicht angemeldet');
      return false;
    }

    try {
      final rootId = await _getOrCreateBackupFolder();
      if (rootId == null) return false;
      final notesFolderId =
          await _getOrCreateSubfolder(rootId, _notesFolderName);
      if (notesFolderId == null) return false;

      // Altes Gesamt-Backup einspielen, falls vorhanden (deckt Erst-Migration ab).
      await _importLegacyBackup(rootId);

      // Alle per-Notiz-Dateien laden
      final files = await _listFiles(notesFolderId);
      for (final f in files) {
        final content = await _downloadFile(f.id!);
        if (content == null) continue;
        try {
          final note = Note.fromJson(jsonDecode(content) as Map<String, dynamic>);
          await DatabaseService.instance.insertOrUpdateNotes([note]);
          await DatabaseService.instance
              .setSyncBase(note.id, note.modifiedAt.toIso8601String());
        } catch (_) {}
      }

      return true;
    } catch (e) {
      debugPrint('Wiederherstellung Fehler: $e');
      if (_isAuthError(e)) {
        if (allowAuthRetry && !_isDesktop && await _refreshMobileToken()) {
          return restoreBackup(allowAuthRetry: false);
        }
        await _handleAuthFailure();
      }
      return false;
    }
  }

  // Delta-Synchronisierung: nur geänderte Notizen, Tombstones für Löschungen,
  // Versions-Historie. Lädt/überträgt nur, was sich seit dem letzten Sync ändert.
  Future<SyncResult> synchronize() async {
    if (_driveApi == null) {
      return SyncResult(success: false, message: 'Nicht angemeldet');
    }
    // Läuft schon ein Sync (Auto + manuell gleichzeitig)? Dann denselben
    // mitbenutzen statt mit "läuft bereits" fehlzuschlagen.
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final future = _doSynchronize();
    _inFlight = future;
    try {
      return await future;
    } finally {
      _inFlight = null;
    }
  }

  Future<SyncResult> _doSynchronize({bool allowAuthRetry = true}) async {
    try {
      final rootId = await _getOrCreateBackupFolder();
      if (rootId == null) {
        return SyncResult(
            success: false, message: 'Ordner konnte nicht erstellt werden');
      }
      final notesFolderId = await _getOrCreateSubfolder(rootId, _notesFolderName);
      final tombFolderId =
          await _getOrCreateSubfolder(rootId, _tombstonesFolderName);
      final historyFolderId =
          await _getOrCreateSubfolder(rootId, _historyFolderName);
      if (notesFolderId == null ||
          tombFolderId == null ||
          historyFolderId == null) {
        return SyncResult(
            success: false, message: 'Unterordner konnten nicht erstellt werden');
      }

      final prefs = await SharedPreferences.getInstance();
      // Frische, prozessübergreifende Sicht (Hauptapp + Sticky-Fenster syncen beide).
      await prefs.reload();
      // Gemessenen Uhr-Versatz zur Drive-Serverzeit laden (siehe _isRemoteNewer).
      await _loadClockOffset(prefs);

      // Einmalige Migration vom alten Gesamt-Backup
      await _migrateLegacyIfNeeded(rootId);

      final lastSyncLocal = DateTime.tryParse(
              prefs.getString(_lastSyncKey) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final lastRemoteSync = prefs.getString(_lastRemoteSyncKey);

      // Watermark für lokale Änderungen JETZT festhalten – VOR dem Erfassen der
      // geänderten Notizen – und am Ende genau diesen Wert als neuen last_sync
      // speichern (NICHT now() am Ende). Sonst gehen Änderungen verloren, die
      // WÄHREND des Syncs gespeichert werden: ihr modifiedAt läge vor einem
      // End-now(), der nächste Sync (getNotesModifiedAfter) würde sie überspringen
      // und sie würden nie hochgeladen (war real ein Bug: nur Zwischenstand wie
      // "Test m" hochgeladen, finaler Stand "Test machen" verschluckt).
      final localSyncStart = DateTime.now();

      var uploaded = 0;
      var downloaded = 0;
      DateTime? maxSeen;
      // Auf beiden Seiten geänderte Notizen (siehe ConflictInfo).
      final conflicts = <ConflictInfo>[];
      // IDs, die wir in diesem Sync gerade von Remote übernommen haben – die
      // dürfen wir NICHT direkt wieder hochladen (verhindert Ping-Pong und das
      // versehentliche Zurückschreiben eines gerade geholten Stands).
      final appliedIds = <String>{};

      // Lokale Änderungen VOR dem Pull erfassen (Stand vor dem Mergen).
      final localChangedIds = (await DatabaseService.instance
              .getNotesModifiedAfter(lastSyncLocal))
          .map((n) => n.id)
          .toList();
      final pendingDeletions =
          await DatabaseService.instance.getPendingDeletions();

      // ---- PULL: geänderte Remote-Notizen ----
      final remoteNoteFiles =
          await _listFiles(notesFolderId, modifiedAfter: lastRemoteSync);
      for (final f in remoteNoteFiles) {
        maxSeen = _laterOf(maxSeen, f.modifiedTime);
        final content = await _downloadFile(f.id!);
        if (content == null) continue;
        try {
          final decoded = jsonDecode(content) as Map<String, dynamic>;
          final note = Note.fromJson(decoded);
          // Auf welcher Fassung die fremde Änderung aufsetzt (seit 1.31.2 mit
          // hochgeladen). Fehlt der Wert (ältere App-Version hat zuletzt
          // geschrieben), wird nicht gewarnt statt falsch gewarnt.
          final remoteBasedOn = decoded[_basedOnKey] as String?;
          final local = await DatabaseService.instance.getNoteById(note.id);
          final base = await DatabaseService.instance.getSyncBase(note.id);
          final remoteIso = note.modifiedAt.toIso8601String();

          // KONFLIKT nur, wenn dabei tatsächlich eine Änderung ÜBERSPRUNGEN
          // wird (siehe isSkippedChange). Es gewinnt weiterhin die neuere
          // Fassung, aber der Nutzer wird gewarnt und findet die andere im
          // Versionsverlauf.
          final isConflict = local != null &&
              base != null &&
              isSkippedChange(
                base: base,
                local: local.modifiedAt.toIso8601String(),
                remote: remoteIso,
                remoteBasedOn: remoteBasedOn,
              );
          if (local == null || _isRemoteNewer(note, local, f.modifiedTime)) {
            // Vor dem Überschreiben die LOKALE Fassung in die Historie retten –
            // sie wurde nie hochgeladen und wäre sonst endgültig weg.
            if (isConflict) {
              await _writeHistorySnapshot(historyFolderId, local);
            }
            await DatabaseService.instance.insertOrUpdateNotes([note]);
            // Ab jetzt ist DIESE Fassung unser gemeinsamer Stand mit Drive.
            await DatabaseService.instance.setSyncBase(note.id, remoteIso);
            appliedIds.add(note.id);
            downloaded++;
            if (isConflict) {
              conflicts.add(ConflictInfo(
                  noteId: note.id, title: note.title, remoteWon: true));
            }
          } else if (isConflict) {
            // Lokale Fassung ist neuer -> sie wird gleich gepusht und
            // überschreibt die fremde. Die liegt bereits in der Historie.
            conflicts.add(ConflictInfo(
                noteId: note.id, title: local.title, remoteWon: false));
          }
        } catch (_) {}
      }

      // ---- PULL: Tombstones (Löschungen von anderen Geräten) ----
      final remoteTombs =
          await _listFiles(tombFolderId, modifiedAfter: lastRemoteSync);
      for (final f in remoteTombs) {
        maxSeen = _laterOf(maxSeen, f.modifiedTime);
        final content = await _downloadFile(f.id!);
        if (content == null) continue;
        try {
          final t = jsonDecode(content) as Map<String, dynamic>;
          final id = t['id'] as String;
          final deletedAt = DateTime.parse(t['deletedAt'] as String);
          final local = await DatabaseService.instance.getNoteById(id);
          if (local != null && deletedAt.isAfter(local.modifiedAt)) {
            await DatabaseService.instance.applyRemoteDeletion(id);
            appliedIds.add(id);
            downloaded++;
          }
        } catch (_) {}
      }

      // ---- PUSH: lokal geänderte Notizen (frischen Stand hochladen) ----
      for (final id in localChangedIds) {
        if (appliedIds.contains(id)) continue; // gerade von Remote übernommen
        final note = await DatabaseService.instance.getNoteById(id);
        if (note == null) continue; // zwischenzeitlich gelöscht
        // Basis dieser Änderung mitschicken: auf welchem Stand sie aufsetzt.
        // Damit erkennt das ANDERE Gerät, ob seine Fassung dabei übersprungen
        // wurde – es sieht sonst nur „neuere Datei" und merkt den Verlust nicht.
        final basedOn = await DatabaseService.instance.getSyncBase(note.id);
        final mt = await _putFile(notesFolderId, '${note.id}.json',
            jsonEncode(_notePayload(note, basedOn)));
        maxSeen = _laterOf(maxSeen, mt);
        // Serverzeit dieses Schreibvorgangs -> Uhr-Versatz nachführen.
        await _updateClockOffset(prefs, mt);
        await _writeHistorySnapshot(historyFolderId, note);
        // Hochgeladener Stand ist ab jetzt der gemeinsame Stand mit Drive.
        await DatabaseService.instance
            .setSyncBase(note.id, note.modifiedAt.toIso8601String());
        uploaded++;
      }

      // ---- PUSH: lokale Löschungen -> Tombstones ----
      for (final d in pendingDeletions) {
        final id = d['id'] as String;
        final deletedAt = d['deletedAt'] as String;
        final snapshot = d['snapshot'] as String?;
        final mt = await _putFile(
          tombFolderId,
          '$id.json',
          jsonEncode({'id': id, 'deletedAt': deletedAt}),
        );
        maxSeen = _laterOf(maxSeen, mt);
        await _deleteFileByName(notesFolderId, '$id.json');
        if (snapshot != null) {
          try {
            final note =
                Note.fromJson(jsonDecode(snapshot) as Map<String, dynamic>);
            await _writeHistorySnapshot(historyFolderId, note, deleted: true);
          } catch (_) {}
        }
        await DatabaseService.instance.clearDeletion(id);
        uploaded++;
      }

      // ---- Ordnerliste abgleichen (leere/Reihenfolge-Ordner) ----
      await _syncFolderList(rootId);

      // ---- Historie kürzen (nur wenn sich etwas getan hat) ----
      if (uploaded > 0 || downloaded > 0) {
        await _pruneHistory(historyFolderId, tombFolderId);
      }

      // Konflikte dauerhaft vermerken – aus JEDEM Sync-Pfad (auch Sticky-
      // Fenster, Hintergrund-Isolate, manueller Sync). Die Notizliste zeigt sie
      // beim nächsten Blick als Hinweis; ein reiner Speicher-Merker ginge beim
      // Wechsel in den Hintergrund verloren (siehe ConflictStore).
      if (conflicts.isNotEmpty) {
        await ConflictStore.add([
          for (final c in conflicts)
            PendingConflict(
              noteId: c.noteId,
              title: c.title,
              remoteWon: c.remoteWon,
              detectedAt: DateTime.now(),
            ),
        ]);
        debugPrint('Sync-Konflikte erkannt: ${conflicts.length}');
      }

      // Zeitstempel fortschreiben: Start-Watermark verwenden, damit während des
      // Syncs gespeicherte Änderungen im nächsten Lauf erfasst werden.
      await prefs.setString(_lastSyncKey, localSyncStart.toIso8601String());
      if (maxSeen != null) {
        await prefs.setString(
            _lastRemoteSyncKey, maxSeen.toUtc().toIso8601String());
      }

      return SyncResult(
        success: true,
        message: 'Synchronisierung erfolgreich',
        uploadedCount: uploaded,
        downloadedCount: downloaded,
        conflicts: conflicts,
      );
    } catch (e) {
      debugPrint('Sync Fehler: $e');
      if (_isAuthError(e)) {
        // Mobil: meist nur ein abgelaufenes ~1-h-Access-Token. Still erneuern und
        // EINMAL neu versuchen, statt den Nutzer sichtbar auszuloggen.
        if (allowAuthRetry && !_isDesktop && await _refreshMobileToken()) {
          return _doSynchronize(allowAuthRetry: false);
        }
        await _handleAuthFailure();
        return SyncResult(
            success: false,
            message: 'Anmeldung abgelaufen – bitte in den Einstellungen neu anmelden');
      }
      return SyncResult(
          success: false, message: 'Synchronisierung fehlgeschlagen: $e');
    }
  }

  // ---- Ordnerliste-Abgleich ----

  /// Ordnerliste (explizit angelegte Ordner, inkl. leerer) über die kleine
  /// Drive-Datei `folders.json` abgleichen – last-write-wins über den Zeitstempel
  /// [_foldersModifiedKey]. Ohne das erscheinen leere Ordner nie auf anderen
  /// Geräten. Läuft NICHT in Sticky-/Sekundärprozessen: die verwalten keine
  /// Ordner und dürfen die settings.json der Hauptapp nicht schreiben
  /// (SettingsStore-Invariante, s. CLAUDE.md).
  Future<void> _syncFolderList(String rootId) async {
    if (isSecondaryProcess) return;
    try {
      // Lokalen Stand frisch lesen. Mobil reload() (auch Hintergrund-Isolate-
      // Sicht; per-Key-Store, unkritisch); Desktop load() – dort ist die Hauptapp
      // einziger Schreiber, ein reload() würde nur mit eigenen Writes konkurrieren.
      if (!_isDesktop) {
        await SettingsStore.reload();
      } else {
        await SettingsStore.load();
      }
      final localRaw = SettingsStore.getString(_foldersKey);
      final localList = _parseFolderList(localRaw);
      final localTsRaw = SettingsStore.getString(_foldersModifiedKey);
      var localTs = DateTime.tryParse(localTsRaw ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      // Ordner aus einer Version VOR diesem Feature haben noch keinen Zeitstempel.
      final neverStamped = localTsRaw == null;

      // Remote lesen
      List<String>? remoteList;
      DateTime? remoteTs;
      final fileId = await _findFile(rootId, _foldersFileName);
      if (fileId != null) {
        final content = await _downloadFile(fileId);
        if (content != null) {
          try {
            final m = jsonDecode(content) as Map<String, dynamic>;
            final fl = m['folders'];
            if (fl is List) {
              remoteList = fl
                  .map((e) => e.toString())
                  .where((e) => e.isNotEmpty)
                  .toList();
            }
            remoteTs =
                DateTime.tryParse(m['modifiedAt'] as String? ?? '')?.toUtc();
          } catch (_) {}
        }
      }

      // Übergang (einmalig pro Gerät): lokale Alt-Ordner ohne Zeitstempel.
      if (neverStamped && localList.isNotEmpty) {
        final now = DateTime.now().toUtc();
        // Existiert schon eine Remote-Liste, VEREINEN – so gehen weder lokale noch
        // fremde (leere) Alt-Ordner verloren, egal welches Gerät zuerst synct.
        final merged = remoteList == null
            ? localList
            : <String>{...remoteList, ...localList}.toList();
        await SettingsStore.setString(_foldersKey, jsonEncode(merged));
        await SettingsStore.setString(
            _foldersModifiedKey, now.toIso8601String());
        await _putFile(
            rootId,
            _foldersFileName,
            jsonEncode({'folders': merged, 'modifiedAt': now.toIso8601String()}));
        return;
      }

      if (remoteList != null && remoteTs != null && remoteTs.isAfter(localTs)) {
        // Remote neuer -> lokal übernehmen (mit dem REMOTE-Zeitstempel, nicht now).
        await SettingsStore.setString(_foldersKey, jsonEncode(remoteList));
        await SettingsStore.setString(
            _foldersModifiedKey, remoteTs.toIso8601String());
      } else if (localRaw != null &&
          (remoteTs == null || localTs.isAfter(remoteTs))) {
        // Lokal neuer (oder Remote fehlt) -> hochladen.
        await _putFile(
            rootId,
            _foldersFileName,
            jsonEncode({
              'folders': localList,
              'modifiedAt': localTs.toIso8601String(),
            }));
      }
    } catch (e) {
      debugPrint('Ordnerliste-Sync Fehler: $e');
    }
  }

  List<String> _parseFolderList(String? raw) {
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return <String>[];
  }

  // ---- Gelöschte Notizen (Papierkorb) ----

  /// Aktuell gelöschte Notizen geräteübergreifend aus dem Drive-Verlauf.
  /// Quelle: Tombstones (= momentan gelöscht) + neuester history-Snapshot je
  /// Notiz (= Inhalt). Nur innerhalb der 30-Tage-Aufbewahrung verfügbar; danach
  /// sind Tombstone und Historie weg. Wirft bei Fehlern (UI zeigt Hinweis).
  Future<List<DeletedNote>> getDeletedNotes({bool allowAuthRetry = true}) async {
    if (_driveApi == null) return [];
    try {
      final rootId = await _getOrCreateBackupFolder();
      if (rootId == null) return [];
      final tombFolderId =
          await _getOrCreateSubfolder(rootId, _tombstonesFolderName);
      final historyFolderId =
          await _getOrCreateSubfolder(rootId, _historyFolderName);
      if (tombFolderId == null || historyFolderId == null) return [];

      // Aktuell gelöschte IDs aus den Tombstone-Dateinamen (<id>.json).
      final tombs = await _listFiles(tombFolderId);
      final deletedIds = <String>{};
      for (final t in tombs) {
        final name = t.name ?? '';
        if (name.endsWith('.json')) {
          deletedIds.add(name.substring(0, name.length - 5));
        }
      }
      if (deletedIds.isEmpty) return [];

      // Neuesten history-Snapshot je gelöschter Notiz finden. Der Zeitstempel
      // steckt im Namen (<id>__<ts>__<titel>…) -> String-Sortierung reicht.
      final histFiles = await _listFiles(historyFolderId);
      final latestById = <String, drive.File>{};
      for (final f in histFiles) {
        final id = (f.name ?? '').split('__').first;
        if (!deletedIds.contains(id)) continue;
        final cur = latestById[id];
        if (cur == null || (f.name ?? '').compareTo(cur.name ?? '') > 0) {
          latestById[id] = f;
        }
      }

      final result = <DeletedNote>[];
      for (final id in deletedIds) {
        final f = latestById[id];
        if (f == null) continue; // Inhalt nicht mehr vorhanden (Historie weg)
        final content = await _downloadFile(f.id!);
        if (content == null) continue;
        try {
          final note =
              Note.fromJson(jsonDecode(content) as Map<String, dynamic>);
          // Lösch-Zeitpunkt ≈ Upload-Zeit des Snapshots.
          final deletedAt = f.modifiedTime ?? note.modifiedAt;
          result.add(DeletedNote(note: note, deletedAt: deletedAt));
        } catch (_) {}
      }
      result.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
      return result;
    } catch (e) {
      debugPrint('Gelöschte Notizen laden Fehler: $e');
      if (_isAuthError(e)) {
        if (allowAuthRetry && !_isDesktop && await _refreshMobileToken()) {
          return getDeletedNotes(allowAuthRetry: false);
        }
        await _handleAuthFailure();
      }
      rethrow;
    }
  }

  /// Wiederherstellen auf Drive: Tombstone entfernen und den (frischen) Stand
  /// als notes/<id>.json hochladen, damit der nächste Sync die Notiz nicht
  /// erneut löscht. Der lokale DB-Eintrag wird vom Provider angelegt.
  Future<bool> restoreDeletedNoteRemote(Note note) async {
    if (_driveApi == null) return false;
    try {
      final rootId = await _getOrCreateBackupFolder();
      if (rootId == null) return false;
      final notesFolderId =
          await _getOrCreateSubfolder(rootId, _notesFolderName);
      final tombFolderId =
          await _getOrCreateSubfolder(rootId, _tombstonesFolderName);
      if (notesFolderId == null || tombFolderId == null) return false;
      await _deleteFileByName(tombFolderId, '${note.id}.json');
      await _putFile(
          notesFolderId, '${note.id}.json', jsonEncode(_notePayload(note, null)));
      await DatabaseService.instance
          .setSyncBase(note.id, note.modifiedAt.toIso8601String());
      return true;
    } catch (e) {
      debugPrint('Wiederherstellen (Drive) Fehler: $e');
      return false;
    }
  }

  // ---- Drive-Helfer ----

  Future<String?> _getOrCreateSubfolder(String parentId, String name) async {
    if (_driveApi == null) return null;
    try {
      final list = await _driveApi!.files.list(
        q: "name='$name' and '$parentId' in parents and "
            "mimeType='application/vnd.google-apps.folder' and trashed=false",
        spaces: 'drive',
        $fields: 'files(id)',
      );
      if (list.files != null && list.files!.isNotEmpty) {
        return list.files!.first.id;
      }
      final folder = drive.File()
        ..name = name
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = [parentId];
      final created = await _driveApi!.files.create(folder, $fields: 'id');
      return created.id;
    } catch (e) {
      debugPrint('Unterordner "$name" Fehler: $e');
      rethrow;
    }
  }

  Future<List<drive.File>> _listFiles(String folderId,
      {String? modifiedAfter, String? nameContains}) async {
    final files = <drive.File>[];
    var query = "'$folderId' in parents and trashed=false";
    if (modifiedAfter != null) {
      query += " and modifiedTime > '$modifiedAfter'";
    }
    if (nameContains != null) {
      // Vorfiltern auf dem Server – der Historie-Ordner enthält die Snapshots
      // ALLER Notizen, die will man für eine einzelne nicht komplett laden.
      query += " and name contains '$nameContains'";
    }
    String? pageToken;
    do {
      final res = await _driveApi!.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'nextPageToken, files(id,name,modifiedTime)',
        pageSize: 1000,
        pageToken: pageToken,
      );
      if (res.files != null) files.addAll(res.files!);
      pageToken = res.nextPageToken;
    } while (pageToken != null);
    return files;
  }

  Future<String?> _findFile(String folderId, String name) async {
    final res = await _driveApi!.files.list(
      q: "name='$name' and '$folderId' in parents and trashed=false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    if (res.files != null && res.files!.isNotEmpty) return res.files!.first.id;
    return null;
  }

  Future<String?> _downloadFile(String fileId) async {
    try {
      final media = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      final bytes = <int>[];
      // Stillstands-Timeout pro Chunk: bricht ab, wenn der Body mitten im
      // Download hängt (Antwort-Header kamen, aber keine weiteren Daten mehr).
      await for (final chunk in media.stream.timeout(_netTimeout)) {
        bytes.addAll(chunk);
      }
      return utf8.decode(bytes);
    } catch (e) {
      debugPrint('Download-Fehler ($fileId): $e');
      return null;
    }
  }

  // Datei anlegen/aktualisieren; gibt die Drive-modifiedTime zurück.
  Future<DateTime?> _putFile(
      String folderId, String name, String content) async {
    final bytes = utf8.encode(content);
    final media = drive.Media(Stream.value(bytes), bytes.length);
    final existingId = await _findFile(folderId, name);
    drive.File result;
    if (existingId != null) {
      result = await _driveApi!.files.update(
        drive.File()..name = name,
        existingId,
        uploadMedia: media,
        $fields: 'id,modifiedTime',
      );
    } else {
      result = await _driveApi!.files.create(
        drive.File()
          ..name = name
          ..parents = [folderId],
        uploadMedia: media,
        $fields: 'id,modifiedTime',
      );
    }
    return result.modifiedTime;
  }

  // Datei nur anlegen (für eindeutig benannte Historie-Snapshots).
  Future<void> _createFile(
      String folderId, String name, String content) async {
    final bytes = utf8.encode(content);
    await _driveApi!.files.create(
      drive.File()
        ..name = name
        ..parents = [folderId],
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
      $fields: 'id',
    );
  }

  Future<void> _deleteFileByName(String folderId, String name) async {
    final id = await _findFile(folderId, name);
    if (id != null) await _safeDelete(id);
  }

  Future<void> _safeDelete(String fileId) async {
    try {
      await _driveApi!.files.delete(fileId);
    } catch (e) {
      debugPrint('Löschen ($fileId) Fehler: $e');
    }
  }

  DateTime? _laterOf(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return b.isAfter(a) ? b : a;
  }

  // ---- Historie ----

  // ---- Zeitvergleich (Geräte-Uhr vs. Drive-Serverzeit) ----

  /// Gemessener Versatz zwischen dieser Geräte-Uhr und der Drive-Serverzeit
  /// (`serverzeit - gerätezeit`), gespeichert in den Prefs.
  ///
  /// Warum: Welche Fassung beim Sync gewinnt, entscheidet `modifiedAt` – und
  /// das ist die Uhr des jeweiligen GERÄTS. Geht eine Uhr falsch, gewinnt
  /// systematisch das falsche Gerät, ohne dass irgendwo ein Fehler auftaucht.
  /// Beim Hochladen liefert Drive die Serverzeit der Datei zurück; damit lässt
  /// sich der Versatz messen und beim Vergleich herausrechnen.
  static const String _clockOffsetKey = 'drive_clock_offset_seconds';

  /// Ab diesem Versatz wird korrigiert. Kleine Abweichungen (normale
  /// Ungenauigkeit, Laufzeit des Uploads) bleiben bewusst unangetastet, damit
  /// sich am eingespielten Verhalten nichts ändert.
  static const int _clockOffsetThresholdSeconds = 60;

  Duration _clockOffset = Duration.zero;

  Future<void> _loadClockOffset(SharedPreferences prefs) async {
    final s = prefs.getInt(_clockOffsetKey) ?? 0;
    _clockOffset = Duration(seconds: s);
  }

  /// Versatz aus einer frisch von Drive zurückgemeldeten Schreibzeit ableiten.
  Future<void> _updateClockOffset(
      SharedPreferences prefs, DateTime? serverTime) async {
    if (serverTime == null) return;
    final offset = serverTime.toUtc().difference(DateTime.now().toUtc());
    if (offset.abs() < const Duration(seconds: _clockOffsetThresholdSeconds)) {
      if (_clockOffset != Duration.zero) {
        _clockOffset = Duration.zero;
        await prefs.setInt(_clockOffsetKey, 0);
      }
      return;
    }
    _clockOffset = offset;
    await prefs.setInt(_clockOffsetKey, offset.inSeconds);
    debugPrint('Uhr-Versatz zur Drive-Serverzeit: ${offset.inSeconds}s');
  }

  /// Ist die Remote-Fassung neuer als die lokale?
  ///
  /// Für die Remote-Seite zählt die **Drive-Serverzeit** der Datei, wenn sie
  /// vorliegt – die stammt von Google und nicht von einer möglicherweise falsch
  /// gehenden Geräte-Uhr. Die lokale Zeit wird um den gemessenen Versatz
  /// korrigiert, damit beide in derselben Zeitbasis verglichen werden.
  /// Ohne gemessenen Versatz (Normalfall) verhält sich das exakt wie bisher.
  bool _isRemoteNewer(Note remote, Note local, DateTime? remoteServerTime) {
    if (_clockOffset == Duration.zero || remoteServerTime == null) {
      return remote.modifiedAt.isAfter(local.modifiedAt);
    }
    final localInServerTime = local.modifiedAt.toUtc().add(_clockOffset);
    return remoteServerTime.toUtc().isAfter(localInServerTime);
  }

  /// Notiz-JSON für `notes/<id>.json` inkl. Basis-Stand der Änderung.
  Map<String, dynamic> _notePayload(Note note, String? basedOn) => {
        ...note.toJson(),
        if (basedOn != null) _basedOnKey: basedOn,
      };

  /// Geht bei diesem Zusammenführen eine Änderung VERLOREN?
  ///
  /// Nur dann ist es ein Konflikt, über den gewarnt werden muss. Alle Zeiten
  /// sind `modifiedAt`-Zeitstempel (ISO) und identifizieren damit eindeutig
  /// eine Fassung der Notiz:
  /// - [base]: Fassung, die dieses Gerät zuletzt mit Drive ausgetauscht hat
  ///   (gemeinsamer Vorfahre, siehe `DatabaseService.getSyncBase`).
  /// - [local]: aktueller lokaler Stand.
  /// - [remote]: Stand, der jetzt von Drive kommt.
  /// - [remoteBasedOn]: Fassung, auf der die fremde Änderung aufsetzt.
  ///
  /// Fälle:
  /// 1. `remote == base` → die Drive-Datei ist genau die, die wir schon kennen
  ///    (typisch: unser EIGENER letzter Upload taucht erneut in der Liste auf).
  ///    Nichts geht verloren, egal wie oft lokal geändert wurde.
  /// 2. Beide Seiten haben sich seit [base] geändert → eine der beiden Fassungen
  ///    wird überschrieben → echter Konflikt.
  /// 3. Nur die fremde Seite hat sich geändert → normalerweise sauberes
  ///    Nachziehen. AUSNAHME: die fremde Änderung setzt auf einer ÄLTEREN
  ///    Fassung auf als unserer Basis – dann hat das andere Gerät unseren
  ///    zwischenzeitlich hochgeladenen Stand übersprungen und überschreibt ihn.
  static bool isSkippedChange({
    required String base,
    required String local,
    required String remote,
    String? remoteBasedOn,
  }) {
    if (remote == base) return false; // Fall 1
    if (local != base) return true; // Fall 2
    // Fall 3
    if (remoteBasedOn == null || remoteBasedOn == base) return false;
    final parent = DateTime.tryParse(remoteBasedOn);
    final ours = DateTime.tryParse(base);
    if (parent == null || ours == null) return false;
    // Nur älter = übersprungen. Neuer heißt bloß, dass wir Zwischenstände nie
    // gesehen haben (Drive hält pro Notiz nur die jüngste Datei) – dabei geht
    // nichts von UNS verloren.
    return parent.isBefore(ours);
  }

  Future<void> _writeHistorySnapshot(String historyFolderId, Note note,
      {bool deleted = false}) async {
    // Dateiname: <id>__<zeitstempel>__<titel>__<gerät>[__geloescht].json
    // (id vorne = leicht gruppierbar; das Gerät steht seit 1.30.1 dabei, damit
    // im Versionsverlauf erkennbar ist, von welchem Gerät ein Stand kommt.
    // Ältere Snapshots haben den Teil nicht – das Parsen kommt damit klar.)
    final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final safeTitle = _sanitizeTitle(note.title.isEmpty ? 'Notiz' : note.title);
    final device = _sanitizeTitle(await DeviceInfoService.describe());
    final marker = deleted ? '__geloescht' : '';
    final name = '${note.id}__${ts}__${safeTitle}__$device$marker.json';
    await _createFile(historyFolderId, name, jsonEncode(note.toJson()));
  }

  String _sanitizeTitle(String title) {
    return title
        .replaceAll(RegExp(r'[\\/:*?"<>|_]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // Pro Notiz die neuesten N behalten; gelöschte Notizen nach Ablauf entsorgen.
  Future<void> _pruneHistory(
      String historyFolderId, String tombFolderId) async {
    final files = await _listFiles(historyFolderId);
    final byId = <String, List<drive.File>>{};
    for (final f in files) {
      final id = (f.name ?? '').split('__').first;
      byId.putIfAbsent(id, () => []).add(f);
    }

    // Tombstones -> deletedAt je Notiz
    final tombs = await _listFiles(tombFolderId);
    final deletedAtById = <String, DateTime>{};
    final tombIdToFile = <String, String>{};
    for (final t in tombs) {
      final content = await _downloadFile(t.id!);
      if (content == null) continue;
      try {
        final m = jsonDecode(content) as Map<String, dynamic>;
        deletedAtById[m['id'] as String] =
            DateTime.parse(m['deletedAt'] as String);
        tombIdToFile[m['id'] as String] = t.id!;
      } catch (_) {}
    }

    final now = DateTime.now();
    for (final entry in byId.entries) {
      final id = entry.key;
      final list = entry.value;
      final deletedAt = deletedAtById[id];

      // Gelöscht und Aufbewahrung abgelaufen -> komplette Historie + Tombstone weg
      if (deletedAt != null &&
          now.difference(deletedAt).inDays >= _deletedRetentionDays) {
        for (final f in list) {
          await _safeDelete(f.id!);
        }
        final tombFileId = tombIdToFile[id];
        if (tombFileId != null) await _safeDelete(tombFileId);
        continue;
      }

      // Sonst: neueste _historyPerNote behalten (Zeitstempel steckt im Namen)
      list.sort((a, b) => (b.name ?? '').compareTo(a.name ?? ''));
      for (var i = _historyPerNote; i < list.length; i++) {
        await _safeDelete(list[i].id!);
      }
    }
  }

  // ---- Versionsverlauf einer Notiz ----

  /// Alle in Drive vorhandenen Stände einer Notiz, neueste zuerst.
  ///
  /// Quelle sind die ohnehin geschriebenen Snapshots im Ordner `history/`
  /// (Dateiname `<id>__<zeitstempel>__<titel>.json`, pro Notiz die neuesten 30).
  /// Damit lässt sich ein Stand zurückholen, der vom Abgleich überschrieben
  /// wurde – etwa nach einem gemeldeten Konflikt.
  Future<List<NoteVersion>> getNoteVersions(String noteId) async {
    if (_driveApi == null) return [];
    final rootId = await _getOrCreateBackupFolder();
    if (rootId == null) return [];
    final historyFolderId =
        await _getOrCreateSubfolder(rootId, _historyFolderName);
    if (historyFolderId == null) return [];

    final files = await _listFiles(historyFolderId, nameContains: noteId);
    final versions = <NoteVersion>[];
    for (final f in files) {
      final name = f.name ?? '';
      if (!name.startsWith('${noteId}__')) continue;
      versions.add(NoteVersion.fromFileName(
        name,
        fileId: f.id!,
        fallbackTime: f.modifiedTime,
      ));
    }
    versions.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return versions;
  }

  /// Den Inhalt eines Standes laden (zum Anzeigen bzw. Wiederherstellen).
  Future<Note?> loadNoteVersion(String fileId) async {
    final content = await _downloadFile(fileId);
    if (content == null) return null;
    try {
      return Note.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Version laden fehlgeschlagen: $e');
      return null;
    }
  }

  // ---- Migration vom alten Gesamt-Backup ----

  Future<void> _migrateLegacyIfNeeded(String rootId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedKey) == true) return;
    await _importLegacyBackup(rootId);
    await prefs.setBool(_migratedKey, true);
  }

  Future<void> _importLegacyBackup(String rootId) async {
    try {
      final fileId = await _findFile(rootId, _backupFileName);
      if (fileId == null) return;
      final content = await _downloadFile(fileId);
      if (content == null) return;
      final data = jsonDecode(content) as Map<String, dynamic>;
      final notesJson = data['notes'] as List<dynamic>?;
      if (notesJson == null) return;
      for (final j in notesJson) {
        final note = Note.fromJson(j as Map<String, dynamic>);
        final local = await DatabaseService.instance.getNoteById(note.id);
        // Nur einspielen, wenn lokal fehlend oder Backup-Version neuer ist.
        if (local == null || note.modifiedAt.isAfter(local.modifiedAt)) {
          await DatabaseService.instance.insertOrUpdateNotes([note]);
        }
      }
    } catch (e) {
      debugPrint('Alt-Backup-Import Fehler: $e');
    }
  }

  // Letzten Sync-Zeitpunkt abrufen
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncString = prefs.getString(_lastSyncKey);
    return lastSyncString != null ? DateTime.parse(lastSyncString) : null;
  }
}

class SyncResult {
  final bool success;
  final String message;
  final int uploadedCount;
  final int downloadedCount;
  /// Notizen, die seit dem letzten Abgleich auf BEIDEN Seiten geändert wurden.
  /// Eine der beiden Fassungen hat dabei verloren (last-write-wins) – beide
  /// liegen aber im Versionsverlauf. Die UI warnt daraufhin.
  final List<ConflictInfo> conflicts;

  SyncResult({
    required this.success,
    required this.message,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
    this.conflicts = const [],
  });
}

/// Ein erkannter Sync-Konflikt: dieselbe Notiz wurde seit dem letzten Abgleich
/// hier UND auf einem anderen Gerät geändert.
class ConflictInfo {
  final String noteId;
  final String title;
  /// true = die Fassung des anderen Geräts hat gewonnen (die lokale wurde
  /// ersetzt), false = die lokale Fassung hat gewonnen.
  final bool remoteWon;

  ConflictInfo({
    required this.noteId,
    required this.title,
    required this.remoteWon,
  });
}

/// Ein Stand aus dem Versionsverlauf einer Notiz (Drive-Ordner `history/`).
class NoteVersion {
  final String fileId;
  /// Zeitpunkt des Snapshots (aus dem Dateinamen; sonst die Drive-Zeit).
  final DateTime savedAt;
  /// Titel, den die Notiz zu diesem Zeitpunkt hatte.
  final String title;
  /// Von welchem Gerät der Stand stammt („Windows - ANDI-PC", „Android - …").
  /// Leer bei Snapshots aus Versionen vor 1.30.1.
  final String device;
  /// Snapshot einer gelöschten Notiz.
  final bool deleted;

  NoteVersion({
    required this.fileId,
    required this.savedAt,
    required this.title,
    this.device = '',
    this.deleted = false,
  });

  /// Aus dem Dateinamen der Historie lesen:
  /// `<id>__<zeitstempel>__<titel>[__<gerät>][__geloescht].json`.
  ///
  /// Der Zeitstempel steht mit `-` statt `:` in der Uhrzeit (Doppelpunkte sind
  /// in Dateinamen nicht erlaubt) und wird hier zurückgedreht. Lässt er sich
  /// nicht lesen, gilt [fallbackTime] (die Drive-Zeit der Datei).
  ///
  /// Das Geräte-Feld gibt es erst seit 1.30.1 – ältere Snapshots haben nur drei
  /// Teile (bzw. vier, wenn sie eine Löschung markieren). Deshalb wird der
  /// vierte Teil nur dann als Gerät gelesen, wenn er nicht die Löschmarkierung
  /// ist.
  factory NoteVersion.fromFileName(
    String name, {
    required String fileId,
    DateTime? fallbackTime,
  }) {
    final parts = name.replaceAll('.json', '').split('__');
    DateTime? saved;
    if (parts.length >= 2) {
      // 2026-08-04T18-30-00.000Z -> 2026-08-04T18:30:00.000Z
      final fixed = parts[1].replaceFirstMapped(
        RegExp(r'T(\d{2})-(\d{2})-(\d{2})'),
        (m) => 'T${m[1]}:${m[2]}:${m[3]}',
      );
      saved = DateTime.tryParse(fixed)?.toLocal();
    }
    final title = parts.length >= 3 ? parts[2].trim() : '';
    var device = '';
    if (parts.length >= 4 && parts[3].trim() != 'geloescht') {
      device = parts[3].trim();
    }
    return NoteVersion(
      fileId: fileId,
      savedAt: saved ?? fallbackTime?.toLocal() ?? DateTime.now(),
      title: title,
      device: device,
      deleted: parts.contains('geloescht'),
    );
  }
}

/// Eine gelöschte Notiz aus dem Drive-Verlauf: letzter bekannter Stand + wann
/// sie gelöscht wurde.
class DeletedNote {
  final Note note;
  final DateTime deletedAt;

  DeletedNote({required this.note, required this.deletedAt});
}
