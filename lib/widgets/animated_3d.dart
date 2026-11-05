import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Lightweight perspective/lighting effect using Flutter's rendering engine.
/// No external animation package or GPU-heavy 3D scene is required.
class SplitwizeTiltCard extends StatefulWidget {
  const SplitwizeTiltCard({
    super.key,
    required this.child,
    this.onTap,
    this.radius = 22,
    this.depth = 12,
    this.duration = const Duration(milliseconds: 340),
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final double depth;
  final Duration duration;

  @override
  State<SplitwizeTiltCard> createState() => _SplitwizeTiltCardState();
}

class _SplitwizeTiltCardState extends State<SplitwizeTiltCard> {
  double _x = 0;
  double _y = 0;
  bool _pressed = false;

  void _setTilt(Offset local, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    setState(() {
      _x = ((local.dy / size.height) - .5).clamp(-.5, .5) * -.16;
      _y = ((local.dx / size.width) - .5).clamp(-.5, .5) * .16;
    });
  }

  void _reset() => setState(() {
    _x = 0;
    _y = 0;
    _pressed = false;
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth.isFinite ? constraints.maxWidth : 100,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 100);
      return MouseRegion(
        onHover: reduceMotion ? null : (event) => _setTilt(event.localPosition, size),
        onExit: (_) => _reset(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: reduceMotion ? null : (details) {
            _setTilt(details.localPosition, size);
            setState(() => _pressed = true);
          },
          onTapCancel: _reset,
          onTapUp: (_) => _reset(),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: reduceMotion ? Duration.zero : widget.duration,
            curve: Curves.easeOutCubic,
            transformAlignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .001)
              ..rotateX(reduceMotion ? 0 : _x)
              ..rotateY(reduceMotion ? 0 : _y)
              ..scale(_pressed ? .975 : 1.0),
            child: Stack(children: [
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(0, widget.depth * .35),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.radius),
                      boxShadow: [BoxShadow(
                        color: const Color(0xFF5746D9).withValues(alpha: .18),
                        blurRadius: widget.depth * 2,
                        offset: Offset(0, widget.depth * .5),
                      )],
                    ),
                  ),
                ),
              ),
              widget.child,
            ]),
          ),
        ),
      );
    });
  }
}

/// Animated dimensional brand emblem for headers and empty states.
class Splitwize3DBrand extends StatefulWidget {
  const Splitwize3DBrand({super.key, this.size = 64});
  final double size;

  @override
  State<Splitwize3DBrand> createState() => _Splitwize3DBrandState();
}

class _Splitwize3DBrandState extends State<Splitwize3DBrand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, child) {
        final t = reduceMotion ? .5 : _motion.value;
        return Transform.translate(
          offset: Offset(0, -3 * math.sin(t * math.pi)),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .001)
              ..rotateY((t - .5) * .28)
              ..rotateX((t - .5) * -.14),
            child: child,
          ),
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.size * .28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A43EF).withValues(alpha: .35),
              blurRadius: widget.size * .30,
              offset: Offset(0, widget.size * .15),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.size * .28),
          child: Image.asset(
            'assets/icon/app_icon.png',
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}
