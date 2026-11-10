import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../widgets/app_drawer.dart';
import 'balances_tab.dart';
import 'bills_tab.dart';
import 'friends_tab.dart';
import 'groups_tab.dart';
import 'requests_tab.dart';
import '../providers/data_providers.dart';

/// Standard Material navigation: calm, predictable, and accessible.
/// The IndexedStack preserves each tab's list scroll and provider state.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _tabs = [
    BillsTab(), BalancesTab(), GroupsTab(), FriendsTab(), RequestsTab(),
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
    (icon: Icons.mark_email_unread_outlined,
     active: Icons.mark_email_read_rounded, label: 'Requests'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(tabIndexProvider);
    final int pending = (ref.watch(groupInvitesProvider.select(
          (v) => v.value?.length ?? 0)) +
        ref.watch(incomingRequestsProvider.select(
          (v) => v.value?.length ?? 0))).toInt();
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
                    for (var i = 0; i < _items.length; i++)
                      NavigationRailDestination(
                        icon: _navIcon(_items[i].icon, i == 4 ? pending : 0),
                        selectedIcon: _navIcon(_items[i].active, i == 4 ? pending : 0),
                        label: Text(_items[i].label),
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
              for (var i = 0; i < _items.length; i++)
                NavigationDestination(
                  icon: _navIcon(_items[i].icon, i == 4 ? pending : 0),
                  selectedIcon: _navIcon(_items[i].active, i == 4 ? pending : 0),
                  label: _items[i].label,
                ),
            ],
          ),
        ),
      ),
    );
  }
  static Widget _navIcon(IconData icon, int pending) => Badge(
        isLabelVisible: pending > 0,
        label: Text('$pending'),
        child: Icon(icon),
      );
}
