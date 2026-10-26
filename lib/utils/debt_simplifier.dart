import '../models/models.dart';

/// Debt simplification for a group's bills (Splitwise-style), computed
/// entirely on-device from the local bill cache — offline, zero
/// Firestore reads, and strictly per currency (a PKR debt never cancels
/// a USD one).
///
/// The plan is built from the actual unpaid shares:
/// 1. **Netting** — mutual debts between a pair (A owes B, B owes A)
///    cancel out up to the smaller side; no money needs to move.
/// 2. **Chaining** — payments are routed along debt chains, so
///    A→B→C collapses into a single A→C payment. Each routed payment
///    settles the same amount on every share along its chain.
/// 3. **Leftovers** — any debt that can't be chained is listed as a
///    direct payment to the person actually owed.
///
/// Every [SimplifiedTransfer] and [NettedDebts] carries
/// [SplitAllocation]s naming the exact bill shares it settles (a
/// transfer can settle several bills at once, and can settle part of
/// a share — see [BillSplit.paidAmount]). Recording a plan entry is
/// just a matter of marking those shares settled through the existing
/// mark-paid machinery, so per-bill accounting stays exact: applying
/// every entry in the plan settles every open share in the group.

/// The amount of one bill share that a plan entry settles.
class SplitAllocation {
  final String billId;
  final String splitUid;

  /// Amount of that share settled by this entry (> 0, ≤ the share's
  /// remaining amount at plan time).
  final double amount;

  const SplitAllocation({
    required this.billId,
    required this.splitUid,
    required this.amount,
  });
}

/// One payment that settles (part of) one or more bill shares:
/// [fromUid] pays [toUid] the given [amount].
class SimplifiedTransfer {
  final String fromUid;
  final String fromName;
  final String toUid;
  final String toName;
  final double amount;
  final String currency;
  final List<SplitAllocation> allocations;

  const SimplifiedTransfer({
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.toName,
    required this.amount,
    required this.currency,
    required this.allocations,
  });

  /// Bills this payment touches (for display and for checking the
  /// recorder is a participant — Firestore only lets participants
  /// update a bill).
  Set<String> get billIds => allocations.map((a) => a.billId).toSet();

  bool involves(String uid) => uid == fromUid || uid == toUid;
}

/// Mutual debts between two people that cancel out without any money
/// moving. [allocations] covers shares on both sides.
class NettedDebts {
  final String aUid;
  final String aName;
  final String bUid;
  final String bName;
  final double amount;
  final String currency;
  final List<SplitAllocation> allocations;

  const NettedDebts({
    required this.aUid,
    required this.aName,
    required this.bUid,
    required this.bName,
    required this.amount,
    required this.currency,
    required this.allocations,
  });

  Set<String> get billIds => allocations.map((a) => a.billId).toSet();

  bool involves(String uid) => uid == aUid || uid == bUid;
}

/// The settlement plan for one currency.
class CurrencySettlement {
  final String currency;
  final List<SimplifiedTransfer> transfers;
  final List<NettedDebts> nettings;

  /// Total still owed in this currency across the group's bills.
  final double openAmount;

  const CurrencySettlement({
    required this.currency,
    required this.transfers,
    required this.nettings,
    required this.openAmount,
  });

  bool get isSettled => transfers.isEmpty && nettings.isEmpty;
}

/// The full plan: one [CurrencySettlement] per currency that has any
/// open debt, sorted by currency code.
class GroupSettlementPlan {
  final List<CurrencySettlement> byCurrency;

  const GroupSettlementPlan(this.byCurrency);

  bool get isEmpty => byCurrency.every((c) => c.isSettled);

  int get transferCount => byCurrency.fold(0, (a, c) => a + c.transfers.length);
}

const _eps = 0.005;

double _round2(double v) => (v * 100).round() / 100;

/// Builds the settlement plan for [bills] (one group's bills, any
/// currencies). Pure function — safe to call in build methods.
GroupSettlementPlan simplifyGroupDebts(List<Bill> bills) {
  final currencies = bills.map((b) => b.currency).toSet().toList()..sort();
  final out = <CurrencySettlement>[];
  for (final code in currencies) {
    final inCurrency = bills.where((b) => b.currency == code).toList()
      // Oldest debts settle first, so allocations are fair and stable.
      ..sort((a, b) => (a.createdAt ?? DateTime(1970))
          .compareTo(b.createdAt ?? DateTime(1970)));
    final settlement = _simplifyCurrency(inCurrency, code);
    if (settlement != null) out.add(settlement);
  }
  return GroupSettlementPlan(out);
}

/// One not-yet-settled slice of a share, in FIFO order per debt edge.
class _Slice {
  _Slice(this.billId, this.splitUid, this.remaining);

  final String billId;
  final String splitUid;
  double remaining;
}

/// All open debt from one person to another (debtor owes creditor),
/// backed by slices of individual bill shares.
class _Edge {
  _Edge(this.debtor, this.creditor);

  final String debtor;
  final String creditor;
  final List<_Slice> slices = [];

  double get total => slices.fold(0.0, (a, s) => a + s.remaining);

  /// Takes [amount] off this edge, oldest shares first, and returns
  /// the allocations that cover it.
  List<SplitAllocation> consume(double amount) {
    var left = amount;
    final out = <SplitAllocation>[];
    for (final s in slices) {
      if (left <= _eps) break;
      if (s.remaining <= _eps) continue;
      final take = s.remaining < left ? s.remaining : left;
      s.remaining = _round2(s.remaining - take);
      left = _round2(left - take);
      out.add(SplitAllocation(
          billId: s.billId, splitUid: s.splitUid, amount: _round2(take)));
    }
    return out;
  }
}

CurrencySettlement? _simplifyCurrency(List<Bill> bills, String currency) {
  final names = <String, String>{};
  final edges = <String, _Edge>{};
  var openAmount = 0.0;

  _Edge edgeFor(String debtor, String creditor) =>
      edges.putIfAbsent('$debtor|$creditor', () => _Edge(debtor, creditor));

  for (final bill in bills) {
    names[bill.createdBy] = bill.createdByName;
    for (final s in bill.splits) {
      if (s.displayName.isNotEmpty) names[s.uid] = s.displayName;
      // The creator's own share is not a debt, and settled shares
      // are history.
      if (s.uid == bill.createdBy) continue;
      final remaining = s.remainingAmount;
      if (remaining <= _eps) continue;
      openAmount += remaining;
      edgeFor(s.uid, bill.createdBy)
          .slices
          .add(_Slice(bill.id, s.uid, remaining));
    }
  }
  if (openAmount <= _eps) return null;

  String nameOf(String uid) => names[uid] ?? 'Someone';

  // ---- Phase 1: net mutual debts pairwise. -------------------------
  final nettings = <NettedDebts>[];
  final pairKeys = edges.keys.toList();
  for (final key in pairKeys) {
    final e = edges[key]!;
    if (e.total <= _eps) continue;
    final reverse = edges['${e.creditor}|${e.debtor}'];
    if (reverse == null || reverse.total <= _eps) continue;
    // Net each unordered pair exactly once.
    if (e.debtor.compareTo(e.creditor) > 0) continue;
    final amount = _round2(e.total < reverse.total ? e.total : reverse.total);
    if (amount <= _eps) continue;
    final allocations = [...e.consume(amount), ...reverse.consume(amount)];
    nettings.add(NettedDebts(
      aUid: e.debtor,
      aName: nameOf(e.debtor),
      bUid: e.creditor,
      bName: nameOf(e.creditor),
      amount: amount,
      currency: currency,
      allocations: allocations,
    ));
  }

  // ---- Phase 2: route payments along debt chains. ------------------
  // Net position per person over the remaining edges:
  // positive = is owed money overall, negative = owes overall.
  final net = <String, double>{};
  for (final e in edges.values) {
    if (e.total <= _eps) continue;
    net[e.creditor] = (net[e.creditor] ?? 0) + e.total;
    net[e.debtor] = (net[e.debtor] ?? 0) - e.total;
  }

  final transfers = <String, SimplifiedTransfer>{};
  void addTransfer(String from, String to, double amount,
      List<SplitAllocation> allocations) {
    final key = '$from|$to';
    final existing = transfers[key];
    transfers[key] = SimplifiedTransfer(
      fromUid: from,
      fromName: nameOf(from),
      toUid: to,
      toName: nameOf(to),
      amount: _round2((existing?.amount ?? 0) + amount),
      currency: currency,
      allocations: [...?existing?.allocations, ...allocations],
    );
  }

  List<_Edge>? findPath(String from, Set<String> targets) {
    // BFS over open edges, widest edges first for stable results.
    final parent = <String, _Edge>{};
    final seen = {from};
    final queue = [from];
    while (queue.isNotEmpty) {
      final node = queue.removeAt(0);
      if (node != from && targets.contains(node)) {
        final path = <_Edge>[];
        var cur = node;
        while (cur != from) {
          final e = parent[cur]!;
          path.add(e);
          cur = e.debtor;
        }
        return path.reversed.toList();
      }
      final outgoing =
          edges.values.where((e) => e.debtor == node && e.total > _eps).toList()
            ..sort((a, b) {
              final byTotal = b.total.compareTo(a.total);
              return byTotal != 0
                  ? byTotal
                  : nameOf(a.creditor).compareTo(nameOf(b.creditor));
            });
      for (final e in outgoing) {
        if (seen.add(e.creditor)) {
          parent[e.creditor] = e;
          queue.add(e.creditor);
        }
      }
    }
    return null;
  }

  var guard = 0;
  while (guard++ < 10000) {
    final debtors = net.entries.where((e) => e.value < -_eps).toList()
      ..sort((a, b) {
        final byNet = a.value.compareTo(b.value); // most negative first
        return byNet != 0 ? byNet : nameOf(a.key).compareTo(nameOf(b.key));
      });
    if (debtors.isEmpty) break;
    final creditors = net.entries.where((e) => e.value > _eps).toList()
      ..sort((a, b) {
        final byNet = b.value.compareTo(a.value); // largest first
        return byNet != 0 ? byNet : nameOf(a.key).compareTo(nameOf(b.key));
      });
    if (creditors.isEmpty) break;
    final creditorUids = creditors.map((e) => e.key).toSet();

    // Take the biggest debtor and route as much as possible to a
    // reachable creditor.
    final debtor = debtors.first;
    final path = findPath(debtor.key, creditorUids);
    if (path == null) break; // leftovers are handled as direct debts
    final creditorUid = path.last.creditor;
    var amount = -debtor.value;
    if (net[creditorUid]! < amount) amount = net[creditorUid]!;
    for (final e in path) {
      if (e.total < amount) amount = e.total;
    }
    amount = _round2(amount);
    if (amount <= _eps) break;
    final allocations = <SplitAllocation>[];
    for (final e in path) {
      allocations.addAll(e.consume(amount));
    }
    addTransfer(debtor.key, creditorUid, amount, allocations);
    net[debtor.key] = _round2(debtor.value + amount);
    net[creditorUid] = _round2(net[creditorUid]! - amount);
  }

  // ---- Phase 3: leftover debts are paid directly. ------------------
  final leftovers = edges.values.where((e) => e.total > _eps).toList()
    ..sort((a, b) {
      final byTotal = b.total.compareTo(a.total);
      if (byTotal != 0) return byTotal;
      final byDebtor = nameOf(a.debtor).compareTo(nameOf(b.debtor));
      return byDebtor != 0
          ? byDebtor
          : nameOf(a.creditor).compareTo(nameOf(b.creditor));
    });
  for (final e in leftovers) {
    final amount = _round2(e.total);
    addTransfer(e.debtor, e.creditor, amount, e.consume(amount));
  }

  final transferList = transfers.values.toList()
    ..sort((a, b) {
      final byAmount = b.amount.compareTo(a.amount);
      if (byAmount != 0) return byAmount;
      final byFrom = a.fromName.compareTo(b.fromName);
      return byFrom != 0 ? byFrom : a.toName.compareTo(b.toName);
    });
  nettings.sort((a, b) => b.amount.compareTo(a.amount));

  return CurrencySettlement(
    currency: currency,
    transfers: transferList,
    nettings: nettings,
    openAmount: _round2(openAmount),
  );
}
