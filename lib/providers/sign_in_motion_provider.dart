import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'onboarding_motion_provider.dart';

/// Reuses the lifecycle-aware scene clock with a separate lifetime for login.
/// Login and onboarding can never pause or dispose each other's animation.
final signInMotionProvider = Provider.autoDispose<OnboardingMotion>((ref) {
  final motion = OnboardingMotion();
  ref.onDispose(motion.dispose);
  return motion;
});
