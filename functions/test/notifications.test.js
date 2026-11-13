const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const { runInNewContext } = require('node:vm');

// Run the real trigger handlers with in-memory Firebase transports. These
// tests require no credentials and never send a notification to a device.
function harness(responses, bill = {
  createdBy: 'me', splits: [{ uid: 'friend', amount: 15, paid: false }],
}, group = { invited: ['friend'], members: ['me'] }, options = {}) {
  const updates = [];
  const inbox = [];
  const pushes = [];
  const db = {
    collection: (collection) => ({
      where: (field, operator, value) => {
        const filters = [[field, value]];
        const query = {
          where: (field, operator, value) => {
            filters.push([field, value]);
            return query;
          },
          limit: () => query,
          get: async () => ({ empty: !(options.requests || []).some((request) =>
            filters.every(([field, value]) => request[field] === value)) }),
        };
        return query;
      },
      doc: (uid) => ({
        get: async () => collection === 'bills'
          ? { exists: bill !== null, data: () => bill }
          : collection === 'groups' ? { exists: group !== null, data: () => group }
          : { exists: options.userExists !== false,
            get: () => options.tokens || ['dead-a', 'dead-b', 'valid'] },
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
    Buffer,
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

const inviteEvent = (invite) => ({ data: { data: () => invite } });

test('connection invitation names the sender and routes to incoming requests without a duplicate entry', async () => {
  const h = harness(deadResponses, null, null, { requests: [
    { fromUid: 'alice', toUid: 'friend', status: 'pending' },
  ] });
  await h.notifyFriendRequest(inviteEvent({
    type: 'friend_request', toUid: 'friend', fromUid: 'alice',
    fromName: 'Alice Khan', fromEmail: 'alice@example.com',
    title: 'Connection invitation', body: 'You have a new update.',
  }));
  assert.equal(h.pushes.length, 1);
  assert.equal(h.inbox.length, 0);
  assert.equal(h.pushes[0].notification.title, 'Connection invitation');
  assert.equal(h.pushes[0].notification.body, 'Alice Khan invited you to connect on Splitwize.');
  assert.equal(h.pushes[0].data.type, 'friend_request');
  assert.equal(h.pushes[0].data.toUid, 'friend');
  assert.equal(h.pushes[0].data.fromUid, 'alice');
  assert.equal(h.pushes[0].data.fromName, 'Alice Khan');
  assert.equal(h.pushes[0].data.fromEmail, 'alice@example.com');
  assert.equal(h.updates[0].uid, 'friend');
  assert.deepEqual(Array.from(h.updates[0].data.fcmTokens.remove), ['dead-a', 'dead-b']);
});

test('connection invitation falls back to sender email or preserves the legacy body', async () => {
  const h = harness(deadResponses);
  await h.notifyFriendRequest(inviteEvent({
    type: 'friend_request', toUid: 'friend',
    fromName: '  ', fromEmail: ' alice@example.com ',
  }));
  assert.equal(h.pushes[0].notification.body, 'alice@example.com invited you to connect on Splitwize.');
  await h.notifyFriendRequest(inviteEvent({
    type: 'friend_request', toUid: 'friend', body: 'Alice wants to connect with you on Splitwize.',
  }));
  assert.equal(h.pushes[1].notification.body, 'Alice wants to connect with you on Splitwize.');
});

test('connection invitations no longer pending do not push', async () => {
  for (const status of ['accepted', 'declined', 'cancelled', null]) {
    const h = harness(deadResponses, null, null, { requests: status ? [
      { fromUid: 'alice', toUid: 'friend', status },
    ] : [] });
    await h.notifyFriendRequest(inviteEvent({
      type: 'friend_request', toUid: 'friend', fromUid: 'alice', fromName: 'Alice',
    }));
    assert.equal(h.pushes.length, 0);
  }
});

test('invitation pushes ignore other notification types, self requests, and unavailable recipients', async () => {
  const h = harness(deadResponses);
  for (const type of ['bill_created', 'bill_paid', 'group_invite', 'reminder']) {
    await h.notifyFriendRequest(inviteEvent({ type, toUid: 'friend', body: 'Update' }));
  }
  await h.notifyFriendRequest(inviteEvent({ type: 'friend_request', toUid: 'friend', fromUid: 'friend' }));
  assert.equal(h.pushes.length, 0);
  for (const options of [{ userExists: false }, { tokens: [] }]) {
    const unavailable = harness(deadResponses, null, null, options);
    await unavailable.notifyFriendRequest(inviteEvent({ type: 'friend_request', toUid: 'friend', body: 'Alice invited you.' }));
    assert.equal(unavailable.pushes.length, 0);
  }
});

test('group invitation push includes the route to the pending incoming invitation', async () => {
  const h = harness(deadResponses);
  await h.notifyGroupInvitation({ data: { data: () => ({ type: 'group_invite',
    groupId: 'g1', toUid: 'friend', title: 'Group invitation', body: 'Me invited you to Weekend',
  }) } });
  assert.equal(h.pushes.length, 1);
  assert.equal(h.pushes[0].data.type, 'group_invite');
  assert.equal(h.pushes[0].data.groupId, 'g1');
  assert.equal(h.pushes[0].data.toUid, 'friend');
  assert.equal(h.inbox.length, 0);
});

test('group invitation names the actual inviting member and group in the push', async () => {
  const h = harness(deadResponses, null, {
    name: 'Weekend Trip', createdBy: 'owner', members: ['owner', 'alice'], invited: ['friend'],
    invitations: { friend: { from: { uid: 'alice', displayName: 'Alice Khan', email: 'alice@example.com' } } },
  });
  await h.notifyGroupInvitation(inviteEvent({
    type: 'group_invite', groupId: 'g1', toUid: 'friend',
    fromUid: 'alice', fromName: 'Outdated name', body: 'You have an update.',
  }));
  assert.equal(h.pushes.length, 1);
  assert.equal(h.pushes[0].notification.body, 'Alice Khan invited you to join "Weekend Trip".');
  assert.equal(h.pushes[0].data.fromUid, 'alice');
  assert.equal(h.pushes[0].data.fromName, 'Alice Khan');
  assert.equal(h.pushes[0].data.fromEmail, 'alice@example.com');
  assert.equal(h.pushes[0].data.groupName, 'Weekend Trip');
  assert.equal(h.inbox.length, 0);
});

test('group invitation uses supplied metadata and preserves a readable legacy message', async () => {
  const h = harness(deadResponses);
  await h.notifyGroupInvitation(inviteEvent({
    type: 'group_invite', groupId: 'g1', toUid: 'friend',
    fromName: ' ', fromEmail: 'alice@example.com', groupName: 'Housemates',
  }));
  assert.equal(h.pushes[0].notification.body, 'alice@example.com invited you to join "Housemates".');
  await h.notifyGroupInvitation(inviteEvent({
    type: 'group_invite', groupId: 'g1', toUid: 'friend', body: 'Alice invited you to join "Housemates".',
  }));
  assert.equal(h.pushes[1].notification.body, 'Alice invited you to join "Housemates".');
});

test('a canonical inviter email takes precedence over a stale notification name', async () => {
  const h = harness(deadResponses, null, {
    name: 'Housemates', members: ['owner', 'alice'], invited: ['friend'],
    invitations: { friend: { from: { uid: 'alice', displayName: ' ', email: 'alice@example.com' } } },
  });
  await h.notifyGroupInvitation(inviteEvent({
    type: 'group_invite', groupId: 'g1', toUid: 'friend',
    fromUid: 'owner', fromName: 'Group Owner', fromEmail: 'owner@example.com',
  }));
  assert.equal(h.pushes[0].notification.body, 'alice@example.com invited you to join "Housemates".');
  assert.equal(h.pushes[0].data.fromUid, 'alice');
  assert.equal(h.pushes[0].data.fromName, undefined);
  assert.equal(h.pushes[0].data.fromEmail, 'alice@example.com');
});

test('invitation previews and metadata stay bounded for long Unicode names', async () => {
  const h = harness(deadResponses);
  const fromName = '\u{1F469}\u{1F3FD}'.repeat(1000);
  const invite = { type: 'group_invite', groupId: 'g1', toUid: 'friend',
    fromName, fromEmail: 'a'.repeat(1000), groupName: '\u{1F3E0}'.repeat(1000), title: '\u{1F4E8}'.repeat(1000) };
  await h.notifyGroupInvitation(inviteEvent(invite));
  const push = h.pushes[0];
  assert.ok(Buffer.byteLength(push.notification.title, 'utf8') <= 160);
  assert.ok(Buffer.byteLength(push.notification.body, 'utf8') <= 1024);
  assert.ok(Buffer.byteLength(push.data.fromName, 'utf8') <= 256);
  assert.ok(Buffer.byteLength(push.data.fromEmail, 'utf8') <= 320);
  assert.ok(Buffer.byteLength(push.data.groupName, 'utf8') <= 256);
  assert.ok(!JSON.stringify(push).includes('\uFFFD'));
  assert.equal(invite.fromName, fromName);
});

test('accepted, cancelled, deleted and missing group invitations do not push', async () => {
  for (const group of [null, { deleted: true }, { invited: [], members: ['me'] },
      { invited: ['friend'], members: ['me', 'friend'] }]) {
    const h = harness(deadResponses, null, group);
    await h.notifyGroupInvitation({ data: { data: () => ({ type: 'group_invite',
      groupId: 'g1', toUid: 'friend' }) } });
    assert.equal(h.pushes.length, 0);
  }
});

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

test('reminder inbox entry pushes to its recipient without creating a second entry', async () => {
  const h = harness(deadResponses);
  await h.notifyPaymentReminder({ data: { data: () => ({
    toUid: 'friend', type: 'reminder', billId: 'b1',
    title: 'Payment reminder', body: 'Lunch: USD 15.00 still owed.',
  }) } });
  assert.equal(h.inbox.length, 0);
  assert.equal(h.pushes.length, 1);
  assert.equal(h.pushes[0].notification.body, 'Lunch: USD 15.00 still owed.');
  assert.equal(h.pushes[0].data.type, 'reminder');
  assert.equal(h.pushes[0].data.billId, 'b1');
  assert.equal(h.updates[0].uid, 'friend');
});

test('combined reminder push is bounded without changing the full inbox body', async () => {
  const h = harness(deadResponses);
  const body = 'Dinner \u{1F35C} PKR 100.00\n'.repeat(1000);
  const reminder = { toUid: 'friend', type: 'reminder',
    title: 'Reminder '.repeat(100), body };
  await h.notifyPaymentReminder({ data: { data: () => reminder } });
  assert.equal(h.pushes.length, 1);
  assert.ok(Buffer.byteLength(h.pushes[0].notification.body, 'utf8') <= 1024);
  assert.ok(Buffer.byteLength(h.pushes[0].notification.title, 'utf8') <= 160);
  assert.ok(!h.pushes[0].notification.body.includes('\uFFFD'));
  assert.equal(reminder.body, body);
  assert.equal(h.pushes[0].data.billId, undefined);
});

test('other inbox notification types do not send duplicate pushes', async () => {
  const h = harness(deadResponses);
  for (const type of ['bill_created', 'bill_paid', 'friend_request', 'group_invite']) {
    await h.notifyPaymentReminder({ data: { data: () => ({ toUid: 'friend', type }) } });
  }
  assert.equal(h.pushes.length, 0);
});

test('bill reminder push skips people paid by another user before delivery', async () => {
  const bills = [
    null,
    { deleted: true },
    { createdBy: 'me', splits: [{ uid: 'friend', amount: 15, paid: true }] },
    { createdBy: 'me', splits: [{ uid: 'friend', amount: 15, paidAmount: 15 }] },
    { merchantPayments: { me: 30 }, paymentDebts: [{ debtorUid: 'friend',
      creditorUid: 'me', amount: 15, settledAmount: 15 }] },
  ];
  for (const bill of bills) {
    const h = harness(deadResponses, bill);
    await h.notifyPaymentReminder({ data: { data: () => ({
      toUid: 'friend', type: 'reminder', billId: 'b1', title: 'Reminder', body: 'Pay',
    }) } });
    assert.equal(h.pushes.length, 0);
  }
});

test('bill reminder push still reaches partially paid people', async () => {
  const h = harness(deadResponses, { merchantPayments: { me: 30 },
    paymentDebts: [{ debtorUid: 'friend', creditorUid: 'me', amount: 15, settledAmount: 5 }] });
  await h.notifyPaymentReminder({ data: { data: () => ({
    toUid: 'friend', type: 'reminder', billId: 'b1', body: 'USD 10.00 remaining',
  }) } });
  assert.equal(h.pushes.length, 1);
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

test('new ledger settlement notifies the actual merchant creditor, not creator', async () => {
  const h = harness(deadResponses);
  const before = {
    createdBy: 'me', title: 'Hotel dinner', currency: 'PKR',
    splits: [{ uid: 'me', amount: 300 }, { uid: 'fa', amount: 300 }],
    merchantPayments: { me: 200, fa: 700 },
    paymentDebts: [{
      id: 'me|fa', debtorUid: 'me', debtorName: 'Recorder',
      creditorUid: 'fa', creditorName: 'Friend A',
      amount: 100, settledAmount: 0,
    }],
  };
  const after = {
    ...before,
    paymentDebts: [{ ...before.paymentDebts[0], settledAmount: 100 }],
  };
  const event = (a, b) => ({ params: { billId: 'b1' }, data: {
    before: { data: () => a }, after: { data: () => b },
  } });
  await h.notifyBillPaid(event(before, after));
  assert.equal(h.inbox.length, 1);
  assert.equal(h.inbox[0].toUid, 'fa');
  assert.equal(h.inbox[0].title, 'Settlement recorded');
  assert.match(h.inbox[0].body, /PKR 100\.00/);
  assert.equal(h.pushes.length, 1);
  await h.notifyBillPaid(event(after, { ...after, updatedAt: 123 }));
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
