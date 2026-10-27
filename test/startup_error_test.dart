import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/main.dart';

import 'test_harness.dart';

void main() {
  testWidgets('Firebase init failure shows an error screen, not a crash',
      (tester) async {
    await initTestEnv();
    await tester.pumpWidget(
      const ProviderScope(
        child: SplitwizeApp(firebaseError: 'Fake init failure for test'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining("couldn't start"), findsOneWidget);
    expect(find.textContaining('Fake init failure for test'), findsOneWidget);
  });
}
