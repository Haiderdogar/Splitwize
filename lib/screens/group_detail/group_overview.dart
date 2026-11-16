import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../utils/money.dart';
import '../../widgets/state_widgets.dart';

/// Totals use the effective currency supplied by the repository. Group bills
/// follow the selected group currency without converting their numeric amounts.
class GroupOverview extends ConsumerWidget {
  const GroupOverview({
    required this.group,
    super.key,
  });

  final BillGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(groupBillsProvider(group.id));
    return bills.when(
      loading: () => const ShimmerRows(count: 1),
      error: (_, __) => LoadError.compact(
        message: 'Could not load the group overview.',
        onRetry: () => ref.invalidate(groupBillsProvider(group.id)),
      ),
      data: (bills) => _OverviewCard(
        bills: bills,
        currency: group.currency,
      ),
    );
  }
}

class _CurrencyOverview {
  int spentCents = 0;
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.bills,
    required this.currency,
  });

  final List<Bill> bills;
  final String currency;

  Map<String, _CurrencyOverview> _totals() {
    final totals = <String, _CurrencyOverview>{};
    for (final bill in bills.where((bill) => !bill.deleted)) {
      final entry = totals.putIfAbsent(bill.currency, _CurrencyOverview.new);
      entry.spentCents += (bill.total * 100).round();
    }
    if (totals.isEmpty) totals[currency] = _CurrencyOverview();
    return Map.fromEntries(
        totals.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final foreground = dark ? scheme.onSurface : scheme.onPrimary;
    final secondary = foreground.withValues(alpha: .76);
    final totals = _totals();
    final activeBills = bills.where((bill) => !bill.deleted).toList();
    final unsettled = activeBills.where((bill) => !bill.fullySettled).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: dark ? scheme.surfaceContainerHigh : scheme.primary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text('TOTAL GROUP SPENDING',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: secondary,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      )),
                ),
                Icon(Icons.receipt_long_outlined, color: secondary, size: 20),
              ]),
              const SizedBox(height: 12),
              for (final entry in totals.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(formatMoney(entry.value.spentCents / 100, entry.key),
                          key: ValueKey('group-spending-${entry.key}'),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: foreground,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.8,
                          )),
                      Text(entry.key,
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: secondary)),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Divider(color: foreground.withValues(alpha: .18), height: 1),
              const SizedBox(height: 14),
              Wrap(spacing: 20, runSpacing: 10, children: [
                _OverviewMetric(
                  icon: Icons.layers_outlined,
                  label:
                      '${activeBills.length} ${activeBills.length == 1 ? 'expense' : 'expenses'}',
                  color: foreground,
                ),
                _OverviewMetric(
                  icon: unsettled == 0
                      ? Icons.check_circle_outline_rounded
                      : Icons.timelapse_rounded,
                  label: '$unsettled unsettled',
                  color: foreground,
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color.withValues(alpha: .8)),
          const SizedBox(width: 6),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      );
}
