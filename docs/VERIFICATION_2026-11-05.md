# Code review and verification — 2026-11-05

## Fixes

- Bill totals and splits use consistent whole cents. Percentage splits
  distribute rounding remainders; custom splits must allocate the exact total.
- Non-finite numbers and amounts that cannot be represented accurately in
  cents are rejected. Split previews tolerate invalid and very large inputs.
- Bill submission locks before asynchronous work starts, preventing duplicate
  bills from overlapping saves, and saves one consistent form snapshot.
- Sync drains all outbox batches before pulling remote state, preserves failed
  operation order, and lets concurrent callers await the active sync.
- Disposed sync services stop before applying completed remote operations to
  a closed database. Cleared receipt fields take precedence over old queued
  receipt data.
- The whole navigation drawer scrolls, including its header and footer, on
  small screens and with large accessibility text.
- Settlement rules restrict changes to `splits` and `updatedAt` without
  dereferencing optional fields such as a deleted receipt URL. This follows
  Firebase's [field-change guidance](https://firebase.google.com/docs/firestore/security/rules-fields).
- Receipt storage rules validate metadata for uploads and handle deletes
  separately, since a delete has no incoming file metadata.
- Notification handlers remove invalid FCM tokens individually rather than
  passing an array as a single Firestore array element.
- CI tests notification handlers and requires both test jobs to succeed
  before building and publishing Android releases.

## Verification

- `flutter analyze --no-pub`: no issues.
- `flutter test --concurrency=1`: 224 tests passed, including 20 new regression
  cases. Repository tests use real SQLite; sync tests mock remote transport.
- `node --test functions/test/notifications.test.js`: 3 tests passed against
  the real handlers with mocked Firebase transports.
- `flutter build apk --debug --no-pub`: Android debug APK built successfully.
- Formatting checked on edited Dart files; `git diff --check` passed.

## Remaining live checks

No GitHub push or Firebase deployment was performed. Deploy the changed
Firestore rules, Storage rules, and Cloud Functions through the project's
normal deployment process before testing their live behavior.

Firebase rules were reviewed against the client writes and Firebase guidance;
they were not run in a rules emulator. Google sign-in, receipt uploads and
deletes, cross-device settlement sync, FCM delivery, and store checkout still
need testing with the configured Firebase project and store accounts. iOS
builds and physical-device behavior were not verified in this Windows session.

The existing local plugin registration and lockfile changes were preserved.
