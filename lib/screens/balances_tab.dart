import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../widgets/state_widgets.dart';
import 'bills_tab.dart' show formatMoney;

/// Running net balances per friend across all bills (unpaid shares only).
/// Positive net = friend owes me; negative net = I owe the friend.
class BalancesTab extends StatelessWidget {
  const BalancesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balances')),
      // Only this subtree reacts to balance state.
      body: Consumer(
        builder: (context, ref, _) {
          // Gate on the bills stream so first load shows a shimmer
          // (and failures a retry) instead of a premature "all settled".
          final billsAsync = ref.watch(myBillsProvider);
          if (billsAsync.isLoading) return const ShimmerList();
          if (billsAsync.hasError) {
            return LoadError(
              message: 'Could not load your balances.',
              onRetry: () {
                ref.invalidate(appRepositoryProvider);
                ref.invalidate(myBillsProvider);
              },
            );
          }
          final balances = ref.watch(balancesProvider);
          final myUid = ref.watch(currentUidProvider) ?? '';
          // Totals are kept per currency — never summed across them.
          final byCurrency = <String, ({double owed, double owe})>{};
          for (final b in balances) {
            final e = byCurrency[b.currency] ?? (owed: 0.0, owe: 0.0);
            byCurrency[b.currency] = (
              owed: e.owed + (b.net > 0 ? b.net : 0),
              owe: e.owe + (b.net < 0 ? b.net.abs() : 0),
            );
          }

          if (balances.isEmpty) return const _AllSettled();

          // Lazy list: only the visible balance cards are built.
          // Index 0 is the summary card, the rest are friends.
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: balances.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SummaryCard(byCurrency: byCurrency),
                );
              }
              final b = balances[i - 1];
              return _BalanceCard(
                balance: b,
                onSettleUp: () => _settleUp(context, ref, myUid, b),
                onRemind: () => _remind(context, ref, myUid, b),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _settleUp(BuildContext context, WidgetRef ref, String myUid,
      FriendBalance b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settle up?'),
        content: Text(
          'Mark your ${b.openBills} outstanding share${b.openBills == 1 ? '' : 's'} '
          '(${formatMoney(b.iOweThem, b.currency)}) with ${b.displayName} as paid?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Settle up'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final repo = await ref.read(appRepositoryProvider.future);
      final count = await repo.settleUpWithFriend(b.uid, currency: b.currency);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Settled $count share${count == 1 ? '' : 's'} with ${b.displayName}.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not settle up: $e')),
        );
      }
    }
  }

  Future<void> _remind(BuildContext context, WidgetRef ref, String myUid,
      FriendBalance b) async {
    try {
      final repo = await ref.read(appRepositoryProvider.future);
      final me = await repo.getUser(myUid);
      await repo.sendNotification(
        toUid: b.uid,
        title: 'Payment reminder',
        body:
            '${me?.displayName ?? 'A friend'} reminds you: you owe ${formatMoney(b.owesMe, b.currency)} across ${b.openBills} bill${b.openBills == 1 ? '' : 's'}.',
        type: 'reminder',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder sent to ${b.displayName}.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send reminder: $e')),
        );
      }
    }
  }
}

class _AllSettled extends StatelessWidget {
  const _AllSettled();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text(
              'All settled up 🎉\nNo outstanding balances with anyone.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.byCurrency});

  /// Currency code → (owed to me, I owe) totals in that currency.
  final Map<String, ({double owed, double owe})> byCurrency;

  @override
  Widget build(BuildContext context) {
    final codes = byCurrency.keys.toList()..sort();
    final multi = codes.length > 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            for (final code in codes) ...[
              if (multi)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    code,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: _Summary(
                        label: 'You are owed',
                        amount: byCurrency[code]!.owed,
                        currency: code,
                        color: Colors.green),
                  ),
                  Expanded(
                    child: _Summary(
                        label: 'You owe',
                        amount: byCurrency[code]!.owe,
                        currency: code,
                        color: Colors.orange),
                  ),
                ],
              ),
              if (code != codes.last) const Divider(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(
      {required this.label,
      required this.amount,
      required this.currency,
      required this.color});

  final String label;
  final double amount;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        // Scale the amount down (never truncate money) if a very
        // large figure meets a narrow screen / big text setting.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            formatMoney(amount, currency),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.onSettleUp,
    required this.onRemind,
  });

  final FriendBalance balance;
  final VoidCallback onSettleUp;
  final VoidCallback onRemind;

  bool get _iOwe => balance.net < 0;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(child: Text(balance.initials)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    balance.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _iOwe
                        ? 'You owe ${formatMoney(balance.net.abs(), balance.currency)}'
                        : '${balance.displayName.split(' ').first} owes you ${formatMoney(balance.net, balance.currency)}',
                    style: TextStyle(
                      color: _iOwe ? Colors.orange : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Across ${balance.openBills} open bill${balance.openBills == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (_iOwe)
              FilledButton(
                onPressed: onSettleUp,
                child: const Text('Settle up'),
              )
            else
              TextButton(
                onPressed: onRemind,
                child: const Text('Remind'),
              ),
          ],
        ),
      ),
    );
  }
}
