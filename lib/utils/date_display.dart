import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Datums-/Zeitangaben in der Sprache der App ausgeben.
///
/// Vorher standen die Muster fest auf Deutsch (`DateFormat(..., 'de')`). Mit
/// nur fünf europäischen Sprachen fiel das kaum auf; seit die App auch
/// Russisch, Ukrainisch, Türkisch, Chinesisch und Japanisch spricht, stünde in
/// einer japanischen Oberfläche „4. August 2026" – deshalb hier zentral über
/// die aktive Sprache.
///
/// **Wichtig:** Es wird bewusst NICHT jede beliebige Locale gesetzt, sondern
/// nur die gerade geladene. `GlobalMaterialLocalizations` initialisiert die
/// Datums-Daten genau für diese; für andere würde `DateFormat` eine
/// `LocaleDataException` werfen. Zur Sicherheit fällt jede Formatierung bei
/// einem Fehler auf das sprachneutrale Zahlenformat zurück.
class DateDisplay {
  DateDisplay._();

  static String _locale(BuildContext context) =>
      Localizations.localeOf(context).toLanguageTag();

  static String _safe(String Function() format, DateTime date, String fallback) {
    try {
      return format();
    } catch (_) {
      return DateFormat(fallback).format(date);
    }
  }

  /// Lang: „4. August 2026, 18:30" bzw. das Äquivalent der Sprache.
  static String long(BuildContext context, DateTime date) => _safe(
        () => DateFormat.yMMMMd(_locale(context)).add_Hm().format(date),
        date,
        'yyyy-MM-dd HH:mm',
      );

  /// Mittel: „4. Aug. 2026, 18:30".
  static String medium(BuildContext context, DateTime date) => _safe(
        () => DateFormat.yMMMd(_locale(context)).add_Hm().format(date),
        date,
        'yyyy-MM-dd HH:mm',
      );

  /// Kurz für enge Leisten: „4.8. 18:30" (nur Tag/Monat + Uhrzeit).
  static String shortDayTime(BuildContext context, DateTime date) => _safe(
        () => DateFormat.Md(_locale(context)).add_Hm().format(date),
        date,
        'MM-dd HH:mm',
      );

  /// Wochentag ausgeschrieben („Montag").
  static String weekday(BuildContext context, DateTime date) => _safe(
        () => DateFormat.EEEE(_locale(context)).format(date),
        date,
        'EEEE',
      );

  /// Wochentag kurz („Mo").
  static String weekdayShort(BuildContext context, DateTime date) => _safe(
        () => DateFormat.E(_locale(context)).format(date),
        date,
        'E',
      );

  /// Tag und Monat ohne Jahr („4. Aug.").
  static String dayMonth(BuildContext context, DateTime date) => _safe(
        () => DateFormat.MMMd(_locale(context)).format(date),
        date,
        'MM-dd',
      );

  /// Tag und Monat rein numerisch („4.8.").
  static String dayMonthNumeric(BuildContext context, DateTime date) => _safe(
        () => DateFormat.Md(_locale(context)).format(date),
        date,
        'MM-dd',
      );

  /// Uhrzeit („18:30").
  static String time(BuildContext context, DateTime date) => _safe(
        () => DateFormat.Hm(_locale(context)).format(date),
        date,
        'HH:mm',
      );
}
