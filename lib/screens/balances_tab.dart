import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/person_bills.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_notification_button.dart';
import '../widgets/balance_totals.dart';
import '../widgets/money_text.dart';
import '../widgets/repayment_action.dart';
import '../widgets/state_widgets.dart';
import '../widgets/studio_ui.dart';
import 'bills_tab.dart' show formatMoney;
import 'person_bills_screen.dart';

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
        final bills = billsAsync.value ?? const <Bill>[];
        final billCounts = <String, int>{};
        for (final balance in balances) {
          billCounts.putIfAbsent(balance.uid,
              () => billsWithPerson(bills, uid, balance.uid).length);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 3, 16, 24),
          itemCount: balances.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return _BalanceOverview(hasBalances: balances.isNotEmpty);
            }
            final balance = balances[i - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _BalanceTile(
                balance: balance,
                totalBills: billCounts[balance.uid]!,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PersonBillsScreen(
                    personUid: balance.uid,
                    personName: balance.displayName,
                  ),
                )),
                onSettleUp: () => recordRepayment(context, ref, balance),
              ),
            );
          },
        );
      }),
    );
  }
}

class _BalanceOverview extends StatelessWidget {
  const _BalanceOverview({required this.hasBalances});
  final bool hasBalances;

  @override
  Widget build(BuildContext context) {
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
        const BalanceTotals(bottomPadding: 9),
        const SectionHeading('People',
            subtitle: 'Open shared bills or record repayments.'),
      ],
    ]);
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.balance,
    required this.totalBills,
    required this.onTap,
    required this.onSettleUp,
  });
  final FriendBalance balance;
  final int totalBills;
  final VoidCallback onTap;
  final VoidCallback onSettleUp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final owe = balance.net < -0.005;
    final owed = balance.net > 0.005;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SoftPanel(
          fill: Colors.transparent,
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              PersonMark(initials: balance.initials),
              const SizedBox(width: 11),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(balance.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                        '$totalBills shared ${totalBills == 1 ? 'bill' : 'bills'}',
                        style: Theme.of(context).textTheme.bodySmall),
                    Text('${balance.openBills} open in ${balance.currency}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ])),
              const Icon(Icons.chevron_right_rounded),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: Text(
                      owe
                          ? 'Net: you owe'
                          : owed
                              ? 'Net: owes you'
                              : 'Net zero',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant))),
              const SizedBox(width: 8),
              Flexible(
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: MoneyText(balance.net.abs(),
                          currencyCode: balance.currency,
                          color: owe
                              ? scheme.owe
                              : owed
                                  ? scheme.owed
                                  : scheme.onSurface,
                          style: Theme.of(context).textTheme.titleMedium))),
            ]),
            Text(
                'You owe ${formatMoney(balance.iOweThem, balance.currency)} · '
                'Owes you ${formatMoney(balance.owesMe, balance.currency)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (balance.iOweThem > 0.005)
                FilledButton.icon(
                    onPressed: onSettleUp,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Record repayment')),
            ]),
          ]),
        ),
      ),
    );
  }
}
