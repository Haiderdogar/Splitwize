import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:splitwize/data/app_repository.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/providers/core_providers.dart';
import 'package:splitwize/providers/data_providers.dart';
import 'package:splitwize/providers/monetization_providers.dart';
import 'package:splitwize/screens/bills_tab.dart';
import 'package:splitwize/screens/settings_screen.dart';
import 'package:splitwize/services/sync_service.dart';
import 'package:splitwize/theme.dart';
import 'package:splitwize/widgets/app_drawer.dart';
import 'package:splitwize/widgets/paywall_sheet.dart';

import 'responsive_overflow_test.dart' as responsive show loadRoboto;

const _user = AppUser(
  uid: 'me',
  displayName: 'Ali Haider',
  email: 'ali@example.com',
  currency: 'PKR',
);

class _SettingsRepository extends Fake implements AppRepository {
  AppUser profile = _user;
  final currencies = <String>[];
  final changes = StreamController<AppUser>.broadcast();

  Stream<AppUser?> watchProfile() async* {
    yield profile;
    yield* changes.stream;
  }

  @override
  Future<void> setMyCurrency(String code) async {
    currencies.add(code);
    profile = profile.copyWith(currency: code);
    changes.add(profile);
  }
}

class _SettingsSync extends Fake implements SyncService {
  int calls = 0;
  Completer<void>? gate;

  @override
  Future<void> syncNow() async {
    calls++;
    await gate?.future;
  }
}

class _Appearance extends ThemeModeSetting {
  @override
  Future<AppTheme> build() async => AppTheme.system;

  @override
  Future<void> setMode(AppTheme value) async {
    state = AsyncData(value);
  }
}

class _AdFree extends AdFreeStatus {
  _AdFree(this.active);
  final bool active;

  @override
  Future<bool> build() async => active;
}

Future<void> _pumpSettings(
  WidgetTester tester,
  _SettingsRepository repository, {
  Widget screen = const SettingsScreen(),
  bool adFree = false,
  _SettingsSync? sync,
  Stream<SyncState>? syncStates,
  Future<AuthorizationStatus?>? permission,
  Future<AuthorizationStatus?> Function()? permissionRequest,
  bool settle = true,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUidProvider.overrideWith((ref) => _user.uid),
      currentAppUserProvider.overrideWith((ref) => repository.watchProfile()),
      authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
      appRepositoryProvider.overrideWith((ref) async => repository),
      themeModeSettingProvider.overrideWith(_Appearance.new),
      notificationAuthorizationStatusProvider.overrideWith((ref) =>
          permissionRequest?.call() ??
          permission ??
          Future.value(AuthorizationStatus.authorized)),
      syncStatusProvider
          .overrideWith((ref) => syncStates ?? Stream.value(const SyncState())),
      syncServiceProvider.overrideWith((ref) async => sync ?? _SettingsSync()),
      adFreeStatusProvider.overrideWith(() => _AdFree(adFree)),
      adFreePricesProvider.overrideWith(
          (ref) async => (monthly: r'$0.99/month', yearly: r'$7/year')),
      myBillsProvider.overrideWith((ref) => Stream.value(const <Bill>[])),
      notificationsProvider
          .overrideWith((ref) => Stream.value(const <AppNotification>[])),
    ],
    child: MaterialApp(
      theme: splitwizeLightTheme,
      home: screen,
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  expect(tester.takeException(), isNull);
  if (settle) await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 250,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Finder _text(String text) =>
    find.byWidgetPredicate((widget) => widget is Text && widget.data == text);

void main() {
  setUpAll(responsive.loadRoboto);
  late _SettingsRepository repository;

  setUp(() {
    repository = _SettingsRepository();
  });
  tearDown(() async {
    await repository.changes.close();
  });

  testWidgets(
      'notification permission loading and errors stay explicit and retry',
      (tester) async {
    final firstRequest = Completer<AuthorizationStatus?>();
    var requests = 0;
    Future<AuthorizationStatus?> requestPermissionStatus() {
      requests++;
      return requests == 1
          ? firstRequest.future
          : Future.value(AuthorizationStatus.provisional);
    }

    await _pumpSettings(
      tester,
      repository,
      permissionRequest: requestPermissionStatus,
      settle: false,
    );
    await _reveal(tester, find.text('Push notifications'));
    expect(find.text('Checking permission…'), findsOneWidget);
    expect(find.text('Off'), findsNothing);

    firstRequest.completeError(StateError('Permission status unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Status unavailable'), findsOneWidget);
    expect(find.text('Off'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('Enabled'), findsOneWidget);
    expect(find.text('Status unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('default currency picker saves the selected account currency',
      (tester) async {
    await _pumpSettings(tester, repository);
    await _reveal(tester, find.text('Default currency'));
    await tester.tap(find.text('Default currency'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'EUR');
    await tester.pumpAndSettle();
    // A favorite also appears in the filtered all-currencies list.
    await tester.tap(_text('EUR').hitTestable().first);
    await tester.pumpAndSettle();
    expect(repository.currencies, ['EUR']);
    expect(repository.profile.currencyCode, 'EUR');
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('EUR'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sync command runs and is disabled while sync is in progress',
      (tester) async {
    final states = StreamController<SyncState>();
    addTearDown(states.close);
    final sync = _SettingsSync()..gate = Completer<void>();
    Stream<SyncState> updates() async* {
      yield const SyncState(online: false, pending: 2);
      yield* states.stream;
    }

    await _pumpSettings(tester, repository, sync: sync, syncStates: updates());
    await _reveal(tester, find.text('Sync now'));
    expect(find.textContaining('Offline'), findsWidgets);
    await tester.tap(find.text('Sync now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(sync.calls, 1);
    final button = find.ancestor(
      of: find.text('Sync now'),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);

    states.add(const SyncState(syncing: true, pending: 2));
    sync.gate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
    expect(sync.calls, 1);

    states.add(const SyncState());
    await tester.pumpAndSettle();
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('free account upgrade opens the existing subscription sheet',
      (tester) async {
    await _pumpSettings(tester, repository);
    await _reveal(tester, find.text('Upgrade'));
    await tester.tap(find.text('Upgrade'));
    await tester.pumpAndSettle();
    expect(find.byType(PaywallSheet), findsOneWidget);
    expect(find.text('Splitwize Ad-Free'), findsOneWidget);
    expect(find.text('Subscribe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('active subscription does not offer another upgrade',
      (tester) async {
    await _pumpSettings(tester, repository, adFree: true);
    await _reveal(tester, find.text('Ad-Free'));
    expect(find.text('Upgrade'), findsNothing);
    expect(find.textContaining(RegExp('active', caseSensitive: false)),
        findsWidgets);
    expect(find.byType(PaywallSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home app bar and drawer use the existing app artwork',
      (tester) async {
    await _pumpSettings(
      tester,
      repository,
      screen: Scaffold(
        key: splitwizeScaffoldKey,
        drawer: const SplitwizeDrawer(),
        body: const BillsTab(),
      ),
    );
    final artwork = find.byWidgetPredicate((widget) {
      if (widget is! Image) return false;
      final provider = widget.image;
      final asset = provider is ResizeImage ? provider.imageProvider : provider;
      return asset is AssetImage &&
          asset.assetName == 'assets/icon/app_icon.png';
    });
    expect(
      find.descendant(of: find.byType(AppBar), matching: artwork),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(Drawer), matching: artwork),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
