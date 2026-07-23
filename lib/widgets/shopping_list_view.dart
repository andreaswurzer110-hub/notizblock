import 'package:flutter/material.dart';
import '../models/shopping_list.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';

/// Editierbare Einkaufsliste. Zwei Sektionen:
///  - **Einkaufsliste** (oben): je Artikel eine Zeile mit Bezeichnung, einer
///    Mengensteuerung (−/+) und einer Checkbox. Häkchen setzen = „erledigt".
///  - **Erledigt** (unten, einklappbar): abgehakte Artikel. Häkchen entfernen
///    holt den Artikel zurück in die Einkaufsliste – so muss man wiederkehrende
///    Einkäufe nicht neu tippen, sondern nur wieder anhaken.
///
/// Wird im Vollbild-Editor und im Windows/Linux-Sticky-Fenster verwendet. Über
/// einen [GlobalKey] auf [ShoppingListViewState] können Eltern den aktuellen
/// Stand auslesen ([currentJson]), den Fokus prüfen ([hasFocus]) und externe
/// Änderungen einspielen ([setData]) – genau wie bei der Autopool-Tabelle.
class ShoppingListView extends StatefulWidget {
  final String initialData;
  final ValueChanged<String> onChanged;
  final Color textColor;
  final double fontScale;

  const ShoppingListView({
    super.key,
    required this.initialData,
    required this.onChanged,
    this.textColor = Colors.black87,
    this.fontScale = 1.0,
  });

  @override
  State<ShoppingListView> createState() => ShoppingListViewState();
}

/// Ein Artikel im Bearbeitungszustand: Controller/Fokus fürs Namensfeld plus
/// Menge und Erledigt-Flag.
class _ItemCtrl {
  final TextEditingController controller;
  final FocusNode focus;
  int quantity;
  bool done;

  _ItemCtrl({required String name, required this.quantity, required this.done})
      : controller = TextEditingController(text: name),
        focus = FocusNode();

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

class ShoppingListViewState extends State<ShoppingListView> {
  final List<_ItemCtrl> _items = [];
  bool _completedExpanded = true;

  @override
  void initState() {
    super.initState();
    _build(ShoppingListData.fromJsonString(widget.initialData));
  }

  void _build(ShoppingListData data) {
    _disposeItems();
    _items.clear();
    for (final i in data.items) {
      _items.add(_ItemCtrl(name: i.name, quantity: i.quantity, done: i.done));
    }
    // Ganz leere Liste (z.B. neue Notiz): eine leere Startzeile zeigen, damit
    // man sofort lostippen kann – analog zur Autopool-Tabelle. Wird beim
    // Speichern ohnehin verworfen, solange nichts eingetragen wird.
    if (_items.isEmpty) {
      _items.add(_ItemCtrl(name: '', quantity: 1, done: false));
    }
  }

  void _disposeItems() {
    for (final i in _items) {
      i.dispose();
    }
  }

  @override
  void dispose() {
    _disposeItems();
    super.dispose();
  }

  // --- Öffentliche API (für externe Aktualisierung, v.a. Sticky-Fenster) ---

  /// True, wenn gerade in irgendeinem Artikelfeld getippt wird.
  bool get hasFocus => _items.any((i) => i.focus.hasFocus);

  /// Aktueller Stand als JSON-String (für Speichern). Leere Zeilen (kein Name)
  /// werden weggelassen – sie sind nur UI-Platzhalter einer neuen Zeile.
  String get currentJson => _toData().toJsonString();

  /// Inhalt durch externe Daten ersetzen (nur aufrufen, wenn nicht fokussiert).
  void setData(String json) {
    setState(() => _build(ShoppingListData.fromJsonString(json)));
  }

  ShoppingListData _toData() => ShoppingListData([
        for (final i in _items)
          if (i.controller.text.trim().isNotEmpty)
            ShoppingItem(i.controller.text.trim(),
                quantity: i.quantity, done: i.done),
      ]);

  void _emitChange() => widget.onChanged(currentJson);

  // --- Aktionen ---

  void _addItem() {
    final item = _ItemCtrl(name: '', quantity: 1, done: false);
    setState(() => _items.add(item));
    _emitChange();
    // Direkt ins neue Feld springen, damit man sofort lostippen kann.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) item.focus.requestFocus();
    });
  }

  void _setQuantity(_ItemCtrl item, int delta) {
    final next = (item.quantity + delta).clamp(1, 9999);
    if (next == item.quantity) return;
    setState(() => item.quantity = next);
    _emitChange();
  }

  void _toggleDone(_ItemCtrl item) {
    setState(() => item.done = !item.done);
    // Fokus abgeben, damit die Tastatur nicht offen bleibt, während die Zeile
    // in die andere Sektion wandert.
    item.focus.unfocus();
    _emitChange();
  }

  void _deleteItem(_ItemCtrl item) {
    setState(() => _items.remove(item));
    item.dispose();
    _emitChange();
  }

  Color get _tc => widget.textColor;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final active = [for (final i in _items) if (!i.done) i];
    final completed = [for (final i in _items) if (i.done) i];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in active) _activeRow(item),
        const SizedBox(height: 4),
        Align(alignment: Alignment.centerLeft, child: _addButton(l)),
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 8),
          _completedHeader(l, completed.length),
          if (_completedExpanded)
            for (final item in completed) _completedRow(item),
        ],
      ],
    );
  }

  // Zeile in der aktiven Einkaufsliste: [ Artikel ] [ − Menge + ] [ ☐ ] [ 🗑 ]
  Widget _activeRow(_ItemCtrl item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _nameField(item)),
          const SizedBox(width: 4),
          _quantityControl(item),
          const SizedBox(width: 2),
          _checkbox(item),
          _deleteButton(item),
        ],
      ),
    );
  }

  // Zeile in der Erledigt-Liste: [ ✓ Artikel (durchgestrichen) ] [ ×N ] [ ☑ ] [ 🗑 ]
  // Häkchen entfernen holt den Artikel zurück in die Einkaufsliste.
  Widget _completedRow(_ItemCtrl item) {
    final text = item.controller.text.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15 * widget.fontScale,
                  color: _tc.withValues(alpha: 0.55),
                  decoration: TextDecoration.lineThrough,
                  decorationColor: _tc.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
          if (item.quantity > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '×${item.quantity}',
                style: TextStyle(
                  fontSize: 13 * widget.fontScale,
                  color: _tc.withValues(alpha: 0.55),
                ),
              ),
            ),
          _checkbox(item),
          _deleteButton(item),
        ],
      ),
    );
  }

  Widget _nameField(_ItemCtrl item) {
    final l = AppLocalizations.of(context)!;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: _tc.withValues(alpha: 0.25)),
    );
    return TextField(
      controller: item.controller,
      focusNode: item.focus,
      onChanged: (_) => _emitChange(),
      // Enter im Artikelfeld legt gleich die nächste Zeile an (flott mehrere
      // Artikel eintippen), statt einen Zeilenumbruch im Feld einzufügen.
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => _addItem(),
      maxLines: 1,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(fontSize: 15 * widget.fontScale, color: _tc),
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        hintText: l.shoppingItemHint,
        hintStyle: TextStyle(
          color: _tc.withValues(alpha: 0.35),
          fontSize: 14 * widget.fontScale,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _tc.withValues(alpha: 0.6)),
        ),
      ),
    );
  }

  // Kompakte Mengensteuerung: − Zahl +
  Widget _quantityControl(_ItemCtrl item) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _tc.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _qtyButton(
            Icons.remove,
            item.quantity > 1 ? () => _setQuantity(item, -1) : null,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 22),
            alignment: Alignment.center,
            child: Text(
              '${item.quantity}',
              style: TextStyle(
                fontSize: 14 * widget.fontScale,
                fontWeight: FontWeight.w600,
                color: _tc,
              ),
            ),
          ),
          _qtyButton(Icons.add, () => _setQuantity(item, 1)),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 18,
          color: _tc.withValues(alpha: onTap == null ? 0.25 : 0.75),
        ),
      ),
    );
  }

  Widget _checkbox(_ItemCtrl item) {
    return Checkbox(
      value: item.done,
      onChanged: (_) => _toggleDone(item),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(color: _tc.withValues(alpha: 0.6), width: 2),
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? _tc.withValues(alpha: 0.85)
              : Colors.transparent),
      checkColor: _contrastOn(_tc),
    );
  }

  Widget _deleteButton(_ItemCtrl item) {
    final l = AppLocalizations.of(context)!;
    return IconButton(
      icon: const Icon(Icons.close),
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
      tooltip: l.shoppingDeleteItem,
      color: _tc.withValues(alpha: 0.45),
      onPressed: () => _deleteItem(item),
    );
  }

  Widget _addButton(AppLocalizations l) {
    return InkWell(
      onTap: _addItem,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 20, color: _tc),
            const SizedBox(width: 8),
            Text(
              l.shoppingAddItem,
              style: TextStyle(color: _tc, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _completedHeader(AppLocalizations l, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        onTap: () => setState(() => _completedExpanded = !_completedExpanded),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(
                _completedExpanded
                    ? Icons.expand_more
                    : Icons.chevron_right,
                size: 22,
                color: _tc.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Text(
                l.shoppingCompleted(count),
                style: TextStyle(
                  fontSize: 13 * widget.fontScale,
                  fontWeight: FontWeight.bold,
                  color: _tc.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Divider(color: _tc.withValues(alpha: 0.2), height: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Kontrastfarbe (Häkchen) auf einer gegebenen Füllfarbe.
  Color _contrastOn(Color c) =>
      ThemeData.estimateBrightnessForColor(c) == Brightness.dark
          ? Colors.white
          : Colors.black;
}
