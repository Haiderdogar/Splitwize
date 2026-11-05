import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../widgets/app_drawer.dart';
import '../widgets/aurora_ui.dart';
import 'balances_tab.dart';
import 'bills_tab.dart';
import 'friends_tab.dart';
import 'groups_tab.dart';
import 'profile_tab.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const _tabs = [BillsTab(), BalancesTab(), GroupsTab(), FriendsTab(), ProfileTab()];
  static const _items = <({IconData icon, IconData active, String label, Color color})>[
    (icon: Icons.receipt_long_outlined, active: Icons.receipt_long_rounded, label: 'Bills', color: AuroraPalette.indigo),
    (icon: Icons.account_balance_wallet_outlined, active: Icons.account_balance_wallet_rounded, label: 'Balances', color: AuroraPalette.cyan),
    (icon: Icons.groups_outlined, active: Icons.groups_rounded, label: 'Groups', color: AuroraPalette.violet),
    (icon: Icons.people_outline_rounded, active: Icons.people_rounded, label: 'Friends', color: AuroraPalette.coral),
    (icon: Icons.person_outline_rounded, active: Icons.person_rounded, label: 'Profile', color: AuroraPalette.indigo),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final index = ref.watch(tabIndexProvider);
      final dark = Theme.of(context).brightness == Brightness.dark;
      final wide = MediaQuery.sizeOf(context).width >= 760;
      return Scaffold(
        key: splitwizeScaffoldKey,
        drawer: const SplitwizeDrawer(),
        extendBody: !wide,
        body: wide
            ? Row(children: [
                SafeArea(child: NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (i) => ref.read(tabIndexProvider.notifier).set(i),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                  selectedIconTheme: const IconThemeData(color: AuroraPalette.indigo, size: 27),
                  unselectedIconTheme: IconThemeData(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  selectedLabelTextStyle: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w900,
                    color: AuroraPalette.indigo,
                  ),
                  useIndicator: true,
                  indicatorColor: AuroraPalette.indigo.withValues(alpha: .12),
                  destinations: [
                    for (final item in _items)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.active),
                        label: Text(item.label),
                      ),
                  ],
                )),
                const VerticalDivider(width: 1),
                Expanded(child: IndexedStack(index: index, children: _tabs)),
              ])
            : IndexedStack(index: index, children: _tabs),
        bottomNavigationBar: wide ? null : SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(27),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: 72,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xFF191A39).withValues(alpha: .92)
                        : Colors.white.withValues(alpha: .93),
                    borderRadius: BorderRadius.circular(27),
                    border: Border.all(
                      color: dark ? Colors.white.withValues(alpha: .10)
                          : const Color(0xFFDCE1FA),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AuroraPalette.indigo.withValues(alpha: .13),
                        blurRadius: 24,
                        offset: const Offset(0, 9),
                      ),
                    ],
                  ),
                  child: Row(children: [
                    for (var i = 0; i < _items.length; i++)
                      Expanded(child: _NavDestination(
                        item: _items[i],
                        selected: index == i,
                        dark: dark,
                        onTap: () => ref.read(tabIndexProvider.notifier).set(i),
                      )),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _NavDestination extends StatelessWidget {
  const _NavDestination({
    required this.item,
    required this.selected,
    required this.dark,
    required this.onTap,
  });
  final ({IconData icon, IconData active, String label, Color color}) item;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = dark ? const Color(0xFFB9C0DF) : const Color(0xFF777F9F);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              gradient: selected ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [item.color, item.color.withValues(alpha: .80)],
              ) : null,
              borderRadius: BorderRadius.circular(19),
              boxShadow: selected ? [
                BoxShadow(
                  color: item.color.withValues(alpha: .29),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ] : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: selected ? 1.08 : 1.0,
                  duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 240),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    selected ? item.active : item.icon,
                    size: 23,
                    color: selected ? Colors.white : muted,
                  ),
                ),
                const SizedBox(height: 3),
                Flexible(child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                      color: selected ? Colors.white : muted,
                    ),
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
