import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/core_providers.dart';
import 'invitation_person_details.dart';
import 'studio_ui.dart';

class FriendRequestCard extends ConsumerStatefulWidget {
  const FriendRequestCard(
      {super.key, required this.request, required this.incoming});
  final ConnectionRequest request;
  final bool incoming;
  @override
  ConsumerState<FriendRequestCard> createState() => _FriendRequestCardState();
}

class _FriendRequestCardState extends ConsumerState<FriendRequestCard> {
  bool _busy = false;
  Future<void> _act(String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = await ref.read(appRepositoryProvider.future);
      switch (action) {
        case 'accept':
          await repo.acceptConnectionRequest(widget.request);
        case 'decline':
          await repo.declineConnectionRequest(widget.request.id);
        case 'cancel':
          await repo.cancelConnectionRequest(widget.request.id);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not update this request. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final person = AppUser(
        uid: widget.incoming ? request.fromUid : request.toUid,
        displayName: widget.incoming ? request.fromName : request.toName,
        email: widget.incoming ? request.fromEmail : request.toEmail);
    return SoftPanel(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InvitationPersonDetails(person: person),
        const SizedBox(height: 10),
        Text(widget.incoming
            ? 'wants to connect with you'
            : 'Waiting for response'),
        if (request.createdAt != null)
          Text(
              'Sent ${DateFormat.yMMMd().add_jm().format(request.createdAt!)}'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (widget.incoming) ...[
            TextButton(
                onPressed: _busy ? null : () => _act('decline'),
                child: const Text('Decline')),
            FilledButton(
                onPressed: _busy ? null : () => _act('accept'),
                child: const Text('Accept')),
          ] else
            TextButton(
                onPressed: _busy ? null : () => _act('cancel'),
                child: const Text('Cancel')),
        ]),
      ],
    ));
  }
}
