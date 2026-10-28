import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../widgets/state_widgets.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';

class GroupsTab extends StatelessWidget {
  const GroupsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      // Slivers + builder lists: cards are built lazily, only
      // for what's on screen.
      body: CustomScrollView(
        slivers: [
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('Invites'),
                  SizedBox(height: 8),
                ],
              ),
            ),
          ),
          // Only this subtree reacts to invite state.
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: Consumer(
              builder: (context, ref, _) {
                final invitesAsync = ref.watch(groupInvitesProvider);
                return invitesAsync.when(
                  loading: () =>
                      const SliverToBoxAdapter(child: ShimmerRows(count: 1)),
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
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No pending group invites.'),
                        ),
                      );
                    }
                    return SliverList.builder(
                      itemCount: invites.length,
                      itemBuilder: (itemContext, i) {
                        final g = invites[i];
                        return _InviteCard(
                          group: g,
                          onAccept: () => runGuarded(
                            context,
                            () async =>
                                (await ref.read(appRepositoryProvider.future))
                                    .acceptGroupInvite(g.id),
                            errorLabel: 'Could not join group',
                          ),
                          onDecline: () => runGuarded(
                            context,
                            () async =>
                                (await ref.read(appRepositoryProvider.future))
                                    .declineGroupInvite(g.id),
                            errorLabel: 'Could not decline invite',
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('My groups'),
                  SizedBox(height: 8),
                ],
              ),
            ),
          ),
          // Only this subtree reacts to group state.
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: Consumer(
              builder: (context, ref, _) {
                final groupsAsync = ref.watch(myGroupsProvider);
                return groupsAsync.when(
                  loading: () =>
                      const SliverToBoxAdapter(child: ShimmerRows(count: 3)),
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
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No groups yet. Create one and invite your friends.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                      );
                    }
                    return SliverList.builder(
                      itemCount: groups.length,
                      itemBuilder: (itemContext, i) {
                        final g = groups[i];
                        return Card(
                          child: ListTile(
                            leading:
                                const CircleAvatar(child: Icon(Icons.group)),
                            title: Text(g.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                '${g.members.length} member${g.members.length == 1 ? '' : 's'}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(itemContext).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    GroupDetailScreen(groupId: g.id),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New group'),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.group,
    required this.onAccept,
    required this.onDecline,
  });

  final BillGroup group;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.group_add)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Text('You are invited to join this group'),
                ],
              ),
            ),
            TextButton(
              onPressed: onDecline,
              child: const Text('Decline'),
            ),
            FilledButton(
              onPressed: onAccept,
              child: const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }
}
