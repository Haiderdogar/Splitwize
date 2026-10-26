import 'package:currency_picker/currency_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../providers/monetization_providers.dart';
import '../widgets/paywall_sheet.dart';
import '../widgets/state_widgets.dart';
import 'bills_tab.dart' show currencyLabel;

/// My default currency — used for new groups and friend bills, and
/// shown everywhere money is displayed. Saved on my profile, so it
/// follows me across devices; works offline (queued profile update).
class _DefaultCurrencyTile extends StatelessWidget {
  const _DefaultCurrencyTile();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final code =
            ref.watch(currentAppUserProvider).value?.currencyCode ?? 'USD';
        return ListTile(
          leading: const Icon(Icons.currency_exchange),
          title: const Text('Default currency'),
          subtitle:
              Text('${currencyLabel(code)} — for new groups & friend bills'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showCurrencyPicker(
            context: context,
            showFlag: true,
            favorite: const ['PKR', 'USD', 'EUR', 'GBP', 'AED', 'SAR', 'INR'],
            onSelect: (c) async {
              try {
                final repo = await ref.read(appRepositoryProvider.future);
                await repo.setMyCurrency(c.code);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Default currency set to ${c.code}.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not set currency: $e')),
                  );
                }
              }
            },
          ),
        );
      },
    );
  }
}

/// App appearance — Light, Dark, or follow the system. A per-device
/// preference (stored locally); changing it re-themes the whole app
/// immediately.
class _AppearanceTile extends StatelessWidget {
  const _AppearanceTile();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final mode =
            ref.watch(themeModeSettingProvider).value ?? AppTheme.system;
        return ListTile(
          leading: const Icon(Icons.brightness_6_outlined),
          title: const Text('Appearance'),
          subtitle: Text(mode.label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => const _ThemePickerDialog(),
          ),
        );
      },
    );
  }
}

/// Light / Dark / System radio picker — applies instantly on tap.
class _ThemePickerDialog extends StatelessWidget {
  const _ThemePickerDialog();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final mode =
            ref.watch(themeModeSettingProvider).value ?? AppTheme.system;
        return AlertDialog(
          title: const Text('Appearance'),
          content: RadioGroup<AppTheme>(
            groupValue: mode,
            onChanged: (value) async {
              if (value == null) return;
              await ref.read(themeModeSettingProvider.notifier).setMode(value);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in AppTheme.values)
                  RadioListTile<AppTheme>(
                    value: option,
                    title: Text(option.label),
                    secondary: Icon(switch (option) {
                      AppTheme.system => Icons.brightness_auto_outlined,
                      AppTheme.light => Icons.light_mode_outlined,
                      AppTheme.dark => Icons.dark_mode_outlined,
                    }),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Push-notification permission status for the profile tile.
/// Guarded: if Firebase Messaging is unavailable for any reason,
/// this returns null (tile shows "Off") instead of throwing while
/// the widget tree is building.
Future<NotificationSettings?> _notificationSettings() async {
  try {
    return await FirebaseMessaging.instance.getNotificationSettings();
  } catch (_) {
    return null;
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      // Only this subtree reacts to profile state.
      body: Consumer(
        builder: (context, ref, _) {
          final userAsync = ref.watch(currentAppUserProvider);
          return userAsync.when(
            loading: () =>
                const ShimmerList(count: 5, padding: EdgeInsets.all(16)),
            error: (e, _) => LoadError(
              message: 'Could not load your profile.',
              onRetry: () {
                ref.invalidate(appRepositoryProvider);
                ref.invalidate(currentAppUserProvider);
              },
            ),
            data: (user) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        child: Text(
                          user?.initials ?? '?',
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.displayName ?? '…',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(user?.email ?? ''),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FutureBuilder<NotificationSettings?>(
                  future: _notificationSettings(),
                  builder: (context, notifSnap) {
                    final status = notifSnap.data?.authorizationStatus;
                    final enabled = status == AuthorizationStatus.authorized ||
                        status == AuthorizationStatus.provisional;
                    return ListTile(
                      leading: Icon(enabled
                          ? Icons.notifications_active
                          : Icons.notifications_off),
                      title: const Text('Push notifications'),
                      subtitle: Text(enabled
                          ? 'On — you will be notified of new bills'
                          : 'Off — enable in system settings to get bill alerts'),
                    );
                  },
                ),
                const _SyncStatusTile(),
                const _DefaultCurrencyTile(),
                const _AppearanceTile(),
                const _AdFreeTile(),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  onTap: () => runGuarded(
                    context,
                    () async {
                      final uid = ref.read(currentUidProvider);
                      if (uid != null) {
                        await ref
                            .read(notificationServiceProvider)
                            .dispose(uid);
                      }
                      await ref.read(authServiceProvider).signOut();
                      ref.read(tabIndexProvider.notifier).set(0);
                    },
                    errorLabel: 'Could not sign out',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Offline/sync status — only this tile reacts to sync state.
/// The app is offline-first: everything is stored locally in SQLite
/// and synced with Firestore when a connection is available.
class _SyncStatusTile extends StatelessWidget {
  const _SyncStatusTile();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final status = ref.watch(syncStatusProvider).value;
        final online = status?.online ?? true;
        final pending = status?.pending ?? 0;
        final syncing = status?.syncing ?? false;
        final subtitle = status?.error != null
            ? 'Sync failed — will retry automatically'
            : !online
                ? 'Offline — changes are saved on this device'
                : pending > 0
                    ? '$pending change${pending == 1 ? '' : 's'} waiting to sync'
                    : status?.lastSyncedAt != null
                        ? 'All changes synced'
                        : 'Local data up to date';
        return ListTile(
          leading: Icon(
            syncing
                ? Icons.sync
                : online
                    ? Icons.cloud_done
                    : Icons.cloud_off,
          ),
          title: const Text('Sync'),
          subtitle: Text(subtitle),
          trailing: TextButton(
            onPressed: syncing
                ? null
                : () => runGuarded(
                      context,
                      () async {
                        final sync = await ref.read(syncServiceProvider.future);
                        await sync.syncNow();
                      },
                      errorLabel: 'Sync failed',
                    ),
            child: const Text('Sync now'),
          ),
        );
      },
    );
  }
}

/// Ad-Free subscription status. The free tier shows ads; the tile
/// opens the paywall. Subscribers see their active status.
class _AdFreeTile extends StatelessWidget {
  const _AdFreeTile();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final isAdFree = ref.watch(adFreeStatusProvider).value ?? false;
        if (isAdFree) {
          return const ListTile(
            leading: Icon(Icons.block),
            title: Text('Ad-Free'),
            subtitle: Text('Active — no ads'),
          );
        }
        return ListTile(
          leading: const Icon(Icons.block_outlined),
          title: const Text('Ad-Free'),
          subtitle: const Text('Remove all ads with a subscription'),
          trailing: const Text('Upgrade'),
          onTap: () => showPaywallSheet(context),
        );
      },
    );
  }
}
