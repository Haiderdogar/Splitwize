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

  static const _items = <({String name, IconData icon})>[
    (name: 'Home', icon: Icons.space_dashboard_outlined),
    (name: 'Balances', icon: Icons.account_balance_wallet_outlined),
    (name: 'Groups', icon: Icons.groups_outlined),
    (name: 'Friends', icon: Icons.people_outline_rounded),
    (name: 'Notifications', icon: Icons.notifications_none_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(currentAppUserProvider).value;
    final google = ref.watch(authStateChangesProvider).value;
    final identity = resolveCurrentUserIdentity(
        cached: user,
        googleName: google?.displayName,
        googleEmail: google?.email);
    final selected = ref.watch(tabIndexProvider);
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
            Material(
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
                        Row(children: [
                          Expanded(
                              child: Text(identity.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.titleSmall)),
                          const SizedBox(width: 5),
                          Text('YOU',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: scheme.primary)),
                        ]),
                        if (identity.email.isNotEmpty)
                          Text(identity.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                        Text('View profile',
                            style: Theme.of(context).textTheme.labelSmall),
                      ],
                    )),
                    const Icon(Icons.chevron_right_rounded),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 25),
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 7),
              child: Text('WORKSPACE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurfaceVariant)),
            ),
            for (var i = 0; i < _items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: ListTile(
                  selected: selected == i,
                  selectedTileColor: scheme.primaryContainer,
                  selectedColor: scheme.onPrimaryContainer,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  leading: Icon(_items[i].icon),
                  title: Text(_items[i].name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    ref.read(tabIndexProvider.notifier).set(i);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 11),
              child: Divider(height: 1),
            ),
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
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('Simple splits. Clear balances.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}
