import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../widgets/app_drawer.dart';
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

  // These colors and dimensions mirror the floating glass navigation bar
  // used in the Expense Tracker app. They are kept local so this UI-only
  // update does not introduce dependencies into Splitwize.
  static const _primaryEmerald = Color(0xFF2563EB);
  static const _deepForest = Color(0xFF111827);
  static const _mintAccent = Color(0xFF60A5FA);
  static const _gray200 = Color(0xFFE2E8F0);
  static const _gray400 = Color(0xFF94A3B8);
  static const _gray600 = Color(0xFF475569);

  @override
  Widget build(BuildContext context) {
    // Only the shell reacts to the selected tab.
    return Consumer(
      builder: (context, ref, _) {
        final index = ref.watch(tabIndexProvider);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          key: splitwizeScaffoldKey,
          drawer: const SplitwizeDrawer(),
          extendBody: true,
          body: IndexedStack(index: index, children: _tabs),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    height: 62,
                    decoration: BoxDecoration(
                      color: isDark
                          ? _deepForest.withValues(alpha: 0.75)
                          : Colors.white.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark
                            ? _mintAccent.withValues(alpha: 0.2)
                            : _gray200.withValues(alpha: 0.8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.3 : 0.08,
                          ),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(
                          index: 0,
                          currentIndex: index,
                          icon: Icons.receipt_long_outlined,
                          activeIcon: Icons.receipt_long,
                          label: 'Bills',
                          isDark: isDark,
                          onTap: (i) =>
                              ref.read(tabIndexProvider.notifier).set(i),
                        ),
                        _buildNavItem(
                          index: 1,
                          currentIndex: index,
                          icon: Icons.account_balance_wallet_outlined,
                          activeIcon: Icons.account_balance_wallet,
                          label: 'Balances',
                          isDark: isDark,
                          onTap: (i) =>
                              ref.read(tabIndexProvider.notifier).set(i),
                        ),
                        _buildNavItem(
                          index: 2,
                          currentIndex: index,
                          icon: Icons.group_outlined,
                          activeIcon: Icons.group,
                          label: 'Groups',
                          isDark: isDark,
                          onTap: (i) =>
                              ref.read(tabIndexProvider.notifier).set(i),
                        ),
                        _buildNavItem(
                          index: 3,
                          currentIndex: index,
                          icon: Icons.people_outline,
                          activeIcon: Icons.people,
                          label: 'Friends',
                          isDark: isDark,
                          onTap: (i) =>
                              ref.read(tabIndexProvider.notifier).set(i),
                        ),
                        _buildNavItem(
                          index: 4,
                          currentIndex: index,
                          icon: Icons.person_outline,
                          activeIcon: Icons.person,
                          label: 'Profile',
                          isDark: isDark,
                          onTap: (i) =>
                              ref.read(tabIndexProvider.notifier).set(i),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required int index,
    required int currentIndex,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isDark,
    required ValueChanged<int> onTap,
  }) {
    final selected = index == currentIndex;
    final color = selected
        ? _primaryEmerald
        : (isDark ? _gray400 : _gray600);

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
