import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'providers/core_providers.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/sign_in_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Offline-first: the app caches everything in SQLite and syncs via
  // deltas, so Firestore's own disk cache is disabled to avoid keeping
  // two copies (and Firestore never fetches behind our back).
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const ProviderScope(child: SplitwizeApp()));
}

class SplitwizeApp extends StatelessWidget {
  const SplitwizeApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Only the MaterialApp shell reacts to the appearance setting;
    // flipping it re-themes the whole app (light/dark ColorSchemes
    // are both derived from the same teal seed).
    return Consumer(
      builder: (context, ref, _) {
        final mode =
            ref.watch(themeModeSettingProvider).value ?? AppTheme.system;
        return MaterialApp(
          title: 'Splitwize',
          debugShowCheckedModeBanner: false,
          navigatorKey: NotificationService.instance.navigatorKey,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: switch (mode) {
            AppTheme.system => ThemeMode.system,
            AppTheme.light => ThemeMode.light,
            AppTheme.dark => ThemeMode.dark,
          },
          home: const AuthGate(),
        );
      },
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
