import 'dart:io';

import 'package:flutter/material.dart';
import '../models/shopping_list.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';

/// Editierbare Einkaufsliste. Zwei Sektionen:
///  - **Einkaufsliste** (oben): je Artikel eine Zeile mit Anfasser, Bezeichnung,
///    einer Mengensteuerung (−/+) und einer Checkbox. Häkchen setzen =
///    „erledigt".
///  - **Erledigt** (unten, einklappbar): abgehakte Artikel. Häkchen entfernen
///    holt den Artikel zurück in die Einkaufsliste – so muss man wiederkehrende
///    Einkäufe nicht neu tippen, sondern nur wieder anhaken.
///
/// **Reihenfolge** (wie bei der Autopool-Tabelle):
///  - Drag&Drop am Anfasser links. Auf Desktop sofort mit der Maus, auf Touch
///    per langem Druck. Anders als beim Autopool braucht es hier KEINEN
///    Verschiebe-Modus über ein Kontextmenü: die Einkaufszeile hat kein
///    Kontextmenü, mit dem der Long-Press kollidieren könnte.
///  - Alphabetisch sortieren über den Knopf neben „Artikel hinzufügen"
///    (einmalige Aktion, wechselt zwischen A–Z und Z–A – danach lässt sich von
///    Hand weiter umsortieren).
/// Nur die AKTIVE Liste ist umsortierbar; in der Erledigt-Sektion hat die
/// Reihenfolge keine Bedeutung (sie wird beim Sortieren aber mit sortiert).
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
  // Richtung des NÄCHSTEN Sortierlaufs (der Knopf zeigt sie im Tooltip an).
  bool _sortAscending = true;

  /// Nur für Tests: erzwingt den Desktop- (`true`) bzw. Touch-Zweig (`false`).
  /// `null` = echte Plattform. Nötig, weil `Platform.is…` im Test immer die
  /// Rechner-Plattform meldet – der Touch-Pfad wäre auf Windows sonst gar
  /// nicht prüfbar (und genau dort saß der Fehler mit dem Tooltip).
  @visibleForTesting
  static bool? debugForceDesktop;

  bool get _isDesktop =>
      debugForceDesktop ??
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

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

  /// Umsortieren der AKTIVEN Liste per Drag&Drop (Logik in
  /// [reorderActiveItems], damit sie ohne UI testbar ist).
  void _reorderActive(int oldIndex, int newIndex) {
    final next =
        reorderActiveItems(_items, (i) => i.done, oldIndex, newIndex);
    setState(() {
      _items
        ..clear()
        ..addAll(next);
    });
    _emitChange();
  }

  /// Alle Artikel alphabetisch sortieren; die Richtung wechselt bei jedem Druck.
  /// Sortiert wird die flache Liste – dadurch stehen sowohl die aktiven als auch
  /// die erledigten Artikel in ihrer jeweiligen Sektion alphabetisch.
  void _sortAlphabetically() {
    setState(() {
      final ascending = _sortAscending;
      _items.sort((a, b) => compareShoppingNames(
            a.controller.text,
            b.controller.text,
            ascending: ascending,
          ));
      _sortAscending = !ascending;
    });
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
        // shrinkWrap + NeverScrollable, weil das Ganze in einer äußeren
        // SingleChildScrollView steckt (Editor wie Sticky-Fenster) – genau wie
        // bei der Autopool-Tabelle.
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: active.length,
          onReorderItem: _reorderActive,
          proxyDecorator: (child, index, animation) => Material(
            color: Colors.transparent,
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            child: child,
          ),
          itemBuilder: (context, i) => KeyedSubtree(
            key: ObjectKey(active[i]),
            child: _activeRow(active[i], i),
          ),
        ),
        const SizedBox(height: 4),
        _actionRow(l),
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 8),
          _completedHeader(l, completed.length),
          if (_completedExpanded)
            for (final item in completed) _completedRow(item),
        ],
      ],
    );
  }

  // Zeile in der aktiven Einkaufsliste:
  // [ ⠿ ] [ Artikel ] [ − Menge + ] [ ☐ ] [ 🗑 ]
  Widget _activeRow(_ItemCtrl item, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _dragHandle(index),
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

  // Anfasser fürs Umsortieren. Desktop: sofortiges Maus-Drag. Touch: langer
  // Druck startet DIREKT das Ziehen – anders als beim Autopool braucht es
  // keinen Umweg über ein Kontextmenü, weil die Einkaufszeile keine weitere
  // Long-Press-Aktion hat.
  //
  // KEIN Tooltip auf Touch (war real ein Bug in 1.31.2): Flutter löst Tooltips
  // auf Touch-Geräten per LANGEM DRUCK aus – die Sprechblase „Verschieben"
  // gewann damit gegen den Drag-Listener, das Ziehen kam nie zustande und die
  // Blase sah aus wie ein Knopf, der nichts tut. Auf Desktop erscheint der
  // Tooltip beim Überfahren mit der Maus und stört das Ziehen nicht.
  Widget _dragHandle(int index) {
    final icon = Icon(
      Icons.drag_indicator,
      size: 18,
      color: _tc.withValues(alpha: 0.45),
    );

    if (_isDesktop) {
      final l = AppLocalizations.of(context)!;
      return ReorderableDragStartListener(
        index: index,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          // Bewusst derselbe Text wie beim Autopool („Verschieben") – gleiche
          // Geste, gleiche Benennung; kein zusätzlicher Übersetzungsschlüssel.
          child: Tooltip(
            message: l.autopoolMoveRow,
            child: Padding(
              padding: const EdgeInsets.only(right: 2),
              child: icon,
            ),
          ),
        ),
      );
    }

    // Touch: größere Trefferfläche. Das 18-px-Symbol allein ist mit dem Finger
    // kaum zu halten, und daneben liegt sofort das Textfeld – ein Fehlgriff
    // landet dort im Text statt im Ziehen.
    return ReorderableDelayedDragStartListener(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(right: 2),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(child: icon),
        ),
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

  // „Artikel hinzufügen" links, Sortier-Knopf rechts. Der Sortier-Knopf steht
  // erst ab zwei Artikeln zur Verfügung – vorher ist er sinnlos und nimmt im
  // schmalen Sticky-Fenster nur Platz weg.
  Widget _actionRow(AppLocalizations l) {
    final sortable =
        _items.where((i) => i.controller.text.trim().isNotEmpty).length > 1;
    return Row(
      children: [
        // Flexible + Ellipse: im schmalen Sticky-Fenster wird die Beschriftung
        // gekürzt, statt die Zeile überlaufen zu lassen.
        Flexible(child: _addButton(l)),
        const Spacer(),
        if (sortable)
          IconButton(
            icon: const Icon(Icons.sort_by_alpha),
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            tooltip: _sortAscending ? l.shoppingSortAZ : l.shoppingSortZA,
            color: _tc.withValues(alpha: 0.7),
            onPressed: _sortAlphabetically,
          ),
      ],
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
            Flexible(
              child: Text(
                l.shoppingAddItem,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _tc, fontWeight: FontWeight.w500),
              ),
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
