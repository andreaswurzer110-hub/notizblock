// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Notizblock AW';

  @override
  String get newNote => 'Nova nota';

  @override
  String get settings => 'Configurações';

  @override
  String get search => 'Pesquisar';

  @override
  String get searchHint => 'Pesquisar notas...';

  @override
  String get delete => 'Excluir';

  @override
  String get deleteNote => 'Excluir nota';

  @override
  String get deleteNoteConfirm => 'Deseja realmente excluir esta nota?';

  @override
  String get save => 'Salvar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get noNotes => 'Nenhuma nota';

  @override
  String get noNotesHint => 'Toque em + para criar uma nota';

  @override
  String get noSearchResults => 'Nenhum resultado';

  @override
  String get emptyNote => 'Nota vazia';

  @override
  String get pin => 'Fixar';

  @override
  String get unpin => 'Desafixar';

  @override
  String get color => 'Cor';

  @override
  String get archive => 'Arquivar';

  @override
  String get titleHint => 'Título';

  @override
  String get contentHint => 'Escreva uma nota...';

  @override
  String createdAt(String date) {
    return 'Criada em: $date';
  }

  @override
  String modifiedAt(String date) {
    return 'Alterada em: $date';
  }

  @override
  String get language => 'Idioma';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';

  @override
  String get defaultColor => 'Cor padrão';

  @override
  String get googleDrive => 'Google Drive';

  @override
  String get signIn => 'Entrar';

  @override
  String get signOut => 'Sair';

  @override
  String signedInAs(String email) {
    return 'Conectado como $email';
  }

  @override
  String get sync => 'Sincronizar';

  @override
  String get autoSync => 'Sincronização automática';

  @override
  String lastSync(String date) {
    return 'Última sincronização: $date';
  }

  @override
  String get neverSynced => 'Nunca sincronizado';

  @override
  String get syncSuccess => 'Sincronização concluída';

  @override
  String get syncFailed => 'Falha na sincronização';

  @override
  String uploaded(int count) {
    return '$count enviadas';
  }

  @override
  String downloaded(int count) {
    return '$count recebidas';
  }

  @override
  String get createBackup => 'Criar backup';

  @override
  String get restoreBackup => 'Restaurar backup';

  @override
  String get restore => 'Restaurar';

  @override
  String get restoreConfirm =>
      'Todas as notas locais serão substituídas. Continuar?';

  @override
  String get backupSuccess => 'Backup criado com sucesso';

  @override
  String get backupFailed => 'Falha ao criar o backup';

  @override
  String get restoreSuccess => 'Backup restaurado com sucesso';

  @override
  String get restoreFailed => 'Falha ao restaurar';

  @override
  String get about => 'Sobre';

  @override
  String get version => 'Versão';

  @override
  String get openInWindow => 'Abrir em uma nova janela';

  @override
  String get pinAsWidget => 'Fixar como widget';

  @override
  String get unpinWidget => 'Remover widget';

  @override
  String get syncNow => 'Sincronizar agora';

  @override
  String get autostart => 'Iniciar automaticamente';

  @override
  String get autostartSubtitle => 'Abrir os widgets ao iniciar o sistema';

  @override
  String get showMainWindow => 'Abrir a janela principal ao iniciar';

  @override
  String get showMainWindowSubtitle =>
      'Por padrão, abrem-se apenas os widgets fixados';

  @override
  String get fontSize => 'Tamanho da fonte';

  @override
  String get fontSizeSample => 'Texto de exemplo';

  @override
  String get undo => 'Desfazer';

  @override
  String get redo => 'Refazer';

  @override
  String get notSignedIn => 'Não conectado ao Google Drive';

  @override
  String get archiveAndRestore => 'Arquivo e restauração';

  @override
  String get archivedTab => 'Arquivadas';

  @override
  String get deletedTab => 'Excluídas';

  @override
  String get noArchivedNotes => 'Nenhuma nota arquivada';

  @override
  String get noDeletedNotes => 'Nenhuma nota excluída';

  @override
  String get deletedSignInHint =>
      'Conecte-se ao Google Drive para ver as notas excluídas';

  @override
  String get deletedLoadFailed =>
      'Não foi possível carregar as notas excluídas';

  @override
  String get noteRestored => 'Nota restaurada';

  @override
  String deletedOn(String date) {
    return 'Excluída em: $date';
  }

  @override
  String get deletePermanently => 'Excluir definitivamente';

  @override
  String get deletePermanentlyConfirm =>
      'Excluir esta nota definitivamente? Não é possível desfazer.';

  @override
  String get autopool => 'Autopool';

  @override
  String get createNoteTitle => 'O que você quer criar?';

  @override
  String get noteTypeNote => 'Nota';

  @override
  String get noteTypeNoteSubtitle => 'Nota de texto simples';

  @override
  String get noteTypeAutopoolSubtitle => 'Tabela (lista de aparelhos)';

  @override
  String get noteTypeShoppingSubtitle => 'Marcar itens, contar quantidades';

  @override
  String get shoppingList => 'Lista de compras';

  @override
  String get shoppingItemHint => 'Item';

  @override
  String get shoppingAddItem => 'Adicionar item';

  @override
  String shoppingCompleted(int count) {
    return 'Concluídos ($count)';
  }

  @override
  String get shoppingDeleteItem => 'Excluir item';

  @override
  String shoppingOpenCount(int open, int total) {
    return '$open/$total em aberto';
  }

  @override
  String get allNotes => 'Todas as notas';

  @override
  String get folders => 'Pastas';

  @override
  String get newFolder => 'Nova pasta';

  @override
  String get folderName => 'Nome da pasta';

  @override
  String get renameFolder => 'Renomear pasta';

  @override
  String get deleteFolder => 'Excluir pasta';

  @override
  String deleteFolderConfirm(String name) {
    return 'Excluir a pasta “$name”? As notas dentro dela são mantidas e deixam de pertencer a uma pasta.';
  }

  @override
  String get moveToFolder => 'Mover para a pasta';

  @override
  String get noFolder => 'Sem pasta';

  @override
  String get addExistingNote => 'Adicionar nota existente';

  @override
  String addNotesToFolderTitle(String folder) {
    return 'Adicionar notas a “$folder”';
  }

  @override
  String addedToFolderSnack(String folder) {
    return 'Adicionada a “$folder”';
  }

  @override
  String get removedFromFolderSnack => 'Removida da pasta';

  @override
  String get noNotesToAdd => 'Nenhuma outra nota para adicionar';

  @override
  String get add => 'Adicionar';

  @override
  String get autopoolColName => 'Descrição';

  @override
  String get autopoolColOfficeVersion => 'Setor e versão';

  @override
  String get autopoolColLocation => 'Local';

  @override
  String get autopoolColInventory => 'Nº de inventário';

  @override
  String get autopoolColSerial => 'Número de série';

  @override
  String get autopoolColDate => 'Data';

  @override
  String get autopoolAddRow => 'Adicionar linha';

  @override
  String get autopoolAddRowFull => 'Linha completa (6 campos)';

  @override
  String get autopoolAddRow4 => 'Linha curta (4 campos)';

  @override
  String get autopoolAddRow2 => 'Linha curta (2 campos)';

  @override
  String get autopoolMoveRow => 'Mover';

  @override
  String get autopoolDeleteRow => 'Excluir linha';

  @override
  String get autopoolMarkRow => 'Marcar / desmarcar';

  @override
  String get autopoolRowColor => 'Cor da linha';

  @override
  String get autopoolNoColor => 'Sem cor';

  @override
  String get autopoolRenameColumn => 'Renomear coluna';

  @override
  String get autopoolResetColumn => 'Restaurar padrão';

  @override
  String get autopoolColumnLabel => 'Nome da coluna';

  @override
  String get moveUp => 'Mover para cima';

  @override
  String get moveDown => 'Mover para baixo';

  @override
  String get openLink => 'Abrir link';

  @override
  String get searchWeb => 'Pesquisar na web';

  @override
  String get linkOpenFailed => 'Não foi possível abrir o link';

  @override
  String get ctxCut => 'Recortar';

  @override
  String get ctxPaste => 'Colar';

  @override
  String get readOnly => 'Somente leitura';

  @override
  String get creator => 'Autor';

  @override
  String get feedback => 'Comentários e dúvidas';

  @override
  String get close => 'Fechar';

  @override
  String get bibleVerse1Ref => 'Colossenses 3:17';

  @override
  String get bibleVerse1Text =>
      'E tudo quanto fizerdes, por palavras ou por obras, fazei-o em nome do Senhor Jesus, dando por ele graças a Deus Pai.';

  @override
  String get bibleVerse2Ref => 'João 14:6';

  @override
  String get bibleVerse2Text =>
      'Disse-lhe Jesus: Eu sou o caminho, e a verdade, e a vida; ninguém vem ao Pai senão por mim.';

  @override
  String get printExport => 'Imprimir';

  @override
  String get printExportTitle => 'Imprimir e exportar';

  @override
  String get printSystem => 'Imprimir';

  @override
  String get printSystemSubtitle => 'Janela do sistema (impressora/PDF)';

  @override
  String get exportPdf => 'Salvar como PDF';

  @override
  String get exportTxt => 'Salvar como arquivo de texto';

  @override
  String get exportWord => 'Salvar como documento do Word';

  @override
  String exportSaved(String file) {
    return 'Salvo: $file';
  }

  @override
  String exportFailed(String error) {
    return 'Falha na exportação: $error';
  }

  @override
  String get shareImportTitle => 'Adicionar texto compartilhado';

  @override
  String get shareImportNewNote => 'Em uma nota nova';

  @override
  String get shareImportNewNoteSubtitle => 'Cria uma nota nova com o texto';

  @override
  String get shareImportExisting => 'Em uma nota existente';

  @override
  String get shareImportExistingSubtitle =>
      'Inserir o texto em uma nota existente';

  @override
  String get shareImportChooseNote => 'Escolher nota';

  @override
  String get shareInsertPositionTitle => 'Inserir onde?';

  @override
  String get shareInsertTop => 'Inserir acima';

  @override
  String get shareInsertBottom => 'Inserir abaixo';

  @override
  String shareInsertedSnack(String title) {
    return 'Texto inserido em “$title”';
  }

  @override
  String get selectNotes => 'Selecionar';

  @override
  String selectedCount(int count) {
    return '$count selecionadas';
  }

  @override
  String get selectAllNotes => 'Selecionar tudo';

  @override
  String deleteNotesConfirm(int count) {
    return 'Excluir $count notas?';
  }

  @override
  String notesMovedSnack(int count) {
    return '$count notas movidas';
  }

  @override
  String notesArchivedSnack(int count) {
    return '$count notas arquivadas';
  }

  @override
  String get versionHistory => 'Versões anteriores';

  @override
  String get versionHistoryHint =>
      'Versões do histórico do Google Drive (as 30 mais recentes por nota)';

  @override
  String get versionHistoryEmpty => 'Ainda não há versões anteriores';

  @override
  String get versionHistoryFailed => 'Não foi possível carregar o histórico';

  @override
  String get versionDeletedMarker => 'excluída';

  @override
  String get versionRestore => 'Restaurar';

  @override
  String versionRestoreConfirm(String date) {
    return 'Restaurar a versão de $date? A versão atual permanece no histórico.';
  }

  @override
  String versionRestored(String date) {
    return 'Versão de $date restaurada';
  }

  @override
  String conflictDetected(String title) {
    return 'Conflito: “$title” foi alterada em dois aparelhos. Verifique a versão anterior.';
  }

  @override
  String conflictDetectedMulti(int count) {
    return 'Conflito: $count notas foram alteradas em dois aparelhos. Verifique as versões anteriores.';
  }

  @override
  String get yesterday => 'Ontem';

  @override
  String get pinned => 'Fixada';
}
