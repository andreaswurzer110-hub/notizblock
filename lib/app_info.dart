// Für den Nutzer sichtbare App-Version (volle 4-teilige Nummer inkl. Revision).
// Wird in den Einstellungen angezeigt.
//
// WARUM eine Konstante statt package_info: pubspec.version kann keine 4. Stelle
// führen (semver = 3-teilig + Build-Nr.), und package_info liefert die volle
// Nummer nur auf Android (via --build-name) – auf Windows/Linux zeigt es die
// pubspec-Version ohne Revision. Diese Konstante ist die EINE, plattform-
// übergreifend identische Anzeige-Version.
//
// WICHTIG: Bei jedem Release mitziehen, zusammen mit pubspec `version:`
// (versionCode), `msix_version` und dem `--build-name`-Flag des AAB-Builds.
const String kAppVersionDisplay = '1.25.9.3';
