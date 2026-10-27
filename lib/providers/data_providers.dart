import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/app_repository.dart';
import '../models/models.dart';
import '../utils/debt_simplifier.dart';
import 'core_providers.dart';

part 'data_providers.g.dart';

/// All data providers read from the local SQLite cache via
/// [AppRepository] — instant, free and offline. Firestore is only ever
/// touched by [SyncService] in the background.

/// Bridges the repository (a future) into the stream providers.
///
/// While the repository is still opening, the stream stays silent so
/// providers remain in AsyncLoading and screens show their shimmer —
/// they must never flash a fake "empty" state first. Repository
/// failures are forwarded as stream errors so screens land in their
/// error branch (with Retry) instead of silently showing nothing.
Stream<T> _fromRepo<T>(
  Ref ref,
  Stream<T> Function(AppRepository repo) pick,
) {
  final repoAsync = ref.watch(appRepositoryProvider);
  return repoAsync.when(
    data: pick,
    loading: () => Stream<T>.empty(),
    error: (e, st) => Stream<T>.error(e, st),
  );
}

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------

@riverpod
Stream<AppUser?> appUser(Ref ref, String uid) =>
    _fromRepo(ref, (repo) => repo.watchUser(uid));

/// My own profile, LIVE — not a one-shot fetch.
///
/// It used to be a `Future` provider: it resolved once at startup
/// and never again, so changing the default currency in Profile (or
/// a profile change arriving from another device) left the Profile
/// header, the Profile currency tile, the create-group currency
/// field and the create-bill currency stale until the app was
/// restarted. Deriving it from the profile stream fixes that, and
/// the stream's distinct filter (see `AppRepository._watch`) means
/// it only emits when the profile content actually changes — the
/// screens watching it do not rebuild on unrelated mutations.
@riverpod
Stream<AppUser?> currentAppUser(Ref ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return _fromRepo(ref, (repo) => repo.watchUser(uid));
}

// ---------------------------------------------------------------------------
// Bills
// ---------------------------------------------------------------------------

@riverpod
Stream<List<Bill>> myBills(Ref ref) =>
    _fromRepo(ref, (repo) => repo.watchMyBills());

@riverpod
Stream<Bill?> bill(Ref ref, String billId) =>
    _fromRepo(ref, (repo) => repo.watchBill(billId));

@riverpod
Stream<List<Bill>> groupBills(Ref ref, String groupId) =>
    _fromRepo(ref, (repo) => repo.watchBillsForGroup(groupId));

/// The group's settlement plan, memoized in a provider instead of
/// recomputed inside the Group Detail build: [simplifyGroupDebts]
/// runs only when the group's bills actually change. A rebuild of
/// the detail screen for any other reason (e.g. the signed-in user
/// or a member list change) reuses the cached plan object.
@riverpod
GroupSettlementPlan simplifiedDebts(Ref ref, String groupId) {
  final bills = ref.watch(groupBillsProvider(groupId)).value ?? const <Bill>[];
  return simplifyGroupDebts(bills);
}

/// Net per-friend balances across all my bills (unpaid shares only).
/// Pure local computation over the SQLite cache.
@riverpod
List<FriendBalance> balances(Ref ref) {
  final uid = ref.watch(currentUidProvider);
  final bills = ref.watch(myBillsProvider).value ?? const <Bill>[];
  final repo = ref.watch(appRepositoryProvider).value;
  if (uid == null || repo == null) return const [];
  return repo.computeBalances(bills);
}

// ---------------------------------------------------------------------------
// Groups
// ---------------------------------------------------------------------------

@riverpod
Stream<List<BillGroup>> myGroups(Ref ref) =>
    _fromRepo(ref, (repo) => repo.watchMyGroups());

@riverpod
Stream<List<BillGroup>> groupInvites(Ref ref) =>
    _fromRepo(ref, (repo) => repo.watchGroupInvites());

@riverpod
Stream<BillGroup?> group(Ref ref, String groupId) =>
    _fromRepo(ref, (repo) => repo.watchGroup(groupId));

@riverpod
Future<List<AppUser>> groupMembers(Ref ref, String groupId) async {
  final g = await ref.watch(groupProvider(groupId).future);
  if (g == null) return const [];
  final repo = await ref.watch(appRepositoryProvider.future);
  return repo.fetchUsers(g.members);
}

/// Profiles of the users a group is still waiting on (pending invites).
/// A real provider (not a FutureBuilder) so the fetch is cached and
/// doesn't restart on every rebuild.
@riverpod
Future<List<AppUser>> invitedUsers(Ref ref, String groupId) async {
  final g = await ref.watch(groupProvider(groupId).future);
  if (g == null) return const [];
  final repo = await ref.watch(appRepositoryProvider.future);
  return repo.fetchUsers(g.invited);
}

// ---------------------------------------------------------------------------
// Friends
// ---------------------------------------------------------------------------

@riverpod
Stream<List<AppUser>> connections(Ref ref) =>
    _fromRepo(ref, (repo) => repo.watchConnections());

@riverpod
Stream<List<ConnectionRequest>> incomingRequests(Ref ref) =>
    _fromRepo(ref, (repo) => repo.watchIncomingRequests());

@riverpod
Stream<List<ConnectionRequest>> outgoingRequests(Ref ref) =>
    _fromRepo(ref, (repo) => repo.watchOutgoingRequests());

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

@riverpod
Stream<List<AppNotification>> notifications(Ref ref) =>
    _fromRepo(ref, (repo) => repo.watchNotifications());

@riverpod
int unreadCount(Ref ref) =>
    ref.watch(notificationsProvider).value?.where((n) => !n.read).length ?? 0;
