import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import 'money_text.dart';
import 'studio_ui.dart';

/// What is owed to you and what you owe, summed per currency.
///
/// The app has no exchange rates, so amounts in different currencies are never
/// added together: every currency keeps its own totals.
Map<String, ({double owed, double owe})> balanceTotalsByCurrency(
    Iterable<FriendBalance> balances) {
  final totals = <String, ({double owed, double owe})>{};
  for (final balance in balances) {
    final previous = totals[balance.currency] ?? (owed: 0.0, owe: 0.0);
    totals[balance.currency] = (
      owed: previous.owed + balance.owesMe,
      owe: previous.owe + balance.iOweThem,
    );
  }
  return totals;
}

/// One panel with an "Owed to you / You owe" pair for each currency.
/// It shows nothing while there are no outstanding balances.
class BalanceTotals extends ConsumerWidget {
  const BalanceTotals({super.key, this.topPadding = 0, this.bottomPadding = 0});

  /// Space kept above and below the panel, only while the panel is shown.
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = balanceTotalsByCurrency(ref.watch(balancesProvider));
    if (totals.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final codes = totals.keys.toList()..sort();
    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      child: SoftPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < codes.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: scheme.outlineVariant),
              ),
            Column(
              key: ValueKey('balance-totals-${codes[i]}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(codes[i], style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _AmountSummary(
                          label: 'Owed to you',
                          amount: totals[codes[i]]!.owed,
                          currency: codes[i],
                          color: scheme.owed)),
                  const SizedBox(width: 12),
                  Container(height: 43, width: 1, color: scheme.outlineVariant),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _AmountSummary(
                          label: 'You owe',
                          amount: totals[codes[i]]!.owe,
                          currency: codes[i],
                          color: scheme.owe)),
                ]),
              ],
            ),
          ],
        ]),
      ),
    );
  }
}

class _AmountSummary extends StatelessWidget {
  const _AmountSummary({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });
  final String label;
  final double amount;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 5),
      FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: MoneyText(amount,
              currencyCode: currency,
              color: color,
              style: Theme.of(context).textTheme.titleLarge)),
    ]);
  }
}
