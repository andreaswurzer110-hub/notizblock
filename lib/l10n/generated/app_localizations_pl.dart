// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Notizblock AW';

  @override
  String get newNote => 'Nowa notatka';

  @override
  String get settings => 'Ustawienia';

  @override
  String get search => 'Szukaj';

  @override
  String get searchHint => 'Szukaj notatek...';

  @override
  String get delete => 'Usuń';

  @override
  String get deleteNote => 'Usuń notatkę';

  @override
  String get deleteNoteConfirm => 'Czy na pewno usunąć tę notatkę?';

  @override
  String get save => 'Zapisz';

  @override
  String get cancel => 'Anuluj';

  @override
  String get noNotes => 'Brak notatek';

  @override
  String get noNotesHint => 'Dotknij +, aby utworzyć notatkę';

  @override
  String get noSearchResults => 'Brak wyników';

  @override
  String get emptyNote => 'Pusta notatka';

  @override
  String get pin => 'Przypnij';

  @override
  String get unpin => 'Odepnij';

  @override
  String get color => 'Kolor';

  @override
  String get archive => 'Archiwizuj';

  @override
  String get titleHint => 'Tytuł';

  @override
  String get contentHint => 'Napisz notatkę...';

  @override
  String createdAt(String date) {
    return 'Utworzono: $date';
  }

  @override
  String modifiedAt(String date) {
    return 'Zmieniono: $date';
  }

  @override
  String get language => 'Język';

  @override
  String get theme => 'Motyw';

  @override
  String get themeSystem => 'Systemowy';

  @override
  String get themeLight => 'Jasny';

  @override
  String get themeDark => 'Ciemny';

  @override
  String get defaultColor => 'Kolor domyślny';

  @override
  String get googleDrive => 'Google Drive';

  @override
  String get signIn => 'Zaloguj się';

  @override
  String get signOut => 'Wyloguj się';

  @override
  String signedInAs(String email) {
    return 'Zalogowano jako $email';
  }

  @override
  String get sync => 'Synchronizuj';

  @override
  String get autoSync => 'Synchronizacja automatyczna';

  @override
  String lastSync(String date) {
    return 'Ostatnia synchronizacja: $date';
  }

  @override
  String get neverSynced => 'Nigdy nie synchronizowano';

  @override
  String get syncSuccess => 'Synchronizacja zakończona';

  @override
  String get syncFailed => 'Synchronizacja nie powiodła się';

  @override
  String uploaded(int count) {
    return 'Wysłano: $count';
  }

  @override
  String downloaded(int count) {
    return 'Pobrano: $count';
  }

  @override
  String get createBackup => 'Utwórz kopię zapasową';

  @override
  String get restoreBackup => 'Przywróć kopię zapasową';

  @override
  String get restore => 'Przywróć';

  @override
  String get restoreConfirm =>
      'Wszystkie notatki lokalne zostaną nadpisane. Kontynuować?';

  @override
  String get backupSuccess => 'Kopia zapasowa utworzona';

  @override
  String get backupFailed => 'Nie udało się utworzyć kopii zapasowej';

  @override
  String get restoreSuccess => 'Kopia zapasowa przywrócona';

  @override
  String get restoreFailed => 'Przywracanie nie powiodło się';

  @override
  String get about => 'O aplikacji';

  @override
  String get version => 'Wersja';

  @override
  String get openInWindow => 'Otwórz w nowym oknie';

  @override
  String get pinAsWidget => 'Przypnij jako widżet';

  @override
  String get unpinWidget => 'Odepnij widżet';

  @override
  String get syncNow => 'Synchronizuj teraz';

  @override
  String get autostart => 'Uruchamiaj automatycznie';

  @override
  String get autostartSubtitle => 'Otwieraj widżety przy starcie systemu';

  @override
  String get showMainWindow => 'Otwieraj okno główne przy starcie';

  @override
  String get showMainWindowSubtitle =>
      'Domyślnie otwierają się tylko przypięte widżety';

  @override
  String get fontSize => 'Rozmiar czcionki';

  @override
  String get fontSizeSample => 'Tekst przykładowy';

  @override
  String get undo => 'Cofnij';

  @override
  String get redo => 'Ponów';

  @override
  String get notSignedIn => 'Brak połączenia z Google Drive';

  @override
  String get archiveAndRestore => 'Archiwum i przywracanie';

  @override
  String get archivedTab => 'Zarchiwizowane';

  @override
  String get deletedTab => 'Usunięte';

  @override
  String get noArchivedNotes => 'Brak zarchiwizowanych notatek';

  @override
  String get noDeletedNotes => 'Brak usuniętych notatek';

  @override
  String get deletedSignInHint =>
      'Zaloguj się do Google Drive, aby zobaczyć usunięte notatki';

  @override
  String get deletedLoadFailed => 'Nie udało się wczytać usuniętych notatek';

  @override
  String get noteRestored => 'Notatka przywrócona';

  @override
  String deletedOn(String date) {
    return 'Usunięto: $date';
  }

  @override
  String get deletePermanently => 'Usuń trwale';

  @override
  String get deletePermanentlyConfirm =>
      'Usunąć tę notatkę trwale? Tej operacji nie można cofnąć.';

  @override
  String get autopool => 'Autopool';

  @override
  String get createNoteTitle => 'Co chcesz utworzyć?';

  @override
  String get noteTypeNote => 'Notatka';

  @override
  String get noteTypeNoteSubtitle => 'Zwykła notatka tekstowa';

  @override
  String get noteTypeAutopoolSubtitle => 'Tabela (lista urządzeń)';

  @override
  String get noteTypeShoppingSubtitle => 'Odhaczaj pozycje, licz ilości';

  @override
  String get shoppingList => 'Lista zakupów';

  @override
  String get shoppingItemHint => 'Pozycja';

  @override
  String get shoppingAddItem => 'Dodaj pozycję';

  @override
  String shoppingCompleted(int count) {
    return 'Zrobione ($count)';
  }

  @override
  String get shoppingDeleteItem => 'Usuń pozycję';

  @override
  String get shoppingSortAZ => 'Sortuj alfabetycznie (A–Z)';

  @override
  String get shoppingSortZA => 'Sortuj alfabetycznie (Z–A)';

  @override
  String shoppingOpenCount(int open, int total) {
    return '$open/$total do zrobienia';
  }

  @override
  String get allNotes => 'Wszystkie notatki';

  @override
  String get folders => 'Foldery';

  @override
  String get newFolder => 'Nowy folder';

  @override
  String get folderName => 'Nazwa folderu';

  @override
  String get renameFolder => 'Zmień nazwę folderu';

  @override
  String get deleteFolder => 'Usuń folder';

  @override
  String deleteFolderConfirm(String name) {
    return 'Usunąć folder „$name”? Notatki zostaną zachowane i nie będą już w żadnym folderze.';
  }

  @override
  String get moveToFolder => 'Przenieś do folderu';

  @override
  String get noFolder => 'Bez folderu';

  @override
  String get addExistingNote => 'Dodaj istniejącą notatkę';

  @override
  String addNotesToFolderTitle(String folder) {
    return 'Dodaj notatki do „$folder”';
  }

  @override
  String addedToFolderSnack(String folder) {
    return 'Dodano do „$folder”';
  }

  @override
  String get removedFromFolderSnack => 'Usunięto z folderu';

  @override
  String get noNotesToAdd => 'Brak innych notatek do dodania';

  @override
  String get add => 'Dodaj';

  @override
  String get autopoolColName => 'Nazwa';

  @override
  String get autopoolColOfficeVersion => 'Dział i wersja';

  @override
  String get autopoolColLocation => 'Miejsce';

  @override
  String get autopoolColInventory => 'Nr inwentarzowy';

  @override
  String get autopoolColSerial => 'Numer seryjny';

  @override
  String get autopoolColDate => 'Data';

  @override
  String get autopoolAddRow => 'Dodaj wiersz';

  @override
  String get autopoolAddRowFull => 'Pełny wiersz (6 pól)';

  @override
  String get autopoolAddRow4 => 'Krótki wiersz (4 pola)';

  @override
  String get autopoolAddRow2 => 'Krótki wiersz (2 pola)';

  @override
  String get autopoolMoveRow => 'Przenieś';

  @override
  String get autopoolDeleteRow => 'Usuń wiersz';

  @override
  String get autopoolMarkRow => 'Zaznacz / usuń zaznaczenie';

  @override
  String get autopoolRowColor => 'Kolor wiersza';

  @override
  String get autopoolNoColor => 'Bez koloru';

  @override
  String get autopoolRenameColumn => 'Zmień nazwę kolumny';

  @override
  String get autopoolResetColumn => 'Przywróć domyślną';

  @override
  String get autopoolColumnLabel => 'Nazwa kolumny';

  @override
  String get moveUp => 'W górę';

  @override
  String get moveDown => 'W dół';

  @override
  String get openLink => 'Otwórz link';

  @override
  String get searchWeb => 'Szukaj w sieci';

  @override
  String get linkOpenFailed => 'Nie udało się otworzyć linku';

  @override
  String get ctxCut => 'Wytnij';

  @override
  String get ctxPaste => 'Wklej';

  @override
  String get readOnly => 'Tylko do odczytu';

  @override
  String get creator => 'Autor';

  @override
  String get feedback => 'Opinie i pytania';

  @override
  String get close => 'Zamknij';

  @override
  String get bibleVerse1Ref => 'Kolosan 3:17';

  @override
  String get bibleVerse1Text =>
      'A wszystko, cokolwiek czynicie w słowie albo w uczynku, wszystko czyńcie w imieniu Pana Jezusa, dziękując Bogu Ojcu przez niego.';

  @override
  String get bibleVerse2Ref => 'Jana 14:6';

  @override
  String get bibleVerse2Text =>
      'Rzekł mu Jezus: Jam jest droga i prawda, i żywot; nikt nie przychodzi do Ojca, tylko przeze mnie.';

  @override
  String get printExport => 'Drukuj';

  @override
  String get printExportTitle => 'Drukowanie i eksport';

  @override
  String get printSystem => 'Drukuj';

  @override
  String get printSystemSubtitle => 'Okno systemowe (drukarka/PDF)';

  @override
  String get exportPdf => 'Zapisz jako PDF';

  @override
  String get exportTxt => 'Zapisz jako plik tekstowy';

  @override
  String get exportWord => 'Zapisz jako dokument Word';

  @override
  String exportSaved(String file) {
    return 'Zapisano: $file';
  }

  @override
  String exportFailed(String error) {
    return 'Eksport nie powiódł się: $error';
  }

  @override
  String get shareImportTitle => 'Dodaj udostępniony tekst';

  @override
  String get shareImportNewNote => 'Do nowej notatki';

  @override
  String get shareImportNewNoteSubtitle => 'Tworzy nową notatkę z tym tekstem';

  @override
  String get shareImportExisting => 'Do istniejącej notatki';

  @override
  String get shareImportExistingSubtitle =>
      'Wstaw tekst do istniejącej notatki';

  @override
  String get shareImportChooseNote => 'Wybierz notatkę';

  @override
  String get shareInsertPositionTitle => 'Gdzie wstawić?';

  @override
  String get shareInsertTop => 'Wstaw powyżej';

  @override
  String get shareInsertBottom => 'Wstaw poniżej';

  @override
  String shareInsertedSnack(String title) {
    return 'Wstawiono tekst do „$title”';
  }

  @override
  String get selectNotes => 'Zaznacz';

  @override
  String selectedCount(int count) {
    return 'Zaznaczono: $count';
  }

  @override
  String get selectAllNotes => 'Zaznacz wszystko';

  @override
  String deleteNotesConfirm(int count) {
    return 'Usunąć notatki w liczbie $count?';
  }

  @override
  String notesMovedSnack(int count) {
    return 'Przeniesiono notatki: $count';
  }

  @override
  String notesArchivedSnack(int count) {
    return 'Zarchiwizowano notatki: $count';
  }

  @override
  String get versionHistory => 'Wcześniejsze wersje';

  @override
  String get versionHistoryHint =>
      'Wersje z historii Google Drive (30 najnowszych na notatkę)';

  @override
  String get versionHistoryEmpty => 'Brak wcześniejszych wersji';

  @override
  String get versionHistoryFailed => 'Nie udało się wczytać historii';

  @override
  String get versionDeletedMarker => 'usunięta';

  @override
  String get versionRestore => 'Przywróć';

  @override
  String versionRestoreConfirm(String date) {
    return 'Przywrócić wersję z $date? Obecna wersja pozostanie w historii.';
  }

  @override
  String versionRestored(String date) {
    return 'Przywrócono wersję z $date';
  }

  @override
  String conflictDetected(String title) {
    return 'Konflikt: notatka „$title” została zmieniona na dwóch urządzeniach. Sprawdź wcześniejszą wersję.';
  }

  @override
  String conflictDetectedMulti(int count) {
    return 'Konflikt: liczba notatek zmienionych na dwóch urządzeniach: $count. Sprawdź wcześniejsze wersje.';
  }

  @override
  String get yesterday => 'Wczoraj';

  @override
  String get pinned => 'Przypięta';
}
