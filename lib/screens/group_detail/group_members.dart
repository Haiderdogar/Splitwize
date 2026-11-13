import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../providers/form_providers.dart';
import '../../utils/current_user_identity.dart';
import '../../utils/invitation_notification_content.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/studio_ui.dart';

class GroupMembersTab extends ConsumerWidget {
  const GroupMembersTab({required this.group, super.key});
  final BillGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(groupMembersProvider(group.id));
    final myUid = ref.watch(currentUidProvider) ?? '';
    final google = ref.watch(authStateChangesProvider).value;
    final identity = resolveCurrentUserIdentity(
      cached: ref.watch(currentAppUserProvider).value,
      googleName: google?.displayName,
      googleEmail: google?.email,
    );
    return CustomScrollView(
      key: PageStorageKey('group-members-${group.id}'),
      slivers: [
        SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeading('The people in your group',
                    subtitle: '${group.members.length} joined · '
                        '${group.invited.length} pending'),
                GroupInviteButton(group: group),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: members.when(
            loading: () =>
                const SliverToBoxAdapter(child: ShimmerRows(count: 3)),
            error: (_, __) => SliverToBoxAdapter(
              child: LoadError.compact(
                message: 'Could not load members.',
                onRetry: () => ref.invalidate(groupMembersProvider(group.id)),
              ),
            ),
            data: (users) => SliverList.builder(
              itemCount: users.length,
              itemBuilder: (context, i) {
                final user = users[i];
                final isMe = user.uid == myUid;
                return _MemberRow(
                  initials: isMe ? identity.initials : user.initials,
                  name: isMe ? '${identity.name} (you)' : user.displayName,
                  email: isMe ? identity.email : user.email,
                  label: user.uid == group.createdBy ? 'Creator' : 'Member',
                );
              },
            ),
          ),
        ),
        if (group.invited.isNotEmpty) ...[
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            sliver: SliverToBoxAdapter(
              child: SectionHeading('Pending invitations',
                  subtitle: 'They can join once they accept your invitation.'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: _PendingMembers(group: group),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class GroupInviteButton extends ConsumerWidget {
  const GroupInviteButton({required this.group, super.key});
  final BillGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref.watch(connectionsProvider);
    return OutlinedButton.icon(
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
      label:
          Text(connections.isLoading ? 'Loading friends…' : 'Invite friends'),
      onPressed: connections.isLoading
          ? null
          : () {
              if (connections.hasError) {
                ref.invalidate(connectionsProvider);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Could not load friends. Retrying…')));
                return;
              }
              final candidates = (connections.value ?? <AppUser>[])
                  .where((user) =>
                      !group.members.contains(user.uid) &&
                      !group.invited.contains(user.uid))
                  .toList();
              if (candidates.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('No more connected friends to invite.')));
                return;
              }
              ref.read(groupInviteSelectionProvider.notifier).clear();
              showDialog<void>(
                context: context,
                builder: (_) =>
                    _InviteDialog(group: group, candidates: candidates),
              );
            },
    );
  }
}

class _PendingMembers extends ConsumerWidget {
  const _PendingMembers({required this.group});
  final BillGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(invitedUsersProvider(group.id)).when(
          loading: () => const SliverToBoxAdapter(child: ShimmerRows(count: 2)),
          error: (_, __) => SliverToBoxAdapter(
            child: LoadError.compact(
              message: 'Could not load invitations.',
              onRetry: () => ref.invalidate(invitedUsersProvider(group.id)),
            ),
          ),
          data: (users) => SliverList.builder(
            itemCount: users.length,
            itemBuilder: (_, i) => _MemberRow(
              initials: users[i].initials,
              name: users[i].displayName,
              email: users[i].email,
              label: 'Invited',
            ),
          ),
        );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.initials,
    required this.name,
    required this.email,
    required this.label,
  });
  final String initials;
  final String name;
  final String email;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftPanel(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PersonMark(initials: initials, size: 44),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.titleSmall),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(email,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 8),
              Text(label,
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary, fontWeight: FontWeight.w700)),
            ],
          )),
        ]),
      ),
    );
  }
}

/// One candidate row in the invite checklist. Watches only its own
/// tick, so ticking one candidate does not rebuild the other rows.
class _InviteCheckRow extends StatelessWidget {
  const _InviteCheckRow({required this.candidate, required this.enabled});

  final AppUser candidate;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final checked = ref.watch(groupInviteSelectionProvider
            .select((s) => s.contains(candidate.uid)));
        final notifier = ref.read(groupInviteSelectionProvider.notifier);
        return CheckboxListTile(
          value: checked,
          onChanged: enabled
              ? (v) => notifier.toggle(candidate.uid, v ?? false)
              : null,
          secondary: CircleAvatar(child: Text(candidate.initials)),
          title: Text(candidate.displayName),
        );
      },
    );
  }
}

/// Selection remains isolated per row; local state guards submission.
class _InviteDialog extends StatefulWidget {
  const _InviteDialog({
    required this.group,
    required this.candidates,
  });

  final BillGroup group;
  final List<AppUser> candidates;

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sending,
      child: AlertDialog(
        title: const Text('Invite friends'),
        content: SizedBox(
          width: double.maxFinite,
          // Cap the checklist height so the dialog always fits the
          // screen; the list scrolls internally past the cap.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.45,
            ),
            // No watch at this level: each row watches only its own
            // tick (see [_InviteCheckRow]), so ticking one candidate
            // rebuilds that row alone, not the whole checklist.
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.candidates.length,
              itemBuilder: (itemContext, i) => _InviteCheckRow(
                  candidate: widget.candidates[i], enabled: !_sending),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _sending ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          // Only the button reacts to selection state — and only to
          // whether anything is selected at all (a bool), not to the
          // whole set, so ticking a second friend does not rebuild it.
          Consumer(
            builder: (context, ref, _) {
              final hasSelection = ref.watch(
                  groupInviteSelectionProvider.select((s) => s.isNotEmpty));
              return FilledButton(
                onPressed: !hasSelection || _sending
                    ? null
                    : () async {
                        setState(() => _sending = true);
                        final selected = Set<String>.of(
                            ref.read(groupInviteSelectionProvider));
                        try {
                          final repo =
                              await ref.read(appRepositoryProvider.future);
                          await repo.inviteToGroup(
                              widget.group.id, selected.toList());
                          final inviter = await repo.getUser(repo.myUid);
                          for (final uid in selected) {
                            await repo.sendNotification(
                              toUid: uid,
                              title: 'Group invitation',
                              body: invitationNotificationBody(
                                    type: 'group_invite',
                                    fromName: inviter?.displayName,
                                    fromEmail: inviter?.email,
                                    groupName: widget.group.name,
                                  ) ??
                                  'A group member invited you to join "${widget.group.name}".',
                              type: 'group_invite',
                              groupId: widget.group.id,
                              fromUid: repo.myUid,
                              fromName: inviter?.displayName,
                              fromEmail: inviter?.email,
                              groupName: widget.group.name,
                            );
                          }
                        } catch (e) {
                          if (mounted) setState(() => _sending = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Could not send invites: $e')),
                            );
                          }
                          return;
                        }
                        if (!mounted) return;
                        ref.read(groupInviteSelectionProvider.notifier).clear();
                        setState(() => _sending = false);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invites sent.')),
                        );
                      },
                child: Text(_sending ? 'Sending…' : 'Send invites'),
              );
            },
          ),
        ],
      ),
    );
  }
}
