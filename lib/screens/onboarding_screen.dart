import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../providers/form_providers.dart';
import '../providers/onboarding_motion_provider.dart';
import '../theme.dart';
import '../widgets/onboarding_art.dart';
import '../widgets/studio_ui.dart';

/// One-time onboarding with native, layered 3D illustrations.
/// Auto-disposed providers own the flow and animation lifetimes.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer(builder: (context, ref, _) {
        final page = ref.watch(onboardingFlowProvider.select((s) => s.page));
        final flow = ref.read(onboardingFlowProvider.notifier);
        final scheme = Theme.of(context).colorScheme;
        final reduceMotion = MediaQuery.disableAnimationsOf(context);
        final motion = ref.watch(onboardingMotionProvider);
        motion
            .setEnabled(!reduceMotion && TickerMode.valuesOf(context).enabled);

        Future<void> finish() =>
            ref.read(onboardingSeenProvider.notifier).markSeen();

        void goTo(int index) {
          if (reduceMotion) {
            flow.controller.jumpToPage(index);
          } else {
            flow.controller.animateToPage(index,
                duration: const Duration(milliseconds: 620),
                curve: const Cubic(.22, 1, .36, 1));
          }
        }

        return AnimatedContainer(
          duration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 650),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -.5),
              radius: .9,
              colors: [
                Color.alphaBlend(
                  _pages[page].accent.withValues(
                      alpha: scheme.brightness == Brightness.dark ? .11 : .10),
                  scheme.surface,
                ),
                scheme.surface,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(children: [
              _Header(page: page, onSkip: finish),
              Expanded(
                child: PageView.builder(
                  controller: flow.controller,
                  onPageChanged: flow.onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, index) => _OnboardingPage(
                    index: index,
                    controller: flow.controller,
                    motion: motion,
                    reduceMotion: reduceMotion,
                  ),
                ),
              ),
              _Controls(
                page: page,
                reduceMotion: reduceMotion,
                onBack: () => goTo(page - 1),
                onNext:
                    page == _pages.length - 1 ? finish : () => goTo(page + 1),
                onSelect: goTo,
              ),
            ]),
          ),
        );
      }),
    );
  }
}

class _PageData {
  const _PageData(this.title, this.body, this.accent, this.detail, this.icon);
  final String title;
  final String body;
  final Color accent;
  final String detail;
  final IconData icon;
}

const _pages = [
  _PageData(
    'Good times.\nFair shares.',
    'Dinner, a weekend away, or the everyday.\n'
        'Split any bill, any way that works for you.',
    SplitwizePalette.lime,
    'Equal, percentage, or custom splits',
    Icons.call_split_rounded,
  ),
  _PageData(
    'Less chasing.\nMore living.',
    'Keep everyone in the loop. See who owes what,\n'
        'send a little nudge, and settle up together.',
    SplitwizePalette.coral,
    'Clear balances. Happier friendships.',
    Icons.favorite_border_rounded,
  ),
  _PageData(
    'Go anywhere.\nStay in sync.',
    'Add your expenses, even off the grid.\n'
        'We\'ll sync everything when you\'re back online.',
    SplitwizePalette.lime,
    'Offline ready. Automatically synced.',
    Icons.cloud_done_outlined,
  ),
];

class _Header extends StatelessWidget {
  const _Header({required this.page, required this.onSkip});
  final int page;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 16, 4),
          child: Row(children: [
            const ExcludeSemantics(child: SplitwizeMark(size: 32)),
            const SizedBox(width: 9),
            Expanded(
              child: Text('splitwize',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.8)),
            ),
            if (page < _pages.length - 1)
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                    foregroundColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    minimumSize: const Size(48, 48)),
                child: const Text('Skip'),
              )
            else
              const SizedBox(height: 48),
          ]),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.index,
    required this.controller,
    required this.motion,
    required this.reduceMotion,
  });
  final int index;
  final PageController controller;
  final OnboardingMotion motion;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final data = _pages[index];
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < 510;
      final artHeight = (constraints.maxHeight * .58).clamp(160.0, 360.0);
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: MediaQuery.withNoTextScaling(
                  child: RepaintBoundary(
                    child: SizedBox(
                      height: artHeight,
                      width: double.infinity,
                      child: FittedBox(
                        child: AnimatedBuilder(
                          animation:
                              Listenable.merge([motion.animation, controller]),
                          builder: (context, _) {
                            final offset = controller.hasClients &&
                                    controller.position.hasContentDimensions
                                ? (controller.page! - index).clamp(-1.0, 1.0)
                                : 0.0;
                            return OnboardingArt(
                              index: index,
                              phase:
                                  reduceMotion ? .12 : motion.animation.value,
                              pageOffset: reduceMotion ? 0 : offset,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 12 : 24),
              _ContentReveal(
                index: index,
                reduceMotion: reduceMotion,
                child: Column(children: [
                  Semantics(
                    header: true,
                    child: Text(data.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineLarge?.copyWith(
                            fontSize: compact ? 32 : 40,
                            height: 1.08,
                            letterSpacing: -1.6,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 390),
                    child: Text(data.body,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: compact ? 14 : 15,
                            height: 1.6,
                            color: theme.colorScheme.onSurfaceVariant)),
                  ),
                  SizedBox(height: compact ? 16 : 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      ExcludeSemantics(
                        child: Icon(data.icon,
                            size: 15, color: theme.colorScheme.primary),
                      ),
                      Text(data.detail,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              height: 1.5)),
                    ],
                  ),
                ]),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _ContentReveal extends StatelessWidget {
  const _ContentReveal({
    required this.index,
    required this.reduceMotion,
    required this.child,
  });
  final int index;
  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      child: child,
      builder: (context, ref, child) {
        final active =
            ref.watch(onboardingFlowProvider.select((s) => s.page == index));
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: active ? 1 : 0),
          duration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 700),
          curve: const Cubic(.22, 1, .36, 1),
          child: child,
          builder: (context, value, child) => Opacity(
            opacity: reduceMotion ? 1 : .35 + value * .65,
            child: Transform.translate(
              offset: Offset(0, reduceMotion ? 0 : (1 - value) * 20),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.page,
    required this.reduceMotion,
    required this.onBack,
    required this.onNext,
    required this.onSelect,
  });
  final int page;
  final bool reduceMotion;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLast = page == _pages.length - 1;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              SizedBox(
                width: 64,
                height: 48,
                child: page > 0
                    ? IconButton(
                        tooltip: 'Back',
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back_rounded, size: 21),
                        color: scheme.onSurfaceVariant)
                    : null,
              ),
              Expanded(
                child: Semantics(
                  label: 'Page ${page + 1} of ${_pages.length}',
                  liveRegion: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      return Semantics(
                        label: 'Go to page ${index + 1}',
                        selected: index == page,
                        button: true,
                        child: InkResponse(
                          onTap: () => onSelect(index),
                          radius: 24,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: AnimatedContainer(
                                duration: reduceMotion
                                    ? Duration.zero
                                    : const Duration(milliseconds: 380),
                                curve: Curves.easeOutCubic,
                                width: index == page ? 28 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: index == page
                                      ? scheme.primary
                                      : scheme.primary.withValues(alpha: .16),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 64),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.fromLTRB(24, 12, 12, 12),
                  minimumSize: const Size(48, 60),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: Row(children: [
                  Expanded(
                    child: Text(isLast ? 'Get started' : 'Continue',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  ExcludeSemantics(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: page.toDouble()),
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Transform.rotate(
                        angle: value * math.pi * 2,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                              color: scheme.onPrimary.withValues(alpha: .13),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(
                              isLast
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 20),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Text('A little less maths. A lot more life.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400)),
          ]),
        ),
      ),
    );
  }
}
