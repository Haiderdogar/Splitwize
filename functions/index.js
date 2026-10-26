/**
 * Splitwize — Cloud Functions.
 *
 * notifyBillCreated: when a bill is created, every participant except the
 *   creator gets a push notification AND an in-app inbox entry.
 * notifyBillPaid: when a participant's share flips to paid, the bill creator
 *   gets a push notification AND an inbox entry.
 *
 * Deploy with:
 *   cd functions && npm install && cd ..
 *   firebase deploy --only functions
 */

const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

const money = (n, code) => (code ? code + ' ' : '') + Number(n || 0).toFixed(2);

async function pruneBadTokens(db, uid, tokens, responses) {
  const bad = [];
  responses.forEach((resp, i) => {
    if (!resp.success) {
      const code = resp.error && resp.error.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        bad.push(tokens[i]);
      }
    }
  });
  if (bad.length > 0) {
    await db
      .collection("users")
      .doc(uid)
      .update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(bad) });
  }
}

exports.notifyBillCreated = onDocumentCreated(
  "bills/{billId}",
  async (event) => {
    const bill = event.data && event.data.data();
    if (!bill) return;

    const billId = event.params.billId;
    const db = admin.firestore();
    const participantIds = [...new Set(bill.participantIds || [])].filter(
      (id) => id !== bill.createdBy
    );
    if (participantIds.length === 0) return;

    const title = `New bill: ${bill.title || "Split"}`;
    const cur = bill.currency || 'USD';
    const total = money(bill.total, cur);

    // Load each recipient once.
    const recipients = [];
    for (const uid of participantIds) {
      try {
        const snap = await db.collection("users").doc(uid).get();
        if (!snap.exists) continue;
        const split = (bill.splits || []).find((s) => s.uid === uid);
        recipients.push({
          uid,
          tokens: snap.get("fcmTokens") || [],
          share: split ? split.amount : 0,
        });
      } catch (e) {
        console.error(`Failed to load user ${uid}`, e);
      }
    }
    if (recipients.length === 0) return;

    // In-app inbox entries (one batch).
    const batch = db.batch();
    for (const r of recipients) {
      const ref = db.collection("notifications").doc();
      batch.set(ref, {
        toUid: r.uid,
        title,
        body: `${bill.createdByName || "A friend"} split ${total} — your share: ${money(r.share, cur)}`,
        type: "bill_created",
        billId: String(billId),
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    // Push notifications.
    for (const r of recipients) {
      if (r.tokens.length === 0) continue;
      try {
        const res = await admin.messaging().sendEachForMulticast({
          tokens: r.tokens,
          notification: {
            title,
            body: `${bill.createdByName || "A friend"} split ${total} — your share: ${money(r.share, cur)}`,
          },
          data: { type: "bill_created", billId: String(billId) },
        });
        console.log(
          `Bill ${billId}: notified ${r.uid} — ${res.successCount} ok`
        );
        await pruneBadTokens(db, r.uid, r.tokens, res.responses);
      } catch (e) {
        console.error(`FCM send failed for ${r.uid}`, e);
      }
    }
  }
);

exports.notifyBillPaid = onDocumentUpdated(
  "bills/{billId}",
  async (event) => {
    const before = event.data && event.data.before.data();
    const after = event.data && event.data.after.data();
    if (!before || !after) return;

    const billId = event.params.billId;
    const beforeSplits = before.splits || [];
    const afterSplits = after.splits || [];
    const newlyPaid = afterSplits.filter((a) => {
      if (!a.paid) return false;
      const b = beforeSplits.find((x) => x.uid === a.uid);
      return !b || !b.paid;
    });
    if (newlyPaid.length === 0) return;

    const db = admin.firestore();
    const creatorId = after.createdBy;
    let creatorTokens = [];
    try {
      const snap = await db.collection("users").doc(creatorId).get();
      if (snap.exists) creatorTokens = snap.get("fcmTokens") || [];
    } catch (e) {
      console.error(`Failed to load creator ${creatorId}`, e);
    }

    // Inbox entries for the creator.
    const batch = db.batch();
    for (const s of newlyPaid) {
      const ref = db.collection("notifications").doc();
      batch.set(ref, {
        toUid: creatorId,
        title: "Share marked as paid",
        body: `${s.displayName || "Someone"} marked their ${money(s.amount, after.currency || 'USD')} share of "${after.title || "a bill"}" as paid.`,
        type: "bill_paid",
        billId: String(billId),
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    // Push to the creator.
    if (creatorTokens.length === 0) return;
    const names = newlyPaid.map((s) => s.displayName || "Someone").join(", ");
    try {
      const res = await admin.messaging().sendEachForMulticast({
        tokens: creatorTokens,
        notification: {
          title: "Share marked as paid",
          body:
            newlyPaid.length === 1
              ? `${names} marked their ${money(newlyPaid[0].amount, after.currency || 'USD')} share of "${after.title || "a bill"}" as paid.`
              : `${newlyPaid.length} shares of "${after.title || "a bill"}" were marked as paid.`,
        },
        data: { type: "bill_paid", billId: String(billId) },
      });
      await pruneBadTokens(db, creatorId, creatorTokens, res.responses);
    } catch (e) {
      console.error(`FCM send failed for creator ${creatorId}`, e);
    }
  }
);
