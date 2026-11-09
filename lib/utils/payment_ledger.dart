import '../models/models.dart';

/// Converts who paid the merchant and who consumed the expense into
/// exact debt obligations. Integer cents are used throughout.
List<BillDebt> buildPaymentDebts({
  required List<BillSplit> splits,
  required Map<String, double> merchantPayments,
}) {
  if (splits.length < 2) {
    throw ArgumentError('Choose at least two expense participants.');
  }
  final names = {for (final share in splits) share.uid: share.displayName};
  if (names.length != splits.length) {
    throw ArgumentError('Duplicate expense participant.');
  }
  int toCents(double amount) {
    if (!amount.isFinite || amount < 0 || amount > 90071992547409) {
      throw ArgumentError('Invalid expense payment amount.');
    }
    return (amount * 100).round();
  }
  final shares = {
    for (final split in splits) split.uid: toCents(split.amount),
  };
  final totalCents = shares.values.fold<int>(0, (sum, x) => sum + x);
  final paidCents = <String, int>{};
  for (final entry in merchantPayments.entries) {
    if (!shares.containsKey(entry.key)) {
      throw ArgumentError('Payer must be a selected participant.');
    }
    paidCents[entry.key] = toCents(entry.value);
  }
  if (paidCents.isEmpty ||
      paidCents.values.fold<int>(0, (a, b) => a + b) != totalCents) {
    throw ArgumentError('Payments must add up to the bill total.');
  }

  final creditors = <String, int>{};
  final debtors = <String, int>{};
  for (final uid in shares.keys) {
    final net = (paidCents[uid] ?? 0) - shares[uid]!;
    if (net > 0) creditors[uid] = net;
    if (net < 0) debtors[uid] = -net;
  }
  // Deterministic: largest contributions/shortfalls first, then uid.
  int order(MapEntry<String, int> a, MapEntry<String, int> b) {
    final magnitude = b.value.compareTo(a.value);
    return magnitude != 0 ? magnitude : a.key.compareTo(b.key);
  }
  final receivers = creditors.entries.toList()..sort(order);
  final senders = debtors.entries.toList()..sort(order);
  final result = <BillDebt>[];
  var i = 0, j = 0;
  while (i < senders.length && j < receivers.length) {
    final debtor = senders[i];
    final creditor = receivers[j];
    final amount = debtor.value < creditor.value ? debtor.value : creditor.value;
    if (amount <= 0) throw StateError('Zero amount in payment ledger.');
    result.add(BillDebt(
      id: '${debtor.key}|${creditor.key}',
      debtorUid: debtor.key,
      debtorName: names[debtor.key]!,
      creditorUid: creditor.key,
      creditorName: names[creditor.key]!,
      amount: amount / 100,
    ));
    senders[i] = MapEntry(debtor.key, debtor.value - amount);
    receivers[j] = MapEntry(creditor.key, creditor.value - amount);
    if (senders[i].value == 0) i++;
    if (receivers[j].value == 0) j++;
  }
  if (i != senders.length || j != receivers.length) {
    throw StateError('Unbalanced payment ledger.');
  }
  return result;
}
