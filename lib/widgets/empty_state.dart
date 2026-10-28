import 'package:flutter/material.dart';

/// The app's standard "nothing here yet" view: a large visual, a bold
/// title, and a muted one-line explanation, all centred, plus an
/// optional action button so the empty state itself tells the user
/// what to do next (not just the FAB). Used by the Bills, Balances and
/// Notifications tabs so every empty screen reads the same — one
/// widget, not three hand-rolled copies.
///
/// [visual] replaces the default tonal-circle icon when a screen
/// wants its own art (e.g. a split bar on Bills). Both the circle and
/// any custom visual are decorative and hidden from screen readers.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.visual,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// When both are given, a filled button under the subtitle.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Custom decorative visual replacing the circle icon.
  final Widget? visual;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: visual ??
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 56, color: scheme.outline),
                  ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
