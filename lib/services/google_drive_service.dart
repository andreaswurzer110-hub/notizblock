import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/note.dart';
import 'database_service.dart';
import 'google_drive_config.dart';

/// HTTP-Client, der feste Auth-Header anhängt (für google_sign_in auf Mobil).
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleDriveService {
  static const String _folderName = 'Notizblock Backup';
  static const String _backupFileName = 'notizblock_backup.json';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _lastRemoteSyncKey = 'last_remote_sync_time';
  static const String _migratedKey = 'delta_migrated';
  static const String _credentialsKey = 'drive_desktop_credentials';

  // Unterordner im Backup-Ordner
  static const String _notesFolderName = 'notes';
  static const String _tombstonesFolderName = 'tombstones';
  static const String _historyFolderName = 'history';

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
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_credentialsKey);
    } else {
      await _googleSignIn.signOut();
      _mobileUser = null;
    }
    _authClient?.close();
    _authClient = null;
    _driveApi = null;
    _userEmail = null;
    _userName = null;
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_credentialsKey);
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
  }

  // --- Mobil (Android/iOS) via google_sign_in ---
  Future<bool> _mobileSignIn({required bool silent}) async {
    _mobileUser = silent
        ? await _googleSignIn.signInSilently()
        : await _googleSignIn.signIn();
    if (_mobileUser == null) return false;

    final authHeaders = await _mobileUser!.authHeaders;
    _authClient = GoogleAuthClient(authHeaders);
    _userEmail = _mobileUser!.email;
    _userName = _mobileUser!.displayName ?? _mobileUser!.email;
    _driveApi = drive.DriveApi(_authClient!);
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
    final prefs = await SharedPreferences.getInstance();

    // 1) Gespeicherte Credentials → stiller Login ohne Browser
    final stored = prefs.getString(_credentialsKey);
    if (stored != null) {
      try {
        final credentials = auth.AccessCredentials.fromJson(
          jsonDecode(stored) as Map<String, dynamic>,
        );
        final client =
            auth.autoRefreshingClient(clientId, credentials, http.Client());
        client.credentialUpdates.listen(_saveCredentials);
        await _finishDesktopSignIn(client);
        return true;
      } catch (e) {
        debugPrint('Gespeicherte Credentials ungültig, neu anmelden: $e');
        await prefs.remove(_credentialsKey);
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
  }

  Future<void> _saveCredentials(auth.AccessCredentials credentials) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_credentialsKey, jsonEncode(credentials.toJson()));
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
  Future<bool> createBackup() async {
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
          jsonEncode(note.toJson()),
        );
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
      if (_isAuthError(e)) await _handleAuthFailure();
      return false;
    }
  }

  // Voll-Wiederherstellung: alle per-Notiz-Dateien (und ggf. Alt-Backup) laden.
  Future<bool> restoreBackup() async {
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
        } catch (_) {}
      }

      return true;
    } catch (e) {
      debugPrint('Wiederherstellung Fehler: $e');
      if (_isAuthError(e)) await _handleAuthFailure();
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

  Future<SyncResult> _doSynchronize() async {
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
          final note =
              Note.fromJson(jsonDecode(content) as Map<String, dynamic>);
          final local = await DatabaseService.instance.getNoteById(note.id);
          if (local == null || note.modifiedAt.isAfter(local.modifiedAt)) {
            await DatabaseService.instance.insertOrUpdateNotes([note]);
            appliedIds.add(note.id);
            downloaded++;
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
        final mt = await _putFile(
            notesFolderId, '${note.id}.json', jsonEncode(note.toJson()));
        maxSeen = _laterOf(maxSeen, mt);
        await _writeHistorySnapshot(historyFolderId, note);
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

      // ---- Historie kürzen (nur wenn sich etwas getan hat) ----
      if (uploaded > 0 || downloaded > 0) {
        await _pruneHistory(historyFolderId, tombFolderId);
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
      );
    } catch (e) {
      debugPrint('Sync Fehler: $e');
      if (_isAuthError(e)) {
        await _handleAuthFailure();
        return SyncResult(
            success: false,
            message: 'Anmeldung abgelaufen – bitte in den Einstellungen neu anmelden');
      }
      return SyncResult(
          success: false, message: 'Synchronisierung fehlgeschlagen: $e');
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
      {String? modifiedAfter}) async {
    final files = <drive.File>[];
    var query = "'$folderId' in parents and trashed=false";
    if (modifiedAfter != null) {
      query += " and modifiedTime > '$modifiedAfter'";
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
      await for (final chunk in media.stream) {
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

  Future<void> _writeHistorySnapshot(String historyFolderId, Note note,
      {bool deleted = false}) async {
    // Dateiname: <id>__<zeitstempel>__<titel>.json  (id vorne = leicht gruppierbar)
    final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final safeTitle = _sanitizeTitle(note.title.isEmpty ? 'Notiz' : note.title);
    final marker = deleted ? '__geloescht' : '';
    final name = '${note.id}__${ts}__$safeTitle$marker.json';
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

  SyncResult({
    required this.success,
    required this.message,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
  });
}
