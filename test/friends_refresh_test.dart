import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/providers/core_providers.dart';
import 'package:splitwize/providers/data_providers.dart';
import 'package:splitwize/screens/friends_tab.dart';

import 'fake_sync_service.dart';

const friendA =
    AppUser(uid: 'fa', displayName: 'Friend A', email: 'a@example.com');
const friendB =
    AppUser(uid: 'fb', displayName: 'Friend B', email: 'b@example.com');

Future<ProviderContainer> pumpFriends(WidgetTester tester, FakeSyncService sync,
    Stream<List<AppUser>> friends) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUidProvider.overrideWith((ref) => 'me'),
      syncServiceProvider.overrideWith((ref) async => sync),
      connectionsProvider.overrideWith((ref) => friends),
      unreadCountProvider.overrideWith((ref) => 0),
    ],
    child: const MaterialApp(home: FriendsTab()),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(FriendsTab)));
}

void main() {
  testWidgets(
      'opening Friends fetches connected people and pull refresh updates them',
      (tester) async {
    final friends = StreamController<List<AppUser>>();
    addTearDown(friends.close);
    var current = [friendA];
    final sync = FakeSyncService()
      ..onRefresh = () async => friends.add(current);
    await pumpFriends(tester, sync, friends.stream);
    expect(sync.refreshCalls, 1);
    expect(find.text('Friend A'), findsOneWidget);
    expect(find.text('No friends yet'), findsNothing);
    current = [friendA, friendB];
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(sync.refreshCalls, 2);
    expect(find.text('Friend B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning to Friends and resuming the app refresh the list',
      (tester) async {
    final sync = FakeSyncService();
    final container = await pumpFriends(tester, sync, Stream.value([friendA]));
    expect(sync.refreshCalls, 1);
    container.read(tabIndexProvider.notifier).set(3);
    await tester.pumpAndSettle();
    expect(sync.refreshCalls, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(sync.refreshCalls, 3);
    expect(tester.takeException(), isNull);
  });

  for (final cached in [
    const <AppUser>[],
    const [friendA]
  ]) {
    testWidgets(
        'failed refresh preserves ${cached.length} cached friends and allows retry',
        (tester) async {
      final sync = FakeSyncService()
        ..onRefresh = () async => throw StateError('Network unavailable');
      await pumpFriends(tester, sync, Stream.value(cached));
      expect(
          find.text(
              'Could not refresh friends. Check your connection and try again.'),
          findsOneWidget);
      expect(find.text('No friends yet'), findsNothing);
      if (cached.isNotEmpty) expect(find.text('Friend A'), findsOneWidget);
      sync.onRefresh = null;
      await tester.tap(find.byTooltip('Refresh friends'));
      await tester.pumpAndSettle();
      expect(sync.refreshCalls, 2);
      expect(
          find.text(
              'Could not refresh friends. Check your connection and try again.'),
          findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'an active search stays visible when the connection count shrinks',
      (tester) async {
    final friends = StreamController<List<AppUser>>();
    addTearDown(friends.close);
    friends.add([
      for (var i = 0; i < 9; i++)
        AppUser(uid: 'f$i', displayName: 'User $i', email: '$i@example.com')
    ]);
    await pumpFriends(tester, FakeSyncService(), friends.stream);
    await tester.enterText(find.byType(TextField), 'User 8');
    await tester.pumpAndSettle();
    friends.add([friendA]);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('No friends match your search.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('Friend A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
