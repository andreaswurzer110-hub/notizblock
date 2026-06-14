import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

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
    Locale('en')
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
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

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
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
