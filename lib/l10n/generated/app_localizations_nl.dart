// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get appTitle => 'Notizblock AW';

  @override
  String get newNote => 'Nieuwe notitie';

  @override
  String get settings => 'Instellingen';

  @override
  String get search => 'Zoeken';

  @override
  String get searchHint => 'Notities zoeken...';

  @override
  String get delete => 'Verwijderen';

  @override
  String get deleteNote => 'Notitie verwijderen';

  @override
  String get deleteNoteConfirm => 'Wil je deze notitie echt verwijderen?';

  @override
  String get save => 'Opslaan';

  @override
  String get cancel => 'Annuleren';

  @override
  String get noNotes => 'Geen notities';

  @override
  String get noNotesHint => 'Tik op + voor een nieuwe notitie';

  @override
  String get noSearchResults => 'Geen resultaten';

  @override
  String get emptyNote => 'Lege notitie';

  @override
  String get pin => 'Vastzetten';

  @override
  String get unpin => 'Losmaken';

  @override
  String get color => 'Kleur';

  @override
  String get archive => 'Archiveren';

  @override
  String get titleHint => 'Titel';

  @override
  String get contentHint => 'Schrijf een notitie...';

  @override
  String createdAt(String date) {
    return 'Gemaakt: $date';
  }

  @override
  String modifiedAt(String date) {
    return 'Gewijzigd: $date';
  }

  @override
  String get language => 'Taal';

  @override
  String get theme => 'Thema';

  @override
  String get themeSystem => 'Systeem';

  @override
  String get themeLight => 'Licht';

  @override
  String get themeDark => 'Donker';

  @override
  String get defaultColor => 'Standaardkleur';

  @override
  String get googleDrive => 'Google Drive';

  @override
  String get signIn => 'Aanmelden';

  @override
  String get signOut => 'Afmelden';

  @override
  String signedInAs(String email) {
    return 'Aangemeld als $email';
  }

  @override
  String get sync => 'Synchroniseren';

  @override
  String get autoSync => 'Automatisch synchroniseren';

  @override
  String lastSync(String date) {
    return 'Laatste synchronisatie: $date';
  }

  @override
  String get neverSynced => 'Nog nooit gesynchroniseerd';

  @override
  String get syncSuccess => 'Synchronisatie gelukt';

  @override
  String get syncFailed => 'Synchronisatie mislukt';

  @override
  String uploaded(int count) {
    return '$count geüpload';
  }

  @override
  String downloaded(int count) {
    return '$count opgehaald';
  }

  @override
  String get createBackup => 'Back-up maken';

  @override
  String get restoreBackup => 'Back-up terugzetten';

  @override
  String get restore => 'Terugzetten';

  @override
  String get restoreConfirm =>
      'Alle lokale notities worden overschreven. Doorgaan?';

  @override
  String get backupSuccess => 'Back-up gemaakt';

  @override
  String get backupFailed => 'Back-up mislukt';

  @override
  String get restoreSuccess => 'Back-up teruggezet';

  @override
  String get restoreFailed => 'Terugzetten mislukt';

  @override
  String get about => 'Over';

  @override
  String get version => 'Versie';

  @override
  String get openInWindow => 'In nieuw venster openen';

  @override
  String get pinAsWidget => 'Als widget vastzetten';

  @override
  String get unpinWidget => 'Widget losmaken';

  @override
  String get syncNow => 'Nu synchroniseren';

  @override
  String get autostart => 'Automatisch starten';

  @override
  String get autostartSubtitle =>
      'Widgets openen bij het opstarten van het systeem';

  @override
  String get showMainWindow => 'Hoofdvenster openen bij het opstarten';

  @override
  String get showMainWindowSubtitle =>
      'Standaard openen alleen de vastgezette widgets';

  @override
  String get fontSize => 'Tekstgrootte';

  @override
  String get fontSizeSample => 'Voorbeeldtekst';

  @override
  String get undo => 'Ongedaan maken';

  @override
  String get redo => 'Opnieuw';

  @override
  String get notSignedIn => 'Niet aangemeld bij Google Drive';

  @override
  String get archiveAndRestore => 'Archief en terugzetten';

  @override
  String get archivedTab => 'Gearchiveerd';

  @override
  String get deletedTab => 'Verwijderd';

  @override
  String get noArchivedNotes => 'Geen gearchiveerde notities';

  @override
  String get noDeletedNotes => 'Geen verwijderde notities';

  @override
  String get deletedSignInHint =>
      'Meld je aan bij Google Drive om verwijderde notities te zien';

  @override
  String get deletedLoadFailed =>
      'Verwijderde notities konden niet worden geladen';

  @override
  String get noteRestored => 'Notitie teruggezet';

  @override
  String deletedOn(String date) {
    return 'Verwijderd: $date';
  }

  @override
  String get deletePermanently => 'Definitief verwijderen';

  @override
  String get deletePermanentlyConfirm =>
      'Deze notitie definitief verwijderen? Dit kan niet ongedaan worden gemaakt.';

  @override
  String get autopool => 'Autopool';

  @override
  String get createNoteTitle => 'Wat wil je maken?';

  @override
  String get noteTypeNote => 'Notitie';

  @override
  String get noteTypeNoteSubtitle => 'Eenvoudige tekstnotitie';

  @override
  String get noteTypeAutopoolSubtitle => 'Tabel (apparatenlijst)';

  @override
  String get noteTypeShoppingSubtitle => 'Items afvinken, aantallen tellen';

  @override
  String get shoppingList => 'Boodschappenlijst';

  @override
  String get shoppingItemHint => 'Artikel';

  @override
  String get shoppingAddItem => 'Artikel toevoegen';

  @override
  String shoppingCompleted(int count) {
    return 'Afgerond ($count)';
  }

  @override
  String get shoppingDeleteItem => 'Artikel verwijderen';

  @override
  String get shoppingSortAZ => 'Alfabetisch sorteren (A–Z)';

  @override
  String get shoppingSortZA => 'Alfabetisch sorteren (Z–A)';

  @override
  String shoppingOpenCount(int open, int total) {
    return '$open/$total open';
  }

  @override
  String get allNotes => 'Alle notities';

  @override
  String get folders => 'Mappen';

  @override
  String get newFolder => 'Nieuwe map';

  @override
  String get folderName => 'Mapnaam';

  @override
  String get renameFolder => 'Map hernoemen';

  @override
  String get deleteFolder => 'Map verwijderen';

  @override
  String deleteFolderConfirm(String name) {
    return 'Map “$name” verwijderen? De notities blijven bestaan en horen daarna bij geen map meer.';
  }

  @override
  String get moveToFolder => 'Naar map verplaatsen';

  @override
  String get noFolder => 'Geen map';

  @override
  String get addExistingNote => 'Bestaande notitie toevoegen';

  @override
  String addNotesToFolderTitle(String folder) {
    return 'Notities toevoegen aan “$folder”';
  }

  @override
  String addedToFolderSnack(String folder) {
    return 'Toegevoegd aan “$folder”';
  }

  @override
  String get removedFromFolderSnack => 'Uit de map gehaald';

  @override
  String get noNotesToAdd => 'Geen andere notities om toe te voegen';

  @override
  String get add => 'Toevoegen';

  @override
  String get autopoolColName => 'Omschrijving';

  @override
  String get autopoolColOfficeVersion => 'Afd. en versie';

  @override
  String get autopoolColLocation => 'Locatie';

  @override
  String get autopoolColInventory => 'Inventarisnr.';

  @override
  String get autopoolColSerial => 'Serienummer';

  @override
  String get autopoolColDate => 'Datum';

  @override
  String get autopoolAddRow => 'Rij toevoegen';

  @override
  String get autopoolAddRowFull => 'Volledige rij (6 velden)';

  @override
  String get autopoolAddRow4 => 'Korte rij (4 velden)';

  @override
  String get autopoolAddRow2 => 'Korte rij (2 velden)';

  @override
  String get autopoolMoveRow => 'Verplaatsen';

  @override
  String get autopoolDeleteRow => 'Rij verwijderen';

  @override
  String get autopoolMarkRow => 'Markeren / markering opheffen';

  @override
  String get autopoolRowColor => 'Rijkleur';

  @override
  String get autopoolNoColor => 'Geen kleur';

  @override
  String get autopoolRenameColumn => 'Kolom hernoemen';

  @override
  String get autopoolResetColumn => 'Terug naar standaard';

  @override
  String get autopoolColumnLabel => 'Kolomnaam';

  @override
  String get moveUp => 'Omhoog';

  @override
  String get moveDown => 'Omlaag';

  @override
  String get openLink => 'Link openen';

  @override
  String get searchWeb => 'Op het web zoeken';

  @override
  String get linkOpenFailed => 'Link kon niet worden geopend';

  @override
  String get ctxCut => 'Knippen';

  @override
  String get ctxPaste => 'Plakken';

  @override
  String get readOnly => 'Alleen lezen';

  @override
  String get creator => 'Maker';

  @override
  String get toolsUsed => 'Gebruikte hulpmiddelen';

  @override
  String get aiNotice =>
      'Deze app is ontwikkeld met hulp van kunstmatige intelligentie (Claude Code). Delen van de code en de teksten zijn AI-gegenereerd en door de maker gecontroleerd.';

  @override
  String get feedback => 'Feedback en vragen';

  @override
  String get close => 'Sluiten';

  @override
  String get bibleVerse1Ref => 'Kolossenzen 3:17';

  @override
  String get bibleVerse1Text =>
      'En al wat gij doet met woorden of met werken, doet het alles in den Naam van den Heere Jezus, dankende God en den Vader door Hem.';

  @override
  String get bibleVerse2Ref => 'Johannes 14:6';

  @override
  String get bibleVerse2Text =>
      'Jezus zeide tot hem: Ik ben de Weg, en de Waarheid, en het Leven. Niemand komt tot den Vader, dan door Mij.';

  @override
  String get printExport => 'Afdrukken';

  @override
  String get printExportTitle => 'Afdrukken en exporteren';

  @override
  String get printSystem => 'Afdrukken';

  @override
  String get printSystemSubtitle => 'Systeemvenster (printer/PDF)';

  @override
  String get exportPdf => 'Opslaan als PDF';

  @override
  String get exportTxt => 'Opslaan als tekstbestand';

  @override
  String get exportWord => 'Opslaan als Word-document';

  @override
  String exportSaved(String file) {
    return 'Opgeslagen: $file';
  }

  @override
  String exportFailed(String error) {
    return 'Exporteren mislukt: $error';
  }

  @override
  String get shareImportTitle => 'Gedeelde tekst toevoegen';

  @override
  String get shareImportNewNote => 'In een nieuwe notitie';

  @override
  String get shareImportNewNoteSubtitle =>
      'Maakt een nieuwe notitie met de tekst';

  @override
  String get shareImportExisting => 'In een bestaande notitie';

  @override
  String get shareImportExistingSubtitle =>
      'De tekst in een bestaande notitie invoegen';

  @override
  String get shareImportChooseNote => 'Notitie kiezen';

  @override
  String get shareInsertPositionTitle => 'Waar invoegen?';

  @override
  String get shareInsertTop => 'Erboven invoegen';

  @override
  String get shareInsertBottom => 'Eronder invoegen';

  @override
  String shareInsertedSnack(String title) {
    return 'Tekst ingevoegd in “$title”';
  }

  @override
  String get selectNotes => 'Selecteren';

  @override
  String selectedCount(int count) {
    return '$count geselecteerd';
  }

  @override
  String get selectAllNotes => 'Alles selecteren';

  @override
  String deleteNotesConfirm(int count) {
    return '$count notities verwijderen?';
  }

  @override
  String notesMovedSnack(int count) {
    return '$count notities verplaatst';
  }

  @override
  String notesArchivedSnack(int count) {
    return '$count notities gearchiveerd';
  }

  @override
  String get versionHistory => 'Eerdere versies';

  @override
  String get versionHistoryHint =>
      'Versies uit de Google Drive-geschiedenis (de 30 nieuwste per notitie)';

  @override
  String get versionHistoryEmpty => 'Nog geen eerdere versies';

  @override
  String get versionHistoryFailed => 'Geschiedenis kon niet worden geladen';

  @override
  String get versionDeletedMarker => 'verwijderd';

  @override
  String get versionRestore => 'Terugzetten';

  @override
  String versionRestoreConfirm(String date) {
    return 'De versie van $date terugzetten? De huidige versie blijft in de geschiedenis staan.';
  }

  @override
  String versionRestored(String date) {
    return 'Versie van $date teruggezet';
  }

  @override
  String conflictDetected(String title) {
    return 'Conflict: “$title” is op twee apparaten gewijzigd. Bekijk de eerdere versie.';
  }

  @override
  String conflictDetectedMulti(int count) {
    return 'Conflict: $count notities zijn op twee apparaten gewijzigd. Bekijk de eerdere versies.';
  }

  @override
  String get yesterday => 'Gisteren';

  @override
  String get pinned => 'Vastgezet';
}
