// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appUser)
const appUserProvider = AppUserFamily._();

final class AppUserProvider extends $FunctionalProvider<AsyncValue<AppUser?>,
        AppUser?, Stream<AppUser?>>
    with $FutureModifier<AppUser?>, $StreamProvider<AppUser?> {
  const AppUserProvider._(
      {required AppUserFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'appUserProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$appUserHash();

  @override
  String toString() {
    return r'appUserProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<AppUser?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<AppUser?> create(Ref ref) {
    final argument = this.argument as String;
    return appUser(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppUserProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$appUserHash() => r'b68b55903fdc2d2ec09c1f49723dbafc8a2386f9';

final class AppUserFamily extends $Family
    with $FunctionalFamilyOverride<Stream<AppUser?>, String> {
  const AppUserFamily._()
      : super(
          retry: null,
          name: r'appUserProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  AppUserProvider call(
    String uid,
  ) =>
      AppUserProvider._(argument: uid, from: this);

  @override
  String toString() => r'appUserProvider';
}

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

@ProviderFor(currentAppUser)
const currentAppUserProvider = CurrentAppUserProvider._();

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

final class CurrentAppUserProvider extends $FunctionalProvider<
        AsyncValue<AppUser?>, AppUser?, Stream<AppUser?>>
    with $FutureModifier<AppUser?>, $StreamProvider<AppUser?> {
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
  const CurrentAppUserProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'currentAppUserProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$currentAppUserHash();

  @$internal
  @override
  $StreamProviderElement<AppUser?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<AppUser?> create(Ref ref) {
    return currentAppUser(ref);
  }
}

String _$currentAppUserHash() => r'a85b26905a74176beaf9d017529f709ee2723041';

@ProviderFor(myBills)
const myBillsProvider = MyBillsProvider._();

final class MyBillsProvider extends $FunctionalProvider<AsyncValue<List<Bill>>,
        List<Bill>, Stream<List<Bill>>>
    with $FutureModifier<List<Bill>>, $StreamProvider<List<Bill>> {
  const MyBillsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'myBillsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$myBillsHash();

  @$internal
  @override
  $StreamProviderElement<List<Bill>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Bill>> create(Ref ref) {
    return myBills(ref);
  }
}

String _$myBillsHash() => r'cee48fa7b1ccb0610a574b1f69d97ce7a0565d40';

@ProviderFor(bill)
const billProvider = BillFamily._();

final class BillProvider
    extends $FunctionalProvider<AsyncValue<Bill?>, Bill?, Stream<Bill?>>
    with $FutureModifier<Bill?>, $StreamProvider<Bill?> {
  const BillProvider._(
      {required BillFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'billProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$billHash();

  @override
  String toString() {
    return r'billProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Bill?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Bill?> create(Ref ref) {
    final argument = this.argument as String;
    return bill(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BillProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$billHash() => r'bc4d598827f95c56c2ba6d8cbd6239c85d934ee7';

final class BillFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Bill?>, String> {
  const BillFamily._()
      : super(
          retry: null,
          name: r'billProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  BillProvider call(
    String billId,
  ) =>
      BillProvider._(argument: billId, from: this);

  @override
  String toString() => r'billProvider';
}

@ProviderFor(groupBills)
const groupBillsProvider = GroupBillsFamily._();

final class GroupBillsProvider extends $FunctionalProvider<
        AsyncValue<List<Bill>>, List<Bill>, Stream<List<Bill>>>
    with $FutureModifier<List<Bill>>, $StreamProvider<List<Bill>> {
  const GroupBillsProvider._(
      {required GroupBillsFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'groupBillsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$groupBillsHash();

  @override
  String toString() {
    return r'groupBillsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Bill>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Bill>> create(Ref ref) {
    final argument = this.argument as String;
    return groupBills(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GroupBillsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupBillsHash() => r'0c8dc5369998e0946ec03a8ea86e49cee57f2441';

final class GroupBillsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Bill>>, String> {
  const GroupBillsFamily._()
      : super(
          retry: null,
          name: r'groupBillsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  GroupBillsProvider call(
    String groupId,
  ) =>
      GroupBillsProvider._(argument: groupId, from: this);

  @override
  String toString() => r'groupBillsProvider';
}

/// The group's settlement plan, memoized in a provider instead of
/// recomputed inside the Group Detail build: [simplifyGroupDebts]
/// runs only when the group's bills actually change. A rebuild of
/// the detail screen for any other reason (e.g. the signed-in user
/// or a member list change) reuses the cached plan object.

@ProviderFor(simplifiedDebts)
const simplifiedDebtsProvider = SimplifiedDebtsFamily._();

/// The group's settlement plan, memoized in a provider instead of
/// recomputed inside the Group Detail build: [simplifyGroupDebts]
/// runs only when the group's bills actually change. A rebuild of
/// the detail screen for any other reason (e.g. the signed-in user
/// or a member list change) reuses the cached plan object.

final class SimplifiedDebtsProvider extends $FunctionalProvider<
    GroupSettlementPlan,
    GroupSettlementPlan,
    GroupSettlementPlan> with $Provider<GroupSettlementPlan> {
  /// The group's settlement plan, memoized in a provider instead of
  /// recomputed inside the Group Detail build: [simplifyGroupDebts]
  /// runs only when the group's bills actually change. A rebuild of
  /// the detail screen for any other reason (e.g. the signed-in user
  /// or a member list change) reuses the cached plan object.
  const SimplifiedDebtsProvider._(
      {required SimplifiedDebtsFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'simplifiedDebtsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$simplifiedDebtsHash();

  @override
  String toString() {
    return r'simplifiedDebtsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<GroupSettlementPlan> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GroupSettlementPlan create(Ref ref) {
    final argument = this.argument as String;
    return simplifiedDebts(
      ref,
      argument,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GroupSettlementPlan value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GroupSettlementPlan>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SimplifiedDebtsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$simplifiedDebtsHash() => r'e668c1743cf0f0c9732070d4e5caa7575bbcb7d1';

/// The group's settlement plan, memoized in a provider instead of
/// recomputed inside the Group Detail build: [simplifyGroupDebts]
/// runs only when the group's bills actually change. A rebuild of
/// the detail screen for any other reason (e.g. the signed-in user
/// or a member list change) reuses the cached plan object.

final class SimplifiedDebtsFamily extends $Family
    with $FunctionalFamilyOverride<GroupSettlementPlan, String> {
  const SimplifiedDebtsFamily._()
      : super(
          retry: null,
          name: r'simplifiedDebtsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// The group's settlement plan, memoized in a provider instead of
  /// recomputed inside the Group Detail build: [simplifyGroupDebts]
  /// runs only when the group's bills actually change. A rebuild of
  /// the detail screen for any other reason (e.g. the signed-in user
  /// or a member list change) reuses the cached plan object.

  SimplifiedDebtsProvider call(
    String groupId,
  ) =>
      SimplifiedDebtsProvider._(argument: groupId, from: this);

  @override
  String toString() => r'simplifiedDebtsProvider';
}

/// Net per-friend balances across all my bills (unpaid shares only).
/// Pure local computation over the SQLite cache.

@ProviderFor(balances)
const balancesProvider = BalancesProvider._();

/// Net per-friend balances across all my bills (unpaid shares only).
/// Pure local computation over the SQLite cache.

final class BalancesProvider extends $FunctionalProvider<
    List<FriendBalance>,
    List<FriendBalance>,
    List<FriendBalance>> with $Provider<List<FriendBalance>> {
  /// Net per-friend balances across all my bills (unpaid shares only).
  /// Pure local computation over the SQLite cache.
  const BalancesProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'balancesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$balancesHash();

  @$internal
  @override
  $ProviderElement<List<FriendBalance>> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<FriendBalance> create(Ref ref) {
    return balances(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<FriendBalance> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<FriendBalance>>(value),
    );
  }
}

String _$balancesHash() => r'e689e4f8fcfa806731f2bd218a4753b1fa1afca1';

@ProviderFor(myGroups)
const myGroupsProvider = MyGroupsProvider._();

final class MyGroupsProvider extends $FunctionalProvider<
        AsyncValue<List<BillGroup>>, List<BillGroup>, Stream<List<BillGroup>>>
    with $FutureModifier<List<BillGroup>>, $StreamProvider<List<BillGroup>> {
  const MyGroupsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'myGroupsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$myGroupsHash();

  @$internal
  @override
  $StreamProviderElement<List<BillGroup>> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<BillGroup>> create(Ref ref) {
    return myGroups(ref);
  }
}

String _$myGroupsHash() => r'0e7c99b51dda92038c8270b454fbb8444b04184c';

@ProviderFor(groupInvites)
const groupInvitesProvider = GroupInvitesProvider._();

final class GroupInvitesProvider extends $FunctionalProvider<
        AsyncValue<List<BillGroup>>, List<BillGroup>, Stream<List<BillGroup>>>
    with $FutureModifier<List<BillGroup>>, $StreamProvider<List<BillGroup>> {
  const GroupInvitesProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'groupInvitesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$groupInvitesHash();

  @$internal
  @override
  $StreamProviderElement<List<BillGroup>> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<BillGroup>> create(Ref ref) {
    return groupInvites(ref);
  }
}

String _$groupInvitesHash() => r'ae660b07b8d08c727f631dfd791971a66bd34ab7';

@ProviderFor(group)
const groupProvider = GroupFamily._();

final class GroupProvider extends $FunctionalProvider<AsyncValue<BillGroup?>,
        BillGroup?, Stream<BillGroup?>>
    with $FutureModifier<BillGroup?>, $StreamProvider<BillGroup?> {
  const GroupProvider._(
      {required GroupFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'groupProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$groupHash();

  @override
  String toString() {
    return r'groupProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<BillGroup?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<BillGroup?> create(Ref ref) {
    final argument = this.argument as String;
    return group(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GroupProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupHash() => r'0bb82aacbdbc81b35ea21c61667266fbe429830f';

final class GroupFamily extends $Family
    with $FunctionalFamilyOverride<Stream<BillGroup?>, String> {
  const GroupFamily._()
      : super(
          retry: null,
          name: r'groupProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  GroupProvider call(
    String groupId,
  ) =>
      GroupProvider._(argument: groupId, from: this);

  @override
  String toString() => r'groupProvider';
}

@ProviderFor(groupMembers)
const groupMembersProvider = GroupMembersFamily._();

final class GroupMembersProvider extends $FunctionalProvider<
        AsyncValue<List<AppUser>>, List<AppUser>, FutureOr<List<AppUser>>>
    with $FutureModifier<List<AppUser>>, $FutureProvider<List<AppUser>> {
  const GroupMembersProvider._(
      {required GroupMembersFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'groupMembersProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$groupMembersHash();

  @override
  String toString() {
    return r'groupMembersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<AppUser>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<AppUser>> create(Ref ref) {
    final argument = this.argument as String;
    return groupMembers(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GroupMembersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupMembersHash() => r'70aa1108c47e7b1e045143244ea6636c7b102daa';

final class GroupMembersFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AppUser>>, String> {
  const GroupMembersFamily._()
      : super(
          retry: null,
          name: r'groupMembersProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  GroupMembersProvider call(
    String groupId,
  ) =>
      GroupMembersProvider._(argument: groupId, from: this);

  @override
  String toString() => r'groupMembersProvider';
}

/// Profiles of the users a group is still waiting on (pending invites).
/// A real provider (not a FutureBuilder) so the fetch is cached and
/// doesn't restart on every rebuild.

@ProviderFor(invitedUsers)
const invitedUsersProvider = InvitedUsersFamily._();

/// Profiles of the users a group is still waiting on (pending invites).
/// A real provider (not a FutureBuilder) so the fetch is cached and
/// doesn't restart on every rebuild.

final class InvitedUsersProvider extends $FunctionalProvider<
        AsyncValue<List<AppUser>>, List<AppUser>, FutureOr<List<AppUser>>>
    with $FutureModifier<List<AppUser>>, $FutureProvider<List<AppUser>> {
  /// Profiles of the users a group is still waiting on (pending invites).
  /// A real provider (not a FutureBuilder) so the fetch is cached and
  /// doesn't restart on every rebuild.
  const InvitedUsersProvider._(
      {required InvitedUsersFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'invitedUsersProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$invitedUsersHash();

  @override
  String toString() {
    return r'invitedUsersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<AppUser>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<AppUser>> create(Ref ref) {
    final argument = this.argument as String;
    return invitedUsers(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is InvitedUsersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$invitedUsersHash() => r'2ef0c87ac60335b927392c84acecd1e9831b9c6a';

/// Profiles of the users a group is still waiting on (pending invites).
/// A real provider (not a FutureBuilder) so the fetch is cached and
/// doesn't restart on every rebuild.

final class InvitedUsersFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AppUser>>, String> {
  const InvitedUsersFamily._()
      : super(
          retry: null,
          name: r'invitedUsersProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Profiles of the users a group is still waiting on (pending invites).
  /// A real provider (not a FutureBuilder) so the fetch is cached and
  /// doesn't restart on every rebuild.

  InvitedUsersProvider call(
    String groupId,
  ) =>
      InvitedUsersProvider._(argument: groupId, from: this);

  @override
  String toString() => r'invitedUsersProvider';
}

@ProviderFor(connections)
const connectionsProvider = ConnectionsProvider._();

final class ConnectionsProvider extends $FunctionalProvider<
        AsyncValue<List<AppUser>>, List<AppUser>, Stream<List<AppUser>>>
    with $FutureModifier<List<AppUser>>, $StreamProvider<List<AppUser>> {
  const ConnectionsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'connectionsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$connectionsHash();

  @$internal
  @override
  $StreamProviderElement<List<AppUser>> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<AppUser>> create(Ref ref) {
    return connections(ref);
  }
}

String _$connectionsHash() => r'045b39a93c939d447461d48ee6cdb86a95d4d688';

@ProviderFor(incomingRequests)
const incomingRequestsProvider = IncomingRequestsProvider._();

final class IncomingRequestsProvider extends $FunctionalProvider<
        AsyncValue<List<ConnectionRequest>>,
        List<ConnectionRequest>,
        Stream<List<ConnectionRequest>>>
    with
        $FutureModifier<List<ConnectionRequest>>,
        $StreamProvider<List<ConnectionRequest>> {
  const IncomingRequestsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'incomingRequestsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$incomingRequestsHash();

  @$internal
  @override
  $StreamProviderElement<List<ConnectionRequest>> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<ConnectionRequest>> create(Ref ref) {
    return incomingRequests(ref);
  }
}

String _$incomingRequestsHash() => r'4ac62aefe23b7ba42b5a847ac1610a46f6defcef';

@ProviderFor(outgoingRequests)
const outgoingRequestsProvider = OutgoingRequestsProvider._();

final class OutgoingRequestsProvider extends $FunctionalProvider<
        AsyncValue<List<ConnectionRequest>>,
        List<ConnectionRequest>,
        Stream<List<ConnectionRequest>>>
    with
        $FutureModifier<List<ConnectionRequest>>,
        $StreamProvider<List<ConnectionRequest>> {
  const OutgoingRequestsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'outgoingRequestsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$outgoingRequestsHash();

  @$internal
  @override
  $StreamProviderElement<List<ConnectionRequest>> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<ConnectionRequest>> create(Ref ref) {
    return outgoingRequests(ref);
  }
}

String _$outgoingRequestsHash() => r'c1aacc0bd56e061435843194dbc4215ad3643129';

@ProviderFor(notifications)
const notificationsProvider = NotificationsProvider._();

final class NotificationsProvider extends $FunctionalProvider<
        AsyncValue<List<AppNotification>>,
        List<AppNotification>,
        Stream<List<AppNotification>>>
    with
        $FutureModifier<List<AppNotification>>,
        $StreamProvider<List<AppNotification>> {
  const NotificationsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'notificationsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$notificationsHash();

  @$internal
  @override
  $StreamProviderElement<List<AppNotification>> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<AppNotification>> create(Ref ref) {
    return notifications(ref);
  }
}

String _$notificationsHash() => r'857b3a6952a8b95646c920c4082d59dac98d5165';

@ProviderFor(unreadCount)
const unreadCountProvider = UnreadCountProvider._();

final class UnreadCountProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  const UnreadCountProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'unreadCountProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$unreadCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return unreadCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$unreadCountHash() => r'0cdcd171d16c655740005daf2bb4255bb8ef1881';
