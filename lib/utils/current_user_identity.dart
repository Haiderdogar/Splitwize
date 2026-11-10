import '../models/models.dart';

/// Resolves the signed-in user's display identity, ignoring the old
/// placeholder "Friend" when a real Google name or email is available.
class CurrentUserIdentity {
  const CurrentUserIdentity({required this.name, required this.email});

  final String name;
  final String email;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    return parts.length == 1
        ? parts.first[0].toUpperCase()
        : (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

CurrentUserIdentity resolveCurrentUserIdentity({
  required AppUser? cached,
  String? googleName,
  String? googleEmail,
}) {
  final email = (googleEmail?.trim().isNotEmpty ?? false)
      ? googleEmail!.trim()
      : (cached?.email.trim() ?? '');

  bool usable(String value) =>
      value.isNotEmpty &&
      value.toLowerCase() != 'friend' &&
      value.toLowerCase() != 'splitwize member';

  final authenticated = googleName?.trim() ?? '';
  final saved = cached?.displayName.trim() ?? '';
  final name = usable(authenticated)
      ? authenticated
      : usable(saved)
          ? saved
          : email.contains('@')
              ? email.split('@').first
              : 'Your account';
  return CurrentUserIdentity(name: name, email: email);
}
