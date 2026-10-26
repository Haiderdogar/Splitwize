import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../data/app_repository.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';

/// The current state of background sync, for a small status indicator.
class SyncState {
  final bool syncing;
  final bool online;
  final DateTime? lastSyncedAt;
  final int pending; // outbox operations waiting for connectivity
  final String? error;

  const SyncState({
    this.syncing = false,
    this.online = true,
    this.lastSyncedAt,
    this.pending = 0,
    this.error,
  });

  SyncState copyWith({
    bool? syncing,
    bool? online,
    DateTime? lastSyncedAt,
    int? pending,
    String? error,
  }) {
    return SyncState(
      syncing: syncing ?? this.syncing,
      online: online ?? this.online,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pending: pending ?? this.pending,
      error: error,
    );
  }
}

/// Drains the local outbox into Firestore and pulls everyone else's
/// changes as deltas — the single place where network reads/writes
/// happen, and the reason the Firebase bill stays tiny:
///
/// - **Push**: only real user actions leave the device, replayed from the
///   outbox in order when online. A bill created offline sits in the
///   outbox until connectivity returns; the moment it lands in Firestore
///   the Cloud Function fires, so participants get their push
///   notification even if their app is closed.
/// - **Pull**: no snapshot listeners (which charge a read per changed
///   document forever). Instead each collection is re-fetched only for
///   documents with `updatedAt` newer than the last successful pull
///   (with a 60s overlap for clock skew). After the first sync this is
///   usually a handful of documents, often zero.
/// - Connections are the one full refresh: mirror documents are tiny
///   (id + displayName, no profile reads).
class SyncService {
  SyncService({
    required this.repository,
    required this.remote,
  });

  final AppRepository repository;
  final FirestoreService remote;

  static const _overlap = Duration(seconds: 60);

  final _state = StreamController<SyncState>.broadcast();
  SyncState _current = const SyncState();
  bool _syncing = false;
  bool _queued = false;
  StreamSubscription? _connectivitySub;
  bool _started = false;

  Stream<SyncState> get state => _state.stream;
  SyncState get current => _current;

  String get myUid => repository.myUid;

  void _emit(SyncState s) {
    _current = s;
    if (!_state.isClosed) _state.add(s);
  }

  /// Starts the connectivity listener and runs the first sync.
  Future<void> init() async {
    if (_started) return;
    _started = true;
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      _emit(_current.copyWith(online: online));
      if (online) syncNow();
    });
    try {
      final results = await Connectivity().checkConnectivity();
      _emit(_current.copyWith(
          online: results.any((r) => r != ConnectivityResult.none)));
    } catch (_) {}
    unawaited(syncNow());
  }

  /// Pushes pending mutations, then pulls deltas. Safe to call often;
  /// concurrent calls collapse into one.
  Future<void> syncNow() async {
    if (_syncing) {
      _queued = true;
      return;
    }
    _syncing = true;
    _emit(_current.copyWith(syncing: true, error: null));
    try {
      final online = await _isOnline();
      _emit(_current.copyWith(online: online));
      if (!online) {
        _emit(_current.copyWith(
            syncing: false, pending: await repository.db.outboxCount()));
        return;
      }
      await _pushOutbox();
      await _pushReadFlags();
      await _pullDeltas();
      repository.notifyChanged();
      _emit(_current.copyWith(
        syncing: false,
        lastSyncedAt: DateTime.now(),
        pending: await repository.db.outboxCount(),
      ));
    } catch (e) {
      _emit(_current.copyWith(
        syncing: false,
        error: e.toString(),
        pending: await repository.db.outboxCount(),
      ));
    } finally {
      _syncing = false;
      if (_queued) {
        _queued = false;
        unawaited(syncNow());
      }
    }
  }

  Future<bool> _isOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------ push

  Future<void> _pushOutbox() async {
    final db = repository.db;
    for (final op in await db.peekOutbox()) {
      final id = op['id'] as int;
      final type = op['type'] as String;
      final payload = op['payload'] as Map<String, dynamic>;
      try {
        await _execute(type, payload);
        await db.removeOutbox(id);
        // Bill/group creates flip their local rows to synced.
        if (type == 'bill.create') {
          await db.markBillSynced((payload['bill'] as Map)['id'] as String);
        } else if (type == 'group.create') {
          await db.markGroupSynced((payload['group'] as Map)['id'] as String);
        }
      } catch (_) {
        await db.bumpOutboxRetries(id);
        rethrow; // preserve order — retry everything next time
      }
    }
  }

  Future<void> _execute(String type, Map<String, dynamic> p) async {
    switch (type) {
      case 'bill.create':
        await _pushBillCreate(Map<String, dynamic>.from(p['bill'] as Map));
      case 'group.create':
        await remote.pushGroup(Map<String, dynamic>.from(p['group'] as Map));
      case 'bill.setPaid':
        await remote.setSplitPaid(
          billId: p['billId'] as String,
          uid: p['uid'] as String,
          paid: p['paid'] as bool,
          // Absent on ops queued by older app versions — the remote
          // side then applies the plain paid/unpaid flip.
          paidAmount: (p['paidAmount'] as num?)?.toDouble(),
        );
      case 'bill.receiptRemoved':
        await remote.removeReceiptPhoto(p['billId'] as String);
      case 'group.invite':
        await remote.inviteToGroup(
          p['groupId'] as String,
          List<String>.from(p['uids'] as List),
        );
      case 'group.accept':
        await remote.acceptGroupInvite(
            p['groupId'] as String, p['uid'] as String);
      case 'group.currency':
        await remote.setGroupCurrency(
            p['groupId'] as String, p['currency'] as String);
      case 'group.decline':
        await remote.declineGroupInvite(
            p['groupId'] as String, p['uid'] as String);
      case 'conn.send':
        await _pushConnectionSend(p);
      case 'conn.accept':
        await remote.acceptConnectionRequest(ConnectionRequest(
          id: p['requestId'] as String,
          fromUid: p['fromUid'] as String,
          fromName: p['fromName'] as String,
          toUid: p['toUid'] as String,
          toName: p['toName'] as String,
          status: 'pending',
        ));
      case 'conn.decline':
        await remote.declineConnectionRequest(
            await _resolveRequestId(p['requestId'] as String));
      case 'conn.cancel':
        await remote.cancelConnectionRequest(
            await _resolveRequestId(p['requestId'] as String));
      case 'conn.remove':
        await remote.removeConnection(
            p['myUid'] as String, p['otherUid'] as String);
      case 'notify':
        await remote.sendNotification(
          toUid: p['toUid'] as String,
          title: p['title'] as String,
          body: p['body'] as String,
          type: p['type'] as String,
          billId: p['billId'] as String?,
          groupId: p['groupId'] as String?,
        );
      case 'user.upsert':
        await remote.upsertUser(AppUser.fromMap(
          p['uid'] as String,
          Map<String, dynamic>.from(p),
        ));
      default:
        // Unknown op — drop it so it can never wedge the queue.
        break;
    }
  }

  /// Pushes an offline-created bill. If a receipt photo was attached,
  /// it is uploaded to Firebase Storage first (this only runs when
  /// online — the whole sync aborts earlier otherwise) and the
  /// download URL goes into the pushed document.
  ///
  /// Ordering matters: the local row is only updated (and the temp
  /// file only deleted) AFTER the bill document itself has landed.
  /// If the push fails midway, the retry finds the temp file still in
  /// place and simply re-uploads (same Storage path, idempotent) —
  /// or, if the file is somehow gone, reuses the URL an earlier
  /// attempt already recorded on the local row.
  Future<void> _pushBillCreate(Map<String, dynamic> billMap) async {
    final billId = billMap['id'] as String;
    // The local row is the live truth for the receipt: the user may
    // have removed the photo after this op was queued, in which case
    // the bill goes out without one. The queued payload is only a
    // fallback for a row that no longer exists.
    final localBill = await repository.billById(billId);
    final localPath =
        localBill?.receiptLocalPath ?? (billMap['receiptLocalPath'] as String?);
    String? uploadedUrl;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (await file.exists()) {
        uploadedUrl = await remote.uploadReceipt(billId, file);
        billMap['receiptImageUrl'] = uploadedUrl;
      } else {
        // Temp file is gone (e.g. the OS cleaned the cache folder);
        // drop the stale reference so the push stays clean, and keep
        // any URL a previous attempt managed to record locally.
        billMap['receiptLocalPath'] = null;
        final local = await repository.billById(billId);
        if (local?.receiptImageUrl != null) {
          billMap['receiptImageUrl'] = local!.receiptImageUrl;
        }
      }
    }
    await remote.pushBill(billMap);
    if (uploadedUrl != null) {
      await repository.applyReceiptUploaded(billId, uploadedUrl);
      try {
        await File(localPath!).delete();
      } catch (_) {}
    }
  }

  Future<void> _pushConnectionSend(Map<String, dynamic> p) async {
    await remote.sendConnectionRequest(
      from: AppUser(
        uid: p['fromUid'] as String,
        displayName: p['fromName'] as String,
        email: '',
      ),
      to: AppUser(
        uid: p['toUid'] as String,
        displayName: p['toName'] as String,
        email: '',
      ),
    );
    // Remember which remote request backs this local one, so a later
    // cancel/decline op can target it.
    final remoteId = await remote.findPendingRequestId(
      p['fromUid'] as String,
      p['toUid'] as String,
    );
    if (remoteId != null) {
      await repository.db.setMeta('reqmap_${p['localId']}', remoteId);
      // Re-key the local row to the remote id, so delta pulls match
      // it (no duplicate) and clear it when its status changes.
      await repository.remapRequestId(p['localId'] as String, remoteId);
    }
  }

  /// Maps a possibly-local request id to its remote id.
  Future<String> _resolveRequestId(String id) async {
    if (!id.startsWith('local-')) return id;
    return await repository.db.getMeta('reqmap_$id') ?? id;
  }

  /// Pushes read flags for notifications marked read while offline.
  Future<void> _pushReadFlags() async {
    for (final id in await repository.db.pendingReadNotificationIds()) {
      try {
        await remote.markNotificationRead(id);
        await repository.db.markNotificationSynced(id);
      } catch (_) {
        // Leave pending — the next sync will retry.
        break;
      }
    }
  }

  // ------------------------------------------------------------------ pull

  /// Fetches only what changed since the last successful pull.
  /// [since] is the previous cursor minus a small overlap; null means
  /// "first sync — take everything".
  Future<void> _pullDeltas() async {
    final db = repository.db;
    final startedAt = DateTime.now();

    Future<DateTime?> readCursor(String key) async {
      final raw = await db.getMeta(key);
      if (raw == null) return null;
      final ms = int.tryParse(raw);
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    }

    Future<DateTime> advanceCursor(
        String key, DateTime? prev, Iterable<DateTime?> seen) async {
      var max = prev;
      for (final d in seen) {
        if (d != null && (max == null || d.isAfter(max))) max = d;
      }
      // Fall back to "now" so documents that pre-date this feature
      // (no updatedAt) are not re-fetched forever.
      final next = max ?? startedAt;
      await db.setMeta(key, next.millisecondsSinceEpoch.toString());
      return next;
    }

    // Bills ------------------------------------------------------------
    {
      final cur = await readCursor('cursor_bills');
      final since = cur?.subtract(_overlap);
      final bills = await remote.fetchBillsDelta(myUid, since: since);
      for (final b in bills) {
        await repository.applyRemoteBill(b);
      }
      await advanceCursor('cursor_bills', cur, bills.map((b) => b.updatedAt));
    }

    // Groups -----------------------------------------------------------
    {
      final cur = await readCursor('cursor_groups');
      final since = cur?.subtract(_overlap);
      final groups = await remote.fetchGroupsDelta(myUid, since: since);
      for (final g in groups) {
        await repository.applyRemoteGroup(g);
      }
      await advanceCursor('cursor_groups', cur, groups.map((g) => g.updatedAt));
    }

    // Notifications ----------------------------------------------------
    {
      final cur = await readCursor('cursor_notifications');
      final since = cur?.subtract(_overlap);
      final notifs = await remote.fetchNotificationsDelta(myUid, since: since);
      for (final n in notifs) {
        await repository.applyRemoteNotification(n);
      }
      await advanceCursor(
          'cursor_notifications', cur, notifs.map((n) => n.updatedAt));
    }

    // Connection requests ---------------------------------------------
    {
      final cur = await readCursor('cursor_requests');
      final since = cur?.subtract(_overlap);
      final requests = await remote.fetchRequests(myUid, since: since);
      for (final r in requests) {
        await repository.applyRemoteRequest(r);
      }
      await advanceCursor(
          'cursor_requests', cur, requests.map((r) => r.updatedAt));
    }

    // Connections (full refresh — mirror docs are tiny) ---------------
    {
      final mirrors = await remote.fetchConnectionMirrors(myUid);
      await repository.applyRemoteConnections(mirrors);
      // Resolve display names for anyone referenced by bills/groups who
      // we haven't cached a real profile for — best effort.
    }

    // Cache profiles referenced by pulled data ------------------------
    {
      final bills = await repository.db.billsFor(myUid);
      final uids = <String>{};
      for (final r in bills) {
        final map = r;
        final ids = (map['participantIds'] as List?) ?? const [];
        uids.addAll(ids.cast<String>());
      }
      final missing = <String>[];
      for (final uid in uids) {
        if (await repository.db.userRow(uid) == null) missing.add(uid);
      }
      if (missing.isNotEmpty) {
        try {
          final users = await remote.fetchUsers(missing.take(50).toList());
          for (final u in users) {
            await repository.db.upsertUser(u.uid, u.toProfileMap());
          }
        } catch (_) {}
      }
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _state.close();
  }
}
