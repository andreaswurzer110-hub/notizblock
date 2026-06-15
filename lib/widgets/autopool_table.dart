import 'package:flutter/material.dart';
import '../models/autopool.dart';
import 'color_picker.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';

/// Editierbare Autopool-Tabelle (6 Spalten je Zeile). Wird sowohl im Vollbild-
/// Editor als auch im Windows-Sticky-Fenster verwendet.
///
/// - Desktop/breit: alle 6 Felder in einer Zeile.
/// - Handy/schmal: drei Zeilen à zwei Felder pro Gerät (lesbarer als 6 quer).
/// - Zeilen per ↑/↓ an der Seite umsortierbar (oder per Drag&Drop am Anfasser).
/// - **Zeilen-Kontextmenü** (Rechtsklick auf die Zeile bzw. langer Druck auf den
///   Anfasser links): Zeile einfärben, markieren (durchgestrichen) und löschen.
///   Diese Aktionen haben KEINE eigenen Buttons mehr an der Seite.
/// - **Spaltenüberschriften umbenennbar** per Rechtsklick / langem Druck auf die
///   Überschrift (eigener Name pro Notiz; auf Standard zurücksetzbar).
/// - Felder sind umrahmt und wachsen mit dem Inhalt (kein Abschneiden).
///
/// Über einen [GlobalKey] auf [AutopoolTableState] können Eltern den aktuellen
/// Stand auslesen ([currentJson]), den Fokus prüfen ([hasFocus]) und externe
/// Änderungen einspielen ([setData]) – genutzt fürs Sticky-Fenster.
class AutopoolTable extends StatefulWidget {
  final String initialData;
  final ValueChanged<String> onChanged;
  final Color textColor;
  final double fontScale;

  const AutopoolTable({
    super.key,
    required this.initialData,
    required this.onChanged,
    this.textColor = Colors.black87,
    this.fontScale = 1.0,
  });

  @override
  State<AutopoolTable> createState() => AutopoolTableState();
}

class AutopoolTableState extends State<AutopoolTable> {
  // Relative Spaltenbreiten (breite Ansicht). Bezeichnung/Dienststelle breiter,
  // Ort/Datum schmaler.
  static const List<int> _flex = [4, 4, 2, 3, 3, 2];
  static const double _narrowBreakpoint = 620;
  // Schmal (Handy): pro Gerät drei Zeilen à zwei Felder.
  static const List<List<int>> _narrowGroups = [
    [0, 1],
    [2, 3],
    [4, 5],
  ];
  // Anfasser/Pfeile links auf Desktop größer, auf Handy kompakt. `_narrow` wird
  // im build() aus der verfügbaren Breite gesetzt.
  bool _narrow = false;
  double get _arrowWidth => _narrow ? 24 : 40;
  double get _iconSize => _narrow ? 18.0 : 24.0;

  final List<List<TextEditingController>> _rows = [];
  final List<List<FocusNode>> _focus = [];
  final List<bool> _marked = [];
  // Eigene Zeilenfarbe je Zeile (Hex `#RRGGBB`) oder null = Zebra-Standard.
  final List<String?> _colors = [];
  // Benutzerdefinierte Spaltenüberschriften (Länge kAutopoolColCount) oder null
  // = lokalisierte Standardüberschriften. Ein null-Eintrag = diese Spalte Standard.
  List<String?>? _headers;

  @override
  void initState() {
    super.initState();
    _buildControllers(AutopoolData.fromJsonString(widget.initialData));
  }

  void _buildControllers(AutopoolData data) {
    _disposeControllers();
    _rows.clear();
    _focus.clear();
    _marked.clear();
    _colors.clear();
    for (final r in data.rows) {
      _rows.add([for (final c in r.cells) TextEditingController(text: c)]);
      _focus.add([for (var i = 0; i < kAutopoolColCount; i++) FocusNode()]);
      _marked.add(r.marked);
      _colors.add(r.color);
    }
    _headers = data.headers;
    if (_rows.isEmpty) _addEmptyRowInternal();
  }

  void _disposeControllers() {
    for (final r in _rows) {
      for (final c in r) {
        c.dispose();
      }
    }
    for (final r in _focus) {
      for (final f in r) {
        f.dispose();
      }
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  // --- Öffentliche API (für externe Aktualisierung, v.a. Sticky-Fenster) ---

  /// True, wenn gerade in irgendeiner Zelle getippt wird.
  bool get hasFocus => _focus.any((row) => row.any((f) => f.hasFocus));

  /// Aktueller Stand als JSON-String (für Speichern).
  String get currentJson => _toData().toJsonString();

  /// Inhalt durch externe Daten ersetzen (nur aufrufen, wenn nicht fokussiert).
  void setData(String json) {
    setState(() => _buildControllers(AutopoolData.fromJsonString(json)));
  }

  AutopoolData _toData() => AutopoolData([
        for (var i = 0; i < _rows.length; i++)
          AutopoolRow([for (final c in _rows[i]) c.text],
              marked: _marked[i], color: _colors[i]),
      ], headers: _headers);

  void _emitChange() => widget.onChanged(currentJson);

  Color _parseColor(String hex) =>
      Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

  void _addEmptyRowInternal() {
    _rows.add([
      for (var i = 0; i < kAutopoolColCount; i++) TextEditingController()
    ]);
    _focus.add([for (var i = 0; i < kAutopoolColCount; i++) FocusNode()]);
    _marked.add(false);
    _colors.add(null);
  }

  void _addRow() {
    setState(_addEmptyRowInternal);
    _emitChange();
  }

  void _deleteRow(int index) {
    setState(() {
      for (final c in _rows[index]) {
        c.dispose();
      }
      for (final f in _focus[index]) {
        f.dispose();
      }
      _rows.removeAt(index);
      _focus.removeAt(index);
      _marked.removeAt(index);
      _colors.removeAt(index);
      if (_rows.isEmpty) _addEmptyRowInternal();
    });
    _emitChange();
  }

  void _moveRow(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _rows.length) return;
    setState(() {
      _rows.insert(target, _rows.removeAt(index));
      _focus.insert(target, _focus.removeAt(index));
      _marked.insert(target, _marked.removeAt(index));
      _colors.insert(target, _colors.removeAt(index));
    });
    _emitChange();
  }

  // Drag&Drop-Reorder (ReorderableListView liefert beim Verschieben nach unten
  // ein newIndex hinter der entfernten Position → um 1 korrigieren).
  void _reorderRow(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      _rows.insert(newIndex, _rows.removeAt(oldIndex));
      _focus.insert(newIndex, _focus.removeAt(oldIndex));
      _marked.insert(newIndex, _marked.removeAt(oldIndex));
      _colors.insert(newIndex, _colors.removeAt(oldIndex));
    });
    _emitChange();
  }

  void _toggleMark(int index) {
    setState(() => _marked[index] = !_marked[index]);
    _emitChange();
  }

  void _setRowColor(int index, String? hex) {
    setState(() => _colors[index] = hex);
    _emitChange();
  }

  // Eine Spaltenüberschrift setzen (null/leer = zurück auf Standard).
  void _setColumnHeader(int col, String? name) {
    setState(() {
      final h = List<String?>.filled(kAutopoolColCount, null);
      if (_headers != null) {
        for (var i = 0; i < kAutopoolColCount; i++) {
          h[i] = _headers![i];
        }
      }
      final trimmed = name?.trim();
      h[col] = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
      _headers = h.any((e) => e != null) ? h : null;
    });
    _emitChange();
  }

  // Effektive Überschrift einer Spalte: eigener Name oder lokalisierter Standard.
  String _colLabel(int c, List<String> defaults) {
    final custom = _headers?[c];
    return (custom != null && custom.isNotEmpty) ? custom : defaults[c];
  }

  List<String> _columns(AppLocalizations l) => [
        l.autopoolColName,
        l.autopoolColOfficeVersion,
        l.autopoolColLocation,
        l.autopoolColInventory,
        l.autopoolColSerial,
        l.autopoolColDate,
      ];

  // --- Kontextmenüs ---

  RelativeRect _menuPosition(Offset globalPos) {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    return RelativeRect.fromRect(
      globalPos & const Size(40, 40),
      Offset.zero & overlay.size,
    );
  }

  // Zeilen-Kontextmenü: Einfärben / Markieren / Löschen.
  Future<void> _showRowMenu(int index, Offset globalPos) async {
    if (index < 0 || index >= _rows.length) return;
    final l = AppLocalizations.of(context)!;
    final action = await showMenu<String>(
      context: context,
      position: _menuPosition(globalPos),
      items: [
        PopupMenuItem(
          value: 'color',
          child: Row(children: [
            const Icon(Icons.palette_outlined, size: 20),
            const SizedBox(width: 12),
            Text(l.autopoolRowColor),
          ]),
        ),
        PopupMenuItem(
          value: 'mark',
          child: Row(children: [
            const Icon(Icons.format_strikethrough, size: 20),
            const SizedBox(width: 12),
            Text(l.autopoolMarkRow),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            const Icon(Icons.delete_outline, size: 20, color: Colors.red),
            const SizedBox(width: 12),
            Text(l.autopoolDeleteRow,
                style: const TextStyle(color: Colors.red)),
          ]),
        ),
      ],
    );
    if (action == null || !mounted || index >= _rows.length) return;
    switch (action) {
      case 'color':
        final chosen = await showRowColorPickerSheet(
          context,
          current: _colors[index],
          title: l.autopoolRowColor,
          noColorLabel: l.autopoolNoColor,
        );
        if (chosen == null || !mounted || index >= _rows.length) return;
        _setRowColor(index, chosen.isEmpty ? null : chosen);
        break;
      case 'mark':
        _toggleMark(index);
        break;
      case 'delete':
        _deleteRow(index);
        break;
    }
  }

  // Überschriften-Kontextmenü: Spalte umbenennen / auf Standard zurücksetzen.
  Future<void> _showHeaderMenu(
      int col, Offset globalPos, List<String> defaults) async {
    final l = AppLocalizations.of(context)!;
    final hasCustom = _headers?[col] != null;
    final action = await showMenu<String>(
      context: context,
      position: _menuPosition(globalPos),
      items: [
        PopupMenuItem(
          value: 'rename',
          child: Row(children: [
            const Icon(Icons.edit_outlined, size: 20),
            const SizedBox(width: 12),
            Text(l.autopoolRenameColumn),
          ]),
        ),
        if (hasCustom)
          PopupMenuItem(
            value: 'reset',
            child: Row(children: [
              const Icon(Icons.restart_alt, size: 20),
              const SizedBox(width: 12),
              Text(l.autopoolResetColumn),
            ]),
          ),
      ],
    );
    if (action == null || !mounted) return;
    if (action == 'rename') {
      final newName = await _promptColumnName(_colLabel(col, defaults));
      if (newName != null && mounted) _setColumnHeader(col, newName);
    } else if (action == 'reset') {
      _setColumnHeader(col, null);
    }
  }

  Future<String?> _promptColumnName(String current) async {
    final l = AppLocalizations.of(context)!;
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.autopoolRenameColumn),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.autopoolColumnLabel),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(l.save),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cols = _columns(l);

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < _narrowBreakpoint;
        _narrow = narrow;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(cols, narrow),
            const SizedBox(height: 6),
            // Zeilen umsortierbar per ↑/↓ ODER per Drag&Drop am Anfasser (links).
            // shrinkWrap + NeverScrollable, weil das Ganze in einer äußeren
            // SingleChildScrollView steckt (Editor wie Sticky-Fenster).
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _rows.length,
              onReorder: _reorderRow,
              proxyDecorator: (child, index, animation) => Material(
                color: Colors.transparent,
                elevation: 6,
                borderRadius: BorderRadius.circular(6),
                child: child,
              ),
              itemBuilder: (context, i) => _buildRow(i, cols, narrow),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add),
                label: Text(l.autopoolAddRow),
                style: TextButton.styleFrom(foregroundColor: widget.textColor),
              ),
            ),
          ],
        );
      },
    );
  }

  // Spaltenüberschrift (einmal oben). Breit: eine Zeile; schmal: zwei Zeilen.
  // Jede Überschrift ist per Rechtsklick / langem Druck umbenennbar.
  Widget _buildHeader(List<String> cols, bool narrow) {
    Widget label(int c) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapDown: (d) =>
              _showHeaderMenu(c, d.globalPosition, cols),
          onLongPressStart: (d) => _showHeaderMenu(c, d.globalPosition, cols),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: Text(
              _colLabel(c, cols),
              style: TextStyle(
                fontSize: 11 * widget.fontScale,
                fontWeight: FontWeight.bold,
                color: widget.textColor.withValues(alpha: 0.7),
              ),
            ),
          ),
        );

    if (narrow) {
      return Column(
        children: [
          for (var g = 0; g < _narrowGroups.length; g++) ...[
            if (g > 0) const SizedBox(height: 4),
            Row(children: [
              SizedBox(width: _arrowWidth),
              for (final c in _narrowGroups[g]) Expanded(child: label(c)),
            ]),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(width: _arrowWidth),
        for (var c = 0; c < kAutopoolColCount; c++)
          Expanded(flex: _flex[c], child: label(c)),
      ],
    );
  }

  Widget _buildRow(int index, List<String> cols, bool narrow) {
    // Eigene Zeilenfarbe? Dann diese als Hintergrund + passende Textfarbe (Kontrast
    // zur Zeilenfarbe, unabhängig von der Notizfarbe). Sonst Zebra + Notiz-Textfarbe.
    final customHex = _colors[index];
    final customColor = customHex != null ? _parseColor(customHex) : null;
    final rowTextColor = customColor != null
        ? (ThemeData.estimateBrightnessForColor(customColor) == Brightness.dark
            ? Colors.white
            : Colors.black87)
        : widget.textColor;
    final bg = customColor ??
        widget.textColor.withValues(alpha: index.isEven ? 0.04 : 0.11);

    final Widget cells;
    if (narrow) {
      cells = Column(
        children: [
          for (var g = 0; g < _narrowGroups.length; g++) ...[
            if (g > 0) const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final c in _narrowGroups[g])
                  Expanded(
                      child: _cell(index, c, _colLabel(c, cols), rowTextColor)),
              ],
            ),
          ],
        ],
      );
    } else {
      cells = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < kAutopoolColCount; c++)
            Expanded(
                flex: _flex[c],
                child: _cell(index, c, _colLabel(c, cols), rowTextColor)),
        ],
      );
    }

    return GestureDetector(
      // Rechtsklick irgendwo auf der Zeile öffnet das Zeilenmenü (Desktop). Über
      // den Zellen gewinnt das Textfeld die Geste (zeigt dessen Textmenü) – das
      // ist gewollt. Der Anfasser links ist der zuverlässige Auslöser (auch
      // Long-Press auf Android), s. _arrows().
      key: ObjectKey(_rows[index]),
      onSecondaryTapDown: (d) => _showRowMenu(index, d.globalPosition),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
                width: _arrowWidth, child: _arrows(index, rowTextColor)),
            Expanded(child: cells),
          ],
        ),
      ),
    );
  }

  // Linke Spalte: ↑ / Anfasser / ↓. Der Anfasser ist zugleich der zuverlässige
  // Auslöser für das Zeilen-Kontextmenü (Rechtsklick + langer Druck auf Android),
  // ohne die Textauswahl in den Zellen zu stören.
  Widget _arrows(int index, Color color) {
    final l = AppLocalizations.of(context)!;
    final last = _rows.length - 1;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (d) => _showRowMenu(index, d.globalPosition),
      onLongPressStart: (d) => _showRowMenu(index, d.globalPosition),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconBtn(
            Icons.keyboard_arrow_up,
            l.moveUp,
            index > 0 ? () => _moveRow(index, -1) : null,
            color,
          ),
          // Anfasser für Drag&Drop (zusätzlich zu den Pfeilen): am schnellsten,
          // um eine Zeile über mehrere Positionen zu verschieben.
          ReorderableDragStartListener(
            index: index,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: _narrow ? 1 : 2),
                child: Icon(
                  Icons.drag_indicator,
                  size: _iconSize,
                  color: color.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
          _iconBtn(
            Icons.keyboard_arrow_down,
            l.moveDown,
            index < last ? () => _moveRow(index, 1) : null,
            color,
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(
      IconData icon, String tooltip, VoidCallback? onPressed, Color color) {
    return IconButton(
      iconSize: _iconSize,
      padding: EdgeInsets.all(_narrow ? 1 : 3),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(),
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: _iconSize,
        color: color.withValues(alpha: onPressed == null ? 0.2 : 0.6),
      ),
    );
  }

  Widget _cell(int row, int col, String label, Color cellTextColor) {
    final marked = _marked[row];
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: cellTextColor.withValues(alpha: 0.25)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: TextField(
        controller: _rows[row][col],
        focusNode: _focus[row][col],
        onChanged: (_) => _emitChange(),
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(
          fontSize: 13 * widget.fontScale,
          color: cellTextColor.withValues(alpha: marked ? 0.55 : 1.0),
          decoration: marked ? TextDecoration.lineThrough : null,
          decorationColor: cellTextColor,
          decorationThickness: 2,
        ),
        decoration: InputDecoration(
          isDense: true,
          // Keine Füllfarbe: die Zelle zeigt die Notiz-/Zeilenfarbe, nur der
          // Rahmen umgibt sie. Sonst dunkle Theme-Füllung über der Notizfarbe.
          filled: false,
          hintText: label,
          hintStyle: TextStyle(
            color: cellTextColor.withValues(alpha: 0.35),
            fontSize: 11 * widget.fontScale,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          border: border,
          enabledBorder: border,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: cellTextColor.withValues(alpha: 0.6)),
          ),
        ),
      ),
    );
  }
}
