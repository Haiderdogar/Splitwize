import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../widgets/ad_banner.dart';
import '../widgets/app_drawer.dart';
import '../widgets/balance_totals.dart';
import '../widgets/bill_list_tile.dart';
import '../widgets/home_expense_controls.dart';
import '../widgets/state_widgets.dart';
import '../widgets/studio_ui.dart';
import 'create_bill_screen.dart';

export '../utils/money.dart';

/// Local-first expense history with view-only search, filters and sorting.
class BillsTab extends ConsumerStatefulWidget {
  const BillsTab({super.key});

  @override
  ConsumerState<BillsTab> createState() => _BillsTabState();
}

class _BillsTabState extends ConsumerState<BillsTab> {
  final _searchController = TextEditingController();
  ExpenseFilter _filter = ExpenseFilter.all;
  bool _showSearch = false;
  bool _oldestFirst = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addExpense() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const CreateBillScreen()));

  void _resetFilters() {
    _searchController.clear();
    setState(() => _filter = ExpenseFilter.all);
  }

  void _toggleSearch() => setState(() {
        _showSearch = !_showSearch;
        if (!_showSearch) {
          _searchController.clear();
          FocusScope.of(context).unfocus();
        }
      });

  List<Bill> _visibleBills(List<Bill> bills) {
    final query = _searchController.text.trim().toLowerCase();
    final visible = bills.where((bill) {
      final matchesStatus = switch (_filter) {
        ExpenseFilter.all => true,
        ExpenseFilter.open => !bill.fullySettled,
        ExpenseFilter.settled => bill.fullySettled,
      };
      if (!matchesStatus) return false;
      if (query.isEmpty) return true;
      final searchable = [
        bill.title,
        bill.groupName ?? 'Personal expense',
        bill.createdByName,
        bill.currency,
        ...bill.splits.map((split) => split.displayName),
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
    visible.sort((a, b) {
      // Unknown dates belong at the end in either direction.
      if (a.createdAt == null && b.createdAt == null) {
        return a.id.compareTo(b.id);
      }
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      final order = a.createdAt!.compareTo(b.createdAt!);
      return order == 0
          ? a.id.compareTo(b.id)
          : (_oldestFirst ? order : -order);
    });
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider) ?? '';
    final billsAsync = ref.watch(myBillsProvider);
    final theme = Theme.of(context);
    final compactAction = MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(14) > 20;

    return Scaffold(
      appBar: AppBar(
        leading: const SplitwizeMenuButton(),
        titleSpacing: 0,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const SplitwizeMark(size: 31),
          const SizedBox(width: 9),
          Flexible(
            child: Text('Splitwize',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge),
          ),
        ]),
        actions: [
          IconButton(
            tooltip: _showSearch ? 'Close search' : 'Search expenses',
            onPressed: _toggleSearch,
            icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: billsAsync.when(
                  loading: () => const ShimmerList(),
                  error: (e, _) => LoadError(
                    message: 'Could not load your expenses.',
                    onRetry: () {
                      ref.invalidate(appRepositoryProvider);
                      ref.invalidate(myBillsProvider);
                    },
                  ),
                  data: (data) {
                    final bills = data.where((bill) => !bill.deleted).toList();
                    final settledCount =
                        bills.where((bill) => bill.fullySettled).length;
                    final visible = _visibleBills(bills);
                    final now = DateTime.now();
                    return ListView.builder(
                      key: const PageStorageKey('home-expenses'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),
                      itemCount: visible.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_showSearch)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: TextField(
                                    controller: _searchController,
                                    autofocus: true,
                                    onChanged: (_) => setState(() {}),
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: (_) =>
                                        FocusScope.of(context).unfocus(),
                                    decoration: InputDecoration(
                                      hintText: 'Search expenses',
                                      prefixIcon:
                                          const Icon(Icons.search_rounded),
                                      suffixIcon: _searchController.text.isEmpty
                                          ? null
                                          : IconButton(
                                              tooltip: 'Clear search',
                                              onPressed: () => setState(
                                                  _searchController.clear),
                                              icon: const Icon(
                                                  Icons.close_rounded),
                                            ),
                                    ),
                                  ),
                                ),
                              // Totals per currency; nothing is shown until
                              // there is an outstanding balance.
                              const BalanceTotals(bottomPadding: 16),
                              ExpenseFilterBar(
                                total: bills.length,
                                settled: settledCount,
                                selected: _filter,
                                onSelected: (filter) =>
                                    setState(() => _filter = filter),
                              ),
                              const SizedBox(height: 12),
                              if (bills.isEmpty)
                                InlineEmpty(
                                  icon: Icons.receipt_long_outlined,
                                  title: 'Your first split starts here',
                                  message:
                                      'Add an expense to start splitting with friends.',
                                )
                              else if (visible.isEmpty)
                                InlineEmpty(
                                  icon: _searchController.text.trim().isNotEmpty
                                      ? Icons.search_off_rounded
                                      : Icons.task_alt_rounded,
                                  title:
                                      _searchController.text.trim().isNotEmpty
                                          ? 'No matching expenses'
                                          : _filter == ExpenseFilter.open
                                              ? 'All settled up'
                                              : 'No settled expenses yet',
                                  message: _searchController.text
                                          .trim()
                                          .isNotEmpty
                                      ? 'Try a different name, group, or currency.'
                                      : _filter == ExpenseFilter.open
                                          ? 'Unsettled expenses will appear here.'
                                          : 'Expenses appear here once everyone has settled.',
                                  action: TextButton(
                                    onPressed: _resetFilters,
                                    child: const Text('Show all expenses'),
                                  ),
                                )
                              else
                                ExpenseListHeading(
                                  count: visible.length,
                                  filtered: _filter != ExpenseFilter.all ||
                                      _searchController.text.trim().isNotEmpty,
                                  oldestFirst: _oldestFirst,
                                  onSort: (oldestFirst) => setState(
                                      () => _oldestFirst = oldestFirst),
                                ),
                            ],
                          );
                        }
                        final bill = visible[index - 1];
                        final dateLabel = _dateLabel(bill.createdAt, now);
                        final beginsSection = index == 1 ||
                            _dateLabel(visible[index - 2].createdAt, now) !=
                                dateLabel;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (beginsSection)
                              ExpenseDateHeading(label: dateLabel),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: BillListTile(
                                  key: ValueKey(bill.id), bill: bill, uid: uid),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          const AdBannerSlot(),
        ]),
      ),
      floatingActionButton: compactAction
          ? FloatingActionButton(
              heroTag: 'home-add-expense',
              onPressed: _addExpense,
              tooltip: 'Add expense',
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : FloatingActionButton.extended(
              heroTag: 'home-add-expense',
              onPressed: _addExpense,
              tooltip: 'Add expense',
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add expense'),
            ),
    );
  }

  String _dateLabel(DateTime? value, DateTime now) {
    if (value == null) return 'Undated';
    final local = value.toLocal();
    final day = DateUtils.dateOnly(local);
    final today = DateUtils.dateOnly(now);
    if (day == today) return 'Today';
    if (day == DateTime(today.year, today.month, today.day - 1)) {
      return 'Yesterday';
    }
    return DateFormat('MMMM yyyy').format(local);
  }
}
