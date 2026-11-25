import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_repository.dart';
import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';

/// Accept / Decline for an invitation shown in the Activity list.
///
/// The buttons appear only while the invitation is still pending, and run the
/// same repository calls as the invitation screens, so answering here and
/// answering there behave identically. Once answered, the matching pending
/// invitation disappears from its provider and the buttons go with it.
class NotificationInvitationActions extends ConsumerStatefulWidget {
  const NotificationInvitationActions({super.key, required this.notification});

  final AppNotification notification;

  @override
  ConsumerState<NotificationInvitationActions> createState() =>
      _NotificationInvitationActionsState();
}

class _NotificationInvitationActionsState
    extends ConsumerState<NotificationInvitationActions> {
  bool _busy = false;

  Future<void> _run(
    Future<void> Function(AppRepository repo) action,
    String failure,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = await ref.read(appRepositoryProvider.future);
      await action(repo);
      // Best effort: an answered invitation is no longer unread.
      try {
        await repo.markNotificationRead(widget.notification.id);
      } catch (_) {}
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final Future<void> Function(AppRepository) accept;
    final Future<void> Function(AppRepository) decline;
    final String acceptFailure;
    final String declineFailure;

    if (notification.type == 'friend_request') {
      final from = notification.fromUid ?? '';
      final requests = ref.watch(incomingRequestsProvider).value ??
          const <ConnectionRequest>[];
      ConnectionRequest? pending;
      for (final candidate in requests) {
        if (candidate.fromUid == from) {
          pending = candidate;
          break;
        }
      }
      if (pending == null) return const SizedBox.shrink();
      final request = pending;
      accept = (repo) => repo.acceptConnectionRequest(request);
      decline = (repo) => repo.declineConnectionRequest(request.id);
      acceptFailure = 'Could not accept this request. Please try again.';
      declineFailure = 'Could not decline this request. Please try again.';
    } else if (notification.type == 'group_invite') {
      final groupId = notification.groupId ?? '';
      final invites =
          ref.watch(groupInvitesProvider).value ?? const <BillGroup>[];
      if (groupId.isEmpty || !invites.any((group) => group.id == groupId)) {
        return const SizedBox.shrink();
      }
      accept = (repo) => repo.acceptGroupInviteConfirmed(groupId);
      decline = (repo) => repo.declineGroupInvite(groupId);
      acceptFailure =
          'Could not accept invitation. Check your connection and try again.';
      declineFailure = 'Could not decline invitation. Please try again.';
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          FilledButton(
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: _busy ? null : () => _run(accept, acceptFailure),
            child: const Text('Accept'),
          ),
          TextButton(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: _busy ? null : () => _run(decline, declineFailure),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }
}
