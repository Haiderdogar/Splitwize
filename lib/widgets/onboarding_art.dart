import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Native, resolution-independent artwork for the three onboarding chapters.
///
/// The parent owns the timeline so offscreen illustrations share one clock and
/// reduced-motion mode can render exactly the same scenes at rest.
class OnboardingArt extends StatelessWidget {
  const OnboardingArt({
    super.key,
    required this.index,
    required this.phase,
    required this.pageOffset,
  });

  final int index;
  final double phase;
  final double pageOffset;

  @override
  Widget build(BuildContext context) {
    final angle = phase * math.pi * 2;
    return SizedBox(
      width: 360,
      height: 340,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _StagePainter(
                  dark: Theme.of(context).brightness == Brightness.dark,
                  index: index,
                ),
              ),
            ),
          ),
          ...switch (index) {
            0 => _splitScene(context, angle),
            1 => _settleScene(context, angle),
            _ => _syncScene(context, angle),
          },
        ],
      ),
    );
  }

  List<Widget> _splitScene(BuildContext context, double angle) => [
        _layer(
          left: 264,
          top: 63,
          angle: angle + 1.4,
          depth: .55,
          rotateZ: .15,
          child: const _Coin(
            size: 48,
            color: SplitwizePalette.coral,
            child: Icon(Icons.restaurant_rounded,
                size: 21, color: SplitwizePalette.forestDark),
          ),
        ),
        _layer(
          left: 89,
          top: 52,
          angle: angle,
          depth: 1,
          rotateY: -.18,
          rotateX: .12,
          rotateZ: -.10,
          child: const RepaintBoundary(child: _Receipt()),
        ),
        _layer(
          left: 23,
          top: 105,
          angle: angle + 2.1,
          depth: 1.4,
          rotateY: .24,
          rotateZ: -.13,
          child: const _Coin(
            size: 67,
            color: SplitwizePalette.lime,
            child: _ArtLabel('A', size: 26, weight: FontWeight.w800),
          ),
        ),
        _layer(
          left: 269,
          top: 196,
          angle: angle + 4.2,
          depth: 1.5,
          rotateY: -.28,
          rotateZ: .10,
          child: const _Coin(
            size: 60,
            color: SplitwizePalette.coral,
            child: _ArtLabel('S', size: 24, weight: FontWeight.w800),
          ),
        ),
        _layer(
          left: 47,
          top: 263,
          angle: angle + 3,
          depth: 1.9,
          rotateZ: .05,
          child: _SmallCard(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusDot(color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                _ArtLabel('Fair shares. Zero fuss.',
                    size: 11, color: Theme.of(context).colorScheme.onSurface),
              ],
            ),
          ),
        ),
      ];

  List<Widget> _settleScene(BuildContext context, double angle) => [
        _layer(
          left: 21,
          top: 70,
          angle: angle + 1.1,
          depth: .65,
          rotateZ: -.13,
          rotateY: .12,
          child: const RepaintBoundary(
            child:
                _FriendCard(initial: 'A', label: 'Your share', amount: '20.00'),
          ),
        ),
        _layer(
          left: 93,
          top: 79,
          angle: angle,
          depth: 1.1,
          rotateY: -.16,
          rotateX: .12,
          rotateZ: -.10,
          child: const _Coin(
            size: 178,
            color: SplitwizePalette.lime,
            child: CustomPaint(
              size: Size(86, 86),
              painter: _CheckPainter(),
            ),
          ),
        ),
        _layer(
          left: 239,
          top: 39,
          angle: angle + 3,
          depth: .9,
          rotateY: .2,
          child: const _Coin(
            size: 47,
            color: SplitwizePalette.coral,
            child: Icon(Icons.favorite_rounded,
                size: 21, color: SplitwizePalette.forestDark),
          ),
        ),
        _layer(
          left: 226,
          top: 216,
          angle: angle + 2.6,
          depth: 1.8,
          rotateZ: .09,
          rotateY: -.13,
          child: const RepaintBoundary(
            child: _FriendCard(
              initial: 'S',
              label: 'All settled',
              amount: '20.00',
              settled: true,
            ),
          ),
        ),
        _layer(
          left: 20,
          top: 288,
          angle: angle + 4,
          depth: 1.6,
          rotateZ: -.04,
          child: _SmallCard(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 17, color: SplitwizePalette.positive),
                const SizedBox(width: 7),
                _ArtLabel('Good friends. Clear balances.',
                    size: 11, color: Theme.of(context).colorScheme.onSurface),
              ],
            ),
          ),
        ),
      ];

  List<Widget> _syncScene(BuildContext context, double angle) => [
        _layer(
          left: 91,
          top: 55,
          angle: angle,
          depth: .85,
          rotateX: .08,
          rotateY: .22,
          rotateZ: -.10,
          child: const RepaintBoundary(child: _Device()),
        ),
        _layer(
          left: 177,
          top: 39,
          angle: angle + 2,
          depth: 1.5,
          rotateY: -.16,
          rotateZ: .06,
          child: const RepaintBoundary(
            child: CustomPaint(
              size: Size(142, 105),
              painter: _CloudPainter(),
              child: SizedBox(
                width: 142,
                height: 105,
                child: Padding(
                  padding: EdgeInsets.only(top: 20, left: 14),
                  child: Center(
                    child: Icon(Icons.done_all_rounded,
                        size: 35, color: SplitwizePalette.forestDark),
                  ),
                ),
              ),
            ),
          ),
        ),
        _layer(
          left: 25,
          top: 261,
          angle: angle + 3.1,
          depth: 1.8,
          rotateZ: -.07,
          child: _SmallCard(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.offline_pin_rounded,
                    size: 19, color: SplitwizePalette.positive),
                const SizedBox(width: 8),
                _ArtLabel('Saved on your phone',
                    size: 11, color: Theme.of(context).colorScheme.onSurface),
              ],
            ),
          ),
        ),
        _layer(
          left: 238,
          top: 253,
          angle: angle + 4.5,
          depth: 1.4,
          rotateY: -.2,
          rotateZ: .14,
          child: const _Coin(
            size: 56,
            color: SplitwizePalette.coral,
            child: Icon(Icons.sync_rounded,
                size: 28, color: SplitwizePalette.forestDark),
          ),
        ),
        _layer(
          left: 34,
          top: 78,
          angle: angle + 1.5,
          depth: .7,
          child: const _Coin(
            size: 35,
            color: SplitwizePalette.lime,
            child: Icon(Icons.wifi_rounded,
                size: 18, color: SplitwizePalette.forestDark),
          ),
        ),
      ];

  Widget _layer({
    required double left,
    required double top,
    required double angle,
    required double depth,
    required Widget child,
    double rotateX = 0,
    double rotateY = 0,
    double rotateZ = 0,
  }) {
    final offset = pageOffset.clamp(-1.0, 1.0);
    return Positioned(
      left: left,
      top: top,
      child: Transform.translate(
        offset: Offset(
          math.cos(angle) * 2.8 * depth - offset * 26 * depth,
          math.sin(angle) * 5 * depth,
        ),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .0016)
            ..rotateX(rotateX + math.sin(angle) * .025)
            ..rotateY(rotateY + math.cos(angle) * .055 + offset * .18)
            ..rotateZ(rotateZ + math.sin(angle) * .018),
          child: child,
        ),
      ),
    );
  }
}

class _Receipt extends StatelessWidget {
  const _Receipt();

  @override
  Widget build(BuildContext context) {
    return _ExtrudedCard(
      width: 190,
      height: 222,
      color: SplitwizePalette.forest,
      edge: SplitwizePalette.forestDark,
      radius: 25,
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long_rounded,
                    size: 19, color: SplitwizePalette.lime),
                SizedBox(width: 8),
                Expanded(
                  child: _ArtLabel('Dinner with friends',
                      size: 10, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _ArtLabel('60.00',
                size: 37,
                color: Colors.white,
                weight: FontWeight.w800,
                alignment: Alignment.centerLeft),
            const SizedBox(height: 3),
            _ArtLabel('One bill. Three happy people.',
                size: 8,
                color: Colors.white.withValues(alpha: .65),
                alignment: Alignment.centerLeft),
            const SizedBox(height: 16),
            CustomPaint(
              size: const Size(double.infinity, 1),
              painter: _DashedLinePainter(
                color: Colors.white.withValues(alpha: .22),
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                _MiniShare(initial: 'A', color: SplitwizePalette.lime),
                SizedBox(width: 8),
                _MiniShare(initial: 'S', color: SplitwizePalette.coral),
                SizedBox(width: 8),
                _MiniShare(initial: 'You', color: Color(0xFFDEE9E2)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniShare extends StatelessWidget {
  const _MiniShare({required this.initial, required this.color});
  final String initial;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: _ArtLabel(initial, size: initial.length > 1 ? 8 : 11),
            ),
            const SizedBox(height: 5),
            const _ArtLabel('20.00', size: 11, color: Colors.white),
          ],
        ),
      );
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({
    required this.initial,
    required this.label,
    required this.amount,
    this.settled = false,
  });
  final String initial;
  final String label;
  final String amount;
  final bool settled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _ExtrudedCard(
      width: 111,
      height: 102,
      color: scheme.surfaceContainerLowest,
      edge: Color.alphaBlend(
          SplitwizePalette.forest.withValues(alpha: .13), scheme.surface),
      radius: 19,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 25,
                  height: 25,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: settled
                        ? SplitwizePalette.coral
                        : SplitwizePalette.lime,
                  ),
                  child: _ArtLabel(initial, size: 11),
                ),
                const Spacer(),
                if (settled)
                  const Icon(Icons.check_circle_rounded,
                      color: SplitwizePalette.positive, size: 17),
              ],
            ),
            const SizedBox(height: 8),
            _ArtLabel(label, size: 9, color: scheme.onSurfaceVariant),
            const SizedBox(height: 3),
            _ArtLabel(amount,
                size: 21, weight: FontWeight.w800, color: scheme.onSurface),
          ],
        ),
      ),
    );
  }
}

class _Device extends StatelessWidget {
  const _Device();

  @override
  Widget build(BuildContext context) {
    return _ExtrudedCard(
      width: 151,
      height: 230,
      color: SplitwizePalette.forest,
      edge: SplitwizePalette.forestDark,
      radius: 29,
      depth: 9,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0F3E7),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: SplitwizePalette.forestDark,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 24),
              const _Coin(
                size: 58,
                color: SplitwizePalette.lime,
                child: Icon(Icons.shield_rounded,
                    size: 28, color: SplitwizePalette.forest),
              ),
              const SizedBox(height: 14),
              const _ArtLabel('You\'re covered.',
                  size: 14, weight: FontWeight.w800),
              const SizedBox(height: 6),
              const _ArtLabel('Online or off.', size: 10),
              const SizedBox(height: 12),
              for (var i = 0; i < 2; i++)
                Padding(
                  padding:
                      const EdgeInsets.only(left: 17, right: 17, bottom: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 17,
                        height: 17,
                        decoration: BoxDecoration(
                          color: i == 0
                              ? SplitwizePalette.coral.withValues(alpha: .5)
                              : SplitwizePalette.lime,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color:
                                SplitwizePalette.forest.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.check_rounded,
                          size: 12, color: SplitwizePalette.forest),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A beveled face and a visible lower edge form a small physical object.
class _ExtrudedCard extends StatelessWidget {
  const _ExtrudedCard({
    required this.width,
    required this.height,
    required this.color,
    required this.edge,
    required this.radius,
    required this.child,
    this.depth = 7,
  });

  final double width;
  final double height;
  final double radius;
  final double depth;
  final Color color;
  final Color edge;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width + depth,
        height: height + depth,
        child: Stack(
          children: [
            Positioned(
              left: depth * .55,
              top: depth,
              width: width,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: edge,
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: [
                    BoxShadow(
                      color: SplitwizePalette.forestDark.withValues(alpha: .15),
                      blurRadius: 22,
                      offset: const Offset(2, 18),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(
                        Colors.white.withValues(alpha: .12), color),
                    color,
                    Color.alphaBlend(
                        Colors.black.withValues(alpha: .06), color),
                  ],
                ),
                border: Border.all(
                    color: Colors.white.withValues(alpha: .21), width: 1.2),
              ),
              child: child,
            ),
          ],
        ),
      );
}

class _Coin extends StatelessWidget {
  const _Coin({required this.size, required this.color, required this.child});
  final double size;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final depth = size * .085;
    return _ExtrudedCard(
      width: size,
      height: size,
      color: color,
      edge: Color.alphaBlend(Colors.black.withValues(alpha: .20), color),
      radius: size / 2,
      depth: depth,
      child: Container(
        margin: EdgeInsets.all(size * .065),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: .30),
              color.withValues(alpha: .01),
              Colors.black.withValues(alpha: .035),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: .28)),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _SmallCard extends StatelessWidget {
  const _SmallCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: scheme.onSurface.withValues(alpha: .045), width: 1),
        boxShadow: [
          BoxShadow(
            color: SplitwizePalette.forestDark.withValues(alpha: .09),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: scheme.outlineVariant.withValues(alpha: .5),
            offset: const Offset(1, 3),
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: scheme.onSurface),
        child: child,
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _ArtLabel extends StatelessWidget {
  const _ArtLabel(
    this.text, {
    this.size = 12,
    this.weight = FontWeight.w600,
    this.color,
    this.alignment = Alignment.center,
  });
  final String text;
  final double size;
  final FontWeight weight;
  final Color? color;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(
            fontSize: size,
            height: 1.1,
            fontWeight: weight,
            letterSpacing: -.2,
            color: color ?? SplitwizePalette.forestDark,
          ),
        ),
      );
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .18, size.height * .51)
      ..lineTo(size.width * .42, size.height * .73)
      ..lineTo(size.width * .83, size.height * .28);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.translate(0, 5);
    canvas.drawPath(path,
        paint..color = SplitwizePalette.forestDark.withValues(alpha: .23));
    canvas.restore();
    canvas.drawPath(path, paint..color = SplitwizePalette.forest);
    canvas.save();
    canvas.translate(-1, -1);
    canvas.drawPath(
      path,
      paint
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: .13),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) => false;
}

class _CloudPainter extends CustomPainter {
  const _CloudPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(32, 88)
      ..cubicTo(4, 88, 2, 50, 28, 46)
      ..cubicTo(22, 5, 83, -1, 91, 34)
      ..cubicTo(121, 19, 148, 52, 129, 74)
      ..cubicTo(125, 84, 115, 88, 105, 88)
      ..close();
    canvas.drawShadow(path.shift(const Offset(2, 9)),
        SplitwizePalette.forestDark.withValues(alpha: .20), 14, false);
    canvas.drawPath(path.shift(const Offset(3, 9)),
        Paint()..color = const Color(0xFFA4BB71));
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F8D6), SplitwizePalette.lime, Color(0xFFC8DE8A)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: .55),
    );
  }

  @override
  bool shouldRepaint(_CloudPainter oldDelegate) => false;
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(
          Offset(x, 0), Offset(math.min(x + 3, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      color != oldDelegate.color;
}

class _StagePainter extends CustomPainter {
  const _StagePainter({required this.dark, required this.index});
  final bool dark;
  final int index;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .48);
    final halo = Rect.fromCircle(center: center, radius: 148);
    final accent = index == 1 ? SplitwizePalette.coral : SplitwizePalette.lime;
    canvas.drawCircle(
      center,
      148,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: dark ? .08 : .23),
            accent.withValues(alpha: 0),
          ],
        ).createShader(halo),
    );
    final orbit = Rect.fromCenter(
      center: center + const Offset(0, 11),
      width: 318,
      height: 216,
    );
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = (dark ? SplitwizePalette.lime : SplitwizePalette.forest)
          .withValues(alpha: dark ? .13 : .09);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.34);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawOval(orbit, orbitPaint);
    canvas.drawArc(orbit.inflate(12), math.pi * .90, math.pi * .47, false,
        orbitPaint..color = accent.withValues(alpha: dark ? .24 : .45));
    canvas.restore();
    final shadow = Rect.fromCenter(
      center: const Offset(182, 304),
      width: index == 1 ? 176 : 150,
      height: 25,
    );
    canvas.drawOval(
      shadow,
      Paint()
        ..shader = RadialGradient(
          colors: [
            SplitwizePalette.forestDark.withValues(alpha: dark ? .30 : .12),
            SplitwizePalette.forestDark.withValues(alpha: 0),
          ],
        ).createShader(shadow),
    );
    _sparkle(canvas, const Offset(56, 43), 6,
        dark ? SplitwizePalette.lime : SplitwizePalette.forest, .55);
    _sparkle(canvas, const Offset(304, 154), 5, SplitwizePalette.coral, .85);
    _sparkle(canvas, const Offset(84, 242), 3.5,
        dark ? SplitwizePalette.lime : SplitwizePalette.forest, .35);
    canvas.drawCircle(const Offset(299, 295), 3,
        Paint()..color = SplitwizePalette.coral.withValues(alpha: .65));
    canvas.drawCircle(const Offset(26, 178), 2,
        Paint()..color = SplitwizePalette.forest.withValues(alpha: .30));
  }

  void _sparkle(
      Canvas canvas, Offset center, double radius, Color color, double alpha) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(center.dx + radius * .14, center.dy - radius * .14,
          center.dx + radius, center.dy)
      ..quadraticBezierTo(center.dx + radius * .14, center.dy + radius * .14,
          center.dx, center.dy + radius)
      ..quadraticBezierTo(center.dx - radius * .14, center.dy + radius * .14,
          center.dx - radius, center.dy)
      ..quadraticBezierTo(center.dx - radius * .14, center.dy - radius * .14,
          center.dx, center.dy - radius)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: alpha));
  }

  @override
  bool shouldRepaint(_StagePainter oldDelegate) =>
      dark != oldDelegate.dark || index != oldDelegate.index;
}
