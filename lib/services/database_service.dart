import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/note.dart';
import 'widget_service.dart';

class DatabaseService {
  static Database? _database;
  static String? _databasePath;
  static const String _databaseName = 'notizblock.db';
  static const int _databaseVersion = 5;

  // Singleton Pattern
  DatabaseService._privateConstructor();
  static final DatabaseService instance = DatabaseService._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final bool isDesktop = Platform.isWindows || Platform.isLinux;

    // FFI für Desktop-Plattformen initialisieren
    if (isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Speicherort: Desktop -> App-Support (%APPDATA%\…\notizblock bzw.
    // ~/.local/share/…), wo auch die Sticky-State-Dateien liegen. Android/iOS
    // bleiben im Dokumente-Ordner, weil das Home-Widget die notes.json dort liest.
    final Directory baseDir = isDesktop
        ? await getApplicationSupportDirectory()
        : await getApplicationDocumentsDirectory();
    final String path = join(baseDir.path, _databaseName);

    // Einmalige Migration: früher lag die DB auf Desktop im Dokumente-Ordner.
    if (isDesktop) {
      await _migrateDbFromDocuments(path);
    }

    _databasePath = path;

    return await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Läuft bei JEDEM Verbindungsaufbau (in jedem Prozess) – vor dem Versions-
  /// Check (`PRAGMA user_version`). Auf Desktop teilen sich Hauptapp UND jedes
  /// Sticky-Note-Fenster (eigene Prozesse) dieselbe DB-Datei; auf Android öffnet
  /// zusätzlich das Background-Sync-Isolate eine eigene Verbindung.
  ///
  /// Ohne diese Pragmas liefert SQLite bei Lock-Kollision SOFORT „database is
  /// locked" (SQLITE_BUSY, Code 5) – z.B. wenn ein Sync gerade schreibt, während
  /// ein anderer Prozess die DB öffnet/liest (war real ein Bug: Sync hängt bei
  /// einer Notiz, paralleler Sync im Hauptmenü scheitert mit „database is locked"
  /// schon beim `PRAGMA user_version`).
  Future<void> _onConfigure(Database db) async {
    // WICHTIG – rawQuery, NICHT execute: Beide PRAGMAs LIEFERN einen Wert zurück
    // (busy_timeout den gesetzten Wert, journal_mode den neuen Modus). Androids
    // SQLite weist sie über execute()/execSQL() ab ("Queries can be performed
    // using SQLiteDatabase query or rawQuery methods only.") → die DB ließ sich
    // auf Android gar nicht mehr öffnen: keine Notizen, jeder Sync scheiterte
    // schon beim Öffnen (war real ein Bug 1.25.7.1–1.25.9.1, nur auf Windows
    // getestet). rawQuery FÜHRT das Statement genauso aus (setzt den Wert) und
    // funktioniert auf ALLEN Plattformen (Android + Desktop-ffi). NICHT zurück
    // auf execute ändern.
    // Bei belegter Sperre bis zu 5 s warten statt sofort zu scheitern. MUSS pro
    // Verbindung gesetzt werden (nicht persistent) → daher hier.
    await db.rawQuery('PRAGMA busy_timeout = 5000');
    // WAL: nebenläufige Leser blockieren den Schreiber nicht mehr und umgekehrt
    // (prozessübergreifend). Einmal gesetzt, bleibt der Modus in der Datei. Muss
    // NACH busy_timeout kommen, damit der Moduswechsel selbst ggf. warten kann.
    await db.rawQuery('PRAGMA journal_mode = WAL');
  }

  /// Verschiebt eine alte DB aus dem Dokumente-Ordner an den neuen Ort
  /// (App-Support), falls dort noch keine existiert. Inkl. WAL/SHM/Journal,
  /// damit keine ungeschriebenen Transaktionen verloren gehen. Idempotent und
  /// fehlertolerant (mehrere Sticky-Prozesse können das parallel versuchen).
  Future<void> _migrateDbFromDocuments(String newPath) async {
    try {
      if (await File(newPath).exists()) return; // schon am neuen Ort
      final docs = await getApplicationDocumentsDirectory();
      final oldPath = join(docs.path, _databaseName);
      if (!await File(oldPath).exists()) return; // nichts zu migrieren

      for (final suffix in const ['', '-wal', '-shm', '-journal']) {
        final src = File('$oldPath$suffix');
        if (await src.exists()) {
          await src.copy('$newPath$suffix');
          try {
            await src.delete();
          } catch (_) {
            // Alte Datei in Benutzung -> Kopie reicht; Original bleibt liegen.
          }
        }
      }
      debugPrint('DB aus Dokumente nach App-Support migriert: $newPath');
    } catch (e) {
      debugPrint('DB-Migration übersprungen: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        modifiedAt TEXT NOT NULL,
        color TEXT NOT NULL DEFAULT '#FFFDE7',
        isPinned INTEGER NOT NULL DEFAULT 0,
        isArchived INTEGER NOT NULL DEFAULT 0,
        type TEXT NOT NULL DEFAULT 'text',
        autopoolData TEXT NOT NULL DEFAULT '',
        folder TEXT NOT NULL DEFAULT ''
      )
    ''');

    // Index für schnellere Abfragen
    await db.execute('CREATE INDEX idx_notes_modified ON notes(modifiedAt)');
    await db.execute('CREATE INDEX idx_notes_pinned ON notes(isPinned)');

    await _createDeletionsTable(db);
    await _createSyncBaseTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v2: Tabelle für ausstehende Löschungen (Tombstones für den Sync)
    if (oldVersion < 2) {
      await _createDeletionsTable(db);
    }
    // v3: Autopool-Tabellen-Notizen (Notiz-Typ + strukturierte Tabellendaten)
    if (oldVersion < 3) {
      await db.execute(
          "ALTER TABLE notes ADD COLUMN type TEXT NOT NULL DEFAULT 'text'");
      await db.execute(
          "ALTER TABLE notes ADD COLUMN autopoolData TEXT NOT NULL DEFAULT ''");
    }
    // v4: Ordner/Kategorie pro Notiz
    if (oldVersion < 4) {
      await db.execute(
          "ALTER TABLE notes ADD COLUMN folder TEXT NOT NULL DEFAULT ''");
    }
    // v5: Basis-Stand pro Notiz für die Konflikt-Erkennung
    if (oldVersion < 5) {
      await _createSyncBaseTable(db);
    }
  }

  Future<void> _createDeletionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS deletions (
        id TEXT PRIMARY KEY,
        deletedAt TEXT NOT NULL,
        snapshot TEXT
      )
    ''');
  }

  Future<void> _createSyncBaseTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_base (
        id TEXT PRIMARY KEY,
        base TEXT NOT NULL
      )
    ''');
  }

  // JSON-Datei für Widget aktualisieren
  Future<void> _updateWidgetJsonFile() async {
    if (!Platform.isAndroid) return;
    
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'notes',
        where: 'isArchived = ?',
        whereArgs: [0],
        orderBy: 'isPinned DESC, modifiedAt DESC',
      );
      final notes = List.generate(maps.length, (i) => Note.fromMap(maps[i]));
      final jsonList = notes.map((n) => n.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      // In app_flutter Ordner speichern (wo Android es lesen kann)
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/notes.json');
      await file.writeAsString(jsonString);

      // Broadcast an den Widget-Provider, damit er die frische JSON sofort
      // liest. Ohne diesen Aufruf aktualisiert sich das Homescreen-Widget erst
      // beim nächsten System-Intervall (1 h) – auch bei Remote-Sync-Änderungen,
      // die im Hauptmenü längst sichtbar sind. Zentral hier, weil ALLE
      // DB-Schreibwege (auch Delta-Sync) durch diese Methode laufen.
      await WidgetService.instance.updateWidget();

      debugPrint('Widget JSON aktualisiert: ${notes.length} Notizen');
    } catch (e) {
      debugPrint('Fehler beim Aktualisieren der Widget-JSON: $e');
    }
  }

  // CRUD Operationen

  Future<List<Note>> getAllNotes({bool includeArchived = false}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: includeArchived ? null : 'isArchived = ?',
      whereArgs: includeArchived ? null : [0],
      orderBy: 'isPinned DESC, modifiedAt DESC',
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  /// Nur die archivierten Notizen (für den Archiv-Bildschirm).
  Future<List<Note>> getArchivedNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'isArchived = ?',
      whereArgs: [1],
      orderBy: 'modifiedAt DESC',
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  Future<Note?> getNoteById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Note.fromMap(maps.first);
  }

  Future<int> insertNote(Note note) async {
    final db = await database;
    final result = await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _updateWidgetJsonFile();
    return result;
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    final result = await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
    await _updateWidgetJsonFile();
    return result;
  }

  Future<int> deleteNote(String id) async {
    final db = await database;
    // Für Sync/Historie: Löschung mit Snapshot des Inhalts vormerken (Tombstone).
    final note = await getNoteById(id);
    if (note != null) {
      await _recordDeletion(db, note);
    }
    final result = await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    await db.delete('sync_base', where: 'id = ?', whereArgs: [id]);
    await _updateWidgetJsonFile();
    return result;
  }

  Future<int> deleteAllNotes() async {
    final db = await database;
    final notes = await getAllNotes(includeArchived: true);
    for (final note in notes) {
      await _recordDeletion(db, note);
    }
    final result = await db.delete('notes');
    await db.delete('sync_base');
    await _updateWidgetJsonFile();
    return result;
  }

  /// Löscht eine Notiz, OHNE einen Tombstone zu erzeugen. Für das Anwenden
  /// von Löschungen, die per Sync von einem anderen Gerät kommen.
  Future<void> applyRemoteDeletion(String id) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
    await db.delete('sync_base', where: 'id = ?', whereArgs: [id]);
    await _updateWidgetJsonFile();
  }

  Future<void> _recordDeletion(Database db, Note note) async {
    await db.insert(
      'deletions',
      {
        'id': note.id,
        'deletedAt': DateTime.now().toIso8601String(),
        'snapshot': jsonEncode(note.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Ausstehende Löschungen (Tombstones), die noch zu Drive gepusht werden müssen.
  Future<List<Map<String, dynamic>>> getPendingDeletions() async {
    final db = await database;
    return await db.query('deletions');
  }

  Future<void> clearDeletion(String id) async {
    final db = await database;
    await db.delete('deletions', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Basis-Stand für die Konflikt-Erkennung ----
  //
  // Gespeichert wird der `modifiedAt`-Zeitstempel (ISO) genau der Fassung, die
  // dieses Gerät zuletzt mit Drive ausgetauscht hat (hochgeladen ODER geholt) –
  // also der gemeinsame Vorfahre von lokalem Stand und Drive-Stand.
  //
  // WARUM: Ohne diesen Anker kann der Sync nur „lokal seit X geändert UND
  // Remote-Datei seit Y neu" prüfen. Das trifft aber auch auf die EIGENE gerade
  // hochgeladene Datei zu (z.B. wenn zwei Prozesse – Hauptfenster und
  // Sticky-Fenster – parallel syncen und der Zeitstempel-Wasserstand
  // zurückspringt) → es wurde ständig „Konflikt" gemeldet, obwohl alle
  // Änderungen vom selben Gerät kamen (war real ein Bug bis 1.30.x). Mit dem
  // Basis-Stand ist die Frage exakt beantwortbar: Ist die Remote-Fassung
  // dieselbe, die wir zuletzt gesehen haben, ist NICHTS passiert.
  Future<String?> getSyncBase(String id) async {
    final db = await database;
    final rows = await db.query(
      'sync_base',
      columns: ['base'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['base'] as String?;
  }

  Future<void> setSyncBase(String id, String base) async {
    final db = await database;
    // Kein _updateWidgetJsonFile(): reine Sync-Buchhaltung, keine Notizdaten.
    await db.insert(
      'sync_base',
      {'id': id, 'base': base},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearSyncBase(String id) async {
    final db = await database;
    await db.delete('sync_base', where: 'id = ?', whereArgs: [id]);
  }

  // Suche
  Future<List<Note>> searchNotes(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: '(title LIKE ? OR content LIKE ?) AND isArchived = ?',
      whereArgs: ['%$query%', '%$query%', 0],
      orderBy: 'isPinned DESC, modifiedAt DESC',
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  // Für Google Drive Sync
  Future<List<Note>> getNotesModifiedAfter(DateTime date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'modifiedAt > ?',
      whereArgs: [date.toIso8601String()],
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  // Batch-Operationen für Sync
  Future<void> insertOrUpdateNotes(List<Note> notes) async {
    final db = await database;
    final batch = db.batch();
    for (final note in notes) {
      batch.insert(
        'notes',
        note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    await _updateWidgetJsonFile();
  }

  // Datenbank schließen
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  // Export für Backup
  Future<List<Map<String, dynamic>>> exportAllNotes() async {
    final db = await database;
    return await db.query('notes');
  }

  // Import von Backup
  Future<void> importNotes(List<Map<String, dynamic>> notesData) async {
    final db = await database;
    final batch = db.batch();
    for (final noteData in notesData) {
      batch.insert(
        'notes',
        noteData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    await _updateWidgetJsonFile();
  }

  // Widget-JSON manuell aktualisieren (z.B. beim App-Start)
  Future<void> syncWidgetData() async {
    await _updateWidgetJsonFile();
  }

  /// Letzter Änderungszeitpunkt der DB-Dateien. Dient der Hauptapp dazu,
  /// Schreibvorgänge aus anderen Prozessen (Sticky-Note-Fenster) zu erkennen.
  Future<DateTime?> getLastModified() async {
    // Sicherstellen, dass der Pfad bekannt ist (DB ggf. initialisieren).
    if (_databasePath == null) {
      await database;
    }
    final path = _databasePath;
    if (path == null) return null;

    DateTime? latest;
    for (final suffix in ['', '-wal', '-journal', '-shm']) {
      final file = File('$path$suffix');
      if (await file.exists()) {
        final modified = (await file.stat()).modified;
        if (latest == null || modified.isAfter(latest)) {
          latest = modified;
        }
      }
    }
    return latest;
  }
}

