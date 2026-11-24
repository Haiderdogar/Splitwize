import 'package:flutter/material.dart';

import '../widgets/logout_button.dart';
import 'settings/settings_connection.dart';
import 'settings/settings_preferences.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Settings'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const ValueKey('settings-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SettingsHeading('Personalize'),
                  const SizedBox(height: 12),
                  Material(
                    color: scheme.surfaceContainerLowest,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: scheme.outlineVariant)),
                    child: const SettingsPreferences(),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                        'Your currency is used for new groups and friend expenses.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                  const SizedBox(height: 28),
                  const _SettingsHeading('Stay connected'),
                  const SizedBox(height: 12),
                  const SettingsNotificationsCard(),
                  const SizedBox(height: 12),
                  const SettingsSyncCard(),
                  const SizedBox(height: 28),
                  // Log out is the only account action, so it has no heading.
                  Material(
                    color: scheme.surfaceContainerLowest,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                            color: scheme.error.withValues(alpha: .2))),
                    child: const LogoutButton(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}
