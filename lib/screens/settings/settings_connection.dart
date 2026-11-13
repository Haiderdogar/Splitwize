import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/core_providers.dart';
import '../../theme.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/studio_ui.dart';

/// Notification permission is managed by the operating system. This card
/// reports that permission without suggesting an app toggle can change it.
class SettingsNotificationsCard extends ConsumerWidget {
  const SettingsNotificationsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(notificationAuthorizationStatusProvider);
    final checking = permission.isLoading;
    final unavailable =
        !checking && (permission.hasError || permission.value == null);
    final enabled = permission.value == AuthorizationStatus.authorized ||
        permission.value == AuthorizationStatus.provisional;

    return _ConnectionCard(
      title: 'Push notifications',
      icon: enabled
          ? Icons.notifications_active_outlined
          : Icons.notifications_outlined,
      status: checking
          ? 'Checking permission…'
          : unavailable
              ? 'Status unavailable'
              : enabled
                  ? 'Enabled'
                  : 'Off',
      tone: unavailable
          ? _StatusTone.attention
          : enabled && !checking
              ? _StatusTone.positive
              : _StatusTone.neutral,
      description: checking
          ? 'Checking notification permission on this device.'
          : unavailable
              ? 'Notification status couldn’t be checked. Try again.'
              : enabled
                  ? 'New bills and payment updates.'
                  : 'Turn on notifications in your device settings.',
      action: unavailable
          ? OutlinedButton.icon(
              onPressed: () =>
                  ref.invalidate(notificationAuthorizationStatusProvider),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            )
          : null,
    );
  }
}

/// Keeps manual sync separate from the status stream, so repeated taps cannot
/// issue another request before the service publishes its syncing state.
class SettingsSyncCard extends ConsumerStatefulWidget {
  const SettingsSyncCard({super.key});

  @override
  ConsumerState<SettingsSyncCard> createState() => _SettingsSyncCardState();
}

class _SettingsSyncCardState extends ConsumerState<SettingsSyncCard> {
  bool _requesting = false;

  Future<void> _syncNow() async {
    if (_requesting || ref.read(syncStatusProvider).value?.syncing == true) {
      return;
    }
    setState(() => _requesting = true);
    try {
      await runGuarded(
        context,
        () async {
          final sync = await ref.read(syncServiceProvider.future);
          await sync.syncNow();
        },
        errorLabel: 'Sync failed',
      );
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(syncStatusProvider);
    final status = state.value;
    final checking = state.isLoading;
    final unavailable = state.hasError || (!checking && status == null);
    final failed = unavailable || status?.error != null;
    final offline = status?.online == false;
    final syncing = status?.syncing == true || _requesting;
    final pending = status?.pending ?? 0;

    final label = checking
        ? 'Checking'
        : failed
            ? 'Needs attention'
            : offline
                ? 'Offline'
                : syncing
                    ? 'Syncing'
                    : pending > 0
                        ? 'Waiting'
                        : 'Up to date';
    final description = checking
        ? 'Checking your connection and saved changes.'
        : unavailable
            ? 'Could not check sync status. Your changes stay saved on this device.'
            : status?.error != null
                ? 'Sync failed. Your changes are saved and will retry automatically.'
                : offline
                    ? pending > 0
                        ? 'Offline. $pending change${pending == 1 ? '' : 's'} '
                            'saved on this device and waiting to sync.'
                        : 'Offline. Your changes are saved on this device.'
                    : syncing
                        ? 'Syncing your changes. You can keep using the app.'
                        : pending > 0
                            ? '$pending change${pending == 1 ? '' : 's'} waiting to sync.'
                            : status?.lastSyncedAt != null
                                ? 'All changes synced.'
                                : 'Local data is up to date.';

    return _ConnectionCard(
      title: 'Sync',
      icon: checking || syncing
          ? Icons.sync_rounded
          : offline
              ? Icons.cloud_off_outlined
              : failed
                  ? Icons.cloud_outlined
                  : pending > 0
                      ? Icons.cloud_queue_outlined
                      : Icons.cloud_done_outlined,
      status: label,
      tone: checking || syncing || offline
          ? _StatusTone.neutral
          : failed
              ? _StatusTone.attention
              : pending > 0
                  ? _StatusTone.neutral
                  : _StatusTone.positive,
      description: description,
      action: OutlinedButton.icon(
        onPressed: syncing ? null : _syncNow,
        icon: const Icon(Icons.sync_rounded, size: 18),
        label: const Text('Sync now'),
      ),
    );
  }
}

enum _StatusTone { positive, neutral, attention }

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.title,
    required this.icon,
    required this.status,
    required this.tone,
    required this.description,
    this.action,
  });

  final String title;
  final IconData icon;
  final String status;
  final _StatusTone tone;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SoftPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 23, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title, style: theme.textTheme.titleMedium),
                    ),
                    const SizedBox(height: 8),
                    _ConnectionStatus(label: status, tone: tone),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              )),
          if (action != null) ...[
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerLeft, child: action),
          ],
        ],
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.label, required this.tone});

  final String label;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = switch (tone) {
      _StatusTone.positive => scheme.owed,
      _StatusTone.neutral => scheme.onSurfaceVariant,
      _StatusTone.attention => scheme.error,
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            )),
      ),
    );
  }
}
