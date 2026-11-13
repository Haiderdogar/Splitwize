import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/utils/invitation_notification_content.dart';

void main() {
  test('connection invitation names the sender', () {
    expect(
        invitationNotificationBody(
            type: 'friend_request',
            fromName: 'Hamza Malik',
            fromEmail: 'hamza@example.com'),
        'Hamza Malik invited you to connect on Splitwize.');
  });

  test('group invitation names the actual sender and destination group', () {
    expect(
        invitationNotificationBody(
            type: 'group_invite',
            fromName: 'Sara Khan',
            groupName: 'Road trip'),
        'Sara Khan invited you to join "Road trip".');
  });

  test('email identifies a sender whose display name is blank', () {
    expect(
        invitationNotificationBody(
            type: 'friend_request',
            fromName: '   ',
            fromEmail: 'sara@example.com'),
        'sara@example.com invited you to connect on Splitwize.');
  });

  test('trims identity and group snapshots', () {
    expect(
        invitationNotificationBody(
            type: 'group_invite',
            fromName: ' Hamza Malik ',
            groupName: ' Weekend '),
        'Hamza Malik invited you to join "Weekend".');
  });

  test('missing identity preserves the legacy message through null fallback',
      () {
    for (final type in ['friend_request', 'group_invite']) {
      expect(
          invitationNotificationBody(type: type, groupName: 'Weekend'), isNull);
    }
  });

  test('missing group name preserves the original group invitation message',
      () {
    expect(
        invitationNotificationBody(
            type: 'group_invite', fromName: 'Hamza Malik', groupName: '  '),
        isNull);
  });

  test('bill and reminder copy stays unchanged', () {
    for (final type in ['bill_created', 'bill_paid', 'reminder', 'unknown']) {
      expect(
          invitationNotificationBody(
              type: type, fromName: 'Hamza Malik', groupName: 'Weekend'),
          isNull);
    }
  });
}
