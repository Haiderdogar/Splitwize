import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/app_repository.dart';
import '../data/local_database.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/secure_storage_service.dart';
import '../services/sync_service.dart';

part 'core_providers.g.dart';

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------

/// Remote data source — used only by [SyncService] (push/pull) and
/// [AuthService] (first profile upsert). Screens never touch this.
@riverpod
FirestoreService firestoreService(Ref ref) => FirestoreService();

@riverpod
AuthService authService(Ref ref) => AuthService();

@riverpod
SecureStorageService secureStorageService(Ref ref) => SecureStorageService();

/// Whether the one-time onboarding has been seen on this install.
/// Read from secure storage at startup; [markSeen] flips it for good
/// (per install — it survives sign-out and is only reset by wiping the
/// app's data / reinstalling).
@riverpod
class OnboardingSeen extends _$OnboardingSeen {
  @override
  Future<bool> build() =>
      ref.watch(secureStorageServiceProvider).isOnboardingSeen();

  Future<void> markSeen() async {
    await ref.read(secureStorageServiceProvider).markOnboardingSeen();
    state = const AsyncData(true);
  }
}

/// The app appearance choice: light, dark, or follow the system.
/// A per-device preference in secure storage (not synced across
/// devices); changing it flips MaterialApp's themeMode immediately.
enum AppTheme { system, light, dark }

extension AppThemeLabel on AppTheme {
  String get label => switch (this) {
        AppTheme.system => 'System default',
        AppTheme.light => 'Light',
        AppTheme.dark => 'Dark',
      };
}

@riverpod
class ThemeModeSetting extends _$ThemeModeSetting {
  @override
  Future<AppTheme> build() async {
    final raw = await ref.watch(secureStorageServiceProvider).loadThemeMode();
    return AppTheme.values
        .firstWhere((e) => e.name == raw, orElse: () => AppTheme.system);
  }

  Future<void> setMode(AppTheme mode) async {
    await ref.read(secureStorageServiceProvider).saveThemeMode(mode.name);
    state = AsyncData(mode);
  }
}

@riverpod
NotificationService notificationService(Ref ref) =>
    NotificationService.instance;

/// Push-permission status for the Profile tile, as a provider — not
/// a `FutureBuilder` whose future was created inside `build`.
///
/// The old tile built its future on every Profile rebuild, so every
/// profile change re-queried Firebase Messaging and the tile could
/// flicker back to "Off" while the new future was pending. A
/// provider computes this once and caches it; only the tile watches
/// it, so nothing else rebuilds when it resolves.
@riverpod
Future<AuthorizationStatus?> notificationAuthorizationStatus(Ref ref) async {
  try {
    return (await FirebaseMessaging.instance.getNotificationSettings())
        .authorizationStatus;
  } catch (_) {
    // Messaging unavailable (tests, no Google services): tile shows
    // "Off" instead of throwing while the tree is building.
    return null;
  }
}

@riverpod
FirebaseAuth firebaseAuth(Ref ref) => FirebaseAuth.instance;

// ---------------------------------------------------------------------------
// Offline-first data graph
// ---------------------------------------------------------------------------

/// The signed-in user's local SQLite database. Re-opens automatically on
/// account switch; closed via [AuthService.signOut].
@riverpod
Future<LocalDatabase> localDatabase(Ref ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) throw StateError('Not signed in');
  final db = await LocalDatabase.open(uid);
  ref.onDispose(() => LocalDatabase.close());
  return db;
}

/// Local-first repository: reads hit SQLite (free, instant, offline),
/// writes apply locally and queue in the outbox.
@riverpod
Future<AppRepository> appRepository(Ref ref) async {
  final db = await ref.watch(localDatabaseProvider.future);
  final uid = ref.watch(currentUidProvider);
  if (uid == null) throw StateError('Not signed in');
  final repo = AppRepository(
    db: db,
    remote: ref.watch(firestoreServiceProvider),
    secure: ref.watch(secureStorageServiceProvider),
    myUid: uid,
  );
  ref.onDispose(repo.dispose);
  return repo;
}

/// Outbox drain + delta pull. Wires the repository's mutation hook so
/// every local write attempts an immediate sync when online.
@riverpod
Future<SyncService> syncService(Ref ref) async {
  final repo = await ref.watch(appRepositoryProvider.future);
  final sync = SyncService(
    repository: repo,
    remote: ref.watch(firestoreServiceProvider),
  );
  repo.requestSync = () => sync.syncNow();
  ref.onDispose(sync.dispose);
  return sync;
}

/// Current sync status for the small indicator in the profile tab.
@riverpod
Stream<SyncState> syncStatus(Ref ref) async* {
  final sync = await ref.watch(syncServiceProvider.future);
  yield sync.current;
  yield* sync.state;
}

// ---------------------------------------------------------------------------
// Auth state
// ---------------------------------------------------------------------------

@riverpod
Stream<User?> authStateChanges(Ref ref) =>
    ref.watch(firebaseAuthProvider).authStateChanges();

@riverpod
String? currentUid(Ref ref) => ref.watch(authStateChangesProvider).value?.uid;

/// Registers this device for push notifications whenever someone is signed
/// in. Watched once from [AuthGate]; re-runs automatically on sign-in/out.
@riverpod
Future<void> initNotifications(Ref ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return;
  await ref.watch(notificationServiceProvider).init(uid);
}

/// Boots offline-first sync: opens the local DB, caches my profile for
/// instant offline opens, and starts the connectivity-aware sync loop.
/// Watched once from [AuthGate].
@riverpod
Future<void> initSync(Ref ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return;
  final sync = await ref.watch(syncServiceProvider.future);
  final repo = await ref.watch(appRepositoryProvider.future);

  // On a fresh install / account switch the local cache is empty and
  // getUser would fall back to the sign-in session snapshot, which
  // predates settings saved on other devices (e.g. default currency).
  // Fetch the real profile once so those are here from the start.
  // Only when nothing is cached — a cached row may hold newer local
  // changes that have not synced yet and must not be clobbered.
  if (await repo.getCachedUser(uid) == null) {
    try {
      final fresh = await repo.remote.getUser(uid);
      if (fresh != null) await repo.cacheMyProfile(fresh);
    } catch (_) {
      // Offline — getUser below falls back to the session snapshot.
    }
  }

  // Make sure my own profile is cached locally. Works fully offline:
  // falls back to the secure-storage session snapshot, then to the
  // Firebase Auth profile (no network needed).
  var me = await repo.getUser(uid);
  if (me == null) {
    final fb = ref.watch(firebaseAuthProvider).currentUser;
    if (fb != null) {
      me = AppUser(
        uid: fb.uid,
        displayName: fb.displayName ?? 'Friend',
        email: fb.email ?? '',
        photoUrl: fb.photoURL,
      );
    }
  }
  if (me != null) {
    // Keep the local cache and secure session fresh (no remote write —
    // the profile is unchanged).
    await repo.cacheMyProfile(me);
  }

  await sync.init();
}

// ---------------------------------------------------------------------------
// Navigation
// ---------------------------------------------------------------------------

@riverpod
class TabIndex extends _$TabIndex {
  @override
  int build() => 0;

  void set(int index) => state = index;
}
