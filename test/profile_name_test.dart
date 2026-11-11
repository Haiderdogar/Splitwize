import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/data/app_repository.dart';
import 'package:splitwize/data/local_database.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/services/auth_service.dart';
import 'package:splitwize/services/firestore_service.dart';
import 'package:splitwize/services/secure_storage_service.dart';
import 'package:splitwize/utils/current_user_identity.dart';

import 'test_harness.dart' show initTestEnv;

const _me = AppUser(
  uid: 'profile-name-test',
  displayName: 'Google Name',
  email: 'verified@example.com',
  photoUrl: 'https://example.com/avatar.png',
  currency: 'PKR',
);

class _ProfileRemote extends FirestoreService {
  AppUser? stored;
  Object? lookupError;
  final writes = <AppUser>[];
  final calls = <String>[];

  @override
  Future<AppUser?> getUser(String uid) async {
    calls.add('get:$uid');
    final error = lookupError;
    if (error != null) throw error;
    return stored;
  }

  @override
  Future<void> upsertUser(AppUser user) async {
    calls.add('upsert:${user.uid}');
    writes.add(user);
    stored = user;
  }
}

void main() {
  setUpAll(initTestEnv);

  group('editing my name', () {
    late LocalDatabase db;
    late SecureStorageService secure;
    late AppRepository repo;

    AppRepository openRepository() => AppRepository(
          db: db,
          remote: _ProfileRemote(),
          secure: secure,
          myUid: _me.uid,
        );

    setUp(() async {
      await LocalDatabase.deleteForUid(_me.uid);
      db = await LocalDatabase.open(_me.uid);
      secure = SecureStorageService();
      await secure.clearSession();
      repo = openRepository();
      await db.upsertUser(_me.uid, _me.toProfileMap());
    });

    tearDown(() async {
      repo.dispose();
      await LocalDatabase.deleteForUid(_me.uid);
      await secure.clearSession();
    });

    test('saves a trimmed name offline and retains verified account details',
        () async {
      await repo.setMyDisplayName('  New Account Name  ');
      final expected = _me.copyWith(
        displayName: 'New Account Name',
        nameIsCustom: true,
      );
      expect(await repo.getCachedUser(_me.uid), expected);
      expect(await secure.loadSession(), expected);
      final operation = (await db.peekOutbox()).single;
      expect(operation['type'], 'user.upsert');
      expect(
          operation['payload'], {'uid': _me.uid, ...expected.toProfileMap()});

      repo.dispose();
      await LocalDatabase.close();
      db = await LocalDatabase.open(_me.uid);
      repo = openRepository();
      expect(await repo.getUser(_me.uid), expected);
      expect((await db.peekOutbox()).single['type'], 'user.upsert');
    });

    test('rejects blank and oversized names without changing the profile',
        () async {
      for (final name in ['', ' \n\t ', 'x' * 101]) {
        await expectLater(repo.setMyDisplayName(name), throwsArgumentError);
      }
      expect(await repo.getCachedUser(_me.uid), _me);
      expect(await db.peekOutbox(), isEmpty);
      expect(await secure.loadSession(), isNull);
    });

    test('marks an explicitly saved Google name as custom only once', () async {
      await repo.setMyDisplayName(_me.displayName);
      await repo.setMyDisplayName(' ${_me.displayName} ');
      expect((await repo.getCachedUser(_me.uid))!.nameIsCustom, isTrue);
      expect(await db.peekOutbox(), hasLength(1));
    });

    test('currency settings preserve the edited name and immutable email',
        () async {
      await repo.setMyDisplayName('My Preferred Name');
      await repo.setMyCurrency('USD');
      final profile = await repo.getCachedUser(_me.uid);
      expect(profile!.displayName, 'My Preferred Name');
      expect(profile.nameIsCustom, isTrue);
      expect(profile.currencyCode, 'USD');
      expect(profile.email, _me.email);
      expect(profile.uid, _me.uid);
      expect(profile.photoUrl, _me.photoUrl);
      expect(await secure.loadSession(), profile);
    });

    test('cannot edit a different account from a stale secure snapshot',
        () async {
      await LocalDatabase.close();
      await LocalDatabase.deleteForUid(_me.uid);
      db = await LocalDatabase.open(_me.uid);
      await secure.saveSession(const AppUser(
        uid: 'another-account',
        displayName: 'Someone Else',
        email: 'someone@example.com',
      ));
      repo.dispose();
      repo = openRepository();
      await expectLater(repo.setMyDisplayName('New Name'), throwsStateError);
      expect(await repo.getCachedUser(_me.uid), isNull);
      expect(await db.peekOutbox(), isEmpty);
      expect((await secure.loadSession())!.uid, 'another-account');
    });
  });

  group('custom names and Google sign-in', () {
    test('marker survives profile serialization without changing older maps',
        () {
      expect(_me.toProfileMap().containsKey('nameIsCustom'), isFalse);
      expect(AppUser.fromMap(_me.uid, _me.toProfileMap()), _me);
      final custom = _me.copyWith(nameIsCustom: true);
      expect(AppUser.fromMap(_me.uid, custom.toProfileMap()), custom);
      expect(custom.toMap()['nameIsCustom'], isTrue);
      expect(custom, isNot(_me));
    });

    test('custom names override live Google names including legacy words', () {
      for (final name in ['Preferred Name', 'Friend', 'Splitwize member']) {
        final identity = resolveCurrentUserIdentity(
          cached: _me.copyWith(displayName: name, nameIsCustom: true),
          googleName: 'Google Name',
          googleEmail: _me.email,
        );
        expect(identity.name, name);
        expect(identity.email, _me.email);
      }
    });

    test('re-login retains a remote custom name and saved currency', () {
      final stored = _me.copyWith(
        displayName: 'My Preferred Name',
        nameIsCustom: true,
      );
      final merged = mergeGoogleSignInProfile(
        authenticated: AppUser(
          uid: _me.uid,
          displayName: _me.displayName,
          email: 'current-google@example.com',
        ),
        stored: stored,
      );
      expect(merged.displayName, stored.displayName);
      expect(merged.nameIsCustom, isTrue);
      expect(merged.email, 'current-google@example.com');
      expect(merged.currency, 'PKR');
    });

    test('same-account secure name preserves an unsynced edit on re-login', () {
      final merged = mergeGoogleSignInProfile(
        authenticated: _me,
        stored: _me.copyWith(displayName: 'Older Name', nameIsCustom: true),
        session: _me.copyWith(displayName: 'Newest Name', nameIsCustom: true),
      );
      expect(merged.displayName, 'Newest Name');
      expect(merged.nameIsCustom, isTrue);
      expect(merged.email, _me.email);
    });

    test('offline sign-in merge can restore same-account secure preferences',
        () {
      final authenticated = AppUser(
        uid: _me.uid,
        displayName: 'Google Name',
        email: _me.email,
      );
      final merged = mergeGoogleSignInProfile(
        authenticated: authenticated,
        session: _me.copyWith(displayName: 'Friend', nameIsCustom: true),
      );
      expect(merged.displayName, 'Friend');
      expect(merged.nameIsCustom, isTrue);
      expect(merged.currency, 'PKR');
      expect(merged.photoUrl, _me.photoUrl);
    });

    test('never imports another account name, email, photo or currency', () {
      const other = AppUser(
        uid: 'another-account',
        displayName: 'Other Person',
        email: 'other@example.com',
        currency: 'EUR',
        photoUrl: 'https://example.com/other.png',
        nameIsCustom: true,
      );
      expect(
        mergeGoogleSignInProfile(
          authenticated: _me,
          stored: other,
          session: other,
        ),
        _me,
      );
    });

    test('unmarked cached names still refresh from Google', () {
      final merged = mergeGoogleSignInProfile(
        authenticated: _me,
        stored: _me.copyWith(displayName: 'Friend'),
        session: _me.copyWith(displayName: 'Outdated Google Name'),
      );
      expect(merged.displayName, _me.displayName);
      expect(merged.nameIsCustom, isFalse);
    });

    test('failed remote lookup never overwrites an unknown custom name',
        () async {
      final secure = SecureStorageService();
      await secure.saveSession(_me);
      final custom = _me.copyWith(
        displayName: 'Custom Name From Another Device',
        nameIsCustom: true,
      );
      final remote = _ProfileRemote()
        ..stored = custom
        ..lookupError = StateError('Temporary profile read failure');
      final auth = AuthService(secure: secure, remote: remote);

      await expectLater(
        auth.saveGoogleSignInProfile(_me),
        throwsStateError,
      );

      expect(remote.calls, ['get:${_me.uid}']);
      expect(remote.writes, isEmpty);
      expect(remote.stored, custom);
      expect(await secure.loadSession(), _me);
      await secure.clearSession();
    });

    test('successful re-login persists custom name and verified Google email',
        () async {
      final secure = SecureStorageService();
      await secure.clearSession();
      final remote = _ProfileRemote()
        ..stored = _me.copyWith(
          displayName: 'Custom Name From Another Device',
          nameIsCustom: true,
        );
      final authenticated = AppUser(
        uid: _me.uid,
        displayName: 'Google Name',
        email: 'verified-current@example.com',
      );
      final auth = AuthService(secure: secure, remote: remote);

      final saved = await auth.saveGoogleSignInProfile(authenticated);

      expect(remote.calls, ['get:${_me.uid}', 'upsert:${_me.uid}']);
      expect(saved.displayName, 'Custom Name From Another Device');
      expect(saved.nameIsCustom, isTrue);
      expect(saved.email, authenticated.email);
      expect(saved.currency, _me.currency);
      expect(remote.writes.single, saved);
      expect(await secure.loadSession(), saved);
      await secure.clearSession();
    });
  });
}
