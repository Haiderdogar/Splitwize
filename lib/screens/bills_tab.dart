import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../utils/money.dart';
import '../widgets/ad_banner.dart';
import '../widgets/aurora_ui.dart';
import '../widgets/app_drawer.dart';
import '../widgets/empty_state.dart';
import '../widgets/money_text.dart';
import '../widgets/split_bar.dart';
import '../widgets/state_widgets.dart';
import 'bill_detail_screen.dart';
import 'create_bill_screen.dart';
import 'notifications_screen.dart';

export '../utils/money.dart';

class BillsTab extends StatelessWidget {
  const BillsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const SplitwizeMenuButton(),
        title: const Text('Splitwize'),
        actions: [
          // Only the badge reacts to notification state.
          Consumer(
            builder: (context, ref, _) {
              final unread = ref.watch(unreadCountProvider);
              return Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: IconButton(
                  tooltip: 'Notifications',
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const NotificationsScreen()),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      // Only the list reacts to bill state. The free-tier ad banner
      // sits under it (collapses for Pro users).
      body: Column(
        children: [
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final billsAsync = ref.watch(myBillsProvider);
                final myUid = ref.watch(currentUidProvider);
                return billsAsync.when(
                  loading: () => const ShimmerList(),
                  error: (e, _) => LoadError(
                    message: 'Could not load your bills.',
                    onRetry: () {
                      ref.invalidate(appRepositoryProvider);
                      ref.invalidate(myBillsProvider);
                    },
                  ),
                  data: (bills) {
                    final open = bills.where((bill) => !bill.fullySettled).length;
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
                      itemCount: bills.isEmpty ? 2 : bills.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return _BillsDashboardHeader(
                            billCount: bills.length,
                            openCount: open,
                            onSplit: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const CreateBillScreen()),
                            ),
                            onGroups: () => ref.read(tabIndexProvider.notifier).set(2),
                            onBalances: () => ref.read(tabIndexProvider.notifier).set(1),
                          );
                        }
                        if (bills.isEmpty) return const _EmptyBills();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _BillCard(
                            bill: bills[i - 1],
                            myUid: myUid ?? '',
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          const AdBannerSlot(),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateBillScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Split bill'),
        ),
      ),
    );
  }
}

class _BillsDashboardHeader extends StatelessWidget {
  const _BillsDashboardHeader({
    required this.billCount,
    required this.openCount,
    required this.onSplit,
    required this.onGroups,
    required this.onBalances,
  });

  final int billCount;
  final int openCount;
  final VoidCallback onSplit;
  final VoidCallback onGroups;
  final VoidCallback onBalances;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuroraHero(
          eyebrow: 'YOUR SHARED SPACE',
          title: 'Split moments.\nNot friendships.',
          subtitle: 'Your bills, people and payments in one happy place.',
          icon: Icons.auto_awesome_rounded,
          metric: '$billCount',
          metricLabel: billCount == 1 ? 'shared bill' : 'shared bills',
          bottom: Row(children: [
            const Icon(Icons.bolt_rounded, color: AuroraPalette.gold, size: 19),
            const SizedBox(width: 5),
            Expanded(child: Text(
              openCount == 0 ? 'All caught up — nice work!' : '$openCount bills still in progress',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
            )),
          ]),
        ),
        const SizedBox(height: 21),
        const AuroraSectionHeading('Quick actions', subtitle: 'Your essentials, one tap away'),
        Row(children: [
          AuroraActionTile(
            icon: Icons.add_card_rounded,
            label: 'Split bill',
            color: AuroraPalette.indigo,
            onTap: onSplit,
          ),
          AuroraActionTile(
            icon: Icons.groups_rounded,
            label: 'My groups',
            color: AuroraPalette.cyan,
            onTap: onGroups,
          ),
          AuroraActionTile(
            icon: Icons.balance_rounded,
            label: 'Balances',
            color: AuroraPalette.coral,
            onTap: onBalances,
          ),
        ]),
        const SizedBox(height: 22),
        AuroraSectionHeading(
          'Recent splits',
          subtitle: billCount == 0 ? 'Your first bill will appear here' : 'Shared expenses at a glance',
        ),
      ],
    );
  }
}

class _EmptyBills extends StatelessWidget {
  const _EmptyBills();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'No bills yet.',
      subtitle: 'Split your first bill with friends.',
      actionLabel: 'Split a bill',
      onAction: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CreateBillScreen()),
      ),
      // The split motif as this screen's own art, instead of the
      // generic circle every other empty state uses.
      visual: const SizedBox(
        width: 220,
        child: SplitBar(
          segments: [
            SplitSegment(value: 5, color: Colors.teal),
            SplitSegment(value: 3, color: Colors.orange),
            SplitSegment(value: 2, color: Colors.purple),
          ],
        ),
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill, required this.myUid});

  final Bill bill;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    final mine = bill.createdBy == myUid;
    final myShare = bill.myShare(myUid);
    final progress =
        bill.splits.isEmpty ? 0.0 : bill.paidCount / bill.splits.length;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .46)),
      ),
      child: ListTile(
        leading: AuroraMonogram(
          label: '',
          icon: mine ? Icons.receipt_long_rounded : Icons.payments_rounded,
          color: bill.fullySettled ? AuroraPalette.mint : AuroraPalette.indigo,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(
          bill.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                Chip(
                  label: Text(bill.splitTypeLabel),
                  visualDensity: VisualDensity.compact,
                ),
                if (bill.groupName != null)
                  Chip(
                    label: Text(bill.groupName!),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              mine
                  ? 'You split ${formatMoney(bill.total, bill.currency)} with ${bill.splits.length} ${bill.splits.length == 1 ? 'person' : 'people'}'
                  : '${bill.createdByName} split ${formatMoney(bill.total, bill.currency)}',
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress,
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(width: 8),
                // Loose fit: takes its natural width when there's
                // room, wraps instead of overflowing when there
                // isn't (fixed text beside an Expanded can
                // otherwise overflow by a rounding fraction).
                Flexible(
                  fit: FlexFit.loose,
                  child: Text(
                    bill.fullySettled
                        ? 'Settled'
                        : '${bill.paidCount}/${bill.splits.length} paid',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            if (bill.createdAt != null)
              Text(
                DateFormat.yMMMd().add_jm().format(bill.createdAt!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        trailing: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MoneyText(
                mine ? bill.total : myShare,
                currencyCode: bill.currency,
              ),
              Text(
                mine ? 'total' : 'your share',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BillDetailScreen(billId: bill.id),
          ),
        ),
      ),
    );
  }
}
