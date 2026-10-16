import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// Gemeinsam genutzt von autopool_scan_test.dart und text_scale_test.dart.

/// Kamera-Ersatz: startet sofort und liefert Barcodes über [emit].
class FakeScannerPlatform extends MobileScannerPlatform {
  FakeScannerPlatform({this.startError});

  final MobileScannerException? startError;
  final _barcodes = StreamController<BarcodeCapture?>.broadcast();

  void emit(List<String> codes) => _barcodes.add(BarcodeCapture(
        barcodes: [for (final c in codes) Barcode(rawValue: c)],
      ));

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodes.stream;

  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    if (startError != null) throw startError!;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(1080, 1920),
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<void> dispose() async {}
}
