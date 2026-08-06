// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Notizblock AW';

  @override
  String get newNote => '新建笔记';

  @override
  String get settings => '设置';

  @override
  String get search => '搜索';

  @override
  String get searchHint => '搜索笔记…';

  @override
  String get delete => '删除';

  @override
  String get deleteNote => '删除笔记';

  @override
  String get deleteNoteConfirm => '确定要删除这条笔记吗？';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get noNotes => '暂无笔记';

  @override
  String get noNotesHint => '点按 + 新建笔记';

  @override
  String get noSearchResults => '没有结果';

  @override
  String get emptyNote => '空笔记';

  @override
  String get pin => '置顶';

  @override
  String get unpin => '取消置顶';

  @override
  String get color => '颜色';

  @override
  String get archive => '归档';

  @override
  String get titleHint => '标题';

  @override
  String get contentHint => '写点什么…';

  @override
  String createdAt(String date) {
    return '创建时间：$date';
  }

  @override
  String modifiedAt(String date) {
    return '修改时间：$date';
  }

  @override
  String get language => '语言';

  @override
  String get theme => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get defaultColor => '默认颜色';

  @override
  String get googleDrive => 'Google 云端硬盘';

  @override
  String get signIn => '登录';

  @override
  String get signOut => '退出登录';

  @override
  String signedInAs(String email) {
    return '已登录：$email';
  }

  @override
  String get sync => '同步';

  @override
  String get autoSync => '自动同步';

  @override
  String lastSync(String date) {
    return '上次同步：$date';
  }

  @override
  String get neverSynced => '尚未同步';

  @override
  String get syncSuccess => '同步完成';

  @override
  String get syncFailed => '同步失败';

  @override
  String uploaded(int count) {
    return '已上传 $count 条';
  }

  @override
  String downloaded(int count) {
    return '已下载 $count 条';
  }

  @override
  String get createBackup => '创建备份';

  @override
  String get restoreBackup => '恢复备份';

  @override
  String get restore => '恢复';

  @override
  String get restoreConfirm => '本地所有笔记将被覆盖，要继续吗？';

  @override
  String get backupSuccess => '备份已创建';

  @override
  String get backupFailed => '备份失败';

  @override
  String get restoreSuccess => '备份已恢复';

  @override
  String get restoreFailed => '恢复失败';

  @override
  String get about => '关于';

  @override
  String get version => '版本';

  @override
  String get openInWindow => '在新窗口中打开';

  @override
  String get pinAsWidget => '固定为小组件';

  @override
  String get unpinWidget => '取消固定小组件';

  @override
  String get syncNow => '立即同步';

  @override
  String get autostart => '自动启动';

  @override
  String get autostartSubtitle => '系统启动时打开小组件';

  @override
  String get showMainWindow => '启动时打开主窗口';

  @override
  String get showMainWindowSubtitle => '默认只打开已固定的小组件';

  @override
  String get fontSize => '字号';

  @override
  String get fontSizeSample => '示例文字';

  @override
  String get undo => '撤销';

  @override
  String get redo => '重做';

  @override
  String get notSignedIn => '尚未登录 Google 云端硬盘';

  @override
  String get archiveAndRestore => '归档与恢复';

  @override
  String get archivedTab => '已归档';

  @override
  String get deletedTab => '已删除';

  @override
  String get noArchivedNotes => '没有已归档的笔记';

  @override
  String get noDeletedNotes => '没有已删除的笔记';

  @override
  String get deletedSignInHint => '登录 Google 云端硬盘后可查看已删除的笔记';

  @override
  String get deletedLoadFailed => '无法加载已删除的笔记';

  @override
  String get noteRestored => '笔记已恢复';

  @override
  String deletedOn(String date) {
    return '删除时间：$date';
  }

  @override
  String get deletePermanently => '永久删除';

  @override
  String get deletePermanentlyConfirm => '永久删除这条笔记？此操作无法撤销。';

  @override
  String get autopool => 'Autopool';

  @override
  String get createNoteTitle => '要创建什么？';

  @override
  String get noteTypeNote => '笔记';

  @override
  String get noteTypeNoteSubtitle => '简单的文字笔记';

  @override
  String get noteTypeAutopoolSubtitle => '表格（设备清单）';

  @override
  String get noteTypeShoppingSubtitle => '勾选条目、计算数量';

  @override
  String get shoppingList => '购物清单';

  @override
  String get shoppingItemHint => '商品';

  @override
  String get shoppingAddItem => '添加商品';

  @override
  String shoppingCompleted(int count) {
    return '已完成（$count）';
  }

  @override
  String get shoppingDeleteItem => '删除商品';

  @override
  String shoppingOpenCount(int open, int total) {
    return '$open/$total 未完成';
  }

  @override
  String get allNotes => '全部笔记';

  @override
  String get folders => '文件夹';

  @override
  String get newFolder => '新建文件夹';

  @override
  String get folderName => '文件夹名称';

  @override
  String get renameFolder => '重命名文件夹';

  @override
  String get deleteFolder => '删除文件夹';

  @override
  String deleteFolderConfirm(String name) {
    return '删除文件夹“$name”？其中的笔记会保留，之后不属于任何文件夹。';
  }

  @override
  String get moveToFolder => '移动到文件夹';

  @override
  String get noFolder => '无文件夹';

  @override
  String get addExistingNote => '添加已有笔记';

  @override
  String addNotesToFolderTitle(String folder) {
    return '将笔记添加到“$folder”';
  }

  @override
  String addedToFolderSnack(String folder) {
    return '已添加到“$folder”';
  }

  @override
  String get removedFromFolderSnack => '已移出文件夹';

  @override
  String get noNotesToAdd => '没有其他可添加的笔记';

  @override
  String get add => '添加';

  @override
  String get autopoolColName => '名称';

  @override
  String get autopoolColOfficeVersion => '部门与版本';

  @override
  String get autopoolColLocation => '位置';

  @override
  String get autopoolColInventory => '资产编号';

  @override
  String get autopoolColSerial => '序列号';

  @override
  String get autopoolColDate => '日期';

  @override
  String get autopoolAddRow => '添加行';

  @override
  String get autopoolAddRowFull => '完整行（6 个字段）';

  @override
  String get autopoolAddRow4 => '短行（4 个字段）';

  @override
  String get autopoolAddRow2 => '短行（2 个字段）';

  @override
  String get autopoolMoveRow => '移动';

  @override
  String get autopoolDeleteRow => '删除行';

  @override
  String get autopoolMarkRow => '标记 / 取消标记';

  @override
  String get autopoolRowColor => '行颜色';

  @override
  String get autopoolNoColor => '无颜色';

  @override
  String get autopoolRenameColumn => '重命名列';

  @override
  String get autopoolResetColumn => '恢复默认';

  @override
  String get autopoolColumnLabel => '列名称';

  @override
  String get moveUp => '上移';

  @override
  String get moveDown => '下移';

  @override
  String get openLink => '打开链接';

  @override
  String get searchWeb => '在网上搜索';

  @override
  String get linkOpenFailed => '无法打开链接';

  @override
  String get ctxCut => '剪切';

  @override
  String get ctxPaste => '粘贴';

  @override
  String get readOnly => '只读';

  @override
  String get creator => '开发者';

  @override
  String get feedback => '反馈与提问';

  @override
  String get close => '关闭';

  @override
  String get bibleVerse1Ref => '歌罗西书 3:17';

  @override
  String get bibleVerse1Text => '无论作什么，或说话或行事，都要奉主耶稣的名，藉着他感谢父神。';

  @override
  String get bibleVerse2Ref => '约翰福音 14:6';

  @override
  String get bibleVerse2Text => '耶稣说：我就是道路、真理、生命；若不藉着我，没有人能到父那里去。';

  @override
  String get printExport => '打印';

  @override
  String get printExportTitle => '打印与导出';

  @override
  String get printSystem => '打印';

  @override
  String get printSystemSubtitle => '系统对话框（打印机/PDF）';

  @override
  String get exportPdf => '另存为 PDF';

  @override
  String get exportTxt => '另存为文本文件';

  @override
  String get exportWord => '另存为 Word 文档';

  @override
  String exportSaved(String file) {
    return '已保存：$file';
  }

  @override
  String exportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get shareImportTitle => '添加分享的文字';

  @override
  String get shareImportNewNote => '存入新笔记';

  @override
  String get shareImportNewNoteSubtitle => '用这段文字新建一条笔记';

  @override
  String get shareImportExisting => '存入已有笔记';

  @override
  String get shareImportExistingSubtitle => '把文字插入已有的笔记';

  @override
  String get shareImportChooseNote => '选择笔记';

  @override
  String get shareInsertPositionTitle => '插入到哪里？';

  @override
  String get shareInsertTop => '插入到上方';

  @override
  String get shareInsertBottom => '插入到下方';

  @override
  String shareInsertedSnack(String title) {
    return '文字已插入“$title”';
  }

  @override
  String get selectNotes => '选择';

  @override
  String selectedCount(int count) {
    return '已选择 $count 条';
  }

  @override
  String get selectAllNotes => '全选';

  @override
  String deleteNotesConfirm(int count) {
    return '删除 $count 条笔记？';
  }

  @override
  String notesMovedSnack(int count) {
    return '已移动 $count 条笔记';
  }

  @override
  String notesArchivedSnack(int count) {
    return '已归档 $count 条笔记';
  }

  @override
  String get versionHistory => '历史版本';

  @override
  String get versionHistoryHint => '来自 Google 云端硬盘的历史记录（每条笔记保留最新 30 个）';

  @override
  String get versionHistoryEmpty => '暂无历史版本';

  @override
  String get versionHistoryFailed => '无法加载历史记录';

  @override
  String get versionDeletedMarker => '已删除';

  @override
  String get versionRestore => '恢复';

  @override
  String versionRestoreConfirm(String date) {
    return '恢复 $date 的版本？当前版本会保留在历史记录中。';
  }

  @override
  String versionRestored(String date) {
    return '已恢复 $date 的版本';
  }

  @override
  String conflictDetected(String title) {
    return '冲突：“$title”在两台设备上都被修改过，请查看历史版本。';
  }

  @override
  String conflictDetectedMulti(int count) {
    return '冲突：有 $count 条笔记在两台设备上都被修改过，请查看历史版本。';
  }

  @override
  String get yesterday => '昨天';

  @override
  String get pinned => '已置顶';
}
