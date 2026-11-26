import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../screens/bill_detail_screen.dart';
import '../theme.dart';
import '../utils/bill_position.dart';
import '../utils/current_user_identity.dart';
import '../utils/expense_icon.dart';
import '../utils/money.dart';
import 'money_text.dart';

/// A scannable expense summary: what it was, who is in it, the bill total, and
/// what it means for you right now (owed to you, owed by you, or settled).
class BillListTile extends ConsumerWidget {
  const BillListTile({super.key, required this.bill, required this.uid});

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
    final payerIds = bill.merchantPayments.entries
        .where((payment) => payment.value > 0.005)
        .map((payment) => payment.key)
        .toList();

    String personName(String payerUid) {
      if (payerUid == uid) return '${identity.name} (you)';
      for (final split in bill.splits) {
        if (split.uid == payerUid) return split.displayName;
      }
      return 'A participant';
    }

    final paidBy = !bill.hasPaymentLedger
        ? 'Recorded by ${bill.createdBy == uid ? "${identity.name} (you)" : bill.createdByName}'
        : payerIds.length == 1
            ? 'Paid by ${personName(payerIds.single)}'
            : 'Paid by ${payerIds.length} people';
    final radius = BorderRadius.circular(20);
    final metaStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        );

    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BillDetailScreen(billId: bill.id),
        )),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ExpenseHeading(bill: bill),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (bill.splits.isNotEmpty) ...[
                    _ParticipantStack(
                      names: [for (final split in bill.splits) split.displayName],
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(paidBy, style: metaStyle),
                        if (bill.createdAt != null)
                          Text(
                            DateFormat.MMMd().format(bill.createdAt!.toLocal()),
                            style: metaStyle,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: scheme.outlineVariant),
              ),
              _ExpenseSettlement(bill: bill, uid: uid),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseHeading extends StatelessWidget {
  const _ExpenseHeading({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(expenseIcon(bill.title),
              size: 24, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bill.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  )),
              const SizedBox(height: 4),
              Text(bill.groupName ?? 'Personal expense',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  )),
            ],
          ),
        ),
      ],
    );

    // The amount beside the title is the bill total; the settlement row below
    // says what it means for you, so no caption is needed on every tile.
    Widget total({required bool stacked}) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: stacked ? Alignment.centerLeft : Alignment.centerRight,
          child: MoneyText(bill.total,
              currencyCode: bill.currency,
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 20)),
        );

    return LayoutBuilder(builder: (context, constraints) {
      final stacked = constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(14) > 18.2;
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 12),
            total(stacked: true),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: title),
          const SizedBox(width: 12),
          SizedBox(width: 105, child: total(stacked: false)),
        ],
      );
    });
  }
}

/// Up to three overlapping initials, then "+N" for everyone else.
class _ParticipantStack extends StatelessWidget {
  const _ParticipantStack({required this.names});

  final List<String> names;

  static const _size = 26.0;
  static const _step = 17.0;
  static const _shown = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = names.take(_shown).toList();
    final extra = names.length - shown.length;
    final labels = [
      for (final name in shown) _initials(name),
      if (extra > 0) '+$extra',
    ];
    final fills = [
      scheme.primaryContainer,
      scheme.secondaryContainer,
      scheme.surfaceContainerHigh,
      scheme.surfaceContainer,
    ];
    return ExcludeSemantics(
      child: SizedBox(
        width: _size + (labels.length - 1) * _step,
        height: _size,
        child: Stack(
          children: [
            for (var i = 0; i < labels.length; i++)
              Positioned(
                left: i * _step,
                child: Container(
                  width: _size,
                  height: _size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fills[i % fills.length],
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: scheme.surfaceContainerLowest, width: 2),
                  ),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    // A fixed-size badge: larger system text must not
                    // push the initials out of the circle.
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

class _ExpenseSettlement extends StatelessWidget {
  const _ExpenseSettlement({required this.bill, required this.uid});

  final Bill bill;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settled = bill.fullySettled;
    final position = billPosition(bill, uid);
    final settlementTotal = bill.hasPaymentLedger
        ? bill.paymentDebts.fold(0.0, (total, debt) => total + debt.amount)
        : bill.splits.fold(0.0, (total, share) => total + share.amount);
    final progress = settled
        ? 1.0
        : settlementTotal > 0
            ? (1 - bill.outstanding / settlementTotal).clamp(0.0, 1.0)
            : 0.0;

    // What this expense means for you. The amounts follow the same rules as
    // the Home totals, so the tiles add up to them.
    final chips = <Widget>[
      if (settled)
        _StatusChip(
          icon: Icons.check_circle_rounded,
          label: 'Settled',
          color: scheme.owed,
        )
      else ...[
        if (position.owed > 0.004)
          _StatusChip(
            icon: Icons.south_west_rounded,
            label: "You're owed ${formatMoney(position.owed, bill.currency)}",
            color: scheme.owed,
          ),
        if (position.owe > 0.004)
          _StatusChip(
            icon: Icons.north_east_rounded,
            label: 'You owe ${formatMoney(position.owe, bill.currency)}',
            color: scheme.owe,
          ),
        if (position.owed <= 0.004 && position.owe <= 0.004)
          _StatusChip(
            icon: Icons.timelapse_rounded,
            label:
                '${formatMoney(bill.outstanding, bill.currency)} remaining',
            color: scheme.onSurfaceVariant,
          ),
      ],
    ];
    final status = Wrap(spacing: 8, runSpacing: 6, children: chips);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final stacked = constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(14) > 18.2;
          final share = Text(
            'Your share: ${formatMoney(bill.myShare(uid), bill.currency)}',
            textAlign: stacked ? TextAlign.start : TextAlign.end,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          );
          final participant = bill.participantIds.contains(uid);
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                status,
                if (participant) ...[
                  const SizedBox(height: 8),
                  share,
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: status),
              if (participant) ...[
                const SizedBox(width: 12),
                // Natural width, but never more than ~40% of the row, so a
                // very large amount wraps instead of squeezing the status.
                ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: constraints.maxWidth * .4),
                  child: share,
                ),
              ],
            ],
          );
        }),
        if (!settled && bill.splits.isNotEmpty) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: scheme.surfaceContainerHigh,
            color: scheme.primary,
            semanticsLabel: 'Settlement progress',
            semanticsValue: '${(progress * 100).round()}%',
          ),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
