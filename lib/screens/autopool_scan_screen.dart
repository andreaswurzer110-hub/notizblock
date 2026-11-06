import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/autopool.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';

/// Ergebnis des Scanners: die erfassten Nummern ('' = nicht erfasst).
class AutopoolScanResult {
  final String serial;
  final String inventory;

  const AutopoolScanResult({required this.serial, required this.inventory});
}

/// Öffnet den Scanner für ein neues Autopool-Gerät. Liefert null, wenn ohne
/// „Übernehmen" zurückgegangen wurde. Die Feldnamen kommen vom Aufrufer, damit
/// umbenannte Spaltenüberschriften auch hier erscheinen; [date] ist das
/// heutige Datum, das die Tabelle in die neue Zeile schreibt (hier nur
/// angezeigt).
Future<AutopoolScanResult?> showAutopoolScanner(
  BuildContext context, {
  required String inventoryLabel,
  required String serialLabel,
  required String dateLabel,
  required String date,
}) {
  return Navigator.of(context).push<AutopoolScanResult>(
    MaterialPageRoute(
      builder: (_) => AutopoolScanScreen(
        inventoryLabel: inventoryLabel,
        serialLabel: serialLabel,
        dateLabel: dateLabel,
        date: date,
      ),
    ),
  );
}

/// Kamera-Scanner (nur Android) für Inventar- und Seriennummer eines Geräts.
///
/// Ablauf: Der erste erkannte Barcode geht in die Inventarnummer, danach
/// springt das Ziel von selbst zur Seriennummer. Ein Tipp auf ein Feld macht es
/// zum Ziel (z.B. um eine falsch erwischte Nummer neu zu scannen). „Übernehmen"
/// gibt beide zurück; die Tabelle legt daraus eine neue Zeile mit dem heutigen
/// Datum an. Korrigiert wird danach ganz normal in der Tabelle.
///
/// Nur Barcodes innerhalb des Rahmens zählen (`scanWindow`) – Typenschilder
/// tragen oft mehrere Codes nebeneinander (Seriennummer, Artikelnummer, MAC …).
/// Die Bilder werden nur auf dem Gerät ausgewertet (ML Kit), nicht gespeichert.
///
/// Seit 1.34.0: Mit zwei Fingern zoomt die Kamera (kleine Codes). Was live nicht
/// klappt – kleine oder hell auf dunkel gelaserte Codes wie der Data-Matrix-Code
/// am Boden einer Dockingstation –, liest „Foto“ bzw. „Galerie“: ein richtiges
/// Foto, ausgewertet von `CodeFinder` in MainActivity (Kanal `notizblock/codes`).
/// Trägt ein Code mehrere Angaben („Modell,Teilenummer,MAC,Seriennummer,…“),
/// fragt der Scanner, welche ins Feld soll ([scannedCodeParts]).
class AutopoolScanScreen extends StatefulWidget {
  final String inventoryLabel;
  final String serialLabel;
  final String dateLabel;
  final String date;

  const AutopoolScanScreen({
    super.key,
    required this.inventoryLabel,
    required this.serialLabel,
    required this.dateLabel,
    required this.date,
  });

  @override
  State<AutopoolScanScreen> createState() => _AutopoolScanScreenState();
}

class _AutopoolScanScreenState extends State<AutopoolScanScreen>
    with WidgetsBindingObserver {
  // Feldindizes = Scan-Reihenfolge: erst Inventar-, dann Seriennummer.
  static const int _inventory = 0;
  static const int _serial = 1;

  // Nach einem Treffer kurz nichts annehmen: Zeit, um zum nächsten Etikett zu
  // schwenken, ohne dass ein Nachbarcode sofort im nächsten Feld landet.
  static const Duration _pauseAfterHit = Duration(milliseconds: 1200);

  // autoStart aus: Start/Stopp laufen selbst über den App-Lebenszyklus (Kamera
  // freigeben, wenn die App in den Hintergrund geht) – Muster aus der
  // mobile_scanner-README.
  final MobileScannerController _scanner =
      MobileScannerController(autoStart: false);
  StreamSubscription<BarcodeCapture>? _subscription;

  // Foto/Galerie: Android holt das Bild und sucht darin die Codes.
  static const MethodChannel _codes = MethodChannel('notizblock/codes');

  final List<String> _values = ['', ''];
  // Feld, in das der nächste Treffer geht; null = beide erfasst (Scan ruht).
  int? _target = _inventory;
  // Läuft nach jedem Treffer; solange er aktiv ist, zählt kein Code.
  Timer? _pauseTimer;
  // Ein Foto wird ausgewertet bzw. die Auswahl der Teile ist offen – solange
  // zählt live kein Code.
  bool _busy = false;
  bool _choosing = false;
  // Codes mit mehreren Angaben, die live schon zur Auswahl standen. Sie bleiben
  // nach der Auswahl im Bild und kämen sonst sofort fürs nächste Feld wieder.
  final Set<String> _offered = {};
  // Zoom der Kamera (0–1): zuletzt gewünscht und beim Aufsetzen der zwei
  // Finger. Selbst gemerkt – nicht jede Kamera meldet ihn zurück.
  double _zoom = 0;
  double _zoomAtStart = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = _scanner.barcodes.listen(_onBarcodes);
    unawaited(_startCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pauseTimer?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
    unawaited(_scanner.dispose());
  }

  // Startfehler (z.B. Kamera verweigert) landen im Controller-Zustand und zeigt
  // der errorBuilder; hier nur nichts unbehandelt hochwerfen lassen.
  Future<void> _startCamera() async {
    _zoom = 0; // ein Neustart der Kamera beginnt ohne Zoom
    try {
      await _scanner.start();
    } catch (e) {
      debugPrint('Scanner-Start fehlgeschlagen: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Der Berechtigungsdialog löst selbst Lebenszyklus-Wechsel aus → erst
    // reagieren, wenn die Kamera erlaubt ist.
    if (!_scanner.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
      case AppLifecycleState.resumed:
        _subscription ??= _scanner.barcodes.listen(_onBarcodes);
        unawaited(_startCamera());
      case AppLifecycleState.inactive:
        unawaited(_subscription?.cancel());
        _subscription = null;
        unawaited(_scanner.stop());
    }
  }

  void _onBarcodes(BarcodeCapture capture) {
    final target = _target;
    if (!mounted || target == null || _busy || _choosing) return;
    if (_pauseTimer?.isActive ?? false) return;
    for (final barcode in capture.barcodes) {
      final code = cleanScannedCode(barcode.rawValue);
      // Schon erfasst? Dann steht derselbe Code nach dem Treffer noch im Bild –
      // Inventar- und Seriennummer sind nie gleich.
      if (code.isEmpty || _values.contains(code)) continue;
      // Mehrere Angaben in einem Code: fragen, welche ins Feld soll.
      if (scannedCodeParts(barcode.rawValue).isNotEmpty) {
        if (!_offered.add(code)) continue;
        HapticFeedback.mediumImpact();
        unawaited(_offer([barcode.rawValue!]));
        return;
      }
      HapticFeedback.mediumImpact();
      _take(code);
      return;
    }
  }

  // Wert ins aktuelle Ziel, danach weiter zum nächsten leeren Feld.
  void _take(String code) {
    final target = _target;
    if (target == null || code.isEmpty) return;
    _pauseTimer?.cancel();
    _pauseTimer = Timer(_pauseAfterHit, () {});
    setState(() {
      _values[target] = code;
      _target = _nextEmpty(after: target);
    });
  }

  // Gefundene Codes anbieten. Einer ohne Teile wird gleich übernommen, sonst
  // entscheidet die Auswahl (ganzer Code oder einer seiner Teile).
  Future<void> _offer(List<String> raws) async {
    final target = _target;
    if (target == null) return;
    final groups = <(String, List<String>)>[];
    for (final raw in raws) {
      final whole = cleanScannedCode(raw);
      if (whole.isEmpty || groups.any((g) => g.$1 == whole)) continue;
      groups.add((whole, scannedCodeParts(raw)));
    }
    if (groups.isEmpty) return;
    if (groups.length == 1 && groups.single.$2.isEmpty) {
      _take(groups.single.$1);
      return;
    }
    setState(() => _choosing = true);
    final labels = [widget.inventoryLabel, widget.serialLabel];
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _CodeChoice(
        title: AppLocalizations.of(context)!.autopoolScanChoose(labels[target]),
        groups: groups,
      ),
    );
    if (!mounted) return;
    setState(() => _choosing = false);
    if (chosen != null) _take(chosen);
  }

  // „Foto“ (Kamera-App, volle Auflösung) bzw. „Galerie“: Android holt das Bild,
  // CodeFinder sucht darin – auch kleine und hell auf dunkel gelaserte Codes.
  Future<void> _photo({required bool camera}) async {
    if (_target == null || _busy) return;
    final l = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    Object? answer;
    try {
      // Die Kamera-App braucht die Kamera; der Lebenszyklus startet den
      // Live-Scanner beim Zurückkommen wieder.
      if (camera) await _scanner.stop();
      answer = await _codes.invokeMethod<Object?>(
          'photoCodes', {'source': camera ? 'camera' : 'gallery'});
    } catch (e) {
      answer = {'error': 'unreadable'};
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (camera && !_scanner.value.isRunning) unawaited(_startCamera());
    if (answer is! Map) return; // abgebrochen
    final error = answer['error'];
    final codes = [
      for (final c in (answer['codes'] as List? ?? const []))
        if (c is Map && (c['value'] ?? '').toString().isNotEmpty)
          c['value'].toString(),
    ];
    if (error != null || codes.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(error == 'camera'
              ? l.autopoolScanPhotoFailed
              : error != null
                  ? l.autopoolScanUnreadable
                  : l.autopoolScanNothing),
        ));
      return;
    }
    await _offer(codes);
  }

  // Zwei Finger zoomen die Kamera – für kleine Codes. 0 = weit, 1 = stärkster
  // Zoom; Auseinanderziehen auf die doppelte Fingerweite bringt etwa die Hälfte.
  void _onZoomStart(ScaleStartDetails d) {
    _zoomAtStart = _zoom;
  }

  void _onZoomUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount < 2) return;
    _zoom = (_zoomAtStart + (d.scale - 1) * 0.5).clamp(0.0, 1.0);
    _scanner.setZoomScale(_zoom).catchError((Object e) {});
  }

  // Nächstes noch leeres Feld nach [after] (reihum) oder null, wenn alle voll.
  int? _nextEmpty({required int after}) {
    for (var i = 1; i <= _values.length; i++) {
      final f = (after + i) % _values.length;
      if (_values[f].isEmpty) return f;
    }
    return null;
  }

  void _clear(int field) {
    setState(() {
      _values[field] = '';
      _target = field;
      // Ausdrücklich neu scannen: Codes mit mehreren Angaben wieder anbieten.
      _offered.clear();
    });
  }

  void _apply() {
    Navigator.of(context).pop(AutopoolScanResult(
      serial: _values[_serial],
      inventory: _values[_inventory],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final labels = [widget.inventoryLabel, widget.serialLabel];
    final target = _target;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l.autopoolScanTitle),
        actions: [_torchButton(l)],
      ),
      body: Column(
        children: [
          Expanded(
            child: _cameraArea(
              l,
              target == null
                  ? l.autopoolScanComplete
                  : l.autopoolScanAim(labels[target]),
            ),
          ),
          _fieldsPanel(l, labels),
        ],
      ),
    );
  }

  Widget _cameraArea(AppLocalizations l, String hint) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        // Breiter, flacher Rahmen – passt zu Strichcodes auf Typenschildern.
        final width = math.min(size.width * 0.85, 420.0);
        final window = Rect.fromCenter(
          center: size.center(Offset.zero),
          width: width,
          height: math.min(width * 0.5, size.height * 0.6),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onScaleStart: _onZoomStart,
              onScaleUpdate: _onZoomUpdate,
              child: MobileScanner(
                controller: _scanner,
                scanWindow: window,
                tapToFocus: true,
                errorBuilder: (context, error) => _cameraError(l, error),
              ),
            ),
            IgnorePointer(
              child: ScanWindowOverlay(
                controller: _scanner,
                scanWindow: window,
                borderWidth: 3,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: IgnorePointer(
                child: ValueListenableBuilder<MobileScannerState>(
                  valueListenable: _scanner,
                  builder: (context, state, _) {
                    // Bei Kamerafehler steht die Meldung in der Mitte.
                    if (state.error != null) return const SizedBox.shrink();
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hint,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15),
                            ),
                            if (_target != null)
                              Text(
                                l.autopoolScanSmallHint,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Foto/Galerie – für Codes, die live nicht klappen.
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _target == null || _busy
                        ? null
                        : () => _photo(camera: true),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(l.autopoolScanPhoto),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _target == null || _busy
                        ? null
                        : () => _photo(camera: false),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(l.autopoolScanGallery),
                  ),
                ],
              ),
            ),
            if (_busy)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 16),
                          Text(
                            l.autopoolScanSearching,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _cameraError(AppLocalizations l, MobileScannerException error) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                denied ? Icons.no_photography_outlined : Icons.error_outline,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                denied ? l.autopoolScanNoPermission : l.autopoolScanCameraError,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _torchButton(AppLocalizations l) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: _scanner,
      builder: (context, state, _) {
        if (!state.isRunning || state.torchState == TorchState.unavailable) {
          return const SizedBox.shrink();
        }
        return IconButton(
          tooltip: l.autopoolScanTorch,
          icon: Icon(switch (state.torchState) {
            TorchState.on => Icons.flash_on,
            TorchState.auto => Icons.flash_auto,
            _ => Icons.flash_off,
          }),
          onPressed: () => unawaited(_scanner.toggleTorch()),
        );
      },
    );
  }

  Widget _fieldsPanel(AppLocalizations l, List<String> labels) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _values.length; i++)
                _fieldTile(l, i, labels[i]),
              _dateLine(),
              const SizedBox(height: 4),
              FilledButton.icon(
                onPressed: _values.any((v) => v.isNotEmpty) ? _apply : null,
                icon: const Icon(Icons.check),
                label: Text(l.autopoolScanApply),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Datum, das automatisch in die neue Zeile kommt – nur zur Info, nicht
  // antippbar (wird ja nicht gescannt).
  Widget _dateLine() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fg = scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Icon(Icons.event, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '${widget.dateLabel}  ',
                    style: textTheme.labelMedium?.copyWith(color: fg)),
                TextSpan(
                    text: widget.date,
                    style: textTheme.bodyLarge?.copyWith(color: fg)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // Ein Feld: Tipp = dieses Feld (neu) scannen; ✕ leert es.
  Widget _fieldTile(AppLocalizations l, int field, String label) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final active = _target == field;
    final value = _values[field];
    final fg = active ? scheme.onPrimaryContainer : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: active
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() {
            _target = field;
            _offered.clear();
          }),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Icon(
                  active
                      ? Icons.qr_code_scanner
                      : (value.isEmpty
                          ? Icons.radio_button_unchecked
                          : Icons.check_circle),
                  color: fg,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: textTheme.labelMedium
                              ?.copyWith(color: fg.withValues(alpha: 0.75))),
                      Text(
                        value.isEmpty ? '–' : value,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(color: fg),
                      ),
                    ],
                  ),
                ),
                if (value.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: fg,
                    tooltip: l.delete,
                    onPressed: () => _clear(field),
                  )
                else
                  const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Auswahl, was von den gefundenen Codes ins Feld soll: bei einem Code mit
/// mehreren Angaben jede einzeln (meist will man genau eine, z.B. die
/// Seriennummer), darunter der ganze Inhalt.
class _CodeChoice extends StatelessWidget {
  final String title;
  final List<(String, List<String>)> groups;

  const _CodeChoice({required this.title, required this.groups});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            for (final (i, (whole, parts)) in groups.indexed) ...[
              if (i > 0) const Divider(),
              for (final part in parts)
                ListTile(
                  leading: const Icon(Icons.label_outline),
                  title: Text(part),
                  onTap: () => Navigator.of(context).pop(part),
                ),
              ListTile(
                leading: const Icon(Icons.qr_code_2),
                title: Text(whole,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: parts.isEmpty ? null : Text(l.autopoolScanWhole),
                onTap: () => Navigator.of(context).pop(whole),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
