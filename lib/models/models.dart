import 'package:cloud_firestore/cloud_firestore.dart';

bool _paymentMapsEqual(Map<String, double> a, Map<String, double> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (a[key] != b[key]) return false;
  }
  return true;
}

/// Element-wise list equality (Dart's `List ==` is identity only).
/// Used by the model `==` operators below and by the repository's
/// change stream, so a re-query that returns the same content does
/// not count as a change (see `AppRepository._watch`).
bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

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

  /// A name deliberately saved in the app takes precedence over Google.
  final bool nameIsCustom;

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
    this.nameIsCustom = false,
  });

  factory AppUser.fromDoc(DocumentSnapshot doc) =>
      AppUser.fromMap(doc.id, doc.data() as Map<String, dynamic>? ?? {});

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) => AppUser(
        uid: uid,
        displayName: (map['displayName'] as String?) ?? 'Friend',
        email: (map['email'] as String?) ?? '',
        photoUrl: map['photoUrl'] as String?,
        currency: map['currency'] as String?,
        nameIsCustom: map['nameIsCustom'] == true,
      );

  /// The effective default currency code (never null).
  String get currencyCode => currency ?? 'USD';

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email.toLowerCase(),
        'photoUrl': photoUrl,
        if (currency != null) 'currency': currency,
        if (nameIsCustom) 'nameIsCustom': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Plain (JSON-safe) profile map — no server sentinels.
  Map<String, dynamic> toProfileMap() => {
        'displayName': displayName,
        'email': email.toLowerCase(),
        'photoUrl': photoUrl,
        if (currency != null) 'currency': currency,
        if (nameIsCustom) 'nameIsCustom': true,
      };

  AppUser copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    String? currency,
    bool? nameIsCustom,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      currency: currency ?? this.currency,
      nameIsCustom: nameIsCustom ?? this.nameIsCustom,
    );
  }

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  // Value equality: two profiles built from the same data are the
  // same profile. The repository's change stream and Riverpod's
  // listeners rely on this to skip rebuilds when a re-query returns
  // unchanged content (see `AppRepository._watch`).
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          uid == other.uid &&
          displayName == other.displayName &&
          email == other.email &&
          photoUrl == other.photoUrl &&
          currency == other.currency &&
          nameIsCustom == other.nameIsCustom;

  @override
  int get hashCode =>
      Object.hash(uid, displayName, email, photoUrl, currency, nameIsCustom);
}

/// A friend/connection request stored in `connectionRequests/{id}`.
class ConnectionRequest {
  final String id;
  final String fromUid;
  final String fromName;
  final String toUid;
  final String toName;
  final String fromEmail;
  final String toEmail;
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
    this.fromEmail = '',
    this.toEmail = '',
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
        fromEmail: map['fromEmail'] as String? ?? '',
        toEmail: map['toEmail'] as String? ?? '',
        status: (map['status'] as String?) ?? 'pending',
        createdAt: dateFrom(map['createdAt']),
        updatedAt: dateFrom(map['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'fromUid': fromUid,
        'fromName': fromName,
        'toUid': toUid,
        'toName': toName,
        'fromEmail': fromEmail,
        'toEmail': toEmail,
        'status': status,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  String otherUid(String myUid) => myUid == fromUid ? toUid : fromUid;
  String otherName(String myUid) => myUid == fromUid ? toName : fromName;

  // Value equality (see AppUser). `updatedAt` is sync bookkeeping
  // that is never displayed, so it is deliberately excluded: a sync
  // that only bumps it must not rebuild the Friends tab.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectionRequest &&
          id == other.id &&
          fromUid == other.fromUid &&
          fromName == other.fromName &&
          toUid == other.toUid &&
          toName == other.toName &&
          fromEmail == other.fromEmail &&
          toEmail == other.toEmail &&
          status == other.status &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        fromUid,
        fromName,
        toUid,
        toName,
        fromEmail,
        toEmail,
        status,
        createdAt,
      );
}

class GroupInvitation {
  const GroupInvitation({required this.from, required this.to, this.sentAt});
  final AppUser from;
  final AppUser to;
  final DateTime? sentAt;

  factory GroupInvitation.fromMap(Map<String, dynamic> map) {
    final from = Map<String, dynamic>.from(map['from'] as Map? ?? {});
    final to = Map<String, dynamic>.from(map['to'] as Map? ?? {});
    return GroupInvitation(
      from: AppUser.fromMap(from['uid'] as String? ?? '', from),
      to: AppUser.fromMap(to['uid'] as String? ?? '', to),
      sentAt: dateFrom(map['sentAt']),
    );
  }
  Map<String, dynamic> toMap() => {
        'from': {'uid': from.uid, ...from.toProfileMap()},
        'to': {'uid': to.uid, ...to.toProfileMap()},
        'sentAt': sentAt,
      };
  @override
  bool operator ==(Object other) =>
      other is GroupInvitation &&
      from == other.from &&
      to == other.to &&
      sentAt == other.sentAt;
  @override
  int get hashCode => Object.hash(from, to, sentAt);
}

/// A group stored in `groups/{groupId}`.
/// `members` are accepted uids, `invited` are uids with a pending invite.
class BillGroup {
  final String id;
  final String name;
  final String createdBy;
  final List<String> members;
  final List<String> invited;
  final Map<String, GroupInvitation> invitations;
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
    this.invitations = const {},
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
        invitations: {
          for (final entry in (map['invitations'] as Map? ?? {}).entries)
            entry.key.toString(): GroupInvitation.fromMap(
                Map<String, dynamic>.from(entry.value as Map)),
        },
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
        'invitations':
            invitations.map((uid, invite) => MapEntry(uid, invite.toMap())),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deleted': deleted,
        'currency': currency,
      };

  BillGroup copyWith({
    List<String>? members,
    List<String>? invited,
    Map<String, GroupInvitation>? invitations,
    String? currency,
  }) {
    return BillGroup(
      id: id,
      name: name,
      createdBy: createdBy,
      members: members ?? this.members,
      invited: invited ?? this.invited,
      invitations: invitations ?? this.invitations,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deleted: deleted,
      currency: currency ?? this.currency,
    );
  }

  // Value equality (see AppUser). `updatedAt` is excluded: it is
  // sync bookkeeping, never displayed.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillGroup &&
          id == other.id &&
          name == other.name &&
          createdBy == other.createdBy &&
          _listEquals(members, other.members) &&
          _listEquals(invited, other.invited) &&
          invitations.length == other.invitations.length &&
          invitations.entries
              .every((entry) => other.invitations[entry.key] == entry.value) &&
          createdAt == other.createdAt &&
          deleted == other.deleted &&
          currency == other.currency;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        createdBy,
        Object.hashAll(members),
        Object.hashAll(invited),
        Object.hashAll((invitations.keys.toList()..sort())
            .map((uid) => Object.hash(uid, invitations[uid]))),
        createdAt,
        deleted,
        currency,
      );
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

  // Value equality (see AppUser). `paidAt` is included: the bill
  // detail screen displays it ("Paid on …").
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillSplit &&
          uid == other.uid &&
          displayName == other.displayName &&
          amount == other.amount &&
          percent == other.percent &&
          paid == other.paid &&
          paidAt == other.paidAt &&
          paidAmount == other.paidAmount;

  @override
  int get hashCode => Object.hash(
        uid,
        displayName,
        amount,
        percent,
        paid,
        paidAt,
        paidAmount,
      );
}

/// One remaining obligation created by the initial merchant payments.
/// A participant can have multiple creditors; this ledger avoids assuming
/// that the bill creator paid the merchant. Values are stored in cents.
class BillDebt {
  final String id;
  final String debtorUid;
  final String debtorName;
  final String creditorUid;
  final String creditorName;
  final double amount;
  final double settledAmount;

  const BillDebt({
    required this.id,
    required this.debtorUid,
    required this.debtorName,
    required this.creditorUid,
    required this.creditorName,
    required this.amount,
    this.settledAmount = 0,
  });

  factory BillDebt.fromMap(Map<String, dynamic> map) => BillDebt(
        id: map['id'] as String? ?? '',
        debtorUid: map['debtorUid'] as String? ?? '',
        debtorName: map['debtorName'] as String? ?? '',
        creditorUid: map['creditorUid'] as String? ?? '',
        creditorName: map['creditorName'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        settledAmount: (map['settledAmount'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'debtorUid': debtorUid,
        'debtorName': debtorName,
        'creditorUid': creditorUid,
        'creditorName': creditorName,
        'amount': amount,
        'settledAmount': settledAmount,
      };

  double get remainingAmount =>
      ((amount - settledAmount).clamp(0, amount) * 100).round() / 100;

  bool get isSettled => remainingAmount < 0.005;

  BillDebt copyWith({double? settledAmount}) => BillDebt(
        id: id,
        debtorUid: debtorUid,
        debtorName: debtorName,
        creditorUid: creditorUid,
        creditorName: creditorName,
        amount: amount,
        settledAmount: settledAmount ?? this.settledAmount,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillDebt &&
          id == other.id &&
          debtorUid == other.debtorUid &&
          debtorName == other.debtorName &&
          creditorUid == other.creditorUid &&
          creditorName == other.creditorName &&
          amount == other.amount &&
          settledAmount == other.settledAmount;

  @override
  int get hashCode => Object.hash(id, debtorUid, debtorName, creditorUid,
      creditorName, amount, settledAmount);
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

  /// Merchant payments are immutable after creation; the expense's creator
  /// need not be a payer. Empty on legacy bills written before this feature.
  final Map<String, double> merchantPayments;

  /// Who pays whom to settle the expense, with separate settlement progress.
  /// Legacy bills use [splits] instead.
  final List<BillDebt> paymentDebts;

  bool get hasPaymentLedger => merchantPayments.isNotEmpty;

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
    this.merchantPayments = const {},
    this.paymentDebts = const [],
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
      merchantPayments: Map<String, double>.from(
        (map['merchantPayments'] as Map?)?.map(
              (key, value) => MapEntry(
                key.toString(),
                (value as num).toDouble(),
              ),
            ) ??
            const <String, double>{},
      ),
      paymentDebts: [
        for (final row in (map['paymentDebts'] as List?) ?? const [])
          BillDebt.fromMap(Map<String, dynamic>.from(row as Map)),
      ],
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
        if (hasPaymentLedger) 'merchantPayments': merchantPayments,
        if (hasPaymentLedger)
          'paymentDebts': paymentDebts.map((d) => d.toMap()).toList(),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'receiptImageUrl': receiptImageUrl,
        'receiptLocalPath': receiptLocalPath,
        'currency': currency,
        'deleted': deleted,
      };

  Bill copyWith({
    List<BillSplit>? splits,
    List<BillDebt>? paymentDebts,
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
      merchantPayments: merchantPayments,
      paymentDebts: paymentDebts ?? this.paymentDebts,
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

  // Value equality (see AppUser). `updatedAt` is excluded: it is
  // sync bookkeeping, never displayed. Everything the UI shows —
  // title, amounts, splits (including paid state), receipt, currency,
  // deletion — is compared.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bill &&
          id == other.id &&
          title == other.title &&
          subtotal == other.subtotal &&
          tipPercent == other.tipPercent &&
          total == other.total &&
          splitType == other.splitType &&
          createdBy == other.createdBy &&
          createdByName == other.createdByName &&
          groupId == other.groupId &&
          groupName == other.groupName &&
          _listEquals(participantIds, other.participantIds) &&
          _listEquals(splits, other.splits) &&
          _listEquals(paymentDebts, other.paymentDebts) &&
          _paymentMapsEqual(merchantPayments, other.merchantPayments) &&
          createdAt == other.createdAt &&
          receiptImageUrl == other.receiptImageUrl &&
          receiptLocalPath == other.receiptLocalPath &&
          currency == other.currency &&
          deleted == other.deleted;

  @override
  int get hashCode => Object.hashAll([
        id,
        title,
        subtotal,
        tipPercent,
        total,
        splitType,
        createdBy,
        createdByName,
        groupId,
        groupName,
        Object.hashAll(participantIds),
        Object.hashAll(splits),
        Object.hashAll(paymentDebts),
        Object.hashAll([
          for (final key in (merchantPayments.keys.toList()..sort()))
            Object.hash(key, merchantPayments[key]),
        ]),
        createdAt,
        receiptImageUrl,
        receiptLocalPath,
        currency,
        deleted,
      ]);

  /// Settlement helpers. A partially settled share (see
  /// [BillSplit.paidAmount]) counts as paid only once nothing remains.
  int get paidCount => hasPaymentLedger
      ? splits
          .where((share) => !paymentDebts
              .any((debt) => debt.debtorUid == share.uid && !debt.isSettled))
          .length
      : splits.where((s) => s.isFullyPaid).length;

  double get outstanding => hasPaymentLedger
      ? paymentDebts.fold(0.0, (a, d) => a + d.remainingAmount)
      : splits.fold(0.0, (a, s) => a + s.remainingAmount);

  bool get fullySettled => hasPaymentLedger
      ? paymentDebts.every((debt) => debt.isSettled)
      : splits.isNotEmpty && paidCount == splits.length;
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

  // Value equality (see AppUser): a balance is fully described by
  // its numbers, so a recompute that yields the same numbers is
  // not a change.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendBalance &&
          uid == other.uid &&
          displayName == other.displayName &&
          currency == other.currency &&
          net == other.net &&
          owesMe == other.owesMe &&
          iOweThem == other.iOweThem &&
          openBills == other.openBills;

  @override
  int get hashCode => Object.hash(
        uid,
        displayName,
        currency,
        net,
        owesMe,
        iOweThem,
        openBills,
      );
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

  // Value equality (see AppUser). `updatedAt` is excluded: it is
  // sync bookkeeping, never displayed. `read` is included: it
  // drives the unread badge.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          id == other.id &&
          toUid == other.toUid &&
          title == other.title &&
          body == other.body &&
          type == other.type &&
          billId == other.billId &&
          groupId == other.groupId &&
          read == other.read &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        toUid,
        title,
        body,
        type,
        billId,
        groupId,
        read,
        createdAt,
      );
}
