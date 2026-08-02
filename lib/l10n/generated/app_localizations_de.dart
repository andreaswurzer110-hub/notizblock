// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Notizblock AW';

  @override
  String get newNote => 'Neue Notiz';

  @override
  String get settings => 'Einstellungen';

  @override
  String get search => 'Suchen';

  @override
  String get searchHint => 'Notizen durchsuchen...';

  @override
  String get delete => 'Löschen';

  @override
  String get deleteNote => 'Notiz löschen';

  @override
  String get deleteNoteConfirm => 'Möchtest du diese Notiz wirklich löschen?';

  @override
  String get save => 'Speichern';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get noNotes => 'Keine Notizen';

  @override
  String get noNotesHint => 'Tippe auf + um eine neue Notiz zu erstellen';

  @override
  String get noSearchResults => 'Keine Ergebnisse';

  @override
  String get emptyNote => 'Leere Notiz';

  @override
  String get pin => 'Anheften';

  @override
  String get unpin => 'Loslassen';

  @override
  String get color => 'Farbe';

  @override
  String get archive => 'Archivieren';

  @override
  String get titleHint => 'Titel';

  @override
  String get contentHint => 'Notiz schreiben...';

  @override
  String createdAt(String date) {
    return 'Erstellt: $date';
  }

  @override
  String modifiedAt(String date) {
    return 'Geändert: $date';
  }

  @override
  String get language => 'Sprache';

  @override
  String get theme => 'Design';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get defaultColor => 'Standardfarbe';

  @override
  String get googleDrive => 'Google Drive';

  @override
  String get signIn => 'Anmelden';

  @override
  String get signOut => 'Abmelden';

  @override
  String signedInAs(String email) {
    return 'Angemeldet als $email';
  }

  @override
  String get sync => 'Synchronisieren';

  @override
  String get autoSync => 'Automatisch synchronisieren';

  @override
  String lastSync(String date) {
    return 'Letzte Sync: $date';
  }

  @override
  String get neverSynced => 'Noch nie synchronisiert';

  @override
  String get syncSuccess => 'Synchronisierung erfolgreich';

  @override
  String get syncFailed => 'Synchronisierung fehlgeschlagen';

  @override
  String uploaded(int count) {
    return '$count hochgeladen';
  }

  @override
  String downloaded(int count) {
    return '$count heruntergeladen';
  }

  @override
  String get createBackup => 'Backup erstellen';

  @override
  String get restoreBackup => 'Backup wiederherstellen';

  @override
  String get restore => 'Wiederherstellen';

  @override
  String get restoreConfirm =>
      'Alle lokalen Notizen werden überschrieben. Fortfahren?';

  @override
  String get backupSuccess => 'Backup erfolgreich erstellt';

  @override
  String get backupFailed => 'Backup fehlgeschlagen';

  @override
  String get restoreSuccess => 'Backup erfolgreich wiederhergestellt';

  @override
  String get restoreFailed => 'Wiederherstellung fehlgeschlagen';

  @override
  String get about => 'Über';

  @override
  String get version => 'Version';

  @override
  String get openInWindow => 'In neuem Fenster öffnen';

  @override
  String get pinAsWidget => 'Als Widget anheften';

  @override
  String get unpinWidget => 'Widget lösen';

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String get autostart => 'Automatisch starten';

  @override
  String get autostartSubtitle => 'Widgets automatisch beim Systemstart öffnen';

  @override
  String get showMainWindow => 'Hauptfenster beim Start öffnen';

  @override
  String get showMainWindowSubtitle =>
      'Standardmäßig öffnen sich nur die angehefteten Widgets';

  @override
  String get fontSize => 'Schriftgröße';

  @override
  String get fontSizeSample => 'Beispieltext';

  @override
  String get undo => 'Rückgängig';

  @override
  String get redo => 'Wiederholen';

  @override
  String get notSignedIn => 'Nicht bei Google Drive angemeldet';

  @override
  String get archiveAndRestore => 'Archiv & Wiederherstellen';

  @override
  String get archivedTab => 'Archiviert';

  @override
  String get deletedTab => 'Gelöscht';

  @override
  String get noArchivedNotes => 'Keine archivierten Notizen';

  @override
  String get noDeletedNotes => 'Keine gelöschten Notizen';

  @override
  String get deletedSignInHint =>
      'Bei Google Drive anmelden, um gelöschte Notizen anzuzeigen';

  @override
  String get deletedLoadFailed =>
      'Gelöschte Notizen konnten nicht geladen werden';

  @override
  String get noteRestored => 'Notiz wiederhergestellt';

  @override
  String deletedOn(String date) {
    return 'Gelöscht: $date';
  }

  @override
  String get deletePermanently => 'Endgültig löschen';

  @override
  String get deletePermanentlyConfirm =>
      'Diese Notiz endgültig löschen? Das kann nicht rückgängig gemacht werden.';

  @override
  String get autopool => 'Autopool';

  @override
  String get createNoteTitle => 'Was möchtest du erstellen?';

  @override
  String get noteTypeNote => 'Notiz';

  @override
  String get noteTypeNoteSubtitle => 'Einfache Textnotiz';

  @override
  String get noteTypeAutopoolSubtitle => 'Tabelle (Geräteliste)';

  @override
  String get noteTypeShoppingSubtitle => 'Artikel abhaken, Mengen zählen';

  @override
  String get shoppingList => 'Einkaufsliste';

  @override
  String get shoppingItemHint => 'Artikel';

  @override
  String get shoppingAddItem => 'Artikel hinzufügen';

  @override
  String shoppingCompleted(int count) {
    return 'Erledigt ($count)';
  }

  @override
  String get shoppingDeleteItem => 'Artikel löschen';

  @override
  String shoppingOpenCount(int open, int total) {
    return '$open/$total offen';
  }

  @override
  String get allNotes => 'Alle Notizen';

  @override
  String get folders => 'Ordner';

  @override
  String get newFolder => 'Neuer Ordner';

  @override
  String get folderName => 'Ordnername';

  @override
  String get renameFolder => 'Ordner umbenennen';

  @override
  String get deleteFolder => 'Ordner löschen';

  @override
  String deleteFolderConfirm(String name) {
    return 'Ordner „$name“ löschen? Die enthaltenen Notizen bleiben erhalten und sind dann keinem Ordner mehr zugeordnet.';
  }

  @override
  String get moveToFolder => 'In Ordner verschieben';

  @override
  String get noFolder => 'Kein Ordner';

  @override
  String get addExistingNote => 'Vorhandene Notiz hinzufügen';

  @override
  String addNotesToFolderTitle(String folder) {
    return 'Notizen zu „$folder“ hinzufügen';
  }

  @override
  String addedToFolderSnack(String folder) {
    return 'Zu „$folder“ hinzugefügt';
  }

  @override
  String get removedFromFolderSnack => 'Aus Ordner entfernt';

  @override
  String get noNotesToAdd => 'Keine weiteren Notizen zum Hinzufügen';

  @override
  String get add => 'Hinzufügen';

  @override
  String get autopoolColName => 'Bezeichnung';

  @override
  String get autopoolColOfficeVersion => 'DS & Version';

  @override
  String get autopoolColLocation => 'Ort';

  @override
  String get autopoolColInventory => 'Inventarnummer';

  @override
  String get autopoolColSerial => 'Seriennummer';

  @override
  String get autopoolColDate => 'Datum';

  @override
  String get autopoolAddRow => 'Zeile hinzufügen';

  @override
  String get autopoolAddRowFull => 'Volle Zeile (6 Felder)';

  @override
  String get autopoolAddRow4 => 'Kurze Zeile (4 Felder)';

  @override
  String get autopoolAddRow2 => 'Kurze Zeile (2 Felder)';

  @override
  String get autopoolMoveRow => 'Verschieben';

  @override
  String get autopoolDeleteRow => 'Zeile löschen';

  @override
  String get autopoolMarkRow => 'Markieren / Markierung entfernen';

  @override
  String get autopoolRowColor => 'Zeilenfarbe';

  @override
  String get autopoolNoColor => 'Keine Farbe';

  @override
  String get autopoolRenameColumn => 'Spalte umbenennen';

  @override
  String get autopoolResetColumn => 'Auf Standard zurücksetzen';

  @override
  String get autopoolColumnLabel => 'Spaltenname';

  @override
  String get moveUp => 'Nach oben';

  @override
  String get moveDown => 'Nach unten';

  @override
  String get openLink => 'Link öffnen';

  @override
  String get searchWeb => 'Im Web suchen';

  @override
  String get linkOpenFailed => 'Link konnte nicht geöffnet werden';

  @override
  String get ctxCut => 'cut';

  @override
  String get ctxPaste => 'Einfügen';

  @override
  String get readOnly => 'Nur Lesen';

  @override
  String get creator => 'Ersteller';

  @override
  String get feedback => 'Feedback und Fragen';

  @override
  String get close => 'Schließen';

  @override
  String get bibleVerse1Ref => 'Kolosser 3,17';

  @override
  String get bibleVerse1Text =>
      'Und was immer ihr tut in Wort oder Werk, das tut alles im Namen des Herrn Jesus und dankt Gott, dem Vater, durch ihn.';

  @override
  String get bibleVerse2Ref => 'Johannes 14,6';

  @override
  String get bibleVerse2Text =>
      'Jesus spricht zu ihm: Ich bin der Weg und die Wahrheit und das Leben; niemand kommt zum Vater als nur durch mich!';

  @override
  String get printExport => 'Drucken';

  @override
  String get printExportTitle => 'Drucken & Exportieren';

  @override
  String get printSystem => 'Drucken';

  @override
  String get printSystemSubtitle => 'Systemdialog (Drucker/PDF)';

  @override
  String get exportPdf => 'Als PDF speichern';

  @override
  String get exportTxt => 'Als Textdatei speichern';

  @override
  String get exportWord => 'Als Word-Dokument speichern';

  @override
  String exportSaved(String file) {
    return 'Gespeichert: $file';
  }

  @override
  String exportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get shareImportTitle => 'Text übernehmen';

  @override
  String get shareImportNewNote => 'In neue Notiz';

  @override
  String get shareImportNewNoteSubtitle =>
      'Legt eine neue Notiz mit dem Text an';

  @override
  String get shareImportExisting => 'In bestehende Notiz';

  @override
  String get shareImportExistingSubtitle =>
      'Text in eine vorhandene Notiz einfügen';

  @override
  String get shareImportChooseNote => 'Notiz auswählen';

  @override
  String get shareInsertPositionTitle => 'Wo einfügen?';

  @override
  String get shareInsertTop => 'Oberhalb einfügen';

  @override
  String get shareInsertBottom => 'Unterhalb einfügen';

  @override
  String shareInsertedSnack(String title) {
    return 'Text in „$title“ eingefügt';
  }

  @override
  String get selectNotes => 'Auswählen';

  @override
  String selectedCount(int count) {
    return '$count ausgewählt';
  }

  @override
  String get selectAllNotes => 'Alle auswählen';

  @override
  String deleteNotesConfirm(int count) {
    return 'Sollen $count Notizen wirklich gelöscht werden?';
  }

  @override
  String notesMovedSnack(int count) {
    return '$count Notizen verschoben';
  }

  @override
  String notesArchivedSnack(int count) {
    return '$count Notizen archiviert';
  }
}
