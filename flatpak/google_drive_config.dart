// Dedizierter Google-OAuth-Client NUR für die Linux-/Flatpak-Variante.
//
// Bewusst öffentlich (Flathub baut aus öffentlichem Quellcode): ein SEPARATER
// Client vom Typ "Desktop app", getrennt von den Windows-/Android-Clients –
// damit ein etwaiger Missbrauch isoliert ist und sich rotieren/sperren lässt,
// ohne die anderen Plattformen zu treffen. Bei OAuth-Clients vom Typ
// "Desktop app" gilt das Client-Secret laut Google ohnehin NICHT als
// vertraulich (es steckt zwangsläufig in jeder verteilten App).
//
// Der Flatpak-Build kopiert diese Datei nach lib/services/google_drive_config.dart
// (siehe flatpak/io.github.andreaswurzer110_hub.Notizblock.yml). Struktur MUSS
// exakt der echten GoogleDriveConfig entsprechen.
class GoogleDriveConfig {
  // --- Desktop/Linux (Flatpak) ---
  static const String desktopClientId =
      '445597891658-uhecqr5h1751c50hlfkh06hten10ncev.apps.googleusercontent.com';
  static const String desktopClientSecret =
      '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';

  // --- Android --- (auf Linux ungenutzt)
  static const String androidServerClientId = '';

  /// true, sobald echte Desktop-Credentials hinterlegt sind.
  static bool get isDesktopConfigured =>
      desktopClientId.isNotEmpty &&
      !desktopClientId.startsWith('DEINE_') &&
      desktopClientSecret.isNotEmpty &&
      !desktopClientSecret.startsWith('DEIN_');
}
