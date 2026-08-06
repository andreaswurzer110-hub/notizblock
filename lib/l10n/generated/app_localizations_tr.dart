// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Notizblock AW';

  @override
  String get newNote => 'Yeni not';

  @override
  String get settings => 'Ayarlar';

  @override
  String get search => 'Ara';

  @override
  String get searchHint => 'Notlarda ara...';

  @override
  String get delete => 'Sil';

  @override
  String get deleteNote => 'Notu sil';

  @override
  String get deleteNoteConfirm => 'Bu notu gerçekten silmek istiyor musunuz?';

  @override
  String get save => 'Kaydet';

  @override
  String get cancel => 'İptal';

  @override
  String get noNotes => 'Not yok';

  @override
  String get noNotesHint => 'Yeni not için + simgesine dokunun';

  @override
  String get noSearchResults => 'Sonuç yok';

  @override
  String get emptyNote => 'Boş not';

  @override
  String get pin => 'Sabitle';

  @override
  String get unpin => 'Sabitlemeyi kaldır';

  @override
  String get color => 'Renk';

  @override
  String get archive => 'Arşivle';

  @override
  String get titleHint => 'Başlık';

  @override
  String get contentHint => 'Bir not yazın...';

  @override
  String createdAt(String date) {
    return 'Oluşturuldu: $date';
  }

  @override
  String modifiedAt(String date) {
    return 'Değiştirildi: $date';
  }

  @override
  String get language => 'Dil';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get themeLight => 'Açık';

  @override
  String get themeDark => 'Koyu';

  @override
  String get defaultColor => 'Varsayılan renk';

  @override
  String get googleDrive => 'Google Drive';

  @override
  String get signIn => 'Oturum aç';

  @override
  String get signOut => 'Oturumu kapat';

  @override
  String signedInAs(String email) {
    return 'Oturum açıldı: $email';
  }

  @override
  String get sync => 'Eşitle';

  @override
  String get autoSync => 'Otomatik eşitleme';

  @override
  String lastSync(String date) {
    return 'Son eşitleme: $date';
  }

  @override
  String get neverSynced => 'Henüz eşitlenmedi';

  @override
  String get syncSuccess => 'Eşitleme tamamlandı';

  @override
  String get syncFailed => 'Eşitleme başarısız';

  @override
  String uploaded(int count) {
    return '$count yüklendi';
  }

  @override
  String downloaded(int count) {
    return '$count indirildi';
  }

  @override
  String get createBackup => 'Yedek oluştur';

  @override
  String get restoreBackup => 'Yedeği geri yükle';

  @override
  String get restore => 'Geri yükle';

  @override
  String get restoreConfirm =>
      'Yereldeki tüm notların üzerine yazılacak. Devam edilsin mi?';

  @override
  String get backupSuccess => 'Yedek oluşturuldu';

  @override
  String get backupFailed => 'Yedek oluşturulamadı';

  @override
  String get restoreSuccess => 'Yedek geri yüklendi';

  @override
  String get restoreFailed => 'Geri yükleme başarısız';

  @override
  String get about => 'Hakkında';

  @override
  String get version => 'Sürüm';

  @override
  String get openInWindow => 'Yeni pencerede aç';

  @override
  String get pinAsWidget => 'Widget olarak sabitle';

  @override
  String get unpinWidget => 'Widget sabitlemesini kaldır';

  @override
  String get syncNow => 'Şimdi eşitle';

  @override
  String get autostart => 'Otomatik başlat';

  @override
  String get autostartSubtitle => 'Sistem açılışında widget’ları aç';

  @override
  String get showMainWindow => 'Açılışta ana pencereyi aç';

  @override
  String get showMainWindowSubtitle =>
      'Varsayılan olarak yalnızca sabitlenmiş widget’lar açılır';

  @override
  String get fontSize => 'Yazı boyutu';

  @override
  String get fontSizeSample => 'Örnek metin';

  @override
  String get undo => 'Geri al';

  @override
  String get redo => 'Yinele';

  @override
  String get notSignedIn => 'Google Drive oturumu açık değil';

  @override
  String get archiveAndRestore => 'Arşiv ve geri yükleme';

  @override
  String get archivedTab => 'Arşivlenen';

  @override
  String get deletedTab => 'Silinen';

  @override
  String get noArchivedNotes => 'Arşivlenmiş not yok';

  @override
  String get noDeletedNotes => 'Silinmiş not yok';

  @override
  String get deletedSignInHint =>
      'Silinen notları görmek için Google Drive oturumu açın';

  @override
  String get deletedLoadFailed => 'Silinen notlar yüklenemedi';

  @override
  String get noteRestored => 'Not geri yüklendi';

  @override
  String deletedOn(String date) {
    return 'Silindi: $date';
  }

  @override
  String get deletePermanently => 'Kalıcı olarak sil';

  @override
  String get deletePermanentlyConfirm =>
      'Bu not kalıcı olarak silinsin mi? Bu işlem geri alınamaz.';

  @override
  String get autopool => 'Autopool';

  @override
  String get createNoteTitle => 'Ne oluşturmak istersiniz?';

  @override
  String get noteTypeNote => 'Not';

  @override
  String get noteTypeNoteSubtitle => 'Basit metin notu';

  @override
  String get noteTypeAutopoolSubtitle => 'Tablo (cihaz listesi)';

  @override
  String get noteTypeShoppingSubtitle =>
      'Maddeleri işaretleyin, adetleri sayın';

  @override
  String get shoppingList => 'Alışveriş listesi';

  @override
  String get shoppingItemHint => 'Ürün';

  @override
  String get shoppingAddItem => 'Ürün ekle';

  @override
  String shoppingCompleted(int count) {
    return 'Tamamlanan ($count)';
  }

  @override
  String get shoppingDeleteItem => 'Ürünü sil';

  @override
  String shoppingOpenCount(int open, int total) {
    return '$open/$total açık';
  }

  @override
  String get allNotes => 'Tüm notlar';

  @override
  String get folders => 'Klasörler';

  @override
  String get newFolder => 'Yeni klasör';

  @override
  String get folderName => 'Klasör adı';

  @override
  String get renameFolder => 'Klasörü yeniden adlandır';

  @override
  String get deleteFolder => 'Klasörü sil';

  @override
  String deleteFolderConfirm(String name) {
    return '“$name” klasörü silinsin mi? İçindeki notlar korunur ve artık bir klasörde olmaz.';
  }

  @override
  String get moveToFolder => 'Klasöre taşı';

  @override
  String get noFolder => 'Klasörsüz';

  @override
  String get addExistingNote => 'Var olan notu ekle';

  @override
  String addNotesToFolderTitle(String folder) {
    return '“$folder” klasörüne not ekle';
  }

  @override
  String addedToFolderSnack(String folder) {
    return '“$folder” klasörüne eklendi';
  }

  @override
  String get removedFromFolderSnack => 'Klasörden çıkarıldı';

  @override
  String get noNotesToAdd => 'Eklenecek başka not yok';

  @override
  String get add => 'Ekle';

  @override
  String get autopoolColName => 'Tanım';

  @override
  String get autopoolColOfficeVersion => 'Birim ve sürüm';

  @override
  String get autopoolColLocation => 'Konum';

  @override
  String get autopoolColInventory => 'Envanter no.';

  @override
  String get autopoolColSerial => 'Seri numarası';

  @override
  String get autopoolColDate => 'Tarih';

  @override
  String get autopoolAddRow => 'Satır ekle';

  @override
  String get autopoolAddRowFull => 'Tam satır (6 alan)';

  @override
  String get autopoolAddRow4 => 'Kısa satır (4 alan)';

  @override
  String get autopoolAddRow2 => 'Kısa satır (2 alan)';

  @override
  String get autopoolMoveRow => 'Taşı';

  @override
  String get autopoolDeleteRow => 'Satırı sil';

  @override
  String get autopoolMarkRow => 'İşaretle / işareti kaldır';

  @override
  String get autopoolRowColor => 'Satır rengi';

  @override
  String get autopoolNoColor => 'Renk yok';

  @override
  String get autopoolRenameColumn => 'Sütunu yeniden adlandır';

  @override
  String get autopoolResetColumn => 'Varsayılana döndür';

  @override
  String get autopoolColumnLabel => 'Sütun adı';

  @override
  String get moveUp => 'Yukarı taşı';

  @override
  String get moveDown => 'Aşağı taşı';

  @override
  String get openLink => 'Bağlantıyı aç';

  @override
  String get searchWeb => 'Web’de ara';

  @override
  String get linkOpenFailed => 'Bağlantı açılamadı';

  @override
  String get ctxCut => 'Kes';

  @override
  String get ctxPaste => 'Yapıştır';

  @override
  String get readOnly => 'Salt okunur';

  @override
  String get creator => 'Geliştirici';

  @override
  String get feedback => 'Geri bildirim ve sorular';

  @override
  String get close => 'Kapat';

  @override
  String get bibleVerse1Ref => 'Koloseliler 3:17';

  @override
  String get bibleVerse1Text =>
      'Söylediğiniz ya da yaptığınız her şeyi Rab İsa’nın adıyla, O’nun aracılığıyla Baba Tanrı’ya şükrederek yapın.';

  @override
  String get bibleVerse2Ref => 'Yuhanna 14:6';

  @override
  String get bibleVerse2Text =>
      'İsa ona, Yol, gerçek ve yaşam Ben’im, dedi. Benim aracılığım olmadan Baba’ya kimse gelemez.';

  @override
  String get printExport => 'Yazdır';

  @override
  String get printExportTitle => 'Yazdır ve dışa aktar';

  @override
  String get printSystem => 'Yazdır';

  @override
  String get printSystemSubtitle => 'Sistem penceresi (yazıcı/PDF)';

  @override
  String get exportPdf => 'PDF olarak kaydet';

  @override
  String get exportTxt => 'Metin dosyası olarak kaydet';

  @override
  String get exportWord => 'Word belgesi olarak kaydet';

  @override
  String exportSaved(String file) {
    return 'Kaydedildi: $file';
  }

  @override
  String exportFailed(String error) {
    return 'Dışa aktarma başarısız: $error';
  }

  @override
  String get shareImportTitle => 'Paylaşılan metni ekle';

  @override
  String get shareImportNewNote => 'Yeni bir nota';

  @override
  String get shareImportNewNoteSubtitle => 'Metinle yeni bir not oluşturur';

  @override
  String get shareImportExisting => 'Var olan bir nota';

  @override
  String get shareImportExistingSubtitle => 'Metni var olan bir nota ekler';

  @override
  String get shareImportChooseNote => 'Not seç';

  @override
  String get shareInsertPositionTitle => 'Nereye eklensin?';

  @override
  String get shareInsertTop => 'Üste ekle';

  @override
  String get shareInsertBottom => 'Alta ekle';

  @override
  String shareInsertedSnack(String title) {
    return 'Metin “$title” notuna eklendi';
  }

  @override
  String get selectNotes => 'Seç';

  @override
  String selectedCount(int count) {
    return '$count seçildi';
  }

  @override
  String get selectAllNotes => 'Tümünü seç';

  @override
  String deleteNotesConfirm(int count) {
    return '$count not silinsin mi?';
  }

  @override
  String notesMovedSnack(int count) {
    return '$count not taşındı';
  }

  @override
  String notesArchivedSnack(int count) {
    return '$count not arşivlendi';
  }

  @override
  String get versionHistory => 'Önceki sürümler';

  @override
  String get versionHistoryHint =>
      'Google Drive geçmişindeki sürümler (not başına en yeni 30 tanesi)';

  @override
  String get versionHistoryEmpty => 'Henüz önceki sürüm yok';

  @override
  String get versionHistoryFailed => 'Geçmiş yüklenemedi';

  @override
  String get versionDeletedMarker => 'silindi';

  @override
  String get versionRestore => 'Geri yükle';

  @override
  String versionRestoreConfirm(String date) {
    return '$date tarihli sürüm geri yüklensin mi? Şu anki sürüm geçmişte kalır.';
  }

  @override
  String versionRestored(String date) {
    return '$date tarihli sürüm geri yüklendi';
  }

  @override
  String conflictDetected(String title) {
    return 'Çakışma: “$title” iki cihazda değiştirildi. Lütfen önceki sürümü inceleyin.';
  }

  @override
  String conflictDetectedMulti(int count) {
    return 'Çakışma: $count not iki cihazda değiştirildi. Lütfen önceki sürümleri inceleyin.';
  }

  @override
  String get yesterday => 'Dün';

  @override
  String get pinned => 'Sabitlendi';
}
