const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const { runInNewContext } = require('node:vm');

// Run the real trigger handlers with in-memory Firebase transports. These
// tests require no credentials and never send a notification to a device.
function harness(responses) {
  const updates = [];
  const inbox = [];
  const pushes = [];
  const db = {
    collection: (collection) => ({
      doc: (uid) => ({
        get: async () => ({ exists: true, get: () => ['dead-a', 'dead-b', 'valid'] }),
        update: async (data) => updates.push({ uid, data }),
        collection,
        uid,
      }),
    }),
    batch: () => ({
      set: (ref, data) => inbox.push(data),
      commit: async () => {},
    }),
  };
  const firestore = () => db;
  firestore.FieldValue = {
    serverTimestamp: () => 'server-timestamp',
    arrayRemove: (...values) => ({ remove: values }),
  };
  const admin = {
    initializeApp: () => {},
    firestore,
    messaging: () => ({
      sendEachForMulticast: async (message) => {
        pushes.push(message);
        return { responses, successCount: responses.filter((r) => r.success).length };
      },
    }),
  };
  const exports = {};
  runInNewContext(readFileSync(join(__dirname, '..', 'index.js'), 'utf8'), {
    exports,
    console: { log() {}, error() {} },
    require: (name) => {
      if (name === 'firebase-admin') return admin;
      if (name === 'firebase-functions/v2/firestore') return {
        onDocumentCreated: (_, handler) => handler,
        onDocumentUpdated: (_, handler) => handler,
      };
      throw new Error(`Unexpected dependency: ${name}`);
    },
  });
  return { ...exports, updates, inbox, pushes };
}

const deadResponses = [
  { success: false, error: { code: 'messaging/registration-token-not-registered' } },
  { success: false, error: { code: 'messaging/invalid-registration-token' } },
  { success: true },
];

test('bill created notifies each other participant once and removes individual dead tokens', async () => {
  const h = harness(deadResponses);
  await h.notifyBillCreated({ params: { billId: 'b1' }, data: { data: () => ({
    title: 'Lunch', total: 30, currency: 'USD', createdBy: 'me', createdByName: 'Me',
    participantIds: ['me', 'friend', 'friend'], splits: [{ uid: 'friend', amount: 15 }],
  }) } });
  assert.equal(h.inbox.length, 1);
  assert.equal(h.inbox[0].toUid, 'friend');
  assert.equal(h.pushes.length, 1);
  assert.match(h.pushes[0].notification.body, /USD 15\.00/);
  assert.equal(h.updates[0].uid, 'friend');
  assert.deepEqual(Array.from(h.updates[0].data.fcmTokens.remove), ['dead-a', 'dead-b']);
});

test('transient push failures do not remove registered tokens', async () => {
  const h = harness([
    { success: false, error: { code: 'messaging/server-unavailable' } },
    { success: true }, { success: true },
  ]);
  await h.notifyBillCreated({ params: { billId: 'b1' }, data: { data: () => ({
    createdBy: 'me', participantIds: ['friend'], splits: [],
  }) } });
  assert.equal(h.updates.length, 0);
  assert.equal(h.inbox.length, 1);
});

test('only a newly paid share notifies the creator; unrelated updates stay silent', async () => {
  const h = harness(deadResponses);
  const before = { createdBy: 'me', title: 'Lunch', splits: [{ uid: 'friend', paid: false, amount: 15 }] };
  const after = { ...before, splits: [{ uid: 'friend', paid: true, amount: 15 }] };
  const event = (a, b) => ({ params: { billId: 'b1' }, data: {
    before: { data: () => a }, after: { data: () => b },
  } });
  await h.notifyBillPaid(event(before, after));
  assert.equal(h.inbox.length, 1);
  assert.equal(h.inbox[0].toUid, 'me');
  assert.deepEqual(Array.from(h.updates[0].data.fcmTokens.remove), ['dead-a', 'dead-b']);
  await h.notifyBillPaid(event(after, { ...after, updatedAt: 123 }));
  assert.equal(h.inbox.length, 1);
  assert.equal(h.pushes.length, 1);
});
