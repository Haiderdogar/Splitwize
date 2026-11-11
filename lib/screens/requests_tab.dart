import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../providers/invitation_providers.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_notification_button.dart';
import '../widgets/friend_request_card.dart';
import '../widgets/group_invitation_card.dart';
import '../widgets/state_widgets.dart';
import '../widgets/studio_ui.dart';
import 'group_detail_screen.dart';

class RequestsTab extends ConsumerWidget {
  const RequestsTab({super.key, this.initialIndex = 0});
  final int initialIndex;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupIncoming = ref.watch(groupInvitesProvider).value?.length ?? 0;
    final groupOutgoing =
        ref.watch(outgoingGroupInvitesProvider).value?.length ?? 0;
    final incoming = ref.watch(incomingRequestsProvider).value?.length ?? 0;
    final outgoing = ref.watch(outgoingRequestsProvider).value?.length ?? 0;
    return DefaultTabController(
        length: 4,
        initialIndex: initialIndex,
        child: Scaffold(
          appBar: AppBar(
            leading: const SplitwizeMenuButton(),
            title: const Text('Requests & Invitations',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: const [AppNotificationButton(), SizedBox(width: 5)],
            bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Group incoming ($groupIncoming)'),
                  Tab(text: 'Group outgoing ($groupOutgoing)'),
                  Tab(text: 'Incoming ($incoming)'),
                  Tab(text: 'Outgoing ($outgoing)'),
                ]),
          ),
          body: const TabBarView(children: [
            _GroupRequests(incoming: true),
            _GroupRequests(incoming: false),
            _FriendRequests(incoming: true),
            _FriendRequests(incoming: false),
          ]),
        ));
  }
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests(this.title, this.message);
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        InlineEmpty(icon: Icons.inbox_outlined, title: title, message: message)
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
            ref.invalidate(myGroupsProvider);
          }),
      data: (items) => items.isEmpty
          ? _EmptyRequests(
              incoming
                  ? 'No incoming group invitations'
                  : 'No outgoing group invitations',
              incoming
                  ? 'New group invitations will appear here.'
                  : 'Invitations you send will appear here.')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (itemContext, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GroupInvitationCard(
                      group: item.group,
                      recipientUid: item.recipientUid,
                      incoming: incoming,
                      onAccepted: incoming
                          ? () async {
                              final repo =
                                  await ref.read(appRepositoryProvider.future);
                              await repo
                                  .acceptGroupInviteConfirmed(item.group.id);
                              if (context.mounted) {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => GroupDetailScreen(
                                        groupId: item.group.id)));
                              }
                            }
                          : null),
                );
              }),
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
          }),
      data: (items) => items.isEmpty
          ? _EmptyRequests(
              incoming ? 'No incoming requests' : 'No outgoing requests',
              incoming
                  ? 'New friend requests will appear here.'
                  : 'Sent friend requests will appear here.')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FriendRequestCard(
                      request: items[index], incoming: incoming))),
    );
  }
}
