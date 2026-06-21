import 'package:flutter_test/flutter_test.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';
import 'package:notizblock/providers/settings_provider.dart';

/// Regressionsschutz gegen den „graues Bild bei anderer Sprache"-Bug
/// (bis 1.25.8.0): `SettingsProvider.supportedLocales` bot Sprachen an, für die
/// es KEINE Übersetzung gab → `AppLocalizations.of(context)` wurde null →
/// `!`-Zugriff warf → Haupt-/Einstellungsbildschirm grau und unbedienbar.
///
/// Daher: JEDE im Sprachwähler angebotene Locale MUSS von AppLocalizations
/// unterstützt werden und sich mit nicht-leeren Strings laden lassen. Wer künftig
/// eine Sprache zu supportedLocales hinzufügt, muss auch die `app_<locale>.arb`
/// anlegen – sonst schlägt dieser Test fehl.
void main() {
  test('alle angebotenen Sprachen werden von AppLocalizations geladen', () async {
    for (final locale in SettingsProvider.supportedLocales) {
      final code = locale.languageCode;
      expect(
        AppLocalizations.delegate.isSupported(locale),
        isTrue,
        reason: 'Locale "$code" ist in supportedLocales, aber AppLocalizations '
            'unterstützt sie nicht (fehlende app_$code.arb?) → Graubild-Bug.',
      );
      final l10n = await AppLocalizations.delegate.load(locale);
      // Stichproben: UI-Grundstring + die lokalisierten Bibelverse (Easter Egg).
      expect(l10n.settings, isNotEmpty, reason: '"settings" leer in "$code".');
      expect(l10n.bibleVerse1Ref, isNotEmpty,
          reason: 'Bibelvers-Referenz leer in "$code".');
      expect(l10n.bibleVerse2Text, isNotEmpty,
          reason: 'Bibelvers-Text leer in "$code".');
    }
  });
}
