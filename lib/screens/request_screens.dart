import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../providers/invitation_providers.dart';
import '../widgets/invitation_summary_tile.dart';
import '../widgets/state_widgets.dart';
import '../widgets/studio_ui.dart';
import 'friend_invitation_screen.dart';
import 'group_invitation_screen.dart';

/// Group invitations opened from the Groups screen or a notification.
class GroupRequestsScreen extends ConsumerStatefulWidget {
  const GroupRequestsScreen({
    super.key,
    this.initialIndex = 0,
    this.initialGroupId,
  }) : assert(initialIndex >= 0 && initialIndex < 2);

  final int initialIndex;
  final String? initialGroupId;

  @override
  ConsumerState<GroupRequestsScreen> createState() => _GroupRequestsScreenState();
}

class _GroupRequestsScreenState extends ConsumerState<GroupRequestsScreen> {
  @override
  void initState() {
    super.initState();
    final groupId = widget.initialGroupId?.trim();
    if (groupId == null || groupId.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshInitialInvitation(groupId);
    });
  }

  Future<void> _refreshInitialInvitation(String groupId) async {
    try {
      final sync = await ref.read(syncServiceProvider.future);
      if (mounted) await sync.refreshGroupInvitation(groupId);
    } catch (_) {
      // Keep cached invitations available when the push is opened offline.
    }
  }

  @override
  Widget build(BuildContext context) {
    final incoming = ref.watch(groupInvitesProvider).value?.length ?? 0;
    final outgoing = ref.watch(outgoingGroupInvitesProvider).value?.length ?? 0;
    return _RequestsShell(
      title: 'Group invitations',
      initialIndex: widget.initialIndex,
      incoming: incoming,
      outgoing: outgoing,
      children: const [
        _GroupRequests(incoming: true),
        _GroupRequests(incoming: false),
      ],
    );
  }
}

/// Friend invitations opened from the Friends screen or a notification.
class FriendRequestsScreen extends ConsumerWidget {
  const FriendRequestsScreen({super.key, this.initialIndex = 0})
      : assert(initialIndex >= 0 && initialIndex < 2);

  final int initialIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(incomingRequestsProvider).value?.length ?? 0;
    final outgoing = ref.watch(outgoingRequestsProvider).value?.length ?? 0;
    return _RequestsShell(
      title: 'Friend invitations',
      initialIndex: initialIndex,
      incoming: incoming,
      outgoing: outgoing,
      children: const [
        _FriendRequests(incoming: true),
        _FriendRequests(incoming: false),
      ],
    );
  }
}

class _RequestsShell extends StatelessWidget {
  const _RequestsShell({
    required this.title,
    required this.initialIndex,
    required this.incoming,
    required this.outgoing,
    required this.children,
  });

  final String title;
  final int initialIndex;
  final int incoming;
  final int outgoing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        initialIndex: initialIndex,
        child: Scaffold(
          appBar: AppBar(
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Incoming ($incoming)'),
                Tab(text: 'Outgoing ($outgoing)'),
              ],
            ),
          ),
          body: TabBarView(children: children),
        ),
      );
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests(this.title, this.message);
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        InlineEmpty(icon: Icons.inbox_outlined, title: title, message: message),
      ]);
}

class _GroupRequests extends ConsumerWidget {
  const _GroupRequests({required this.incoming});
  final bool incoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider) ?? '';
    final AsyncValue<List<OutgoingGroupInvitation>> invitations = incoming
        ? ref.watch(groupInvitesProvider).whenData((groups) => [
              for (final group in groups) (group: group, recipientUid: uid),
            ])
        : ref.watch(outgoingGroupInvitesProvider);
    return invitations.when(
      loading: () => const ShimmerList(count: 2),
      error: (error, stack) => LoadError(
        message: 'Could not load group invitations.',
        onRetry: () {
          ref.invalidate(appRepositoryProvider);
          ref.invalidate(groupInvitesProvider);
          ref.invalidate(outgoingGroupInvitesProvider);
          ref.invalidate(myGroupsProvider);
        },
      ),
      data: (items) => items.isEmpty
          ? _EmptyRequests(
              incoming
                  ? 'No incoming group invitations'
                  : 'No outgoing group invitations',
              incoming
                  ? 'New group invitations will appear here.'
                  : 'Invitations you send will appear here.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (itemContext, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InvitationSummaryTile(
                    groupName: item.group.name,
                    incoming: incoming,
                    person: incoming
                        ? item.group.invitations[item.recipientUid]?.from ??
                            AppUser(
                                uid: item.group.createdBy,
                                displayName: 'Group owner',
                                email: '')
                        : item.group.invitations[item.recipientUid]?.to ??
                            AppUser(
                                uid: item.recipientUid,
                                displayName: 'Invited person',
                                email: ''),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => GroupInvitationScreen(
                        groupId: item.group.id,
                        incoming: incoming,
                        recipientUid: item.recipientUid,
                      ),
                    )),
                  ),
                );
              },
            ),
    );
  }
}

class _FriendRequests extends ConsumerWidget {
  const _FriendRequests({required this.incoming});
  final bool incoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = incoming
        ? ref.watch(incomingRequestsProvider)
        : ref.watch(outgoingRequestsProvider);
    return requests.when(
      loading: () => const ShimmerList(count: 2),
      error: (error, stack) => LoadError(
        message: 'Could not load friend requests.',
        onRetry: () {
          ref.invalidate(appRepositoryProvider);
          ref.invalidate(incomingRequestsProvider);
          ref.invalidate(outgoingRequestsProvider);
        },
      ),
      data: (items) => items.isEmpty
          ? _EmptyRequests(
              incoming ? 'No incoming requests' : 'No outgoing requests',
              incoming
                  ? 'New friend requests will appear here.'
                  : 'Sent friend requests will appear here.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, index) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InvitationSummaryTile(
                  incoming: incoming,
                  person: AppUser(
                    uid: incoming ? items[index].fromUid : items[index].toUid,
                    displayName:
                        incoming ? items[index].fromName : items[index].toName,
                    email: incoming
                        ? items[index].fromEmail
                        : items[index].toEmail,
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => FriendInvitationScreen(
                      request: items[index],
                      incoming: incoming,
                    ),
                  )),
                ),
              ),
            ),
    );
  }
}
