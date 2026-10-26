import 'package:currency_picker/currency_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../providers/form_providers.dart';
import '../utils/debt_simplifier.dart';
import '../widgets/state_widgets.dart';
import 'bill_detail_screen.dart';
import 'bills_tab.dart' show currencyLabel, formatMoney;

/// The group's currency row: shows the current currency and lets any
/// member change it (existing bills keep their own currency; only new
/// bills use the new one). Applies locally at once, syncs in the
/// background.
class _GroupCurrencyTile extends StatelessWidget {
  const _GroupCurrencyTile({required this.group});

  final BillGroup group;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Card(
        child: ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: const Text('Group currency'),
          subtitle: Text('${currencyLabel(group.currency)} — tap to change'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showCurrencyPicker(
            context: context,
            showFlag: true,
            favorite: const ['PKR', 'USD', 'EUR', 'GBP', 'AED', 'SAR', 'INR'],
            onSelect: (c) async {
              try {
                final repo = await ref.read(appRepositoryProvider.future);
                await repo.setGroupCurrency(group.id, c.code);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Group currency changed to ${c.code}. New bills will use it.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not change currency: $e')),
                  );
                }
              }
            },
          ),
        ),
      ),
    );
  }
}

class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group')),
      // Only this subtree reacts to the group stream.
      body: Consumer(
        builder: (context, ref, _) {
          final groupAsync = ref.watch(groupProvider(groupId));
          return groupAsync.when(
            loading: () => const ShimmerDetail(),
            error: (e, _) => LoadError(
              message: 'Could not load this group.',
              onRetry: () {
                ref.invalidate(appRepositoryProvider);
                ref.invalidate(groupProvider(groupId));
              },
            ),
            data: (group) => group == null
                ? const Center(child: Text('Group not found.'))
                : _GroupBody(group: group),
          );
        },
      ),
    );
  }
}

class _GroupBody extends StatelessWidget {
  const _GroupBody({required this.group});

  final BillGroup group;

  @override
  Widget build(BuildContext context) {
    // Slivers + builder lists: member/invitee/bill rows are built
    // lazily, only for what's on screen.
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _GroupCurrencyTile(group: group),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Members (${group.members.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Invite button needs connection state.
                    Consumer(
                      builder: (context, ref, _) {
                        final conns =
                            ref.watch(connectionsProvider).value ?? [];
                        final myUid = ref.watch(currentUidProvider) ?? '';
                        final candidates = conns
                            .where((c) =>
                                !group.members.contains(c.uid) &&
                                !group.invited.contains(c.uid))
                            .toList();
                        return TextButton.icon(
                          onPressed: candidates.isEmpty
                              ? () =>
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'No more connected friends to invite.')),
                                  )
                              : () => showDialog(
                                    context: context,
                                    builder: (_) => _InviteDialog(
                                      group: group,
                                      candidates: candidates,
                                      myUid: myUid,
                                    ),
                                  ),
                          icon: const Icon(Icons.person_add),
                          label: const Text('Invite'),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Only the member list reacts to member state.
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: Consumer(
            builder: (context, ref, _) {
              final membersAsync = ref.watch(groupMembersProvider(group.id));
              final myUid = ref.watch(currentUidProvider) ?? '';
              return membersAsync.when(
                loading: () =>
                    const SliverToBoxAdapter(child: ShimmerRows(count: 3)),
                error: (e, _) => SliverToBoxAdapter(
                  child: LoadError.compact(
                    message: 'Could not load members',
                    onRetry: () {
                      ref.invalidate(appRepositoryProvider);
                      ref.invalidate(groupMembersProvider(group.id));
                    },
                  ),
                ),
                data: (members) => SliverList.builder(
                  itemCount: members.length,
                  itemBuilder: (itemContext, i) {
                    final m = members[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text(m.initials)),
                      title: Text(m.uid == myUid
                          ? '${m.displayName} (you)'
                          : m.displayName),
                      subtitle: Text(m.email),
                    );
                  },
                ),
              );
            },
          ),
        ),
        if (group.invited.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Pending invites (${group.invited.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: _InvitedList(group: group),
          ),
        ],
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: _SimplifyDebtsSection(groupId: group.id),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Bills in this group',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: _GroupBills(groupId: group.id),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}

class _InvitedList extends StatelessWidget {
  const _InvitedList({required this.group});

  final BillGroup group;

  @override
  Widget build(BuildContext context) {
    // Backed by invitedUsersProvider — cached, no per-rebuild refetch.
    return Consumer(
      builder: (context, ref, _) {
        final invitedAsync = ref.watch(invitedUsersProvider(group.id));
        return invitedAsync.when(
          loading: () => const SliverToBoxAdapter(child: ShimmerRows(count: 2)),
          error: (e, _) => SliverToBoxAdapter(
            child: LoadError.compact(
              message: 'Could not load invitees',
              onRetry: () {
                ref.invalidate(appRepositoryProvider);
                ref.invalidate(invitedUsersProvider(group.id));
              },
            ),
          ),
          data: (invited) => SliverList.builder(
            itemCount: invited.length,
            itemBuilder: (itemContext, i) {
              final m = invited[i];
              return ListTile(
                leading: CircleAvatar(child: Text(m.initials)),
                title: Text(m.displayName),
                trailing: const Chip(label: Text('Invited')),
              );
            },
          ),
        );
      },
    );
  }
}

class _GroupBills extends StatelessWidget {
  const _GroupBills({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    // Only this list reacts to the group's bills.
    return Consumer(
      builder: (context, ref, _) {
        final billsAsync = ref.watch(groupBillsProvider(groupId));
        return billsAsync.when(
          loading: () => const SliverToBoxAdapter(child: ShimmerRows(count: 2)),
          error: (e, _) => SliverToBoxAdapter(
            child: LoadError.compact(
              message: 'Could not load bills',
              onRetry: () {
                ref.invalidate(appRepositoryProvider);
                ref.invalidate(groupBillsProvider(groupId));
              },
            ),
          ),
          data: (bills) {
            if (bills.isEmpty) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No bills split in this group yet.'),
                ),
              );
            }
            return SliverList.builder(
              itemCount: bills.length,
              itemBuilder: (itemContext, i) {
                final b = bills[i];
                return Card(
                  child: ListTile(
                    title: Text(b.title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle:
                        Text('${b.splits.length} people • ${b.splitTypeLabel}'),
                    trailing: Text(
                      formatMoney(b.total, b.currency),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    onTap: () => Navigator.of(itemContext).push(
                      MaterialPageRoute(
                        builder: (_) => BillDetailScreen(billId: b.id),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// "Simplify debts" — the fewest payments that settle the group's
/// open bills, computed on-device from the group's bills (per
/// currency) by [simplifyGroupDebts]. Recording a payment reuses the
/// mark-paid machinery on the underlying bill shares, so the bills
/// themselves never change shape.
///
/// The record button is only offered to the payment's payer or
/// receiver, and only when they participate in every bill the
/// payment touches — Firestore lets participants (and only
/// participants) update a bill, so anyone else sees the suggestion
/// read-only.
class _SimplifyDebtsSection extends StatelessWidget {
  const _SimplifyDebtsSection({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final billsAsync = ref.watch(groupBillsProvider(groupId));
        final myUid = ref.watch(currentUidProvider) ?? '';
        return billsAsync.when(
          loading: () => const SliverToBoxAdapter(child: ShimmerRows(count: 2)),
          error: (e, _) => SliverToBoxAdapter(
            child: LoadError.compact(
              message: 'Could not load debts',
              onRetry: () {
                ref.invalidate(appRepositoryProvider);
                ref.invalidate(groupBillsProvider(groupId));
              },
            ),
          ),
          data: (bills) {
            if (bills.isEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }
            final plan = simplifyGroupDebts(bills);
            final billsById = {for (final b in bills) b.id: b};
            bool canRecord(Set<String> billIds, bool involvesMe) =>
                involvesMe &&
                billIds.every((id) =>
                    billsById[id]?.participantIds.contains(myUid) ?? false);
            final entries = <_PlanEntry>[];
            for (final c in plan.byCurrency) {
              if (plan.byCurrency.length > 1) {
                entries.add(_PlanEntry.currency(c.currency));
              }
              for (final n in c.nettings) {
                entries.add(_PlanEntry.netting(
                  n,
                  canRecord(n.billIds, n.involves(myUid)),
                ));
              }
              for (final t in c.transfers) {
                entries.add(_PlanEntry.transfer(
                  t,
                  canRecord(t.billIds, t.involves(myUid)),
                ));
              }
            }
            return SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.alt_route, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Simplify debts',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'The fewest payments that settle this group — '
                        'computed on-device, per currency.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                if (entries.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text('Everyone is settled up in this group 🎉'),
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: entries.length,
                    itemBuilder: (itemContext, i) {
                      final e = entries[i];
                      return switch (e.kind) {
                        _PlanEntryKind.currency => Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Text(
                              currencyLabel(e.currency!),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        _PlanEntryKind.netting => _NettingTile(
                            netting: e.netting!,
                            myUid: myUid,
                            canRecord: e.canRecord,
                            onRecord: () =>
                                _recordNetting(itemContext, ref, e.netting!),
                          ),
                        _PlanEntryKind.transfer => _TransferTile(
                            transfer: e.transfer!,
                            myUid: myUid,
                            canRecord: e.canRecord,
                            onRecord: () =>
                                _recordTransfer(itemContext, ref, e.transfer!),
                          ),
                      };
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _recordTransfer(
      BuildContext context, WidgetRef ref, SimplifiedTransfer t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record settlement?'),
        content: Text(
          '${t.fromName} pays ${t.toName} ${formatMoney(t.amount, t.currency)}.\n\n'
          'This marks the underlying bill shares as paid — the bills '
          'themselves don\'t change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Mark settled'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final repo = await ref.read(appRepositoryProvider.future);
      final touched = await repo.applySettlementAllocations(t.allocations);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Settlement recorded — $touched share${touched == 1 ? '' : 's'} updated.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not record settlement: $e')),
        );
      }
    }
  }

  Future<void> _recordNetting(
      BuildContext context, WidgetRef ref, NettedDebts n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Net mutual debts?'),
        content: Text(
          '${n.aName} and ${n.bName} owe each other — '
          '${formatMoney(n.amount, n.currency)} cancels out on both '
          'sides. No money needs to move; the shares on both sides '
          'are marked settled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Mark netted'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final repo = await ref.read(appRepositoryProvider.future);
      final touched = await repo.applySettlementAllocations(n.allocations);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Mutual debts netted — $touched share${touched == 1 ? '' : 's'} updated.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not net debts: $e')),
        );
      }
    }
  }
}

enum _PlanEntryKind { currency, netting, transfer }

/// One row of the settlement plan list.
class _PlanEntry {
  const _PlanEntry._(this.kind,
      {this.currency, this.netting, this.transfer, this.canRecord = false});

  factory _PlanEntry.currency(String code) =>
      _PlanEntry._(_PlanEntryKind.currency, currency: code);
  factory _PlanEntry.netting(NettedDebts n, bool canRecord) =>
      _PlanEntry._(_PlanEntryKind.netting, netting: n, canRecord: canRecord);
  factory _PlanEntry.transfer(SimplifiedTransfer t, bool canRecord) =>
      _PlanEntry._(_PlanEntryKind.transfer, transfer: t, canRecord: canRecord);

  final _PlanEntryKind kind;
  final String? currency;
  final NettedDebts? netting;
  final SimplifiedTransfer? transfer;
  final bool canRecord;
}

String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String _named(String uid, String name, String myUid) =>
    uid == myUid ? '$name (you)' : name;

/// "Settles 3 shares across 2 bills" for a plan entry.
String _settlesLabel(List<SplitAllocation> allocations) {
  final shares = allocations.length;
  final bills = allocations.map((a) => a.billId).toSet().length;
  return 'Settles $shares share${shares == 1 ? '' : 's'} '
      'across $bills bill${bills == 1 ? '' : 's'}';
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({
    required this.transfer,
    required this.myUid,
    required this.canRecord,
    required this.onRecord,
  });

  final SimplifiedTransfer transfer;
  final String myUid;
  final bool canRecord;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final t = transfer;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(_initialsOf(t.fromName))),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 18),
                const SizedBox(width: 8),
                CircleAvatar(child: Text(_initialsOf(t.toName))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _named(t.fromUid, t.fromName, myUid),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'pays ${_named(t.toUid, t.toName, myUid)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatMoney(t.amount, t.currency),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _settlesLabel(t.allocations),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                if (canRecord)
                  FilledButton.tonal(
                    onPressed: onRecord,
                    child: const Text('Mark settled'),
                  ),
              ],
            ),
            if (!canRecord)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'The payer or receiver records this once it\'s paid.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NettingTile extends StatelessWidget {
  const _NettingTile({
    required this.netting,
    required this.myUid,
    required this.canRecord,
    required this.onRecord,
  });

  final NettedDebts netting;
  final String myUid;
  final bool canRecord;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final n = netting;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(_initialsOf(n.aName))),
                const SizedBox(width: 8),
                const Icon(Icons.swap_horiz, size: 18),
                const SizedBox(width: 8),
                CircleAvatar(child: Text(_initialsOf(n.bName))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _named(n.aUid, n.aName, myUid),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'and ${_named(n.bUid, n.bName, myUid)} owe each other',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatMoney(n.amount, n.currency),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cancels out — no payment needed',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                if (canRecord)
                  FilledButton.tonal(
                    onPressed: onRecord,
                    child: const Text('Mark netted'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Invite dialog: selection lives in [GroupInviteSelection] so no
/// StatefulWidget is needed.
class _InviteDialog extends StatelessWidget {
  const _InviteDialog({
    required this.group,
    required this.candidates,
    required this.myUid,
  });

  final BillGroup group;
  final List<AppUser> candidates;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite friends'),
      content: SizedBox(
        width: double.maxFinite,
        // Cap the checklist height so the dialog always fits the
        // screen; the list scrolls internally past the cap.
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.45,
          ),
          child: Consumer(
            builder: (context, ref, _) {
              final selected = ref.watch(groupInviteSelectionProvider);
              final notifier = ref.read(groupInviteSelectionProvider.notifier);
              return ListView.builder(
                shrinkWrap: true,
                itemCount: candidates.length,
                itemBuilder: (itemContext, i) {
                  final c = candidates[i];
                  return CheckboxListTile(
                    value: selected.contains(c.uid),
                    onChanged: (v) => notifier.toggle(c.uid, v ?? false),
                    secondary: CircleAvatar(child: Text(c.initials)),
                    title: Text(c.displayName),
                  );
                },
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        // Only the button reacts to selection state.
        Consumer(
          builder: (context, ref, _) {
            final selected = ref.watch(groupInviteSelectionProvider);
            return FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () async {
                      try {
                        final repo =
                            await ref.read(appRepositoryProvider.future);
                        await repo.inviteToGroup(group.id, selected.toList());
                        for (final uid in selected) {
                          await repo.sendNotification(
                            toUid: uid,
                            title: 'Group invite',
                            body: 'You were invited to join "${group.name}".',
                            type: 'group_invite',
                            groupId: group.id,
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Could not send invites: $e')),
                          );
                        }
                        return;
                      }
                      ref.read(groupInviteSelectionProvider.notifier).clear();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invites sent.')),
                        );
                      }
                    },
              child: const Text('Send invites'),
            );
          },
        ),
      ],
    );
  }
}
