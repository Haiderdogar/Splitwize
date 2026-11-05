import 'package:flutter/material.dart';

/// Splitwize's original Aurora design language. Every surface is Flutter
/// native: no external 3D engine, network image, or animation dependency.
abstract final class AuroraPalette {
  static const deep = Color(0xFF11194D);
  static const indigo = Color(0xFF5145EF);
  static const violet = Color(0xFF915BFA);
  static const cyan = Color(0xFF1BC8E5);
  static const coral = Color(0xFFFF789B);
  static const gold = Color(0xFFFFCA69);
  static const mint = Color(0xFF36D8A3);
}

class AuroraHero extends StatelessWidget {
  const AuroraHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.metric,
    this.metricLabel,
    this.bottom,
    this.colors = const [AuroraPalette.indigo, AuroraPalette.violet],
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final String? metric;
  final String? metricLabel;
  final Widget? bottom;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 540),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, progress, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .001)
          ..rotateY((1 - progress) * -.12)
          ..rotateX((1 - progress) * .08)
          ..scaleByDouble(.96 + (.04 * progress), .96 + (.04 * progress), 1.0, 1.0),
        child: child,
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: .23),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(children: [
          Positioned(
            right: -64,
            top: -76,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: .15),
                  width: 32,
                ),
              ),
            ),
          ),
          Positioned(
            right: 35,
            bottom: -44,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .07),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 20, 23),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.7,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .84),
                          fontSize: 12.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )),
                  const SizedBox(width: 10),
                  _AuroraSculpture(icon: icon),
                ]),
                if (metric != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .16),
                      border: Border.all(color: Colors.white.withValues(alpha: .23)),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(metric!, style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        height: 1.1,
                      )),
                      if (metricLabel != null) ...[
                        const SizedBox(width: 9),
                        Flexible(child: Text(metricLabel!, style: TextStyle(
                          color: Colors.white.withValues(alpha: .87),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ))),
                      ],
                    ]),
                  ),
                ],
                if (bottom != null) ...[
                  const SizedBox(height: 17),
                  bottom!,
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _AuroraSculpture extends StatelessWidget {
  const _AuroraSculpture({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 83,
      child: Stack(alignment: Alignment.center, children: [
        Positioned(
          top: 10,
          left: 6,
          child: Transform.rotate(
            angle: -.23,
            child: Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: AuroraPalette.cyan,
                boxShadow: const [
                  BoxShadow(color: Color(0x44000C65), blurRadius: 9, offset: Offset(0, 8)),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 3,
          right: 0,
          child: Transform.rotate(
            angle: .20,
            child: Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AuroraPalette.gold, AuroraPalette.coral]),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000D50), blurRadius: 8, offset: Offset(0, 5)),
                ],
              ),
              child: Icon(icon, size: 31, color: AuroraPalette.deep),
            ),
          ),
        ),
      ]),
    );
  }
}

class AuroraSectionHeading extends StatelessWidget {
  const AuroraSectionHeading(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 7, 2, 9),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -.3,
            )),
            if (subtitle != null)
              Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          ],
        )),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class AuroraActionTile extends StatelessWidget {
  const AuroraActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              constraints: const BoxConstraints(minHeight: 92),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .45)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: .11),
                    blurRadius: 13,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 41,
                  height: 41,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color.withValues(alpha: .26), color.withValues(alpha: .09)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class AuroraMonogram extends StatelessWidget {
  const AuroraMonogram({
    super.key,
    required this.label,
    this.color = AuroraPalette.indigo,
    this.icon,
    this.size = 50,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: .82), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * .34),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: .19), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: Center(child: icon != null
          ? Icon(icon, color: Colors.white, size: size * .48)
          : Text(label, maxLines: 1, style: TextStyle(
              color: Colors.white, fontSize: size * .28,
              fontWeight: FontWeight.w900,
            ))),
    );
  }
}
