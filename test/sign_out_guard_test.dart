import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/utils/sign_out_guard.dart';

void main() {
  group('resolveSignOut', () {
    test('proceeds immediately when nothing is pending', () async {
      var drainCalls = 0;
      var confirmCalls = 0;
      final result = await resolveSignOut(
        pendingCount: () async => 0,
        drain: () async {
          drainCalls++;
        },
        confirm: (_) async {
          confirmCalls++;
          return false;
        },
      );
      expect(result, isTrue);
      expect(drainCalls, 0);
      expect(confirmCalls, 0);
    });

    test('drains first and proceeds when the drain clears the queue', () async {
      var pending = 3;
      var confirmCalls = 0;
      final result = await resolveSignOut(
        pendingCount: () async => pending,
        drain: () async {
          pending = 0;
        },
        confirm: (_) async {
          confirmCalls++;
          return false;
        },
      );
      expect(result, isTrue);
      expect(confirmCalls, 0);
    });

    test('asks the user with the remaining count when changes survive',
        () async {
      var askedWith = -1;
      final result = await resolveSignOut(
        pendingCount: () async => 2,
        drain: () async {},
        confirm: (pending) async {
          askedWith = pending;
          return true;
        },
      );
      expect(result, isTrue);
      expect(askedWith, 2);
    });

    test('aborts when the user declines to discard changes', () async {
      final result = await resolveSignOut(
        pendingCount: () async => 5,
        drain: () async {},
        confirm: (_) async => false,
      );
      expect(result, isFalse);
    });
  });
}
