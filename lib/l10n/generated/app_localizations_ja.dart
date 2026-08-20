// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Notizblock AW';

  @override
  String get newNote => '新しいメモ';

  @override
  String get settings => '設定';

  @override
  String get search => '検索';

  @override
  String get searchHint => 'メモを検索…';

  @override
  String get delete => '削除';

  @override
  String get deleteNote => 'メモを削除';

  @override
  String get deleteNoteConfirm => 'このメモを削除しますか？';

  @override
  String get save => '保存';

  @override
  String get cancel => 'キャンセル';

  @override
  String get noNotes => 'メモがありません';

  @override
  String get noNotesHint => '＋ をタップして新しいメモを作成';

  @override
  String get noSearchResults => '該当なし';

  @override
  String get emptyNote => '空のメモ';

  @override
  String get pin => '固定';

  @override
  String get unpin => '固定を解除';

  @override
  String get color => '色';

  @override
  String get archive => 'アーカイブ';

  @override
  String get titleHint => 'タイトル';

  @override
  String get contentHint => 'メモを入力…';

  @override
  String createdAt(String date) {
    return '作成: $date';
  }

  @override
  String modifiedAt(String date) {
    return '更新: $date';
  }

  @override
  String get language => '言語';

  @override
  String get theme => 'テーマ';

  @override
  String get themeSystem => 'システムに合わせる';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get defaultColor => '既定の色';

  @override
  String get googleDrive => 'Google ドライブ';

  @override
  String get signIn => 'ログイン';

  @override
  String get signOut => 'ログアウト';

  @override
  String signedInAs(String email) {
    return 'ログイン中: $email';
  }

  @override
  String get sync => '同期';

  @override
  String get autoSync => '自動同期';

  @override
  String lastSync(String date) {
    return '最終同期: $date';
  }

  @override
  String get neverSynced => 'まだ同期していません';

  @override
  String get syncSuccess => '同期が完了しました';

  @override
  String get syncFailed => '同期に失敗しました';

  @override
  String uploaded(int count) {
    return '$count 件アップロード';
  }

  @override
  String downloaded(int count) {
    return '$count 件ダウンロード';
  }

  @override
  String get createBackup => 'バックアップを作成';

  @override
  String get restoreBackup => 'バックアップから復元';

  @override
  String get restore => '復元';

  @override
  String get restoreConfirm => 'ローカルのメモはすべて上書きされます。続けますか？';

  @override
  String get backupSuccess => 'バックアップを作成しました';

  @override
  String get backupFailed => 'バックアップに失敗しました';

  @override
  String get restoreSuccess => 'バックアップを復元しました';

  @override
  String get restoreFailed => '復元に失敗しました';

  @override
  String get about => 'このアプリについて';

  @override
  String get version => 'バージョン';

  @override
  String get openInWindow => '新しいウィンドウで開く';

  @override
  String get pinAsWidget => 'ウィジェットとして固定';

  @override
  String get unpinWidget => 'ウィジェットの固定を解除';

  @override
  String get syncNow => '今すぐ同期';

  @override
  String get autostart => '自動的に起動する';

  @override
  String get autostartSubtitle => 'システム起動時にウィジェットを開く';

  @override
  String get showMainWindow => '起動時にメイン画面を開く';

  @override
  String get showMainWindowSubtitle => '既定では固定したウィジェットのみ開きます';

  @override
  String get fontSize => '文字サイズ';

  @override
  String get fontSizeSample => 'サンプルテキスト';

  @override
  String get undo => '元に戻す';

  @override
  String get redo => 'やり直す';

  @override
  String get notSignedIn => 'Google ドライブにログインしていません';

  @override
  String get archiveAndRestore => 'アーカイブと復元';

  @override
  String get archivedTab => 'アーカイブ済み';

  @override
  String get deletedTab => '削除済み';

  @override
  String get noArchivedNotes => 'アーカイブされたメモはありません';

  @override
  String get noDeletedNotes => '削除されたメモはありません';

  @override
  String get deletedSignInHint => '削除したメモを見るには Google ドライブにログインしてください';

  @override
  String get deletedLoadFailed => '削除したメモを読み込めませんでした';

  @override
  String get noteRestored => 'メモを復元しました';

  @override
  String deletedOn(String date) {
    return '削除: $date';
  }

  @override
  String get deletePermanently => '完全に削除';

  @override
  String get deletePermanentlyConfirm => 'このメモを完全に削除しますか？元に戻せません。';

  @override
  String get autopool => 'Autopool';

  @override
  String get createNoteTitle => '何を作成しますか？';

  @override
  String get noteTypeNote => 'メモ';

  @override
  String get noteTypeNoteSubtitle => 'シンプルなテキストメモ';

  @override
  String get noteTypeAutopoolSubtitle => '表（機器リスト）';

  @override
  String get noteTypeShoppingSubtitle => '項目にチェック、数量も管理';

  @override
  String get shoppingList => '買い物リスト';

  @override
  String get shoppingItemHint => '品目';

  @override
  String get shoppingAddItem => '品目を追加';

  @override
  String shoppingCompleted(int count) {
    return '完了（$count）';
  }

  @override
  String get shoppingDeleteItem => '品目を削除';

  @override
  String get shoppingSortAZ => '名前順に並べ替え（A–Z）';

  @override
  String get shoppingSortZA => '名前順に並べ替え（Z–A）';

  @override
  String shoppingOpenCount(int open, int total) {
    return '残り $open/$total';
  }

  @override
  String get allNotes => 'すべてのメモ';

  @override
  String get folders => 'フォルダ';

  @override
  String get newFolder => '新しいフォルダ';

  @override
  String get folderName => 'フォルダ名';

  @override
  String get renameFolder => 'フォルダ名を変更';

  @override
  String get deleteFolder => 'フォルダを削除';

  @override
  String deleteFolderConfirm(String name) {
    return 'フォルダ「$name」を削除しますか？中のメモは残り、どのフォルダにも属さなくなります。';
  }

  @override
  String get moveToFolder => 'フォルダへ移動';

  @override
  String get noFolder => 'フォルダなし';

  @override
  String get addExistingNote => '既存のメモを追加';

  @override
  String addNotesToFolderTitle(String folder) {
    return '「$folder」にメモを追加';
  }

  @override
  String addedToFolderSnack(String folder) {
    return '「$folder」に追加しました';
  }

  @override
  String get removedFromFolderSnack => 'フォルダから外しました';

  @override
  String get noNotesToAdd => '追加できるメモがありません';

  @override
  String get add => '追加';

  @override
  String get autopoolColName => '名称';

  @override
  String get autopoolColOfficeVersion => '部署・バージョン';

  @override
  String get autopoolColLocation => '場所';

  @override
  String get autopoolColInventory => '管理番号';

  @override
  String get autopoolColSerial => 'シリアル番号';

  @override
  String get autopoolColDate => '日付';

  @override
  String get autopoolAddRow => '行を追加';

  @override
  String get autopoolAddRowFull => '通常の行（6 項目）';

  @override
  String get autopoolAddRow4 => '短い行（4 項目）';

  @override
  String get autopoolAddRow2 => '短い行（2 項目）';

  @override
  String get autopoolMoveRow => '移動';

  @override
  String get autopoolDeleteRow => '行を削除';

  @override
  String get autopoolMarkRow => 'マークする / 解除する';

  @override
  String get autopoolRowColor => '行の色';

  @override
  String get autopoolNoColor => '色なし';

  @override
  String get autopoolRenameColumn => '列名を変更';

  @override
  String get autopoolResetColumn => '既定に戻す';

  @override
  String get autopoolColumnLabel => '列名';

  @override
  String get moveUp => '上へ';

  @override
  String get moveDown => '下へ';

  @override
  String get openLink => 'リンクを開く';

  @override
  String get searchWeb => 'ウェブで検索';

  @override
  String get linkOpenFailed => 'リンクを開けませんでした';

  @override
  String get ctxCut => '切り取り';

  @override
  String get ctxPaste => '貼り付け';

  @override
  String get readOnly => '読み取り専用';

  @override
  String get creator => '作者';

  @override
  String get toolsUsed => '使用ツール';

  @override
  String get aiNotice =>
      'このアプリは人工知能（Claude Code）の支援を受けて開発されました。コードとテキストの一部はAIが生成したもので、作者が確認しています。';

  @override
  String get feedback => 'ご意見・お問い合わせ';

  @override
  String get close => '閉じる';

  @override
  String get bibleVerse1Ref => 'コロサイ人への手紙 3:17';

  @override
  String get bibleVerse1Text =>
      'あなたがたのなすことは、言葉によるものも行いによるものも、すべて主イエスの名によってなし、彼によって父なる神に感謝しなさい。';

  @override
  String get bibleVerse2Ref => 'ヨハネによる福音書 14:6';

  @override
  String get bibleVerse2Text =>
      'イエスは彼に言われた、わたしは道であり、真理であり、命である。だれでもわたしによらないでは、父のみもとに行くことはできない。';

  @override
  String get printExport => '印刷';

  @override
  String get printExportTitle => '印刷と書き出し';

  @override
  String get printSystem => '印刷';

  @override
  String get printSystemSubtitle => 'システムのダイアログ（プリンター/PDF）';

  @override
  String get exportPdf => 'PDF として保存';

  @override
  String get exportTxt => 'テキストファイルとして保存';

  @override
  String get exportWord => 'Word 文書として保存';

  @override
  String exportSaved(String file) {
    return '保存しました: $file';
  }

  @override
  String exportFailed(String error) {
    return '書き出しに失敗しました: $error';
  }

  @override
  String get shareImportTitle => '共有されたテキストを追加';

  @override
  String get shareImportNewNote => '新しいメモへ';

  @override
  String get shareImportNewNoteSubtitle => 'テキストで新しいメモを作成します';

  @override
  String get shareImportExisting => '既存のメモへ';

  @override
  String get shareImportExistingSubtitle => '既存のメモにテキストを挿入します';

  @override
  String get shareImportChooseNote => 'メモを選択';

  @override
  String get shareInsertPositionTitle => 'どこに挿入しますか？';

  @override
  String get shareInsertTop => '上に挿入';

  @override
  String get shareInsertBottom => '下に挿入';

  @override
  String shareInsertedSnack(String title) {
    return '「$title」にテキストを挿入しました';
  }

  @override
  String get selectNotes => '選択';

  @override
  String selectedCount(int count) {
    return '$count 件選択中';
  }

  @override
  String get selectAllNotes => 'すべて選択';

  @override
  String deleteNotesConfirm(int count) {
    return '$count 件のメモを削除しますか？';
  }

  @override
  String notesMovedSnack(int count) {
    return '$count 件のメモを移動しました';
  }

  @override
  String notesArchivedSnack(int count) {
    return '$count 件のメモをアーカイブしました';
  }

  @override
  String get versionHistory => '以前のバージョン';

  @override
  String get versionHistoryHint => 'Google ドライブの履歴（メモごとに最新 30 件）';

  @override
  String get versionHistoryEmpty => '以前のバージョンはまだありません';

  @override
  String get versionHistoryFailed => '履歴を読み込めませんでした';

  @override
  String get versionDeletedMarker => '削除済み';

  @override
  String get versionRestore => '復元';

  @override
  String versionRestoreConfirm(String date) {
    return '$date のバージョンを復元しますか？現在のバージョンは履歴に残ります。';
  }

  @override
  String versionRestored(String date) {
    return '$date のバージョンを復元しました';
  }

  @override
  String conflictDetected(String title) {
    return '競合: 「$title」が 2 台の端末で変更されました。以前のバージョンをご確認ください。';
  }

  @override
  String conflictDetectedMulti(int count) {
    return '競合: $count 件のメモが 2 台の端末で変更されました。以前のバージョンをご確認ください。';
  }

  @override
  String get yesterday => '昨日';

  @override
  String get pinned => '固定中';
}
