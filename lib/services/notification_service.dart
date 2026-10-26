import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'firestore_service.dart';
import 'secure_storage_service.dart';

/// Must stay a top-level function for background messages.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // The OS shows the notification automatically when the app is in the
  // background/terminated, so nothing is needed here for the basic flow.
}

/// Handles FCM: permission, token registration in Firestore,
/// foreground messages (in-app snackbar) and taps.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirestoreService _db = FirestoreService();
  final SecureStorageService _secure = SecureStorageService();

  /// Used to show foreground notifications from anywhere.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  String? _uid;
  String? _token;
  bool _listenersAttached = false;

  Future<void> init(String uid) async {
    _uid = uid;
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    _token = await messaging.getToken();
    if (_token != null) {
      // Best effort — may be offline; SyncService re-registers nothing,
      // the token is already cached in secure storage for later.
      try {
        await _db.saveFcmToken(uid, _token!);
      } catch (_) {}
      await _secure.saveFcmToken(_token!);
    }

    if (!_listenersAttached) {
      _listenersAttached = true;
      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        final currentUid = _uid;
        if (currentUid == null) return;
        // Best effort: a refresh while offline must not surface as an
        // unhandled async error; the next init re-registers anyway.
        try {
          if (_token != null) {
            await _db.removeFcmToken(currentUid, _token!);
          }
          _token = token;
          await _db.saveFcmToken(currentUid, token);
          await _secure.saveFcmToken(token);
        } catch (_) {}
      });
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final title = message.notification?.title ?? 'Splitwize';
    final body = message.notification?.body ?? 'You have a new update.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title\n$body'),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    // Tapping a bill notification could deep-link to the bill.
    // For now the Bills tab shows the latest bills at the top.
  }

  /// Call on sign-out so this device stops receiving the old user's pushes.
  Future<void> dispose(String uid) async {
    if (_token != null) {
      try {
        await _db.removeFcmToken(uid, _token!);
      } catch (_) {}
    }
    await _secure.clearFcmToken();
    _uid = null;
    _token = null;
  }
}
