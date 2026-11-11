import '../models/models.dart';

/// All bills shared by two people, including settled bills and all currencies.
/// The recorder can be involved without having a share on the bill.
List<Bill> billsWithPerson(List<Bill> bills, String myUid, String personUid) {
  if (myUid.isEmpty || personUid.isEmpty || myUid == personUid) return [];

  bool involves(Bill bill, String uid) =>
      bill.createdBy == uid ||
      bill.participantIds.contains(uid) ||
      bill.splits.any((split) => split.uid == uid) ||
      bill.merchantPayments.containsKey(uid) ||
      bill.paymentDebts.any(
        (debt) => debt.debtorUid == uid || debt.creditorUid == uid,
      );

  final shared = bills
      .where((bill) =>
          !bill.deleted && involves(bill, myUid) && involves(bill, personUid))
      .toList();
  shared.sort((a, b) =>
      (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970)));
  return shared;
}
