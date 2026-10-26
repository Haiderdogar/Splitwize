// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'core_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Remote data source — used only by [SyncService] (push/pull) and
/// [AuthService] (first profile upsert). Screens never touch this.

@ProviderFor(firestoreService)
const firestoreServiceProvider = FirestoreServiceProvider._();

/// Remote data source — used only by [SyncService] (push/pull) and
/// [AuthService] (first profile upsert). Screens never touch this.

final class FirestoreServiceProvider extends $FunctionalProvider<
    FirestoreService,
    FirestoreService,
    FirestoreService> with $Provider<FirestoreService> {
  /// Remote data source — used only by [SyncService] (push/pull) and
  /// [AuthService] (first profile upsert). Screens never touch this.
  const FirestoreServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'firestoreServiceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$firestoreServiceHash();

  @$internal
  @override
  $ProviderElement<FirestoreService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FirestoreService create(Ref ref) {
    return firestoreService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FirestoreService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FirestoreService>(value),
    );
  }
}

String _$firestoreServiceHash() => r'0ef4accaaf33544dfe918e6b1b52288ede148d38';

@ProviderFor(authService)
const authServiceProvider = AuthServiceProvider._();

final class AuthServiceProvider
    extends $FunctionalProvider<AuthService, AuthService, AuthService>
    with $Provider<AuthService> {
  const AuthServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'authServiceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$authServiceHash();

  @$internal
  @override
  $ProviderElement<AuthService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthService create(Ref ref) {
    return authService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthService>(value),
    );
  }
}

String _$authServiceHash() => r'ed0872794ec8e4cb3f50cb37b9c0b9467eb51ddb';

@ProviderFor(secureStorageService)
const secureStorageServiceProvider = SecureStorageServiceProvider._();

final class SecureStorageServiceProvider extends $FunctionalProvider<
    SecureStorageService,
    SecureStorageService,
    SecureStorageService> with $Provider<SecureStorageService> {
  const SecureStorageServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'secureStorageServiceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$secureStorageServiceHash();

  @$internal
  @override
  $ProviderElement<SecureStorageService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SecureStorageService create(Ref ref) {
    return secureStorageService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SecureStorageService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SecureStorageService>(value),
    );
  }
}

String _$secureStorageServiceHash() =>
    r'464d195bb7795379137f71775ab2fb28d3954e02';

/// Whether the one-time onboarding has been seen on this install.
/// Read from secure storage at startup; [markSeen] flips it for good
/// (per install — it survives sign-out and is only reset by wiping the
/// app's data / reinstalling).

@ProviderFor(OnboardingSeen)
const onboardingSeenProvider = OnboardingSeenProvider._();

/// Whether the one-time onboarding has been seen on this install.
/// Read from secure storage at startup; [markSeen] flips it for good
/// (per install — it survives sign-out and is only reset by wiping the
/// app's data / reinstalling).
final class OnboardingSeenProvider
    extends $AsyncNotifierProvider<OnboardingSeen, bool> {
  /// Whether the one-time onboarding has been seen on this install.
  /// Read from secure storage at startup; [markSeen] flips it for good
  /// (per install — it survives sign-out and is only reset by wiping the
  /// app's data / reinstalling).
  const OnboardingSeenProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'onboardingSeenProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$onboardingSeenHash();

  @$internal
  @override
  OnboardingSeen create() => OnboardingSeen();
}

String _$onboardingSeenHash() => r'dc3236138f6946b905ec21146c9fee984c8afc51';

/// Whether the one-time onboarding has been seen on this install.
/// Read from secure storage at startup; [markSeen] flips it for good
/// (per install — it survives sign-out and is only reset by wiping the
/// app's data / reinstalling).

abstract class _$OnboardingSeen extends $AsyncNotifier<bool> {
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

@ProviderFor(ThemeModeSetting)
const themeModeSettingProvider = ThemeModeSettingProvider._();

final class ThemeModeSettingProvider
    extends $AsyncNotifierProvider<ThemeModeSetting, AppTheme> {
  const ThemeModeSettingProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'themeModeSettingProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$themeModeSettingHash();

  @$internal
  @override
  ThemeModeSetting create() => ThemeModeSetting();
}

String _$themeModeSettingHash() => r'77c4f601a810e4d45f57c08169a0565831f99c19';

abstract class _$ThemeModeSetting extends $AsyncNotifier<AppTheme> {
  FutureOr<AppTheme> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<AppTheme>, AppTheme>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<AppTheme>, AppTheme>,
        AsyncValue<AppTheme>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(notificationService)
const notificationServiceProvider = NotificationServiceProvider._();

final class NotificationServiceProvider extends $FunctionalProvider<
    NotificationService,
    NotificationService,
    NotificationService> with $Provider<NotificationService> {
  const NotificationServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'notificationServiceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$notificationServiceHash();

  @$internal
  @override
  $ProviderElement<NotificationService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NotificationService create(Ref ref) {
    return notificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationService>(value),
    );
  }
}

String _$notificationServiceHash() =>
    r'2389020220ef0e64a28e453b6a07a6e1696b314b';

@ProviderFor(firebaseAuth)
const firebaseAuthProvider = FirebaseAuthProvider._();

final class FirebaseAuthProvider
    extends $FunctionalProvider<FirebaseAuth, FirebaseAuth, FirebaseAuth>
    with $Provider<FirebaseAuth> {
  const FirebaseAuthProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'firebaseAuthProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$firebaseAuthHash();

  @$internal
  @override
  $ProviderElement<FirebaseAuth> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FirebaseAuth create(Ref ref) {
    return firebaseAuth(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FirebaseAuth value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FirebaseAuth>(value),
    );
  }
}

String _$firebaseAuthHash() => r'8f84097cccd00af817397c1715c5f537399ba780';

/// The signed-in user's local SQLite database. Re-opens automatically on
/// account switch; closed via [AuthService.signOut].

@ProviderFor(localDatabase)
const localDatabaseProvider = LocalDatabaseProvider._();

/// The signed-in user's local SQLite database. Re-opens automatically on
/// account switch; closed via [AuthService.signOut].

final class LocalDatabaseProvider extends $FunctionalProvider<
        AsyncValue<LocalDatabase>, LocalDatabase, FutureOr<LocalDatabase>>
    with $FutureModifier<LocalDatabase>, $FutureProvider<LocalDatabase> {
  /// The signed-in user's local SQLite database. Re-opens automatically on
  /// account switch; closed via [AuthService.signOut].
  const LocalDatabaseProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'localDatabaseProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$localDatabaseHash();

  @$internal
  @override
  $FutureProviderElement<LocalDatabase> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<LocalDatabase> create(Ref ref) {
    return localDatabase(ref);
  }
}

String _$localDatabaseHash() => r'cc001f582a2ef66e31446ffd894f74da22bd1dbb';

/// Local-first repository: reads hit SQLite (free, instant, offline),
/// writes apply locally and queue in the outbox.

@ProviderFor(appRepository)
const appRepositoryProvider = AppRepositoryProvider._();

/// Local-first repository: reads hit SQLite (free, instant, offline),
/// writes apply locally and queue in the outbox.

final class AppRepositoryProvider extends $FunctionalProvider<
        AsyncValue<AppRepository>, AppRepository, FutureOr<AppRepository>>
    with $FutureModifier<AppRepository>, $FutureProvider<AppRepository> {
  /// Local-first repository: reads hit SQLite (free, instant, offline),
  /// writes apply locally and queue in the outbox.
  const AppRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'appRepositoryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$appRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<AppRepository> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<AppRepository> create(Ref ref) {
    return appRepository(ref);
  }
}

String _$appRepositoryHash() => r'83157a87df6f3bfe07c22955ffeb173d0816aa54';

/// Outbox drain + delta pull. Wires the repository's mutation hook so
/// every local write attempts an immediate sync when online.

@ProviderFor(syncService)
const syncServiceProvider = SyncServiceProvider._();

/// Outbox drain + delta pull. Wires the repository's mutation hook so
/// every local write attempts an immediate sync when online.

final class SyncServiceProvider extends $FunctionalProvider<
        AsyncValue<SyncService>, SyncService, FutureOr<SyncService>>
    with $FutureModifier<SyncService>, $FutureProvider<SyncService> {
  /// Outbox drain + delta pull. Wires the repository's mutation hook so
  /// every local write attempts an immediate sync when online.
  const SyncServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'syncServiceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$syncServiceHash();

  @$internal
  @override
  $FutureProviderElement<SyncService> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<SyncService> create(Ref ref) {
    return syncService(ref);
  }
}

String _$syncServiceHash() => r'8d5d399668ce32da6cfffd327a5a38120219c721';

/// Current sync status for the small indicator in the profile tab.

@ProviderFor(syncStatus)
const syncStatusProvider = SyncStatusProvider._();

/// Current sync status for the small indicator in the profile tab.

final class SyncStatusProvider extends $FunctionalProvider<
        AsyncValue<SyncState>, SyncState, Stream<SyncState>>
    with $FutureModifier<SyncState>, $StreamProvider<SyncState> {
  /// Current sync status for the small indicator in the profile tab.
  const SyncStatusProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'syncStatusProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$syncStatusHash();

  @$internal
  @override
  $StreamProviderElement<SyncState> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<SyncState> create(Ref ref) {
    return syncStatus(ref);
  }
}

String _$syncStatusHash() => r'f2fc47b491d48315edfc74ebd83a04b99ed651af';

@ProviderFor(authStateChanges)
const authStateChangesProvider = AuthStateChangesProvider._();

final class AuthStateChangesProvider
    extends $FunctionalProvider<AsyncValue<User?>, User?, Stream<User?>>
    with $FutureModifier<User?>, $StreamProvider<User?> {
  const AuthStateChangesProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'authStateChangesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$authStateChangesHash();

  @$internal
  @override
  $StreamProviderElement<User?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<User?> create(Ref ref) {
    return authStateChanges(ref);
  }
}

String _$authStateChangesHash() => r'ed73bb63cae92e791c80e19c01a8eb421d09a663';

@ProviderFor(currentUid)
const currentUidProvider = CurrentUidProvider._();

final class CurrentUidProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  const CurrentUidProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'currentUidProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$currentUidHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return currentUid(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$currentUidHash() => r'a3918e6ad268bf13db0be396bccbad40fd93be93';

/// Registers this device for push notifications whenever someone is signed
/// in. Watched once from [AuthGate]; re-runs automatically on sign-in/out.

@ProviderFor(initNotifications)
const initNotificationsProvider = InitNotificationsProvider._();

/// Registers this device for push notifications whenever someone is signed
/// in. Watched once from [AuthGate]; re-runs automatically on sign-in/out.

final class InitNotificationsProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Registers this device for push notifications whenever someone is signed
  /// in. Watched once from [AuthGate]; re-runs automatically on sign-in/out.
  const InitNotificationsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'initNotificationsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$initNotificationsHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return initNotifications(ref);
  }
}

String _$initNotificationsHash() => r'6d67375ad98b57a6d6615348630174e39ff7c4ae';

/// Boots offline-first sync: opens the local DB, caches my profile for
/// instant offline opens, and starts the connectivity-aware sync loop.
/// Watched once from [AuthGate].

@ProviderFor(initSync)
const initSyncProvider = InitSyncProvider._();

/// Boots offline-first sync: opens the local DB, caches my profile for
/// instant offline opens, and starts the connectivity-aware sync loop.
/// Watched once from [AuthGate].

final class InitSyncProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Boots offline-first sync: opens the local DB, caches my profile for
  /// instant offline opens, and starts the connectivity-aware sync loop.
  /// Watched once from [AuthGate].
  const InitSyncProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'initSyncProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$initSyncHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return initSync(ref);
  }
}

String _$initSyncHash() => r'0b1ad8371d4269840dace6339e81ded1dc77c1a4';

@ProviderFor(TabIndex)
const tabIndexProvider = TabIndexProvider._();

final class TabIndexProvider extends $NotifierProvider<TabIndex, int> {
  const TabIndexProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'tabIndexProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$tabIndexHash();

  @$internal
  @override
  TabIndex create() => TabIndex();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$tabIndexHash() => r'67369f88dd27c566c151c9fca3f90855759bce2b';

abstract class _$TabIndex extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<int, int>;
    final element = ref.element
        as $ClassProviderElement<AnyNotifier<int, int>, int, Object?, Object?>;
    element.handleValue(ref, created);
  }
}
