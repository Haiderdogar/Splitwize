import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../utils/current_user_identity.dart';
import '../../utils/debt_simplifier.dart';
import '../../utils/money.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/studio_ui.dart';

/// The group's currency-separated settlement plan. Recording a suggestion
/// updates its underlying bill shares and keeps original expenses intact.
class GroupBalancesSection extends ConsumerStatefulWidget {
  const GroupBalancesSection({required this.groupId, super.key});
  final String groupId;

  @override
  ConsumerState<GroupBalancesSection> createState() =>
      _GroupBalancesSectionState();
}

class _GroupBalancesSectionState extends ConsumerState<GroupBalancesSection> {
  bool _busy = false;
  bool _saving = false;
  List<SplitAllocation>? _activeAllocations;

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(groupBillsProvider(widget.groupId));
    final plan = ref.watch(simplifiedDebtsProvider(widget.groupId));
    final myUid = ref.watch(currentUidProvider) ?? '';
    final google = ref.watch(authStateChangesProvider).value;
    final identity = resolveCurrentUserIdentity(
      cached: ref.watch(currentAppUserProvider).value,
      googleName: google?.displayName,
      googleEmail: google?.email,
    );
    return billsAsync.when(
      loading: () => const SliverToBoxAdapter(child: ShimmerRows(count: 2)),
      error: (e, _) => SliverToBoxAdapter(
        child: LoadError.compact(
          message: 'Could not load balances',
          onRetry: () {
            ref.invalidate(appRepositoryProvider);
            ref.invalidate(groupBillsProvider(widget.groupId));
          },
        ),
      ),
      data: (bills) {
        if (bills.isEmpty) {
          return const SliverToBoxAdapter(
            child: InlineEmpty(
              icon: Icons.account_balance_wallet_outlined,
              title: 'A fresh start',
              message: 'Add an expense to see who owes what in this group.',
            ),
          );
        }
        if (plan.isEmpty) {
          return const SliverToBoxAdapter(
            child: InlineEmpty(
              icon: Icons.check_circle_outline_rounded,
              title: 'Everyone is settled up',
              message: 'All shared expenses are covered. You are good to go.',
            ),
          );
        }
        final billsById = {for (final bill in bills) bill.id: bill};
        bool canRecord(Set<String> billIds, bool involvesMe) =>
            involvesMe &&
            billIds.every(
                (id) => billsById[id]?.participantIds.contains(myUid) ?? false);
        final entries = <_PlanEntry>[];
        for (final currency in plan.byCurrency) {
          if (plan.byCurrency.length > 1) {
            entries.add(_PlanEntry.currency(currency.currency));
          }
          for (final netting in currency.nettings) {
            entries.add(_PlanEntry.netting(
              netting,
              canRecord(netting.billIds, netting.involves(myUid)),
            ));
          }
          for (final transfer in currency.transfers) {
            entries.add(_PlanEntry.transfer(
              transfer,
              canRecord(transfer.billIds, transfer.involves(myUid)),
            ));
          }
        }
        String nameOf(String uid, String name) =>
            uid == myUid ? '${identity.name} (you)' : name;
        return SliverMainAxisGroup(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Settle up',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 5),
                  Text(
                    'A simpler way to square up. Record a payment after '
                    'the money has changed hands.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              if (entry.currency != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Text(currencyLabel(entry.currency!),
                      style: Theme.of(context).textTheme.titleSmall),
                );
              }
              final transfer = entry.transfer;
              final netting = entry.netting;
              final allocations = transfer?.allocations ?? netting!.allocations;
              final fromUid = transfer?.fromUid ?? netting!.aUid;
              final toUid = transfer?.toUid ?? netting!.bUid;
              final fromName =
                  nameOf(fromUid, transfer?.fromName ?? netting!.aName);
              final toName = nameOf(toUid, transfer?.toName ?? netting!.bName);
              final isNetting = netting != null;
              final relationship = isNetting
                  ? 'Mutual balance'
                  : fromUid == myUid
                      ? 'You pay'
                      : toUid == myUid
                          ? 'You receive'
                          : 'Group payment';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SettlementCard(
                  amount: transfer?.amount ?? netting!.amount,
                  currency: transfer?.currency ?? netting!.currency,
                  fromName: fromName,
                  toName: toName,
                  relationship: relationship,
                  isNetting: isNetting,
                  details: isNetting
                      ? 'These mutual debts cancel out. No payment is needed.'
                      : _settlesLabel(allocations),
                  canRecord: entry.canRecord,
                  busy: _busy,
                  active: _saving && identical(_activeAllocations, allocations),
                  onRecord: () => _recordSettlement(
                    allocations: allocations,
                    plan: plan,
                    isNetting: isNetting,
                    fromName: fromName,
                    toName: toName,
                    amount: transfer?.amount ?? netting!.amount,
                    currency: transfer?.currency ?? netting!.currency,
                  ),
                ),
              );
            },
          ),
        ]);
      },
    );
  }

  Future<void> _recordSettlement({
    required List<SplitAllocation> allocations,
    required GroupSettlementPlan plan,
    required bool isNetting,
    required String fromName,
    required String toName,
    required double amount,
    required String currency,
  }) async {
    // Partial allocations are additive: lock all actions before confirmation.
    if (_busy) return;
    setState(() {
      _busy = true;
      _activeAllocations = allocations;
    });
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(isNetting ? 'Clear mutual debts?' : 'Record settlement?'),
          content: Text(isNetting
              ? '$fromName and $toName owe each other. '
                  '${formatMoney(amount, currency)} cancels out on both sides. '
                  'This settles those shares without a payment.'
              : '$fromName pays $toName ${formatMoney(amount, currency)}.\n\n'
                  'Only confirm once the payment has been received. '
                  'This updates the related expense shares.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(isNetting ? 'Mark netted' : 'Mark settled'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      setState(() => _saving = true);
      final repo = await ref.read(appRepositoryProvider.future);
      if (!mounted) return;
      // Background changes while confirming require reviewing a fresh plan.
      if (!identical(ref.read(simplifiedDebtsProvider(widget.groupId)), plan)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Balances changed. Review the latest amounts and try again.'),
        ));
        return;
      }
      final touched = await repo.applySettlementAllocations(allocations);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${isNetting ? 'Mutual debts cleared' : 'Settlement recorded'}. '
              '$touched share${touched == 1 ? '' : 's'} updated.'),
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Could not ${isNetting ? 'clear mutual debts' : 'record settlement'}: $error'),
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _saving = false;
          _activeAllocations = null;
        });
      }
    }
  }
}

class _PlanEntry {
  const _PlanEntry._({
    this.currency,
    this.netting,
    this.transfer,
    this.canRecord = false,
  });
  factory _PlanEntry.currency(String code) => _PlanEntry._(currency: code);
  factory _PlanEntry.netting(NettedDebts netting, bool canRecord) =>
      _PlanEntry._(netting: netting, canRecord: canRecord);
  factory _PlanEntry.transfer(SimplifiedTransfer transfer, bool canRecord) =>
      _PlanEntry._(transfer: transfer, canRecord: canRecord);
  final String? currency;
  final NettedDebts? netting;
  final SimplifiedTransfer? transfer;
  final bool canRecord;
}

String _initialsOf(String name) {
  final parts = name
      .replaceFirst(RegExp(r'\s+\(you\)$'), '')
      .trim()
      .split(RegExp(r'\s+'));
  if (parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String _settlesLabel(List<SplitAllocation> allocations) {
  final shares = allocations.length;
  final bills =
      allocations.map((allocation) => allocation.billId).toSet().length;
  return 'Settles $shares share${shares == 1 ? '' : 's'} '
      'across $bills expense${bills == 1 ? '' : 's'}.';
}

class _SettlementCard extends StatelessWidget {
  const _SettlementCard({
    required this.amount,
    required this.currency,
    required this.fromName,
    required this.toName,
    required this.relationship,
    required this.isNetting,
    required this.details,
    required this.canRecord,
    required this.busy,
    required this.active,
    required this.onRecord,
  });
  final double amount;
  final String currency;
  final String fromName;
  final String toName;
  final String relationship;
  final bool isNetting;
  final String details;
  final bool canRecord;
  final bool busy;
  final bool active;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SoftPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
                isNetting ? Icons.swap_horiz_rounded : Icons.north_east_rounded,
                size: 18,
                color: scheme.primary),
            const SizedBox(width: 7),
            Expanded(
              child: Text(relationship,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: scheme.primary)),
            ),
            Text(currency,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 10),
          Text(formatMoney(amount, currency),
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          _SettlementPerson(
              label: isNetting ? 'Between' : 'From', name: fromName),
          const SizedBox(height: 12),
          _SettlementPerson(label: isNetting ? 'And' : 'To', name: toName),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          Text(details,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          if (canRecord) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: busy ? null : onRecord,
                icon: busy && active
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isNetting
                            ? Icons.swap_horiz_rounded
                            : Icons.check_rounded,
                        size: 19),
                label: Text(isNetting ? 'Mark netted' : 'Mark settled'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text('An eligible payer or receiver can record this settlement.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _SettlementPerson extends StatelessWidget {
  const _SettlementPerson({required this.label, required this.name});
  final String label;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PersonMark(initials: _initialsOf(name), size: 36),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(name, style: theme.textTheme.titleSmall),
        ]),
      ),
    ]);
  }
}
