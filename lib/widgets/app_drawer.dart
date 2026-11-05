import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import 'animated_3d.dart';
import '../providers/data_providers.dart';
import '../screens/notifications_screen.dart';

/// Shared drawer controller used by the tab app bars.
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

/// Navigation drawer for the main app shell. All destinations reuse the
/// existing tab provider; no business logic or data flow is changed.
class SplitwizeDrawer extends ConsumerWidget {
  const SplitwizeDrawer({super.key});

  static const _items = <({String title, IconData icon, int index, Color color})>[
    (title: 'My bills', icon: Icons.receipt_long_rounded, index: 0, color: Color(0xFF26A69A)),
    (title: 'Balances', icon: Icons.account_balance_wallet_rounded, index: 1, color: Color(0xFF5C6BC0)),
    (title: 'Groups', icon: Icons.groups_rounded, index: 2, color: Color(0xFFFFA726)),
    (title: 'Friends', icon: Icons.diversity_3_rounded, index: 3, color: Color(0xFFEC407A)),
    (title: 'Profile & settings', icon: Icons.tune_rounded, index: 4, color: Color(0xFF7E57C2)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(currentAppUserProvider).value;
    final selected = ref.watch(tabIndexProvider);
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.82,
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF073B4C), Color(0xFF087F8C), Color(0xFF26A69A)],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Splitwize3DBrand(size: 62),
                  const SizedBox(height: 18),
                  const Text('Splitwize', style: TextStyle(
                    color: Colors.white, fontSize: 27, fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  )),
                  const SizedBox(height: 4),
                  Text('Better together. Easier to split.',
                    style: TextStyle(color: Colors.white.withValues(alpha: .82), fontSize: 13)),
                  const SizedBox(height: 18),
                  Row(children: [
                    CircleAvatar(
                      radius: 21,
                      backgroundColor: Colors.white.withValues(alpha: .2),
                      child: Text(user?.initials ?? '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 11),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.displayName ?? 'Welcome to Splitwize',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        Text(user?.email ?? 'Your shared expenses, organised',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 11)),
                      ],
                    )),
                  ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('WORKSPACE', style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
              ),
            ),
            Expanded(child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final item in _items)
                  _DrawerDestination(
                    title: item.title, icon: item.icon, color: item.color,
                    selected: selected == item.index,
                    onTap: () {
                      ref.read(tabIndexProvider.notifier).set(item.index);
                      Navigator.of(context).pop();
                    },
                  ),
                const SizedBox(height: 12),
                const Divider(indent: 12, endIndent: 12),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.arrow_outward_rounded, size: 17),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()));
                  },
                ),
              ],
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Row(children: [
                Icon(Icons.shield_moon_outlined, size: 17, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: Text('Your expenses stay in sync, even offline.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerDestination extends StatelessWidget {
  const _DrawerDestination({required this.title, required this.icon,
    required this.color, required this.selected, required this.onTap});
  final String title;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? scheme.primaryContainer.withValues(alpha: .72) : Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: .12), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 13),
              Expanded(child: Text(title, style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? scheme.primary : scheme.onSurface))),
              if (selected) Icon(Icons.arrow_right_rounded, color: scheme.primary),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A tiny layered mark with a gentle floating/rotating animation. It is
/// vector-drawn so it works without bundled image assets.
class _AnimatedBrandMark extends StatefulWidget {
  const _AnimatedBrandMark();

  @override
  State<_AnimatedBrandMark> createState() => _AnimatedBrandMarkState();
}

class _AnimatedBrandMarkState extends State<_AnimatedBrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Transform.translate(
      offset: Offset(0, -3 * _controller.value),
      child: Transform.rotate(
        angle: (_controller.value - .5) * .08,
        child: Container(
          width: 62, height: 62,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFFFFD166), Color(0xFFFF7B54), Color(0xFFEF476F)]),
            borderRadius: BorderRadius.circular(21),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .22), blurRadius: 18, offset: const Offset(0, 9))],
          ),
          child: Stack(alignment: Alignment.center, children: [
            Transform.translate(offset: const Offset(5, 5),
              child: Icon(Icons.call_split_rounded, size: 34, color: Colors.white.withValues(alpha: .35))),
            const Icon(Icons.call_split_rounded, size: 34, color: Colors.white),
            const Positioned(right: 8, top: 8,
              child: Icon(Icons.auto_awesome_rounded, size: 13, color: Color(0xFFFFF3C4))),
          ]),
        ),
      ),
    ),
  );
}
