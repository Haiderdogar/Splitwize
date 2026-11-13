import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/app_drawer.dart';
import '../widgets/studio_ui.dart';
import '../theme.dart';
import '../widgets/state_widgets.dart';
import '../utils/notification_destination.dart';
import '../utils/invitation_notification_content.dart';

/// In-app notification inbox: bill events, payments, invites, reminders.
/// Tapping a notification marks it read and deep-links where relevant.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, this.embedded = false});

  /// Embedded inboxes keep the home shell beneath notification detail routes.
  final bool embedded;

  IconData _iconFor(String type) {
    switch (type) {
      case 'bill_created':
        return Icons.receipt_long;
      case 'bill_paid':
        return Icons.payments_outlined;
      case 'friend_request':
        return Icons.person_add_alt;
      case 'group_invite':
        return Icons.group_add_outlined;
      case 'reminder':
        return Icons.alarm_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: embedded ? const SplitwizeMenuButton() : null,
        title: const Text('Notifications'),
        actions: [
          // Writes only.
          Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () {
                final uid = ref.read(currentUidProvider);
                if (uid == null) return;
                runGuarded(
                  context,
                  () async {
                    final repo = await ref.read(appRepositoryProvider.future);
                    await repo.markAllNotificationsRead();
                  },
                  errorLabel: 'Could not mark all read',
                );
              },
              child: const Text('Mark all read'),
            ),
          ),
        ],
      ),
      // Only the list reacts to notification state.
      body: Consumer(
        builder: (context, ref, _) {
          final itemsAsync = ref.watch(notificationsProvider);
          return itemsAsync.when(
            loading: () => const ShimmerList(count: 5),
            error: (e, _) => LoadError(
              message: 'Could not load notifications.',
              onRetry: () {
                ref.invalidate(appRepositoryProvider);
                ref.invalidate(notificationsProvider);
              },
            ),
            data: (items) {
              if (items.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: const [
                    _EmptyInbox(),
                  ],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                itemCount: items.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return const SectionHeading('Recent updates');
                  }
                  final n = items[i - 1];
                  final isInvitation =
                      n.type == 'friend_request' || n.type == 'group_invite';
                  final name = isInvitation ? n.fromName?.trim() ?? '' : '';
                  final email = isInvitation ? n.fromEmail?.trim() ?? '' : '';
                  final sender = name.isNotEmpty ? name : email;
                  final group =
                      n.type == 'group_invite' ? n.groupName?.trim() ?? '' : '';
                  final body = invitationNotificationBody(
                        type: n.type,
                        fromName: name,
                        fromEmail: email,
                        groupName: group,
                      ) ??
                      n.body;
                  return Card(
                    color: n.read
                        ? null
                        : Theme.of(context)
                            .colorScheme
                            .secondaryContainer
                            .withValues(alpha: 0.5),
                    child: ListTile(
                      leading: PersonMark(
                          initials: AppUser(
                                  uid: n.fromUid ?? '',
                                  displayName: sender,
                                  email: email)
                              .initials,
                          icon: sender.isEmpty ? _iconFor(n.type) : null,
                          size: 48),
                      title: Text(
                        n.title,
                        style: TextStyle(
                          fontWeight:
                              n.read ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(body),
                          if (sender.isNotEmpty || group.isNotEmpty)
                            const SizedBox(height: 6),
                          if (sender.isNotEmpty) Text('Invited by: $sender'),
                          if (name.isNotEmpty && email.isNotEmpty)
                            Text('Email: $email'),
                          if (group.isNotEmpty) Text('Group: $group'),
                          if (n.createdAt != null)
                            Text(
                              DateFormat.yMMMd().add_jm().format(n.createdAt!),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                      trailing: n.read
                          ? null
                          : const Icon(Icons.circle,
                              color: SplitwizePalette.positive, size: 13),
                      onTap: () => _open(context, ref, n),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _open(
      BuildContext context, WidgetRef ref, AppNotification n) async {
    // Marking read is best effort — a failure must never block
    // opening the notification's target.
    try {
      final repo = await ref.read(appRepositoryProvider.future);
      await repo.markNotificationRead(n.id);
    } catch (_) {}
    if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) return;
    if (embedded && ref.read(tabIndexProvider) != 4) return;
    final destination = notificationDestination(
        type: n.type, groupId: n.groupId, billId: n.billId, fromInbox: true);
    if (destination != null) {
      final route = MaterialPageRoute<void>(builder: (_) => destination);
      if (embedded) {
        Navigator.of(context).push(route);
      } else {
        Navigator.of(context).pushReplacement(route);
      }
    }
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.notifications_none,
      title: 'All caught up.',
      subtitle: 'New bills, payments and invites will show up here.',
    );
  }
}
