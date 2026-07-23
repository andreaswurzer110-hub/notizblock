import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import '../models/note.dart';
import '../services/database_service.dart';
import '../services/widget_service.dart';
import '../services/google_drive_service.dart';
import '../services/settings_store.dart';
import 'settings_provider.dart';

class NotesProvider with ChangeNotifier, WidgetsBindingObserver {
  // SettingsStore-Key für die explizite Ordner-Liste (lokal, JSON-Array).
  static const String foldersKey = 'folders';

  List<Note> _notes = [];
  String _searchQuery = '';
  // Aktueller Ordner-Filter; leer = "Alle Notizen".
  String _selectedFolder = '';
  // Vom Nutzer angelegte Ordner (Reihenfolge/leere Ordner). Im Drawer vereint mit
  // den Ordnern, die tatsächlich in Notizen vorkommen (siehe [folders]).
  List<String> _folders = [];
  bool _isLoading = false;
  String? _error;
  Timer? _autoSyncTimer;
  Timer? _externalChangeTimer;
  Timer? _remotePullTimer;
  DateTime? _lastDbMtime;

  // Auto-Sync und Fremdänderungs-Erkennung nur auf Desktop. Android hat keine
  // separaten Sticky-Fenster-Prozesse; das Auto-Sync-Verhalten dort ist offen.
  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  NotesProvider() {
    if (_isDesktop) {
      // Erkennt Änderungen, die andere Prozesse (Sticky-Note-Fenster) in die
      // DB schreiben, und hält Hauptfenster + Drive aktuell.
      _externalChangeTimer = Timer.periodic(
        const Duration(milliseconds: 800),
        (_) => _checkExternalChanges(),
      );
    }
    // Regelmäßiger Drive-Pull auf ALLEN Plattformen, damit Änderungen anderer
    // Geräte automatisch erscheinen. Läuft nur im Vordergrund – auf Android
    // pausieren Timer im Hintergrund, daher kein Akkuverbrauch dort.
    _remotePullTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _runAutoSync(),
    );
    // Sofort-Sync, wenn die App in den Vordergrund zurückkehrt.
    WidgetsBinding.instance.addObserver(this);
    // Einmaliger Sync kurz nach Start: holt Änderungen anderer Geräte herein.
    Timer(const Duration(seconds: 2), _runAutoSync);
    // Explizite Ordner-Liste laden.
    _loadFolders();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // resumed: Änderungen anderer Geräte holen. paused: eigene Änderungen noch
    // schnell hochladen, bevor Android den Prozess (und Timer) einfriert.
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.paused) {
      _runAutoSync();
    }
  }

  Future<void> _checkExternalChanges() async {
    if (_isLoading) return;
    final mtime = await DatabaseService.instance.getLastModified();
    if (mtime == null) return;
    if (_lastDbMtime != null && !mtime.isAfter(_lastDbMtime!)) return;

    final hadKnownState = _lastDbMtime != null;
    await loadNotes(silent: true); // lädt neu und merkt sich _lastDbMtime
    if (hadKnownState) {
      // Fremdänderung (z.B. aus einem Sticky-Fenster) -> auch zu Drive syncen.
      _scheduleAutoSync();
    }
  }

  /// Nach einer eigenen Schreiboperation: DB-Zeitstempel merken (sonst würde die
  /// Fremdänderungs-Erkennung den eigenen Schreibvorgang erneut laden) und
  /// Auto-Sync planen.
  Future<void> _afterLocalWrite() async {
    _lastDbMtime = await DatabaseService.instance.getLastModified();
    _scheduleAutoSync();
  }

  /// Plant einen entprellten Auto-Sync nach einer Datenänderung.
  /// Mehrere schnelle Änderungen (z.B. Tippen) lösen nur einen Sync aus.
  /// Läuft auf allen Plattformen (Android lädt dank Delta nur die geänderte
  /// Notiz hoch); nur das Fremdänderungs-Polling bleibt Desktop-exklusiv.
  void _scheduleAutoSync() {
    if (!GoogleDriveService.instance.isSignedIn) return;
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer(const Duration(seconds: 2), _runAutoSync);
  }

  Future<void> _runAutoSync() async {
    await SettingsStore.load();
    if (!(SettingsStore.getBool(SettingsProvider.autoSyncKey) ?? false)) return;
    // Sicherheitsnetz: Ging die Anmeldung verloren (z.B. App lange im Hintergrund),
    // still neu anmelden, bevor synchronisiert wird – sonst bliebe der Status bis
    // zum nächsten App-Start auf "abgemeldet".
    if (!GoogleDriveService.instance.isSignedIn) {
      await GoogleDriveService.instance.signInSilently();
    }
    final result = await GoogleDriveService.instance.synchronize();
    if (result.success) {
      await loadNotes(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSyncTimer?.cancel();
    _externalChangeTimer?.cancel();
    _remotePullTimer?.cancel();
    super.dispose();
  }

  // Getters. Die sichtbare Liste kombiniert Ordner-Filter UND Suche (live
  // berechnet – kein separater _filteredNotes-Cache mehr).
  List<Note> get notes {
    Iterable<Note> result = _notes;
    if (_selectedFolder.isNotEmpty) {
      result = result.where((n) => n.folder == _selectedFolder);
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((n) =>
          n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q));
    }
    return result.toList();
  }

  List<Note> get pinnedNotes => notes.where((n) => n.isPinned).toList();
  List<Note> get unpinnedNotes => notes.where((n) => !n.isPinned).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  // --- Ordner ---

  String get selectedFolder => _selectedFolder;

  /// Alle sichtbaren Ordnernamen: explizit angelegte + solche, die tatsächlich in
  /// (nicht archivierten) Notizen vorkommen. Alphabetisch sortiert.
  List<String> get folders {
    final set = <String>{..._folders};
    for (final n in _notes) {
      if (n.folder.isNotEmpty) set.add(n.folder);
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  /// Anzahl Notizen in einem Ordner (aus der aktuell geladenen, nicht
  /// archivierten Liste).
  int folderCount(String folder) =>
      _notes.where((n) => n.folder == folder).length;

  /// Gesamtzahl (für „Alle Notizen").
  int get totalCount => _notes.length;

  void selectFolder(String folder) {
    if (_selectedFolder == folder) return;
    _selectedFolder = folder;
    notifyListeners();
  }

  Future<void> _loadFolders() async {
    try {
      await SettingsStore.load();
      final raw = SettingsStore.getString(foldersKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _folders = decoded
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Ordner laden fehlgeschlagen: $e');
    }
  }

  Future<void> _saveFolders() async {
    try {
      await SettingsStore.setString(foldersKey, jsonEncode(_folders));
    } catch (e) {
      debugPrint('Ordner speichern fehlgeschlagen: $e');
    }
  }

  /// Neuen (leeren) Ordner anlegen.
  Future<void> createFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _folders.contains(trimmed)) return;
    _folders.add(trimmed);
    await _saveFolders();
    notifyListeners();
  }

  /// Ordner umbenennen: explizite Liste anpassen und alle Notizen umhängen.
  Future<void> renameFolder(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return;
    final idx = _folders.indexOf(oldName);
    if (idx != -1) {
      _folders[idx] = trimmed;
    } else {
      _folders.add(trimmed);
    }
    _folders = _folders.toSet().toList(); // eventuelles Duplikat mergen
    await _saveFolders();

    for (final n in _notes.where((n) => n.folder == oldName).toList()) {
      final updated = n.copyWith(folder: trimmed, modifiedAt: DateTime.now());
      await DatabaseService.instance.updateNote(updated);
      final i = _notes.indexWhere((x) => x.id == n.id);
      if (i != -1) _notes[i] = updated;
    }
    if (_selectedFolder == oldName) _selectedFolder = trimmed;
    notifyListeners();
    await WidgetService.instance.updateWidget();
    await _afterLocalWrite();
  }

  /// Ordner löschen: aus der Liste entfernen; enthaltene Notizen bleiben erhalten
  /// und wandern zu „kein Ordner" (folder = '').
  Future<void> deleteFolder(String name) async {
    _folders.remove(name);
    await _saveFolders();

    for (final n in _notes.where((n) => n.folder == name).toList()) {
      final updated = n.copyWith(folder: '', modifiedAt: DateTime.now());
      await DatabaseService.instance.updateNote(updated);
      final i = _notes.indexWhere((x) => x.id == n.id);
      if (i != -1) _notes[i] = updated;
    }
    if (_selectedFolder == name) _selectedFolder = '';
    notifyListeners();
    await WidgetService.instance.updateWidget();
    await _afterLocalWrite();
  }

  /// Eine Notiz einem Ordner zuordnen (leer = kein Ordner).
  Future<bool> setNoteFolder(String id, String folder) async {
    final note = _notes.firstWhere((n) => n.id == id);
    if (note.folder == folder) return true;
    return await updateNote(note.copyWith(folder: folder));
  }

  // Notizen laden
  Future<void> loadNotes({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      _notes = await DatabaseService.instance.getAllNotes();
      _lastDbMtime = await DatabaseService.instance.getLastModified();
    } catch (e) {
      _error = e.toString();
      debugPrint('Fehler beim Laden der Notizen: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Notiz hinzufügen
  Future<Note?> addNote({
    required String title,
    required String content,
    String color = '#FFFDE7',
    String type = 'text',
    String autopoolData = '',
    String? folder,
  }) async {
    try {
      final note = Note(
        title: title,
        content: content,
        color: color,
        type: type,
        autopoolData: autopoolData,
        // Ohne explizite Angabe im aktuell gewählten Ordner anlegen (leer = kein
        // Ordner), damit eine neue Notiz dort erscheint, wo man gerade ist.
        folder: folder ?? _selectedFolder,
      );

      await DatabaseService.instance.insertNote(note);
      _notes.insert(0, note);

      notifyListeners();
      
      // Widget aktualisieren
      await WidgetService.instance.updateWidget();

      await _afterLocalWrite();
      return note;
    } catch (e) {
      _error = e.toString();
      debugPrint('Fehler beim Hinzufügen: $e');
      notifyListeners();
      return null;
    }
  }

  // Notiz aktualisieren
  Future<bool> updateNote(Note note) async {
    try {
      final updatedNote = note.copyWith(modifiedAt: DateTime.now());
      await DatabaseService.instance.updateNote(updatedNote);

      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = updatedNote;
        _sortNotes();
      }

      notifyListeners();

      // Widget aktualisieren
      await WidgetService.instance.updateWidget();

      await _afterLocalWrite();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Fehler beim Aktualisieren: $e');
      notifyListeners();
      return false;
    }
  }

  // Notiz löschen
  Future<bool> deleteNote(String id) async {
    try {
      await DatabaseService.instance.deleteNote(id);
      _notes.removeWhere((n) => n.id == id);

      notifyListeners();

      // Widget aktualisieren
      await WidgetService.instance.updateWidget();

      await _afterLocalWrite();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Fehler beim Löschen: $e');
      notifyListeners();
      return false;
    }
  }

  // Notiz anheften/lösen
  Future<bool> togglePin(String id) async {
    final note = _notes.firstWhere((n) => n.id == id);
    final updatedNote = note.copyWith(isPinned: !note.isPinned);
    return await updateNote(updatedNote);
  }

  // Notiz archivieren
  Future<bool> archiveNote(String id) async {
    final note = _notes.firstWhere((n) => n.id == id);
    final updatedNote = note.copyWith(isArchived: true);
    
    try {
      await DatabaseService.instance.updateNote(updatedNote);
      _notes.removeWhere((n) => n.id == id);

      notifyListeners();

      await _afterLocalWrite();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Fehler beim Archivieren: $e');
      notifyListeners();
      return false;
    }
  }

  // Archivierte Notizen laden (für den Archiv-Bildschirm). Liegen nicht in der
  // sichtbaren Liste, daher direkt aus der DB.
  Future<List<Note>> getArchivedNotes() =>
      DatabaseService.instance.getArchivedNotes();

  // Archivierte Notiz wiederherstellen: isArchived zurücksetzen, frischer
  // modifiedAt-Stempel (damit die Änderung synct) und zurück in die Liste.
  Future<bool> unarchiveNote(String id) async {
    try {
      final note = await DatabaseService.instance.getNoteById(id);
      if (note == null) return false;
      final updated =
          note.copyWith(isArchived: false, modifiedAt: DateTime.now());
      await DatabaseService.instance.updateNote(updated);

      _notes.removeWhere((n) => n.id == id);
      _notes.insert(0, updated);
      _sortNotes();

      notifyListeners();
      await WidgetService.instance.updateWidget();
      await _afterLocalWrite();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Fehler beim Wiederherstellen (Archiv): $e');
      notifyListeners();
      return false;
    }
  }

  // Gelöschte Notiz wiederherstellen (Stand stammt aus dem Drive-Verlauf):
  // lokal neu anlegen, eventuellen lokalen Tombstone löschen und auf Drive den
  // Tombstone entfernen + frischen Stand hochladen, damit der nächste Sync sie
  // nicht erneut löscht. Frischer modifiedAt > deletedAt = gewinnt last-write-wins.
  Future<bool> restoreDeletedNote(Note snapshot) async {
    try {
      final restored =
          snapshot.copyWith(isArchived: false, modifiedAt: DateTime.now());
      await DatabaseService.instance.insertOrUpdateNotes([restored]);
      await DatabaseService.instance.clearDeletion(restored.id);
      await GoogleDriveService.instance.restoreDeletedNoteRemote(restored);

      await loadNotes(silent: true);
      _scheduleAutoSync();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Fehler beim Wiederherstellen (gelöscht): $e');
      notifyListeners();
      return false;
    }
  }

  // Farbe ändern
  Future<bool> changeColor(String id, String color) async {
    final note = _notes.firstWhere((n) => n.id == id);
    final updatedNote = note.copyWith(color: color);
    return await updateNote(updatedNote);
  }

  // Suche (Filterung passiert live im notes-Getter, kombiniert mit dem Ordner).
  void search(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  void _sortNotes() {
    _notes.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.modifiedAt.compareTo(a.modifiedAt);
    });
  }

  // Notiz nach ID finden
  Note? getNoteById(String id) {
    try {
      return _notes.firstWhere((n) => n.id == id);
    } catch (e) {
      return null;
    }
  }

  // Fehler zurücksetzen
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Alle Notizen neu laden (nach Sync)
  Future<void> refreshNotes() async {
    await loadNotes();
  }
}
