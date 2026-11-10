import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/utils/current_user_identity.dart';

void main() {
  group('signed-in account identity', () {
    test('replaces legacy Friend name with the Google profile', () {
      const cached = AppUser(
        uid: 'me', displayName: 'Friend', email: 'cached@example.com');
      final identity = resolveCurrentUserIdentity(
        cached: cached,
        googleName: 'Ali Haider',
        googleEmail: 'ali@example.com',
      );
      expect(identity.name, 'Ali Haider');
      expect(identity.email, 'ali@example.com');
      expect(identity.initials, 'AH');
    });

    test('uses email prefix when both names are placeholders', () {
      const cached = AppUser(
        uid: 'me', displayName: 'Friend', email: 'ali@example.com');
      final identity = resolveCurrentUserIdentity(cached: cached);
      expect(identity.name, 'ali');
      expect(identity.email, 'ali@example.com');
    });

    test('preserves an existing proper display name offline', () {
      const cached = AppUser(
        uid: 'me', displayName: 'Hamza Malik', email: 'hamza@example.com');
      final identity = resolveCurrentUserIdentity(cached: cached);
      expect(identity.name, 'Hamza Malik');
      expect(identity.initials, 'HM');
    });
  });
}
