import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
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
        subtitle: billCount == 0 ? 'Your bills will appear here.' : '$billCount recorded'),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final option in _ExpenseFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: ChoiceChip(
                  label: Text(switch (option) {
                    _ExpenseFilter.all => 'All',
                    _ExpenseFilter.open => 'Unsettled',
                    _ExpenseFilter.settled => 'Settled',
                  }),
                  selected: filter == option,
                  onSelected: (_) => onFilter(option),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 5),
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
    final isOwner = bill.createdBy == uid;
    final google = ref.watch(authStateChangesProvider).value;
    final identity = resolveCurrentUserIdentity(
      cached: ref.watch(currentAppUserProvider).value,
      googleName: google?.displayName,
      googleEmail: google?.email,
    );
    final payerIds = bill.merchantPayments.entries
        .where((payment) => payment.value > 0.005)
        .map((payment) => payment.key).toList();
    String personName(String payerUid) {
      if (payerUid == uid) return '${identity.name} (you)';
      for (final split in bill.splits) {
        if (split.uid == payerUid) return split.displayName;
      }
      return 'A participant';
    }
    final paidBy = !bill.hasPaymentLedger
        ? 'Recorded by ${isOwner ? "${identity.name} (you)" : bill.createdByName}'
        : payerIds.length == 1
            ? 'Paid by ${personName(payerIds.single)}'
            : 'Paid by ${payerIds.length} people';
    final detail = bill.groupName ?? 'Personal expense';
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
                Text('$detail · $paidBy', maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant)),
                if (isOwner && bill.groupName == null && identity.email.isNotEmpty)
                  Text(identity.email, maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Text(bill.fullySettled ? 'Settled' :
                  '${formatMoney(bill.outstanding, bill.currency)} remaining to settle',
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
                if (bill.participantIds.contains(uid))
                  Text('Your share: ${formatMoney(bill.myShare(uid), bill.currency)}',
                    textAlign: TextAlign.end, maxLines: 2,
                    style: Theme.of(context).textTheme.labelSmall),
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
