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
              final balances = ref.watch(balancesProvider);
              final byCurrency = <String, ({double owed, double owe})>{};
              for (final balance in balances) {
                final previous = byCurrency[balance.currency] ??
                    (owed: 0.0, owe: 0.0);
                byCurrency[balance.currency] = (
                  owed: previous.owed + (balance.net > 0 ? balance.net : 0.0),
                  owe: previous.owe + (balance.net < 0 ? -balance.net : 0.0),
                );
              }
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
                      balances: byCurrency,
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
    required this.balances,
    required this.filter,
    required this.onFilter,
    required this.onAdd,
  });

  final int billCount;
  final int visibleCount;
  final Map<String, ({double owed, double owe})> balances;
  final _ExpenseFilter filter;
  final ValueChanged<_ExpenseFilter> onFilter;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final codes = balances.keys.toList()..sort();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeading('Your balances',
        subtitle: 'Amounts are kept separate by currency.'),
      if (codes.isEmpty)
        SoftPanel(child: Row(children: [
          const PersonMark(initials: '', icon: Icons.check_rounded),
          const SizedBox(width: 12),
          Expanded(child: Text('No outstanding balances.',
            style: Theme.of(context).textTheme.bodyMedium)),
        ]))
      else
        for (final code in codes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CurrencySnapshot(
              currency: code,
              owed: balances[code]!.owed,
              owe: balances[code]!.owe,
            ),
          ),
      SectionHeading(
        'Recent expenses',
        subtitle: billCount == 0
            ? 'Your expenses will show up here.'
            : '$billCount recorded',
        trailing: PopupMenuButton<_ExpenseFilter>(
          tooltip: 'Filter expenses',
          onSelected: onFilter,
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _ExpenseFilter.all,
              child: Text('All expenses'),
            ),
            PopupMenuItem(
              value: _ExpenseFilter.open,
              child: Text('Open expenses'),
            ),
            PopupMenuItem(
              value: _ExpenseFilter.settled,
              child: Text('Settled expenses'),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  switch (filter) {
                    _ExpenseFilter.all => 'See all',
                    _ExpenseFilter.open => 'Open',
                    _ExpenseFilter.settled => 'Settled',
                  },
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 17, color: Theme.of(context).colorScheme.primary),
              ],
            ),
          ),
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

class _CurrencySnapshot extends StatelessWidget {
  const _CurrencySnapshot({
    required this.currency, required this.owed, required this.owe,
  });
  final String currency;
  final double owed;
  final double owe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SoftPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(currency, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 11),
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You are owed', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                child: MoneyText(owed, currencyCode: currency,
                  color: scheme.owed,
                  style: Theme.of(context).textTheme.titleLarge),
              ),
            ],
          )),
          const SizedBox(width: 12),
          Container(width: 1, height: 40, color: scheme.outlineVariant),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You owe', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                child: MoneyText(owe, currencyCode: currency,
                  color: scheme.owe,
                  style: Theme.of(context).textTheme.titleLarge),
              ),
            ],
          )),
        ]),
      ]),
    );
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
    final amount = isOwner ? bill.total : bill.myShare(uid);
    final detail = bill.groupName ??
        (isOwner ? '${identity.name} (you)' : bill.createdByName);
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
                Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant)),
                if (isOwner && bill.groupName == null && identity.email.isNotEmpty)
                  Text(identity.email, maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Text(bill.fullySettled ? 'Settled' :
                  '${bill.paidCount} of ${bill.splits.length} paid',
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
                  child: MoneyText(amount, currencyCode: bill.currency,
                    style: Theme.of(context).textTheme.titleMedium)),
                const SizedBox(height: 4),
                Text(isOwner ? 'total bill' : 'your share',
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
