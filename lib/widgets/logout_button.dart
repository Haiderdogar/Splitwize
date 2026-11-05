import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/logout_provider.dart';
import 'state_widgets.dart';

class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(logoutControllerProvider);
    final errorColor = Theme.of(context).colorScheme.error;
    return ListTile(
      key: const ValueKey('logout-button'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: busy
          ? SizedBox.square(
              dimension: 24,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: errorColor),
            )
          : Icon(Icons.logout_rounded, color: errorColor),
      title: Text(
        busy ? 'Logging out…' : 'Log out',
        style: TextStyle(color: errorColor, fontWeight: FontWeight.bold),
      ),
      enabled: !busy,
      onTap: busy
          ? null
          : () => runGuarded(context, () async {
                final navigator = Navigator.of(context);
                final scaffold = Scaffold.maybeOf(context);
                final loggedOut = await ref
                    .read(logoutControllerProvider.notifier)
                    .logOut(confirm: (pending) async {
                  if (!context.mounted) return false;
                  return _confirmPendingChanges(context, pending);
                });
                if (!loggedOut) return;
                if (scaffold != null &&
                    scaffold.mounted &&
                    scaffold.isDrawerOpen) {
                  scaffold.closeDrawer();
                }
                if (navigator.mounted) {
                  navigator.popUntil((route) => route.isFirst);
                }
              }, errorLabel: 'Could not log out'),
    );
  }
}

Future<bool> _confirmPendingChanges(BuildContext context, int pending) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsynced changes'),
          content: Text(
            'You have $pending change${pending == 1 ? '' : 's'} that '
            "haven't synced yet. Logging out deletes them from this device.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Log out anyway'),
            ),
          ],
        ),
      ) ??
      false;
}
