import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../providers/form_providers.dart';

/// One-time onboarding, shown exactly once per install (gated by
/// [OnboardingSeen] in `main.dart`). Three swipeable pages with
/// widget-drawn illustrations.
///
/// All state lives in [OnboardingFlow] — the page index and the
/// [PageController] — and every animation is implicit
/// (AnimatedContainer / AnimatedScale / AnimatedSlide), so this whole
/// screen is StatelessWidgets with [Consumer] only where state changes.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer(
        builder: (context, ref, _) {
          final page = ref.watch(onboardingFlowProvider.select((s) => s.page));
          final notifier = ref.read(onboardingFlowProvider.notifier);
          final scheme = Theme.of(context).colorScheme;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          // Soft per-page tint that cross-fades as you swipe.
          final tint = Color.alphaBlend(
            _kPages[page].accent.withValues(alpha: isDark ? 0.30 : 0.15),
            scheme.surface,
          );
          Future<void> finish() =>
              ref.read(onboardingSeenProvider.notifier).markSeen();
          return AnimatedContainer(
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [tint, scheme.surface],
                stops: const [0, 0.7],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _Header(
                    showSkip: page < _kPages.length - 1,
                    onSkip: finish,
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: notifier.controller,
                      onPageChanged: notifier.onPageChanged,
                      itemCount: _kPages.length,
                      itemBuilder: (context, i) => switch (i) {
                        0 => const _PageOne(),
                        1 => const _PageTwo(),
                        _ => const _PageThree(),
                      },
                    ),
                  ),
                  _Controls(
                    page: page,
                    onBack: notifier.previous,
                    onNext: page == _kPages.length - 1 ? finish : notifier.next,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page data
// ---------------------------------------------------------------------------

class _OnbPage {
  final Color accent;
  final String title;
  final String body;

  const _OnbPage({
    required this.accent,
    required this.title,
    required this.body,
  });
}

const _kPages = [
  _OnbPage(
    accent: Color(0xFF00897B),
    title: 'Split bills in seconds',
    body: 'Add a bill, pick who was there, and split it equally, by '
        'percentage, or with custom amounts. No more end-of-dinner maths.',
  ),
  _OnbPage(
    accent: Color(0xFF43A047),
    title: 'Everyone knows who owes what',
    body: 'Friends are notified the moment a bill is added. Track who '
        'has paid, send a friendly reminder, and settle up with one tap.',
  ),
  _OnbPage(
    accent: Color(0xFF1E88E5),
    title: 'Works offline, syncs by itself',
    body: 'No signal? No problem. Bills, groups and receipt photos are '
        'saved on your phone and synced securely when you are back online.',
  ),
];

// ---------------------------------------------------------------------------
// Chrome: header + controls
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.showSkip, required this.onSkip});

  final bool showSkip;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.receipt_long, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Splitwize',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (showSkip)
            TextButton(onPressed: onSkip, child: const Text('Skip')),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.page,
    required this.onBack,
    required this.onNext,
  });

  final int page;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _kPages[page].accent;
    final isLast = page == _kPages.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 20, 22),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: page > 0
                ? TextButton(onPressed: onBack, child: const Text('Back'))
                : null,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _kPages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == page ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == page ? accent : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
              ],
            ),
          ),
          // Flexible so the button can shrink on narrow screens /
          // large text scales; its label scales down inside.
          Flexible(
            child: FilledButton.icon(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              ),
              icon: Icon(isLast ? Icons.check : Icons.arrow_forward, size: 18),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(isLast ? 'Get started' : 'Next'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ---------------------------------------------------------------------------
// Pages
// ---------------------------------------------------------------------------

class _PageShell extends StatelessWidget {
  const _PageShell({
    required this.index,
    required this.art,
  });

  final int index;
  final Widget art;

  @override
  Widget build(BuildContext context) {
    final data = _kPages[index];
    final scheme = Theme.of(context).colorScheme;
    // Scrollable when the viewport is short (small phones, landscape)
    // so the page can never overflow; centered when there's room.
    // (ConstrainedBox + IntrinsicHeight is what lets the Column's
    // Spacers work inside a scroll view.)
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // The illustration is decorative — its labels are
                  // artwork, not content — so it doesn't grow with
                  // the accessibility text scale (which would break
                  // its fixed-size layout). Title/body below do scale.
                  MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.noScaling),
                    child: _AnimatedArt(index: index, child: art),
                  ),
                  const SizedBox(height: 38),
                  Text(
                    data.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data.body,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                  ),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pops the illustration in (scale + slight rise) when its page becomes
/// the active one — implicit animations only.
class _AnimatedArt extends StatelessWidget {
  const _AnimatedArt({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final active =
            ref.watch(onboardingFlowProvider.select((s) => s.page == index));
        return AnimatedSlide(
          offset: active ? Offset.zero : const Offset(0, 0.05),
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: active ? 1 : 0.93,
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOutCubic,
            child: child,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Illustration building blocks
// ---------------------------------------------------------------------------

/// A soft white "card" used as the base of each illustration.
class _ArtCard extends StatelessWidget {
  const _ArtCard({required this.child, this.width, this.padding});

  final Widget child;
  final double? width;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(this.width);

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 9,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .outlineVariant
            .withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size, required this.alpha});

  final Color color;
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: alpha),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _FloatChip extends StatelessWidget {
  const _FloatChip({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack(this.people);

  final List<(String, Color)> people;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30 + (people.length - 1) * 20,
      height: 30,
      child: Stack(
        children: [
          for (var i = 0; i < people.length; i++)
            Positioned(
              left: i * 20.0,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: people[i].$2,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    people[i].$1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 1 — split a bill
// ---------------------------------------------------------------------------

class _PageOne extends StatelessWidget {
  const _PageOne();

  @override
  Widget build(BuildContext context) {
    final accent = _kPages[0].accent;
    final scheme = Theme.of(context).colorScheme;
    return _PageShell(
      index: 0,
      art: SizedBox(
        height: 262,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
                top: 0,
                left: 26,
                child: _Blob(color: accent, size: 120, alpha: 0.14)),
            Positioned(
                bottom: 0,
                right: 20,
                child: _Blob(color: accent, size: 170, alpha: 0.10)),
            _ArtCard(
              width: 178,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_long, color: accent, size: 21),
                      const SizedBox(width: 8),
                      const Text('Dinner',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _Bar(142),
                  const SizedBox(height: 9),
                  const _Bar(110),
                  const SizedBox(height: 9),
                  const _Bar(126),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Text('Total',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      const Spacer(),
                      const Text('Rs 8,600.00',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _AvatarStack([
                    ('A', Color(0xFF00897B)),
                    ('S', Color(0xFFEF6C00)),
                    ('F', Color(0xFF5E35B1)),
                    ('H', Color(0xFF43A047)),
                  ]),
                ],
              ),
            ),
            Positioned(
              top: 30,
              right: 30,
              child: Transform.rotate(
                angle: -0.09,
                child: _FloatChip(
                  icon: Icons.balance,
                  label: 'Equal split',
                  background: accent,
                  foreground: Colors.white,
                ),
              ),
            ),
            Positioned(
              bottom: 34,
              left: 18,
              child: Transform.rotate(
                angle: 0.07,
                child: _FloatChip(
                  icon: Icons.percent,
                  label: '50% · custom',
                  background: scheme.surfaceContainerLowest,
                  foreground: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 2 — everyone in the loop
// ---------------------------------------------------------------------------

class _PageTwo extends StatelessWidget {
  const _PageTwo();

  @override
  Widget build(BuildContext context) {
    final accent = _kPages[1].accent;
    final scheme = Theme.of(context).colorScheme;
    return _PageShell(
      index: 1,
      art: SizedBox(
        height: 262,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
                top: 4,
                right: 30,
                child: _Blob(color: accent, size: 130, alpha: 0.13)),
            Positioned(
                bottom: 2,
                left: 22,
                child: _Blob(color: accent, size: 160, alpha: 0.09)),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _ArtCard(
                      width: 276,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.notifications,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('New bill: Dinner',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5)),
                                Text('Your share  Rs 2,150.00',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant)),
                              ],
                            ),
                          ),
                          Text('now',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Positioned(
                      top: -7,
                      right: -5,
                      child: Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.surface, width: 2.5),
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ArtCard(
                  width: 276,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PaidRow(
                          name: 'Ahmed Raza',
                          color: const Color(0xFFEF6C00),
                          accent: accent),
                      const Divider(height: 16),
                      _PaidRow(
                          name: 'Sara Khan',
                          color: const Color(0xFF5E35B1),
                          accent: accent),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaidRow extends StatelessWidget {
  const _PaidRow({
    required this.name,
    required this.color,
    required this.accent,
  });

  final String name;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color,
          child: Text(
            name[0],
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text('$name paid', style: const TextStyle(fontSize: 13)),
        ),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check, color: accent, size: 14),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Page 3 — offline-first sync
// ---------------------------------------------------------------------------

class _PageThree extends StatelessWidget {
  const _PageThree();

  @override
  Widget build(BuildContext context) {
    final accent = _kPages[2].accent;
    final green = _kPages[1].accent;
    return _PageShell(
      index: 2,
      art: SizedBox(
        height: 262,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
                top: 0,
                left: 34,
                child: _Blob(color: accent, size: 120, alpha: 0.13)),
            Positioned(
                bottom: 4,
                right: 26,
                child: _Blob(color: accent, size: 150, alpha: 0.09)),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.09),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(Icons.cloud_sync, size: 54, color: accent),
                ),
                const SizedBox(height: 20),
                _SyncPill(
                  icon: Icons.wifi_off,
                  label: 'Offline? Saved on your device',
                  background:
                      Theme.of(context).colorScheme.surfaceContainerHigh,
                  foreground: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Icon(Icons.arrow_downward, size: 17, color: accent),
                ),
                _SyncPill(
                  icon: Icons.check,
                  label: 'Back online? Synced automatically',
                  background: green,
                  foreground: Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncPill extends StatelessWidget {
  const _SyncPill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
