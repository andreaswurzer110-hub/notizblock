import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_uk.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('ja'),
    Locale('nl'),
    Locale('pl'),
    Locale('pt'),
    Locale('ru'),
    Locale('tr'),
    Locale('uk'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In de, this message translates to:
  /// **'Notizblock AW'**
  String get appTitle;

  /// No description provided for @newNote.
  ///
  /// In de, this message translates to:
  /// **'Neue Notiz'**
  String get newNote;

  /// No description provided for @settings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get settings;

  /// No description provided for @search.
  ///
  /// In de, this message translates to:
  /// **'Suchen'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In de, this message translates to:
  /// **'Notizen durchsuchen...'**
  String get searchHint;

  /// No description provided for @delete.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get delete;

  /// No description provided for @deleteNote.
  ///
  /// In de, this message translates to:
  /// **'Notiz löschen'**
  String get deleteNote;

  /// No description provided for @deleteNoteConfirm.
  ///
  /// In de, this message translates to:
  /// **'Möchtest du diese Notiz wirklich löschen?'**
  String get deleteNoteConfirm;

  /// No description provided for @save.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancel;

  /// No description provided for @noNotes.
  ///
  /// In de, this message translates to:
  /// **'Keine Notizen'**
  String get noNotes;

  /// No description provided for @noNotesHint.
  ///
  /// In de, this message translates to:
  /// **'Tippe auf + um eine neue Notiz zu erstellen'**
  String get noNotesHint;

  /// No description provided for @noSearchResults.
  ///
  /// In de, this message translates to:
  /// **'Keine Ergebnisse'**
  String get noSearchResults;

  /// No description provided for @emptyNote.
  ///
  /// In de, this message translates to:
  /// **'Leere Notiz'**
  String get emptyNote;

  /// No description provided for @pin.
  ///
  /// In de, this message translates to:
  /// **'Anheften'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In de, this message translates to:
  /// **'Loslassen'**
  String get unpin;

  /// No description provided for @color.
  ///
  /// In de, this message translates to:
  /// **'Farbe'**
  String get color;

  /// No description provided for @archive.
  ///
  /// In de, this message translates to:
  /// **'Archivieren'**
  String get archive;

  /// No description provided for @titleHint.
  ///
  /// In de, this message translates to:
  /// **'Titel'**
  String get titleHint;

  /// No description provided for @contentHint.
  ///
  /// In de, this message translates to:
  /// **'Notiz schreiben...'**
  String get contentHint;

  /// No description provided for @createdAt.
  ///
  /// In de, this message translates to:
  /// **'Erstellt: {date}'**
  String createdAt(String date);

  /// No description provided for @modifiedAt.
  ///
  /// In de, this message translates to:
  /// **'Geändert: {date}'**
  String modifiedAt(String date);

  /// No description provided for @language.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In de, this message translates to:
  /// **'Design'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In de, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In de, this message translates to:
  /// **'Hell'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In de, this message translates to:
  /// **'Dunkel'**
  String get themeDark;

  /// No description provided for @defaultColor.
  ///
  /// In de, this message translates to:
  /// **'Standardfarbe'**
  String get defaultColor;

  /// No description provided for @googleDrive.
  ///
  /// In de, this message translates to:
  /// **'Google Drive'**
  String get googleDrive;

  /// No description provided for @signIn.
  ///
  /// In de, this message translates to:
  /// **'Anmelden'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In de, this message translates to:
  /// **'Abmelden'**
  String get signOut;

  /// No description provided for @signedInAs.
  ///
  /// In de, this message translates to:
  /// **'Angemeldet als {email}'**
  String signedInAs(String email);

  /// No description provided for @sync.
  ///
  /// In de, this message translates to:
  /// **'Synchronisieren'**
  String get sync;

  /// No description provided for @autoSync.
  ///
  /// In de, this message translates to:
  /// **'Automatisch synchronisieren'**
  String get autoSync;

  /// No description provided for @lastSync.
  ///
  /// In de, this message translates to:
  /// **'Letzte Sync: {date}'**
  String lastSync(String date);

  /// No description provided for @neverSynced.
  ///
  /// In de, this message translates to:
  /// **'Noch nie synchronisiert'**
  String get neverSynced;

  /// No description provided for @syncSuccess.
  ///
  /// In de, this message translates to:
  /// **'Synchronisierung erfolgreich'**
  String get syncSuccess;

  /// No description provided for @syncFailed.
  ///
  /// In de, this message translates to:
  /// **'Synchronisierung fehlgeschlagen'**
  String get syncFailed;

  /// No description provided for @uploaded.
  ///
  /// In de, this message translates to:
  /// **'{count} hochgeladen'**
  String uploaded(int count);

  /// No description provided for @downloaded.
  ///
  /// In de, this message translates to:
  /// **'{count} heruntergeladen'**
  String downloaded(int count);

  /// No description provided for @createBackup.
  ///
  /// In de, this message translates to:
  /// **'Backup erstellen'**
  String get createBackup;

  /// No description provided for @restoreBackup.
  ///
  /// In de, this message translates to:
  /// **'Backup wiederherstellen'**
  String get restoreBackup;

  /// No description provided for @restore.
  ///
  /// In de, this message translates to:
  /// **'Wiederherstellen'**
  String get restore;

  /// No description provided for @restoreConfirm.
  ///
  /// In de, this message translates to:
  /// **'Alle lokalen Notizen werden überschrieben. Fortfahren?'**
  String get restoreConfirm;

  /// No description provided for @backupSuccess.
  ///
  /// In de, this message translates to:
  /// **'Backup erfolgreich erstellt'**
  String get backupSuccess;

  /// No description provided for @backupFailed.
  ///
  /// In de, this message translates to:
  /// **'Backup fehlgeschlagen'**
  String get backupFailed;

  /// No description provided for @restoreSuccess.
  ///
  /// In de, this message translates to:
  /// **'Backup erfolgreich wiederhergestellt'**
  String get restoreSuccess;

  /// No description provided for @restoreFailed.
  ///
  /// In de, this message translates to:
  /// **'Wiederherstellung fehlgeschlagen'**
  String get restoreFailed;

  /// No description provided for @about.
  ///
  /// In de, this message translates to:
  /// **'Über'**
  String get about;

  /// No description provided for @version.
  ///
  /// In de, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @openInWindow.
  ///
  /// In de, this message translates to:
  /// **'In neuem Fenster öffnen'**
  String get openInWindow;

  /// No description provided for @pinAsWidget.
  ///
  /// In de, this message translates to:
  /// **'Als Widget anheften'**
  String get pinAsWidget;

  /// No description provided for @unpinWidget.
  ///
  /// In de, this message translates to:
  /// **'Widget lösen'**
  String get unpinWidget;

  /// No description provided for @syncNow.
  ///
  /// In de, this message translates to:
  /// **'Jetzt synchronisieren'**
  String get syncNow;

  /// No description provided for @autostart.
  ///
  /// In de, this message translates to:
  /// **'Automatisch starten'**
  String get autostart;

  /// No description provided for @autostartSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Widgets automatisch beim Systemstart öffnen'**
  String get autostartSubtitle;

  /// No description provided for @showMainWindow.
  ///
  /// In de, this message translates to:
  /// **'Hauptfenster beim Start öffnen'**
  String get showMainWindow;

  /// No description provided for @showMainWindowSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Standardmäßig öffnen sich nur die angehefteten Widgets'**
  String get showMainWindowSubtitle;

  /// No description provided for @fontSize.
  ///
  /// In de, this message translates to:
  /// **'Schriftgröße'**
  String get fontSize;

  /// No description provided for @fontSizeSample.
  ///
  /// In de, this message translates to:
  /// **'Beispieltext'**
  String get fontSizeSample;

  /// No description provided for @undo.
  ///
  /// In de, this message translates to:
  /// **'Rückgängig'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In de, this message translates to:
  /// **'Wiederholen'**
  String get redo;

  /// No description provided for @notSignedIn.
  ///
  /// In de, this message translates to:
  /// **'Nicht bei Google Drive angemeldet'**
  String get notSignedIn;

  /// No description provided for @archiveAndRestore.
  ///
  /// In de, this message translates to:
  /// **'Archiv & Wiederherstellen'**
  String get archiveAndRestore;

  /// No description provided for @archivedTab.
  ///
  /// In de, this message translates to:
  /// **'Archiviert'**
  String get archivedTab;

  /// No description provided for @deletedTab.
  ///
  /// In de, this message translates to:
  /// **'Gelöscht'**
  String get deletedTab;

  /// No description provided for @noArchivedNotes.
  ///
  /// In de, this message translates to:
  /// **'Keine archivierten Notizen'**
  String get noArchivedNotes;

  /// No description provided for @noDeletedNotes.
  ///
  /// In de, this message translates to:
  /// **'Keine gelöschten Notizen'**
  String get noDeletedNotes;

  /// No description provided for @deletedSignInHint.
  ///
  /// In de, this message translates to:
  /// **'Bei Google Drive anmelden, um gelöschte Notizen anzuzeigen'**
  String get deletedSignInHint;

  /// No description provided for @deletedLoadFailed.
  ///
  /// In de, this message translates to:
  /// **'Gelöschte Notizen konnten nicht geladen werden'**
  String get deletedLoadFailed;

  /// No description provided for @noteRestored.
  ///
  /// In de, this message translates to:
  /// **'Notiz wiederhergestellt'**
  String get noteRestored;

  /// No description provided for @deletedOn.
  ///
  /// In de, this message translates to:
  /// **'Gelöscht: {date}'**
  String deletedOn(String date);

  /// No description provided for @deletePermanently.
  ///
  /// In de, this message translates to:
  /// **'Endgültig löschen'**
  String get deletePermanently;

  /// No description provided for @deletePermanentlyConfirm.
  ///
  /// In de, this message translates to:
  /// **'Diese Notiz endgültig löschen? Das kann nicht rückgängig gemacht werden.'**
  String get deletePermanentlyConfirm;

  /// No description provided for @autopool.
  ///
  /// In de, this message translates to:
  /// **'Autopool'**
  String get autopool;

  /// No description provided for @createNoteTitle.
  ///
  /// In de, this message translates to:
  /// **'Was möchtest du erstellen?'**
  String get createNoteTitle;

  /// No description provided for @noteTypeNote.
  ///
  /// In de, this message translates to:
  /// **'Notiz'**
  String get noteTypeNote;

  /// No description provided for @noteTypeNoteSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Einfache Textnotiz'**
  String get noteTypeNoteSubtitle;

  /// No description provided for @noteTypeAutopoolSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Tabelle (Geräteliste)'**
  String get noteTypeAutopoolSubtitle;

  /// No description provided for @noteTypeShoppingSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Artikel abhaken, Mengen zählen'**
  String get noteTypeShoppingSubtitle;

  /// No description provided for @shoppingList.
  ///
  /// In de, this message translates to:
  /// **'Einkaufsliste'**
  String get shoppingList;

  /// No description provided for @shoppingItemHint.
  ///
  /// In de, this message translates to:
  /// **'Artikel'**
  String get shoppingItemHint;

  /// No description provided for @shoppingAddItem.
  ///
  /// In de, this message translates to:
  /// **'Artikel hinzufügen'**
  String get shoppingAddItem;

  /// No description provided for @shoppingCompleted.
  ///
  /// In de, this message translates to:
  /// **'Erledigt ({count})'**
  String shoppingCompleted(int count);

  /// No description provided for @shoppingDeleteItem.
  ///
  /// In de, this message translates to:
  /// **'Artikel löschen'**
  String get shoppingDeleteItem;

  /// No description provided for @shoppingOpenCount.
  ///
  /// In de, this message translates to:
  /// **'{open}/{total} offen'**
  String shoppingOpenCount(int open, int total);

  /// No description provided for @allNotes.
  ///
  /// In de, this message translates to:
  /// **'Alle Notizen'**
  String get allNotes;

  /// No description provided for @folders.
  ///
  /// In de, this message translates to:
  /// **'Ordner'**
  String get folders;

  /// No description provided for @newFolder.
  ///
  /// In de, this message translates to:
  /// **'Neuer Ordner'**
  String get newFolder;

  /// No description provided for @folderName.
  ///
  /// In de, this message translates to:
  /// **'Ordnername'**
  String get folderName;

  /// No description provided for @renameFolder.
  ///
  /// In de, this message translates to:
  /// **'Ordner umbenennen'**
  String get renameFolder;

  /// No description provided for @deleteFolder.
  ///
  /// In de, this message translates to:
  /// **'Ordner löschen'**
  String get deleteFolder;

  /// No description provided for @deleteFolderConfirm.
  ///
  /// In de, this message translates to:
  /// **'Ordner „{name}“ löschen? Die enthaltenen Notizen bleiben erhalten und sind dann keinem Ordner mehr zugeordnet.'**
  String deleteFolderConfirm(String name);

  /// No description provided for @moveToFolder.
  ///
  /// In de, this message translates to:
  /// **'In Ordner verschieben'**
  String get moveToFolder;

  /// No description provided for @noFolder.
  ///
  /// In de, this message translates to:
  /// **'Kein Ordner'**
  String get noFolder;

  /// No description provided for @addExistingNote.
  ///
  /// In de, this message translates to:
  /// **'Vorhandene Notiz hinzufügen'**
  String get addExistingNote;

  /// No description provided for @addNotesToFolderTitle.
  ///
  /// In de, this message translates to:
  /// **'Notizen zu „{folder}“ hinzufügen'**
  String addNotesToFolderTitle(String folder);

  /// No description provided for @addedToFolderSnack.
  ///
  /// In de, this message translates to:
  /// **'Zu „{folder}“ hinzugefügt'**
  String addedToFolderSnack(String folder);

  /// No description provided for @removedFromFolderSnack.
  ///
  /// In de, this message translates to:
  /// **'Aus Ordner entfernt'**
  String get removedFromFolderSnack;

  /// No description provided for @noNotesToAdd.
  ///
  /// In de, this message translates to:
  /// **'Keine weiteren Notizen zum Hinzufügen'**
  String get noNotesToAdd;

  /// No description provided for @add.
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen'**
  String get add;

  /// No description provided for @autopoolColName.
  ///
  /// In de, this message translates to:
  /// **'Bezeichnung'**
  String get autopoolColName;

  /// No description provided for @autopoolColOfficeVersion.
  ///
  /// In de, this message translates to:
  /// **'DS & Version'**
  String get autopoolColOfficeVersion;

  /// No description provided for @autopoolColLocation.
  ///
  /// In de, this message translates to:
  /// **'Ort'**
  String get autopoolColLocation;

  /// No description provided for @autopoolColInventory.
  ///
  /// In de, this message translates to:
  /// **'Inventarnummer'**
  String get autopoolColInventory;

  /// No description provided for @autopoolColSerial.
  ///
  /// In de, this message translates to:
  /// **'Seriennummer'**
  String get autopoolColSerial;

  /// No description provided for @autopoolColDate.
  ///
  /// In de, this message translates to:
  /// **'Datum'**
  String get autopoolColDate;

  /// No description provided for @autopoolAddRow.
  ///
  /// In de, this message translates to:
  /// **'Zeile hinzufügen'**
  String get autopoolAddRow;

  /// No description provided for @autopoolAddRowFull.
  ///
  /// In de, this message translates to:
  /// **'Volle Zeile (6 Felder)'**
  String get autopoolAddRowFull;

  /// No description provided for @autopoolAddRow4.
  ///
  /// In de, this message translates to:
  /// **'Kurze Zeile (4 Felder)'**
  String get autopoolAddRow4;

  /// No description provided for @autopoolAddRow2.
  ///
  /// In de, this message translates to:
  /// **'Kurze Zeile (2 Felder)'**
  String get autopoolAddRow2;

  /// No description provided for @autopoolMoveRow.
  ///
  /// In de, this message translates to:
  /// **'Verschieben'**
  String get autopoolMoveRow;

  /// No description provided for @autopoolDeleteRow.
  ///
  /// In de, this message translates to:
  /// **'Zeile löschen'**
  String get autopoolDeleteRow;

  /// No description provided for @autopoolMarkRow.
  ///
  /// In de, this message translates to:
  /// **'Markieren / Markierung entfernen'**
  String get autopoolMarkRow;

  /// No description provided for @autopoolRowColor.
  ///
  /// In de, this message translates to:
  /// **'Zeilenfarbe'**
  String get autopoolRowColor;

  /// No description provided for @autopoolNoColor.
  ///
  /// In de, this message translates to:
  /// **'Keine Farbe'**
  String get autopoolNoColor;

  /// No description provided for @autopoolRenameColumn.
  ///
  /// In de, this message translates to:
  /// **'Spalte umbenennen'**
  String get autopoolRenameColumn;

  /// No description provided for @autopoolResetColumn.
  ///
  /// In de, this message translates to:
  /// **'Auf Standard zurücksetzen'**
  String get autopoolResetColumn;

  /// No description provided for @autopoolColumnLabel.
  ///
  /// In de, this message translates to:
  /// **'Spaltenname'**
  String get autopoolColumnLabel;

  /// No description provided for @moveUp.
  ///
  /// In de, this message translates to:
  /// **'Nach oben'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In de, this message translates to:
  /// **'Nach unten'**
  String get moveDown;

  /// No description provided for @openLink.
  ///
  /// In de, this message translates to:
  /// **'Link öffnen'**
  String get openLink;

  /// No description provided for @searchWeb.
  ///
  /// In de, this message translates to:
  /// **'Im Web suchen'**
  String get searchWeb;

  /// No description provided for @linkOpenFailed.
  ///
  /// In de, this message translates to:
  /// **'Link konnte nicht geöffnet werden'**
  String get linkOpenFailed;

  /// No description provided for @ctxCut.
  ///
  /// In de, this message translates to:
  /// **'cut'**
  String get ctxCut;

  /// No description provided for @ctxPaste.
  ///
  /// In de, this message translates to:
  /// **'Einfügen'**
  String get ctxPaste;

  /// No description provided for @readOnly.
  ///
  /// In de, this message translates to:
  /// **'Nur Lesen'**
  String get readOnly;

  /// No description provided for @creator.
  ///
  /// In de, this message translates to:
  /// **'Ersteller'**
  String get creator;

  /// No description provided for @feedback.
  ///
  /// In de, this message translates to:
  /// **'Feedback und Fragen'**
  String get feedback;

  /// No description provided for @close.
  ///
  /// In de, this message translates to:
  /// **'Schließen'**
  String get close;

  /// No description provided for @bibleVerse1Ref.
  ///
  /// In de, this message translates to:
  /// **'Kolosser 3,17'**
  String get bibleVerse1Ref;

  /// No description provided for @bibleVerse1Text.
  ///
  /// In de, this message translates to:
  /// **'Und was immer ihr tut in Wort oder Werk, das tut alles im Namen des Herrn Jesus und dankt Gott, dem Vater, durch ihn.'**
  String get bibleVerse1Text;

  /// No description provided for @bibleVerse2Ref.
  ///
  /// In de, this message translates to:
  /// **'Johannes 14,6'**
  String get bibleVerse2Ref;

  /// No description provided for @bibleVerse2Text.
  ///
  /// In de, this message translates to:
  /// **'Jesus spricht zu ihm: Ich bin der Weg und die Wahrheit und das Leben; niemand kommt zum Vater als nur durch mich!'**
  String get bibleVerse2Text;

  /// No description provided for @printExport.
  ///
  /// In de, this message translates to:
  /// **'Drucken'**
  String get printExport;

  /// No description provided for @printExportTitle.
  ///
  /// In de, this message translates to:
  /// **'Drucken & Exportieren'**
  String get printExportTitle;

  /// No description provided for @printSystem.
  ///
  /// In de, this message translates to:
  /// **'Drucken'**
  String get printSystem;

  /// No description provided for @printSystemSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Systemdialog (Drucker/PDF)'**
  String get printSystemSubtitle;

  /// No description provided for @exportPdf.
  ///
  /// In de, this message translates to:
  /// **'Als PDF speichern'**
  String get exportPdf;

  /// No description provided for @exportTxt.
  ///
  /// In de, this message translates to:
  /// **'Als Textdatei speichern'**
  String get exportTxt;

  /// No description provided for @exportWord.
  ///
  /// In de, this message translates to:
  /// **'Als Word-Dokument speichern'**
  String get exportWord;

  /// No description provided for @exportSaved.
  ///
  /// In de, this message translates to:
  /// **'Gespeichert: {file}'**
  String exportSaved(String file);

  /// No description provided for @exportFailed.
  ///
  /// In de, this message translates to:
  /// **'Export fehlgeschlagen: {error}'**
  String exportFailed(String error);

  /// No description provided for @shareImportTitle.
  ///
  /// In de, this message translates to:
  /// **'Text übernehmen'**
  String get shareImportTitle;

  /// No description provided for @shareImportNewNote.
  ///
  /// In de, this message translates to:
  /// **'In neue Notiz'**
  String get shareImportNewNote;

  /// No description provided for @shareImportNewNoteSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Legt eine neue Notiz mit dem Text an'**
  String get shareImportNewNoteSubtitle;

  /// No description provided for @shareImportExisting.
  ///
  /// In de, this message translates to:
  /// **'In bestehende Notiz'**
  String get shareImportExisting;

  /// No description provided for @shareImportExistingSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Text in eine vorhandene Notiz einfügen'**
  String get shareImportExistingSubtitle;

  /// No description provided for @shareImportChooseNote.
  ///
  /// In de, this message translates to:
  /// **'Notiz auswählen'**
  String get shareImportChooseNote;

  /// No description provided for @shareInsertPositionTitle.
  ///
  /// In de, this message translates to:
  /// **'Wo einfügen?'**
  String get shareInsertPositionTitle;

  /// No description provided for @shareInsertTop.
  ///
  /// In de, this message translates to:
  /// **'Oberhalb einfügen'**
  String get shareInsertTop;

  /// No description provided for @shareInsertBottom.
  ///
  /// In de, this message translates to:
  /// **'Unterhalb einfügen'**
  String get shareInsertBottom;

  /// No description provided for @shareInsertedSnack.
  ///
  /// In de, this message translates to:
  /// **'Text in „{title}“ eingefügt'**
  String shareInsertedSnack(String title);

  /// No description provided for @selectNotes.
  ///
  /// In de, this message translates to:
  /// **'Auswählen'**
  String get selectNotes;

  /// No description provided for @selectedCount.
  ///
  /// In de, this message translates to:
  /// **'{count} ausgewählt'**
  String selectedCount(int count);

  /// No description provided for @selectAllNotes.
  ///
  /// In de, this message translates to:
  /// **'Alle auswählen'**
  String get selectAllNotes;

  /// No description provided for @deleteNotesConfirm.
  ///
  /// In de, this message translates to:
  /// **'Sollen {count} Notizen wirklich gelöscht werden?'**
  String deleteNotesConfirm(int count);

  /// No description provided for @notesMovedSnack.
  ///
  /// In de, this message translates to:
  /// **'{count} Notizen verschoben'**
  String notesMovedSnack(int count);

  /// No description provided for @notesArchivedSnack.
  ///
  /// In de, this message translates to:
  /// **'{count} Notizen archiviert'**
  String notesArchivedSnack(int count);

  /// No description provided for @versionHistory.
  ///
  /// In de, this message translates to:
  /// **'Frühere Versionen'**
  String get versionHistory;

  /// No description provided for @versionHistoryHint.
  ///
  /// In de, this message translates to:
  /// **'Stände aus dem Google-Drive-Verlauf (die neuesten 30 je Notiz)'**
  String get versionHistoryHint;

  /// No description provided for @versionHistoryEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine früheren Versionen vorhanden'**
  String get versionHistoryEmpty;

  /// No description provided for @versionHistoryFailed.
  ///
  /// In de, this message translates to:
  /// **'Verlauf konnte nicht geladen werden'**
  String get versionHistoryFailed;

  /// No description provided for @versionDeletedMarker.
  ///
  /// In de, this message translates to:
  /// **'gelöscht'**
  String get versionDeletedMarker;

  /// No description provided for @versionRestore.
  ///
  /// In de, this message translates to:
  /// **'Wiederherstellen'**
  String get versionRestore;

  /// No description provided for @versionRestoreConfirm.
  ///
  /// In de, this message translates to:
  /// **'Stand vom {date} wiederherstellen? Der aktuelle Stand bleibt im Verlauf erhalten.'**
  String versionRestoreConfirm(String date);

  /// No description provided for @versionRestored.
  ///
  /// In de, this message translates to:
  /// **'Stand vom {date} wiederhergestellt'**
  String versionRestored(String date);

  /// No description provided for @conflictDetected.
  ///
  /// In de, this message translates to:
  /// **'Konflikt: „{title}“ wurde auf zwei Geräten geändert. Bitte die frühere Version prüfen.'**
  String conflictDetected(String title);

  /// No description provided for @conflictDetectedMulti.
  ///
  /// In de, this message translates to:
  /// **'Konflikt: {count} Notizen wurden auf zwei Geräten geändert. Bitte die früheren Versionen prüfen.'**
  String conflictDetectedMulti(int count);

  /// No description provided for @yesterday.
  ///
  /// In de, this message translates to:
  /// **'Gestern'**
  String get yesterday;

  /// No description provided for @pinned.
  ///
  /// In de, this message translates to:
  /// **'Angeheftet'**
  String get pinned;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'de',
        'en',
        'es',
        'fr',
        'it',
        'ja',
        'nl',
        'pl',
        'pt',
        'ru',
        'tr',
        'uk',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'nl':
      return AppLocalizationsNl();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
    case 'uk':
      return AppLocalizationsUk();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
