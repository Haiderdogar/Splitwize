import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single clock for all three scenes; only artwork listens on every frame.
final onboardingMotionProvider = Provider.autoDispose<OnboardingMotion>((ref) {
  final motion = OnboardingMotion();
  ref.onDispose(motion.dispose);
  return motion;
});

class OnboardingMotion with WidgetsBindingObserver {
  OnboardingMotion() {
    animation = AnimationController(
      vsync: _MotionTickerProvider(),
      duration: const Duration(seconds: 8),
      value: .12,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  late final AnimationController animation;
  bool _enabled = false;
  bool _disposed = false;

  /// Called when reduced motion or the route's inherited TickerMode changes.
  void setEnabled(bool enabled) {
    if (_enabled == enabled || _disposed) return;
    _enabled = enabled;
    _updatePlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _updatePlayback();

  void _updatePlayback() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final foreground =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
    if (_enabled && foreground) {
      if (!animation.isAnimating) animation.repeat();
    } else {
      animation.stop(canceled: false);
    }
  }

  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    animation.dispose();
  }
}

class _MotionTickerProvider implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) =>
      Ticker(onTick, debugLabel: 'Onboarding illustrations');
}
