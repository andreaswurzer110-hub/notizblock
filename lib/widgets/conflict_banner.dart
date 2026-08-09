import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/note.dart';
import '../services/conflict_store.dart';

/// Hinweis GENAU AN DER NOTIZ, bei der eine Änderung überschrieben wurde.
///
/// **Warum nicht (mehr) im Hauptmenü:** Dort war der Hinweis wirkungslos – man
/// sieht ihn beim Durchblättern der Liste, kann aber nichts damit anfangen und
/// klickt ihn weg. Gebraucht wird er dort, wo man an DIESER Notiz arbeitet:
/// im Editor (Desktop + Android) und im Sticky-Fenster (Desktop-Widget).
///
/// **Warum eigener Timer statt NotesProvider:** Das Sticky-Fenster ist ein
/// eigener Prozess ohne Provider – und genau dort syncen Haupt-App und Fenster
/// unabhängig voneinander. Der ConflictStore (Datei) ist die gemeinsame
/// Quelle; kurzes Nachsehen im Takt reicht, die Datei ist winzig.
class ConflictBanner extends StatefulWidget {
  /// Notiz, um die es geht. `null` (neue, noch nicht gespeicherte Notiz) →
  /// nichts anzeigen.
  final Note? note;

  /// Öffnet den Versionsverlauf. Bewusst vom Aufrufer gestellt: das
  /// Sticky-Fenster muss `showVersionHistory` mit eigenem `onRestore` aufrufen
  /// (kein NotesProvider im Sticky-Prozess).
  final VoidCallback onShowVersions;

  /// Kompaktere Darstellung für kleine Fenster (Sticky-Note).
  final bool compact;

  const ConflictBanner({
    super.key,
    required this.note,
    required this.onShowVersions,
    this.compact = false,
  });

  @override
  State<ConflictBanner> createState() => _ConflictBannerState();
}

class _ConflictBannerState extends State<ConflictBanner> {
  PendingConflict? _conflict;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final id = widget.note?.id;
    if (id == null) return;
    final list = await ConflictStore.load();
    PendingConflict? match;
    for (final c in list) {
      if (c.noteId == id) match = c;
    }
    if (!mounted) return;
    if (match?.detectedAt != _conflict?.detectedAt) {
      setState(() => _conflict = match);
    }
  }

  Future<void> _dismiss() async {
    final id = widget.note?.id;
    if (id == null) return;
    await ConflictStore.remove(id);
    if (!mounted) return;
    setState(() => _conflict = null);
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    if (note == null || _conflict == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final title = note.title.trim().isEmpty ? l10n.emptyNote : note.title.trim();
    final scale = widget.compact ? 0.85 : 1.0;

    final banner = Material(
      color: theme.colorScheme.errorContainer,
      borderRadius: widget.compact ? BorderRadius.circular(8) : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(widget.compact ? 8 : 16, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 20 * scale, color: theme.colorScheme.onErrorContainer),
            SizedBox(width: widget.compact ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.conflictDetected(title),
                    style: TextStyle(
                      fontSize: 14 * scale,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: widget.onShowVersions,
                        child: Text(l10n.versionHistory,
                            style: TextStyle(fontSize: 14 * scale)),
                      ),
                      TextButton(
                        onPressed: _dismiss,
                        child: Text(l10n.close,
                            style: TextStyle(fontSize: 14 * scale)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Außenabstand gehört ins Widget, nicht zum Aufrufer: sonst bliebe im
    // Sticky-Fenster auch ohne Konflikt eine leere Lücke stehen.
    return widget.compact
        ? Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 0), child: banner)
        : banner;
  }
}
