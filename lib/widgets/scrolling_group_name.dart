import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Reveals an overflowing group name with a pause at each end.
/// Short names stay still, and reduced-motion preferences disable autoplay.
class ScrollingGroupName extends StatefulWidget {
  const ScrollingGroupName({super.key, required this.name, this.style});

  final String name;
  final TextStyle? style;

  @override
  State<ScrollingGroupName> createState() => _ScrollingGroupNameState();
}

class _ScrollingGroupNameState extends State<ScrollingGroupName> {
  final _scroll = ScrollController();
  Timer? _pause;
  int _run = 0;
  double? _width;
  TextStyle? _style;
  TextScaler? _textScaler;
  TextDirection? _direction;
  bool? _disableAnimations;
  bool _nameChanged = true;

  @override
  void didUpdateWidget(ScrollingGroupName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name) _nameChanged = true;
  }

  void _restartAfterLayout(bool disableAnimations) {
    final run = ++_run;
    _pause?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || run != _run || !_scroll.hasClients) return;
      _scroll.jumpTo(0);
      if (!disableAnimations && _scroll.position.maxScrollExtent > 0) {
        _scheduleScroll(run, toEnd: true);
      }
    });
  }

  void _scheduleScroll(int run, {required bool toEnd}) {
    _pause = Timer(const Duration(seconds: 1), () => _move(run, toEnd: toEnd));
  }

  Future<void> _move(int run, {required bool toEnd}) async {
    if (!mounted || run != _run || !_scroll.hasClients) return;
    final extent = _scroll.position.maxScrollExtent;
    if (extent <= 0) return;
    final target = toEnd ? extent : 0.0;
    final distance = (target - _scroll.offset).abs();
    await _scroll.animateTo(
      target,
      duration:
          Duration(milliseconds: math.max(250, (distance / 30 * 1000).round())),
      curve: Curves.linear,
    );
    if (mounted && run == _run) _scheduleScroll(run, toEnd: !toEnd);
  }

  @override
  void dispose() {
    _pause?.cancel();
    _run++;
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? Theme.of(context).textTheme.titleMedium;
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return LayoutBuilder(builder: (context, constraints) {
      if (_nameChanged ||
          _width != constraints.maxWidth ||
          _style != style ||
          _textScaler != textScaler ||
          _direction != direction ||
          _disableAnimations != disableAnimations) {
        _nameChanged = false;
        _width = constraints.maxWidth;
        _style = style;
        _textScaler = textScaler;
        _direction = direction;
        _disableAnimations = disableAnimations;
        _restartAfterLayout(disableAnimations);
      }
      return SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        physics: disableAnimations
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        clipBehavior: Clip.hardEdge,
        child: Text(widget.name, style: style, maxLines: 1, softWrap: false),
      );
    });
  }
}
