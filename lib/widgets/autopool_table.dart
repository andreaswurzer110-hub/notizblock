import 'package:flutter/material.dart';
import '../models/autopool.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';

/// Editierbare Autopool-Tabelle (7 Spalten je Zeile). Wird sowohl im Vollbild-
/// Editor als auch im Windows-Sticky-Fenster verwendet.
///
/// - Desktop/breit: alle 6 Felder in einer Zeile.
/// - Handy/schmal: drei Zeilen à zwei Felder pro Gerät (lesbarer als 6 quer).
/// - Zeilen per ↑/↓ an der Seite umsortierbar, abwechselnd eingefärbt (Zebra).
/// - Zeile markierbar (Text durchgestrichen) zum Vormerken; Markierung wieder
///   entfernbar oder Zeile löschen.
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
  // Buttons (Verschieben/Markieren/Löschen) auf Desktop größer, auf Handy
  // kompakt. `_narrow` wird im build() aus der verfügbaren Breite gesetzt.
  bool _narrow = false;
  double get _arrowWidth => _narrow ? 24 : 40;
  double get _actionWidth => _narrow ? 28 : 46;
  double get _iconSize => _narrow ? 18.0 : 24.0;

  final List<List<TextEditingController>> _rows = [];
  final List<List<FocusNode>> _focus = [];
  final List<bool> _marked = [];

  @override
  void initState() {
    super.initState();
    _buildControllers(AutopoolData.fromJsonString(widget.initialData).rows);
  }

  void _buildControllers(List<AutopoolRow> rows) {
    _disposeControllers();
    _rows.clear();
    _focus.clear();
    _marked.clear();
    for (final r in rows) {
      _rows.add([for (final c in r.cells) TextEditingController(text: c)]);
      _focus.add([for (var i = 0; i < kAutopoolColCount; i++) FocusNode()]);
      _marked.add(r.marked);
    }
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
    setState(() => _buildControllers(AutopoolData.fromJsonString(json).rows));
  }

  AutopoolData _toData() => AutopoolData([
        for (var i = 0; i < _rows.length; i++)
          AutopoolRow([for (final c in _rows[i]) c.text], marked: _marked[i]),
      ]);

  void _emitChange() => widget.onChanged(currentJson);

  void _addEmptyRowInternal() {
    _rows.add([
      for (var i = 0; i < kAutopoolColCount; i++) TextEditingController()
    ]);
    _focus.add([for (var i = 0; i < kAutopoolColCount; i++) FocusNode()]);
    _marked.add(false);
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
    });
    _emitChange();
  }

  void _toggleMark(int index) {
    setState(() => _marked[index] = !_marked[index]);
    _emitChange();
  }

  List<String> _columns(AppLocalizations l) => [
        l.autopoolColName,
        l.autopoolColOfficeVersion,
        l.autopoolColLocation,
        l.autopoolColInventory,
        l.autopoolColSerial,
        l.autopoolColDate,
      ];

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
            for (var i = 0; i < _rows.length; i++) _buildRow(i, cols, narrow),
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
  Widget _buildHeader(List<String> cols, bool narrow) {
    Widget label(int c) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Text(
            cols[c],
            style: TextStyle(
              fontSize: 11 * widget.fontScale,
              fontWeight: FontWeight.bold,
              color: widget.textColor.withValues(alpha: 0.7),
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
              SizedBox(width: _actionWidth),
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
        SizedBox(width: _actionWidth),
      ],
    );
  }

  Widget _buildRow(int index, List<String> cols, bool narrow) {
    // Zebra: abwechselnd kräftigere/leichtere Einfärbung relativ zur Textfarbe,
    // damit der Wechsel auf jeder Notizfarbe sichtbar ist.
    final zebra =
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
                  Expanded(child: _cell(index, c, cols[c])),
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
            Expanded(flex: _flex[c], child: _cell(index, c, cols[c])),
        ],
      );
    }

    return Container(
      key: ObjectKey(_rows[index]),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: zebra,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: _arrowWidth, child: _arrows(index)),
          Expanded(child: cells),
          SizedBox(
            width: _actionWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _markButton(index),
                _deleteButton(index),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrows(int index) {
    final l = AppLocalizations.of(context)!;
    final last = _rows.length - 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconBtn(
          Icons.keyboard_arrow_up,
          l.moveUp,
          index > 0 ? () => _moveRow(index, -1) : null,
        ),
        _iconBtn(
          Icons.keyboard_arrow_down,
          l.moveDown,
          index < last ? () => _moveRow(index, 1) : null,
        ),
      ],
    );
  }

  Widget _markButton(int index) {
    final l = AppLocalizations.of(context)!;
    final marked = _marked[index];
    return _iconBtn(
      Icons.format_strikethrough,
      l.autopoolMarkRow,
      () => _toggleMark(index),
      color: marked
          ? widget.textColor
          : widget.textColor.withValues(alpha: 0.4),
    );
  }

  Widget _deleteButton(int index) {
    final l = AppLocalizations.of(context)!;
    return _iconBtn(
      Icons.delete_outline,
      l.autopoolDeleteRow,
      () => _deleteRow(index),
      color: widget.textColor.withValues(alpha: 0.55),
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback? onPressed,
      {Color? color}) {
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
        color: color ??
            widget.textColor
                .withValues(alpha: onPressed == null ? 0.2 : 0.6),
      ),
    );
  }

  Widget _cell(int row, int col, String label) {
    final marked = _marked[row];
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide:
          BorderSide(color: widget.textColor.withValues(alpha: 0.25)),
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
          color: widget.textColor.withValues(alpha: marked ? 0.55 : 1.0),
          decoration: marked ? TextDecoration.lineThrough : null,
          decorationColor: widget.textColor,
          decorationThickness: 2,
        ),
        decoration: InputDecoration(
          isDense: true,
          // Keine Füllfarbe: die Zelle zeigt die Notiz-/Zebra-Farbe, nur der
          // Rahmen umgibt sie. Sonst dunkle Theme-Füllung über der Notizfarbe.
          filled: false,
          hintText: label,
          hintStyle: TextStyle(
            color: widget.textColor.withValues(alpha: 0.35),
            fontSize: 11 * widget.fontScale,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          border: border,
          enabledBorder: border,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide:
                BorderSide(color: widget.textColor.withValues(alpha: 0.6)),
          ),
        ),
      ),
    );
  }
}
