import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/form_providers.dart';
import '../widgets/animated_3d.dart';
import '../widgets/aurora_ui.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [colorScheme.surfaceContainerLow, colorScheme.surface],
        )),
        child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Splitwize3DBrand(size: 104),
                const SizedBox(height: 24),
                Text(
                  'Splitwize',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 33,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                const AuroraHero(
                  eyebrow: 'WELCOME TO BETTER TOGETHER',
                  title: 'Split. Settle.\nSmile.',
                  subtitle: 'Turn shared expenses into great memories, without the awkward maths.',
                  icon: Icons.favorite_rounded,
                  colors: [AuroraPalette.indigo, AuroraPalette.violet],
                ),
                const SizedBox(height: 8),
                Text(
                  'One simple place for all your shared moments.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 36),
                // Only the button reacts to sign-in state.
                Consumer(
                  builder: (context, ref, _) {
                    final busy = ref.watch(signInProvider);
                    return SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                final err = await ref
                                    .read(signInProvider.notifier)
                                    .signIn();
                                if (err != null && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(err)),
                                  );
                                }
                              },
                        icon: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login),
                        label: const Text('Sign in with Google'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Your account is created automatically on first sign-in.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
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
