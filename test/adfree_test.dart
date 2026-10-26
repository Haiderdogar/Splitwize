// Ad-Free monetization tests: the store configuration (one
// entitlement, two plans, dormant until the RevenueCat key is
// pasted), the cached-entitlement round-trip, and the paywall's
// plan selection. Ads themselves are the free tier's revenue —
// there is no receipt quota anymore; photos are unlimited for all.
import 'package:splitwize/providers/core_providers.dart';
import 'package:splitwize/providers/monetization_providers.dart';
import 'package:splitwize/utils/monetization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  setUpAll(() async {
    await initTestEnv();
  });

  group('Ad-Free configuration', () {
    test('one entitlement, two distinct plans', () {
      expect(Monetization.entitlementId, 'adfree');
      expect(Monetization.monthlyProductId, 'splitwize_adfree_monthly');
      expect(Monetization.yearlyProductId, 'splitwize_adfree_yearly');
    });

    test('fallback prices match the announced plans', () {
      expect(Monetization.monthlyPriceFallback, '\$0.99/month');
      expect(Monetization.yearlyPriceFallback, '\$7/year');
    });

    test('purchases stay dormant until the RevenueCat key is pasted', () {
      expect(Monetization.revenueCatApiKey, isEmpty);
      expect(Monetization.purchasesConfigured, isFalse);
    });

    test('price provider serves the fallbacks while dormant', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final prices = await container.read(adFreePricesProvider.future);
      expect(prices.monthly, Monetization.monthlyPriceFallback);
      expect(prices.yearly, Monetization.yearlyPriceFallback);
    });
  });

  group('AdFreeStatus cache', () {
    test('defaults to ads-on and round-trips the cached value', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(await container.read(adFreeStatusProvider.future), isFalse);

      // Simulate a purchase being recorded, as _apply does after the
      // store confirms the entitlement.
      final storage = container.read(secureStorageServiceProvider);
      await storage.saveAdFreeStatus(true);
      final fresh = ProviderContainer();
      addTearDown(fresh.dispose);
      expect(await fresh.read(adFreeStatusProvider.future), isTrue);

      await storage.saveAdFreeStatus(false);
    });
  });

  group('PaywallPlan', () {
    test('yearly starts selected and the selection flips', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(paywallPlanProvider, (_, __) {});
      addTearDown(sub.close);
      expect(container.read(paywallPlanProvider), isTrue);
      container.read(paywallPlanProvider.notifier).select(false);
      expect(container.read(paywallPlanProvider), isFalse);
      container.read(paywallPlanProvider.notifier).select(true);
      expect(container.read(paywallPlanProvider), isTrue);
    });
  });
}
