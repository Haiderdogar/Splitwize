import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_notification_button.dart';
import '../widgets/state_widgets.dart';
import '../widgets/studio_ui.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';

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
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          sliver: SliverToBoxAdapter(
            child: SectionHeading('My groups'),
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
                final bills = ref.watch(myBillsProvider).value ??
                    const <Bill>[];
                final activity = <String, DateTime>{};
                final billCounts = <String, int>{};
                final unsettledCounts = <String, int>{};
                for (final bill in bills) {
                  final id = bill.groupId;
                  if (id == null) continue;
                  billCounts[id] = (billCounts[id] ?? 0) + 1;
                  if (!bill.fullySettled) {
                    unsettledCounts[id] = (unsettledCounts[id] ?? 0) + 1;
                  }
                  final date = bill.createdAt;
                  if (date != null &&
                      (activity[id] == null || date.isAfter(activity[id]!))) {
                    activity[id] = date;
                  }
                }
                final sortedGroups = [...groups]..sort((a, b) {
                  final aDate = activity[a.id] ?? a.createdAt ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final bDate = activity[b.id] ?? b.createdAt ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return bDate.compareTo(aDate);
                });
                if (sortedGroups.isEmpty) {
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
                  itemCount: sortedGroups.length,
                  itemBuilder: (context, i) {
                    final group = sortedGroups[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _GroupRow(
                        group: group,
                        billCount: billCounts[group.id] ?? 0,
                        openCount: unsettledCounts[group.id] ?? 0,
                      ),
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
  const _GroupRow({
    required this.group,
    required this.billCount,
    required this.openCount,
  });
  final BillGroup group;
  final int billCount;
  final int openCount;

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
            PersonMark(
              initials: group.name.trim().isEmpty
                  ? '?' : group.name.trim()[0].toUpperCase(), size: 50),
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
                const SizedBox(height: 3),
                Text(
                  billCount == 0
                      ? 'No expenses yet'
                      : openCount == 0
                          ? 'All expenses settled'
                          : '$openCount unsettled expense${openCount == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: openCount > 0 ? scheme.owe :
                        scheme.onSurfaceVariant),
                ),
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
