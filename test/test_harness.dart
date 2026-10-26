// Shared harness for functional tests: runs the REAL SQLite layer
// (via sqflite_common_ffi on the desktop test VM) and lets
// Firebase-backed classes be CONSTRUCTED (core is mocked; no network
// call is ever made — repository paths under test are cache-first and
// every profile they need is seeded into the local DB beforehand).
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:splitwize/models/models.dart';

const meUser = AppUser(
  uid: 'me',
  displayName: 'Me Myself',
  email: 'me@example.com',
);
const friendA = AppUser(
  uid: 'fa',
  displayName: 'Friend A',
  email: 'a@example.com',
);
const friendB = AppUser(
  uid: 'fb',
  displayName: 'Friend B',
  email: 'b@example.com',
);

Future<void> initTestEnv() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  setupFirebaseCoreMocks();
  await Firebase.initializeApp();

  // In-memory flutter_secure_storage.
  final store = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      final args = (call.arguments as Map?) ?? const {};
      switch (call.method) {
        case 'read':
          return store[args['key']];
        case 'write':
          store[args['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          store.remove(args['key']);
          return null;
        case 'deleteAll':
          store.clear();
          return null;
        case 'readAll':
          return Map<String, String>.from(store);
        case 'containsKey':
          return store.containsKey(args['key']);
      }
      return null;
    },
  );
}
