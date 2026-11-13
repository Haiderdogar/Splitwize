# Run Splitwize on Android or iOS

Use your development computer to build and run the Android or iOS mobile app.

Everything you need is in this folder. The app is already connected to
your Firebase project (**splitwize-e5208**) — the config files
(`lib/firebase_options.dart`, `android/app/google-services.json`,
`ios/Runner/GoogleService-Info.plist`) are included and the Firestore
rules are already deployed, so there is no backend setup to do.

## 1. Install Flutter (one time)

1. Download the Flutter SDK: https://docs.flutter.dev/get-started/install
   (this app was built with Flutter 3.47 / Dart 3.13 — any recent
   stable Flutter works).
2. For Android, install Android Studio with the Android SDK and command-line
   tools. Set up an Android emulator or connect a phone with USB debugging on.
3. For iOS, use macOS with Xcode and its command-line tools.
   Set up an iOS simulator or connect an iPhone.
4. Run `flutter doctor` and resolve issues for the mobile target you use:
   the Android toolchain and an Android device/emulator, or Xcode and an
   iPhone/iOS simulator. VS Code with the Flutter extension is optional
   for editing the app.

## 2. Run the app

```bash
cd splitwize
flutter pub get
flutter devices
flutter run -d DEVICE_ID
```

Replace `DEVICE_ID` with the ID of an Android phone/emulator or an iPhone/iOS
simulator listed by `flutter devices`. iOS builds require macOS with Xcode.

Or open the folder in VS Code / Android Studio, select an Android or iOS
device, and press Run.

## 3. REQUIRED for Google Sign-In on Android: add your SHA-1

Google Sign-In will fail on your phone until Firebase knows your
computer's debug key. One-time, two minutes:

1. Get your debug key's SHA-1:

   - Windows: `keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android`
   - macOS/Linux: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`

2. Firebase Console → project **splitwize-e5208** → Project settings →
   Your apps → the Android app → **Add fingerprint** → paste the SHA-1 →
   Save. (Download a fresh `google-services.json` only if the console
   offers one — replacing `android/app/google-services.json` is safe
   but not required just for the fingerprint.)

## 4. Run the tests

```bash
flutter analyze     # should say: No issues found!
flutter test        # 204 tests, all passing
```

The functional tests run against a real local SQLite database, so you
can verify features (bills, balances, settle-up, debt simplification,
receipt photos, the Ad-Free paywall) without touching the live backend.

## What works right now vs. what's still pending

The **code for everything is complete** — including receipt uploads
and push notifications end to end (permission prompts, token
registration, background handling, the Cloud Functions themselves).
What remains is server-side switching-on, not code:

| Works today | Needs a console/deploy step (no code) |
|---|---|
| Google Sign-In (after step 3), friends, groups, bills, balances, settle-up, debt simplification, offline mode + sync, dark theme, multi-currency | **Receipt photo uploads** — enable Storage in the Firebase console (Storage → Get started) and deploy `storage.rules`. **Push notifications** — deploy the Cloud Functions (needs the Blaze plan); iOS pushes additionally need an APNs key uploaded in Project settings → Cloud Messaging. Until then the app degrades gracefully: photos queue locally and upload once Storage is live, and the in-app notification inbox still records bill events once the functions run. |

`docs/POST_DEPLOY_CHECKLIST.md` lists the live checks to run through
once those deploys are in.

## Project map (30 seconds)

- `lib/` — the whole app: `screens/` (UI), `providers/` (Riverpod
  state), `data/` (offline-first repository + local SQLite + outbox),
  `services/` (Firestore, sync, notifications), `models/`, `utils/`
  (money, debt simplifier, monetization), `widgets/` (paywall, ads,
  shared loading/error UI)
- `functions/` — Cloud Functions for push notifications
  (`npm install` inside the folder if you want to run/deploy them)
- `firestore.rules`, `storage.rules`, `firestore.indexes.json` —
  backend security rules (Firestore ones already deployed)
- `test/` — unit, functional and responsive-overflow test suites
- `legacy/` — the preserved v1 local-calculator version of the app
