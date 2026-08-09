// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Notizblock AW';

  @override
  String get newNote => 'Nuova nota';

  @override
  String get settings => 'Impostazioni';

  @override
  String get search => 'Cerca';

  @override
  String get searchHint => 'Cerca tra le note...';

  @override
  String get delete => 'Elimina';

  @override
  String get deleteNote => 'Elimina nota';

  @override
  String get deleteNoteConfirm => 'Vuoi davvero eliminare questa nota?';

  @override
  String get save => 'Salva';

  @override
  String get cancel => 'Annulla';

  @override
  String get noNotes => 'Nessuna nota';

  @override
  String get noNotesHint => 'Tocca + per creare una nuova nota';

  @override
  String get noSearchResults => 'Nessun risultato';

  @override
  String get emptyNote => 'Nota vuota';

  @override
  String get pin => 'Fissa';

  @override
  String get unpin => 'Rilascia';

  @override
  String get color => 'Colore';

  @override
  String get archive => 'Archivia';

  @override
  String get titleHint => 'Titolo';

  @override
  String get contentHint => 'Scrivi una nota...';

  @override
  String createdAt(String date) {
    return 'Creata: $date';
  }

  @override
  String modifiedAt(String date) {
    return 'Modificata: $date';
  }

  @override
  String get language => 'Lingua';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Chiaro';

  @override
  String get themeDark => 'Scuro';

  @override
  String get defaultColor => 'Colore predefinito';

  @override
  String get googleDrive => 'Google Drive';

  @override
  String get signIn => 'Accedi';

  @override
  String get signOut => 'Esci';

  @override
  String signedInAs(String email) {
    return 'Connesso come $email';
  }

  @override
  String get sync => 'Sincronizza';

  @override
  String get autoSync => 'Sincronizzazione automatica';

  @override
  String lastSync(String date) {
    return 'Ultima sincronizzazione: $date';
  }

  @override
  String get neverSynced => 'Mai sincronizzato';

  @override
  String get syncSuccess => 'Sincronizzazione riuscita';

  @override
  String get syncFailed => 'Sincronizzazione non riuscita';

  @override
  String uploaded(int count) {
    return '$count caricate';
  }

  @override
  String downloaded(int count) {
    return '$count scaricate';
  }

  @override
  String get createBackup => 'Crea backup';

  @override
  String get restoreBackup => 'Ripristina backup';

  @override
  String get restore => 'Ripristina';

  @override
  String get restoreConfirm =>
      'Tutte le note locali verranno sovrascritte. Continuare?';

  @override
  String get backupSuccess => 'Backup creato correttamente';

  @override
  String get backupFailed => 'Backup non riuscito';

  @override
  String get restoreSuccess => 'Backup ripristinato correttamente';

  @override
  String get restoreFailed => 'Ripristino non riuscito';

  @override
  String get about => 'Informazioni';

  @override
  String get version => 'Versione';

  @override
  String get openInWindow => 'Apri in una nuova finestra';

  @override
  String get pinAsWidget => 'Fissa come widget';

  @override
  String get unpinWidget => 'Rimuovi widget';

  @override
  String get syncNow => 'Sincronizza ora';

  @override
  String get autostart => 'Avvio automatico';

  @override
  String get autostartSubtitle =>
      'Apri automaticamente i widget all’avvio del sistema';

  @override
  String get showMainWindow => 'Apri la finestra principale all’avvio';

  @override
  String get showMainWindowSubtitle =>
      'Per impostazione predefinita si aprono solo i widget fissati';

  @override
  String get fontSize => 'Dimensione del testo';

  @override
  String get fontSizeSample => 'Testo di esempio';

  @override
  String get undo => 'Annulla';

  @override
  String get redo => 'Ripeti';

  @override
  String get notSignedIn => 'Accesso a Google Drive non effettuato';

  @override
  String get archiveAndRestore => 'Archivio e ripristino';

  @override
  String get archivedTab => 'Archiviate';

  @override
  String get deletedTab => 'Eliminate';

  @override
  String get noArchivedNotes => 'Nessuna nota archiviata';

  @override
  String get noDeletedNotes => 'Nessuna nota eliminata';

  @override
  String get deletedSignInHint =>
      'Accedi a Google Drive per visualizzare le note eliminate';

  @override
  String get deletedLoadFailed => 'Impossibile caricare le note eliminate';

  @override
  String get noteRestored => 'Nota ripristinata';

  @override
  String deletedOn(String date) {
    return 'Eliminata: $date';
  }

  @override
  String get deletePermanently => 'Elimina definitivamente';

  @override
  String get deletePermanentlyConfirm =>
      'Eliminare definitivamente questa nota? L’operazione è irreversibile.';

  @override
  String get autopool => 'Autopool';

  @override
  String get createNoteTitle => 'Cosa vuoi creare?';

  @override
  String get noteTypeNote => 'Nota';

  @override
  String get noteTypeNoteSubtitle => 'Semplice nota di testo';

  @override
  String get noteTypeAutopoolSubtitle => 'Tabella (elenco dispositivi)';

  @override
  String get noteTypeShoppingSubtitle => 'Spunta articoli, conta le quantità';

  @override
  String get shoppingList => 'Lista della spesa';

  @override
  String get shoppingItemHint => 'Articolo';

  @override
  String get shoppingAddItem => 'Aggiungi articolo';

  @override
  String shoppingCompleted(int count) {
    return 'Completati ($count)';
  }

  @override
  String get shoppingDeleteItem => 'Elimina articolo';

  @override
  String get shoppingSortAZ => 'Ordina in ordine alfabetico (A–Z)';

  @override
  String get shoppingSortZA => 'Ordina in ordine alfabetico (Z–A)';

  @override
  String shoppingOpenCount(int open, int total) {
    return '$open/$total da comprare';
  }

  @override
  String get allNotes => 'Tutte le note';

  @override
  String get folders => 'Cartelle';

  @override
  String get newFolder => 'Nuova cartella';

  @override
  String get folderName => 'Nome della cartella';

  @override
  String get renameFolder => 'Rinomina cartella';

  @override
  String get deleteFolder => 'Elimina cartella';

  @override
  String deleteFolderConfirm(String name) {
    return 'Eliminare la cartella «$name»? Le note al suo interno vengono mantenute e non saranno più in alcuna cartella.';
  }

  @override
  String get moveToFolder => 'Sposta nella cartella';

  @override
  String get noFolder => 'Nessuna cartella';

  @override
  String get addExistingNote => 'Aggiungi nota esistente';

  @override
  String addNotesToFolderTitle(String folder) {
    return 'Aggiungi note a «$folder»';
  }

  @override
  String addedToFolderSnack(String folder) {
    return 'Aggiunto a «$folder»';
  }

  @override
  String get removedFromFolderSnack => 'Rimosso dalla cartella';

  @override
  String get noNotesToAdd => 'Nessun’altra nota da aggiungere';

  @override
  String get add => 'Aggiungi';

  @override
  String get autopoolColName => 'Denominazione';

  @override
  String get autopoolColOfficeVersion => 'Ufficio e versione';

  @override
  String get autopoolColLocation => 'Luogo';

  @override
  String get autopoolColInventory => 'N. inventario';

  @override
  String get autopoolColSerial => 'N. di serie';

  @override
  String get autopoolColDate => 'Data';

  @override
  String get autopoolAddRow => 'Aggiungi riga';

  @override
  String get autopoolAddRowFull => 'Riga completa (6 campi)';

  @override
  String get autopoolAddRow4 => 'Riga breve (4 campi)';

  @override
  String get autopoolAddRow2 => 'Riga breve (2 campi)';

  @override
  String get autopoolMoveRow => 'Sposta';

  @override
  String get autopoolDeleteRow => 'Elimina riga';

  @override
  String get autopoolMarkRow => 'Segna / rimuovi segno';

  @override
  String get autopoolRowColor => 'Colore riga';

  @override
  String get autopoolNoColor => 'Nessun colore';

  @override
  String get autopoolRenameColumn => 'Rinomina colonna';

  @override
  String get autopoolResetColumn => 'Ripristina predefinito';

  @override
  String get autopoolColumnLabel => 'Nome colonna';

  @override
  String get moveUp => 'Su';

  @override
  String get moveDown => 'Giù';

  @override
  String get openLink => 'Apri link';

  @override
  String get searchWeb => 'Cerca sul web';

  @override
  String get linkOpenFailed => 'Impossibile aprire il link';

  @override
  String get ctxCut => 'Taglia';

  @override
  String get ctxPaste => 'Incolla';

  @override
  String get readOnly => 'Sola lettura';

  @override
  String get creator => 'Creatore';

  @override
  String get feedback => 'Feedback e domande';

  @override
  String get close => 'Chiudi';

  @override
  String get bibleVerse1Ref => 'Colossesi 3:17';

  @override
  String get bibleVerse1Text =>
      'E qualunque cosa facciate, in parole o in opere, fate ogni cosa nel nome del Signore Gesù, rendendo grazie a Dio Padre per mezzo di lui.';

  @override
  String get bibleVerse2Ref => 'Giovanni 14:6';

  @override
  String get bibleVerse2Text =>
      'Gesù gli disse: Io sono la via, la verità e la vita; nessuno viene al Padre se non per mezzo di me.';

  @override
  String get printExport => 'Stampa';

  @override
  String get printExportTitle => 'Stampa ed esporta';

  @override
  String get printSystem => 'Stampa';

  @override
  String get printSystemSubtitle => 'Finestra di sistema (stampante/PDF)';

  @override
  String get exportPdf => 'Salva come PDF';

  @override
  String get exportTxt => 'Salva come file di testo';

  @override
  String get exportWord => 'Salva come documento Word';

  @override
  String exportSaved(String file) {
    return 'Salvato: $file';
  }

  @override
  String exportFailed(String error) {
    return 'Esportazione non riuscita: $error';
  }

  @override
  String get shareImportTitle => 'Aggiungi il testo condiviso';

  @override
  String get shareImportNewNote => 'In una nuova nota';

  @override
  String get shareImportNewNoteSubtitle => 'Crea una nuova nota con il testo';

  @override
  String get shareImportExisting => 'In una nota esistente';

  @override
  String get shareImportExistingSubtitle =>
      'Inserisci il testo in una nota esistente';

  @override
  String get shareImportChooseNote => 'Scegli la nota';

  @override
  String get shareInsertPositionTitle => 'Dove inserire?';

  @override
  String get shareInsertTop => 'Inserisci sopra';

  @override
  String get shareInsertBottom => 'Inserisci sotto';

  @override
  String shareInsertedSnack(String title) {
    return 'Testo inserito in «$title»';
  }

  @override
  String get selectNotes => 'Seleziona';

  @override
  String selectedCount(int count) {
    return '$count selezionate';
  }

  @override
  String get selectAllNotes => 'Seleziona tutto';

  @override
  String deleteNotesConfirm(int count) {
    return 'Eliminare $count note?';
  }

  @override
  String notesMovedSnack(int count) {
    return '$count note spostate';
  }

  @override
  String notesArchivedSnack(int count) {
    return '$count note archiviate';
  }

  @override
  String get versionHistory => 'Versioni precedenti';

  @override
  String get versionHistoryHint =>
      'Versioni dalla cronologia di Google Drive (le 30 più recenti per nota)';

  @override
  String get versionHistoryEmpty => 'Nessuna versione precedente';

  @override
  String get versionHistoryFailed => 'Impossibile caricare la cronologia';

  @override
  String get versionDeletedMarker => 'eliminata';

  @override
  String get versionRestore => 'Ripristina';

  @override
  String versionRestoreConfirm(String date) {
    return 'Ripristinare la versione del $date? La versione attuale resta nella cronologia.';
  }

  @override
  String versionRestored(String date) {
    return 'Versione del $date ripristinata';
  }

  @override
  String conflictDetected(String title) {
    return 'Conflitto: «$title» è stata modificata su due dispositivi. Controlla la versione precedente.';
  }

  @override
  String conflictDetectedMulti(int count) {
    return 'Conflitto: $count note sono state modificate su due dispositivi. Controlla le versioni precedenti.';
  }

  @override
  String get yesterday => 'Ieri';

  @override
  String get pinned => 'Fissata';
}
