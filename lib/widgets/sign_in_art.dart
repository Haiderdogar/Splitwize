import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// A welcoming pocket for shared moments, drawn entirely in Flutter.
///
/// One parent-owned phase drives the scene. At rest the same illustration can
/// be displayed without a ticker, including when reduced motion is requested.
class SignInArt extends StatelessWidget {
  const SignInArt({
    super.key,
    required this.phase,
    required this.busy,
  });

  final double phase;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final angle = phase * math.pi * 2;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 360,
      height: 320,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _WelcomeStagePainter(dark: dark)),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _OrbitLightPainter(
                phase: phase,
                busy: busy,
                dark: dark,
              ),
            ),
          ),
          _floating(
            left: 105,
            top: 46,
            angle: angle + .5,
            amplitude: 4,
            rotateZ: -.17,
            rotateY: -.17,
            child: const RepaintBoundary(child: _CircleCard()),
          ),
          _floating(
            left: 76,
            top: 125,
            angle: angle,
            amplitude: 5,
            rotateZ: -.10,
            rotateY: -.16,
            rotateX: .10,
            child: const RepaintBoundary(
              child: CustomPaint(
                size: Size(213, 151),
                painter: _WalletPainter(),
              ),
            ),
          ),
          _floating(
            left: 27,
            top: 94,
            angle: angle + 2.1,
            amplitude: 7,
            rotateZ: -.14,
            rotateY: .22,
            child: const _WelcomeCoin(
              size: 59,
              color: SplitwizePalette.coral,
              child: Icon(
                Icons.favorite_rounded,
                size: 26,
                color: SplitwizePalette.forest,
              ),
            ),
          ),
          _floating(
            left: 273,
            top: 60,
            angle: angle + 3.5,
            amplitude: 5,
            rotateZ: .20,
            rotateY: -.25,
            child: const _WelcomeCoin(
              size: 46,
              color: SplitwizePalette.lime,
              child: Icon(
                Icons.add_rounded,
                size: 26,
                color: SplitwizePalette.forest,
              ),
            ),
          ),
          _floating(
            left: 285,
            top: 183,
            angle: angle + 4.3,
            amplitude: 7,
            rotateZ: .15,
            rotateY: -.22,
            child: RepaintBoundary(child: _ReceiptToken(dark: dark)),
          ),
          _floating(
            left: 34,
            top: 235,
            angle: angle + 1.2,
            amplitude: 5,
            rotateZ: -.10,
            rotateY: .18,
            child: const _WelcomeCoin(
              size: 44,
              color: SplitwizePalette.lime,
              child: Icon(
                Icons.lock_rounded,
                size: 20,
                color: SplitwizePalette.forest,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _floating({
    required double left,
    required double top,
    required double angle,
    required double amplitude,
    required Widget child,
    double rotateZ = 0,
    double rotateY = 0,
    double rotateX = 0,
  }) =>
      Positioned(
        left: left,
        top: top,
        child: Transform.translate(
          offset: Offset(
            math.cos(angle) * amplitude * .4,
            math.sin(angle) * amplitude,
          ),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0015)
              ..rotateX(rotateX + math.sin(angle) * .025)
              ..rotateY(rotateY + math.cos(angle) * .06)
              ..rotateZ(rotateZ + math.sin(angle) * .02),
            child: child,
          ),
        ),
      );
}

class _CircleCard extends StatelessWidget {
  const _CircleCard();

  @override
  Widget build(BuildContext context) => _BeveledTile(
        width: 157,
        height: 123,
        radius: 20,
        color: SplitwizePalette.lime,
        edge: const Color(0xFFA6BC75),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 21,
                    height: 5,
                    decoration: BoxDecoration(
                      color: SplitwizePalette.forest.withValues(alpha: .7),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.auto_awesome_rounded,
                      size: 15,
                      color: SplitwizePalette.forest.withValues(alpha: .6)),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  _FriendDisc(color: SplitwizePalette.coral),
                  SizedBox(width: 6),
                  _FriendDisc(color: Color(0xFFECF2D8)),
                  SizedBox(width: 6),
                  _FriendDisc(color: Color(0xFF9CBD79)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: 90,
                height: 5,
                decoration: BoxDecoration(
                  color: SplitwizePalette.forest.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ),
        ),
      );
}

class _FriendDisc extends StatelessWidget {
  const _FriendDisc({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white.withValues(alpha: .5)),
          boxShadow: [
            BoxShadow(
              color: SplitwizePalette.forest.withValues(alpha: .1),
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.person_rounded,
            size: 22, color: SplitwizePalette.forest),
      );
}

class _ReceiptToken extends StatelessWidget {
  const _ReceiptToken({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _BeveledTile(
      width: 47,
      height: 61,
      radius: 11,
      color: scheme.surfaceContainerLowest,
      edge: dark ? const Color(0xFF34473D) : const Color(0xFFD5DED1),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.receipt_long_rounded, size: 18, color: scheme.primary),
            const SizedBox(height: 7),
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .24),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 5),
            Container(
              margin: const EdgeInsets.only(right: 8),
              height: 3,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeCoin extends StatelessWidget {
  const _WelcomeCoin({
    required this.size,
    required this.color,
    required this.child,
  });
  final double size;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => _BeveledTile(
        width: size,
        height: size,
        radius: size / 2,
        depth: size * .10,
        color: color,
        edge: Color.alphaBlend(Colors.black.withValues(alpha: .2), color),
        child: Container(
          margin: EdgeInsets.all(size * .075),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: .45)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: .23),
                color.withValues(alpha: 0),
              ],
            ),
          ),
          child: Center(child: child),
        ),
      );
}

class _BeveledTile extends StatelessWidget {
  const _BeveledTile({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
    required this.edge,
    required this.child,
    this.depth = 6,
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
                      color: SplitwizePalette.forestDark.withValues(alpha: .13),
                      blurRadius: 18,
                      offset: const Offset(1, 13),
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
                border: Border.all(
                    color: Colors.white.withValues(alpha: .35), width: 1.2),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(
                        Colors.white.withValues(alpha: .15), color),
                    color,
                    Color.alphaBlend(
                        Colors.black.withValues(alpha: .04), color),
                  ],
                ),
              ),
              child: child,
            ),
          ],
        ),
      );
}

class _WalletPainter extends CustomPainter {
  const _WalletPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 204, 138),
      const Radius.circular(27),
    );
    final bodyPath = Path()..addRRect(body);
    canvas.drawShadow(bodyPath.shift(const Offset(3, 11)),
        SplitwizePalette.forestDark.withValues(alpha: .28), 19, false);
    canvas.drawRRect(body.shift(const Offset(5, 9)),
        Paint()..color = const Color(0xFF092C26));
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A6455), SplitwizePalette.forest],
        ).createShader(body.outerRect),
    );
    canvas.drawRRect(
      body.deflate(.7),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: .23),
    );
    final pocket = Path()
      ..moveTo(0, 40)
      ..quadraticBezierTo(98, 57, 204, 40)
      ..lineTo(204, 110)
      ..quadraticBezierTo(204, 138, 177, 138)
      ..lineTo(27, 138)
      ..quadraticBezierTo(0, 138, 0, 111)
      ..close();
    canvas.drawPath(
      pocket,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF285B4E), Color(0xFF153F37), Color(0xFF103A30)],
        ).createShader(body.outerRect),
    );
    final pocketLip = Path()
      ..moveTo(2, 41)
      ..quadraticBezierTo(98, 58, 202, 41);
    canvas.drawPath(
      pocketLip,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: .17),
    );

    // Two linked rings give the pocket a tactile shared-finances emblem.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = SplitwizePalette.forestDark.withValues(alpha: .45);
    canvas.drawCircle(const Offset(82, 89), 13, ringPaint);
    canvas.drawCircle(const Offset(104, 89), 13, ringPaint);
    canvas.drawCircle(
        const Offset(82, 86), 13, ringPaint..color = SplitwizePalette.lime);
    canvas.drawCircle(const Offset(104, 86), 13, ringPaint);

    final strap = RRect.fromRectAndRadius(
      const Rect.fromLTWH(164, 65, 45, 38),
      const Radius.circular(13),
    );
    canvas.drawRRect(strap.shift(const Offset(0, 4)),
        Paint()..color = SplitwizePalette.forestDark);
    canvas.drawRRect(
      strap,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF47725E), Color(0xFF2B594A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(strap.outerRect),
    );
    canvas.drawRRect(
      strap,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: .15),
    );
    canvas.drawCircle(const Offset(184, 85), 5.5,
        Paint()..color = SplitwizePalette.forestDark);
    canvas.drawCircle(
      const Offset(184, 83),
      5.5,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFF3BEA0), SplitwizePalette.coral],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(const Rect.fromLTWH(178, 77, 12, 12)),
    );
    final seam = Path()
      ..moveTo(15, 67)
      ..lineTo(15, 111)
      ..quadraticBezierTo(15, 124, 29, 124)
      ..lineTo(174, 124);
    final seamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = SplitwizePalette.lime.withValues(alpha: .23);
    for (final metric in seam.computeMetrics()) {
      for (double distance = 0; distance < metric.length; distance += 7) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 3, metric.length)),
          seamPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WalletPainter oldDelegate) => false;
}

class _WelcomeStagePainter extends CustomPainter {
  const _WelcomeStagePainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    const center = Offset(180, 162);
    final halo = Rect.fromCircle(center: center, radius: 150);
    canvas.drawCircle(
      center,
      150,
      Paint()
        ..shader = RadialGradient(
          colors: [
            SplitwizePalette.lime.withValues(alpha: dark ? .08 : .22),
            SplitwizePalette.lime.withValues(alpha: 0),
          ],
        ).createShader(halo),
    );
    const orbit = Rect.fromLTWH(20, 52, 320, 221);
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = (dark ? SplitwizePalette.lime : SplitwizePalette.forest)
          .withValues(alpha: .10);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.37);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(orbit, .15, 2.4, false, orbitPaint);
    canvas.drawArc(orbit, 3.0, 2.4, false, orbitPaint);
    canvas.drawArc(
      orbit.inflate(10),
      2.3,
      1.35,
      false,
      orbitPaint
        ..color = SplitwizePalette.coral.withValues(alpha: dark ? .25 : .4),
    );
    canvas.restore();
    const shadow = Rect.fromLTWH(93, 286, 182, 20);
    canvas.drawOval(
      shadow,
      Paint()
        ..shader = RadialGradient(
          colors: [
            SplitwizePalette.forestDark.withValues(alpha: dark ? .22 : .11),
            SplitwizePalette.forestDark.withValues(alpha: 0),
          ],
        ).createShader(shadow),
    );
    final sparklePaint = Paint()
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = (dark ? SplitwizePalette.lime : SplitwizePalette.forest)
          .withValues(alpha: .45);
    for (final (center, radius) in [
      (const Offset(66, 46), 4.0),
      (const Offset(308, 139), 5.0),
      (const Offset(251, 286), 3.0),
    ]) {
      canvas.drawLine(
          center - Offset(radius, 0), center + Offset(radius, 0), sparklePaint);
      canvas.drawLine(
          center - Offset(0, radius), center + Offset(0, radius), sparklePaint);
    }
    canvas.drawCircle(const Offset(26, 191), 2.5,
        Paint()..color = SplitwizePalette.coral.withValues(alpha: .65));
    canvas.drawCircle(const Offset(227, 25), 2,
        Paint()..color = SplitwizePalette.lime.withValues(alpha: .7));
  }

  @override
  bool shouldRepaint(_WelcomeStagePainter oldDelegate) =>
      dark != oldDelegate.dark;
}

class _OrbitLightPainter extends CustomPainter {
  const _OrbitLightPainter({
    required this.phase,
    required this.busy,
    required this.dark,
  });
  final double phase;
  final bool busy;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final angle = phase * math.pi * 2;
    final pulse = (math.sin(angle) + 1) * .5;
    const center = Offset(180, 162);
    final glowRect = Rect.fromCircle(center: center, radius: 112);
    if (busy) {
      canvas.drawCircle(
        center,
        112,
        Paint()
          ..shader = RadialGradient(
            colors: [
              SplitwizePalette.lime.withValues(alpha: .06 + pulse * .05),
              SplitwizePalette.lime.withValues(alpha: 0),
            ],
          ).createShader(glowRect),
      );
    }
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.37);
    for (var i = 0; i < 2; i++) {
      final theta = angle + i * math.pi;
      final point = Offset(math.cos(theta) * 160, math.sin(theta) * 110.5);
      canvas.drawCircle(
        point,
        busy ? 3.0 : 2.3,
        Paint()
          ..color = (i == 0
                  ? SplitwizePalette.coral
                  : dark
                      ? SplitwizePalette.lime
                      : SplitwizePalette.forest)
              .withValues(alpha: busy ? .7 : .4),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbitLightPainter oldDelegate) =>
      phase != oldDelegate.phase ||
      busy != oldDelegate.busy ||
      dark != oldDelegate.dark;
}
