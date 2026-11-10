import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/current_user_identity.dart';
import '../widgets/money_text.dart';
import '../widgets/split_bar.dart';
import '../widgets/state_widgets.dart';
import 'bills_tab.dart' show formatMoney;

/// Bill details with per-person settlement tracking.
/// The debtor can mark their own share paid; the creator can mark anyone's.
class BillDetailScreen extends StatelessWidget {
  const BillDetailScreen({required this.billId, super.key});

  final String billId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bill details')),
      // Only this subtree reacts to the bill stream.
      body: Consumer(
        builder: (context, ref, _) {
          final billAsync = ref.watch(billProvider(billId));
          final myUid = ref.watch(currentUidProvider) ?? '';
          final google = ref.watch(authStateChangesProvider).value;
          final identity = resolveCurrentUserIdentity(
            cached: ref.watch(currentAppUserProvider).value,
            googleName: google?.displayName,
            googleEmail: google?.email,
          );
          return billAsync.when(
            loading: () => const ShimmerDetail(),
            error: (e, _) => LoadError(
              message: 'Could not load this bill.',
              onRetry: () => ref.invalidate(billProvider(billId)),
            ),
            data: (bill) {
              if (bill == null) {
                return const Center(child: Text('Bill not found.'));
              }
              return _BillBody(
                bill: bill,
                myUid: myUid,
                myIdentity: identity,
                onTogglePaid: (uid, paid) async {
                  final repo = await ref.read(appRepositoryProvider.future);
                  await repo.setSplitPaid(
                      billId: bill.id, uid: uid, paid: paid);
                },
                onToggleDebt: (debt, settled) async {
                  final repo = await ref.read(appRepositoryProvider.future);
                  await repo.setPaymentDebtSettled(
                    billId: bill.id,
                    debtId: debt.id,
                    settledAmount: settled ? debt.amount : 0,
                  );
                },
                onRemoveReceipt: () async {
                  final repo = await ref.read(appRepositoryProvider.future);
                  await repo.removeReceiptPhoto(bill.id);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _BillBody extends StatelessWidget {
  const _BillBody({
    required this.bill,
    required this.myUid,
    required this.myIdentity,
    required this.onTogglePaid,
    required this.onToggleDebt,
    required this.onRemoveReceipt,
  });

  final Bill bill;
  final String myUid;
  final CurrentUserIdentity myIdentity;
  final Future<void> Function(String uid, bool paid) onTogglePaid;
  final Future<void> Function(BillDebt debt, bool settled) onToggleDebt;
  final Future<void> Function() onRemoveReceipt;

  @override
  Widget build(BuildContext context) {
    final isCreator = bill.createdBy == myUid;
    final debtsTotal =
        bill.paymentDebts.fold<double>(0, (sum, d) => sum + d.amount);
    final progress = bill.hasPaymentLedger
        ? (debtsTotal == 0 ? 1.0
            : (1 - bill.outstanding / debtsTotal).clamp(0.0, 1.0))
        : (bill.splits.isEmpty ? 0.0 : bill.paidCount / bill.splits.length);

    // Slivers + a builder list: share tiles are built lazily,
    // only for what's on screen.
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      bill.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _KVRow(
                        label: 'Subtotal',
                        value: formatMoney(bill.subtotal, bill.currency)),
                    if (bill.tipPercent > 0)
                      _KVRow(
                          label: 'Tip (${bill.tipPercent.toStringAsFixed(0)}%)',
                          value: formatMoney(
                              bill.total - bill.subtotal, bill.currency)),
                    const Divider(),
                    _KVRow(
                        label: 'Total',
                        valueWidget: MoneyText(
                          bill.total,
                          currencyCode: bill.currency,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        bold: true),
                    const SizedBox(height: 12),
                    Text(
                      bill.fullySettled
                          ? 'Fully settled 🎉'
                          : bill.hasPaymentLedger
                              ? '${formatMoney(bill.outstanding, bill.currency)} '
                                  'still to settle between friends'
                              : '${bill.paidCount} of ${bill.splits.length} paid • '
                                  '${formatMoney(bill.outstanding, bill.currency)} outstanding',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(label: Text(bill.splitTypeLabel)),
                        if (bill.groupName != null)
                          Chip(label: Text(bill.groupName!)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Created by ${bill.createdBy == myUid ? '${myIdentity.name} (you)' : bill.createdByName}'
                      '${bill.createdAt != null ? ' • ${DateFormat.yMMMd().format(bill.createdAt!)}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (bill.hasPaymentLedger) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text('Paid at the restaurant',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Card(child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(children: [
                  for (final split in bill.splits)
                    if ((bill.merchantPayments[split.uid] ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          Expanded(child: Text(split.uid == myUid
                              ? '${myIdentity.name} (you)' : split.displayName,
                              maxLines: 2, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 10),
                          MoneyText(bill.merchantPayments[split.uid]!,
                              currencyCode: bill.currency),
                        ]),
                      ),
                ]),
              )),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text('Who owes whom',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),
          if (bill.paymentDebts.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Text('Everyone already covered their own share.'),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemCount: bill.paymentDebts.length,
                itemBuilder: (context, i) => _PaymentDebtTile(
                  debt: bill.paymentDebts[i],
                  currency: bill.currency,
                  myUid: myUid,
                  myIdentity: myIdentity,
                  canUpdate: isCreator ||
                      bill.paymentDebts[i].debtorUid == myUid ||
                      bill.paymentDebts[i].creditorUid == myUid,
                  onToggle: onToggleDebt,
                ),
              ),
            ),
        ],
        if (bill.receiptImageUrl != null || bill.receiptLocalPath != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _ReceiptCard(
                bill: bill,
                // Only the creator manages the photo — it counts
                // against their receipt quota.
                onRemove: isCreator ? onRemoveReceipt : null,
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Shares',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          sliver: SliverToBoxAdapter(
            // The split motif: each share's width is its proportion of
            // the total; the rows below are the legend.
            child: SplitBar(
              segments: [
                for (var i = 0; i < bill.splits.length; i++)
                  SplitSegment(
                    label: bill.splits[i].uid == myUid
                        ? myIdentity.name : bill.splits[i].displayName,
                    value: bill.splits[i].amount,
                    color: splitHues[i % splitHues.length],
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: bill.splits.length,
            itemBuilder: (itemContext, i) => _SplitTile(
              split: bill.splits[i],
              myUid: myUid,
              myIdentity: myIdentity,
              isCreator: isCreator,
              currencyCode: bill.currency,
              usesPaymentLedger: bill.hasPaymentLedger,
              onTogglePaid: onTogglePaid,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}

/// A real transfer between a debtor and the person who fronted money.
class _PaymentDebtTile extends StatelessWidget {
  const _PaymentDebtTile({
    required this.debt,
    required this.currency,
    required this.myUid,
    required this.myIdentity,
    required this.canUpdate,
    required this.onToggle,
  });

  final BillDebt debt;
  final String currency;
  final String myUid;
  final CurrentUserIdentity myIdentity;
  final bool canUpdate;
  final Future<void> Function(BillDebt debt, bool settled) onToggle;

  @override
  Widget build(BuildContext context) {
    final debtorName = debt.debtorUid == myUid
        ? '${myIdentity.name} (you)' : debt.debtorName;
    final creditorName = debt.creditorUid == myUid
        ? '${myIdentity.name} (you)' : debt.creditorName;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$debtorName owes $creditorName',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall),
          if (myIdentity.email.isNotEmpty &&
              (debt.debtorUid == myUid || debt.creditorUid == myUid))
            Text(myIdentity.email, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 5),
          Text(debt.isSettled
              ? 'Settled'
              : '${formatMoney(debt.remainingAmount, currency)} remaining',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 7),
          Row(children: [
            Expanded(child: MoneyText(debt.amount,
                currencyCode: currency)),
            if (canUpdate)
              TextButton(
                onPressed: () async {
                  try {
                    await onToggle(debt, !debt.isSettled);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not update: $e')),
                      );
                    }
                  }
                },
                child: Text(debt.isSettled ? 'Undo' : 'Mark settled'),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _KVRow extends StatelessWidget {
  const _KVRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.bold = false,
  }) : assert(value != null || valueWidget != null);

  final String label;

  /// Plain value text; ignored when [valueWidget] is given.
  final String? value;

  /// Rich value (e.g. [MoneyText]) replacing the plain text.
  final Widget? valueWidget;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // The label flexes; the amount always gets its full width.
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          valueWidget ?? Text(value!, style: style),
        ],
      ),
    );
  }
}

class _SplitTile extends StatelessWidget {
  const _SplitTile({
    required this.split,
    required this.myUid,
    required this.myIdentity,
    required this.isCreator,
    required this.currencyCode,
    required this.usesPaymentLedger,
    required this.onTogglePaid,
  });

  final BillSplit split;
  final String myUid;
  final CurrentUserIdentity myIdentity;
  final bool isCreator;
  final String currencyCode;
  final bool usesPaymentLedger;
  final Future<void> Function(String uid, bool paid) onTogglePaid;

  bool get _isMine => split.uid == myUid;
  bool get _canToggle => _isMine || isCreator;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: split.paid
          ? colorScheme.primaryContainer.withValues(alpha: 0.4)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              child: Text(_isMine ? myIdentity.initials[0]
                  : split.displayName.isEmpty ? '?'
                  : split.displayName[0].toUpperCase()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isMine ? '${myIdentity.name} (you)' : split.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (_isMine && myIdentity.email.isNotEmpty)
                    Text(myIdentity.email, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                  // Wrap (not Row): percent, chip and date flow to a
                  // second line on narrow screens instead of
                  // overflowing.
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (split.percent != null)
                        Text('${split.percent!.toStringAsFixed(1)}%  •  '),
                      if (usesPaymentLedger)
                        const Text('Share of expense')
                      else Chip(
                        label: Text(split.paid
                            ? 'Paid'
                            : split.isPartiallyPaid
                                ? 'Partly paid'
                                : 'Unpaid'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: split.paid
                            ? colorScheme.owed.withValues(alpha: 0.2)
                            : colorScheme.owe.withValues(alpha: 0.2),
                      ),
                      if (split.isPartiallyPaid)
                        Text(
                          '${formatMoney(split.settledAmount, currencyCode)} settled • '
                          '${formatMoney(split.remainingAmount, currencyCode)} left',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (split.paid && split.paidAt != null)
                        Text(
                          DateFormat.MMMd().format(split.paidAt!),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            MoneyText(
              split.amount,
              currencyCode: currencyCode,
            ),
            if (_canToggle && !usesPaymentLedger)
              TextButton(
                onPressed: () async {
                  try {
                    await onTogglePaid(split.uid, !split.paid);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not update: $e')),
                      );
                    }
                  }
                },
                child: Text(split.paid
                    ? 'Undo'
                    : (_isMine ? 'Mark paid' : 'Mark received')),
              ),
          ],
        ),
      ),
    );
  }
}

/// The optional receipt photo. Shows the Firebase Storage image once
/// synced; before that, the creator's device shows the local file with
/// an "uploads when online" note. Tap to view full-screen. The
/// creator can remove the photo; [onRemove] is null for everyone else.
class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.bill, this.onRemove});

  final Bill bill;
  final Future<void> Function()? onRemove;

  @override
  Widget build(BuildContext context) {
    final url = bill.receiptImageUrl;
    final localPath = bill.receiptLocalPath;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _showFull(context),
            child: url != null
                ? Image.network(
                    url,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : const ShimmerBlock(height: 180),
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 120,
                      child: Center(child: Icon(Icons.broken_image_outlined)),
                    ),
                  )
                : Image.file(
                    File(localPath!),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 120,
                      child: Center(child: Icon(Icons.broken_image_outlined)),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    url != null
                        ? 'Receipt photo'
                        : 'Receipt photo — uploads when online',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove photo',
                    onPressed: () => _confirmRemove(context),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove receipt photo?'),
        content: const Text(
          'The photo will be removed from this bill for everyone. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await runGuarded(
        context,
        onRemove!,
        errorLabel: 'Could not remove the photo',
      );
    }
  }

  void _showFull(BuildContext context) {
    final url = bill.receiptImageUrl;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: url != null
              ? Image.network(url, fit: BoxFit.contain)
              : Image.file(File(bill.receiptLocalPath!), fit: BoxFit.contain),
        ),
      ),
    );
  }
}
