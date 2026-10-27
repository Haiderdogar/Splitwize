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

/// Push-notification permission tile. It watches only
/// [notificationAuthorizationStatusProvider] — a cached provider —
/// so a Profile rebuild never re-queries Firebase Messaging, and
/// the tile never flickers back to "Off" while a fresh future is
/// pending (the old `FutureBuilder` built its future inside
/// `build`, so it did exactly that on every profile change).
class _PushNotificationsTile extends StatelessWidget {
  const _PushNotificationsTile();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final status = ref.watch(notificationAuthorizationStatusProvider).value;
        final enabled = status == AuthorizationStatus.authorized ||
            status == AuthorizationStatus.provisional;
        return ListTile(
          leading: Icon(
              enabled ? Icons.notifications_active : Icons.notifications_off),
          title: const Text('Push notifications'),
          subtitle: Text(enabled
              ? 'On — you will be notified of new bills'
              : 'Off — enable in system settings to get bill alerts'),
        );
      },
    );
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
            data: (user) {
              // UI-only regrouping: every tile below, and every tap
              // handler inside them, is unchanged. They are just
              // grouped into cards under a header card, instead of
              // one flat list of tiles.
              final colorScheme = Theme.of(context).colorScheme;
              const divider = Divider(height: 1, indent: 56, endIndent: 16);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header card: avatar, name and email on the
                  // theme's primary container, so it reads in both
                  // light and dark mode.
                  Card(
                    elevation: 0,
                    color: colorScheme.primaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 24),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            child: Text(
                              user?.initials ?? '?',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            user?.displayName ?? '…',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onPrimaryContainer
                                      .withValues(alpha: 0.8),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'SETTINGS',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.outline,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PushNotificationsTile(),
                        divider,
                        _SyncStatusTile(),
                        divider,
                        _DefaultCurrencyTile(),
                        divider,
                        _AppearanceTile(),
                        divider,
                        _AdFreeTile(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Icon(
                        Icons.logout,
                        color: colorScheme.error,
                      ),
                      title: Text(
                        'Sign out',
                        style: TextStyle(
                          color: colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                  ),
                ],
              );
            },
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
