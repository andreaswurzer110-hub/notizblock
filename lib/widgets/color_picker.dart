import 'package:flutter/material.dart';
import '../models/note.dart';

class ColorPicker extends StatelessWidget {
  final String selectedColor;
  final ValueChanged<String> onColorSelected;

  const ColorPicker({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: NoteColors.all.map((color) {
        final isSelected = color == selectedColor;
        return GestureDetector(
          onTap: () => onColorSelected(color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _parseColor(color),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}

// Modal Bottom Sheet für die Zeilenfarbe einer Autopool-Zeile. Wie
// [showColorPickerSheet], aber mit zusätzlichem „Keine Farbe"-Feld (Reset auf
// die Zebra-Standardfärbung). Rückgabe: gewählter Hex-Wert, '' für „keine
// Farbe" (zurücksetzen) oder null bei Abbruch. Beschriftungen werden vom Aufrufer
// (mit l10n) übergeben, damit dieses Widget keine l10n-Abhängigkeit braucht.
Future<String?> showRowColorPickerSheet(
  BuildContext context, {
  String? current,
  required String title,
  required String noColorLabel,
}) async {
  Color parse(String hex) =>
      Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
  return await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final primary = Theme.of(context).colorScheme.primary;
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // „Keine Farbe" – setzt auf die Standard-Zebrafärbung zurück.
                Tooltip(
                  message: noColorLabel,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(''),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: current == null ? primary : Colors.grey.shade400,
                          width: current == null ? 3 : 1,
                        ),
                      ),
                      child: Icon(Icons.format_color_reset_outlined,
                          color: current == null ? primary : Colors.grey.shade600),
                    ),
                  ),
                ),
                ...NoteColors.all.map((color) {
                  final isSelected = color == current;
                  return GestureDetector(
                    onTap: () => Navigator.of(context).pop(color),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: parse(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? primary : Colors.grey.shade300,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: isSelected
                          ? Icon(Icons.check, color: primary, size: 24)
                          : null,
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}

// Modal Bottom Sheet für Farbauswahl
Future<String?> showColorPickerSheet(
  BuildContext context, {
  required String currentColor,
}) async {
  return await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Farbe wählen',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            ColorPicker(
              selectedColor: currentColor,
              onColorSelected: (color) {
                Navigator.of(context).pop(color);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}
