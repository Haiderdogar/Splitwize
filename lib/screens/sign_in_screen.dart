import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/form_providers.dart';
import '../providers/sign_in_motion_provider.dart';
import '../theme.dart';
import '../widgets/sign_in_art.dart';
import '../widgets/studio_ui.dart';

/// A welcoming, native 3D introduction to the existing Google sign-in flow.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -.55),
            radius: 1.1,
            colors: [
              Color.alphaBlend(
                SplitwizePalette.lime.withValues(
                    alpha: scheme.brightness == Brightness.dark ? .07 : .13),
                scheme.surface,
              ),
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            const _BrandHeader(),
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth >= 840;
                final compact = constraints.maxHeight < 650;
                final artHeight = wide
                    ? 360.0
                    : (constraints.maxHeight * .44).clamp(170.0, 300.0);
                final art = _Reveal(
                  reduceMotion: reduceMotion,
                  start: 0,
                  child: SizedBox(
                    height: artHeight,
                    width: double.infinity,
                    child: const _AnimatedSignInArt(),
                  ),
                );
                final content = _SignInContent(
                    compact: compact, wide: wide, reduceMotion: reduceMotion);
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      wide ? 40 : 24, 8, wide ? 40 : 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        minHeight: math.max(0, constraints.maxHeight - 32)),
                    child: Center(
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: wide ? 1020 : 440),
                        child: wide
                            ? Row(children: [
                                Expanded(child: art),
                                const SizedBox(width: 56),
                                Expanded(child: content),
                              ])
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  art,
                                  SizedBox(height: compact ? 12 : 24),
                                  content,
                                ],
                              ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ]),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
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
          ]),
        ),
      ),
    );
  }
}

class _AnimatedSignInArt extends StatelessWidget {
  const _AnimatedSignInArt();

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    return Consumer(builder: (context, ref, _) {
      final busy = ref.watch(signInProvider);
      final motion = ref.watch(signInMotionProvider);
      motion.setEnabled(!reduceMotion && tickerEnabled);
      return ExcludeSemantics(
        child: MediaQuery.withNoTextScaling(
          child: RepaintBoundary(
            child: FittedBox(
              child: AnimatedBuilder(
                animation: motion.animation,
                builder: (context, _) => SignInArt(
                  phase: reduceMotion ? .12 : motion.animation.value,
                  busy: busy,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _SignInContent extends StatelessWidget {
  const _SignInContent({
    required this.compact,
    required this.wide,
    required this.reduceMotion,
  });

  final bool compact;
  final bool wide;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align = wide ? TextAlign.left : TextAlign.center;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Reveal(
          reduceMotion: reduceMotion,
          start: .12,
          child: Semantics(
            header: true,
            child: Text('Share the moments.\nNot the maths.',
                textAlign: align,
                style: theme.textTheme.headlineLarge?.copyWith(
                    fontSize: compact ? 32 : 37,
                    height: 1.12,
                    letterSpacing: -1.4,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 14),
        _Reveal(
          reduceMotion: reduceMotion,
          start: .20,
          child: Text(
            'Split bills, keep balances clear, and make more room for the good stuff.',
            textAlign: align,
            style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                height: 1.6,
                color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        SizedBox(height: compact ? 20 : 28),
        _Reveal(
          reduceMotion: reduceMotion,
          start: .28,
          child: Wrap(
            alignment: wide ? WrapAlignment.start : WrapAlignment.center,
            runSpacing: 12,
            spacing: 18,
            children: const [
              _Feature(icon: Icons.call_split_rounded, label: 'Easy splits'),
              _Feature(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Clear balances'),
              _Feature(icon: Icons.cloud_done_outlined, label: 'Offline ready'),
            ],
          ),
        ),
        SizedBox(height: compact ? 28 : 36),
        _Reveal(
          reduceMotion: reduceMotion,
          start: .36,
          child: _GoogleSignInButton(reduceMotion: reduceMotion),
        ),
        const SizedBox(height: 16),
        _Reveal(
          reduceMotion: reduceMotion,
          start: .42,
          child: Text(
            'An account is created automatically on first sign-in.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
                height: 1.5, color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ExcludeSemantics(child: Icon(icon, size: 15, color: scheme.primary)),
      const SizedBox(width: 5),
      Flexible(
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600)),
      ),
    ]);
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.reduceMotion});
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Consumer(builder: (context, ref, _) {
      final busy = ref.watch(signInProvider);
      return Semantics(
        liveRegion: true,
        child: FilledButton(
          onPressed: busy
              ? null
              : () async {
                  final error =
                      await ref.read(signInProvider.notifier).signIn();
                  if (error != null && context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(error)));
                  }
                },
          style: FilledButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            disabledBackgroundColor: scheme.primary.withValues(alpha: .72),
            disabledForegroundColor: scheme.onPrimary,
            minimumSize: const Size(48, 62),
            padding: const EdgeInsets.all(12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Row(children: [
            ExcludeSemantics(
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11)),
                child: AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  child: busy
                      ? SizedBox(
                          key: const ValueKey('busy'),
                          width: 18,
                          height: 18,
                          child: reduceMotion
                              ? const Icon(Icons.hourglass_top_rounded,
                                  size: 18, color: SplitwizePalette.forest)
                              : const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: SplitwizePalette.forest),
                        )
                      : const CustomPaint(
                          key: ValueKey('google'),
                          size: Size(20, 20),
                          painter: _GoogleMarkPainter(),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(busy ? 'Signing you in...' : 'Sign in with Google',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, height: 1.3)),
            ),
            const SizedBox(width: 12),
            ExcludeSemantics(
              child: Icon(
                  busy
                      ? Icons.lock_outline_rounded
                      : Icons.arrow_forward_rounded,
                  size: 20),
            ),
          ]),
        ),
      );
    });
  }
}

/// Staggered reveals animate only transforms and opacity around static children.
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.reduceMotion,
    required this.start,
    required this.child,
  });
  final bool reduceMotion;
  final double start;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 1100),
      child: child,
      builder: (context, value, child) {
        final progress = reduceMotion
            ? 1.0
            : Interval(start, 1, curve: const Cubic(.22, 1, .36, 1))
                .transform(value);
        return IgnorePointer(
          ignoring: progress == 0,
          child: ExcludeFocus(
            excluding: progress == 0,
            child: Opacity(
              opacity: progress,
              child: Transform.translate(
                offset: Offset(0, (1 - progress) * 22),
                child:
                    Transform.scale(scale: .97 + progress * .03, child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(size.width * .09, size.height * .09,
        size.width * .82, size.height * .82);
    final stroke = size.width * .19;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, math.pi * .25, math.pi * .53, false,
        paint..color = const Color(0xFF34A853));
    canvas.drawArc(rect, math.pi * .78, math.pi * .44, false,
        paint..color = const Color(0xFFFBBC05));
    canvas.drawArc(rect, math.pi * 1.22, math.pi * .53, false,
        paint..color = const Color(0xFFEA4335));
    canvas.drawArc(
        rect, 0, math.pi * .26, false, paint..color = const Color(0xFF4285F4));
    final bar = Path()
      ..moveTo(size.width * .51, size.height * .50)
      ..lineTo(size.width * .91, size.height * .50)
      ..lineTo(size.width * .91, size.height * .62);
    canvas.drawPath(bar, paint..color = const Color(0xFF4285F4));
  }

  @override
  bool shouldRepaint(_GoogleMarkPainter oldDelegate) => false;
}
