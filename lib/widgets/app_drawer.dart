import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../screens/profile_tab.dart';
import '../screens/settings_screen.dart';
import '../utils/current_user_identity.dart';
import 'logout_button.dart';
import 'studio_ui.dart';

final GlobalKey<ScaffoldState> splitwizeScaffoldKey =
    GlobalKey<ScaffoldState>();

class SplitwizeMenuButton extends StatelessWidget {
  const SplitwizeMenuButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Open menu',
        onPressed: () => splitwizeScaffoldKey.currentState?.openDrawer(),
        icon: const Icon(Icons.menu_rounded),
      );
}

class SplitwizeDrawer extends ConsumerWidget {
  const SplitwizeDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(currentAppUserProvider).value;
    final google = ref.watch(authStateChangesProvider).value;
    final identity = resolveCurrentUserIdentity(
        cached: user,
        googleName: google?.displayName,
        googleEmail: google?.email);
    return Drawer(
      width: MediaQuery.sizeOf(context).width < 370 ? 288 : 320,
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Row(children: [
                const SplitwizeMark(size: 42),
                const SizedBox(width: 12),
                Expanded(
                    child: Text('Splitwize',
                        style: Theme.of(context).textTheme.titleLarge)),
              ]),
            ),
            const SizedBox(height: 23),
            // The whole card opens the profile; the chevron says so, so there
            // is no separate "View profile" label.
            Semantics(
              button: true,
              hint: 'View profile',
              child: Material(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.push(
                        MaterialPageRoute(builder: (_) => const ProfileTab()));
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      PersonMark(initials: identity.initials, size: 44),
                      const SizedBox(width: 11),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(identity.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall),
                          if (identity.email.isNotEmpty)
                            Text(identity.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: scheme.onSurfaceVariant)),
                        ],
                      )),
                      const Icon(Icons.chevron_right_rounded),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onTap: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
            const LogoutButton(),
          ],
        ),
      ),
    );
  }
}
