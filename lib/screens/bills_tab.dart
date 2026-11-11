import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../widgets/ad_banner.dart';
import '../widgets/bill_list_tile.dart';
import '../widgets/app_drawer.dart';
import '../widgets/state_widgets.dart';
import '../widgets/studio_ui.dart';
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

  void _addExpense() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const CreateBillScreen()));

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
              final settledCount =
                  bills.where((bill) => bill.fullySettled).length;
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
                      settledCount: settledCount,
                      visibleCount: visible.length,
                      filter: _filter,
                      onFilter: (v) => setState(() => _filter = v),
                      onAdd: _addExpense,
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: BillListTile(bill: visible[i - 1], uid: uid),
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
    required this.settledCount,
    required this.visibleCount,
    required this.filter,
    required this.onFilter,
    required this.onAdd,
  });

  final int billCount;
  final int settledCount;
  final int visibleCount;
  final _ExpenseFilter filter;
  final ValueChanged<_ExpenseFilter> onFilter;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeading('Expenses',
          subtitle: billCount == 0
              ? 'Your bills will appear here.'
              : '$billCount recorded'),
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
                    _ExpenseFilter.all => 'All ($billCount)',
                    _ExpenseFilter.open =>
                      'Unsettled (${billCount - settledCount})',
                    _ExpenseFilter.settled => 'Settled ($settledCount)',
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
