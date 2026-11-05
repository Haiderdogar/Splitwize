import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/data/app_repository.dart';
import 'package:splitwize/data/local_database.dart';
import 'package:splitwize/providers/core_providers.dart';
import 'package:splitwize/providers/logout_provider.dart';
import 'package:splitwize/services/auth_service.dart';
import 'package:splitwize/services/firestore_service.dart';
import 'package:splitwize/services/secure_storage_service.dart';
import 'package:splitwize/services/sync_service.dart';
import 'package:splitwize/widgets/logout_button.dart';

import 'test_harness.dart';

class RecordingAuth extends AuthService {
  int calls = 0;
  bool fail = false;
  Completer<void>? gate;
  final started = Completer<void>();

  @override
  Future<void> signOut() async {
    calls++;
    if (!started.isCompleted) started.complete();
    await gate?.future;
    if (fail) throw StateError('Sign-in service unavailable');
  }
}

class RecordingSync extends SyncService {
  RecordingSync(AppRepository repository, FirestoreService remote)
      : super(repository: repository, remote: remote);
  int calls = 0;
  Future<void> Function()? drain;

  @override
  Future<void> syncNow() async {
    calls++;
    await drain?.call();
  }
}

class DialogLogout extends LogoutController {
  int calls = 0;

  @override
  Future<bool> logOut({required Future<bool> Function(int) confirm}) async {
    calls++;
    state = true;
    try {
      return await confirm(2);
    } finally {
      state = false;
    }
  }
}

void main() {
  setUpAll(initTestEnv);

  group('logout controller', () {
    late LocalDatabase db;
    late AppRepository repo;
    late RecordingAuth auth;
    late RecordingSync sync;
    late ProviderContainer container;

    setUp(() async {
      await LocalDatabase.deleteForUid('logout-test');
      db = await LocalDatabase.open('logout-test');
      final remote = FirestoreService();
      repo = AppRepository(
          db: db,
          remote: remote,
          secure: SecureStorageService(),
          myUid: 'logout-test');
      sync = RecordingSync(repo, remote);
      auth = RecordingAuth();
      container = ProviderContainer(overrides: [
        appRepositoryProvider.overrideWith((ref) async => repo),
        syncServiceProvider.overrideWith((ref) async => sync),
        authServiceProvider.overrideWith((ref) => auth),
      ]);
    });

    tearDown(() async {
      container.dispose();
      sync.dispose();
      repo.dispose();
      await LocalDatabase.deleteForUid('logout-test');
    });

    test('logs out once and resets navigation when all changes are synced',
        () async {
      container.read(tabIndexProvider.notifier).set(4);
      final result = await container
          .read(logoutControllerProvider.notifier)
          .logOut(
              confirm: (_) async =>
                  throw StateError('Unexpected confirmation'));
      expect(result, isTrue);
      expect(auth.calls, 1);
      expect(sync.calls, 0);
      expect(container.read(tabIndexProvider), 0);
      expect(container.read(logoutControllerProvider), isFalse);
    });

    test('cancelling keeps unsynced work and the session', () async {
      await db.enqueue('group.currency', {'groupId': 'g1', 'currency': 'USD'});
      var pending = 0;
      final result = await container
          .read(logoutControllerProvider.notifier)
          .logOut(confirm: (count) async {
        pending = count;
        return false;
      });
      expect(result, isFalse);
      expect(pending, 1);
      expect(sync.calls, 1);
      expect(auth.calls, 0);
      expect(await db.outboxCount(), 1);
      expect(container.read(logoutControllerProvider), isFalse);
    });

    test('syncs outstanding changes before logging out', () async {
      await db.enqueue('group.currency', {'groupId': 'g1', 'currency': 'USD'});
      sync.drain = () async {
        for (final op in await db.peekOutbox()) {
          await db.removeOutbox(op['id'] as int);
        }
      };
      final result = await container
          .read(logoutControllerProvider.notifier)
          .logOut(
              confirm: (_) async =>
                  throw StateError('Unexpected confirmation'));
      expect(result, isTrue);
      expect(auth.calls, 1);
      expect(await db.outboxCount(), 0);
    });

    test('repeated taps cannot start a second logout', () async {
      auth.gate = Completer<void>();
      final controller = container.read(logoutControllerProvider.notifier);
      final first = controller.logOut(confirm: (_) async => true);
      await auth.started.future;
      expect(container.read(logoutControllerProvider), isTrue);
      expect(await controller.logOut(confirm: (_) async => true), isFalse);
      expect(auth.calls, 1);
      auth.gate!.complete();
      expect(await first, isTrue);
      expect(container.read(logoutControllerProvider), isFalse);
    });

    test('failed logout can be retried', () async {
      auth.fail = true;
      final controller = container.read(logoutControllerProvider.notifier);
      await expectLater(
          controller.logOut(confirm: (_) async => true), throwsStateError);
      expect(container.read(logoutControllerProvider), isFalse);
      auth.fail = false;
      expect(await controller.logOut(confirm: (_) async => true), isTrue);
      expect(auth.calls, 2);
    });
  });

  testWidgets('logout button warns about unsynced work and supports cancelling',
      (tester) async {
    final controller = DialogLogout();
    await tester.pumpWidget(ProviderScope(overrides: [
      logoutControllerProvider.overrideWith(() => controller),
    ], child: const MaterialApp(home: Scaffold(body: LogoutButton()))));
    await tester.tap(find.text('Log out'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Unsynced changes'), findsOneWidget);
    expect(find.textContaining('2 changes'), findsOneWidget);
    expect(find.text('Log out anyway'), findsOneWidget);
    expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('logout-button')))
            .enabled,
        isFalse);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Unsynced changes'), findsNothing);
    expect(controller.calls, 1);
  });
}
