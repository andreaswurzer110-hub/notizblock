// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Notizblock AW';

  @override
  String get newNote => 'Nouvelle note';

  @override
  String get settings => 'Paramètres';

  @override
  String get search => 'Rechercher';

  @override
  String get searchHint => 'Rechercher des notes...';

  @override
  String get delete => 'Supprimer';

  @override
  String get deleteNote => 'Supprimer la note';

  @override
  String get deleteNoteConfirm => 'Voulez-vous vraiment supprimer cette note ?';

  @override
  String get save => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get noNotes => 'Aucune note';

  @override
  String get noNotesHint => 'Appuyez sur + pour créer une note';

  @override
  String get noSearchResults => 'Aucun résultat';

  @override
  String get emptyNote => 'Note vide';

  @override
  String get pin => 'Épingler';

  @override
  String get unpin => 'Détacher';

  @override
  String get color => 'Couleur';

  @override
  String get archive => 'Archiver';

  @override
  String get titleHint => 'Titre';

  @override
  String get contentHint => 'Écrire une note...';

  @override
  String createdAt(String date) {
    return 'Créée : $date';
  }

  @override
  String modifiedAt(String date) {
    return 'Modifiée : $date';
  }

  @override
  String get language => 'Langue';

  @override
  String get theme => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get defaultColor => 'Couleur par défaut';

  @override
  String get googleDrive => 'Google Drive';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String signedInAs(String email) {
    return 'Connecté en tant que $email';
  }

  @override
  String get sync => 'Synchroniser';

  @override
  String get autoSync => 'Synchronisation automatique';

  @override
  String lastSync(String date) {
    return 'Dernière synchro : $date';
  }

  @override
  String get neverSynced => 'Jamais synchronisé';

  @override
  String get syncSuccess => 'Synchronisation réussie';

  @override
  String get syncFailed => 'Échec de la synchronisation';

  @override
  String uploaded(int count) {
    return '$count envoyées';
  }

  @override
  String downloaded(int count) {
    return '$count téléchargées';
  }

  @override
  String get createBackup => 'Créer une sauvegarde';

  @override
  String get restoreBackup => 'Restaurer la sauvegarde';

  @override
  String get restore => 'Restaurer';

  @override
  String get restoreConfirm =>
      'Toutes les notes locales seront écrasées. Continuer ?';

  @override
  String get backupSuccess => 'Sauvegarde créée avec succès';

  @override
  String get backupFailed => 'Échec de la sauvegarde';

  @override
  String get restoreSuccess => 'Sauvegarde restaurée avec succès';

  @override
  String get restoreFailed => 'Échec de la restauration';

  @override
  String get about => 'À propos';

  @override
  String get version => 'Version';

  @override
  String get openInWindow => 'Ouvrir dans une nouvelle fenêtre';

  @override
  String get pinAsWidget => 'Épingler comme widget';

  @override
  String get unpinWidget => 'Détacher le widget';

  @override
  String get syncNow => 'Synchroniser maintenant';

  @override
  String get autostart => 'Démarrage automatique';

  @override
  String get autostartSubtitle =>
      'Ouvrir les widgets automatiquement au démarrage du système';

  @override
  String get showMainWindow => 'Ouvrir la fenêtre principale au démarrage';

  @override
  String get showMainWindowSubtitle =>
      'Par défaut, seuls les widgets épinglés s’ouvrent';

  @override
  String get fontSize => 'Taille de police';

  @override
  String get fontSizeSample => 'Exemple de texte';

  @override
  String get undo => 'Annuler';

  @override
  String get redo => 'Rétablir';

  @override
  String get notSignedIn => 'Non connecté à Google Drive';

  @override
  String get archiveAndRestore => 'Archive et restauration';

  @override
  String get archivedTab => 'Archivées';

  @override
  String get deletedTab => 'Supprimées';

  @override
  String get noArchivedNotes => 'Aucune note archivée';

  @override
  String get noDeletedNotes => 'Aucune note supprimée';

  @override
  String get deletedSignInHint =>
      'Connectez-vous à Google Drive pour voir les notes supprimées';

  @override
  String get deletedLoadFailed => 'Impossible de charger les notes supprimées';

  @override
  String get noteRestored => 'Note restaurée';

  @override
  String deletedOn(String date) {
    return 'Supprimée : $date';
  }

  @override
  String get deletePermanently => 'Supprimer définitivement';

  @override
  String get deletePermanentlyConfirm =>
      'Supprimer définitivement cette note ? Action irréversible.';

  @override
  String get autopool => 'Autopool';

  @override
  String get createNoteTitle => 'Que voulez-vous créer ?';

  @override
  String get noteTypeNote => 'Note';

  @override
  String get noteTypeNoteSubtitle => 'Note de texte simple';

  @override
  String get noteTypeAutopoolSubtitle => 'Tableau (liste d’appareils)';

  @override
  String get noteTypeShoppingSubtitle =>
      'Cocher des articles, compter les quantités';

  @override
  String get shoppingList => 'Liste de courses';

  @override
  String get shoppingItemHint => 'Article';

  @override
  String get shoppingAddItem => 'Ajouter un article';

  @override
  String shoppingCompleted(int count) {
    return 'Terminé ($count)';
  }

  @override
  String get shoppingDeleteItem => 'Supprimer l’article';

  @override
  String shoppingOpenCount(int open, int total) {
    return '$open/$total à acheter';
  }

  @override
  String get allNotes => 'Toutes les notes';

  @override
  String get folders => 'Dossiers';

  @override
  String get newFolder => 'Nouveau dossier';

  @override
  String get folderName => 'Nom du dossier';

  @override
  String get renameFolder => 'Renommer le dossier';

  @override
  String get deleteFolder => 'Supprimer le dossier';

  @override
  String deleteFolderConfirm(String name) {
    return 'Supprimer le dossier « $name » ? Les notes qu’il contient sont conservées et ne seront plus dans aucun dossier.';
  }

  @override
  String get moveToFolder => 'Déplacer vers un dossier';

  @override
  String get noFolder => 'Aucun dossier';

  @override
  String get addExistingNote => 'Ajouter une note existante';

  @override
  String addNotesToFolderTitle(String folder) {
    return 'Ajouter des notes à « $folder »';
  }

  @override
  String addedToFolderSnack(String folder) {
    return 'Ajouté à « $folder »';
  }

  @override
  String get removedFromFolderSnack => 'Retiré du dossier';

  @override
  String get noNotesToAdd => 'Aucune autre note à ajouter';

  @override
  String get add => 'Ajouter';

  @override
  String get autopoolColName => 'Désignation';

  @override
  String get autopoolColOfficeVersion => 'Service et version';

  @override
  String get autopoolColLocation => 'Lieu';

  @override
  String get autopoolColInventory => 'N° d’inventaire';

  @override
  String get autopoolColSerial => 'N° de série';

  @override
  String get autopoolColDate => 'Date';

  @override
  String get autopoolAddRow => 'Ajouter une ligne';

  @override
  String get autopoolAddRowFull => 'Ligne complète (6 champs)';

  @override
  String get autopoolAddRow4 => 'Ligne courte (4 champs)';

  @override
  String get autopoolAddRow2 => 'Ligne courte (2 champs)';

  @override
  String get autopoolMoveRow => 'Déplacer';

  @override
  String get autopoolDeleteRow => 'Supprimer la ligne';

  @override
  String get autopoolMarkRow => 'Marquer / démarquer';

  @override
  String get autopoolRowColor => 'Couleur de ligne';

  @override
  String get autopoolNoColor => 'Aucune couleur';

  @override
  String get autopoolRenameColumn => 'Renommer la colonne';

  @override
  String get autopoolResetColumn => 'Réinitialiser par défaut';

  @override
  String get autopoolColumnLabel => 'Nom de la colonne';

  @override
  String get moveUp => 'Monter';

  @override
  String get moveDown => 'Descendre';

  @override
  String get openLink => 'Ouvrir le lien';

  @override
  String get searchWeb => 'Rechercher sur le web';

  @override
  String get linkOpenFailed => 'Impossible d’ouvrir le lien';

  @override
  String get ctxCut => 'Couper';

  @override
  String get ctxPaste => 'Coller';

  @override
  String get readOnly => 'Lecture seule';

  @override
  String get creator => 'Créateur';

  @override
  String get feedback => 'Commentaires et questions';

  @override
  String get close => 'Fermer';

  @override
  String get bibleVerse1Ref => 'Colossiens 3:17';

  @override
  String get bibleVerse1Text =>
      'Et quoi que vous fassiez, en parole ou en œuvre, faites tout au nom du Seigneur Jésus, en rendant par lui des actions de grâces à Dieu le Père.';

  @override
  String get bibleVerse2Ref => 'Jean 14:6';

  @override
  String get bibleVerse2Text =>
      'Jésus lui dit : Je suis le chemin, la vérité et la vie. Nul ne vient au Père que par moi.';

  @override
  String get printExport => 'Imprimer';

  @override
  String get printExportTitle => 'Imprimer et exporter';

  @override
  String get printSystem => 'Imprimer';

  @override
  String get printSystemSubtitle =>
      'Boîte de dialogue du système (imprimante/PDF)';

  @override
  String get exportPdf => 'Enregistrer en PDF';

  @override
  String get exportTxt => 'Enregistrer comme fichier texte';

  @override
  String get exportWord => 'Enregistrer comme document Word';

  @override
  String exportSaved(String file) {
    return 'Enregistré : $file';
  }

  @override
  String exportFailed(String error) {
    return 'Échec de l’exportation : $error';
  }

  @override
  String get shareImportTitle => 'Ajouter le texte partagé';

  @override
  String get shareImportNewNote => 'Dans une nouvelle note';

  @override
  String get shareImportNewNoteSubtitle =>
      'Crée une nouvelle note avec le texte';

  @override
  String get shareImportExisting => 'Dans une note existante';

  @override
  String get shareImportExistingSubtitle =>
      'Insérer le texte dans une note existante';

  @override
  String get shareImportChooseNote => 'Choisir une note';

  @override
  String get shareInsertPositionTitle => 'Insérer où ?';

  @override
  String get shareInsertTop => 'Insérer au-dessus';

  @override
  String get shareInsertBottom => 'Insérer en dessous';

  @override
  String shareInsertedSnack(String title) {
    return 'Texte inséré dans « $title »';
  }

  @override
  String get selectNotes => 'Sélectionner';

  @override
  String selectedCount(int count) {
    return '$count sélectionnées';
  }

  @override
  String get selectAllNotes => 'Tout sélectionner';

  @override
  String deleteNotesConfirm(int count) {
    return 'Supprimer $count notes ?';
  }

  @override
  String notesMovedSnack(int count) {
    return '$count notes déplacées';
  }

  @override
  String notesArchivedSnack(int count) {
    return '$count notes archivées';
  }
}
