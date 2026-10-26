import 'dart:async';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/debt_simplifier.dart';
import 'local_database.dart';

/// Local-first data access for the whole app.
///
/// **Reads** always come from the SQLite cache ([LocalDatabase]) — instant,
/// free, and available offline. The UI never talks to Firestore directly.
///
/// **Writes** apply to SQLite immediately (so the app feels instant and
/// works fully offline) and enqueue a mutation in the outbox.
/// [SyncService] drains the outbox against Firestore when connectivity is
/// available, then pulls down everyone else's changes as deltas.
///
/// Remote → local application happens in the `applyRemote*` methods,
/// called only by [SyncService].
class AppRepository {
  AppRepository({
    required this.db,
    required this.remote,
    required this.secure,
    required this.myUid,
  });

  final LocalDatabase db;
  final FirestoreService remote;
  final SecureStorageService secure;
  final String myUid;

  static const _uuid = Uuid();

  final _changes = StreamController<void>.broadcast();

  /// Called after every local mutation; wired to `SyncService.syncNow`
  /// by the provider graph so writes flush as soon as possible.
  void Function()? requestSync;

  void notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void _mutated() {
    notifyChanged();
    requestSync?.call();
  }

  Stream<T> _watch<T>(Future<T> Function() query) async* {
    yield await query();
    yield* _changes.stream.asyncMap((_) => query());
  }

  // ------------------------------------------------------------------ users

  Stream<AppUser?> watchUser(String uid) => _watch(() => getCachedUser(uid));

  Future<AppUser?> getCachedUser(String uid) async {
    final row = await db.userRow(uid);
    return row == null ? null : AppUser.fromMap(uid, row);
  }

  /// Local-first profile lookup: SQLite → secure session snapshot →
  /// one remote fetch (cached afterwards). Never throws offline.
  Future<AppUser?> getUser(String uid) async {
    final cached = await getCachedUser(uid);
    if (cached != null) return cached;
    if (uid == myUid) {
      final session = await secure.loadSession();
      if (session != null) {
        await db.upsertUser(uid, session.toProfileMap());
        return session;
      }
    }
    try {
      final user = await remote.getUser(uid);
      if (user != null) await db.upsertUser(uid, user.toProfileMap());
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<List<AppUser>> fetchUsers(List<String> uids) async {
    final out = <AppUser>[];
    final missing = <String>[];
    for (final uid in uids.toSet()) {
      final cached = await getCachedUser(uid);
      if (cached != null) {
        out.add(cached);
      } else {
        missing.add(uid);
      }
    }
    if (missing.isNotEmpty) {
      try {
        final fetched = await remote.fetchUsers(missing);
        for (final u in fetched) {
          await db.upsertUser(u.uid, u.toProfileMap());
          out.add(u);
        }
      } catch (_) {
        // Offline — return what the cache has.
      }
    }
    return out;
  }

  Future<AppUser?> getUserByEmail(String email) => remote.getUserByEmail(email);

  /// Saves my own profile locally + in secure storage, and queues the
  /// remote upsert. (Repeated saves queue repeated upserts — they are
  /// idempotent merges, and saves are rare.)
  Future<void> saveMyProfile(AppUser user) async {
    await cacheMyProfile(user);
    await db.enqueue('user.upsert', {
      'uid': user.uid,
      ...user.toProfileMap(),
    });
    _mutated();
  }

  /// Caches my profile locally + in secure storage without queuing a
  /// remote write — for sign-in bootstrap where the profile is unchanged.
  Future<void> cacheMyProfile(AppUser user) async {
    await db.upsertUser(user.uid, user.toProfileMap());
    await secure.saveSession(user);
    notifyChanged();
  }

  // ------------------------------------------------------------------ bills

  Future<List<Bill>> _myBills() async {
    final rows = await db.billsFor(myUid);
    final bills = [for (final r in rows) Bill.fromMap(r['__id'] as String, r)];
    bills.sort((a, b) => (b.createdAt ?? DateTime(1970))
        .compareTo(a.createdAt ?? DateTime(1970)));
    return bills;
  }

  Stream<List<Bill>> watchMyBills() => _watch(_myBills);

  Stream<Bill?> watchBill(String billId) => _watch(() async {
        final row = await db.billRow(billId);
        return row == null ? null : Bill.fromMap(billId, row);
      });

  Stream<List<Bill>> watchBillsForGroup(String groupId) => _watch(() async {
        final rows = await db.billsForGroup(groupId);
        final bills = [
          for (final r in rows) Bill.fromMap(r['__id'] as String, r)
        ];
        bills.sort((a, b) => (b.createdAt ?? DateTime(1970))
            .compareTo(a.createdAt ?? DateTime(1970)));
        return bills;
      });

  Future<Bill?> billById(String billId) async {
    final row = await db.billRow(billId);
    return row == null ? null : Bill.fromMap(billId, row);
  }

  /// Creates a bill locally and queues the Firestore create. Returns the
  /// (client-generated) bill id immediately — fully offline-capable.
  Future<String> createBill({
    required String title,
    required double subtotal,
    required double tipPercent,
    required AppUser creator,
    String? groupId,
    String? groupName,
    required String splitType,
    required List<BillSplit> splits,
    String? receiptLocalPath,
    required String currency,
  }) async {
    final total = subtotal * (1 + tipPercent / 100);
    final participantIds = splits.map((s) => s.uid).toSet().toList();
    if (!participantIds.contains(creator.uid)) {
      participantIds.add(creator.uid);
    }
    final now = DateTime.now();
    final bill = Bill(
      id: _uuid.v4(),
      title: title.trim(),
      subtotal: subtotal,
      tipPercent: tipPercent,
      total: total,
      splitType: splitType,
      createdBy: creator.uid,
      createdByName: creator.displayName,
      groupId: groupId,
      groupName: groupName,
      participantIds: participantIds,
      splits: splits,
      createdAt: now,
      updatedAt: now,
      receiptLocalPath: receiptLocalPath,
      currency: currency,
    );
    await db.upsertBill(bill.id, bill.toMap(), syncState: 'pending');
    await db.enqueue('bill.create', {'bill': bill.toMap()..['id'] = bill.id});
    _mutated();
    return bill.id;
  }

  /// Removes the receipt photo from one of my bills — locally now,
  /// remotely via the outbox when the photo was already uploaded.
  /// Only the bill's creator can do this; anyone else's call is a
  /// no-op.
  ///
  /// A photo that never left the device needs no remote op: the
  /// pending create (if any) reads the local row when it pushes
  /// and goes out without a receipt.
  Future<void> removeReceiptPhoto(String billId) async {
    final bill = await billById(billId);
    if (bill == null || bill.createdBy != myUid) return;
    if (bill.receiptImageUrl == null && bill.receiptLocalPath == null) {
      return;
    }
    final localPath = bill.receiptLocalPath;
    if (localPath != null) {
      try {
        await File(localPath).delete();
      } catch (_) {
        // Already gone — nothing to clean up.
      }
    }
    final wasUploaded = bill.receiptImageUrl != null;
    final state = await db.billSyncState(billId) ?? 'synced';
    await db.upsertBill(
      billId,
      bill
          .copyWith(
            clearReceiptImageUrl: true,
            clearReceiptLocalPath: true,
            updatedAt: DateTime.now(),
          )
          .toMap(),
      syncState: state,
    );
    if (wasUploaded) {
      await db.enqueue('bill.receiptRemoved', {'billId': billId});
    }
    _mutated();
  }

  /// Sets my default currency (Profile → settings). Stored on my user
  /// profile, so it syncs across devices and applies to new groups and
  /// friend bills. Works offline (queued as a profile upsert).
  Future<void> setMyCurrency(String code) async {
    final me = await getUser(myUid);
    if (me == null || me.currencyCode == code) return;
    await saveMyProfile(me.copyWith(currency: code));
  }

  /// Marks one participant's share paid/unpaid — locally now, remotely
  /// via the outbox (executed as a transaction by SyncService).
  Future<void> setSplitPaid({
    required String billId,
    required String uid,
    required bool paid,
  }) async {
    final bill = await billById(billId);
    if (bill == null) return;
    final split = bill.splits.where((s) => s.uid == uid).firstOrNull;
    if (split == null) return;
    await _setSplitSettledAmount(bill, split, paid ? split.amount : 0);
  }

  /// Sets how much of one share is settled (0…share amount) — the
  /// primitive behind [setSplitPaid] and group debt simplification.
  /// The share counts as paid once the settled amount reaches the
  /// full share; anything in between is a partial settlement kept in
  /// [BillSplit.paidAmount]. Local-first like every write, and the
  /// same `bill.setPaid` outbox op carries the settled amount to
  /// Firestore (older queued ops without it still work — the remote
  /// side then applies the plain paid/unpaid flip).
  /// Returns whether anything changed.
  Future<bool> _setSplitSettledAmount(
      Bill bill, BillSplit split, double settledAmount) async {
    final target = (settledAmount.clamp(0, split.amount) * 100).round() / 100;
    if ((target - split.settledAmount).abs() < 0.005) return false;
    final fullyPaid = split.amount - target < 0.005;
    final now = DateTime.now();
    final splits = bill.splits.map((s) {
      if (s.uid != split.uid) return s;
      return fullyPaid
          ? s.copyWith(paid: true, paidAt: s.paidAt ?? now, paidAmount: target)
          : s.copyWith(paid: false, clearPaidAt: true, paidAmount: target);
    }).toList();
    final state = await db.billSyncState(bill.id) ?? 'synced';
    await db.upsertBill(
      bill.id,
      bill.copyWith(splits: splits, updatedAt: now).toMap(),
      syncState: state,
    );
    await db.enqueue('bill.setPaid', {
      'billId': bill.id,
      'uid': split.uid,
      'paid': fullyPaid,
      'paidAmount': target,
    });
    _mutated();
    return true;
  }

  /// Records one entry of a group settlement plan (a simplified
  /// transfer or a netting — see `DebtSimplifier`): each allocation
  /// settles that amount of one bill share through the regular
  /// mark-paid machinery, so no new tables, sync ops or rules are
  /// needed and per-bill accounting stays exact. Allocations are
  /// amounts to settle on top of the plan-time state, so callers
  /// apply a freshly computed plan entry exactly once; settled
  /// amounts clamp at the share total, never beyond.
  /// Returns the number of shares whose settled amount changed.
  Future<int> applySettlementAllocations(
      List<SplitAllocation> allocations) async {
    final byBill = <String, List<SplitAllocation>>{};
    for (final a in allocations) {
      (byBill[a.billId] ??= []).add(a);
    }
    var touched = 0;
    for (final entry in byBill.entries) {
      for (final alloc in entry.value) {
        // Reload per allocation: earlier allocations in this loop may
        // have updated the same bill.
        final bill = await billById(entry.key);
        if (bill == null) break;
        final split =
            bill.splits.where((s) => s.uid == alloc.splitUid).firstOrNull;
        if (split == null) continue;
        if (await _setSplitSettledAmount(
            bill, split, split.settledAmount + alloc.amount)) {
          touched++;
        }
      }
    }
    return touched;
  }

  /// Marks all my unpaid shares in bills created by [friendUid] as
  /// paid. When [currency] is given, only bills in that currency are
  /// settled (balances are tracked per currency).
  /// Returns the number of shares settled.
  Future<int> settleUpWithFriend(String friendUid, {String? currency}) async {
    final bills = await _myBills();
    var count = 0;
    for (final bill in bills) {
      if (bill.createdBy != friendUid) continue;
      if (currency != null && bill.currency != currency) continue;
      for (final s in bill.splits) {
        if (s.uid == myUid && !s.isFullyPaid) {
          await setSplitPaid(billId: bill.id, uid: myUid, paid: true);
          count++;
        }
      }
    }
    return count;
  }

  // --------------------------------------------------------------- balances

  /// Net per-friend, per-currency balances from **unpaid** splits
  /// across all my bills. Pure computation over the local cache — zero
  /// Firestore cost. Currencies are never mixed: a friend can have one
  /// balance in PKR and another in USD.
  List<FriendBalance> computeBalances(List<Bill> bills) {
    final owesMe = <String, double>{};
    final iOwe = <String, double>{};
    final names = <String, String>{};
    final currencies = <String, String>{};
    final openBills = <String, Set<String>>{};
    for (final bill in bills) {
      final iCreated = bill.createdBy == myUid;
      for (final s in bill.splits) {
        // Partially settled shares (group debt simplification) count
        // only their still-owed remainder.
        final remaining = s.remainingAmount;
        if (remaining == 0) continue;
        if (iCreated) {
          if (s.uid == myUid) continue;
          final key = '${s.uid}|${bill.currency}';
          owesMe[key] = (owesMe[key] ?? 0) + remaining;
          names[key] = s.displayName;
          currencies[key] = bill.currency;
          (openBills[key] ??= <String>{}).add(bill.id);
        } else if (s.uid == myUid) {
          final f = bill.createdBy;
          final key = '$f|${bill.currency}';
          iOwe[key] = (iOwe[key] ?? 0) + remaining;
          names[key] = bill.createdByName;
          currencies[key] = bill.currency;
          (openBills[key] ??= <String>{}).add(bill.id);
        }
      }
    }
    final out = <FriendBalance>[];
    for (final key in {...owesMe.keys, ...iOwe.keys}) {
      final net = (owesMe[key] ?? 0) - (iOwe[key] ?? 0);
      if (net.abs() < 0.005) continue; // settled / dust
      out.add(FriendBalance(
        uid: key.split('|').first,
        displayName: names[key] ?? 'Friend',
        currency: currencies[key] ?? 'USD',
        net: net,
        owesMe: owesMe[key] ?? 0,
        iOweThem: iOwe[key] ?? 0,
        openBills: openBills[key]?.length ?? 0,
      ));
    }
    out.sort((a, b) => b.net.abs().compareTo(a.net.abs()));
    return out;
  }

  // ----------------------------------------------------------------- groups

  bool _isMine(BillGroup g) => g.members.contains(myUid);
  bool _isInvited(BillGroup g) => g.invited.contains(myUid);

  Stream<List<BillGroup>> watchMyGroups() => _watch(() async {
        final rows = await db.groupsFor(myUid);
        final groups = [
          for (final r in rows)
            if (_isMine(BillGroup.fromMap(r['__id'] as String, r)))
              BillGroup.fromMap(r['__id'] as String, r)
        ];
        groups.sort((a, b) => (b.createdAt ?? DateTime(1970))
            .compareTo(a.createdAt ?? DateTime(1970)));
        return groups;
      });

  Stream<List<BillGroup>> watchGroupInvites() => _watch(() async {
        final rows = await db.groupsFor(myUid);
        final groups = [
          for (final r in rows)
            if (_isInvited(BillGroup.fromMap(r['__id'] as String, r)) &&
                !_isMine(BillGroup.fromMap(r['__id'] as String, r)))
              BillGroup.fromMap(r['__id'] as String, r)
        ];
        groups.sort((a, b) => (b.createdAt ?? DateTime(1970))
            .compareTo(a.createdAt ?? DateTime(1970)));
        return groups;
      });

  Stream<BillGroup?> watchGroup(String groupId) => _watch(() async {
        final row = await db.groupRow(groupId);
        return row == null ? null : BillGroup.fromMap(groupId, row);
      });

  Future<BillGroup?> groupById(String groupId) async {
    final row = await db.groupRow(groupId);
    return row == null ? null : BillGroup.fromMap(groupId, row);
  }

  Future<String> createGroup({
    required String name,
    required AppUser creator,
    required List<AppUser> invitees,
    required String currency,
  }) async {
    final inviteUids = invitees
        .map((u) => u.uid)
        .where((id) => id != creator.uid)
        .toSet()
        .toList();
    final now = DateTime.now();
    final group = BillGroup(
      id: _uuid.v4(),
      name: name.trim(),
      createdBy: creator.uid,
      members: [creator.uid],
      invited: inviteUids,
      createdAt: now,
      updatedAt: now,
      currency: currency,
    );
    await db.upsertGroup(group.id, group.toMap(), syncState: 'pending');
    await db
        .enqueue('group.create', {'group': group.toMap()..['id'] = group.id});
    _mutated();
    return group.id;
  }

  Future<void> _updateGroup(
      String groupId, BillGroup Function(BillGroup) change) async {
    final group = await groupById(groupId);
    if (group == null) return;
    final state = await db.groupSyncState(groupId) ?? 'synced';
    await db.upsertGroup(groupId, change(group).toMap(), syncState: state);
  }

  /// Changes the group's currency. Applies locally at once and queues
  /// the remote update. Existing bills keep the currency they were
  /// created with; new bills in the group use the new one.
  Future<void> setGroupCurrency(String groupId, String code) async {
    await _updateGroup(groupId, (g) => g.copyWith(currency: code));
    await db.enqueue('group.currency', {'groupId': groupId, 'currency': code});
    _mutated();
  }

  Future<void> inviteToGroup(String groupId, List<String> uids) async {
    await _updateGroup(groupId, (g) {
      final invited = {...g.invited, ...uids}.toList();
      return g.copyWith(invited: invited);
    });
    await db.enqueue('group.invite', {'groupId': groupId, 'uids': uids});
    _mutated();
  }

  Future<void> acceptGroupInvite(String groupId) async {
    await _updateGroup(
        groupId,
        (g) => g.copyWith(
              members: {...g.members, myUid}.toList(),
              invited: g.invited.where((u) => u != myUid).toList(),
            ));
    await db.enqueue('group.accept', {'groupId': groupId, 'uid': myUid});
    _mutated();
  }

  Future<void> declineGroupInvite(String groupId) async {
    await _updateGroup(
        groupId,
        (g) => g.copyWith(
              invited: g.invited.where((u) => u != myUid).toList(),
            ));
    await db.enqueue('group.decline', {'groupId': groupId, 'uid': myUid});
    _mutated();
  }

  // -------------------------------------------------------------- friends

  Stream<List<AppUser>> watchConnections() => _watch(() async {
        final rows = await db.connectionRows();
        final users = [
          for (final r in rows) AppUser.fromMap((r['uid'] as String?) ?? '', r)
        ];
        users.sort((a, b) => a.displayName.compareTo(b.displayName));
        return users;
      });

  Future<List<AppUser>> fetchConnections() async {
    final rows = await db.connectionRows();
    return [
      for (final r in rows) AppUser.fromMap((r['uid'] as String?) ?? '', r)
    ];
  }

  Stream<List<ConnectionRequest>> watchIncomingRequests() => _watch(() async {
        final rows = await db.requestRows('in');
        final list = [
          for (final r in rows)
            ConnectionRequest.fromMap(r['__id'] as String, r)
        ];
        list.sort((a, b) => (b.createdAt ?? DateTime(1970))
            .compareTo(a.createdAt ?? DateTime(1970)));
        return list;
      });

  Stream<List<ConnectionRequest>> watchOutgoingRequests() => _watch(() async {
        final rows = await db.requestRows('out');
        final list = [
          for (final r in rows)
            ConnectionRequest.fromMap(r['__id'] as String, r)
        ];
        list.sort((a, b) => (b.createdAt ?? DateTime(1970))
            .compareTo(a.createdAt ?? DateTime(1970)));
        return list;
      });

  /// Sends a friend request — visible in my outgoing list immediately,
  /// delivered to Firestore by the outbox when online.
  Future<void> sendConnectionRequest({
    required AppUser from,
    required AppUser to,
  }) async {
    if (from.uid == to.uid) return;
    final connections = await fetchConnections();
    if (connections.any((c) => c.uid == to.uid)) return;
    final now = DateTime.now();
    final localId = 'local-${_uuid.v4()}';
    final req = ConnectionRequest(
      id: localId,
      fromUid: from.uid,
      fromName: from.displayName,
      toUid: to.uid,
      toName: to.displayName,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
    );
    await db.upsertUser(to.uid, to.toProfileMap());
    await db.upsertRequest(localId, req.toMap(), 'out');
    await db.enqueue('conn.send', {
      'localId': localId,
      'fromUid': from.uid,
      'fromName': from.displayName,
      'toUid': to.uid,
      'toName': to.displayName,
    });
    _mutated();
  }

  /// Re-keys a locally created outgoing request to its remote id
  /// (called by SyncService once the send lands). See
  /// [LocalDatabase.remapRequestId].
  Future<void> remapRequestId(String localId, String remoteId) async {
    await db.remapRequestId(localId, remoteId);
    notifyChanged();
  }

  Future<void> acceptConnectionRequest(ConnectionRequest req) async {
    await db.deleteRequest(req.id);
    final other = AppUser(
      uid: req.otherUid(myUid),
      displayName: req.otherName(myUid),
      email: '',
    );
    await db.upsertConnection(other.uid, other.toProfileMap());
    await db.enqueue('conn.accept', {
      'requestId': req.id,
      'fromUid': req.fromUid,
      'fromName': req.fromName,
      'toUid': req.toUid,
      'toName': req.toName,
    });
    _mutated();
  }

  Future<void> declineConnectionRequest(String requestId) async {
    await db.deleteRequest(requestId);
    await db.enqueue('conn.decline', {'requestId': requestId});
    _mutated();
  }

  Future<void> cancelConnectionRequest(String requestId) async {
    await db.deleteRequest(requestId);
    await db.enqueue('conn.cancel', {'requestId': requestId});
    _mutated();
  }

  Future<void> removeConnection(String otherUid) async {
    await db.deleteConnection(otherUid);
    await db.enqueue('conn.remove', {'myUid': myUid, 'otherUid': otherUid});
    _mutated();
  }

  // ---------------------------------------------------------- notifications

  Stream<List<AppNotification>> watchNotifications() => _watch(() async {
        final rows = await db.notificationRows();
        final list = [
          for (final r in rows) AppNotification.fromMap(r['__id'] as String, r)
        ];
        list.sort((a, b) => (b.createdAt ?? DateTime(1970))
            .compareTo(a.createdAt ?? DateTime(1970)));
        return list;
      });

  /// Queues an inbox notification for another user (friend requests,
  /// group invites, reminders). Bill events are written by Cloud
  /// Functions when the bill document itself syncs.
  Future<void> sendNotification({
    required String toUid,
    required String title,
    required String body,
    required String type,
    String? billId,
    String? groupId,
  }) async {
    await db.enqueue('notify', {
      'toUid': toUid,
      'title': title,
      'body': body,
      'type': type,
      'billId': billId,
      'groupId': groupId,
    });
    requestSync?.call();
  }

  Future<void> markNotificationRead(String id) async {
    await db.markNotificationReadLocal(id);
    _mutated();
  }

  Future<void> markAllNotificationsRead() async {
    await db.markAllNotificationsReadLocal();
    _mutated();
  }

  // -------------------------------------------- sync application (internal)

  /// Records that the receipt photo for [billId] was uploaded during
  /// sync: the local row keeps the download URL and drops the local
  /// file path (the temp file is deleted by [SyncService]).
  Future<void> applyReceiptUploaded(String billId, String url) async {
    final bill = await billById(billId);
    if (bill == null) return;
    final state = await db.billSyncState(billId) ?? 'synced';
    await db.upsertBill(
      billId,
      bill.copyWith(receiptImageUrl: url, clearReceiptLocalPath: true).toMap(),
      syncState: state,
    );
    notifyChanged();
  }

  /// Applies a bill pulled from Firestore. A tombstone (`deleted`) purges
  /// the local row. Locally pending state is preserved.
  Future<void> applyRemoteBill(Bill bill) async {
    if (bill.deleted) {
      await db.deleteBill(bill.id);
      return;
    }
    final state = await db.billSyncState(bill.id);
    if (state == 'pending') return; // our unsynced create wins locally
    await db.upsertBill(bill.id, bill.toMap(), syncState: 'synced');
    for (final s in bill.splits) {
      // Cache participant profiles opportunistically — names are already
      // embedded in splits, so no extra reads are needed.
      final existing = await db.userRow(s.uid);
      if (existing == null && s.displayName.isNotEmpty) {
        await db.upsertUser(s.uid, {
          'displayName': s.displayName,
          'email': '',
          'photoUrl': null,
        });
      }
    }
  }

  Future<void> applyRemoteGroup(BillGroup group) async {
    if (group.deleted) {
      await db.deleteGroup(group.id);
      return;
    }
    final state = await db.groupSyncState(group.id);
    if (state == 'pending') return;
    await db.upsertGroup(group.id, group.toMap(), syncState: 'synced');
  }

  Future<void> applyRemoteNotification(AppNotification n) async {
    // Never clobber a read flag that has not been pushed yet.
    final rows = await db.notificationRows();
    final local = rows.where((r) => r['__id'] == n.id).firstOrNull;
    final locallyRead = local != null && (local['read'] as bool?) == true;
    await db.upsertNotification(
      n.id,
      n.copyWith(read: n.read || locallyRead).toMap(),
      syncState: locallyRead && !n.read ? 'pending_read' : 'synced',
    );
  }

  Future<void> applyRemoteRequest(ConnectionRequest req) async {
    if (req.status != 'pending') {
      await db.deleteRequest(req.id);
      return;
    }
    final direction = req.toUid == myUid ? 'in' : 'out';
    await db.upsertRequest(req.id, req.toMap(), direction);
  }

  Future<void> applyRemoteConnections(List<AppUser> users) async {
    await db.replaceConnections(
        [for (final u in users) u.toProfileMap()..['uid'] = u.uid]);
    for (final u in users) {
      await db.upsertUser(u.uid, u.toProfileMap());
    }
  }

  void dispose() => _changes.close();
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
