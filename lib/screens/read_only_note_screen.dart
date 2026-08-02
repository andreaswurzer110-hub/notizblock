import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/settings_provider.dart';
import '../widgets/autopool_table.dart';
import '../widgets/shopping_list_view.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';

/// Reiner Anzeige-Screen für eine Notiz (kein Bearbeiten, „nur anzeigen").
///
/// Wird aus dem Archiv-/Papierkorb-Bildschirm geöffnet, damit man archivierte
/// bzw. gelöschte Notizen lesen kann, ohne sie vorher wiederherzustellen.
/// Autopool-Tabellen werden über [IgnorePointer] rein anzeigend gerendert
/// (keinerlei Edit-Interaktion: kein Tippen, kein Kontextmenü, kein Verschieben);
/// Textnotizen als [SelectableText] (lesbar + kopierbar, aber nicht editierbar).
class ReadOnlyNoteScreen extends StatelessWidget {
  final Note note;

  const ReadOnlyNoteScreen({super.key, required this.note});

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final noteColor = _parseColor(note.color);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final fontScale = context.watch<SettingsProvider>().noteFontScale;

    // Textfarbe je nach Helligkeit der Notizfarbe (wie im Editor/Sticky).
    final noteTextColor =
        ThemeData.estimateBrightnessForColor(noteColor) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    // Dark Mode: dunkles Scaffold + Notizbereich als farbige Karte; sonst
    // alles in Notizfarbe (analog NoteEditorScreen).
    final scaffoldColor = isDarkMode ? theme.scaffoldBackgroundColor : noteColor;
    final appBarColor =
        isDarkMode ? theme.appBarTheme.backgroundColor : noteColor;
    final foregroundColor = isDarkMode ? Colors.white : noteTextColor;

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        // Klarer „Nur Lesen"-Hinweis als Titel (kein Bearbeiten-Affordance).
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility_outlined, size: 18),
            const SizedBox(width: 8),
            Text(l10n.readOnly),
          ],
        ),
      ),
      body: Container(
        margin: isDarkMode ? const EdgeInsets.all(12) : EdgeInsets.zero,
        decoration: isDarkMode
            ? BoxDecoration(
                color: noteColor,
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note.title.isNotEmpty) ...[
                SelectableText(
                  note.title,
                  style: TextStyle(
                    fontSize: 24 * fontScale,
                    fontWeight: FontWeight.bold,
                    color: noteTextColor,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (note.isAutopool)
                // Tabelle rein anzeigend: IgnorePointer blockt jede Interaktion
                // (Tippen/Kontextmenü/Drag) → keine Bearbeitung möglich.
                IgnorePointer(
                  child: AutopoolTable(
                    initialData: note.autopoolData,
                    onChanged: (_) {},
                    textColor: noteTextColor,
                    fontScale: fontScale,
                  ),
                )
              else if (note.isShopping)
                // Einkaufsliste rein anzeigend (wie Autopool): IgnorePointer
                // blockt jede Interaktion → nur ansehen, nicht abhaken/ändern.
                IgnorePointer(
                  child: ShoppingListView(
                    initialData: note.autopoolData,
                    onChanged: (_) {},
                    textColor: noteTextColor,
                    fontScale: fontScale,
                  ),
                )
              else
                SelectableText(
                  note.content,
                  style: TextStyle(
                    fontSize: 16 * fontScale,
                    height: 1.6,
                    color: noteTextColor,
                  ),
                  // Zeilenhöhe an der eingestellten Schriftgröße festnageln (wie
                  // im Editor), damit Zeichen mit Fallback-Schrift die Zeilen
                  // nicht höher machen.
                  strutStyle: StrutStyle(
                    fontSize: 16 * fontScale,
                    height: 1.6,
                    forceStrutHeight: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
