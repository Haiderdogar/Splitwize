import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import 'balances_tab.dart';
import 'bills_tab.dart';
import 'friends_tab.dart';
import 'groups_tab.dart';
import 'profile_tab.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const _tabs = [
    BillsTab(),
    BalancesTab(),
    GroupsTab(),
    FriendsTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    // Only the shell reacts to the selected tab.
    return Consumer(
      builder: (context, ref, _) {
        final index = ref.watch(tabIndexProvider);
        final colorScheme = Theme.of(context).colorScheme;
        return Scaffold(
          body: IndexedStack(index: index, children: _tabs),
          // Modern floating pill bar: the same 5 destinations, in the
          // same order, with the same selection handler — only the
          // chrome changes. It floats above the content with side
          // and bottom margins, a soft shadow, and a rounded pill
          // indicator, instead of a full-width bar on the bottom edge.
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: NavigationBar(
                    backgroundColor: Colors.transparent,
                    indicatorColor: colorScheme.primaryContainer,
                    indicatorShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    selectedIndex: index,
                    onDestinationSelected: (i) =>
                        ref.read(tabIndexProvider.notifier).set(i),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long),
                        label: 'Bills',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.account_balance_wallet_outlined),
                        selectedIcon: Icon(Icons.account_balance_wallet),
                        label: 'Balances',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.group_outlined),
                        selectedIcon: Icon(Icons.group),
                        label: 'Groups',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.people_outline),
                        selectedIcon: Icon(Icons.people),
                        label: 'Friends',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: 'Profile',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
