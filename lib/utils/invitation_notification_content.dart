/// Builds invitation copy from saved identity details. Older notifications
/// without those details keep their original body instead.
String? invitationNotificationBody({
  required String type,
  String? fromName,
  String? fromEmail,
  String? groupName,
}) {
  final name = fromName?.trim() ?? '';
  final email = fromEmail?.trim() ?? '';
  final sender = name.isNotEmpty ? name : email;
  if (sender.isEmpty) return null;

  if (type == 'friend_request') {
    return '$sender invited you to connect on Splitwize.';
  }
  final group = groupName?.trim() ?? '';
  if (type == 'group_invite' && group.isNotEmpty) {
    return '$sender invited you to join "$group".';
  }
  return null;
}
