import '../models/models.dart';

/// What one bill still means for one person: money still coming to them
/// ([owed]) and money they still have to pay ([owe]), both in the bill's own
/// currency. Both are zero once nothing is left to settle, or when the person
/// is not part of the money flow.
typedef BillPosition = ({double owed, double owe});

/// Follows exactly the rules of `AppRepository.computeBalances`, bill by bill,
/// so the amounts on the expense tiles add up to the Home totals.
BillPosition billPosition(Bill bill, String uid) {
  var owed = 0.0;
  var owe = 0.0;
  if (bill.hasPaymentLedger) {
    for (final debt in bill.paymentDebts) {
      final remaining = debt.remainingAmount;
      if (remaining < 0.005) continue;
      if (debt.creditorUid == uid) owed += remaining;
      if (debt.debtorUid == uid) owe += remaining;
    }
  } else {
    final iCreated = bill.createdBy == uid;
    for (final split in bill.splits) {
      final remaining = split.remainingAmount;
      if (remaining == 0) continue;
      if (iCreated) {
        if (split.uid != uid) owed += remaining;
      } else if (split.uid == uid) {
        owe += remaining;
      }
    }
  }
  return (owed: _wholeCents(owed), owe: _wholeCents(owe));
}

double _wholeCents(double value) => (value * 100).round() / 100;
