import 'package:currency_picker/currency_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../utils/money.dart';

class SettingsPreferences extends StatelessWidget {
  const SettingsPreferences({super.key});

  @override
  Widget build(BuildContext context) => const Column(
        children: [
          _AppearancePreference(),
          Divider(height: 1, indent: 72, endIndent: 16),
          _CurrencyPreference(),
        ],
      );
}

class _AppearancePreference extends ConsumerWidget {
  const _AppearancePreference();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(themeModeSettingProvider);
    final mode = preference.value;
    return _PreferenceRow(
      icon: switch (mode) {
        AppTheme.dark => Icons.dark_mode_outlined,
        AppTheme.light => Icons.light_mode_outlined,
        _ => Icons.brightness_auto_outlined,
      },
      title: 'Appearance',
      subtitle: mode?.label ??
          (preference.hasError
              ? 'Could not load your preference. Tap to retry.'
              : 'Loading preference…'),
      onTap: preference.isLoading && mode == null
          ? null
          : () {
              if (preference.hasError && mode == null) {
                ref.invalidate(themeModeSettingProvider);
                return;
              }
              showDialog<void>(
                  context: context, builder: (_) => const _ThemePickerDialog());
            },
    );
  }
}

class _CurrencyPreference extends ConsumerWidget {
  const _CurrencyPreference();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider);
    final loading = user.isLoading && !user.hasValue;
    final failed = user.hasError && !user.hasValue;
    final code = user.value?.currencyCode ?? 'USD';
    return _PreferenceRow(
      icon: Icons.payments_outlined,
      title: 'Default currency',
      subtitle: loading
          ? 'Loading currency…'
          : failed
              ? 'Could not load your currency. Tap to retry.'
              : currencyLabel(code),
      value: loading || failed ? null : code,
      onTap: loading
          ? null
          : () {
              if (failed) {
                ref.invalidate(currentAppUserProvider);
                return;
              }
              showCurrencyPicker(
                context: context,
                showFlag: true,
                favorite: const [
                  'PKR',
                  'USD',
                  'EUR',
                  'GBP',
                  'AED',
                  'SAR',
                  'INR'
                ],
                onSelect: (currency) async {
                  try {
                    final repo = await ref.read(appRepositoryProvider.future);
                    await repo.setMyCurrency(currency.code);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'Default currency set to ${currency.code}.')));
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Could not set currency. Please try again.')));
                    }
                  }
                },
              );
            },
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.value,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: scheme.primary, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  if (value != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(value!,
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          )),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded,
              size: 20, color: scheme.onSurfaceVariant),
        ]),
      ),
    );
  }
}

class _ThemePickerDialog extends ConsumerStatefulWidget {
  const _ThemePickerDialog();

  @override
  ConsumerState<_ThemePickerDialog> createState() => _ThemePickerDialogState();
}

class _ThemePickerDialogState extends ConsumerState<_ThemePickerDialog> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(themeModeSettingProvider).value ?? AppTheme.system;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: const Text('Appearance'),
        content:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Choose a look that feels right for you.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          IgnorePointer(
            ignoring: _saving,
            child: RadioGroup<AppTheme>(
              groupValue: mode,
              onChanged: (value) async {
                if (value == null || _saving) return;
                setState(() => _saving = true);
                try {
                  await ref
                      .read(themeModeSettingProvider.notifier)
                      .setMode(value);
                  if (context.mounted) {
                    setState(() => _saving = false);
                    Navigator.of(context).pop();
                  }
                } catch (_) {
                  if (!mounted || !context.mounted) return;
                  setState(() => _saving = false);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Could not save appearance. Please try again.')));
                }
              },
              child: Column(children: [
                for (final option in AppTheme.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: mode == option
                          ? scheme.surfaceContainerLow
                          : scheme.surfaceContainerLowest,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                              color: mode == option
                                  ? scheme.primary
                                  : scheme.outlineVariant)),
                      child: RadioListTile<AppTheme>(
                        value: option,
                        title: Text(option.label),
                        secondary: Icon(
                            switch (option) {
                              AppTheme.system => Icons.brightness_auto_outlined,
                              AppTheme.light => Icons.light_mode_outlined,
                              AppTheme.dark => Icons.dark_mode_outlined,
                            },
                            size: 22),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          )
        ],
      ),
    );
  }
}
