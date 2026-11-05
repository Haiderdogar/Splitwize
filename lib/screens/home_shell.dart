import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../widgets/app_drawer.dart';
import '../widgets/animated_3d.dart';
import 'balances_tab.dart';
import 'bills_tab.dart';
import 'friends_tab.dart';
import 'groups_tab.dart';
import 'profile_tab.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const _tabs = [BillsTab(), BalancesTab(), GroupsTab(), FriendsTab(), ProfileTab()];
  static const _items = <({IconData icon, IconData active, String label, Color color})>[
    (icon: Icons.receipt_long_outlined, active: Icons.receipt_long_rounded, label: 'Bills', color: Color(0xFF19A995)),
    (icon: Icons.account_balance_wallet_outlined, active: Icons.account_balance_wallet_rounded, label: 'Balances', color: Color(0xFF6574E8)),
    (icon: Icons.groups_outlined, active: Icons.groups_rounded, label: 'Groups', color: Color(0xFFFFA34D)),
    (icon: Icons.people_outline_rounded, active: Icons.people_rounded, label: 'Friends', color: Color(0xFFE66A9B)),
    (icon: Icons.person_outline_rounded, active: Icons.person_rounded, label: 'Profile', color: Color(0xFF9A70E8)),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final index = ref.watch(tabIndexProvider);
      final dark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        key: splitwizeScaffoldKey,
        drawer: const SplitwizeDrawer(),
        extendBody: true,
        body: IndexedStack(index: index, children: _tabs),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 8),
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF1A1D38) : Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: dark ? Colors.white12 : const Color(0xFFE5E7F8)),
                boxShadow: [BoxShadow(
                  color: const Color(0xFF353A80).withValues(alpha: dark ? .22 : .12),
                  blurRadius: 28, offset: const Offset(0, 9))],
              ),
              child: Row(children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(child: _NavDestination(
                    item: _items[i], selected: index == i, dark: dark,
                    onTap: () => ref.read(tabIndexProvider.notifier).set(i),
                  )),
              ]),
            ),
          ),
        ),
      );
    });
  }
}

class _NavDestination extends StatelessWidget {
  const _NavDestination({required this.item, required this.selected, required this.dark, required this.onTap});
  final ({IconData icon, IconData active, String label, Color color}) item;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = dark ? const Color(0xFFB4B8D0) : const Color(0xFF8589A4);
    return Semantics(
      button: true, selected: selected, label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            gradient: selected ? LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [item.color.withValues(alpha: .20), item.color.withValues(alpha: .08)],
            ) : null,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: selected ? 1.12 : 1,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..setEntry(3, 2, .002)..rotateY(selected ? -.20 : 0),
                    child: Icon(selected ? item.active : item.icon, size: 23, color: selected ? item.color : muted),
                  ),
                ),
                const SizedBox(height: 3),
                Flexible(child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(item.label, maxLines: 1,
                    style: TextStyle(fontSize: 10.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? item.color : muted)),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
