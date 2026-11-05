# Google sign-in fails in a GitHub release APK

Google Play services status 10 is `DEVELOPER_ERROR`: an app configuration
problem. For this project, verify the release package, certificate registration,
and OAuth configuration before changing Dart authentication logic.

## Current release identity

GitHub Actions builds `com.example.splitwize`, signed by
`android/app/debug.keystore`, alias `splitwize-debug`, through the `sharedDebug`
release signing config in `android/app/build.gradle.kts`.

SHA-1:

```text
EF:46:99:1E:0F:1D:E0:40:82:1B:2D:00:B0:A9:25:A2:D3:E8:00:30
```

SHA-256:

```text
C7:99:72:69:93:AA:31:3E:12:15:F7:3F:75:17:5B:7F:37:0E:06:7D:B0:05:74:8D:57:A2:5E:E8:37:8A:6F:5E
```

These fingerprints belong to the current shared release certificate, not the
machine-specific certificate used by a normal `flutter run` debug build.

## Fix in Firebase and GitHub

1. Open Firebase Console, project `splitwize-e5208`, then Project settings >
   General > Your apps > Android app **com.example.splitwize**.
2. Add the SHA-1 above under SHA certificate fingerprints. Also register the
   SHA-256 above. Keep any fingerprints already registered for other builds.
3. Under Authentication > Sign-in method, ensure **Google** is enabled and the
   support email is configured.
4. Download the updated **google-services.json** for this Android app and
   replace `android/app/google-services.json` locally.
5. In GitHub repository Settings > Secrets and variables > Actions, replace
   **ANDROID_GOOGLE_SERVICES_JSON** with the complete updated JSON file.
   **The release workflow overwrites the repository copy with this secret.**
   Committing only the local JSON file does not update the release's config.
6. Check that **FIREBASE_OPTIONS_DART** still belongs to the same Firebase
   project and Android app; changing certificate fingerprints alone does not
   change the Firebase app ID.
7. Push the updated workflow/configuration, or run Flutter CI again from Actions
   after the workflow is available on GitHub. Install the newly generated APK
   and test Google sign-in.

Registering a fingerprint changes Firebase/Google OAuth configuration. Editing
`google-services.json` to invent an Android OAuth entry cannot register it.

## Release validation

The release job now runs:

```bash
dart run tool/verify_android_sign_in.dart
```

It reads the current shared signing certificate with Java's `keytool`, verifies
the Android package and matching SHA-1 OAuth entry, requires the web OAuth client,
and compares the Firebase Android app/project IDs with `FirebaseOptions.android`.
It prints certificate fingerprints, never API keys or the complete config.

On Windows, if `keytool` is not on PATH or in JAVA_HOME, pass its full path:

```powershell
dart run tool/verify_android_sign_in.dart "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
```

This check can detect stale or mismatched downloaded configuration. It does not
contact Firebase or prove that Google sign-in works on a device. If the check
passes but error 10 remains, verify the installed APK's signing certificate with
`apksigner verify --print-certs`, and inspect the Android OAuth client in the
Google Cloud Console for this project.

When moving to Play Store app signing, register the Play **app signing**
certificate as well. Its fingerprint can differ from the upload certificate
and from this GitHub release certificate.

References: [Firebase Android Google sign-in setup](https://firebase.google.com/docs/auth/android/google-signin),
[Google Play services status codes](https://developers.google.com/android/reference/com/google/android/gms/common/api/CommonStatusCodes#DEVELOPER_ERROR).
