import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../utils/current_user_identity.dart';
import '../widgets/ad_banner.dart';
import '../widgets/app_drawer.dart';
import '../widgets/money_text.dart';
import '../widgets/state_widgets.dart';
import '../widgets/studio_ui.dart';
import 'bill_detail_screen.dart';
import 'create_bill_screen.dart';
import '../widgets/app_notification_button.dart';

export '../utils/money.dart';

enum _ExpenseFilter { all, open, settled }

/// Home is the starting point for real tasks, not a marketing page.
/// The data remains driven by the original offline-first Riverpod providers.
class BillsTab extends ConsumerStatefulWidget {
  const BillsTab({super.key});

  @override
  ConsumerState<BillsTab> createState() => _BillsTabState();
}

class _BillsTabState extends ConsumerState<BillsTab> {
  _ExpenseFilter _filter = _ExpenseFilter.all;

  void _addExpense() => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const CreateBillScreen()));

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider) ?? '';
    final billsAsync = ref.watch(myBillsProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const SplitwizeMenuButton(),
        titleSpacing: 0,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const SplitwizeMark(size: 31),
          const SizedBox(width: 9),
          Text('Splitwize', style: Theme.of(context).textTheme.titleLarge),
        ]),
        actions: const [AppNotificationButton(), SizedBox(width: 5)],
      ),
      body: Column(children: [
        Expanded(
          child: billsAsync.when(
            loading: () => const ShimmerList(),
            error: (e, _) => LoadError(
              message: 'Could not load your expenses.',
              onRetry: () {
                ref.invalidate(appRepositoryProvider);
                ref.invalidate(myBillsProvider);
              },
            ),
            data: (bills) {
              final visible = switch (_filter) {
                _ExpenseFilter.all => bills,
                _ExpenseFilter.open =>
                  bills.where((b) => !b.fullySettled).toList(),
                _ExpenseFilter.settled =>
                  bills.where((b) => b.fullySettled).toList(),
              };
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                itemCount: visible.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return _HomeOverview(
                      billCount: bills.length,
                      visibleCount: visible.length,
                      filter: _filter,
                      onFilter: (v) => setState(() => _filter = v),
                      onAdd: _addExpense,
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ExpenseRow(bill: visible[i - 1], uid: uid),
                  );
                },
              );
            },
          ),
        ),
        const AdBannerSlot(),
      ]),
      floatingActionButton: FloatingActionButton(
        heroTag: 'home-add-expense',
        onPressed: _addExpense,
        tooltip: 'Add expense',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      backgroundColor: scheme.surface,
    );
  }
}

/// Expense-first home. Balances have their own dedicated tab.
class _HomeOverview extends StatelessWidget {
  const _HomeOverview({
    required this.billCount,
    required this.visibleCount,
    required this.filter,
    required this.onFilter,
    required this.onAdd,
  });

  final int billCount;
  final int visibleCount;
  final _ExpenseFilter filter;
  final ValueChanged<_ExpenseFilter> onFilter;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeading('Expenses',
        subtitle: billCount == 0
            ? 'Your shared expenses will appear here.'
            : '$billCount recorded'),
      // Keep all filters visible instead of hiding them in a menu.
      Wrap(spacing: 8, runSpacing: 2, children: [
        ChoiceChip(
          label: const Text('All'),
          selected: filter == _ExpenseFilter.all,
          onSelected: (_) => onFilter(_ExpenseFilter.all),
        ),
        ChoiceChip(
          label: const Text('Unsettled'),
          selected: filter == _ExpenseFilter.open,
          onSelected: (_) => onFilter(_ExpenseFilter.open),
        ),
        ChoiceChip(
          label: const Text('Settled'),
          selected: filter == _ExpenseFilter.settled,
          onSelected: (_) => onFilter(_ExpenseFilter.settled),
        ),
      ]),
      const SizedBox(height: 12),
      if (billCount == 0)
        InlineEmpty(
          icon: Icons.receipt_long_outlined,
          title: 'No expenses yet',
          message: 'Add a bill and invite friends to split it.',
          action: FilledButton(
            onPressed: onAdd,
            child: const Text('Add your first expense'),
          ),
        ),
      if (billCount > 0 && visibleCount == 0)
        const InlineEmpty(
          icon: Icons.filter_list_off_rounded,
          title: 'Nothing to show',
          message: 'Try another expense filter to see your bills.',
        ),
    ]);
  }
}

class _ExpenseRow extends ConsumerWidget {
  const _ExpenseRow({required this.bill, required this.uid});
  final Bill bill;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final google = ref.watch(authStateChangesProvider).value;
    final identity = resolveCurrentUserIdentity(
      cached: ref.watch(currentAppUserProvider).value,
      googleName: google?.displayName,
      googleEmail: google?.email,
    );
    // Always show the same amounts for every expense, irrespective of
    // who recorded it or who paid the merchant.
    final myShare = bill.myShare(uid);
    final payers = bill.merchantPayments.entries
        .where((entry) => entry.value > 0).toList();
    String participantName(String memberUid) {
      if (memberUid == uid) return '${identity.name} (you)';
      for (final member in bill.splits) {
        if (member.uid == memberUid) return member.displayName;
      }
      return 'Member';
    }
    final payerLabel = bill.hasPaymentLedger
        ? payers.length == 1
            ? 'Paid by ${participantName(payers.single.key)}'
            : 'Paid by ${payers.length} people'
        : 'Paid by ${participantName(bill.createdBy)}';
    final groupName = bill.groupName;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BillDetailScreen(billId: bill.id))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
          child: Row(children: [
            const PersonMark(initials: '',
              icon: Icons.receipt_long_outlined, size: 46),
            const SizedBox(width: 11),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bill.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                if (groupName != null)
                  Text(groupName, maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant)),
                Text(payerLabel, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Text(
                  bill.fullySettled ? 'Settled' :
                      '${formatMoney(bill.outstanding, bill.currency)} remaining',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: bill.fullySettled ? scheme.owed :
                      scheme.onSurfaceVariant)),
              ],
            )),
            const SizedBox(width: 8),
            SizedBox(width: 94, child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(fit: BoxFit.scaleDown,
                  child: MoneyText(bill.total, currencyCode: bill.currency,
                    style: Theme.of(context).textTheme.titleMedium)),
                const SizedBox(height: 4),
                const Text('Total bill',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant)),
                Text('Your share: ${formatMoney(myShare, bill.currency)}',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant)),
                if (bill.createdAt != null)
                  Text(DateFormat.MMMd().format(bill.createdAt!),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant)),
              ],
            )),
          ]),
        ),
      ),
    );
  }
}
