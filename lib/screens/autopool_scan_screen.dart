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

  final List<String> _values = ['', ''];
  // Feld, in das der nächste Treffer geht; null = beide erfasst (Scan ruht).
  int? _target = _inventory;
  // Läuft nach jedem Treffer; solange er aktiv ist, zählt kein Code.
  Timer? _pauseTimer;

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
    if (!mounted || target == null) return;
    if (_pauseTimer?.isActive ?? false) return;
    for (final barcode in capture.barcodes) {
      final code = cleanScannedCode(barcode.rawValue);
      // Schon erfasst? Dann steht derselbe Code nach dem Treffer noch im Bild –
      // Inventar- und Seriennummer sind nie gleich.
      if (code.isEmpty || _values.contains(code)) continue;
      HapticFeedback.mediumImpact();
      _pauseTimer = Timer(_pauseAfterHit, () {});
      setState(() {
        _values[target] = code;
        _target = _nextEmpty(after: target);
      });
      return;
    }
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
            MobileScanner(
              controller: _scanner,
              scanWindow: window,
              tapToFocus: true,
              errorBuilder: (context, error) => _cameraError(l, error),
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
                        child: Text(
                          hint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                        ),
                      ),
                    );
                  },
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
          onTap: () => setState(() => _target = field),
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
