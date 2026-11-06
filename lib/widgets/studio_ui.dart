import 'package:flutter/material.dart';

import '../theme.dart';

/// Shared elements for the Splitwize 2026 minimal financial design system.
class SplitwizeMark extends StatelessWidget {
  const SplitwizeMark({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: SplitwizePalette.forest,
        borderRadius: BorderRadius.circular(size * .29),
      ),
      child: Icon(Icons.call_split_rounded, color: SplitwizePalette.lime,
          size: size * .55),
    );
  }
}

class PageIntroduction extends StatelessWidget {
  const PageIntroduction({
    super.key, required this.title, required this.description, this.eyebrow,
  });
  final String title;
  final String description;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (eyebrow != null) ...[
          Text(eyebrow!.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2, color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
        ],
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 5),
        Text(description, style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
            ],
          ],
        )),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class SoftPanel extends StatelessWidget {
  const SoftPanel({
    super.key, required this.child, this.padding = const EdgeInsets.all(18),
    this.fill, this.border = true,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? fill;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: fill ?? scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: border ? Border.all(color: scheme.outlineVariant) : null,
      ),
      padding: padding,
      child: child,
    );
  }
}

class PersonMark extends StatelessWidget {
  const PersonMark({
    super.key, required this.initials, this.icon, this.size = 48, this.color,
  });
  final String initials;
  final IconData? icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size, height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(size * .33),
      ),
      child: icon != null
          ? Icon(icon, color: scheme.primary, size: size * .48)
          : Text(initials, style: TextStyle(
            color: scheme.onSurface, fontWeight: FontWeight.w800,
            fontSize: size * .27,
          )),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key, required this.label, required this.positive,
  });
  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = positive ? scheme.owed : scheme.owe;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: TextStyle(
        color: ink, fontSize: 11, fontWeight: FontWeight.w800,
      )),
    );
  }
}

class InlineEmpty extends StatelessWidget {
  const InlineEmpty({
    super.key, required this.icon, required this.title,
    required this.message, this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SoftPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          PersonMark(initials: '', icon: icon, size: 58),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant)),
          if (action != null) ...[
            const SizedBox(height: 16), action!,
          ],
        ]),
      ),
    );
  }
}
