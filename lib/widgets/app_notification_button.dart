import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/data_providers.dart';
import '../screens/notifications_screen.dart';

/// Shared app-bar notification action for Home, Balances, Groups and Friends.
/// Uses the existing unread count provider and notification inbox.
class AppNotificationButton extends ConsumerWidget {
  const AppNotificationButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return Badge(
      isLabelVisible: unread > 0,
      label: Text('$unread'),
      child: IconButton(
        tooltip: 'Notifications',
        icon: const Icon(Icons.notifications_none_rounded),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const NotificationsScreen(),
          ),
        ),
      ),
    );
  }
}
