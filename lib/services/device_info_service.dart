import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Kurzbezeichnung dieses Geräts – wird an die Snapshots im Versionsverlauf
/// geschrieben, damit im Verlauf steht, WOHER ein Stand stammt
/// („Windows – ANDI-PC", „Android – Pixel 7", …).
///
/// Ohne diese Angabe sieht man im Verlauf nur Zeitpunkte und weiß bei einem
/// Konflikt nicht, welche Zeile das andere Gerät war.
class DeviceInfoService {
  DeviceInfoService._();

  static String? _cached;

  /// Plattform (immer) plus – wenn ermittelbar – der Gerätename.
  /// Beispiele: `Windows - ANDI-PC`, `Android - Pixel 7`, `Linux - zorin-nb`.
  static Future<String> describe() async {
    if (_cached != null) return _cached!;
    final platform = platformName;
    String? name;
    try {
      if (Platform.isAndroid) {
        // Auf Android liefert Platform.localHostname nur „localhost“ – hier
        // braucht es die echten Geräteangaben.
        final info = await DeviceInfoPlugin().androidInfo;
        final model = info.model.trim();
        final brand = info.brand.trim();
        if (model.isNotEmpty) {
          name = (brand.isNotEmpty && !model.toLowerCase().startsWith(brand.toLowerCase()))
              ? '$brand $model'
              : model;
        }
      } else {
        // Desktop: der Rechnername ist genau das, was der Nutzer erwartet.
        final host = Platform.localHostname.trim();
        if (host.isNotEmpty && host.toLowerCase() != 'localhost') name = host;
      }
    } catch (e) {
      debugPrint('Gerätename nicht ermittelbar: $e');
    }
    _cached = (name == null || name.isEmpty) ? platform : '$platform - $name';
    return _cached!;
  }

  /// Reiner Plattformname, auch ohne Geräteabfrage verfügbar.
  static String get platformName {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isIOS) return 'iOS';
    return 'Gerät';
  }
}
