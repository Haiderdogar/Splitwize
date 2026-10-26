import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/models.dart';

/// Remote data source for the app — used ONLY by [SyncService] (and
/// [AuthService] for the initial profile upsert).
///
/// The app itself is offline-first: screens and forms read from SQLite
/// via [AppRepository] and write there too; this service only executes
/// the outbox and fetches *deltas* (documents changed since a cursor).
/// That is the core cost optimization: reads scale with changes, not
/// with total data, and there are no persistent snapshot listeners.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------- users

  Future<void> upsertUser(AppUser user) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    final data = user.toMap();
    if (!snap.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['fcmTokens'] = <String>[];
    }
    await ref.set(data, SetOptions(merge: true));
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromDoc(doc);
  }

  Future<List<AppUser>> fetchUsers(List<String> uids) async {
    final unique = uids.toSet().toList();
    final users = await Future.wait(unique.map(getUser));
    return users.whereType<AppUser>().toList();
  }

  Future<AppUser?> getUserByEmail(String email) async {
    final q = await _db
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return AppUser.fromDoc(q.docs.first);
  }

  Future<void> saveFcmToken(String uid, String token) async {
    await _db.collection('users').doc(uid).set(
      {
        'fcmTokens': FieldValue.arrayUnion([token]),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> removeFcmToken(String uid, String token) async {
    await _db.collection('users').doc(uid).update(
      {
        'fcmTokens': FieldValue.arrayRemove([token]),
      },
    );
  }

  // ------------------------------------------------- connection requests

  Future<void> sendConnectionRequest({
    required AppUser from,
    required AppUser to,
  }) async {
    if (from.uid == to.uid) return;
    final conn = await _db
        .collection('users')
        .doc(from.uid)
        .collection('connections')
        .doc(to.uid)
        .get();
    if (conn.exists) return;
    for (final pair in [
      [from.uid, to.uid],
      [to.uid, from.uid],
    ]) {
      final q = await _db
          .collection('connectionRequests')
          .where('fromUid', isEqualTo: pair[0])
          .where('toUid', isEqualTo: pair[1])
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) return;
    }
    await _db.collection('connectionRequests').add({
      'fromUid': from.uid,
      'fromName': from.displayName,
      'toUid': to.uid,
      'toName': to.displayName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Finds the remote request created from an offline `conn.send` op.
  Future<String?> findPendingRequestId(String fromUid, String toUid) async {
    final q = await _db
        .collection('connectionRequests')
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    return q.docs.isEmpty ? null : q.docs.first.id;
  }

  Future<void> acceptConnectionRequest(ConnectionRequest req) async {
    // The request may be gone (e.g. the sender cancelled first) —
    // update() on a missing document would throw and wedge the
    // outbox, so bail out quietly; the connections refresh will
    // settle the local state.
    final reqRef = _db.collection('connectionRequests').doc(req.id);
    final snap = await reqRef.get();
    if (!snap.exists) return;
    final batch = _db.batch();
    batch.update(
      reqRef,
      {'status': 'accepted', 'updatedAt': FieldValue.serverTimestamp()},
    );
    batch.set(
      _db
          .collection('users')
          .doc(req.fromUid)
          .collection('connections')
          .doc(req.toUid),
      {
        'uid': req.toUid,
        'displayName': req.toName,
        'connectedAt': FieldValue.serverTimestamp(),
      },
    );
    batch.set(
      _db
          .collection('users')
          .doc(req.toUid)
          .collection('connections')
          .doc(req.fromUid),
      {
        'uid': req.fromUid,
        'displayName': req.fromName,
        'connectedAt': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
  }

  Future<void> declineConnectionRequest(String requestId) async {
    final ref = _db.collection('connectionRequests').doc(requestId);
    if (!(await ref.get()).exists) return; // already gone — done
    await ref.update({
      'status': 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelConnectionRequest(String requestId) async {
    final ref = _db.collection('connectionRequests').doc(requestId);
    if (!(await ref.get()).exists) return; // already gone — done
    // A status flip, NOT a hard delete: the other side learns about
    // changes through delta pulls on updatedAt, and a deleted
    // document is invisible to those — it would leave a ghost
    // request in their inbox forever.
    await ref.update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeConnection(String myUid, String otherUid) async {
    final batch = _db.batch();
    batch.delete(_db
        .collection('users')
        .doc(myUid)
        .collection('connections')
        .doc(otherUid));
    batch.delete(_db
        .collection('users')
        .doc(otherUid)
        .collection('connections')
        .doc(myUid));
    await batch.commit();
  }

  /// Mirror docs (id + displayName only) — enough to render the friends
  /// list without paying an extra read per friend's profile.
  Future<List<AppUser>> fetchConnectionMirrors(String uid) async {
    final snap =
        await _db.collection('users').doc(uid).collection('connections').get();
    return snap.docs
        .map((d) => AppUser(
              uid: d.id,
              displayName: (d.data()['displayName'] as String?) ?? 'Friend',
              email: '',
            ))
        .toList();
  }

  /// Connection requests involving [uid].
  /// First sync (no [since]): pending docs only. Later: anything changed
  /// since [since] (so status changes propagate as deltas).
  Future<List<ConnectionRequest>> fetchRequests(String uid,
      {DateTime? since}) async {
    Future<QuerySnapshot> run(bool incoming) async {
      var q = _db
          .collection('connectionRequests')
          .where(incoming ? 'toUid' : 'fromUid', isEqualTo: uid);
      if (since == null) {
        q = q.where('status', isEqualTo: 'pending');
      } else {
        q = q.where('updatedAt', isGreaterThan: Timestamp.fromDate(since));
      }
      return q.get();
    }

    final out = <ConnectionRequest>[];
    final seen = <String>{};
    for (final incoming in [true, false]) {
      final snap = await run(incoming);
      for (final d in snap.docs) {
        if (seen.add(d.id)) out.add(ConnectionRequest.fromDoc(d));
      }
    }
    return out;
  }

  // ---------------------------------------------------------------- groups

  /// Pushes a locally created group (client-chosen id, merge).
  Future<void> pushGroup(Map<String, dynamic> map) async {
    final id = map['id'] as String;
    final data = Map<String, dynamic>.from(map)..remove('id');
    _toFirestoreDates(data);
    data['updatedAt'] = FieldValue.serverTimestamp();
    data['deleted'] = false;
    await _db.collection('groups').doc(id).set(data, SetOptions(merge: true));
  }

  Future<void> inviteToGroup(String groupId, List<String> uids) async {
    final group = (await _db.collection('groups').doc(groupId).get());
    if (!group.exists) return;
    final data = BillGroup.fromDoc(group);
    final fresh = uids
        .where((id) => !data.members.contains(id) && !data.invited.contains(id))
        .toList();
    if (fresh.isEmpty) return;
    await _db.collection('groups').doc(groupId).update({
      'invited': FieldValue.arrayUnion(fresh),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptGroupInvite(String groupId, String uid) async {
    await _db.collection('groups').doc(groupId).update({
      'invited': FieldValue.arrayRemove([uid]),
      'members': FieldValue.arrayUnion([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Sets a group's currency (ISO code). Stamps `updatedAt` so the
  /// delta sync propagates it to every member's local cache.
  Future<void> setGroupCurrency(String groupId, String code) async {
    await _db.collection('groups').doc(groupId).update({
      'currency': code,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> declineGroupInvite(String groupId, String uid) async {
    await _db.collection('groups').doc(groupId).update({
      'invited': FieldValue.arrayRemove([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Groups I belong to or am invited to, changed since [since].
  /// First sync (no [since]): everything (unfiltered).
  Future<List<BillGroup>> fetchGroupsDelta(String uid,
      {DateTime? since}) async {
    Future<QuerySnapshot> run(String field) async {
      var q = _db.collection('groups').where(field, arrayContains: uid);
      if (since != null) {
        q = q.where('updatedAt', isGreaterThan: Timestamp.fromDate(since));
      }
      return q.get();
    }

    final out = <BillGroup>[];
    final seen = <String>{};
    for (final field in ['members', 'invited']) {
      final snap = await run(field);
      for (final d in snap.docs) {
        if (seen.add(d.id)) out.add(BillGroup.fromDoc(d));
      }
    }
    return out;
  }

  // ----------------------------------------------------------------- bills

  /// Pushes a locally created bill (client-chosen id, merge).
  /// The Cloud Function `notifyBillCreated` fires on this write, so the
  /// other participants get their push even if their app is closed.
  Future<void> pushBill(Map<String, dynamic> map) async {
    final id = map['id'] as String;
    final data = Map<String, dynamic>.from(map)..remove('id');
    data.remove('receiptLocalPath'); // local-only, never stored remotely
    _toFirestoreDates(data);
    data['updatedAt'] = FieldValue.serverTimestamp();
    data['deleted'] = false;
    await _db.collection('bills').doc(id).set(data, SetOptions(merge: true));
  }

  /// Uploads a (compressed) receipt photo for [billId] to Firebase
  /// Storage and returns its download URL. Overwrites are idempotent —
  /// the same bill always maps to the same object path.
  Future<String> uploadReceipt(String billId, File file) async {
    final ref = FirebaseStorage.instance.ref('receipts/$billId.jpg');
    await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  /// Removes a bill's receipt photo remotely: clears the field on
  /// the bill document (stamping updatedAt so every participant's
  /// delta pull sees the removal) and deletes the Storage object.
  /// Existence-guarded — a bill that never landed remotely is a
  /// successful no-op, so the outbox can never wedge on it.
  Future<void> removeReceiptPhoto(String billId) async {
    final ref = _db.collection('bills').doc(billId);
    final snap = await ref.get();
    if (!snap.exists) return;
    await ref.update({
      'receiptImageUrl': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    try {
      await FirebaseStorage.instance.ref('receipts/$billId.jpg').delete();
    } catch (_) {
      // The object may not exist (the upload never landed) — the
      // document is already consistent, so this stays best-effort.
    }
  }

  /// Bills I participate in, changed since [since].
  /// First sync (no [since]): everything (unfiltered).
  Future<List<Bill>> fetchBillsDelta(String uid, {DateTime? since}) async {
    var q = _db.collection('bills').where('participantIds', arrayContains: uid);
    if (since != null) {
      q = q.where('updatedAt', isGreaterThan: Timestamp.fromDate(since));
    }
    final snap = await q.get();
    return snap.docs.map((d) => Bill.fromDoc(d)).toList();
  }

  /// Mark one participant's share as paid/unpaid (transactional).
  ///
  /// When [paidAmount] is given it wins: it is the share's settled
  /// amount (group debt simplification can settle part of a share),
  /// and the share counts as paid once the settled amount reaches the
  /// full share. Without it, [paid] flips the whole share — the
  /// behavior for ops queued by older app versions.
  Future<void> setSplitPaid({
    required String billId,
    required String uid,
    required bool paid,
    double? paidAmount,
  }) async {
    final ref = _db.collection('bills').doc(billId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final splits = ((data['splits'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      var changed = false;
      for (final s in splits) {
        if (s['uid'] != uid) continue;
        final shareAmount = (s['amount'] as num?)?.toDouble() ?? 0;
        final wasPaid = (s['paid'] as bool?) ?? false;
        final settledBefore = (s['paidAmount'] as num?)?.toDouble() ??
            (wasPaid ? shareAmount : 0.0);
        var target = paidAmount ?? (paid ? shareAmount : 0.0);
        if (target < 0) target = 0;
        if (target > shareAmount) target = shareAmount;
        target = (target * 100).round() / 100;
        final fullyPaid = shareAmount - target < 0.005;
        if ((target - settledBefore).abs() < 0.005 && wasPaid == fullyPaid) {
          continue;
        }
        s['paidAmount'] = target;
        s['paid'] = fullyPaid;
        // A concrete timestamp, NOT FieldValue.serverTimestamp():
        // Firestore rejects sentinel values nested inside an array,
        // which would fail every mark-paid write (and wedge the
        // outbox behind it). The doc-level updatedAt below still
        // uses the server stamp.
        s['paidAt'] = fullyPaid ? (s['paidAt'] ?? Timestamp.now()) : null;
        changed = true;
      }
      if (changed) {
        tx.update(ref, {
          'splits': splits,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // ------------------------------------------------------- notifications

  /// Client-side inbox write (friend requests, group invites, reminders).
  /// Bill events are written by Cloud Functions instead.
  Future<void> sendNotification({
    required String toUid,
    required String title,
    required String body,
    required String type, // friend_request | group_invite | reminder
    String? billId,
    String? groupId,
  }) async {
    await _db.collection('notifications').add({
      'toUid': toUid,
      'title': title,
      'body': body,
      'type': type,
      'billId': billId,
      'groupId': groupId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// My inbox notifications, changed since [since].
  /// First sync (no [since]): everything (unfiltered).
  Future<List<AppNotification>> fetchNotificationsDelta(String uid,
      {DateTime? since}) async {
    var q = _db.collection('notifications').where('toUid', isEqualTo: uid);
    if (since != null) {
      q = q.where('updatedAt', isGreaterThan: Timestamp.fromDate(since));
    }
    final snap = await q.get();
    return snap.docs.map((d) => AppNotification.fromDoc(d)).toList();
  }

  Future<void> markNotificationRead(String id) async {
    final ref = _db.collection('notifications').doc(id);
    if (!(await ref.get()).exists) return; // already gone — done
    await ref.update({
      'read': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ----------------------------------------------------------------- misc

  /// Converts int-millisecond dates (from the local outbox) back to
  /// Firestore dates before a push.
  void _toFirestoreDates(Map<String, dynamic> map) {
    for (final key in ['createdAt', 'updatedAt']) {
      final v = map[key];
      if (v is int) {
        map[key] = DateTime.fromMillisecondsSinceEpoch(v);
      }
    }
    final splits = map['splits'];
    if (splits is List) {
      for (final s in splits) {
        if (s is Map) {
          final paidAt = s['paidAt'];
          if (paidAt is int) {
            s['paidAt'] = DateTime.fromMillisecondsSinceEpoch(paidAt);
          }
        }
      }
    }
  }
}
