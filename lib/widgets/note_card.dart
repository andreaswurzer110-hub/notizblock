import 'package:flutter/material.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';
import '../models/note.dart';
import '../models/shopping_list.dart';
import '../utils/date_display.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isCompact;
  final bool isWidget;
  // Mehrfachauswahl im Hauptmenü: [selectable] schaltet das Häkchen ein,
  // [selected] markiert die Karte.
  final bool selectable;
  final bool selected;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.isCompact = false,
    this.isWidget = false,
    this.selectable = false,
    this.selected = false,
  });

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _parseColor(note.color);
    final isDark = ThemeData.estimateBrightnessForColor(backgroundColor) ==
        Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    final accent = Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 2,
      shadowColor: Colors.black26,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        // Ausgewählte Karte bekommt einen kräftigen Rahmen (die Notizfarbe
        // bleibt sichtbar, ein Farbfilter würde sie verfälschen).
        side: selected
            ? BorderSide(color: accent, width: 3)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectable)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: selected ? accent : subtitleColor,
                  ),
                ),
              // Indikatoren: angeheftet, als Widget angeheftet, Autopool und/oder
              // Einkaufsliste
              if (note.isPinned ||
                  isWidget ||
                  note.isAutopool ||
                  note.isShopping) ...[
                Wrap(
                  spacing: 12,
                  children: [
                    if (note.isPinned)
                      _badge(Icons.push_pin, AppLocalizations.of(context)!.pinned, subtitleColor),
                    if (isWidget)
                      _badge(Icons.widgets, 'Widget', subtitleColor),
                    if (note.isAutopool)
                      _badge(Icons.table_chart, AppLocalizations.of(context)!.autopool, subtitleColor),
                    if (note.isShopping)
                      _badge(Icons.shopping_cart,
                          AppLocalizations.of(context)!.shoppingList, subtitleColor),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Titel
              if (note.title.isNotEmpty) ...[
                Text(
                  note.title,
                  style: TextStyle(
                    fontSize: isCompact ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  maxLines: isCompact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],

              // Inhalt
              if (note.content.isNotEmpty)
                Flexible(
                  child: Text(
                    note.content,
                    style: TextStyle(
                      fontSize: isCompact ? 12 : 14,
                      color: textColor.withOpacity(0.85),
                      height: 1.4,
                    ),
                    maxLines: isCompact ? 3 : 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Datum
              if (!isCompact) ...[
                const SizedBox(height: 12),
                Text(
                  _formatDate(context, note.modifiedAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: subtitleColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return DateDisplay.time(context, date);
    } else if (difference.inDays == 1) {
      return AppLocalizations.of(context)!.yesterday;
    } else if (difference.inDays < 7) {
      return DateDisplay.weekday(context, date);
    } else {
      return DateDisplay.dayMonth(context, date);
    }
  }
}

// Liste-Ansicht Karte
class NoteListTile extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isWidget;
  // Mehrfachauswahl im Hauptmenü (siehe NoteCard).
  final bool selectable;
  final bool selected;

  const NoteListTile({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.isWidget = false,
    this.selectable = false,
    this.selected = false,
  });

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _parseColor(note.color);
    final isDark = ThemeData.estimateBrightnessForColor(backgroundColor) ==
        Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary, width: 3)
            : BorderSide.none,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: selectable
            ? Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : subtitleColor,
              )
            : (note.isPinned ||
                isWidget ||
                note.isAutopool ||
                note.isShopping)
            // FittedBox: Ab drei Symbolen (angeheftet + Widget + Typ) ist die
            // Spalte höher als die Zeile hergibt – ohne das Verkleinern ragt sie
            // unten heraus (Debug: „RenderFlex overflowed by 12 pixels").
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (note.isPinned)
                      Icon(Icons.push_pin, size: 20, color: textColor),
                    if (isWidget)
                      Icon(Icons.widgets, size: 20, color: subtitleColor),
                    if (note.isAutopool)
                      Icon(Icons.table_chart, size: 20, color: subtitleColor),
                    if (note.isShopping)
                      Icon(Icons.shopping_cart, size: 20, color: subtitleColor),
                  ],
                ),
              )
            : null,
        title: Text(
          note.title.isNotEmpty ? note.title : note.content,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        subtitle: _buildSubtitle(context, textColor, subtitleColor),
        trailing: Text(
          _formatDate(context, note.modifiedAt),
          style: TextStyle(
            fontSize: 12,
            color: subtitleColor,
          ),
        ),
      ),
    );
  }

  /// Untertitel der Listen-Zeile: bei einer Einkaufsliste steht vorne, wie viele
  /// Artikel noch offen sind („1/4 offen"), danach – wie bei allen anderen
  /// Notizen – die Inhalts-Vorschau. Bewusst NUR in der Listen-Ansicht: in der
  /// Kachel-Ansicht ([NoteCard]) sieht man die Artikel ohnehin.
  Widget? _buildSubtitle(
      BuildContext context, Color textColor, Color subtitleColor) {
    final preview =
        note.title.isNotEmpty && note.content.isNotEmpty ? note.content : null;

    Widget? previewText() => preview == null
        ? null
        : Text(
            preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: subtitleColor),
          );

    if (!note.isShopping) return previewText();

    // Leere Artikel (z.B. die noch nicht ausgefüllte letzte Zeile) zählen nicht.
    final items = [
      for (final i in ShoppingListData.fromJsonString(note.autopoolData).items)
        if (i.name.trim().isNotEmpty) i
    ];
    if (items.isEmpty) return previewText();

    final open = items.where((i) => !i.done).length;
    final label = Text(
      AppLocalizations.of(context)!.shoppingOpenCount(open, items.length),
      style: TextStyle(
        color: open > 0 ? textColor : subtitleColor,
        fontWeight: open > 0 ? FontWeight.w600 : FontWeight.w400,
      ),
    );

    if (preview == null) return label;
    return Row(
      children: [
        label,
        const SizedBox(width: 8),
        Expanded(child: previewText()!),
      ],
    );
  }

  String _formatDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return DateDisplay.time(context, date);
    } else if (difference.inDays < 7) {
      return DateDisplay.weekdayShort(context, date);
    } else {
      return DateDisplay.dayMonthNumeric(context, date);
    }
  }
}
