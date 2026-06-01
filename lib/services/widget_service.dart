import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';
import 'database_service.dart';

class WidgetService {
  static const String appGroupId = 'group.com.notizblock.app';
  static const String androidWidgetName = 'NoteWidgetProvider';
  // Voll qualifiziert: die Provider-Klasse liegt im Namespace com.example.notizblock,
  // die applicationId ist aber at.aw.notizblock -> sonst trifft der Update-Broadcast nicht.
  static const String androidWidgetQualifiedName =
      'com.example.notizblock.NoteWidgetProvider';
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
      await HomeWidget.updateWidget(
        androidName: androidWidgetName,
        qualifiedAndroidName: androidWidgetQualifiedName,
      );
    } catch (e) {
      debugPrint('Widget Update Fehler: $e');
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

// Hintergrund-Callback für Widget-Interaktionen
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;

  if (uri.scheme == 'notizblock' && uri.host == 'open_note') {
    final noteId = uri.queryParameters['id'];
    if (noteId != null) {
      // Notiz-ID für das Öffnen speichern
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_note_id', noteId);
    }
  }
}
