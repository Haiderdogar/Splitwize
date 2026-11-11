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
import 'studio_ui.dart';

class BillListTile extends ConsumerWidget {
  const BillListTile({super.key, required this.bill, required this.uid});
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
            const PersonMark(
                initials: '', icon: Icons.receipt_long_outlined, size: 46),
            const SizedBox(width: 11),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bill.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text('$detail · $paidBy',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                if (isOwner &&
                    bill.groupName == null &&
                    identity.email.isNotEmpty)
                  Text(identity.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Text(
                    bill.fullySettled
                        ? 'Settled'
                        : '${formatMoney(bill.outstanding, bill.currency)} remaining to settle',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: bill.fullySettled
                            ? scheme.owed
                            : scheme.onSurfaceVariant)),
              ],
            )),
            const SizedBox(width: 8),
            SizedBox(
                width: 94,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                        fit: BoxFit.scaleDown,
                        child: MoneyText(bill.total,
                            currencyCode: bill.currency,
                            style: Theme.of(context).textTheme.titleMedium)),
                    const SizedBox(height: 4),
                    Text('Total bill',
                        textAlign: TextAlign.end,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                    if (bill.participantIds.contains(uid))
                      Text(
                          'Your share: ${formatMoney(bill.myShare(uid), bill.currency)}',
                          textAlign: TextAlign.end,
                          maxLines: 2,
                          style: Theme.of(context).textTheme.labelSmall),
                    if (bill.createdAt != null)
                      Text(DateFormat.MMMd().format(bill.createdAt!),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                )),
          ]),
        ),
      ),
    );
  }
}
