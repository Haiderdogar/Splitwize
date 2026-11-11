import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/data/app_repository.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/providers/core_providers.dart';
import 'package:splitwize/providers/data_providers.dart';
import 'package:splitwize/providers/monetization_providers.dart';
import 'package:splitwize/screens/profile_tab.dart';
import 'package:splitwize/screens/settings_screen.dart';
import 'package:splitwize/services/sync_service.dart';
import 'package:splitwize/theme.dart';

const original = AppUser(
    uid: 'me', displayName: 'Google Name', email: 'verified@example.com');

class _GoogleUser extends Fake implements User {
  @override
  String get uid => original.uid;
  @override
  String? get displayName => original.displayName;
  @override
  String? get email => original.email;
  @override
  String? get photoURL => null;
}

class _ProfileRepository extends Fake implements AppRepository {
  AppUser profile = original;
  final changes = StreamController<AppUser>.broadcast();
  final names = <String>[];
  Future<void>? gate;
  bool fail = false;
  Stream<AppUser?> watch() async* {
    yield profile;
    yield* changes.stream;
  }

  @override
  Future<void> setMyDisplayName(String value) async {
    names.add(value);
    await gate;
    if (fail) throw StateError('Write failed');
    profile = profile.copyWith(displayName: value, nameIsCustom: true);
    changes.add(profile);
  }
}

class _ThemeSetting extends ThemeModeSetting {
  AppTheme selected = AppTheme.system;
  @override
  Future<AppTheme> build() async => selected;
  @override
  Future<void> setMode(AppTheme value) async {
    selected = value;
    state = AsyncData(value);
  }
}

class _AdFree extends AdFreeStatus {
  @override
  Future<bool> build() async => false;
}

Future<void> _pumpAccount(
    WidgetTester tester, Widget screen, _ProfileRepository repo,
    {double textScale = 1, _ThemeSetting? appearance}) async {
  await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWith((ref) => original.uid),
        currentAppUserProvider.overrideWith((ref) => repo.watch()),
        authStateChangesProvider
            .overrideWith((ref) => Stream.value(_GoogleUser())),
        appRepositoryProvider.overrideWith((ref) async => repo),
        notificationAuthorizationStatusProvider
            .overrideWith((ref) async => AuthorizationStatus.authorized),
        syncStatusProvider
            .overrideWith((ref) => Stream.value(const SyncState())),
        adFreeStatusProvider.overrideWith(() => _AdFree()),
        themeModeSettingProvider
            .overrideWith(() => appearance ?? _ThemeSetting()),
      ],
      child: MaterialApp(
          theme: splitwizeLightTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!),
          home: screen)));
  await tester.pumpAndSettle();
}

void main() {
  late _ProfileRepository repo;
  setUp(() {
    repo = _ProfileRepository();
  });
  tearDown(() async {
    await repo.changes.close();
  });

  testWidgets(
      'profile shows account details, keeps email read-only, and saves only name',
      (tester) async {
    await _pumpAccount(tester, const ProfileTab(), repo);
    expect(find.text(original.displayName), findsOneWidget);
    final emailField = tester.widget<TextField>(find.byType(TextField));
    expect(emailField.readOnly, isTrue);
    expect(emailField.controller!.text, original.email);
    expect(find.text('Appearance'), findsNothing);
    expect(find.text('Default currency'), findsNothing);
    await tester.tap(find.byTooltip('Edit name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('profile-name-input')),
        '  My preferred name  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.names, ['My preferred name']);
    expect(repo.profile.email, original.email);
    expect(find.text('My preferred name'), findsOneWidget,
        reason: 'The old Google name must not override the name just saved');
    expect(find.text('Your name has been updated.'), findsOneWidget);
  });

  testWidgets(
      'blank name is rejected and cancelling leaves the profile unchanged',
      (tester) async {
    await _pumpAccount(tester, const ProfileTab(), repo);
    await tester.tap(find.byTooltip('Edit name'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('profile-name-input')), '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(repo.names, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.profile, original);
  });

  testWidgets(
      'name edits are retained while profile data refreshes and duplicate saves are blocked',
      (tester) async {
    final pending = Completer<void>();
    repo.gate = pending.future;
    await _pumpAccount(tester, const ProfileTab(), repo);
    await tester.tap(find.byTooltip('Edit name'));
    await tester.pumpAndSettle();
    final name = find.byKey(const ValueKey('profile-name-input'));
    await tester.enterText(name, 'Unsaved draft');
    repo.changes.add(original.copyWith(currency: 'PKR'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved draft'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(repo.names, ['Unsaved draft']);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Saving...'))
            .onPressed,
        isNull);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Unsaved draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed name save keeps the edited text and allows retry',
      (tester) async {
    repo.fail = true;
    await _pumpAccount(tester, const ProfileTab(), repo);
    await tester.tap(find.byTooltip('Edit name'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('profile-name-input')), 'Try again');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save your name. Please try again.'),
        findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(repo.profile.email, original.email);
    repo.fail = false;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.names, ['Try again', 'Try again']);
    expect(find.text('Edit name'), findsNothing);
  });

  testWidgets(
      'settings contains the moved controls and appearance still changes',
      (tester) async {
    final appearance = _ThemeSetting();
    await _pumpAccount(tester, const SettingsScreen(), repo,
        appearance: appearance);
    for (final label in [
      'Push notifications',
      'Sync',
      'Default currency',
      'Appearance',
      'Ad-Free',
      'Log out'
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Personal details'), findsNothing);
    expect(find.byTooltip('Edit name'), findsNothing);
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(appearance.selected, AppTheme.dark);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('name editor fits a small phone with enlarged text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    await _pumpAccount(tester, const ProfileTab(), repo, textScale: 2);
    await tester.tap(find.byTooltip('Edit name'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-name-input')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
