import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../widgets/app_drawer.dart';
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
                if (groups.isEmpty) {
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
                  itemCount: groups.length,
                  itemBuilder: (context, i) {
                    final group = groups[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _GroupRow(group: group),
                    );
                  },
                );
              },
            );
          }),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 19, 16, 9),
          sliver: SliverToBoxAdapter(
            child: SectionHeading('Invitations',
              subtitle: 'Groups waiting for your response.'),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: Consumer(builder: (context, ref, _) {
            final asyncInvites = ref.watch(groupInvitesProvider);
            return asyncInvites.when(
              loading: () => const SliverToBoxAdapter(
                child: ShimmerRows(count: 1)),
              error: (e, _) => SliverToBoxAdapter(
                child: LoadError.compact(
                  message: 'Could not load invites',
                  onRetry: () {
                    ref.invalidate(appRepositoryProvider);
                    ref.invalidate(groupInvitesProvider);
                  },
                ),
              ),
              data: (invites) {
                if (invites.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(2, 4, 2, 16),
                      child: Text('No pending group invitations.'),
                    ),
                  );
                }
                return SliverList.builder(
                  itemCount: invites.length,
                  itemBuilder: (itemContext, i) {
                    final group = invites[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _GroupInvitation(
                        group: group,
                        onJoin: () => runGuarded(
                          context,
                          () async =>
                            (await ref.read(appRepositoryProvider.future))
                              .acceptGroupInvite(group.id),
                          errorLabel: 'Could not join group',
                        ),
                        onDecline: () => runGuarded(
                          context,
                          () async =>
                            (await ref.read(appRepositoryProvider.future))
                              .declineGroupInvite(group.id),
                          errorLabel: 'Could not decline invitation',
                        ),
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
        tooltip: 'Create group',
        onPressed: () => _create(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group});
  final BillGroup group;

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

class _GroupInvitation extends StatelessWidget {
  const _GroupInvitation({
    required this.group, required this.onJoin, required this.onDecline,
  });
  final BillGroup group;
  final VoidCallback onJoin;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const PersonMark(initials: '',
            icon: Icons.mark_email_unread_outlined),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(group.name, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium),
              const Text('You are invited to join this group.'),
            ],
          )),
        ]),
        const SizedBox(height: 11),
        Wrap(spacing: 9, runSpacing: 7, children: [
          TextButton(onPressed: onDecline, child: const Text('Decline')),
          FilledButton(onPressed: onJoin, child: const Text('Join group')),
        ]),
      ],
    ));
  }
}
