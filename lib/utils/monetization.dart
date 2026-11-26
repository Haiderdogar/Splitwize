/// Splitwize monetization.
///
/// The app currently shows no ads and has no purchase screen: everything is
/// free and unlimited, including receipt photos. The Ad-Free entitlement
/// below stays configured behind the single RevenueCat entitlement
/// [entitlementId] (monthly [monthlyProductId], yearly [yearlyProductId]) so
/// a paid plan can be offered again later without re-plumbing.
///
/// Purchases run through RevenueCat; the SDK stays dormant until a real
/// public key is pasted below, and until then the app behaves as the free
/// tier.
abstract final class Monetization {
  /// RevenueCat entitlement that removes ads.
  static const String entitlementId = 'adfree';

  /// Store product identifiers for the two Ad-Free plans.
  static const String monthlyProductId = 'splitwize_adfree_monthly';
  static const String yearlyProductId = 'splitwize_adfree_yearly';

  /// Shown when the store offering can't be loaded (e.g. RevenueCat
  /// not configured yet).
  static const String monthlyPriceFallback = '\$0.99/month';
  static const String yearlyPriceFallback = '\$7/year';

  /// RevenueCat public SDK key (Android). Empty = purchases dormant:
  /// the app behaves as free tier and the paywall explains checkout
  /// opens with the store launch. Create the RevenueCat project,
  /// register [monthlyProductId] + [yearlyProductId] under the
  /// [entitlementId] entitlement, then paste the key here.
  static const String revenueCatApiKey = '';

  static bool get purchasesConfigured => revenueCatApiKey.isNotEmpty;
}
