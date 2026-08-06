// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Notizblock AW';

  @override
  String get newNote => 'Новая заметка';

  @override
  String get settings => 'Настройки';

  @override
  String get search => 'Поиск';

  @override
  String get searchHint => 'Поиск заметок...';

  @override
  String get delete => 'Удалить';

  @override
  String get deleteNote => 'Удалить заметку';

  @override
  String get deleteNoteConfirm => 'Действительно удалить эту заметку?';

  @override
  String get save => 'Сохранить';

  @override
  String get cancel => 'Отмена';

  @override
  String get noNotes => 'Заметок нет';

  @override
  String get noNotesHint => 'Нажмите +, чтобы создать заметку';

  @override
  String get noSearchResults => 'Ничего не найдено';

  @override
  String get emptyNote => 'Пустая заметка';

  @override
  String get pin => 'Закрепить';

  @override
  String get unpin => 'Открепить';

  @override
  String get color => 'Цвет';

  @override
  String get archive => 'В архив';

  @override
  String get titleHint => 'Заголовок';

  @override
  String get contentHint => 'Напишите заметку...';

  @override
  String createdAt(String date) {
    return 'Создано: $date';
  }

  @override
  String modifiedAt(String date) {
    return 'Изменено: $date';
  }

  @override
  String get language => 'Язык';

  @override
  String get theme => 'Тема';

  @override
  String get themeSystem => 'Как в системе';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get defaultColor => 'Цвет по умолчанию';

  @override
  String get googleDrive => 'Google Диск';

  @override
  String get signIn => 'Войти';

  @override
  String get signOut => 'Выйти';

  @override
  String signedInAs(String email) {
    return 'Выполнен вход: $email';
  }

  @override
  String get sync => 'Синхронизация';

  @override
  String get autoSync => 'Автоматическая синхронизация';

  @override
  String lastSync(String date) {
    return 'Последняя синхронизация: $date';
  }

  @override
  String get neverSynced => 'Синхронизации ещё не было';

  @override
  String get syncSuccess => 'Синхронизация выполнена';

  @override
  String get syncFailed => 'Ошибка синхронизации';

  @override
  String uploaded(int count) {
    return 'Отправлено: $count';
  }

  @override
  String downloaded(int count) {
    return 'Получено: $count';
  }

  @override
  String get createBackup => 'Создать резервную копию';

  @override
  String get restoreBackup => 'Восстановить из копии';

  @override
  String get restore => 'Восстановить';

  @override
  String get restoreConfirm =>
      'Все локальные заметки будут перезаписаны. Продолжить?';

  @override
  String get backupSuccess => 'Резервная копия создана';

  @override
  String get backupFailed => 'Не удалось создать резервную копию';

  @override
  String get restoreSuccess => 'Данные восстановлены';

  @override
  String get restoreFailed => 'Не удалось восстановить';

  @override
  String get about => 'О приложении';

  @override
  String get version => 'Версия';

  @override
  String get openInWindow => 'Открыть в новом окне';

  @override
  String get pinAsWidget => 'Закрепить как виджет';

  @override
  String get unpinWidget => 'Убрать виджет';

  @override
  String get syncNow => 'Синхронизировать сейчас';

  @override
  String get autostart => 'Запускать автоматически';

  @override
  String get autostartSubtitle => 'Открывать виджеты при запуске системы';

  @override
  String get showMainWindow => 'Открывать главное окно при запуске';

  @override
  String get showMainWindowSubtitle =>
      'По умолчанию открываются только закреплённые виджеты';

  @override
  String get fontSize => 'Размер шрифта';

  @override
  String get fontSizeSample => 'Пример текста';

  @override
  String get undo => 'Отменить';

  @override
  String get redo => 'Повторить';

  @override
  String get notSignedIn => 'Вход в Google Диск не выполнен';

  @override
  String get archiveAndRestore => 'Архив и восстановление';

  @override
  String get archivedTab => 'В архиве';

  @override
  String get deletedTab => 'Удалённые';

  @override
  String get noArchivedNotes => 'В архиве пусто';

  @override
  String get noDeletedNotes => 'Удалённых заметок нет';

  @override
  String get deletedSignInHint =>
      'Войдите в Google Диск, чтобы увидеть удалённые заметки';

  @override
  String get deletedLoadFailed => 'Не удалось загрузить удалённые заметки';

  @override
  String get noteRestored => 'Заметка восстановлена';

  @override
  String deletedOn(String date) {
    return 'Удалено: $date';
  }

  @override
  String get deletePermanently => 'Удалить окончательно';

  @override
  String get deletePermanentlyConfirm =>
      'Удалить эту заметку окончательно? Отменить это будет нельзя.';

  @override
  String get autopool => 'Autopool';

  @override
  String get createNoteTitle => 'Что создать?';

  @override
  String get noteTypeNote => 'Заметка';

  @override
  String get noteTypeNoteSubtitle => 'Обычная текстовая заметка';

  @override
  String get noteTypeAutopoolSubtitle => 'Таблица (список устройств)';

  @override
  String get noteTypeShoppingSubtitle => 'Отмечать пункты, считать количество';

  @override
  String get shoppingList => 'Список покупок';

  @override
  String get shoppingItemHint => 'Товар';

  @override
  String get shoppingAddItem => 'Добавить товар';

  @override
  String shoppingCompleted(int count) {
    return 'Готово ($count)';
  }

  @override
  String get shoppingDeleteItem => 'Удалить товар';

  @override
  String shoppingOpenCount(int open, int total) {
    return '$open/$total осталось';
  }

  @override
  String get allNotes => 'Все заметки';

  @override
  String get folders => 'Папки';

  @override
  String get newFolder => 'Новая папка';

  @override
  String get folderName => 'Название папки';

  @override
  String get renameFolder => 'Переименовать папку';

  @override
  String get deleteFolder => 'Удалить папку';

  @override
  String deleteFolderConfirm(String name) {
    return 'Удалить папку «$name»? Заметки останутся и больше не будут ни в одной папке.';
  }

  @override
  String get moveToFolder => 'Переместить в папку';

  @override
  String get noFolder => 'Без папки';

  @override
  String get addExistingNote => 'Добавить существующую заметку';

  @override
  String addNotesToFolderTitle(String folder) {
    return 'Добавить заметки в «$folder»';
  }

  @override
  String addedToFolderSnack(String folder) {
    return 'Добавлено в «$folder»';
  }

  @override
  String get removedFromFolderSnack => 'Убрано из папки';

  @override
  String get noNotesToAdd => 'Других заметок для добавления нет';

  @override
  String get add => 'Добавить';

  @override
  String get autopoolColName => 'Наименование';

  @override
  String get autopoolColOfficeVersion => 'Отдел и версия';

  @override
  String get autopoolColLocation => 'Место';

  @override
  String get autopoolColInventory => 'Инвентарный номер';

  @override
  String get autopoolColSerial => 'Серийный номер';

  @override
  String get autopoolColDate => 'Дата';

  @override
  String get autopoolAddRow => 'Добавить строку';

  @override
  String get autopoolAddRowFull => 'Полная строка (6 полей)';

  @override
  String get autopoolAddRow4 => 'Короткая строка (4 поля)';

  @override
  String get autopoolAddRow2 => 'Короткая строка (2 поля)';

  @override
  String get autopoolMoveRow => 'Переместить';

  @override
  String get autopoolDeleteRow => 'Удалить строку';

  @override
  String get autopoolMarkRow => 'Отметить / снять отметку';

  @override
  String get autopoolRowColor => 'Цвет строки';

  @override
  String get autopoolNoColor => 'Без цвета';

  @override
  String get autopoolRenameColumn => 'Переименовать столбец';

  @override
  String get autopoolResetColumn => 'Вернуть по умолчанию';

  @override
  String get autopoolColumnLabel => 'Название столбца';

  @override
  String get moveUp => 'Вверх';

  @override
  String get moveDown => 'Вниз';

  @override
  String get openLink => 'Открыть ссылку';

  @override
  String get searchWeb => 'Искать в интернете';

  @override
  String get linkOpenFailed => 'Не удалось открыть ссылку';

  @override
  String get ctxCut => 'Вырезать';

  @override
  String get ctxPaste => 'Вставить';

  @override
  String get readOnly => 'Только чтение';

  @override
  String get creator => 'Автор';

  @override
  String get feedback => 'Отзывы и вопросы';

  @override
  String get close => 'Закрыть';

  @override
  String get bibleVerse1Ref => 'Колоссянам 3:17';

  @override
  String get bibleVerse1Text =>
      'И всё, что вы делаете, словом или делом, всё делайте во имя Господа Иисуса Христа, благодаря через Него Бога и Отца.';

  @override
  String get bibleVerse2Ref => 'Иоанна 14:6';

  @override
  String get bibleVerse2Text =>
      'Иисус сказал ему: Я есмь путь и истина и жизнь; никто не приходит к Отцу, как только через Меня.';

  @override
  String get printExport => 'Печать';

  @override
  String get printExportTitle => 'Печать и экспорт';

  @override
  String get printSystem => 'Печать';

  @override
  String get printSystemSubtitle => 'Системное окно (принтер/PDF)';

  @override
  String get exportPdf => 'Сохранить как PDF';

  @override
  String get exportTxt => 'Сохранить как текстовый файл';

  @override
  String get exportWord => 'Сохранить как документ Word';

  @override
  String exportSaved(String file) {
    return 'Сохранено: $file';
  }

  @override
  String exportFailed(String error) {
    return 'Ошибка экспорта: $error';
  }

  @override
  String get shareImportTitle => 'Добавить полученный текст';

  @override
  String get shareImportNewNote => 'В новую заметку';

  @override
  String get shareImportNewNoteSubtitle =>
      'Создаёт новую заметку с этим текстом';

  @override
  String get shareImportExisting => 'В существующую заметку';

  @override
  String get shareImportExistingSubtitle =>
      'Вставить текст в существующую заметку';

  @override
  String get shareImportChooseNote => 'Выбрать заметку';

  @override
  String get shareInsertPositionTitle => 'Куда вставить?';

  @override
  String get shareInsertTop => 'Вставить сверху';

  @override
  String get shareInsertBottom => 'Вставить снизу';

  @override
  String shareInsertedSnack(String title) {
    return 'Текст вставлен в «$title»';
  }

  @override
  String get selectNotes => 'Выбрать';

  @override
  String selectedCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get selectAllNotes => 'Выбрать все';

  @override
  String deleteNotesConfirm(int count) {
    return 'Удалить заметки ($count)?';
  }

  @override
  String notesMovedSnack(int count) {
    return 'Перемещено заметок: $count';
  }

  @override
  String notesArchivedSnack(int count) {
    return 'В архив отправлено заметок: $count';
  }

  @override
  String get versionHistory => 'Прежние версии';

  @override
  String get versionHistoryHint =>
      'Версии из истории Google Диска (30 последних для каждой заметки)';

  @override
  String get versionHistoryEmpty => 'Прежних версий пока нет';

  @override
  String get versionHistoryFailed => 'Не удалось загрузить историю';

  @override
  String get versionDeletedMarker => 'удалена';

  @override
  String get versionRestore => 'Восстановить';

  @override
  String versionRestoreConfirm(String date) {
    return 'Восстановить версию от $date? Текущая версия останется в истории.';
  }

  @override
  String versionRestored(String date) {
    return 'Восстановлена версия от $date';
  }

  @override
  String conflictDetected(String title) {
    return 'Конфликт: заметка «$title» изменена на двух устройствах. Проверьте прежнюю версию.';
  }

  @override
  String conflictDetectedMulti(int count) {
    return 'Конфликт: на двух устройствах изменено заметок: $count. Проверьте прежние версии.';
  }

  @override
  String get yesterday => 'Вчера';

  @override
  String get pinned => 'Закреплено';
}
