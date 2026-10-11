import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// Ergebnis eines Unterstützungs-Kaufs aus Sicht der Oberfläche.
enum SupportResult { thanks, pending, canceled, failed }

/// „Entwicklung unterstützen" – freiwilliger Betrag.
///
/// Android: über Google Play Billing. Google Play verbietet Links zu PayPal,
/// Ko-fi & Co. für Zahlungen an den Entwickler (Zahlungsrichtlinie – Apps
/// wurden dafür schon entfernt), der zulässige Weg ist ein In-App-Kauf über
/// Play. Die Produkte schalten nichts frei und sind Verbrauchsartikel
/// (consumable), damit man auch mehrmals unterstützen kann.
///
/// Windows/Linux: nur ein Link auf [desktopUrl] (Microsoft Store und Snap
/// Store erlauben das bei Apps, die keine Spiele sind). NIE auf Android zeigen.
///
/// Voraussetzung in der Play Console: Händlerkonto + unter „Monetarisieren →
/// In-App-Produkte" genau die [productIds] angelegt und aktiv (Preise legt die
/// Console fest, die App zeigt sie nur an). Fehlt etwas davon, liefert
/// [loadProducts] eine leere Liste → der Dialog meldet „gerade nicht möglich".
class SupportService {
  SupportService._();
  static final SupportService instance = SupportService._();

  static const Set<String> productIds = {
    'support_small',
    'support_medium',
    'support_large',
  };

  static const String desktopUrl = 'https://ko-fi.com/andreaswurzer';

  bool get usesPlayBilling => Platform.isAndroid;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Completer<SupportResult>? _waiting;
  String? _waitingProductId;

  /// Den Kaufstrom einmal abonnieren und danach dauerhaft offen lassen: Eine
  /// „ausstehende" Zahlung (z. B. Barzahlung im Handel) wird ggf. erst
  /// bestätigt, wenn der Dialog längst zu ist – das Plugin verbraucht den Kauf
  /// nur, solange jemand zuhört.
  void _listen() {
    _subscription ??= InAppPurchase.instance.purchaseStream
        .listen(_onPurchases, onError: (_) => _resolve(SupportResult.failed));
  }

  /// Verfügbare Beträge, aufsteigend nach Preis. Leer, wenn Play nicht
  /// erreichbar ist oder die Produkte (noch) nicht angelegt sind.
  Future<List<ProductDetails>> loadProducts() async {
    if (!usesPlayBilling) return const [];
    try {
      final iap = InAppPurchase.instance;
      if (!await iap.isAvailable()) return const [];
      _listen();
      final response = await iap.queryProductDetails(productIds);
      return List.of(response.productDetails)
        ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
    } catch (_) {
      return const [];
    }
  }

  /// Startet den Play-Kaufdialog und wartet auf dessen Ausgang.
  Future<SupportResult> buy(ProductDetails product) async {
    _listen();
    _resolve(SupportResult.canceled); // etwaigen alten Wartenden freigeben
    final completer = Completer<SupportResult>();
    _waiting = completer;
    _waitingProductId = product.id;
    var started = false;
    try {
      // autoConsume (Standard): das Plugin verbraucht den Kauf sofort, damit
      // derselbe Betrag später erneut gewählt werden kann.
      started = await InAppPurchase.instance.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (_) {}
    if (!started) {
      _resolve(SupportResult.failed);
      // Häufigste Ursache: ein alter, nie verbrauchter Kauf desselben Betrags
      // („bereits gekauft") → aufräumen, dann klappt der nächste Versuch.
      unawaited(finishOpenPurchases());
    }
    return completer.future;
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      // Abbruch/Fehler ohne Kauf kommen mit leerer productID.
      if (p.productID.isNotEmpty && p.productID != _waitingProductId) continue;
      _resolve(switch (p.status) {
        PurchaseStatus.purchased || PurchaseStatus.restored =>
          SupportResult.thanks,
        PurchaseStatus.pending => SupportResult.pending,
        PurchaseStatus.canceled => SupportResult.canceled,
        // Bezahlt, nur das Verbrauchen klappte nicht → trotzdem bedanken
        // (nicht zum zweiten Zahlen verleiten); [finishOpenPurchases] holt
        // das Verbrauchen beim nächsten Start nach.
        PurchaseStatus.error => p.error?.code == kConsumptionFailedErrorCode
            ? SupportResult.thanks
            : SupportResult.failed,
      });
    }
  }

  void _resolve(SupportResult result) {
    final waiting = _waiting;
    if (waiting == null || waiting.isCompleted) return;
    _waiting = null;
    _waitingProductId = null;
    waiting.complete(result);
  }

  /// Liegengebliebene Unterstützungen nachträglich verbrauchen.
  ///
  /// Fälle: Eine ausstehende Zahlung wurde erst bestätigt, als die App zu war,
  /// oder das automatische Verbrauchen schlug fehl. Unverbraucht erstattet
  /// Google den Betrag nach 3 Tagen zurück, und derselbe Betrag ließe sich bis
  /// dahin nicht erneut wählen. Läuft beim App-Start (nach dem ersten Frame).
  Future<void> finishOpenPurchases() async {
    if (!usesPlayBilling) return;
    try {
      final iap = InAppPurchase.instance;
      if (!await iap.isAvailable()) return;
      final android =
          iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await android.queryPastPurchases();
      for (final p in response.pastPurchases) {
        if (productIds.contains(p.productID) &&
            p.billingClientPurchase.purchaseState ==
                PurchaseStateWrapper.purchased) {
          await android.consumePurchase(p);
        }
      }
    } catch (_) {
      // Kein Play Store / offline: beim nächsten Start erneut.
    }
  }
}
