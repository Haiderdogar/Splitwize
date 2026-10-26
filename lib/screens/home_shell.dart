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
        return Scaffold(
          body: IndexedStack(index: index, children: _tabs),
          bottomNavigationBar: NavigationBar(
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
        );
      },
    );
  }
}
