import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_notification_button.dart';
import '../widgets/state_widgets.dart';
import '../widgets/studio_ui.dart';

/// Dedicated action center for group invites and friend requests.
/// Outgoing requests do not count as pending actions.
class RequestsTab extends StatelessWidget {
  const RequestsTab({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        leading: const SplitwizeMenuButton(),
        title: const Text('Requests & Invitations'),
        actions: const [AppNotificationButton(), SizedBox(width: 5)],
        bottom: const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Group invites'),
            Tab(text: 'Incoming'),
            Tab(text: 'Outgoing'),
          ],
        ),
      ),
      body: const TabBarView(children: [
        _GroupInvitesList(),
        _IncomingList(),
        _OutgoingList(),
      ]),
    ),
  );
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests(this.icon, this.title, this.message);
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [InlineEmpty(icon: icon, title: title, message: message)],
  );
}

class _GroupInvitesList extends ConsumerWidget {
  const _GroupInvitesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(groupInvitesProvider).when(
        loading: () => const ShimmerList(count: 2),
        error: (e, _) => LoadError(
          message: 'Could not load group invitations.',
          onRetry: () {
            ref.invalidate(appRepositoryProvider);
            ref.invalidate(groupInvitesProvider);
          },
        ),
        data: (invites) => invites.isEmpty
            ? const _EmptyRequests(Icons.group_add_outlined,
                'No group invitations', 'New group invitations will appear here.')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                itemCount: invites.length,
                itemBuilder: (context, i) {
                  final group = invites[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: SoftPanel(child: Column(
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
                          TextButton(
                            onPressed: () => runGuarded(
                              context,
                              () async => (await ref.read(appRepositoryProvider.future))
                                  .declineGroupInvite(group.id),
                              errorLabel: 'Could not decline invitation',
                            ),
                            child: const Text('Decline'),
                          ),
                          FilledButton(
                            onPressed: () => runGuarded(
                              context,
                              () async => (await ref.read(appRepositoryProvider.future))
                                  .acceptGroupInvite(group.id),
                              errorLabel: 'Could not join group',
                            ),
                            child: const Text('Join group'),
                          ),
                        ]),
                      ],
                    )),
                  );
                },
              ),
      );
}

class _IncomingList extends ConsumerWidget {
  const _IncomingList();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(incomingRequestsProvider).when(
        loading: () => const ShimmerList(count: 2),
        error: (e, _) => LoadError(
          message: 'Could not load incoming requests.',
          onRetry: () {
            ref.invalidate(appRepositoryProvider);
            ref.invalidate(incomingRequestsProvider);
          },
        ),
        data: (requests) => requests.isEmpty
            ? const _EmptyRequests(Icons.inbox_outlined,
                'No incoming requests', 'New friend requests will appear here.')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                itemCount: requests.length,
                itemBuilder: (context, i) {
                  final request = requests[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Card(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              PersonMark(initials: request.fromName.isEmpty
                                  ? '?' : request.fromName[0].toUpperCase()),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(request.fromName,
                                      style: Theme.of(context).textTheme.titleMedium),
                                  const Text('wants to connect with you'),
                                ],
                              )),
                            ]),
                            const SizedBox(height: 6),
                            Wrap(spacing: 8, runSpacing: 5, children: [
                              TextButton(
                                onPressed: () => runGuarded(
                                  context,
                                  () async => (await ref.read(appRepositoryProvider.future))
                                      .declineConnectionRequest(request.id),
                                  errorLabel: 'Could not decline request',
                                ),
                                child: const Text('Decline'),
                              ),
                              FilledButton(
                                onPressed: () => runGuarded(
                                  context,
                                  () async => (await ref.read(appRepositoryProvider.future))
                                      .acceptConnectionRequest(request),
                                  errorLabel: 'Could not accept request',
                                ),
                                child: const Text('Accept'),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      );
}

class _OutgoingList extends ConsumerWidget {
  const _OutgoingList();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(outgoingRequestsProvider).when(
        loading: () => const ShimmerList(count: 2),
        error: (e, _) => LoadError(
          message: 'Could not load outgoing requests.',
          onRetry: () {
            ref.invalidate(appRepositoryProvider);
            ref.invalidate(outgoingRequestsProvider);
          },
        ),
        data: (requests) => requests.isEmpty
            ? const _EmptyRequests(Icons.send_outlined,
                'No outgoing requests', 'Sent friend requests will appear here.')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                itemCount: requests.length,
                itemBuilder: (context, i) {
                  final request = requests[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Card(child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(request.toName.isEmpty
                            ? '?' : request.toName[0].toUpperCase()),
                      ),
                      title: Text(request.toName,
                          style: Theme.of(context).textTheme.titleMedium),
                      subtitle: const Text('Waiting for response'),
                      trailing: TextButton(
                        onPressed: () => runGuarded(
                          context,
                          () async => (await ref.read(appRepositoryProvider.future))
                              .cancelConnectionRequest(request.id),
                          errorLabel: 'Could not cancel request',
                        ),
                        child: const Text('Cancel'),
                      ),
                    )),
                  );
                },
              ),
      );
}
