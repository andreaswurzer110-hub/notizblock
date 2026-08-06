// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Notizblock AW';

  @override
  String get newNote => 'Nueva nota';

  @override
  String get settings => 'Ajustes';

  @override
  String get search => 'Buscar';

  @override
  String get searchHint => 'Buscar notas...';

  @override
  String get delete => 'Eliminar';

  @override
  String get deleteNote => 'Eliminar nota';

  @override
  String get deleteNoteConfirm => '¿Seguro que quieres eliminar esta nota?';

  @override
  String get save => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get noNotes => 'Sin notas';

  @override
  String get noNotesHint => 'Toca + para crear una nota nueva';

  @override
  String get noSearchResults => 'Sin resultados';

  @override
  String get emptyNote => 'Nota vacía';

  @override
  String get pin => 'Fijar';

  @override
  String get unpin => 'Soltar';

  @override
  String get color => 'Color';

  @override
  String get archive => 'Archivar';

  @override
  String get titleHint => 'Título';

  @override
  String get contentHint => 'Escribe una nota...';

  @override
  String createdAt(String date) {
    return 'Creada: $date';
  }

  @override
  String modifiedAt(String date) {
    return 'Modificada: $date';
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
  String get themeDark => 'Oscuro';

  @override
  String get defaultColor => 'Color predeterminado';

  @override
  String get googleDrive => 'Google Drive';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String signedInAs(String email) {
    return 'Sesión iniciada como $email';
  }

  @override
  String get sync => 'Sincronizar';

  @override
  String get autoSync => 'Sincronización automática';

  @override
  String lastSync(String date) {
    return 'Última sincronización: $date';
  }

  @override
  String get neverSynced => 'Nunca sincronizado';

  @override
  String get syncSuccess => 'Sincronización correcta';

  @override
  String get syncFailed => 'Error de sincronización';

  @override
  String uploaded(int count) {
    return '$count subidas';
  }

  @override
  String downloaded(int count) {
    return '$count descargadas';
  }

  @override
  String get createBackup => 'Crear copia de seguridad';

  @override
  String get restoreBackup => 'Restaurar copia de seguridad';

  @override
  String get restore => 'Restaurar';

  @override
  String get restoreConfirm =>
      'Se sobrescribirán todas las notas locales. ¿Continuar?';

  @override
  String get backupSuccess => 'Copia de seguridad creada correctamente';

  @override
  String get backupFailed => 'Error al crear la copia de seguridad';

  @override
  String get restoreSuccess => 'Copia de seguridad restaurada correctamente';

  @override
  String get restoreFailed => 'Error al restaurar';

  @override
  String get about => 'Acerca de';

  @override
  String get version => 'Versión';

  @override
  String get openInWindow => 'Abrir en una ventana nueva';

  @override
  String get pinAsWidget => 'Fijar como widget';

  @override
  String get unpinWidget => 'Quitar widget';

  @override
  String get syncNow => 'Sincronizar ahora';

  @override
  String get autostart => 'Inicio automático';

  @override
  String get autostartSubtitle =>
      'Abrir los widgets automáticamente al iniciar el sistema';

  @override
  String get showMainWindow => 'Abrir la ventana principal al inicio';

  @override
  String get showMainWindowSubtitle =>
      'De forma predeterminada solo se abren los widgets fijados';

  @override
  String get fontSize => 'Tamaño de letra';

  @override
  String get fontSizeSample => 'Texto de ejemplo';

  @override
  String get undo => 'Deshacer';

  @override
  String get redo => 'Rehacer';

  @override
  String get notSignedIn => 'No has iniciado sesión en Google Drive';

  @override
  String get archiveAndRestore => 'Archivo y restauración';

  @override
  String get archivedTab => 'Archivadas';

  @override
  String get deletedTab => 'Eliminadas';

  @override
  String get noArchivedNotes => 'Sin notas archivadas';

  @override
  String get noDeletedNotes => 'Sin notas eliminadas';

  @override
  String get deletedSignInHint =>
      'Inicia sesión en Google Drive para ver las notas eliminadas';

  @override
  String get deletedLoadFailed => 'No se pudieron cargar las notas eliminadas';

  @override
  String get noteRestored => 'Nota restaurada';

  @override
  String deletedOn(String date) {
    return 'Eliminada: $date';
  }

  @override
  String get deletePermanently => 'Eliminar permanentemente';

  @override
  String get deletePermanentlyConfirm =>
      '¿Eliminar esta nota permanentemente? No se puede deshacer.';

  @override
  String get autopool => 'Autopool';

  @override
  String get createNoteTitle => '¿Qué quieres crear?';

  @override
  String get noteTypeNote => 'Nota';

  @override
  String get noteTypeNoteSubtitle => 'Nota de texto sencilla';

  @override
  String get noteTypeAutopoolSubtitle => 'Tabla (lista de dispositivos)';

  @override
  String get noteTypeShoppingSubtitle => 'Marca artículos, cuenta cantidades';

  @override
  String get shoppingList => 'Lista de la compra';

  @override
  String get shoppingItemHint => 'Artículo';

  @override
  String get shoppingAddItem => 'Añadir artículo';

  @override
  String shoppingCompleted(int count) {
    return 'Completado ($count)';
  }

  @override
  String get shoppingDeleteItem => 'Eliminar artículo';

  @override
  String shoppingOpenCount(int open, int total) {
    return '$open/$total pendientes';
  }

  @override
  String get allNotes => 'Todas las notas';

  @override
  String get folders => 'Carpetas';

  @override
  String get newFolder => 'Nueva carpeta';

  @override
  String get folderName => 'Nombre de la carpeta';

  @override
  String get renameFolder => 'Cambiar nombre de la carpeta';

  @override
  String get deleteFolder => 'Eliminar carpeta';

  @override
  String deleteFolderConfirm(String name) {
    return '¿Eliminar la carpeta «$name»? Las notas se conservan y dejarán de estar en una carpeta.';
  }

  @override
  String get moveToFolder => 'Mover a carpeta';

  @override
  String get noFolder => 'Sin carpeta';

  @override
  String get addExistingNote => 'Añadir nota existente';

  @override
  String addNotesToFolderTitle(String folder) {
    return 'Añadir notas a «$folder»';
  }

  @override
  String addedToFolderSnack(String folder) {
    return 'Añadido a «$folder»';
  }

  @override
  String get removedFromFolderSnack => 'Eliminado de la carpeta';

  @override
  String get noNotesToAdd => 'No hay más notas para añadir';

  @override
  String get add => 'Añadir';

  @override
  String get autopoolColName => 'Descripción';

  @override
  String get autopoolColOfficeVersion => 'Oficina y versión';

  @override
  String get autopoolColLocation => 'Ubicación';

  @override
  String get autopoolColInventory => 'N.º de inventario';

  @override
  String get autopoolColSerial => 'N.º de serie';

  @override
  String get autopoolColDate => 'Fecha';

  @override
  String get autopoolAddRow => 'Añadir fila';

  @override
  String get autopoolAddRowFull => 'Fila completa (6 campos)';

  @override
  String get autopoolAddRow4 => 'Fila corta (4 campos)';

  @override
  String get autopoolAddRow2 => 'Fila corta (2 campos)';

  @override
  String get autopoolMoveRow => 'Mover';

  @override
  String get autopoolDeleteRow => 'Eliminar fila';

  @override
  String get autopoolMarkRow => 'Marcar / quitar marca';

  @override
  String get autopoolRowColor => 'Color de fila';

  @override
  String get autopoolNoColor => 'Sin color';

  @override
  String get autopoolRenameColumn => 'Cambiar nombre de columna';

  @override
  String get autopoolResetColumn => 'Restablecer al valor predeterminado';

  @override
  String get autopoolColumnLabel => 'Nombre de columna';

  @override
  String get moveUp => 'Subir';

  @override
  String get moveDown => 'Bajar';

  @override
  String get openLink => 'Abrir enlace';

  @override
  String get searchWeb => 'Buscar en la web';

  @override
  String get linkOpenFailed => 'No se pudo abrir el enlace';

  @override
  String get ctxCut => 'Cortar';

  @override
  String get ctxPaste => 'Pegar';

  @override
  String get readOnly => 'Solo lectura';

  @override
  String get creator => 'Creador';

  @override
  String get feedback => 'Comentarios y preguntas';

  @override
  String get close => 'Cerrar';

  @override
  String get bibleVerse1Ref => 'Colosenses 3:17';

  @override
  String get bibleVerse1Text =>
      'Y todo lo que hacéis, sea de palabra o de hecho, hacedlo todo en el nombre del Señor Jesús, dando gracias a Dios Padre por medio de él.';

  @override
  String get bibleVerse2Ref => 'Juan 14:6';

  @override
  String get bibleVerse2Text =>
      'Jesús le dijo: Yo soy el camino, y la verdad, y la vida; nadie viene al Padre, sino por mí.';

  @override
  String get printExport => 'Imprimir';

  @override
  String get printExportTitle => 'Imprimir y exportar';

  @override
  String get printSystem => 'Imprimir';

  @override
  String get printSystemSubtitle => 'Diálogo del sistema (impresora/PDF)';

  @override
  String get exportPdf => 'Guardar como PDF';

  @override
  String get exportTxt => 'Guardar como archivo de texto';

  @override
  String get exportWord => 'Guardar como documento de Word';

  @override
  String exportSaved(String file) {
    return 'Guardado: $file';
  }

  @override
  String exportFailed(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get shareImportTitle => 'Añadir texto compartido';

  @override
  String get shareImportNewNote => 'En una nota nueva';

  @override
  String get shareImportNewNoteSubtitle => 'Crea una nota nueva con el texto';

  @override
  String get shareImportExisting => 'En una nota existente';

  @override
  String get shareImportExistingSubtitle =>
      'Insertar el texto en una nota existente';

  @override
  String get shareImportChooseNote => 'Elegir nota';

  @override
  String get shareInsertPositionTitle => '¿Dónde insertar?';

  @override
  String get shareInsertTop => 'Insertar arriba';

  @override
  String get shareInsertBottom => 'Insertar abajo';

  @override
  String shareInsertedSnack(String title) {
    return 'Texto insertado en «$title»';
  }

  @override
  String get selectNotes => 'Seleccionar';

  @override
  String selectedCount(int count) {
    return '$count seleccionadas';
  }

  @override
  String get selectAllNotes => 'Seleccionar todo';

  @override
  String deleteNotesConfirm(int count) {
    return '¿Eliminar $count notas?';
  }

  @override
  String notesMovedSnack(int count) {
    return '$count notas movidas';
  }

  @override
  String notesArchivedSnack(int count) {
    return '$count notas archivadas';
  }

  @override
  String get versionHistory => 'Versiones anteriores';

  @override
  String get versionHistoryHint =>
      'Versiones del historial de Google Drive (las 30 más recientes por nota)';

  @override
  String get versionHistoryEmpty => 'Todavía no hay versiones anteriores';

  @override
  String get versionHistoryFailed => 'No se pudo cargar el historial';

  @override
  String get versionDeletedMarker => 'eliminada';

  @override
  String get versionRestore => 'Restaurar';

  @override
  String versionRestoreConfirm(String date) {
    return '¿Restaurar la versión del $date? La versión actual permanece en el historial.';
  }

  @override
  String versionRestored(String date) {
    return 'Versión del $date restaurada';
  }

  @override
  String conflictDetected(String title) {
    return 'Conflicto: «$title» se modificó en dos dispositivos. Consulta la versión anterior.';
  }

  @override
  String conflictDetectedMulti(int count) {
    return 'Conflicto: $count notas se modificaron en dos dispositivos. Consulta las versiones anteriores.';
  }

  @override
  String get yesterday => 'Ayer';

  @override
  String get pinned => 'Fijada';
}
