import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../data/local_database.dart';
import '../models/models.dart';
import 'firestore_service.dart';
import 'notification_service.dart';
import 'secure_storage_service.dart';

/// Google Sign-In backed authentication.
/// On every sign-in the user's Firestore profile is created/updated,
/// and a snapshot is kept in secure storage so the app can open
/// offline straight into the home screen.
class AuthService {
  AuthService({SecureStorageService? secure})
      : _secure = secure ?? SecureStorageService();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _db = FirestoreService();
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
      final profile = AppUser(
        uid: user.uid,
        displayName: user.displayName ?? 'Friend',
        email: user.email ?? '',
        photoUrl: user.photoURL,
      );
      await _db.upsertUser(profile);
      await _secure.saveSession(profile);
    }
    return user;
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
