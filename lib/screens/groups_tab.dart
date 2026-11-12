import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../providers/invitation_providers.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_notification_button.dart';
import '../widgets/invitation_button.dart';
import '../widgets/state_widgets.dart';
import '../widgets/studio_ui.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';
import 'request_screens.dart';

class GroupsTab extends StatelessWidget {
  const GroupsTab({super.key});

  void _create(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const CreateGroupScreen()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const SplitwizeMenuButton(),
        title: const Text('Groups'),
        actions: const [AppNotificationButton(), SizedBox(width: 5)],
      ),
      body: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Consumer(builder: (context, ref, _) {
              final incoming =
                  ref.watch(groupInvitesProvider).value?.length ?? 0;
              final outgoing =
                  ref.watch(outgoingGroupInvitesProvider).value?.length ?? 0;
              return SectionHeading(
                'My groups',
                trailing: InvitationButton(
                  count: incoming + outgoing,
                  tooltip: 'Group invitations',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const GroupRequestsScreen())),
                ),
              );
            }),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: Consumer(builder: (context, ref, _) {
            final asyncGroups = ref.watch(myGroupsProvider);
            return asyncGroups.when(
              loading: () => const SliverToBoxAdapter(
                child: ShimmerRows(count: 3)),
              error: (e, _) => SliverToBoxAdapter(
                child: LoadError.compact(
                  message: 'Could not load groups',
                  onRetry: () {
                    ref.invalidate(appRepositoryProvider);
                    ref.invalidate(myGroupsProvider);
                  },
                ),
              ),
              data: (groups) {
                final bills = ref.watch(myBillsProvider).value;
                final groupBills = <String, List<Bill>>{};
                for (final bill in bills ?? <Bill>[]) {
                  if (bill.groupId != null) {
                    (groupBills[bill.groupId!] ??= <Bill>[]).add(bill);
                  }
                }
                DateTime lastActivity(BillGroup group) {
                  final entries = groupBills[group.id] ?? const <Bill>[];
                  var recent = group.createdAt ?? DateTime(1970);
                  for (final bill in entries) {
                    final when = bill.createdAt;
                    if (when != null && when.isAfter(recent)) recent = when;
                  }
                  return recent;
                }
                final ordered = [...groups]
                  ..sort((a, b) => lastActivity(b).compareTo(lastActivity(a)));
                if (ordered.isEmpty) {
                  return SliverToBoxAdapter(child: InlineEmpty(
                    icon: Icons.groups_outlined,
                    title: 'No groups yet',
                    message: 'Make a group for a trip, flat or project.',
                    action: FilledButton(
                      onPressed: () => _create(context),
                      child: const Text('Create your first group'),
                    ),
                  ));
                }
                return SliverList.builder(
                  itemCount: ordered.length,
                  itemBuilder: (context, i) {
                    final group = ordered[i];
                    final entries = groupBills[group.id] ?? const <Bill>[];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _GroupRow(group: group,
                        totalBills: bills == null ? null : entries.length,
                        unsettledBills: entries.where((bill) => !bill.fullySettled).length),
                    );
                  },
                );
              },
            );
          }),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 26)),
      ]),
      floatingActionButton: FloatingActionButton(
        heroTag: 'groups-create-group',
        tooltip: 'Create group',
        onPressed: () => _create(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, this.totalBills, required this.unsettledBills});
  final BillGroup group;
  final int? totalBills;
  final int unsettledBills;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: BorderSide(color: scheme.outlineVariant)),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => GroupDetailScreen(groupId: group.id))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
          child: Row(children: [
            const PersonMark(initials: '',
              icon: Icons.groups_rounded, size: 50),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 5),
                Text(
                  '${group.members.length} ${group.members.length == 1 ? 'member' : 'members'} · ${group.currency}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant)),
                if (totalBills != null) ...[
                  const SizedBox(height: 3),
                  Text(totalBills == 0 ? 'No expenses yet' :
                    unsettledBills == 0 ? 'All settled' :
                    '$unsettledBills unsettled ${unsettledBills == 1 ? 'expense' : 'expenses'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant)),
                ],
              ],
            )),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}
