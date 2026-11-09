import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/utils/debt_simplifier.dart';
import 'package:splitwize/utils/payment_ledger.dart';

List<BillSplit> shares(double amount) => [
  BillSplit(uid: 'a', displayName: 'A', amount: amount),
  BillSplit(uid: 'b', displayName: 'B', amount: amount),
  BillSplit(uid: 'c', displayName: 'C', amount: amount),
];

Bill billWithPayments(List<BillSplit> parts, Map<String, double> paid) {
  final debts = buildPaymentDebts(splits: parts, merchantPayments: paid);
  final total = parts.fold<double>(0, (sum, s) => sum + s.amount);
  return Bill(
    id: 'payment-test',
    title: 'Dinner',
    subtotal: total,
    tipPercent: 0,
    total: total,
    splitType: 'equal',
    createdBy: 'c', // The recorder did NOT necessarily pay anything.
    createdByName: 'C',
    participantIds: parts.map((s) => s.uid).toList(),
    splits: parts,
    merchantPayments: paid,
    paymentDebts: debts,
    currency: 'PKR',
    groupId: 'g1',
  );
}

void main() {
  group('merchant payments and settlement obligations', () {
    test('one payer is reimbursed by the other two', () {
      final bill = billWithPayments(shares(300), {'b': 900});
      expect(bill.createdBy, 'c');
      expect(bill.merchantPayments, {'b': 900});
      expect(bill.paymentDebts, hasLength(2));
      final debts = {for (final d in bill.paymentDebts) d.debtorUid: d};
      expect(debts['a']!.creditorUid, 'b');
      expect(debts['a']!.amount, 300);
      expect(debts['c']!.creditorUid, 'b');
      expect(debts['c']!.amount, 300);
      expect(bill.outstanding, 600);
    });

    test('200 and 700 out of 900 give 100 and 300 reimbursements', () {
      final bill = billWithPayments(shares(300), {'a': 200, 'b': 700});
      final debts = {for (final d in bill.paymentDebts) d.debtorUid: d};
      expect(debts['a']!.creditorUid, 'b');
      expect(debts['a']!.amount, 100);
      expect(debts['c']!.creditorUid, 'b');
      expect(debts['c']!.amount, 300);
      expect(bill.outstanding, 400);

      final roundtrip = Bill.fromMap(bill.id, bill.toMap());
      expect(roundtrip.merchantPayments, {'a': 200, 'b': 700});
      expect(roundtrip.paymentDebts, bill.paymentDebts);
      expect(roundtrip, bill);

      final plan = simplifyGroupDebts([bill]);
      expect(plan.byCurrency.single.transfers, hasLength(2));
      expect(plan.byCurrency.single.transfers.map((t) => t.amount),
          containsAll([100.0, 300.0]));
      expect(plan.byCurrency.single.transfers
          .expand((t) => t.allocations)
          .every((a) => a.debtId != null), isTrue);
    });

    test('9000 bill with 2000 + 7000 paid nets 1000 and 3000', () {
      final bill = billWithPayments(shares(3000), {'a': 2000, 'b': 7000});
      expect(bill.paymentDebts.map((d) => d.amount),
          containsAll([1000.0, 3000.0]));
    });

    test('multiple creditors can each receive a fair reimbursement', () {
      final bill = billWithPayments(shares(100), {'a': 150, 'b': 150});
      final debts = {for (final d in bill.paymentDebts) d.creditorUid: d};
      expect(debts['a']!.debtorUid, 'c');
      expect(debts['a']!.amount, 50);
      expect(debts['b']!.debtorUid, 'c');
      expect(debts['b']!.amount, 50);
    });

    test('no reimbursement when everyone pays exactly their share', () {
      final bill = billWithPayments(
          shares(100), {'a': 100, 'b': 100, 'c': 100});
      expect(bill.paymentDebts, isEmpty);
      expect(bill.outstanding, 0);
      expect(bill.fullySettled, isTrue);
    });

    test('fractional pennies are preserved as whole cents', () {
      final bill = billWithPayments([
        const BillSplit(uid: 'a', displayName: 'A', amount: 33.34),
        const BillSplit(uid: 'b', displayName: 'B', amount: 33.33),
        const BillSplit(uid: 'c', displayName: 'C', amount: 33.33),
      ], {'a': 100});
      expect(bill.paymentDebts.map((d) => (d.amount * 100).round()),
          containsAll([3333, 3333]));
      expect(bill.outstanding, 66.66);
    });

    test('reject partial payments or a payer outside the participants', () {
      expect(
        () => buildPaymentDebts(splits: shares(300),
            merchantPayments: {'a': 200, 'b': 600}),
        throwsArgumentError,
      );
      expect(
        () => buildPaymentDebts(splits: shares(300),
            merchantPayments: {'a': 900, 'outsider': 0}),
        throwsArgumentError,
      );
    });

    test('old bills without a payment ledger remain compatible', () {
      const old = Bill(
        id: 'old',
        title: 'Legacy dinner',
        subtotal: 200,
        tipPercent: 0,
        total: 200,
        splitType: 'equal',
        createdBy: 'a',
        createdByName: 'A',
        participantIds: ['a', 'b'],
        splits: [
          BillSplit(uid: 'a', displayName: 'A', amount: 100),
          BillSplit(uid: 'b', displayName: 'B', amount: 100),
        ],
      );
      final read = Bill.fromMap(old.id, old.toMap());
      expect(read.hasPaymentLedger, isFalse);
      expect(read.outstanding, 200);
    });
  });
}
