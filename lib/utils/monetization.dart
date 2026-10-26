/// Splitwize monetization — ads are the revenue.
///
/// Everything in the app is free and unlimited, including receipt
/// photos. The free tier shows a banner ad (Google TEST ids until a
/// real AdMob account is wired in). The only paid product is an
/// **Ad-Free subscription** that removes the ads; it comes in two
/// plans — monthly [monthlyProductId] and yearly [yearlyProductId] —
/// behind the single RevenueCat entitlement [entitlementId].
///
/// Purchases run through RevenueCat; the SDK stays dormant until a
/// real public key is pasted below. Until then the app behaves as
/// free tier and the paywall explains checkout opens at store
/// launch; once configured, the paywall shows the store's localized
/// prices instead of the fallbacks.
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

  /// AdMob banner unit. Defaults to Google's public TEST unit id —
  /// replace with the real unit id after creating an AdMob account,
  /// and swap the app ids in AndroidManifest.xml / Info.plist too.
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
}
