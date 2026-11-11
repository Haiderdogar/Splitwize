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

// Keep the full breakdown in the inbox; FCM has a 4096-byte payload limit.
// https://firebase.google.com/docs/cloud-messaging
// Count UTF-8 bytes, including for names and bill titles in other languages.
function pushPreview(value, maxBytes) {
  const text = String(value || '');
  let preview = '';
  let bytes = 0;
  for (const char of text) {
    const size = Buffer.byteLength(char, 'utf8');
    if (bytes + size > maxBytes - 3) return preview + '...';
    preview += char;
    bytes += size;
  }
  return preview;
}

exports.notifyGroupInvitation = onDocumentCreated(
  'notifications/{notificationId}',
  async (event) => {
    const invite = event.data && event.data.data();
    if (!invite || invite.type !== 'group_invite' || !invite.groupId || !invite.toUid) return;
    const db = admin.firestore();
    const groupSnap = await db.collection('groups').doc(invite.groupId).get();
    if (!groupSnap.exists) return;
    const group = groupSnap.data();
    if (group.deleted || !(group.invited || []).includes(invite.toUid) ||
        (group.members || []).includes(invite.toUid)) return;
    const user = await db.collection('users').doc(invite.toUid).get();
    if (!user.exists) return;
    const tokens = [...new Set(user.get('fcmTokens') || [])];
    for (let index = 0; index < tokens.length; index += 500) {
      const chunk = tokens.slice(index, index + 500);
      const result = await admin.messaging().sendEachForMulticast({
        tokens: chunk,
        notification: { title: pushPreview(invite.title || 'Group invitation', 160),
          body: pushPreview(invite.body, 1024) },
        data: { type: 'group_invite', groupId: String(invite.groupId), toUid: String(invite.toUid) },
      });
      await pruneBadTokens(db, invite.toUid, chunk, result.responses);
    }
  }
);

exports.notifyPaymentReminder = onDocumentCreated(
  'notifications/{notificationId}',
  async (event) => {
    const reminder = event.data && event.data.data();
    if (!reminder || reminder.type !== 'reminder' || !reminder.toUid) return;
    const db = admin.firestore();
    // A payment can be recorded by another user after the reminder was queued.
    if (reminder.billId) {
      const billSnap = await db.collection('bills').doc(reminder.billId).get();
      if (!billSnap.exists) return;
      const bill = billSnap.data();
      if (bill.deleted) return;
      const unpaid = bill.merchantPayments && Object.keys(bill.merchantPayments).length
        ? (bill.paymentDebts || []).some((debt) =>
          debt.debtorUid === reminder.toUid && debt.creditorUid !== reminder.toUid &&
          Number(debt.amount || 0) - Number(debt.settledAmount || 0) >= 0.005)
        : bill.createdBy !== reminder.toUid && (bill.splits || []).some((share) =>
          share.uid === reminder.toUid && !share.paid &&
          Number(share.amount || 0) - Number(share.paidAmount || 0) >= 0.005);
      if (!unpaid) return;
    }
    const snap = await db.collection('users').doc(reminder.toUid).get();
    if (!snap.exists) return;
    const tokens = [...new Set(snap.get('fcmTokens') || [])];
    if (!tokens.length) return;
    const data = { type: 'reminder' };
    if (typeof reminder.billId === 'string' && reminder.billId.length <= 128) {
      data.billId = reminder.billId;
    }
    const notification = {
      title: pushPreview(reminder.title || 'Payment reminder', 160),
      body: pushPreview(reminder.body, 1024),
    };
    for (let start = 0; start < tokens.length; start += 500) {
      const batch = tokens.slice(start, start + 500);
      const res = await admin.messaging().sendEachForMulticast({
        tokens: batch, notification, data,
      });
      await pruneBadTokens(db, reminder.toUid, batch, res.responses);
    }
  }
);

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
      .update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...bad) });
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
    // New expenses carry an explicit debtor → creditor ledger. Who
    // recorded the bill is not necessarily who paid the restaurant.
    // A settlement must notify the actual creditor, not the creator.
    if (after.merchantPayments && Object.keys(after.merchantPayments).length) {
      const oldDebts = before.paymentDebts || [];
      const newDebts = after.paymentDebts || [];
      const changes = newDebts.map((debt) => {
        const old = oldDebts.find((d) => d.id === debt.id);
        const previous = Number((old && old.settledAmount) || 0);
        const current = Number(debt.settledAmount || 0);
        return { debt, delta: current - previous };
      }).filter(({ debt, delta }) =>
        delta > 0.005 && debt.creditorUid && debt.debtorUid);
      if (!changes.length) return;

      const db = admin.firestore();
      const batch = db.batch();
      for (const { debt, delta } of changes) {
        batch.set(db.collection("notifications").doc(), {
          toUid: debt.creditorUid,
          title: "Settlement recorded",
          body: `${debt.debtorName || "A friend"} settled ${money(delta, after.currency || 'USD')} for "${after.title || "a bill"}".`,
          type: "bill_paid",
          billId: String(billId),
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      for (const { debt, delta } of changes) {
        try {
          const snap = await db.collection("users").doc(debt.creditorUid).get();
          if (!snap.exists) continue;
          const tokens = snap.get("fcmTokens") || [];
          if (!tokens.length) continue;
          const res = await admin.messaging().sendEachForMulticast({
            tokens,
            notification: {
              title: "Settlement recorded",
              body: `${debt.debtorName || "A friend"} settled ${money(delta, after.currency || 'USD')} for "${after.title || "a bill"}".`,
            },
            data: { type: "bill_paid", billId: String(billId) },
          });
          await pruneBadTokens(db, debt.creditorUid, tokens, res.responses);
        } catch (e) {
          console.error(`Settlement FCM failed for ${debt.creditorUid}`, e);
        }
      }
      return;
    }

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
