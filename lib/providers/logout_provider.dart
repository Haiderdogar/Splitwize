import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/sign_out_guard.dart';
import 'core_providers.dart';

/// Shared by every logout entry point so only one logout can run at a time.
final logoutControllerProvider = NotifierProvider<LogoutController, bool>(
  LogoutController.new,
);

class LogoutController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<bool> logOut({
    required Future<bool> Function(int pending) confirm,
  }) async {
    if (state) return false;
    state = true;
    try {
      final repo = await ref.read(appRepositoryProvider.future);
      final sync = await ref.read(syncServiceProvider.future);
      final proceed = await resolveSignOut(
        pendingCount: repo.db.outboxCount,
        drain: sync.syncNow,
        confirm: confirm,
      );
      if (!proceed || !ref.mounted) return false;
      // AuthService unregisters notifications and clears the local session.
      await ref.read(authServiceProvider).signOut();
      if (ref.mounted) ref.read(tabIndexProvider.notifier).set(0);
      return true;
    } finally {
      if (ref.mounted) state = false;
    }
  }
}
