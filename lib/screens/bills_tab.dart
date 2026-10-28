import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../utils/money.dart';
import '../widgets/ad_banner.dart';
import '../widgets/empty_state.dart';
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
        title: const Text('Bills'),
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
                    if (bills.isEmpty) return const _EmptyBills();
                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: bills.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _BillCard(
                        bill: bills[i],
                        myUid: myUid ?? '',
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const AdBannerSlot(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateBillScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Split bill'),
      ),
    );
  }
}

class _EmptyBills extends StatelessWidget {
  const _EmptyBills();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'No bills yet.',
      subtitle: 'Tap + to split your first bill with friends.',
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
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(
          bill.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
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
              Text(
                formatMoney(mine ? bill.total : myShare, bill.currency),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
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
