import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../widgets/app_drawer.dart';
import 'balances_tab.dart';
import 'bills_tab.dart';
import 'friends_tab.dart';
import 'groups_tab.dart';
import 'profile_tab.dart';

/// Standard Material navigation: calm, predictable, and accessible.
/// The IndexedStack preserves each tab's list scroll and provider state.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _tabs = [
    BillsTab(), BalancesTab(), GroupsTab(), FriendsTab(), ProfileTab(),
  ];

  static const _items = <({IconData icon, IconData active, String label})>[
    (icon: Icons.space_dashboard_outlined,
     active: Icons.space_dashboard_rounded, label: 'Home'),
    (icon: Icons.account_balance_wallet_outlined,
     active: Icons.account_balance_wallet_rounded, label: 'Balances'),
    (icon: Icons.groups_outlined,
     active: Icons.groups_rounded, label: 'Groups'),
    (icon: Icons.people_outline_rounded,
     active: Icons.people_rounded, label: 'Friends'),
    (icon: Icons.person_outline_rounded,
     active: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(tabIndexProvider);
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 760;

    return Scaffold(
      key: splitwizeScaffoldKey,
      drawer: const SplitwizeDrawer(),
      body: wide
          ? Row(children: [
              SafeArea(
                child: NavigationRail(
                  selectedIndex: selected,
                  onDestinationSelected: ref.read(tabIndexProvider.notifier).set,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: scheme.surfaceContainerLowest,
                  indicatorColor: scheme.primaryContainer,
                  selectedIconTheme: IconThemeData(color: scheme.primary),
                  selectedLabelTextStyle: TextStyle(
                    color: scheme.primary, fontWeight: FontWeight.w800,
                  ),
                  destinations: [
                    for (final item in _items)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.active),
                        label: Text(item.label),
                      ),
                  ],
                ),
              ),
              VerticalDivider(width: 1, color: scheme.outlineVariant),
              Expanded(child: IndexedStack(index: selected, children: _tabs)),
            ])
          : IndexedStack(index: selected, children: _tabs),
      bottomNavigationBar: wide ? null : DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: selected,
            onDestinationSelected: ref.read(tabIndexProvider.notifier).set,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              for (final item in _items)
                NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.active),
                  label: item.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
