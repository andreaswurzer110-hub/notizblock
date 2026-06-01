import 'package:flutter/material.dart';
import '../models/note.dart';
import 'package:intl/intl.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isCompact;
  final bool isWidget;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.isCompact = false,
    this.isWidget = false,
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
      elevation: 2,
      shadowColor: Colors.black26,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
              // Indikatoren: angeheftet und/oder als Widget angeheftet
              if (note.isPinned || isWidget) ...[
                Wrap(
                  spacing: 12,
                  children: [
                    if (note.isPinned)
                      _badge(Icons.push_pin, 'Angeheftet', subtitleColor),
                    if (isWidget)
                      _badge(Icons.widgets, 'Widget', subtitleColor),
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
                  _formatDate(note.modifiedAt),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(date);
    } else if (difference.inDays == 1) {
      return 'Gestern';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE', 'de').format(date);
    } else {
      return DateFormat('d. MMM', 'de').format(date);
    }
  }
}

// Liste-Ansicht Karte
class NoteListTile extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isWidget;

  const NoteListTile({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.isWidget = false,
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
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: (note.isPinned || isWidget)
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (note.isPinned) Icon(Icons.push_pin, size: 20, color: textColor),
                  if (isWidget)
                    Icon(Icons.widgets, size: 20, color: subtitleColor),
                ],
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
        subtitle: note.title.isNotEmpty && note.content.isNotEmpty
            ? Text(
                note.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: subtitleColor),
              )
            : null,
        trailing: Text(
          _formatDate(note.modifiedAt),
          style: TextStyle(
            fontSize: 12,
            color: subtitleColor,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(date);
    } else if (difference.inDays < 7) {
      return DateFormat('E', 'de').format(date);
    } else {
      return DateFormat('d.M.', 'de').format(date);
    }
  }
}
