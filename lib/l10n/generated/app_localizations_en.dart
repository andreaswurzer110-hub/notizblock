// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Notizblock AW';

  @override
  String get newNote => 'New Note';

  @override
  String get settings => 'Settings';

  @override
  String get search => 'Search';

  @override
  String get searchHint => 'Search notes...';

  @override
  String get delete => 'Delete';

  @override
  String get deleteNote => 'Delete Note';

  @override
  String get deleteNoteConfirm => 'Do you really want to delete this note?';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get noNotes => 'No notes';

  @override
  String get noNotesHint => 'Tap + to create a new note';

  @override
  String get noSearchResults => 'No results';

  @override
  String get emptyNote => 'Empty note';

  @override
  String get pin => 'Pin';

  @override
  String get unpin => 'Unpin';

  @override
  String get color => 'Color';

  @override
  String get archive => 'Archive';

  @override
  String get titleHint => 'Title';

  @override
  String get contentHint => 'Write a note...';

  @override
  String createdAt(String date) {
    return 'Created: $date';
  }

  @override
  String modifiedAt(String date) {
    return 'Modified: $date';
  }

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get defaultColor => 'Default color';

  @override
  String get googleDrive => 'Google Drive';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String signedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get sync => 'Sync';

  @override
  String get autoSync => 'Auto sync';

  @override
  String lastSync(String date) {
    return 'Last sync: $date';
  }

  @override
  String get neverSynced => 'Never synced';

  @override
  String get syncSuccess => 'Sync successful';

  @override
  String get syncFailed => 'Sync failed';

  @override
  String uploaded(int count) {
    return '$count uploaded';
  }

  @override
  String downloaded(int count) {
    return '$count downloaded';
  }

  @override
  String get createBackup => 'Create backup';

  @override
  String get restoreBackup => 'Restore backup';

  @override
  String get restore => 'Restore';

  @override
  String get restoreConfirm => 'All local notes will be overwritten. Continue?';

  @override
  String get backupSuccess => 'Backup created successfully';

  @override
  String get backupFailed => 'Backup failed';

  @override
  String get restoreSuccess => 'Backup restored successfully';

  @override
  String get restoreFailed => 'Restore failed';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get openInWindow => 'Open in new window';

  @override
  String get pinAsWidget => 'Pin as widget';

  @override
  String get unpinWidget => 'Unpin widget';

  @override
  String get syncNow => 'Sync now';

  @override
  String get autostart => 'Start automatically';

  @override
  String get autostartSubtitle =>
      'Open widgets automatically at system startup';

  @override
  String get showMainWindow => 'Open main window on startup';

  @override
  String get showMainWindowSubtitle =>
      'By default only the pinned widgets open';

  @override
  String get fontSize => 'Font size';

  @override
  String get fontSizeSample => 'Sample text';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get notSignedIn => 'Not signed in to Google Drive';

  @override
  String get archiveAndRestore => 'Archive & Restore';

  @override
  String get archivedTab => 'Archived';

  @override
  String get deletedTab => 'Deleted';

  @override
  String get noArchivedNotes => 'No archived notes';

  @override
  String get noDeletedNotes => 'No deleted notes';

  @override
  String get deletedSignInHint =>
      'Sign in to Google Drive to view deleted notes';

  @override
  String get deletedLoadFailed => 'Could not load deleted notes';

  @override
  String get noteRestored => 'Note restored';

  @override
  String deletedOn(String date) {
    return 'Deleted: $date';
  }

  @override
  String get deletePermanently => 'Delete permanently';

  @override
  String get deletePermanentlyConfirm =>
      'Permanently delete this note? This cannot be undone.';

  @override
  String get autopool => 'Autopool';

  @override
  String get createNoteTitle => 'What would you like to create?';

  @override
  String get noteTypeNote => 'Note';

  @override
  String get noteTypeNoteSubtitle => 'Simple text note';

  @override
  String get noteTypeAutopoolSubtitle => 'Table (device list)';

  @override
  String get noteTypeShoppingSubtitle => 'Check off items, count quantities';

  @override
  String get shoppingList => 'Shopping list';

  @override
  String get shoppingItemHint => 'Item';

  @override
  String get shoppingAddItem => 'Add item';

  @override
  String shoppingCompleted(int count) {
    return 'Completed ($count)';
  }

  @override
  String get shoppingDeleteItem => 'Delete item';

  @override
  String get shoppingSortAZ => 'Sort alphabetically (A–Z)';

  @override
  String get shoppingSortZA => 'Sort alphabetically (Z–A)';

  @override
  String shoppingOpenCount(int open, int total) {
    return '$open/$total open';
  }

  @override
  String get allNotes => 'All notes';

  @override
  String get folders => 'Folders';

  @override
  String get newFolder => 'New folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get renameFolder => 'Rename folder';

  @override
  String get deleteFolder => 'Delete folder';

  @override
  String deleteFolderConfirm(String name) {
    return 'Delete folder “$name”? The notes inside are kept and will no longer be in any folder.';
  }

  @override
  String get moveToFolder => 'Move to folder';

  @override
  String get noFolder => 'No folder';

  @override
  String get addExistingNote => 'Add existing note';

  @override
  String addNotesToFolderTitle(String folder) {
    return 'Add notes to “$folder”';
  }

  @override
  String addedToFolderSnack(String folder) {
    return 'Added to “$folder”';
  }

  @override
  String get removedFromFolderSnack => 'Removed from folder';

  @override
  String get noNotesToAdd => 'No other notes to add';

  @override
  String get add => 'Add';

  @override
  String get autopoolColName => 'Name';

  @override
  String get autopoolColOfficeVersion => 'Dept & ver.';

  @override
  String get autopoolColLocation => 'Location';

  @override
  String get autopoolColInventory => 'Inventory no.';

  @override
  String get autopoolColSerial => 'Serial number';

  @override
  String get autopoolColDate => 'Date';

  @override
  String get autopoolAddRow => 'Add row';

  @override
  String get autopoolAddRowFull => 'Full row (6 fields)';

  @override
  String get autopoolAddRow4 => 'Short row (4 fields)';

  @override
  String get autopoolAddRow2 => 'Short row (2 fields)';

  @override
  String get autopoolMoveRow => 'Move row';

  @override
  String get autopoolDeleteRow => 'Delete row';

  @override
  String get autopoolMarkRow => 'Mark / unmark row';

  @override
  String get autopoolRowColor => 'Row color';

  @override
  String get autopoolNoColor => 'No color';

  @override
  String get autopoolRenameColumn => 'Rename column';

  @override
  String get autopoolResetColumn => 'Reset to default';

  @override
  String get autopoolColumnLabel => 'Column name';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get openLink => 'Open link';

  @override
  String get searchWeb => 'Search the web';

  @override
  String get linkOpenFailed => 'Could not open link';

  @override
  String get ctxCut => 'Cut';

  @override
  String get ctxPaste => 'Paste';

  @override
  String get readOnly => 'Read only';

  @override
  String get creator => 'Creator';

  @override
  String get toolsUsed => 'Tools used';

  @override
  String get aiNotice =>
      'This app was developed with the help of artificial intelligence (Claude Code). Parts of the code and the texts are AI-generated and were reviewed by the creator.';

  @override
  String get feedback => 'Feedback & questions';

  @override
  String get close => 'Close';

  @override
  String get bibleVerse1Ref => 'Colossians 3:17';

  @override
  String get bibleVerse1Text =>
      'And whatever you do, in word or deed, do everything in the name of the Lord Jesus, giving thanks to God the Father through him.';

  @override
  String get bibleVerse2Ref => 'John 14:6';

  @override
  String get bibleVerse2Text =>
      'Jesus said to him: I am the way, and the truth, and the life. No one comes to the Father except through me.';

  @override
  String get printExport => 'Print';

  @override
  String get printExportTitle => 'Print & export';

  @override
  String get printSystem => 'Print';

  @override
  String get printSystemSubtitle => 'System dialog (printer/PDF)';

  @override
  String get exportPdf => 'Save as PDF';

  @override
  String get exportTxt => 'Save as text file';

  @override
  String get exportWord => 'Save as Word document';

  @override
  String exportSaved(String file) {
    return 'Saved: $file';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get shareImportTitle => 'Add shared text';

  @override
  String get shareImportNewNote => 'To a new note';

  @override
  String get shareImportNewNoteSubtitle => 'Creates a new note with the text';

  @override
  String get shareImportExisting => 'To an existing note';

  @override
  String get shareImportExistingSubtitle =>
      'Insert the text into an existing note';

  @override
  String get shareImportChooseNote => 'Choose note';

  @override
  String get shareInsertPositionTitle => 'Insert where?';

  @override
  String get shareInsertTop => 'Insert above';

  @override
  String get shareInsertBottom => 'Insert below';

  @override
  String shareInsertedSnack(String title) {
    return 'Text inserted into “$title”';
  }

  @override
  String get selectNotes => 'Select';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get selectAllNotes => 'Select all';

  @override
  String deleteNotesConfirm(int count) {
    return 'Delete $count notes?';
  }

  @override
  String notesMovedSnack(int count) {
    return '$count notes moved';
  }

  @override
  String notesArchivedSnack(int count) {
    return '$count notes archived';
  }

  @override
  String get versionHistory => 'Earlier versions';

  @override
  String get versionHistoryHint =>
      'Versions from the Google Drive history (the latest 30 per note)';

  @override
  String get versionHistoryEmpty => 'No earlier versions yet';

  @override
  String get versionHistoryFailed => 'Could not load the history';

  @override
  String get versionDeletedMarker => 'deleted';

  @override
  String get versionRestore => 'Restore';

  @override
  String versionRestoreConfirm(String date) {
    return 'Restore the version from $date? The current version stays in the history.';
  }

  @override
  String versionRestored(String date) {
    return 'Restored the version from $date';
  }

  @override
  String conflictDetected(String title) {
    return 'Conflict: “$title” was changed on two devices. Please check the earlier version.';
  }

  @override
  String conflictDetectedMulti(int count) {
    return 'Conflict: $count notes were changed on two devices. Please check the earlier versions.';
  }

  @override
  String get yesterday => 'Yesterday';

  @override
  String get pinned => 'Pinned';
}
