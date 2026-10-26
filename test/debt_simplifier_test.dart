// Unit tests for the group debt simplifier: pure computation over
// Bill objects, no database or Firebase involved. The key invariants
// checked throughout: every open share is covered exactly once by
// the plan's allocations, and applying the plan zeroes everyone's
// net position in each currency.
import 'package:flutter_test/flutter_test.dart';

import 'package:splitwize/models/models.dart';
import 'package:splitwize/utils/debt_simplifier.dart';

const names = {'a': 'Ayesha', 'b': 'Bilal', 'c': 'Chen', 'd': 'Dana'};

int _seq = 0;

/// Builds a bill created by [creator] whose shares are [shares]
/// (uid → amount). The creator's own share can be included to prove
/// it is ignored. [paidUids] are fully paid; [paidAmounts] are
/// partially settled amounts.
Bill mkBill(
  String creator,
  Map<String, double> shares, {
  String currency = 'PKR',
  Set<String> paidUids = const {},
  Map<String, double> paidAmounts = const {},
}) {
  _seq++;
  return Bill(
    id: 'bill$_seq',
    title: 'Bill $_seq',
    subtotal: shares.values.fold(0.0, (a, b) => a + b),
    tipPercent: 0,
    total: shares.values.fold(0.0, (a, b) => a + b),
    splitType: 'equal',
    createdBy: creator,
    createdByName: names[creator] ?? creator,
    groupId: 'g1',
    participantIds: [creator, ...shares.keys],
    splits: [
      for (final e in shares.entries)
        BillSplit(
          uid: e.key,
          displayName: names[e.key] ?? e.key,
          amount: e.value,
          paid: paidUids.contains(e.key),
          paidAt: paidUids.contains(e.key) ? DateTime(2026, 1, 1) : null,
          paidAmount: paidAmounts[e.key] ?? 0,
        ),
    ],
    createdAt: DateTime(2026, 1, _seq),
    currency: currency,
  );
}

/// Net position per person: positive = owed money overall.
Map<String, double> netsOf(List<Bill> bills) {
  final net = <String, double>{};
  for (final bill in bills) {
    for (final s in bill.splits) {
      if (s.uid == bill.createdBy) continue;
      final r = s.remainingAmount;
      if (r == 0) continue;
      net[bill.createdBy] = (net[bill.createdBy] ?? 0) + r;
      net[s.uid] = (net[s.uid] ?? 0) - r;
    }
  }
  return net;
}

/// Total allocated per bill share ('billId|uid') across the whole plan.
Map<String, double> coverageOf(GroupSettlementPlan plan) {
  final cov = <String, double>{};
  void add(List<SplitAllocation> allocs) {
    for (final a in allocs) {
      final key = '${a.billId}|${a.splitUid}';
      cov[key] = (cov[key] ?? 0) + a.amount;
    }
  }

  for (final c in plan.byCurrency) {
    for (final t in c.transfers) {
      add(t.allocations);
    }
    for (final n in c.nettings) {
      add(n.allocations);
    }
  }
  return cov;
}

/// Asserts the plan covers every open share exactly and settles
/// everyone's net position to zero.
void expectPlanExact(List<Bill> bills, GroupSettlementPlan plan) {
  final cov = coverageOf(plan);
  for (final bill in bills) {
    for (final s in bill.splits) {
      final key = '${bill.id}|${s.uid}';
      if (s.uid == bill.createdBy || s.remainingAmount == 0) {
        expect(cov[key] ?? 0, 0,
            reason: '$key must not be allocated (not an open debt)');
      } else {
        expect(cov[key], s.remainingAmount,
            reason: '$key must be covered exactly once');
      }
    }
  }
  final net = netsOf(bills);
  for (final c in plan.byCurrency) {
    for (final t in c.transfers) {
      net[t.fromUid] = (net[t.fromUid] ?? 0) + t.amount;
      net[t.toUid] = (net[t.toUid] ?? 0) - t.amount;
    }
  }
  for (final e in net.entries) {
    expect(e.value.abs(), lessThan(0.01),
        reason: '${e.key} should end settled, net is ${e.value}');
  }
}

void main() {
  group('simplifyGroupDebts', () {
    test('direct debt becomes a single transfer', () {
      final bills = [
        mkBill('b', {'a': 100})
      ];
      final plan = simplifyGroupDebts(bills);
      expect(plan.byCurrency, hasLength(1));
      final c = plan.byCurrency.single;
      expect(c.currency, 'PKR');
      expect(c.openAmount, 100);
      expect(c.nettings, isEmpty);
      expect(c.transfers, hasLength(1));
      final t = c.transfers.single;
      expect(t.fromUid, 'a');
      expect(t.toUid, 'b');
      expect(t.amount, 100);
      expect(t.allocations.single.billId, bills.single.id);
      expect(t.allocations.single.splitUid, 'a');
      expectPlanExact(bills, plan);
    });

    test('a chain A→B→C collapses into one A→C payment', () {
      final bills = [
        mkBill('b', {'a': 100}), // A owes Bilal 100
        mkBill('c', {'b': 100}), // Bilal owes Chen 100
      ];
      final plan = simplifyGroupDebts(bills);
      final c = plan.byCurrency.single;
      expect(c.transfers, hasLength(1));
      final t = c.transfers.single;
      expect(t.fromUid, 'a');
      expect(t.toUid, 'c');
      expect(t.amount, 100);
      // The one payment settles both underlying shares.
      expect(t.allocations, hasLength(2));
      expectPlanExact(bills, plan);
    });

    test('a chain with uneven amounts splits into routed + direct', () {
      final bills = [
        mkBill('b', {'a': 100}), // A owes Bilal 100
        mkBill('c', {'b': 60}), // Bilal owes Chen 60
      ];
      final plan = simplifyGroupDebts(bills);
      final c = plan.byCurrency.single;
      expect(c.transfers, hasLength(2));
      final routed = c.transfers.firstWhere((t) => t.toUid == 'c');
      expect(routed.fromUid, 'a');
      expect(routed.amount, 60);
      final direct = c.transfers.firstWhere((t) => t.toUid == 'b');
      expect(direct.fromUid, 'a');
      expect(direct.amount, 40);
      // A's 100 share is settled partly by each payment: 60 + 40.
      final aAllocs = c.transfers
          .expand((t) => t.allocations)
          .where((x) => x.billId == bills[0].id)
          .fold(0.0, (sum, x) => sum + x.amount);
      expect(aAllocs, 100);
      expectPlanExact(bills, plan);
    });

    test('equal mutual debts net out with no transfer', () {
      final bills = [
        mkBill('b', {'a': 50}),
        mkBill('a', {'b': 50}),
      ];
      final plan = simplifyGroupDebts(bills);
      final c = plan.byCurrency.single;
      expect(c.transfers, isEmpty);
      expect(c.nettings, hasLength(1));
      expect(c.nettings.single.amount, 50);
      expect(c.nettings.single.allocations, hasLength(2));
      expectPlanExact(bills, plan);
    });

    test('unequal mutual debts net the overlap, transfer the rest', () {
      final bills = [
        mkBill('b', {'a': 100}),
        mkBill('a', {'b': 60}),
      ];
      final plan = simplifyGroupDebts(bills);
      final c = plan.byCurrency.single;
      expect(c.nettings.single.amount, 60);
      expect(c.transfers, hasLength(1));
      expect(c.transfers.single.fromUid, 'a');
      expect(c.transfers.single.toUid, 'b');
      expect(c.transfers.single.amount, 40);
      expectPlanExact(bills, plan);
    });

    test('currencies are never mixed', () {
      final bills = [
        mkBill('b', {'a': 100}), // PKR chain…
        mkBill('c', {'b': 100}),
        mkBill('b', {'d': 25}, currency: 'USD'), // …plus a USD debt
      ];
      final plan = simplifyGroupDebts(bills);
      expect(plan.byCurrency, hasLength(2));
      final pkr = plan.byCurrency.firstWhere((c) => c.currency == 'PKR');
      expect(pkr.transfers.single.fromUid, 'a');
      expect(pkr.transfers.single.toUid, 'c');
      final usd = plan.byCurrency.firstWhere((c) => c.currency == 'USD');
      expect(usd.transfers.single.fromUid, 'd');
      expect(usd.transfers.single.toUid, 'b');
      expect(usd.transfers.single.amount, 25);
      expectPlanExact(bills, plan);
    });

    test(
        'paid shares and the creator\'s own share are ignored; '
        'partial shares count only their remainder', () {
      final bills = [
        mkBill('b', {'a': 100, 'c': 50, 'b': 999},
            paidUids: {'c'}, paidAmounts: {'a': 30}),
      ];
      final plan = simplifyGroupDebts(bills);
      final c = plan.byCurrency.single;
      expect(c.openAmount, 70);
      expect(c.transfers, hasLength(1));
      expect(c.transfers.single.amount, 70);
      expectPlanExact(bills, plan);
    });

    test(
        'a tangled 4-person group settles exactly with fewer '
        'payments than open shares', () {
      final bills = [
        mkBill('a', {'b': 30, 'c': 30, 'd': 30}),
        mkBill('b', {'a': 50, 'c': 20}),
        mkBill('c', {'a': 10, 'd': 40}),
        mkBill('d', {'b': 25}),
      ];
      final openShares = bills
          .expand((b) => b.splits)
          .where((s) => s.remainingAmount > 0)
          .length;
      final plan = simplifyGroupDebts(bills);
      expect(plan.transferCount, lessThan(openShares));
      expectPlanExact(bills, plan);
    });

    test('no open debts means an empty plan', () {
      expect(simplifyGroupDebts(const []).isEmpty, isTrue);
      final bills = [
        mkBill('b', {'a': 100}, paidUids: {'a'}),
      ];
      expect(simplifyGroupDebts(bills).isEmpty, isTrue);
      expect(simplifyGroupDebts(bills).byCurrency, isEmpty);
    });
  });
}
