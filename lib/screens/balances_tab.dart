import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/current_user_identity.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_notification_button.dart';
import '../widgets/money_text.dart';
import '../widgets/state_widgets.dart';
import '../widgets/studio_ui.dart';
import 'bills_tab.dart' show formatMoney;
import 'bill_detail_screen.dart';

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
        final myUid = ref.watch(currentUidProvider) ?? '';
        final byCurrency = <String, ({double owed, double owe})>{};
        final peopleByCurrency = <String, List<FriendBalance>>{};
        for (final balance in balances) {
          final previous = byCurrency[balance.currency] ??
              (owed: 0.0, owe: 0.0);
          // Totals show the actual open obligations in each direction.
          // A net-zero balance can still have outstanding debts both ways.
          byCurrency[balance.currency] = (
            owed: previous.owed + balance.owesMe,
            owe: previous.owe + balance.iOweThem,
          );
          (peopleByCurrency[balance.currency] ??= []).add(balance);
        }
        final currencies = peopleByCurrency.keys.toList()..sort();
        final entries = <Object>[
          for (final currency in currencies) ...[
            currency,
            ...peopleByCurrency[currency]!,
          ],
        ];
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 3, 16, 24),
          itemCount: entries.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return _BalanceOverview(
                byCurrency: byCurrency,
                hasBalances: balances.isNotEmpty,
              );
            }
            final item = entries[i - 1];
            if (item is String) {
              return SectionHeading('$item balances',
                subtitle: 'Tap a person to review bills and payments.');
            }
            final balance = item as FriendBalance;
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _BalanceTile(
                balance: balance,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _FriendBalanceDetails(
                    balance: balance,
                    myUid: myUid,
                    onRecordPayment: (ctx) =>
                        _recordPayment(ctx, ref, balance),
                    onRemind: (ctx) =>
                        _remind(ctx, ref, myUid, balance),
                  ),
                )),
              ),
            );
          },
        );
      }),
    );
  }

  /// Records the exact gross amount the user owes. This is not a bank
  /// transfer and is never silently substituted with the net balance.
  Future<bool> _recordPayment(
      BuildContext context, WidgetRef ref, FriendBalance balance) async {
    if (balance.iOweThem <= 0) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record payment?'),
        content: Text(
          'Mark ${formatMoney(balance.iOweThem, balance.currency)} '
          'that you owe ${balance.displayName} as paid? '
          'This only records a settlement in Splitwize; '
          'it does not transfer money.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Mark as paid'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return false;
    try {
      final repo = await ref.read(appRepositoryProvider.future);
      final count = await repo.settleUpWithFriend(
          balance.uid, currency: balance.currency);
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Recorded $count outstanding '
          'payment${count == 1 ? '' : 's'} as settled.'),
      ));
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not record payment: $e')),
        );
      }
      return false;
    }
  }

  Future<void> _remind(BuildContext context, WidgetRef ref, String myUid,
      FriendBalance balance) async {
    if (balance.owesMe <= 0) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send payment reminder?'),
        content: Text(
          'Remind ${balance.displayName} about '
          '${formatMoney(balance.owesMe, balance.currency)} owed to you?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Send reminder'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      final google = ref.read(authStateChangesProvider).value;
      final identity = resolveCurrentUserIdentity(
        cached: ref.read(currentAppUserProvider).value,
        googleName: google?.displayName,
        googleEmail: google?.email,
      );
      final repo = await ref.read(appRepositoryProvider.future);
      await repo.sendNotification(
        toUid: balance.uid,
        title: 'Payment reminder',
        body: '${identity.name} reminds you: you owe '
            '${formatMoney(balance.owesMe, balance.currency)} across '
            '${balance.openBills} bill${balance.openBills == 1 ? '' : 's'}.',
        type: 'reminder',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder sent to ${balance.displayName}.')),
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
        const SizedBox(height: 5),
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

/// Compact, tappable balance row; actions live in the detailed view.
class _BalanceTile extends StatelessWidget {
  const _BalanceTile({required this.balance, required this.onTap});

  final FriendBalance balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final netOwe = balance.net < -0.005;
    final netZero = balance.net.abs() < 0.005;
    final description = netZero
        ? 'Mutual debts outstanding'
        : netOwe ? 'Net: you owe' : 'Net: owes you';
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(children: [
            PersonMark(initials: balance.initials),
            const SizedBox(width: 11),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(balance.displayName, maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium),
                Text('${balance.openBills} open '
                    'bill${balance.openBills == 1 ? '' : 's'} · $description',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant)),
                if (balance.iOweThem > 0 && balance.owesMe > 0)
                  Text('You owe ${formatMoney(balance.iOweThem, balance.currency)}'
                      ' · Owed ${formatMoney(balance.owesMe, balance.currency)}',
                    maxLines: 2,
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            )),
            const SizedBox(width: 7),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: MoneyText(balance.net.abs(),
                  currencyCode: balance.currency,
                  color: netZero ? scheme.onSurfaceVariant :
                      (netOwe ? scheme.owe : scheme.owed),
                  style: Theme.of(context).textTheme.titleMedium),
              ),
              Text('Net balance',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant)),
            ]),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}

/// Review both directions of debt before choosing an explicit action.
class _FriendBalanceDetails extends ConsumerWidget {
  const _FriendBalanceDetails({
    required this.balance,
    required this.myUid,
    required this.onRecordPayment,
    required this.onRemind,
  });

  final FriendBalance balance;
  final String myUid;
  final Future<bool> Function(BuildContext context) onRecordPayment;
  final Future<void> Function(BuildContext context) onRemind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(myBillsProvider).value ?? const <Bill>[];
    final relevant = bills.where((bill) {
      if (bill.currency != balance.currency) return false;
      if (bill.hasPaymentLedger) {
        return bill.paymentDebts.any((debt) =>
          !debt.isSettled &&
          ((debt.creditorUid == myUid && debt.debtorUid == balance.uid) ||
           (debt.debtorUid == myUid && debt.creditorUid == balance.uid)));
      }
      if (bill.createdBy == myUid) {
        return bill.splits.any((share) =>
            share.uid == balance.uid && !share.isFullyPaid);
      }
      return bill.createdBy == balance.uid &&
          bill.splits.any((share) =>
              share.uid == myUid && !share.isFullyPaid);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(balance.displayName,
        maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          SectionHeading('Balance in ${balance.currency}',
            subtitle: 'Outstanding debts, not a money transfer.'),
          SoftPanel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AmountDetail(
                label: 'You owe ${balance.displayName}',
                amount: balance.iOweThem,
                currency: balance.currency,
                color: Theme.of(context).colorScheme.owe),
              const Divider(height: 22),
              _AmountDetail(
                label: '${balance.displayName} owes you',
                amount: balance.owesMe,
                currency: balance.currency,
                color: Theme.of(context).colorScheme.owed),
              const Divider(height: 22),
              _AmountDetail(
                label: 'Net balance',
                amount: balance.net.abs(),
                currency: balance.currency,
                color: Theme.of(context).colorScheme.onSurface),
              if (balance.net.abs() < 0.005)
                const Text(
                  'Net is zero, but payments in both directions are still open.'),
            ],
          )),
          const SizedBox(height: 15),
          if (balance.iOweThem > 0) ...[
            FilledButton.icon(
              onPressed: () async {
                final recorded = await onRecordPayment(context);
                if (recorded && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.check_rounded),
              label: Text('Record ${formatMoney(balance.iOweThem, balance.currency)} paid'),
            ),
            const SizedBox(height: 10),
          ],
          if (balance.owesMe > 0)
            OutlinedButton.icon(
              onPressed: () => onRemind(context),
              icon: const Icon(Icons.notifications_none_rounded),
              label: const Text('Send reminder'),
            ),
          SectionHeading('Outstanding bills',
            subtitle: '${relevant.length} related '
                'bill${relevant.length == 1 ? '' : 's'}'),
          if (relevant.isEmpty)
            const InlineEmpty(
              icon: Icons.receipt_long_outlined,
              title: 'No outstanding bills',
              message: 'Your balances may have just updated.',
            ),
          for (final bill in relevant)
            Card(child: ListTile(
              title: Text(bill.title, maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              subtitle: Text('Total: ${formatMoney(bill.total, bill.currency)}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BillDetailScreen(billId: bill.id))),
            )),
        ],
      ),
    );
  }
}

class _AmountDetail extends StatelessWidget {
  const _AmountDetail({
    required this.label, required this.amount,
    required this.currency, required this.color,
  });

  final String label;
  final double amount;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(label)),
    const SizedBox(width: 8),
    Flexible(child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: MoneyText(amount, currencyCode: currency, color: color),
    )),
  ]);
}
