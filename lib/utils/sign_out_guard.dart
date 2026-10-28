/// Sign-out guard: signing out wipes the per-user local database,
/// including the outbox of changes not yet synced. This helper decides
/// whether signing out is safe right now, draining the outbox first
/// when there is anything pending, and asking the user only when
/// changes would otherwise be lost.
///
/// The [pendingCount], [drain] and [confirm] callbacks are injected so
/// the decision is unit-testable without Firebase, SQLite, or widgets:
/// - [pendingCount] returns the current number of unsynced outbox items.
/// - [drain] attempts a sync (a no-op when offline).
/// - [confirm] asks the user whether to sign out anyway, given the
///   number of changes that would be lost; it is only called when
///   changes remain after draining.
///
/// Returns true when signing out may proceed.
Future<bool> resolveSignOut({
  required Future<int> Function() pendingCount,
  required Future<void> Function() drain,
  required Future<bool> Function(int pending) confirm,
}) async {
  var pending = await pendingCount();
  if (pending == 0) return true;
  // Try to save the pending work first; when online this drains the
  // outbox and sign-out proceeds with nothing to lose.
  await drain();
  pending = await pendingCount();
  if (pending == 0) return true;
  // Still pending (offline, or sync failed): only the user may decide
  // to discard these changes.
  return confirm(pending);
}
