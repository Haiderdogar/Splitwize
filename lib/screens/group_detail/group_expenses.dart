import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../theme.dart';
import '../../utils/money.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/studio_ui.dart';
import '../bill_detail_screen.dart';

enum _ExpenseFilter { all, unsettled, settled }

/// A group's chronological expense history, with its own filter and scroll
/// position. Rows are built lazily, including the month headings.
class GroupExpensesTab extends ConsumerStatefulWidget {
  const GroupExpensesTab({required this.group, super.key});

  final BillGroup group;

  @override
  ConsumerState<GroupExpensesTab> createState() => _GroupExpensesTabState();
}

class _GroupExpensesTabState extends ConsumerState<GroupExpensesTab>
    with AutomaticKeepAliveClientMixin {
  _ExpenseFilter _filter = _ExpenseFilter.all;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final billsAsync = ref.watch(groupBillsProvider(widget.group.id));
    final uid = ref.watch(currentUidProvider) ?? '';

    return CustomScrollView(
      key: PageStorageKey('group-expenses-${widget.group.id}'),
      slivers: [
        SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          sliver: billsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: ShimmerRows(count: 3),
            ),
            error: (_, __) => SliverToBoxAdapter(
              child: LoadError.compact(
                message: 'Could not load expenses.',
                onRetry: () {
                  ref.invalidate(appRepositoryProvider);
                  ref.invalidate(groupBillsProvider(widget.group.id));
                },
              ),
            ),
            data: (bills) {
              final ordered = bills.where((bill) => !bill.deleted).toList()
                ..sort((a, b) => (b.createdAt ?? DateTime(1970))
                    .compareTo(a.createdAt ?? DateTime(1970)));
              final visible = ordered
                  .where((bill) => switch (_filter) {
                        _ExpenseFilter.all => true,
                        _ExpenseFilter.unsettled => !bill.fullySettled,
                        _ExpenseFilter.settled => bill.fullySettled,
                      })
                  .toList();

              return SliverMainAxisGroup(slivers: [
                SliverToBoxAdapter(
                  child: _HistoryHeading(
                    count: ordered.length,
                    filter: _filter,
                    onFilter: (value) => setState(() => _filter = value),
                  ),
                ),
                if (visible.isEmpty)
                  SliverToBoxAdapter(
                    child: InlineEmpty(
                      icon: ordered.isEmpty
                          ? Icons.receipt_long_outlined
                          : Icons.filter_list_off_rounded,
                      title: ordered.isEmpty
                          ? 'Your first expense starts here'
                          : 'No ${_filter.name} expenses',
                      message: ordered.isEmpty
                          ? 'Add a shared expense to start keeping track together.'
                          : 'Choose another filter to see more of your group’s expenses.',
                      action: ordered.isEmpty
                          ? null
                          : TextButton(
                              onPressed: () =>
                                  setState(() => _filter = _ExpenseFilter.all),
                              child: const Text('Show all expenses'),
                            ),
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final bill = visible[index];
                      final previous = index == 0 ? null : visible[index - 1];
                      final beginsMonth = index == 0 ||
                          bill.createdAt?.year != previous?.createdAt?.year ||
                          bill.createdAt?.month != previous?.createdAt?.month;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (beginsMonth) _MonthHeading(date: bill.createdAt),
                          _ExpenseRow(bill: bill, uid: uid),
                        ],
                      );
                    },
                  ),
              ]);
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryHeading extends StatelessWidget {
  const _HistoryHeading({
    required this.count,
    required this.filter,
    required this.onFilter,
  });

  final int count;
  final _ExpenseFilter filter;
  final ValueChanged<_ExpenseFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text('Expense history', style: theme.textTheme.titleMedium),
          ),
          const SizedBox(width: 8),
          Text('$count total',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
        ]),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final option in _ExpenseFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(switch (option) {
                    _ExpenseFilter.all => 'All',
                    _ExpenseFilter.unsettled => 'Unsettled',
                    _ExpenseFilter.settled => 'Settled',
                  }),
                  selected: filter == option,
                  onSelected: (_) => onFilter(option),
                  showCheckmark: false,
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _MonthHeading extends StatelessWidget {
  const _MonthHeading({required this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        date == null ? 'Date unavailable' : DateFormat.yMMMM().format(date!),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.bill, required this.uid});

  final Bill bill;
  final String uid;

  String _payerLabel() {
    if (!bill.hasPaymentLedger) {
      return 'Recorded by ${bill.createdBy == uid ? 'you' : bill.createdByName}';
    }
    final payers = bill.merchantPayments.entries
        .where((entry) => entry.value > 0.005)
        .map((entry) => entry.key)
        .toList();
    if (payers.length != 1) return 'Paid by ${payers.length} people';
    final payerUid = payers.single;
    if (payerUid == uid) return 'You paid';
    for (final split in bill.splits) {
      if (split.uid == payerUid) return '${split.displayName} paid';
    }
    for (final debt in bill.paymentDebts) {
      if (debt.creditorUid == payerUid) return '${debt.creditorName} paid';
    }
    if (payerUid == bill.createdBy) return '${bill.createdByName} paid';
    return 'Paid by a participant';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settled = bill.fullySettled;
    final statusColor = settled ? scheme.owed : scheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BillDetailScreen(billId: bill.id),
        )),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.receipt_long_outlined,
                    size: 21, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bill.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      [
                        _payerLabel(),
                        if (bill.createdAt != null)
                          DateFormat.MMMd().format(bill.createdAt!),
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${formatMoney(bill.total, bill.currency)} ${bill.currency}',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              settled
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.schedule_rounded,
                              size: 14,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(settled ? 'Settled' : 'Unsettled',
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: statusColor)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: scheme.outlineVariant),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
