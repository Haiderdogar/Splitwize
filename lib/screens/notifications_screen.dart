import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/aurora_ui.dart';
import '../widgets/state_widgets.dart';
import 'bill_detail_screen.dart';
import 'group_detail_screen.dart';

/// In-app notification inbox: bill events, payments, invites, reminders.
/// Tapping a notification marks it read and deep-links where relevant.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

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
                    AuroraHero(
                      eyebrow: 'YOUR ACTIVITY',
                      title: 'Stay in the loop.',
                      subtitle: 'Every shared moment, payment and invite in one place.',
                      icon: Icons.notifications_active_rounded,
                      colors: [AuroraPalette.deep, AuroraPalette.violet],
                    ),
                    SizedBox(height: 30),
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
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AuroraHero(
                          eyebrow: 'YOUR ACTIVITY',
                          title: 'Stay in the loop.',
                          subtitle: 'Never miss a split, payment or invitation.',
                          icon: Icons.notifications_active_rounded,
                          metric: '${items.where((n) => !n.read).length}',
                          metricLabel: 'unread',
                          colors: const [AuroraPalette.deep, AuroraPalette.violet],
                        ),
                        const SizedBox(height: 19),
                        const AuroraSectionHeading('Recent updates'),
                      ],
                    );
                  }
                  final n = items[i - 1];
                  return Card(
                    color: n.read
                        ? null
                        : Theme.of(context)
                            .colorScheme
                            .secondaryContainer
                            .withValues(alpha: 0.5),
                    child: ListTile(
                      leading: AuroraMonogram(
                        label: '',
                        icon: _iconFor(n.type),
                        color: n.read ? AuroraPalette.violet : AuroraPalette.indigo,
                        size: 48,
                      ),
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
                          Text(n.body),
                          if (n.createdAt != null)
                            Text(
                              DateFormat.yMMMd().add_jm().format(n.createdAt!),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                      trailing: n.read
                          ? null
                          : const Icon(Icons.circle, color: AuroraPalette.cyan, size: 13),
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
    if (!context.mounted) return;
    if ((n.type == 'bill_created' || n.type == 'bill_paid') &&
        n.billId != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BillDetailScreen(billId: n.billId!),
        ),
      );
    } else if (n.type == 'group_invite' && n.groupId != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GroupDetailScreen(groupId: n.groupId!),
        ),
      );
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
