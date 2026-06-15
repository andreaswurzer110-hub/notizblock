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
}
