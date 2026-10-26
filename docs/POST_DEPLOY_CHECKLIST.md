# Post-deploy verification checklist

Run these after deploying to your live Firebase project. Each item proves one of
the risks the 2026-10-20 full-app review found and fixed — the analyzer and the
158 local tests cannot see these, only a real project can.

## Deploy commands (reference)

```bash
firebase use --add                     # pick the bill-splitter project
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only storage
firebase deploy --only functions       # needs the Blaze (pay-as-you-go) plan
```

## Checklist

1. **Google sign-in works**
   Sign in on the app → a `users/{uid}` profile document appears in Firestore.
   Sign out → the local on-device database is wiped (offline-first behavior).

2. **Friend accept writes both mirrors**
   Send a friend request from account A, accept it on account B →
   `users/{A}/connections` **and** `users/{B}/connections` both contain the mirror.
   (Proves the connection-mirror rule fix — the accept batch writes both sides.)

3. **Bill creation triggers a push + inbox entry**
   A creates a bill split with B → B gets the FCM push notification **and**
   the in-app notification inbox entry.
   (Proves the Cloud Function trigger and the FCM token path end to end.
   Needs the functions deployed — Blaze plan.)

4. **A participant can mark their share paid** *(single most important check)*
   B marks their own share paid → no permission-denied error, B's outbox clears,
   and A sees the share as paid.
   (Proves the bills-rule fix for participant updates with core fields pinned,
   and the `paidAt` timestamp fix. Before the fix, every settle-up wedged the
   outbox.)

5. **Receipt photo round-trip**
   Create a bill with a receipt photo → the object `receipts/{billId}.jpg`
   exists in Storage and the bill shows the photo on B's device.
   (Proves `storage.rules` plus the reordered receipt push.)

6. **Default currency syncs cross-device**
   Set a default currency on device 1 → it appears on device 2 after sync.
   (Proves the `initSync` profile-fetch path on a fresh local cache.)

7. **Offline bill creation drains FIFO**
   Go offline, create a bill, come back online → the outbox drains in FIFO
   order with no stuck ops.
   (Proves the sync plumbing against real Firestore.)

## Known minor items left as-is (not failures)

- Percentage-split shares can drift ~1 cent from the total
  (equal split distributes cents exactly).
- The creator also gets a "share paid" inbox entry when they mark a share paid
  themselves.
- Receipt photos are readable by any signed-in user, not just participants.
