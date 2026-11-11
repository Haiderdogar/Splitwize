import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/services/sync_service.dart';

class FakeSyncService extends Fake implements SyncService {
  int refreshCalls = 0;
  Future<void> Function()? onRefresh;

  @override
  Future<void> refreshConnections() async {
    refreshCalls++;
    await onRefresh?.call();
  }

  @override
  Future<void> refreshGroupInvitation(String groupId) async {}
}
