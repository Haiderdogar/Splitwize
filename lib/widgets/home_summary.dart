import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/current_user_identity.dart';
import '../utils/money.dart';
import 'balance_totals.dart' show balanceTotalsByCurrency;
import 'money_text.dart';

/// The greeting for the hour of [now].
String greetingFor(DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  if (hour >= 17 && hour < 22) return 'Good evening';
  return 'Hello';
}

/// The top of Home: a greeting and where you stand right now.
///
/// There are no exchange rates in the app, so every currency gets its own
/// block and nothing is ever added across currencies.
class HomeSummary extends ConsumerWidget {
  const HomeSummary({super.key, required this.hasExpenses});

  /// Whether there is any expense at all. A brand-new account gets only the
  /// greeting, because the list below already invites the first split.
  final bool hasExpenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final google = ref.watch(authStateChangesProvider).value;
    final identity = resolveCurrentUserIdentity(
      cached: ref.watch(currentAppUserProvider).value,
      googleName: google?.displayName,
      googleEmail: google?.email,
    );
    final summaries = _summariesByCurrency(ref.watch(balancesProvider));
    final now = DateTime.now();
    final greeting = greetingFor(now);
    final firstName = _firstName(identity.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            firstName.isEmpty ? greeting : '$greeting, $firstName',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 2),
          Text(
            DateFormat('EEEE, d MMMM').format(now),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (summaries.isNotEmpty) ...[
            const SizedBox(height: 16),
            _BalanceHero(summaries: summaries),
          ] else if (hasExpenses) ...[
            const SizedBox(height: 16),
            const _NothingOutstanding(),
          ],
        ],
      ),
    );
  }
}

String _firstName(String name) {
  // The identity falls back to this label when it knows nothing better.
  if (name == 'Your account') return '';
  return name.trim().split(RegExp(r'\s+')).first;
}

class _CurrencySummary {
  const _CurrencySummary({
    required this.code,
    required this.owed,
    required this.owe,
    required this.owedPeople,
    required this.owePeople,
  });

  final String code;
  final double owed;
  final double owe;
  final int owedPeople;
  final int owePeople;
}

List<_CurrencySummary> _summariesByCurrency(List<FriendBalance> balances) {
  final totals = balanceTotalsByCurrency(balances);
  final codes = totals.keys.toList()..sort();
  return [
    for (final code in codes)
      _CurrencySummary(
        code: code,
        owed: totals[code]!.owed,
        owe: totals[code]!.owe,
        owedPeople: balances
            .where((entry) => entry.currency == code && entry.owesMe > 0.005)
            .length,
        owePeople: balances
            .where((entry) => entry.currency == code && entry.iOweThem > 0.005)
            .length,
      ),
  ];
}

// The summary card is always dark green, in light and dark mode alike, so its
// colours are its own rather than the theme's.
const _heroOwed = Color(0xFFA9E8BF);
const _heroOwe = Color(0xFFFFC2AC);

Color _onHero(double opacity) => Colors.white.withValues(alpha: opacity);

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.summaries});

  final List<_CurrencySummary> summaries;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SplitwizePalette.forest, SplitwizePalette.forestDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < summaries.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: _onHero(.16)),
              ),
            _CurrencyBlock(summary: summaries[i]),
          ],
        ],
      ),
    );
  }
}

class _CurrencyBlock extends StatelessWidget {
  const _CurrencyBlock({required this.summary});

  final _CurrencySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = summary.code;
    final net = summary.owed - summary.owe;
    final netLabel = net.abs() < 0.005
        ? 'Net ${formatMoney(0, code)}'
        : net > 0
            ? 'Net +${formatMoney(net, code)}'
            : 'Net −${formatMoney(-net, code)}';

    return Column(
      key: ValueKey('balance-totals-$code'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _onHero(.14),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              code,
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: .4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                netLabel,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: _onHero(.78)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _HeroAmount(
              icon: Icons.south_west_rounded,
              label: 'Owed to you',
              amount: summary.owed,
              currency: code,
              color: _heroOwed,
              caption: _peopleCaption(
                summary.owedPeople,
                none: 'No one owes you',
                prefix: 'From',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _HeroAmount(
              icon: Icons.north_east_rounded,
              label: 'You owe',
              amount: summary.owe,
              currency: code,
              color: _heroOwe,
              caption: _peopleCaption(
                summary.owePeople,
                none: 'You owe no one',
                prefix: 'To',
              ),
            ),
          ),
        ]),
      ],
    );
  }
}

String _peopleCaption(int count,
        {required String none, required String prefix}) =>
    count == 0 ? none : '$prefix $count ${count == 1 ? 'person' : 'people'}';

class _HeroAmount extends StatelessWidget {
  const _HeroAmount({
    required this.icon,
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
    required this.caption,
  });

  final IconData icon;
  final String label;
  final double amount;
  final String currency;
  final Color color;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _onHero(.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: _onHero(.8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyText(
              amount,
              currencyCode: currency,
              color: color,
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 22),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(color: _onHero(.68)),
          ),
        ],
      ),
    );
  }
}

class _NothingOutstanding extends StatelessWidget {
  const _NothingOutstanding();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, color: scheme.owed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nothing outstanding',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'No one owes you, and you owe no one.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSecondaryContainer.withValues(alpha: .8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
