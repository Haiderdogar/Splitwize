import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/utils/bill_position.dart';

Bill _plain({
  String createdBy = 'me',
  List<BillSplit> splits = const [
    BillSplit(uid: 'me', displayName: 'Ali', amount: 100, paid: true),
    BillSplit(uid: 'f1', displayName: 'Hamza', amount: 100),
  ],
}) =>
    Bill(
      id: 'plain',
      title: 'Dinner',
      subtotal: 200,
      tipPercent: 0,
      total: 200,
      splitType: 'equal',
      createdBy: createdBy,
      createdByName: 'Someone',
      participantIds: const ['me', 'f1'],
      splits: splits,
    );

Bill _ledger(List<BillDebt> debts) => Bill(
      id: 'ledger',
      title: 'Shared dinner',
      subtotal: 100,
      tipPercent: 0,
      total: 100,
      splitType: 'custom',
      createdBy: 'f1',
      createdByName: 'Alex',
      participantIds: const ['me', 'f1', 'f2'],
      splits: const [
        BillSplit(uid: 'me', displayName: 'Ali', amount: 40),
        BillSplit(uid: 'f1', displayName: 'Alex', amount: 60),
      ],
      merchantPayments: const {'me': 100},
      paymentDebts: debts,
    );

BillDebt _debt(String debtor, String creditor, double amount,
        [double settled = 0]) =>
    BillDebt(
      id: '$debtor-$creditor',
      debtorUid: debtor,
      debtorName: debtor,
      creditorUid: creditor,
      creditorName: creditor,
      amount: amount,
      settledAmount: settled,
    );

void main() {
  group('bills without a payment ledger', () {
    test('the creator is owed the unpaid shares of everyone else', () {
      expect(billPosition(_plain(), 'me'), (owed: 100.0, owe: 0.0));
    });

    test('a participant owes the creator their own unpaid share', () {
      expect(billPosition(_plain(), 'f1'), (owed: 0.0, owe: 100.0));
    });

    test('a partly settled share only counts what is left', () {
      final bill = _plain(splits: const [
        BillSplit(uid: 'me', displayName: 'Ali', amount: 100, paid: true),
        BillSplit(
            uid: 'f1', displayName: 'Hamza', amount: 100, paidAmount: 30),
      ]);
      expect(billPosition(bill, 'me'), (owed: 70.0, owe: 0.0));
      expect(billPosition(bill, 'f1'), (owed: 0.0, owe: 70.0));
    });

    test('nothing is left once every share is paid', () {
      final bill = _plain(splits: const [
        BillSplit(uid: 'me', displayName: 'Ali', amount: 100, paid: true),
        BillSplit(uid: 'f1', displayName: 'Hamza', amount: 100, paid: true),
      ]);
      expect(billPosition(bill, 'me'), (owed: 0.0, owe: 0.0));
      expect(billPosition(bill, 'f1'), (owed: 0.0, owe: 0.0));
    });

    test('someone outside the bill has no position', () {
      expect(billPosition(_plain(), 'stranger'), (owed: 0.0, owe: 0.0));
    });
  });

  group('bills with a payment ledger', () {
    test('the creditor is owed what the debtor has not yet paid back', () {
      final bill = _ledger([_debt('f1', 'me', 60, 30)]);
      expect(billPosition(bill, 'me'), (owed: 30.0, owe: 0.0));
      expect(billPosition(bill, 'f1'), (owed: 0.0, owe: 30.0));
      expect(billPosition(bill, 'f2'), (owed: 0.0, owe: 0.0));
    });

    test('a settled debt leaves nothing owed either way', () {
      final bill = _ledger([_debt('f1', 'me', 60, 60)]);
      expect(billPosition(bill, 'me'), (owed: 0.0, owe: 0.0));
      expect(billPosition(bill, 'f1'), (owed: 0.0, owe: 0.0));
    });

    test('one bill can leave you both owed and owing', () {
      final bill = _ledger([
        _debt('f1', 'me', 25),
        _debt('me', 'f2', 10.5),
      ]);
      expect(billPosition(bill, 'me'), (owed: 25.0, owe: 10.5));
    });
  });
}
