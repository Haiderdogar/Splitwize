import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/core_providers.dart';
import 'invitation_person_details.dart';
import 'studio_ui.dart';

class GroupInvitationCard extends ConsumerStatefulWidget {
  const GroupInvitationCard(
      {super.key,
      required this.group,
      required this.recipientUid,
      this.incoming = true,
      this.onAccepted});
  final BillGroup group;
  final String recipientUid;
  final bool incoming;
  final Future<void> Function()? onAccepted;
  @override
  ConsumerState<GroupInvitationCard> createState() =>
      _GroupInvitationCardState();
}

class _GroupInvitationCardState extends ConsumerState<GroupInvitationCard> {
  bool _busy = false;
  Future<void> _act() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = await ref.read(appRepositoryProvider.future);
      if (widget.incoming) {
        if (widget.onAccepted != null) {
          await widget.onAccepted!();
        } else {
          await repo.acceptGroupInviteConfirmed(widget.group.id);
        }
      } else {
        await repo.cancelGroupInvite(widget.group.id, widget.recipientUid);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.incoming
              ? 'Could not accept invitation. Check your connection and try again.'
              : 'Could not cancel invitation. Please try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitation = widget.group.invitations[widget.recipientUid];
    final inviter = invitation?.from ??
        AppUser(
            uid: widget.group.createdBy, displayName: 'Group owner', email: '');
    final recipient = invitation?.to ??
        AppUser(
            uid: widget.recipientUid, displayName: 'Invited person', email: '');
    return SoftPanel(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Group: ${widget.group.name}',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (!widget.incoming) ...[
          const Text('Invitation sent to'),
          const SizedBox(height: 6),
          InvitationPersonDetails(person: recipient),
          const SizedBox(height: 12),
        ],
        Text(invitation == null ? 'Group owner' : 'Invited by'),
        const SizedBox(height: 6),
        InvitationPersonDetails(person: inviter),
        const SizedBox(height: 10),
        const Text('Invitation pending'),
        if (invitation?.sentAt != null)
          Text(
              'Sent ${DateFormat.yMMMd().add_jm().format(invitation!.sentAt!)}'),
        const SizedBox(height: 12),
        if (widget.incoming)
          FilledButton(
              onPressed: _busy ? null : _act,
              child: Text(_busy ? 'Accepting...' : 'Accept group invitation'))
        else
          OutlinedButton(
              onPressed: _busy ? null : _act,
              child: Text(_busy ? 'Cancelling...' : 'Cancel invitation')),
      ],
    ));
  }
}
