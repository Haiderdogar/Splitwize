import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_notification_button.dart';
import '../widgets/money_text.dart';
import '../widgets/state_widgets.dart';
import '../widgets/studio_ui.dart';
import 'bills_tab.dart' show formatMoney;

class BalancesTab extends StatelessWidget {
  const BalancesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const SplitwizeMenuButton(),
        title: const Text('Balances'),
        actions: const [AppNotificationButton(), SizedBox(width: 5)],
      ),
      body: Consumer(builder: (context, ref, _) {
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
        final uid = ref.watch(currentUidProvider) ?? '';
        final byCurrency = <String, ({double owed, double owe})>{};
        for (final balance in balances) {
          final previous = byCurrency[balance.currency] ??
              (owed: 0.0, owe: 0.0);
          byCurrency[balance.currency] = (
            owed: previous.owed + balance.owesMe,
            owe: previous.owe + balance.iOweThem,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 3, 16, 24),
          itemCount: balances.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return _BalanceOverview(
                byCurrency: byCurrency,
                hasBalances: balances.isNotEmpty,
              );
            }
            final balance = balances[i - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _BalanceTile(
                balance: balance,
                onSettleUp: () => _settleUp(context, ref, uid, balance),
                onRemind: () => _remind(context, ref, uid, balance),
              ),
            );
          },
        );
      }),
    );
  }

  Future<void> _settleUp(BuildContext context, WidgetRef ref, String myUid,
      FriendBalance b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record repayment?'),
        content: Text(
          'You owe ${b.displayName} ${formatMoney(b.iOweThem, b.currency)}. '
          'They owe you ${formatMoney(b.owesMe, b.currency)}. '
          'The net balance is ${formatMoney(b.net.abs(), b.currency)}.\n\n'
          'This will mark your full ${formatMoney(b.iOweThem, b.currency)} '
          'outstanding debt to this person as paid, not just the net amount. '
          'No money is transferred by Splitwize.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Mark my debt paid'),
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
            '${me?.displayName ?? 'A Splitwize member'} reminds you: you owe ${formatMoney(b.owesMe, b.currency)} across ${b.openBills} bill${b.openBills == 1 ? '' : 's'}.',
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

class _BalanceOverview extends StatelessWidget {
  const _BalanceOverview({
    required this.byCurrency, required this.hasBalances,
  });
  final Map<String, ({double owed, double owe})> byCurrency;
  final bool hasBalances;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final codes = byCurrency.keys.toList()..sort();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!hasBalances)
        const InlineEmpty(
          icon: Icons.check_circle_outline_rounded,
          title: 'Everything is settled',
          message: 'You do not have any outstanding balances.',
        )
      else ...[
        const SectionHeading('Your totals',
          subtitle: 'Each currency is calculated separately.'),
        for (final code in codes)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: SoftPanel(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(code, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _AmountSummary(
                    label: 'Owed to you',
                    amount: byCurrency[code]!.owed,
                    currency: code, color: scheme.owed)),
                  const SizedBox(width: 12),
                  Container(height: 43, width: 1, color: scheme.outlineVariant),
                  const SizedBox(width: 12),
                  Expanded(child: _AmountSummary(
                    label: 'You owe',
                    amount: byCurrency[code]!.owe,
                    currency: code, color: scheme.owe)),
                ]),
              ],
            )),
          ),
        const SectionHeading('People',
          subtitle: 'Review debts, record repayments, or send reminders.'),
      ],
    ]);
  }
}

class _AmountSummary extends StatelessWidget {
  const _AmountSummary({
    required this.label, required this.amount,
    required this.currency, required this.color,
  });
  final String label;
  final double amount;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 5),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
        child: MoneyText(amount, currencyCode: currency, color: color,
          style: Theme.of(context).textTheme.titleLarge)),
    ]);
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.balance,
    required this.onSettleUp,
    required this.onRemind,
  });
  final FriendBalance balance;
  final VoidCallback onSettleUp;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final owe = balance.net < -0.005;
    final owed = balance.net > 0.005;
    return SoftPanel(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          PersonMark(initials: balance.initials),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(balance.displayName, maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium),
              Text('${balance.openBills} open ${balance.openBills == 1 ? 'bill' : 'bills'}',
                  style: Theme.of(context).textTheme.bodySmall),
            ])),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(owe ? 'Net: you owe' : owed ? 'Net: owes you' : 'Net zero',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant)),
            MoneyText(balance.net.abs(), currencyCode: balance.currency,
                color: owe ? scheme.owe : owed ? scheme.owed : scheme.onSurface,
                style: Theme.of(context).textTheme.titleMedium),
          ]),
        ]),
        const SizedBox(height: 10),
        Text('You owe ${formatMoney(balance.iOweThem, balance.currency)} · '
          'Owes you ${formatMoney(balance.owesMe, balance.currency)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (balance.iOweThem > 0.005)
            FilledButton.icon(
              onPressed: onSettleUp,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Record repayment')),
          if (balance.owesMe > 0.005)
            OutlinedButton.icon(
              onPressed: onRemind,
              icon: const Icon(Icons.notifications_none_rounded),
              label: const Text('Remind')),
        ]),
      ]),
    );
  }
}
