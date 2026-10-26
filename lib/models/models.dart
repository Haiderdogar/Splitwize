import 'package:cloud_firestore/cloud_firestore.dart';

/// Parses a date coming from Firestore ([Timestamp]), from the local
/// SQLite cache (int milliseconds / ISO string) or an in-memory [DateTime].
DateTime? dateFrom(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  return null;
}

/// A user profile stored in Firestore at `users/{uid}`.
class AppUser {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;

  /// Default currency (ISO 4217 code, e.g. 'PKR') used for new groups
  /// and friend bills. Null when never chosen — [currencyCode] then
  /// falls back to USD. Only written when set, so a sign-in upsert from
  /// another device never clobbers the saved choice.
  final String? currency;

  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.currency,
  });

  factory AppUser.fromDoc(DocumentSnapshot doc) =>
      AppUser.fromMap(doc.id, doc.data() as Map<String, dynamic>? ?? {});

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) => AppUser(
        uid: uid,
        displayName: (map['displayName'] as String?) ?? 'Friend',
        email: (map['email'] as String?) ?? '',
        photoUrl: map['photoUrl'] as String?,
        currency: map['currency'] as String?,
      );

  /// The effective default currency code (never null).
  String get currencyCode => currency ?? 'USD';

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email.toLowerCase(),
        'photoUrl': photoUrl,
        if (currency != null) 'currency': currency,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Plain (JSON-safe) profile map — no server sentinels.
  Map<String, dynamic> toProfileMap() => {
        'displayName': displayName,
        'email': email.toLowerCase(),
        'photoUrl': photoUrl,
        if (currency != null) 'currency': currency,
      };

  AppUser copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    String? currency,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      currency: currency ?? this.currency,
    );
  }

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// A friend/connection request stored in `connectionRequests/{id}`.
class ConnectionRequest {
  final String id;
  final String fromUid;
  final String fromName;
  final String toUid;
  final String toName;
  final String status; // pending | accepted | declined | cancelled
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ConnectionRequest({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.toName,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory ConnectionRequest.fromDoc(DocumentSnapshot doc) =>
      ConnectionRequest.fromMap(
          doc.id, doc.data() as Map<String, dynamic>? ?? {});

  factory ConnectionRequest.fromMap(String id, Map<String, dynamic> map) =>
      ConnectionRequest(
        id: id,
        fromUid: (map['fromUid'] as String?) ?? '',
        fromName: (map['fromName'] as String?) ?? '',
        toUid: (map['toUid'] as String?) ?? '',
        toName: (map['toName'] as String?) ?? '',
        status: (map['status'] as String?) ?? 'pending',
        createdAt: dateFrom(map['createdAt']),
        updatedAt: dateFrom(map['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'fromUid': fromUid,
        'fromName': fromName,
        'toUid': toUid,
        'toName': toName,
        'status': status,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  String otherUid(String myUid) => myUid == fromUid ? toUid : fromUid;
  String otherName(String myUid) => myUid == fromUid ? toName : fromName;
}

/// A group stored in `groups/{groupId}`.
/// `members` are accepted uids, `invited` are uids with a pending invite.
class BillGroup {
  final String id;
  final String name;
  final String createdBy;
  final List<String> members;
  final List<String> invited;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Soft-delete tombstone: set remotely instead of deleting the document,
  /// so delta sync can learn about the deletion and purge the local copy.
  final bool deleted;

  /// ISO 4217 currency code for this group's bills (e.g. 'PKR').
  /// Chosen at creation from the creator's default and changeable
  /// afterwards; existing bills keep the currency they were made with.
  final String currency;

  const BillGroup({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.members,
    required this.invited,
    this.createdAt,
    this.updatedAt,
    this.deleted = false,
    this.currency = 'USD',
  });

  factory BillGroup.fromDoc(DocumentSnapshot doc) =>
      BillGroup.fromMap(doc.id, doc.data() as Map<String, dynamic>? ?? {});

  factory BillGroup.fromMap(String id, Map<String, dynamic> map) => BillGroup(
        id: id,
        name: (map['name'] as String?) ?? 'Group',
        createdBy: (map['createdBy'] as String?) ?? '',
        members: List<String>.from((map['members'] as List?) ?? const []),
        invited: List<String>.from((map['invited'] as List?) ?? const []),
        createdAt: dateFrom(map['createdAt']),
        updatedAt: dateFrom(map['updatedAt']),
        deleted: (map['deleted'] as bool?) ?? false,
        currency: (map['currency'] as String?) ?? 'USD',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'createdBy': createdBy,
        'members': members,
        'invited': invited,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deleted': deleted,
        'currency': currency,
      };

  BillGroup copyWith({
    List<String>? members,
    List<String>? invited,
    String? currency,
  }) {
    return BillGroup(
      id: id,
      name: name,
      createdBy: createdBy,
      members: members ?? this.members,
      invited: invited ?? this.invited,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deleted: deleted,
      currency: currency ?? this.currency,
    );
  }
}

/// One person's share of a bill.
class BillSplit {
  final String uid;
  final String displayName;
  final double amount;
  final double? percent;
  final bool paid;
  final DateTime? paidAt;

  /// Portion of this share already settled through group debt
  /// simplification, when a simplified transfer covered only part of
  /// the share. Zero for untouched shares; when the settled portion
  /// reaches [amount] the share flips to [paid] instead. Only stored
  /// while the share is partially settled — older documents without
  /// the field derive it from [paid] (see [settledAmount]).
  final double paidAmount;

  const BillSplit({
    required this.uid,
    required this.displayName,
    required this.amount,
    this.percent,
    this.paid = false,
    this.paidAt,
    this.paidAmount = 0,
  });

  factory BillSplit.fromMap(Map<String, dynamic> map) {
    final amount = (map['amount'] as num?)?.toDouble() ?? 0;
    final paid = (map['paid'] as bool?) ?? false;
    return BillSplit(
      uid: (map['uid'] as String?) ?? '',
      displayName: (map['displayName'] as String?) ?? '',
      amount: amount,
      percent: (map['percent'] as num?)?.toDouble(),
      paid: paid,
      paidAt: dateFrom(map['paidAt']),
      // Documents written before partial settlement existed carry no
      // paidAmount: a paid share is fully settled, an unpaid one not
      // settled at all.
      paidAmount:
          (map['paidAmount'] as num?)?.toDouble() ?? (paid ? amount : 0),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'amount': amount,
        'percent': percent,
        'paid': paid,
        'paidAt': paidAt,
        // Only a genuinely partial settlement needs the extra field;
        // fully paid shares are described by `paid` alone.
        if (!paid && paidAmount > 0) 'paidAmount': paidAmount,
      };

  /// How much of this share is already settled (0…[amount]).
  double get settledAmount =>
      paid ? amount : paidAmount.clamp(0, amount).toDouble();

  /// How much of this share is still owed, rounded to whole cents.
  double get remainingAmount {
    final r = amount - settledAmount;
    if (r < 0.005) return 0;
    return (r * 100).round() / 100;
  }

  bool get isFullyPaid => remainingAmount == 0;

  bool get isPartiallyPaid => settledAmount > 0.005 && !isFullyPaid;

  BillSplit copyWith({
    bool? paid,
    DateTime? paidAt,
    bool clearPaidAt = false,
    double? paidAmount,
  }) {
    return BillSplit(
      uid: uid,
      displayName: displayName,
      amount: amount,
      percent: percent,
      paid: paid ?? this.paid,
      paidAt: clearPaidAt ? null : (paidAt ?? this.paidAt),
      paidAmount: paidAmount ?? this.paidAmount,
    );
  }
}

/// A bill stored in `bills/{billId}`.
class Bill {
  final String id;
  final String title;
  final double subtotal;
  final double tipPercent;
  final double total;
  final String splitType; // equal | percentage | custom
  final String createdBy;
  final String createdByName;
  final String? groupId;
  final String? groupName;
  final List<String> participantIds;
  final List<BillSplit> splits;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Download URL of the optional receipt photo in Firebase Storage.
  /// Null when no photo was attached (or it hasn't synced yet).
  final String? receiptImageUrl;

  /// Local-only path of the compressed receipt waiting to upload.
  /// Never pushed to Firestore (stripped by the push) — set when the
  /// bill was created offline with a photo attached.
  final String? receiptLocalPath;

  /// ISO 4217 currency code the amounts are in (e.g. 'PKR'). Copied
  /// from the group when the bill is created (or the creator's default
  /// currency for friend bills); a bill's currency never changes.
  final String currency;

  /// Soft-delete tombstone (see [BillGroup.deleted]).
  final bool deleted;

  const Bill({
    required this.id,
    required this.title,
    required this.subtotal,
    required this.tipPercent,
    required this.total,
    required this.splitType,
    required this.createdBy,
    required this.createdByName,
    this.groupId,
    this.groupName,
    required this.participantIds,
    required this.splits,
    this.createdAt,
    this.updatedAt,
    this.receiptImageUrl,
    this.receiptLocalPath,
    this.currency = 'USD',
    this.deleted = false,
  });

  factory Bill.fromDoc(DocumentSnapshot doc) =>
      Bill.fromMap(doc.id, doc.data() as Map<String, dynamic>? ?? {});

  factory Bill.fromMap(String id, Map<String, dynamic> map) {
    final splits = ((map['splits'] as List?) ?? const [])
        .map((e) => BillSplit.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return Bill(
      id: id,
      title: (map['title'] as String?) ?? 'Bill',
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      tipPercent: (map['tipPercent'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      splitType: (map['splitType'] as String?) ?? 'equal',
      createdBy: (map['createdBy'] as String?) ?? '',
      createdByName: (map['createdByName'] as String?) ?? '',
      groupId: map['groupId'] as String?,
      groupName: map['groupName'] as String?,
      participantIds:
          List<String>.from((map['participantIds'] as List?) ?? const []),
      splits: splits,
      createdAt: dateFrom(map['createdAt']),
      updatedAt: dateFrom(map['updatedAt']),
      receiptImageUrl: map['receiptImageUrl'] as String?,
      receiptLocalPath: map['receiptLocalPath'] as String?,
      currency: (map['currency'] as String?) ?? 'USD',
      deleted: (map['deleted'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'subtotal': subtotal,
        'tipPercent': tipPercent,
        'total': total,
        'splitType': splitType,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'groupId': groupId,
        'groupName': groupName,
        'participantIds': participantIds,
        'splits': splits.map((s) => s.toMap()).toList(),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'receiptImageUrl': receiptImageUrl,
        'receiptLocalPath': receiptLocalPath,
        'currency': currency,
        'deleted': deleted,
      };

  Bill copyWith({
    List<BillSplit>? splits,
    DateTime? updatedAt,
    String? receiptImageUrl,
    String? receiptLocalPath,
    bool clearReceiptImageUrl = false,
    bool clearReceiptLocalPath = false,
  }) {
    return Bill(
      id: id,
      title: title,
      subtotal: subtotal,
      tipPercent: tipPercent,
      total: total,
      splitType: splitType,
      createdBy: createdBy,
      createdByName: createdByName,
      groupId: groupId,
      groupName: groupName,
      participantIds: participantIds,
      splits: splits ?? this.splits,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      receiptImageUrl: clearReceiptImageUrl
          ? null
          : (receiptImageUrl ?? this.receiptImageUrl),
      receiptLocalPath: clearReceiptLocalPath
          ? null
          : (receiptLocalPath ?? this.receiptLocalPath),
      currency: currency,
      deleted: deleted,
    );
  }

  String get splitTypeLabel {
    switch (splitType) {
      case 'percentage':
        return 'Percentage';
      case 'custom':
        return 'Custom';
      default:
        return 'Equal';
    }
  }

  double myShare(String uid) {
    final s = splits.where((e) => e.uid == uid);
    if (s.isEmpty) return 0;
    return s.first.amount;
  }

  /// Settlement helpers. A partially settled share (see
  /// [BillSplit.paidAmount]) counts as paid only once nothing remains.
  int get paidCount => splits.where((s) => s.isFullyPaid).length;

  double get outstanding => splits.fold(0.0, (a, s) => a + s.remainingAmount);

  bool get fullySettled => splits.isNotEmpty && paidCount == splits.length;
}

/// Net balance with one friend **in one currency**, computed from unpaid
/// splits across all bills. `net > 0` means the friend owes me;
/// `net < 0` means I owe the friend. (Balances are kept per currency —
/// a PKR debt and a USD debt are never mixed.)
class FriendBalance {
  final String uid;
  final String displayName;

  /// ISO 4217 currency code of the amounts below.
  final String currency;
  final double net;
  final double owesMe;
  final double iOweThem;
  final int openBills;

  const FriendBalance({
    required this.uid,
    required this.displayName,
    required this.currency,
    required this.net,
    required this.owesMe,
    required this.iOweThem,
    required this.openBills,
  });

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// An in-app notification stored in `notifications/{id}`.
/// Written by Cloud Functions (bill events) and by clients (invites).
class AppNotification {
  final String id;
  final String toUid;
  final String title;
  final String body;
  final String type; // bill_created | bill_paid | friend_request | group_invite
  final String? billId;
  final String? groupId;
  final bool read;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AppNotification({
    required this.id,
    required this.toUid,
    required this.title,
    required this.body,
    required this.type,
    this.billId,
    this.groupId,
    required this.read,
    this.createdAt,
    this.updatedAt,
  });

  factory AppNotification.fromDoc(DocumentSnapshot doc) =>
      AppNotification.fromMap(
          doc.id, doc.data() as Map<String, dynamic>? ?? {});

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) =>
      AppNotification(
        id: id,
        toUid: (map['toUid'] as String?) ?? '',
        title: (map['title'] as String?) ?? '',
        body: (map['body'] as String?) ?? '',
        type: (map['type'] as String?) ?? '',
        billId: map['billId'] as String?,
        groupId: map['groupId'] as String?,
        read: (map['read'] as bool?) ?? false,
        createdAt: dateFrom(map['createdAt']),
        updatedAt: dateFrom(map['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'toUid': toUid,
        'title': title,
        'body': body,
        'type': type,
        'billId': billId,
        'groupId': groupId,
        'read': read,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      toUid: toUid,
      title: title,
      body: body,
      type: type,
      billId: billId,
      groupId: groupId,
      read: read ?? this.read,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
