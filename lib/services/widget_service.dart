import 'dart:convert';
import 'dart:io';
import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';
import 'database_service.dart';
import 'google_drive_service.dart';

class WidgetService {
  static const String appGroupId = 'group.com.notizblock.app';
  static const String androidWidgetName = 'NoteWidgetProvider';
  // Voll qualifiziert: die Provider-Klasse liegt im Namespace com.example.notizblock,
  // die applicationId ist aber at.aw.notizblock -> sonst trifft der Update-Broadcast nicht.
  static const String androidWidgetQualifiedName =
      'com.example.notizblock.NoteWidgetProvider';
  // Ordner-Widget (öffnet die App im gewählten Ordner). Eigener Provider, gleicher
  // Namespace-Trick wie beim Notiz-Widget.
  static const String folderWidgetName = 'FolderWidgetProvider';
  static const String folderWidgetQualifiedName =
      'com.example.notizblock.FolderWidgetProvider';
  static const String _selectedNoteKey = 'widget_selected_note_';

  // Singleton
  WidgetService._privateConstructor();
  static final WidgetService instance = WidgetService._privateConstructor();

  // Initialisieren
  Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    // Callback für Widget-Klicks registrieren
    HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
  }

  // Widget aktualisieren
  Future<void> updateWidget() async {
    if (!Platform.isAndroid) return;

    try {
      // Login-Status mitschreiben, bevor das Widget neu zeichnet, damit der
      // Provider Zeit/Datum durchstreichen kann, wenn nicht angemeldet.
      await _writeDriveSignInState();
      await HomeWidget.updateWidget(
        androidName: androidWidgetName,
        qualifiedAndroidName: androidWidgetQualifiedName,
      );
    } catch (e) {
      debugPrint('Widget Update Fehler: $e');
    }
  }

  // Ordner-Widget(s) neu zeichnen lassen (nach Ordner-/Zähler-Änderungen). Die
  // Ordnerliste selbst liegt in app_flutter/folders.json (vom NotesProvider
  // geschrieben); dieser Broadcast stößt nur die Neuberechnung an.
  Future<void> updateFolderWidget() async {
    if (!Platform.isAndroid) return;
    try {
      await HomeWidget.updateWidget(
        androidName: folderWidgetName,
        qualifiedAndroidName: folderWidgetQualifiedName,
      );
    } catch (e) {
      debugPrint('Ordner-Widget Update Fehler: $e');
    }
  }

  // Drive-Login-Status neben notes.json ablegen (app_flutter/drive_state.json).
  // Der NoteWidgetProvider liest die Datei und streicht Zeit/Datum durch, wenn
  // nicht angemeldet – so fällt ein versehentliches Abmelden auf.
  Future<void> _writeDriveSignInState() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/drive_state.json');
      await file.writeAsString(
        jsonEncode({'signedIn': GoogleDriveService.instance.isSignedIn}),
      );
    } catch (e) {
      debugPrint('drive_state.json schreiben fehlgeschlagen: $e');
    }
  }

  // Notiz für Widget speichern
  Future<void> setWidgetNote(int widgetId, Note note) async {
    if (!Platform.isAndroid) return;

    try {
      // Notiz-Daten für Widget speichern
      await HomeWidget.saveWidgetData<String>(
        'note_id_$widgetId',
        note.id,
      );
      await HomeWidget.saveWidgetData<String>(
        'note_title_$widgetId',
        note.title,
      );
      await HomeWidget.saveWidgetData<String>(
        'note_content_$widgetId',
        note.content,
      );
      await HomeWidget.saveWidgetData<String>(
        'note_color_$widgetId',
        note.color,
      );

      // In SharedPreferences für spätere Referenz speichern
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_selectedNoteKey$widgetId', note.id);

      // Widget aktualisieren
      await updateWidget();
    } catch (e) {
      debugPrint('Widget Notiz speichern Fehler: $e');
    }
  }

  // Widget-Notiz abrufen
  Future<String?> getWidgetNoteId(int widgetId) async {
    if (!Platform.isAndroid) return null;

    try {
      return await HomeWidget.getWidgetData<String>('note_id_$widgetId');
    } catch (e) {
      debugPrint('Widget Notiz abrufen Fehler: $e');
      return null;
    }
  }

  // Alle Notizen für Widget-Auswahl laden
  Future<List<Note>> getNotesForWidgetSelection() async {
    return await DatabaseService.instance.getAllNotes();
  }

  // Widget-Daten bei Notiz-Änderung aktualisieren
  Future<void> updateWidgetIfNoteChanged(Note note) async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(_selectedNoteKey)) {
        final storedNoteId = prefs.getString(key);
        if (storedNoteId == note.id) {
          final widgetId = int.tryParse(key.replaceFirst(_selectedNoteKey, ''));
          if (widgetId != null) {
            await setWidgetNote(widgetId, note);
          }
        }
      }
    }
  }

  // Widget-Daten bei Notiz-Löschung bereinigen
  Future<void> removeWidgetNote(String noteId) async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList();

    for (final key in keys) {
      if (key.startsWith(_selectedNoteKey)) {
        final storedNoteId = prefs.getString(key);
        if (storedNoteId == noteId) {
          final widgetId = int.tryParse(key.replaceFirst(_selectedNoteKey, ''));
          if (widgetId != null) {
            // Widget-Daten löschen
            await HomeWidget.saveWidgetData<String>('note_id_$widgetId', null);
            await HomeWidget.saveWidgetData<String>('note_title_$widgetId', null);
            await HomeWidget.saveWidgetData<String>('note_content_$widgetId', null);
            await HomeWidget.saveWidgetData<String>('note_color_$widgetId', null);
            await prefs.remove(key);
          }
        }
      }
    }

    await updateWidget();
  }
}

// Hintergrund-Callback für Widget-Interaktionen.
// Läuft in einem eigenen Isolate (auch bei geschlossener App). Der home_widget-
// Dispatcher ruft vorher WidgetsFlutterBinding.ensureInitialized() auf.
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri == null || uri.scheme != 'notizblock') return;

  switch (uri.host) {
    case 'open_note':
      final noteId = uri.queryParameters['id'];
      if (noteId != null) {
        // Notiz-ID für das Öffnen speichern
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_note_id', noteId);
      }
      break;

    // Klick auf die Zeit-Anzeige im Widget: jetzt von Drive synchronisieren.
    // Bewusst NICHT an den Auto-Sync-Schalter gekoppelt – es ist eine explizite
    // Nutzeraktion. Bei Änderungen schreibt synchronize() notes.json neu und
    // feuert über DatabaseService den Widget-Refresh-Broadcast.
    case 'sync_now':
      try {
        WidgetsFlutterBinding.ensureInitialized();
        // Im home_widget-Hintergrund-Isolate sind sonst KEINE Plugins registriert
        // (der Dispatcher macht nur ensureInitialized, kein PluginRegistrant) →
        // sqflite/shared_preferences/google_sign_in würden sonst fehlschlagen.
        DartPluginRegistrant.ensureInitialized();
        final signedIn = await GoogleDriveService.instance.signInSilently();
        if (signedIn) {
          await GoogleDriveService.instance.synchronize();
        }
        // Auch ohne Datenänderung das Widget neu zeichnen (sichtbares Feedback).
        await WidgetService.instance.updateWidget();
      } catch (e) {
        debugPrint('Widget-Sync fehlgeschlagen: $e');
      }
      break;
  }
}
