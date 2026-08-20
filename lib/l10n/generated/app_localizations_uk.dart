// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Notizblock AW';

  @override
  String get newNote => 'Нова нотатка';

  @override
  String get settings => 'Налаштування';

  @override
  String get search => 'Пошук';

  @override
  String get searchHint => 'Пошук нотаток...';

  @override
  String get delete => 'Видалити';

  @override
  String get deleteNote => 'Видалити нотатку';

  @override
  String get deleteNoteConfirm => 'Справді видалити цю нотатку?';

  @override
  String get save => 'Зберегти';

  @override
  String get cancel => 'Скасувати';

  @override
  String get noNotes => 'Нотаток немає';

  @override
  String get noNotesHint => 'Натисніть +, щоб створити нотатку';

  @override
  String get noSearchResults => 'Нічого не знайдено';

  @override
  String get emptyNote => 'Порожня нотатка';

  @override
  String get pin => 'Закріпити';

  @override
  String get unpin => 'Відкріпити';

  @override
  String get color => 'Колір';

  @override
  String get archive => 'До архіву';

  @override
  String get titleHint => 'Заголовок';

  @override
  String get contentHint => 'Напишіть нотатку...';

  @override
  String createdAt(String date) {
    return 'Створено: $date';
  }

  @override
  String modifiedAt(String date) {
    return 'Змінено: $date';
  }

  @override
  String get language => 'Мова';

  @override
  String get theme => 'Тема';

  @override
  String get themeSystem => 'Як у системі';

  @override
  String get themeLight => 'Світла';

  @override
  String get themeDark => 'Темна';

  @override
  String get defaultColor => 'Колір за умовчанням';

  @override
  String get googleDrive => 'Google Диск';

  @override
  String get signIn => 'Увійти';

  @override
  String get signOut => 'Вийти';

  @override
  String signedInAs(String email) {
    return 'Виконано вхід: $email';
  }

  @override
  String get sync => 'Синхронізація';

  @override
  String get autoSync => 'Автоматична синхронізація';

  @override
  String lastSync(String date) {
    return 'Остання синхронізація: $date';
  }

  @override
  String get neverSynced => 'Синхронізації ще не було';

  @override
  String get syncSuccess => 'Синхронізацію виконано';

  @override
  String get syncFailed => 'Помилка синхронізації';

  @override
  String uploaded(int count) {
    return 'Надіслано: $count';
  }

  @override
  String downloaded(int count) {
    return 'Отримано: $count';
  }

  @override
  String get createBackup => 'Створити резервну копію';

  @override
  String get restoreBackup => 'Відновити з копії';

  @override
  String get restore => 'Відновити';

  @override
  String get restoreConfirm =>
      'Усі локальні нотатки буде перезаписано. Продовжити?';

  @override
  String get backupSuccess => 'Резервну копію створено';

  @override
  String get backupFailed => 'Не вдалося створити резервну копію';

  @override
  String get restoreSuccess => 'Дані відновлено';

  @override
  String get restoreFailed => 'Не вдалося відновити';

  @override
  String get about => 'Про застосунок';

  @override
  String get version => 'Версія';

  @override
  String get openInWindow => 'Відкрити в новому вікні';

  @override
  String get pinAsWidget => 'Закріпити як віджет';

  @override
  String get unpinWidget => 'Прибрати віджет';

  @override
  String get syncNow => 'Синхронізувати зараз';

  @override
  String get autostart => 'Запускати автоматично';

  @override
  String get autostartSubtitle => 'Відкривати віджети під час запуску системи';

  @override
  String get showMainWindow => 'Відкривати головне вікно під час запуску';

  @override
  String get showMainWindowSubtitle =>
      'Типово відкриваються лише закріплені віджети';

  @override
  String get fontSize => 'Розмір шрифту';

  @override
  String get fontSizeSample => 'Зразок тексту';

  @override
  String get undo => 'Скасувати';

  @override
  String get redo => 'Повторити';

  @override
  String get notSignedIn => 'Вхід у Google Диск не виконано';

  @override
  String get archiveAndRestore => 'Архів і відновлення';

  @override
  String get archivedTab => 'В архіві';

  @override
  String get deletedTab => 'Видалені';

  @override
  String get noArchivedNotes => 'В архіві порожньо';

  @override
  String get noDeletedNotes => 'Видалених нотаток немає';

  @override
  String get deletedSignInHint =>
      'Увійдіть у Google Диск, щоб побачити видалені нотатки';

  @override
  String get deletedLoadFailed => 'Не вдалося завантажити видалені нотатки';

  @override
  String get noteRestored => 'Нотатку відновлено';

  @override
  String deletedOn(String date) {
    return 'Видалено: $date';
  }

  @override
  String get deletePermanently => 'Видалити остаточно';

  @override
  String get deletePermanentlyConfirm =>
      'Видалити цю нотатку остаточно? Скасувати це буде неможливо.';

  @override
  String get autopool => 'Autopool';

  @override
  String get createNoteTitle => 'Що створити?';

  @override
  String get noteTypeNote => 'Нотатка';

  @override
  String get noteTypeNoteSubtitle => 'Звичайна текстова нотатка';

  @override
  String get noteTypeAutopoolSubtitle => 'Таблиця (список пристроїв)';

  @override
  String get noteTypeShoppingSubtitle => 'Позначати пункти, рахувати кількість';

  @override
  String get shoppingList => 'Список покупок';

  @override
  String get shoppingItemHint => 'Товар';

  @override
  String get shoppingAddItem => 'Додати товар';

  @override
  String shoppingCompleted(int count) {
    return 'Готово ($count)';
  }

  @override
  String get shoppingDeleteItem => 'Видалити товар';

  @override
  String get shoppingSortAZ => 'Сортувати за абеткою (А–Я)';

  @override
  String get shoppingSortZA => 'Сортувати за абеткою (Я–А)';

  @override
  String shoppingOpenCount(int open, int total) {
    return '$open/$total залишилось';
  }

  @override
  String get allNotes => 'Усі нотатки';

  @override
  String get folders => 'Теки';

  @override
  String get newFolder => 'Нова тека';

  @override
  String get folderName => 'Назва теки';

  @override
  String get renameFolder => 'Перейменувати теку';

  @override
  String get deleteFolder => 'Видалити теку';

  @override
  String deleteFolderConfirm(String name) {
    return 'Видалити теку «$name»? Нотатки збережуться і більше не належатимуть жодній теці.';
  }

  @override
  String get moveToFolder => 'Перемістити до теки';

  @override
  String get noFolder => 'Без теки';

  @override
  String get addExistingNote => 'Додати наявну нотатку';

  @override
  String addNotesToFolderTitle(String folder) {
    return 'Додати нотатки до «$folder»';
  }

  @override
  String addedToFolderSnack(String folder) {
    return 'Додано до «$folder»';
  }

  @override
  String get removedFromFolderSnack => 'Прибрано з теки';

  @override
  String get noNotesToAdd => 'Інших нотаток для додавання немає';

  @override
  String get add => 'Додати';

  @override
  String get autopoolColName => 'Найменування';

  @override
  String get autopoolColOfficeVersion => 'Відділ і версія';

  @override
  String get autopoolColLocation => 'Місце';

  @override
  String get autopoolColInventory => 'Інвентарний номер';

  @override
  String get autopoolColSerial => 'Серійний номер';

  @override
  String get autopoolColDate => 'Дата';

  @override
  String get autopoolAddRow => 'Додати рядок';

  @override
  String get autopoolAddRowFull => 'Повний рядок (6 полів)';

  @override
  String get autopoolAddRow4 => 'Короткий рядок (4 поля)';

  @override
  String get autopoolAddRow2 => 'Короткий рядок (2 поля)';

  @override
  String get autopoolMoveRow => 'Перемістити';

  @override
  String get autopoolDeleteRow => 'Видалити рядок';

  @override
  String get autopoolMarkRow => 'Позначити / зняти позначку';

  @override
  String get autopoolRowColor => 'Колір рядка';

  @override
  String get autopoolNoColor => 'Без кольору';

  @override
  String get autopoolRenameColumn => 'Перейменувати стовпець';

  @override
  String get autopoolResetColumn => 'Повернути типове';

  @override
  String get autopoolColumnLabel => 'Назва стовпця';

  @override
  String get moveUp => 'Вгору';

  @override
  String get moveDown => 'Вниз';

  @override
  String get openLink => 'Відкрити посилання';

  @override
  String get searchWeb => 'Шукати в інтернеті';

  @override
  String get linkOpenFailed => 'Не вдалося відкрити посилання';

  @override
  String get ctxCut => 'Вирізати';

  @override
  String get ctxPaste => 'Вставити';

  @override
  String get readOnly => 'Лише читання';

  @override
  String get creator => 'Автор';

  @override
  String get toolsUsed => 'Використані інструменти';

  @override
  String get aiNotice =>
      'Цей застосунок розроблено за допомогою штучного інтелекту (Claude Code). Частину коду й текстів згенеровано ШІ та перевірено автором.';

  @override
  String get feedback => 'Відгуки та запитання';

  @override
  String get close => 'Закрити';

  @override
  String get bibleVerse1Ref => 'До колоссян 3:17';

  @override
  String get bibleVerse1Text =>
      'І все, що тільки чините словом чи ділом, усе чиніть у Ім’я Господа Ісуса, дякуючи через Нього Богові й Отцеві.';

  @override
  String get bibleVerse2Ref => 'Івана 14:6';

  @override
  String get bibleVerse2Text =>
      'Промовляє до нього Ісус: Я дорога, і правда, і життя. До Отця не приходить ніхто, якщо не через Мене.';

  @override
  String get printExport => 'Друк';

  @override
  String get printExportTitle => 'Друк та експорт';

  @override
  String get printSystem => 'Друк';

  @override
  String get printSystemSubtitle => 'Системне вікно (принтер/PDF)';

  @override
  String get exportPdf => 'Зберегти як PDF';

  @override
  String get exportTxt => 'Зберегти як текстовий файл';

  @override
  String get exportWord => 'Зберегти як документ Word';

  @override
  String exportSaved(String file) {
    return 'Збережено: $file';
  }

  @override
  String exportFailed(String error) {
    return 'Помилка експорту: $error';
  }

  @override
  String get shareImportTitle => 'Додати отриманий текст';

  @override
  String get shareImportNewNote => 'До нової нотатки';

  @override
  String get shareImportNewNoteSubtitle => 'Створює нову нотатку з цим текстом';

  @override
  String get shareImportExisting => 'До наявної нотатки';

  @override
  String get shareImportExistingSubtitle => 'Вставити текст у наявну нотатку';

  @override
  String get shareImportChooseNote => 'Вибрати нотатку';

  @override
  String get shareInsertPositionTitle => 'Куди вставити?';

  @override
  String get shareInsertTop => 'Вставити зверху';

  @override
  String get shareInsertBottom => 'Вставити знизу';

  @override
  String shareInsertedSnack(String title) {
    return 'Текст вставлено в «$title»';
  }

  @override
  String get selectNotes => 'Вибрати';

  @override
  String selectedCount(int count) {
    return 'Вибрано: $count';
  }

  @override
  String get selectAllNotes => 'Вибрати все';

  @override
  String deleteNotesConfirm(int count) {
    return 'Видалити нотатки ($count)?';
  }

  @override
  String notesMovedSnack(int count) {
    return 'Переміщено нотаток: $count';
  }

  @override
  String notesArchivedSnack(int count) {
    return 'До архіву надіслано нотаток: $count';
  }

  @override
  String get versionHistory => 'Попередні версії';

  @override
  String get versionHistoryHint =>
      'Версії з історії Google Диска (30 останніх для кожної нотатки)';

  @override
  String get versionHistoryEmpty => 'Попередніх версій ще немає';

  @override
  String get versionHistoryFailed => 'Не вдалося завантажити історію';

  @override
  String get versionDeletedMarker => 'видалена';

  @override
  String get versionRestore => 'Відновити';

  @override
  String versionRestoreConfirm(String date) {
    return 'Відновити версію від $date? Поточна версія залишиться в історії.';
  }

  @override
  String versionRestored(String date) {
    return 'Відновлено версію від $date';
  }

  @override
  String conflictDetected(String title) {
    return 'Конфлікт: нотатку «$title» змінено на двох пристроях. Перевірте попередню версію.';
  }

  @override
  String conflictDetectedMulti(int count) {
    return 'Конфлікт: на двох пристроях змінено нотаток: $count. Перевірте попередні версії.';
  }

  @override
  String get yesterday => 'Учора';

  @override
  String get pinned => 'Закріплено';
}
