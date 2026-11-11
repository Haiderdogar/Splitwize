import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../data/local_database.dart';
import '../models/models.dart';
import 'firestore_service.dart';
import 'notification_service.dart';
import 'secure_storage_service.dart';

/// Combines the verified Google identity with the same account's preferences.
/// A secure snapshot can contain a name still waiting in the local outbox, so
/// its custom name takes priority during reauthentication on this device.
AppUser mergeGoogleSignInProfile({
  required AppUser authenticated,
  AppUser? stored,
  AppUser? session,
}) {
  if (stored?.uid != authenticated.uid) stored = null;
  if (session?.uid != authenticated.uid) session = null;
  AppUser? customName;
  for (final candidate in [session, stored]) {
    if (candidate != null &&
        candidate.nameIsCustom &&
        candidate.displayName.trim().isNotEmpty) {
      customName = candidate;
      break;
    }
  }
  return authenticated.copyWith(
    displayName: customName?.displayName.trim(),
    nameIsCustom: customName != null,
    photoUrl: authenticated.photoUrl ?? stored?.photoUrl ?? session?.photoUrl,
    currency: stored?.currency ?? session?.currency,
  );
}

/// Google Sign-In backed authentication.
/// On every sign-in the user's Firestore profile is created/updated,
/// and a snapshot is kept in secure storage so the app can open
/// offline straight into the home screen.
class AuthService {
  AuthService({SecureStorageService? secure, FirestoreService? remote})
      : _secure = secure ?? SecureStorageService(),
        _db = remote ?? FirestoreService();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _db;
  final SecureStorageService _secure;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  /// Returns the signed-in Firebase user, or null if the user cancelled.
  Future<User?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // user cancelled

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user != null) {
      // GoogleSignInAccount carries the account's profile information even
      // when the Firebase User object lacks displayName or photoURL.
      final googleName = googleUser.displayName?.trim() ?? '';
      final firebaseName = user.displayName?.trim() ?? '';
      final email = googleUser.email.trim().isNotEmpty
          ? googleUser.email.trim()
          : (user.email?.trim() ?? '');
      final displayName = googleName.isNotEmpty
          ? googleName
          : firebaseName.isNotEmpty
              ? firebaseName
              : email.contains('@')
                  ? email.split('@').first
                  : 'Splitwize member';
      final authenticated = AppUser(
        uid: user.uid,
        displayName: displayName,
        email: email,
        photoUrl: googleUser.photoUrl ?? user.photoURL,
      );
      await saveGoogleSignInProfile(authenticated);
    }
    return user;
  }

  /// Saves the authenticated identity only after reading existing preferences.
  /// A failed lookup must stop the write: falling back to Google at that point
  /// could replace a custom name that exists only in the remote profile.
  Future<AppUser> saveGoogleSignInProfile(AppUser authenticated) async {
    final session = await _secure.loadSession();
    final stored = await _db.getUser(authenticated.uid);
    final profile = mergeGoogleSignInProfile(
      authenticated: authenticated,
      stored: stored,
      session: session,
    );
    await _db.upsertUser(profile);
    await _secure.saveSession(profile);
    return profile;
  }

  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    // Unregister this device's push token FIRST, while still signed
    // in (the Firestore write needs auth): otherwise the device keeps
    // receiving this account's pushes after sign-out.
    if (uid != null) {
      await NotificationService.instance.dispose(uid);
    }
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // ignore — sign out of Firebase regardless
    }
    await _auth.signOut();
    // Wipe local copies: session snapshot + the per-user SQLite cache.
    await _secure.clearSession();
    await _secure.clearFcmToken();
    if (uid != null) {
      try {
        await LocalDatabase.deleteForUid(uid);
      } catch (_) {}
    }
  }
}
