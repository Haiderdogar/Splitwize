import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/form_providers.dart';
import '../widgets/studio_ui.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: SplitwizeMark(size: 76),
                  ),
                  const SizedBox(height: 28),
                  Text('Share the moments.\nNot the maths.',
                    style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 12),
                  Text(
                    'The simple way to track shared expenses, '
                    'see who owes what and settle up.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant, height: 1.5),
                  ),
                  const SizedBox(height: 30),
                  const SoftPanel(child: Column(children: [
                    _FeatureLine(
                      icon: Icons.receipt_long_outlined,
                      label: 'Add expenses in seconds'),
                    Divider(height: 23),
                    _FeatureLine(
                      icon: Icons.balance_outlined,
                      label: 'Keep every balance clear'),
                    Divider(height: 23),
                    _FeatureLine(
                      icon: Icons.cloud_done_outlined,
                      label: 'Stay in sync, even offline'),
                  ])),
                  const SizedBox(height: 28),
                  Consumer(builder: (context, ref, _) {
                    final busy = ref.watch(signInProvider);
                    return FilledButton.icon(
                      onPressed: busy ? null : () async {
                        final err = await ref.read(signInProvider.notifier).signIn();
                        if (err != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(err)));
                        }
                      },
                      icon: busy
                        ? const SizedBox(width: 19, height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2))
                        : const Icon(Icons.login_rounded),
                      label: const Text('Sign in with Google'),
                    );
                  }),
                  const SizedBox(height: 12),
                  Text('An account is created automatically on first sign-in.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      Icon(icon, color: scheme.primary, size: 23),
      const SizedBox(width: 12),
      Expanded(child: Text(label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600))),
    ]);
  }
}
