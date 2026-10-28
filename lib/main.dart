import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'providers/core_providers.dart';
import 'theme.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/sign_in_screen.dart';
import 'services/notification_service.dart';

/// Last-resort startup guard. An error that escapes to the Dart zone —
/// an unhandled Future/Stream error anywhere in startup, including
/// from a plugin's platform channel on a particular device — kills the
/// isolate, and the app then closes instantly with no UI at all (the
/// "opens then closes" crash). The zone handler below catches those
/// instead, and [SplitwizeApp] opens on a readable error screen
/// showing what failed, so the failure is visible and reportable
/// instead of a silent close.
final ValueNotifier<String?> startupFatalError = ValueNotifier<String?>(null);

Future<void> main() async {
  // Set once Firebase is up; the zone handler below only reports to
  // Crashlytics when it is available (Firebase init may itself fail).
  var crashlyticsReady = false;
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Firebase starts before any screen exists, so a failure here used to
    // kill the app instantly with no UI at all (the "opens then closes"
    // crash on a fresh install). Instead, capture the failure and still
    // start the app on a readable error screen, so the user can see —
    // and report — what actually went wrong.
    String? firebaseError;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Crash reporting, wired only once Firebase is up: framework
      // errors and uncaught async errors now land in Crashlytics
      // instead of vanishing, including native crashes (the Crashlytics
      // SDK ships with the plugin; no extra native setup needed).
      // No user identifiers are attached — reports carry opaque
      // stack traces only.
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      ui.PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      crashlyticsReady = true;
      // Offline-first: the app caches everything in SQLite and syncs via
      // deltas, so Firestore's own disk cache is disabled to avoid keeping
      // two copies (and Firestore never fetches behind our back).
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
    } catch (e) {
      firebaseError = '$e';
    }
    runApp(ProviderScope(child: SplitwizeApp(firebaseError: firebaseError)));
  }, (error, stack) {
    // Report to Crashlytics when available (non-fatal: the app stays
    // open on the error screen below instead of dying). Reporting
    // itself must never break the error screen.
    if (crashlyticsReady) {
      try {
        unawaited(
          FirebaseCrashlytics.instance.recordError(
            error,
            stack,
            fatal: false,
          ),
        );
      } catch (_) {
        // Ignore reporting failures entirely.
      }
    }
    // First fatal error wins; the running app rebuilds onto the
    // error screen below instead of dying.
    startupFatalError.value ??= '$error';
  });
}

class SplitwizeApp extends StatelessWidget {
  /// Non-null when Firebase failed to start in [main]: the app opens on
  /// an error screen instead of the auth flow (which needs Firebase).
  final String? firebaseError;

  const SplitwizeApp({super.key, this.firebaseError});

  @override
  Widget build(BuildContext context) {
    // Only the MaterialApp shell reacts to the appearance setting;
    // flipping it re-themes the whole app (light/dark ColorSchemes
    // are both derived from the same teal seed).
    return ValueListenableBuilder<String?>(
      valueListenable: startupFatalError,
      builder: (context, fatalError, _) {
        return Consumer(
          builder: (context, ref, _) {
            final mode =
                ref.watch(themeModeSettingProvider).value ?? AppTheme.system;
            return MaterialApp(
              title: 'Splitwize',
              debugShowCheckedModeBanner: false,
              navigatorKey: NotificationService.instance.navigatorKey,
              theme: splitwizeLightTheme,
              darkTheme: splitwizeDarkTheme,
              themeMode: switch (mode) {
                AppTheme.system => ThemeMode.system,
                AppTheme.light => ThemeMode.light,
                AppTheme.dark => ThemeMode.dark,
              },
              home: fatalError != null
                  ? _FirebaseInitErrorScreen(
                      error: fatalError,
                      message:
                          'Splitwize hit an unexpected error while starting. '
                          'The app stayed open on this screen so the failure '
                          'can be seen and reported, instead of closing with '
                          'no explanation.',
                    )
                  : firebaseError != null
                      ? _FirebaseInitErrorScreen(error: firebaseError!)
                      : const AuthGate(),
            );
          },
        );
      },
    );
  }
}

/// Shown instead of [AuthGate] when Firebase failed to start in [main].
/// The auth flow needs Firebase, so it must not run in that state — but
/// the app itself must still open, with the failure visible, instead of
/// closing instantly with no explanation.
class _FirebaseInitErrorScreen extends StatelessWidget {
  final String error;

  /// Body text. Defaults to the Firebase explanation; the zone guard
  /// passes its own text for non-Firebase startup failures.
  final String? message;

  const _FirebaseInitErrorScreen({required this.error, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                "Splitwize couldn't start.\n"
                '${message ?? 'Firebase failed to initialise on this device. '
                    'This usually means Google Play services is missing or '
                    'out of date, or the installed build has the wrong '
                    'Firebase configuration — reinstalling the matching '
                    'build usually fixes it.'}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// App entry gate: the one-time onboarding shows first (once per
/// install), then sign-in / home based on auth state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final seen = ref.watch(onboardingSeenProvider);
        return seen.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          // If the flag can't be read, fail open into the normal flow
          // rather than trapping the user on onboarding.
          error: (_, __) => const _AuthFlow(),
          data: (seen) => seen ? const _AuthFlow() : const OnboardingScreen(),
        );
      },
    );
  }
}

/// Shows the sign-in screen when logged out, the app when logged in.
class _AuthFlow extends StatelessWidget {
  const _AuthFlow();

  @override
  Widget build(BuildContext context) {
    // Only this subtree reacts to auth state; everything below stays plain.
    return Consumer(
      builder: (context, ref, _) {
        // Keeps FCM registration in sync with the signed-in user.
        ref.watch(initNotificationsProvider);
        // Opens the per-user SQLite cache and runs the offline-first
        // sync loop (outbox drain + delta pull on connectivity regain).
        ref.watch(initSyncProvider);
        final authState = ref.watch(authStateChangesProvider);
        return authState.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Could not reach the sign-in service.\nCheck your connection and restart the app.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$e',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          data: (user) =>
              user == null ? const SignInScreen() : const HomeShell(),
        );
      },
    );
  }
}
