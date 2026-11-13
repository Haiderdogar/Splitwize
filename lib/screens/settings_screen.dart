import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/monetization_providers.dart';
import '../widgets/logout_button.dart';
import '../widgets/paywall_sheet.dart';
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16)),
                      child: Icon(Icons.tune_rounded,
                          color: scheme.onPrimaryContainer, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your app, your way.',
                            style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 6),
                        Text('A few preferences for easier sharing.',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    )),
                  ]),
                  const SizedBox(height: 28),
                  const _SettingsHeading('Personalize',
                      subtitle: 'Small touches that make Splitwize yours.'),
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
                  const _SettingsHeading('Stay connected',
                      subtitle: 'Keep up with shared expenses and updates.'),
                  const SizedBox(height: 12),
                  const SettingsNotificationsCard(),
                  const SizedBox(height: 12),
                  const SettingsSyncCard(),
                  const SizedBox(height: 28),
                  const _AdFreeCard(),
                  const SizedBox(height: 28),
                  const _SettingsHeading('Account'),
                  const SizedBox(height: 12),
                  Material(
                    color: scheme.surfaceContainerLowest,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                            color: scheme.error.withValues(alpha: .2))),
                    child: const LogoutButton(),
                  ),
                  const SizedBox(height: 28),
                  Text('Simple splits. Clear balances.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
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
  const _SettingsHeading(this.title, {this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ]),
      );
}

class _AdFreeCard extends ConsumerWidget {
  const _AdFreeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final plan = ref.watch(adFreeStatusProvider);
    final active = plan.value == true;
    final loading = plan.isLoading && !plan.hasValue;
    final failed = plan.hasError && !plan.hasValue;
    final dark = scheme.brightness == Brightness.dark;
    final foreground = dark ? scheme.onSurface : scheme.onPrimary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: dark ? scheme.surfaceContainerHigh : scheme.primary,
          borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(active ? Icons.verified_outlined : Icons.block_outlined,
              color: foreground, size: 22),
          const SizedBox(width: 10),
          Expanded(
              child: Text('Ad-Free',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: foreground))),
          if (active)
            Text('Active',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: foreground, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        Text(
            loading
                ? 'Checking your plan…'
                : failed
                    ? 'Plan unavailable'
                    : active
                        ? 'More sharing. Zero ads.'
                        : 'Keep the focus on your friends.',
            style: theme.textTheme.titleLarge?.copyWith(color: foreground)),
        const SizedBox(height: 8),
        Text(
            failed
                ? 'We couldn’t load your subscription. Please try again.'
                : loading
                    ? 'Your subscription status will appear here.'
                    : active
                        ? 'Enjoy Splitwize without ads across the app.'
                        : 'Remove ads across Splitwize with an Ad-Free subscription.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: foreground.withValues(alpha: .8))),
        if (!active && !loading) ...[
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer),
            onPressed: failed
                ? () => ref.invalidate(adFreeStatusProvider)
                : () => showPaywallSheet(context),
            icon: Icon(
                failed ? Icons.refresh_rounded : Icons.arrow_forward_rounded,
                size: 18),
            label: Text(failed ? 'Retry' : 'Upgrade'),
          ),
        ],
      ]),
    );
  }
}
