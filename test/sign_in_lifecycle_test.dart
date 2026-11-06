import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/providers/core_providers.dart';
import 'package:splitwize/providers/form_providers.dart';
import 'package:splitwize/services/auth_service.dart';

import 'test_harness.dart';

/// A controllable substitute for the Google/Firebase authentication prompt.
/// The auth provider still uses its real Riverpod lifecycle.
class _DeferredAuthService extends AuthService {
  _DeferredAuthService(this.result);

  final Future<User?> result;
  int calls = 0;

  @override
  Future<User?> signInWithGoogle() {
    calls++;
    return result;
  }
}

void main() {
  setUpAll(initTestEnv);

  test('sign-in finishing after provider disposal does not crash', () async {
    final pending = Completer<User?>();
    final auth = _DeferredAuthService(pending.future);
    final container = ProviderContainer(overrides: [
      authServiceProvider.overrideWith((ref) => auth),
    ]);

    // Keep the autoDispose provider alive while the sign-in screen is up.
    final subscription = container.listen(signInProvider, (_, __) {});
    final signInFuture = container.read(signInProvider.notifier).signIn();
    expect(container.read(signInProvider), isTrue);

    // Simulate AuthFlow replacing the login screen with HomeShell while
    // the Google/Firebase Future is still pending.
    subscription.close();
    container.dispose();

    pending.complete(null);
    expect(await signInFuture, isNull);
    expect(auth.calls, 1);
  });

  test('sign-in suppresses duplicate attempts and resets busy', () async {
    final pending = Completer<User?>();
    final auth = _DeferredAuthService(pending.future);
    final container = ProviderContainer(overrides: [
      authServiceProvider.overrideWith((ref) => auth),
    ]);
    final subscription = container.listen(signInProvider, (_, __) {});
    addTearDown(() {
      subscription.close();
      container.dispose();
    });

    final first = container.read(signInProvider.notifier).signIn();
    final second = container.read(signInProvider.notifier).signIn();

    expect(auth.calls, 1);
    expect(container.read(signInProvider), isTrue);
    expect(await second, isNull);

    pending.complete(null);
    expect(await first, isNull);
    expect(container.read(signInProvider), isFalse);
  });

  test('sign-in errors are returned and busy state is restored', () async {
    final pending = Completer<User?>();
    final auth = _DeferredAuthService(pending.future);
    final container = ProviderContainer(overrides: [
      authServiceProvider.overrideWith((ref) => auth),
    ]);
    final subscription = container.listen(signInProvider, (_, __) {});
    addTearDown(() {
      subscription.close();
      container.dispose();
    });

    final result = container.read(signInProvider.notifier).signIn();
    pending.completeError(StateError('simulated auth failure'));

    expect(await result, contains('Sign-in failed:'));
    expect(container.read(signInProvider), isFalse);
  });
}
