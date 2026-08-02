import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';

// Kontextmenü für die Notiz-Textfelder: ergänzt die Standard-Aktionen
// (Ausschneiden/Kopieren/Einfügen/Alles markieren) um einen Eintrag, der die
// Auswahl im Browser öffnet. Sieht die Auswahl wie eine Web-Adresse aus ->
// „Link öffnen" (direkt); sonst „Im Web suchen" (Google-Suche nach dem Text).
// Kein Eingriff ins Textmodell – reine Zusatzaktion über url_launcher.

final RegExp _schemeRe = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://');
final RegExp _domainRe =
    RegExp(r'^(www\.)?[a-zA-Z0-9\-]+(\.[a-zA-Z0-9\-]+)+(/\S*)?$');
final RegExp _wsRe = RegExp(r'\s');

// Sieht der (getrimmte) Text wie eine Web-Adresse aus? Mehrere Wörter (=
// Whitespace) gelten als Text, nicht als Link.
bool looksLikeUrl(String raw) {
  final s = raw.trim();
  if (s.isEmpty || _wsRe.hasMatch(s)) return false;
  if (_schemeRe.hasMatch(s)) return true;
  return _domainRe.hasMatch(s);
}

// Ziel-URL bauen: echte Adresse -> ggf. https:// voranstellen; sonst Google-
// Suche nach dem Text.
Uri _targetUri(String raw) {
  final s = raw.trim();
  if (looksLikeUrl(s)) {
    return Uri.parse(_schemeRe.hasMatch(s) ? s : 'https://$s');
  }
  return Uri.parse(
      'https://www.google.com/search?q=${Uri.encodeQueryComponent(s)}');
}

// Whitespace-begrenztes Token, das den Bereich [start, end] umschließt. Damit
// lässt sich die GANZE URL gewinnen – auch wenn der Cursor nur drinsteht oder
// (typisch Android-Longpress) nur ein Teilwort markiert ist.
String _tokenSpanning(String text, int start, int end) {
  bool isWs(int i) => i < 0 || i >= text.length || _wsRe.hasMatch(text[i]);
  int s = start.clamp(0, text.length);
  int e = end.clamp(0, text.length);
  while (s > 0 && !isWs(s - 1)) {
    s--;
  }
  while (e < text.length && !isWs(e)) {
    e++;
  }
  return text.substring(s, e);
}

Future<void> _open(BuildContext context, String raw) async {
  // Messenger + Fehlertext vor dem await greifen (Kontext kann danach weg sein).
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failMsg = AppLocalizations.of(context)!.linkOpenFailed;
  bool ok = false;
  try {
    ok = await launchUrl(_targetUri(raw), mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    messenger?.showSnackBar(SnackBar(content: Text(failMsg)));
  }
}

// --- Einfügen: Text normalisieren ------------------------------------------

// Zeichen, die beim Kopieren aus Web/PDF/Office regelmäßig mitkommen, im
// Notizfeld aber nur Ärger machen. Sie sind unsichtbar bzw. sehen aus wie ein
// Leerzeichen, gehören aber zu anderen Unicode-Blöcken -> Flutter rendert sie
// mit einer ANDEREN (Fallback-)Schrift. Deren Metrik ist größer, wodurch die
// ganze Zeile höher wird: der eingefügte Absatz wirkt größer als der Rest der
// Notiz, obwohl die Schriftgröße identisch ist (gemeldeter Fehler „eingefügter
// Text ist größer"). Beim Einfügen daher auf die normalen Entsprechungen
// zurückführen.
// Die Zeichen werden über ihren Code-Punkt geprüft und nicht als Literal in den
// Quelltext geschrieben: unsichtbare Zeichen wären dort nicht erkennbar und beim
// Bearbeiten der Datei schnell zerstört.

// Sehen aus wie ein Leerzeichen, stammen aber aus anderen Unicode-Blöcken
// (geschütztes, schmales, halbes, ideografisches Leerzeichen …).
const List<int> _weirdSpaceCodes = <int>[
  0x00A0, 0x1680, 0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005,
  0x2006, 0x2007, 0x2008, 0x2009, 0x200A, 0x202F, 0x205F, 0x3000,
];

// Unsichtbar: Zero-Width-Space/Non-Joiner, Word-Joiner, BOM, weiches
// Trennzeichen, Bidi-Steuerzeichen. Der Zero-Width-JOINER (0x200D) fehlt hier
// bewusst: er hält zusammengesetzte Emoji zusammen und muss erhalten bleiben.
const List<int> _invisibleCodes = <int>[
  0x00AD, 0x180E, 0x200B, 0x200C, 0x2060, 0xFEFF,
  0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
  0x2066, 0x2067, 0x2068, 0x2069,
];

// Unicode-Zeilen- und Absatztrenner.
const List<int> _lineSepCodes = <int>[0x2028, 0x2029];

/// Aus der Zwischenablage kommenden Text für ein Notizfeld aufbereiten:
/// Zeilenenden vereinheitlichen, exotische Leerzeichen zu normalen machen und
/// unsichtbare Steuerzeichen entfernen. Der sichtbare Text bleibt unverändert.
String normalizePastedText(String raw) {
  final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final buf = StringBuffer();
  for (final rune in normalized.runes) {
    if (_lineSepCodes.contains(rune)) {
      buf.write('\n');
    } else if (_weirdSpaceCodes.contains(rune)) {
      buf.write(' ');
    } else if (!_invisibleCodes.contains(rune)) {
      buf.writeCharCode(rune);
    }
  }
  return buf.toString();
}

// Einfügen mit normalisiertem Text (siehe normalizePastedText). Fällt bei
// leerer Zwischenablage/ungültiger Auswahl auf das Standard-Einfügen zurück.
Future<void> _pasteNormalized(
    EditableTextState state, ContextMenuButtonItem original) async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final raw = data?.text;
  final value = state.textEditingValue;
  if (raw == null || raw.isEmpty || !value.selection.isValid) {
    original.onPressed?.call();
    return;
  }
  final text = normalizePastedText(raw);
  if (text == raw) {
    original.onPressed?.call(); // nichts zu bereinigen -> Standardweg
    return;
  }
  final sel = value.selection;
  state.userUpdateTextEditingValue(
    TextEditingValue(
      text: value.text.replaceRange(sel.start, sel.end, text),
      selection: TextSelection.collapsed(offset: sel.start + text.length),
    ),
    SelectionChangedCause.toolbar,
  );
  state.hideToolbar();
  state.bringIntoView(TextPosition(offset: sel.start + text.length));
}

// Eigener „Link öffnen" / „Im Web suchen"-Eintrag – oder null, wenn weder eine
// URL am Cursor/in der Auswahl noch markierter Text vorliegt.
ContextMenuButtonItem? _linkItem(BuildContext context,
    EditableTextState editableTextState, AppLocalizations l10n) {
  final value = editableTextState.currentTextEditingValue;
  final sel = value.selection;
  if (!sel.isValid) return null;
  String? target;
  bool isLink = false;
  // Erst das Token rund um Auswahl/Cursor prüfen: ist es eine URL, wird die
  // GANZE Adresse geöffnet (auch bei Teilauswahl / blankem Cursor darin).
  final token = _tokenSpanning(value.text, sel.start, sel.end);
  if (looksLikeUrl(token)) {
    target = token;
    isLink = true;
  } else if (!sel.isCollapsed) {
    // Sonst: markierten Text (mehrere Wörter) im Web suchen.
    final selected = sel.textInside(value.text);
    if (selected.trim().isNotEmpty) {
      target = selected;
      isLink = false;
    }
  }
  if (target == null) return null;
  final t = target;
  return ContextMenuButtonItem(
    onPressed: () {
      editableTextState.hideToolbar();
      _open(context, t);
    },
    label: isLink ? l10n.openLink : l10n.searchWeb,
  );
}

// Baut das aufgeräumte Auswahl-/Kontextmenü für ein Notiz-Textfeld. Als
// `contextMenuBuilder` eines TextField verwenden.
//
// Aus der Standard-Liste werden nur die gewünschten Einträge übernommen,
// umbenannt und neu sortiert. Reihenfolge: cut, Kopieren, Link öffnen/Im Web
// suchen, Claude fragen, Alle auswählen, Einfügen. Entfernt: Teilen sowie alle
// „Text verarbeiten"-Aktionen fremder Apps (DeepL, Übersetzen, Vorlesen, Grok,
// In Edge suchen …) AUSSER „Claude fragen".
Widget buildNoteContextMenu(
    BuildContext context, EditableTextState editableTextState) {
  final l10n = AppLocalizations.of(context)!;
  final defaults = editableTextState.contextMenuButtonItems;

  ContextMenuButtonItem? byType(ContextMenuButtonType type) {
    for (final item in defaults) {
      if (item.type == type) return item;
    }
    return null;
  }

  // „Text verarbeiten"-Aktionen sind type == custom mit dem App-Namen als
  // Label; davon nur „Claude fragen" behalten.
  ContextMenuButtonItem? claude;
  for (final item in defaults) {
    if (item.type == ContextMenuButtonType.custom &&
        (item.label?.toLowerCase().contains('claude') ?? false)) {
      claude = item;
      break;
    }
  }

  // Ausschneiden -> „cut", Einsetzen -> „Einfügen" (Funktion/Typ bleiben).
  ContextMenuButtonItem relabel(ContextMenuButtonItem item, String label) =>
      ContextMenuButtonItem(
          onPressed: item.onPressed, type: item.type, label: label);

  final cut = byType(ContextMenuButtonType.cut);
  final copy = byType(ContextMenuButtonType.copy);
  final selectAll = byType(ContextMenuButtonType.selectAll);
  final paste = byType(ContextMenuButtonType.paste);
  final link = _linkItem(context, editableTextState, l10n);

  final items = <ContextMenuButtonItem>[
    if (cut != null) relabel(cut, l10n.ctxCut),
    if (copy != null) copy,
    if (link != null) link,
    if (claude != null) claude,
    if (selectAll != null) selectAll,
    // Einfügen über den eigenen Weg: der Text aus der Zwischenablage wird vorher
    // normalisiert (siehe normalizePastedText), sonst schleppt eingefügter
    // Web-/PDF-Text unsichtbare Sonderzeichen ein, die anders gerendert werden.
    if (paste != null)
      ContextMenuButtonItem(
        onPressed: () => _pasteNormalized(editableTextState, paste),
        type: paste.type,
        label: l10n.ctxPaste,
      ),
  ];

  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: items,
  );
}
