import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../widgets/friend_request_card.dart';
import '../widgets/state_widgets.dart';

/// Details and actions for the one friend invitation selected from the list.
class FriendInvitationScreen extends ConsumerWidget {
  const FriendInvitationScreen({
    super.key,
    required this.request,
    required this.incoming,
  });

  final ConnectionRequest request;
  final bool incoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = incoming
        ? ref.watch(incomingRequestsProvider)
        : ref.watch(outgoingRequestsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          incoming
              ? 'Incoming friend invitation'
              : 'Outgoing friend invitation',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: requests.when(
        loading: () => _details(request),
        error: (error, stack) => LoadError(
          message: 'Could not load this invitation.',
          onRetry: () {
            ref.invalidate(appRepositoryProvider);
            if (incoming) {
              ref.invalidate(incomingRequestsProvider);
            } else {
              ref.invalidate(outgoingRequestsProvider);
            }
          },
        ),
        data: (items) => _details(items
            .where((item) => item.id == request.id && item.status == 'pending')
            .firstOrNull),
      ),
    );
  }

  Widget _details(ConnectionRequest? selected) {
    if (selected == null || selected.status != 'pending') {
      return const Center(
        child: Text('This invitation is no longer available.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [FriendRequestCard(request: selected, incoming: incoming)],
    );
  }
}
