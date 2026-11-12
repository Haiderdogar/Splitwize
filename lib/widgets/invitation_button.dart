import 'package:flutter/material.dart';

/// A section action whose counter totals incoming and outgoing invitations.
class InvitationButton extends StatelessWidget {
  const InvitationButton({
    super.key,
    required this.count,
    required this.tooltip,
    required this.onPressed,
  }) : assert(count >= 0);

  final int count;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pending = count > 0;
    final dark = scheme.brightness == Brightness.dark;
    final compact = MediaQuery.sizeOf(context).width < 480 &&
        MediaQuery.textScalerOf(context).scale(14) > 18;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final foreground = scheme.onPrimary;
    final radius = BorderRadius.circular(16);
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 240);

    return Semantics(
      label: tooltip,
      value: pending
          ? '$count pending ${count == 1 ? 'invitation' : 'invitations'}'
          : 'No pending invitations',
      button: true,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: radius,
            border: Border.all(color: scheme.primary),
            boxShadow: pending
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: dark ? .08 : .14),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              onTap: onPressed,
              borderRadius: radius,
              splashColor: foreground.withValues(alpha: .14),
              highlightColor: foreground.withValues(alpha: .08),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 12, vertical: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: foreground.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(Icons.inbox_outlined,
                          size: 18, color: foreground),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 8),
                      Text('Invites',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                  color: foreground,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                    ],
                    AnimatedSwitcher(
                      duration: duration,
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      ),
                      child: pending
                          ? Padding(
                              key: ValueKey(count),
                              padding: const EdgeInsets.only(left: 8),
                              child: Container(
                                constraints: const BoxConstraints(
                                    minWidth: 26, minHeight: 26),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 4),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text('$count',
                                    textScaler: MediaQuery.textScalerOf(context)
                                        .clamp(maxScaleFactor: 1.3),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      height: 1.1,
                                      color: scheme.onPrimaryContainer,
                                    )),
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('empty')),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
