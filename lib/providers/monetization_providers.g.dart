// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monetization_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AdFreeStatus)
const adFreeStatusProvider = AdFreeStatusProvider._();

final class AdFreeStatusProvider
    extends $AsyncNotifierProvider<AdFreeStatus, bool> {
  const AdFreeStatusProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'adFreeStatusProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$adFreeStatusHash();

  @$internal
  @override
  AdFreeStatus create() => AdFreeStatus();
}

String _$adFreeStatusHash() => r'bbc6bb213f29f171473a082b27ee98df3e31b869';

abstract class _$AdFreeStatus extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<bool>, bool>,
        AsyncValue<bool>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(adFreePrices)
const adFreePricesProvider = AdFreePricesProvider._();

final class AdFreePricesProvider extends $FunctionalProvider<
        AsyncValue<AdFreePrices>, AdFreePrices, FutureOr<AdFreePrices>>
    with $FutureModifier<AdFreePrices>, $FutureProvider<AdFreePrices> {
  const AdFreePricesProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'adFreePricesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$adFreePricesHash();

  @$internal
  @override
  $FutureProviderElement<AdFreePrices> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AdFreePrices> create(Ref ref) {
    return adFreePrices(ref);
  }
}

String _$adFreePricesHash() => r'dfe98c20ae6e13448461a778f84f403ebd0fa2f8';

/// True while a purchase/restore call is in flight (paywall buttons).

@ProviderFor(PurchaseBusy)
const purchaseBusyProvider = PurchaseBusyProvider._();

/// True while a purchase/restore call is in flight (paywall buttons).
final class PurchaseBusyProvider extends $NotifierProvider<PurchaseBusy, bool> {
  /// True while a purchase/restore call is in flight (paywall buttons).
  const PurchaseBusyProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'purchaseBusyProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$purchaseBusyHash();

  @$internal
  @override
  PurchaseBusy create() => PurchaseBusy();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$purchaseBusyHash() => r'83cd5481ff86117b023de918229c259bb1ad20a4';

/// True while a purchase/restore call is in flight (paywall buttons).

abstract class _$PurchaseBusy extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<bool, bool>, bool, Object?, Object?>;
    element.handleValue(ref, created);
  }
}

/// Which plan is selected on the paywall (true = yearly, the better
/// value, so it starts selected).

@ProviderFor(PaywallPlan)
const paywallPlanProvider = PaywallPlanProvider._();

/// Which plan is selected on the paywall (true = yearly, the better
/// value, so it starts selected).
final class PaywallPlanProvider extends $NotifierProvider<PaywallPlan, bool> {
  /// Which plan is selected on the paywall (true = yearly, the better
  /// value, so it starts selected).
  const PaywallPlanProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'paywallPlanProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$paywallPlanHash();

  @$internal
  @override
  PaywallPlan create() => PaywallPlan();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$paywallPlanHash() => r'7a9b74d2f2de7b0b78203f9de46e9c2ec29f691c';

/// Which plan is selected on the paywall (true = yearly, the better
/// value, so it starts selected).

abstract class _$PaywallPlan extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<bool, bool>, bool, Object?, Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(AdBannerController)
const adBannerControllerProvider = AdBannerControllerProvider._();

final class AdBannerControllerProvider
    extends $NotifierProvider<AdBannerController, AdBannerState> {
  const AdBannerControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'adBannerControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$adBannerControllerHash();

  @$internal
  @override
  AdBannerController create() => AdBannerController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AdBannerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AdBannerState>(value),
    );
  }
}

String _$adBannerControllerHash() =>
    r'2dc9cafc04f1b2753574c03fa1dea8fa220600e7';

abstract class _$AdBannerController extends $Notifier<AdBannerState> {
  AdBannerState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AdBannerState, AdBannerState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AdBannerState, AdBannerState>,
        AdBannerState,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
