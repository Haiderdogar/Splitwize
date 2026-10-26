import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/monetization.dart';
import 'core_providers.dart';

part 'monetization_providers.g.dart';

/// Result of a purchase / restore attempt from the paywall.
enum PurchaseOutcome { success, cancelled, notConfigured, failed }

// ---------------------------------------------------------------------------
// Ad-Free entitlement (RevenueCat is the source of truth; secure
// storage caches the last-known value so the app boots with the
// right tier offline and before the store answers)
// ---------------------------------------------------------------------------

@riverpod
class AdFreeStatus extends _$AdFreeStatus {
  bool _configured = false;

  @override
  Future<bool> build() async {
    final cached =
        await ref.watch(secureStorageServiceProvider).loadAdFreeStatus();
    // Refresh from the store in the background; if it disagrees with
    // the cache, the state (and the cache) update when it answers.
    Future<void>.microtask(_syncWithStore);
    return cached;
  }

  Future<void> _ensureConfigured() async {
    if (_configured || !Monetization.purchasesConfigured) return;
    await Purchases.configure(
      PurchasesConfiguration(Monetization.revenueCatApiKey)
        ..appUserID = ref.read(currentUidProvider),
    );
    _configured = true;
  }

  Future<void> _apply(bool isAdFree) async {
    await ref.read(secureStorageServiceProvider).saveAdFreeStatus(isAdFree);
    state = AsyncData(isAdFree);
  }

  Future<void> _syncWithStore() async {
    if (!Monetization.purchasesConfigured) return;
    try {
      await _ensureConfigured();
      final info = await Purchases.getCustomerInfo();
      await _apply(
          info.entitlements.active.containsKey(Monetization.entitlementId));
    } catch (_) {
      // Offline / store unreachable: keep the cached tier.
    }
  }

  /// Buys the selected Ad-Free plan (monthly or yearly) from the
  /// current offering.
  Future<PurchaseOutcome> purchase({required bool yearly}) async {
    if (!Monetization.purchasesConfigured) {
      return PurchaseOutcome.notConfigured;
    }
    try {
      await _ensureConfigured();
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) return PurchaseOutcome.failed;
      final package = (yearly ? current.annual : current.monthly) ??
          current.availablePackages
              .where((p) =>
                  p.storeProduct.identifier ==
                  (yearly
                      ? Monetization.yearlyProductId
                      : Monetization.monthlyProductId))
              .firstOrNull;
      if (package == null) return PurchaseOutcome.failed;
      final result = await Purchases.purchase(PurchaseParams.package(package));
      final isAdFree = result.customerInfo.entitlements.active
          .containsKey(Monetization.entitlementId);
      if (isAdFree) await _apply(true);
      return isAdFree ? PurchaseOutcome.success : PurchaseOutcome.failed;
    } on PlatformException catch (e) {
      return PurchasesErrorHelper.getErrorCode(e) ==
              PurchasesErrorCode.purchaseCancelledError
          ? PurchaseOutcome.cancelled
          : PurchaseOutcome.failed;
    } catch (_) {
      return PurchaseOutcome.failed;
    }
  }

  /// Restores a previous purchase (new device, reinstall).
  Future<PurchaseOutcome> restore() async {
    if (!Monetization.purchasesConfigured) {
      return PurchaseOutcome.notConfigured;
    }
    try {
      await _ensureConfigured();
      final info = await Purchases.restorePurchases();
      final isAdFree =
          info.entitlements.active.containsKey(Monetization.entitlementId);
      if (isAdFree) await _apply(true);
      return isAdFree ? PurchaseOutcome.success : PurchaseOutcome.failed;
    } catch (_) {
      return PurchaseOutcome.failed;
    }
  }
}

/// Localized Ad-Free prices from the store offering, or the
/// fallback labels while purchases are dormant / unreachable.
typedef AdFreePrices = ({String monthly, String yearly});

@riverpod
Future<AdFreePrices> adFreePrices(Ref ref) async {
  const fallback = (
    monthly: Monetization.monthlyPriceFallback,
    yearly: Monetization.yearlyPriceFallback,
  );
  if (!Monetization.purchasesConfigured) return fallback;
  try {
    await ref.read(adFreeStatusProvider.notifier)._ensureConfigured();
    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    final monthly = current?.monthly?.storeProduct.priceString;
    final yearly = current?.annual?.storeProduct.priceString;
    return (
      monthly: monthly != null ? '$monthly/month' : fallback.monthly,
      yearly: yearly != null ? '$yearly/year' : fallback.yearly,
    );
  } catch (_) {
    // Fall through to the fallback labels.
  }
  return fallback;
}

/// True while a purchase/restore call is in flight (paywall buttons).
@riverpod
class PurchaseBusy extends _$PurchaseBusy {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Which plan is selected on the paywall (true = yearly, the better
/// value, so it starts selected).
@riverpod
class PaywallPlan extends _$PaywallPlan {
  @override
  bool build() => true;

  void select(bool yearly) => state = yearly;
}

// ---------------------------------------------------------------------------
// Free-tier ad banner (Ad-Free subscribers never load one)
// ---------------------------------------------------------------------------

typedef AdBannerState = ({BannerAd? ad, bool loaded});

@riverpod
class AdBannerController extends _$AdBannerController {
  @override
  AdBannerState build() {
    // Never touch the ads SDK in tests; the slot collapses instead.
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return (ad: null, loaded: false);
    }
    try {
      MobileAds.instance.initialize();
    } catch (_) {
      return (ad: null, loaded: false);
    }
    late final BannerAd ad;
    ad = BannerAd(
      adUnitId: Monetization.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => state = (ad: ad, loaded: true),
        onAdFailedToLoad: (failedAd, _) => failedAd.dispose(),
      ),
    );
    // Dispose via the captured instance — reading `state` inside
    // onDispose is not allowed.
    ref.onDispose(ad.dispose);
    ad.load();
    return (ad: ad, loaded: false);
  }
}
