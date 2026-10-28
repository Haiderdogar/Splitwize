import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/main.dart';

import 'test_harness.dart';

void main() {
  // The guard notifier is process-global; keep tests independent.
  setUp(() => startupFatalError.value = null);
  tearDown(() => startupFatalError.value = null);

  testWidgets('Zone error shows an error screen instead of closing the app',
      (tester) async {
    await initTestEnv();
    // Start on the Firebase error screen so the onboarding art (which
    // has its own layout quirk under test) stays out of this test;
    // what matters here is the guard switching the app onto the
    // zone-error screen instead of dying.
    await tester.pumpWidget(
      const ProviderScope(
        child: SplitwizeApp(firebaseError: 'Fake init failure for test'),
      ),
    );
    await tester.pump();
    expect(
        find.textContaining('Firebase failed to initialise'), findsOneWidget);
    expect(
        find.textContaining('unexpected error while starting'), findsNothing);

    // A fatal error escaping to the Dart zone — the class of failure
    // that used to kill the isolate and close the app with no UI.
    startupFatalError.value = 'Fake zone failure for test';
    await tester.pump();
    expect(find.textContaining("couldn't start"), findsOneWidget);
    expect(find.textContaining('Fake zone failure for test'), findsOneWidget);
    expect(
        find.textContaining('unexpected error while starting'), findsOneWidget);
  });
}
