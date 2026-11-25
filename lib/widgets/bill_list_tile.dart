import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../screens/bill_detail_screen.dart';
import '../theme.dart';
import '../utils/current_user_identity.dart';
import '../utils/money.dart';
import 'money_text.dart';

/// A scannable expense summary, with the bill total separate from your share.
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
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(paidBy,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          )),
                  if (bill.createdAt != null)
                    Text(
                      DateFormat.yMMMd().format(bill.createdAt!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
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
          width: 42,
          height: 46,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(Icons.receipt_long_outlined,
              size: 22, color: scheme.primary),
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
    // labels "Your share", so no caption is needed on every tile.
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

class _ExpenseSettlement extends StatelessWidget {
  const _ExpenseSettlement({required this.bill, required this.uid});

  final Bill bill;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settled = bill.fullySettled;
    final statusColor = settled ? scheme.owed : scheme.onSurface;
    final settlementTotal = bill.hasPaymentLedger
        ? bill.paymentDebts.fold(0.0, (total, debt) => total + debt.amount)
        : bill.splits.fold(0.0, (total, share) => total + share.amount);
    final progress = settled
        ? 1.0
        : settlementTotal > 0
            ? (1 - bill.outstanding / settlementTotal).clamp(0.0, 1.0)
            : 0.0;
    final status = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            settled ? Icons.check_circle_rounded : Icons.timelapse_rounded,
            size: 16,
            color: settled ? scheme.owed : scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
              settled
                  ? 'Settled'
                  : '${formatMoney(bill.outstanding, bill.currency)} remaining',
              style: theme.textTheme.labelMedium?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              )),
        ),
      ],
    );

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
              color: scheme.onSurface,
            ),
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                status,
                if (bill.participantIds.contains(uid)) ...[
                  const SizedBox(height: 8),
                  share,
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: status),
              if (bill.participantIds.contains(uid)) ...[
                const SizedBox(width: 12),
                Expanded(child: share),
              ],
            ],
          );
        }),
        if (!settled && bill.splits.isNotEmpty) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 3,
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
