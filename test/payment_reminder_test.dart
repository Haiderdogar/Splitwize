import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/data/app_repository.dart';
import 'package:splitwize/data/local_database.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/services/firestore_service.dart';
import 'package:splitwize/services/secure_storage_service.dart';
import 'package:splitwize/utils/payment_reminder.dart';

import 'test_harness.dart';

Bill legacy(String id,
        {String creator = 'payment-reminder-me',
        String currency = 'USD',
        bool paid = false,
        double paidAmount = 0}) =>
    Bill.fromMap(id, {
      'title': 'Dinner $id',
      'createdBy': creator,
      'createdByName': creator,
      'participantIds': ['payment-reminder-me', 'fa'],
      'total': 100,
      'subtotal': 100,
      'groupName': 'Weekend',
      'createdAt': DateTime(2026, 11, 11),
      'currency': currency,
      'splits': [
        {
          'uid': 'payment-reminder-me',
          'displayName': 'Me',
          'amount': 60,
          'paid': true
        },
        {
          'uid': 'fa',
          'displayName': 'Friend A',
          'amount': 40,
          'paid': paid,
          'paidAmount': paidAmount
        },
      ],
    });

Bill ledger({String creditor = 'payment-reminder-me', double settled = 10}) =>
    Bill.fromMap('ledger', {
      'title': 'Hotel',
      'createdBy': 'other',
      'participantIds': ['payment-reminder-me', 'fa', 'other'],
      'total': 150,
      'currency': 'PKR',
      'merchantPayments': {creditor: 150},
      'splits': [
        {'uid': 'fa', 'displayName': 'Friend A', 'amount': 50}
      ],
      'paymentDebts': [
        {
          'id': 'fa|$creditor',
          'debtorUid': 'fa',
          'debtorName': 'Friend A',
          'creditorUid': creditor,
          'creditorName': creditor,
          'amount': 50,
          'settledAmount': settled,
        }
      ],
    });

Bill multiPayerBill() => Bill.fromMap('multi', {
      'title': 'Group dinner',
      'createdBy': 'payment-reminder-me',
      'createdByName': 'Me Myself',
      'currency': 'USD',
      'total': 200,
      'participantIds': ['payment-reminder-me', 'fa', 'fb', 'fc'],
      'merchantPayments': {'payment-reminder-me': 100, 'fb': 100},
      'splits': [
        {'uid': 'fa', 'amount': 80},
        {'uid': 'fb', 'amount': 50},
        {'uid': 'fc', 'amount': 70},
      ],
      'paymentDebts': [
        {
          'id': 'a-me',
          'debtorUid': 'fa',
          'creditorUid': 'payment-reminder-me',
          'creditorName': 'Me Myself',
          'amount': 50,
          'settledAmount': 15
        },
        {
          'id': 'a-b',
          'debtorUid': 'fa',
          'creditorUid': 'fb',
          'creditorName': 'Friend B',
          'amount': 20,
          'settledAmount': 0
        },
        {
          'id': 'b-me',
          'debtorUid': 'fb',
          'creditorUid': 'payment-reminder-me',
          'creditorName': 'Me Myself',
          'amount': 50,
          'settledAmount': 50
        },
        {
          'id': 'c-b',
          'debtorUid': 'fc',
          'creditorUid': 'fb',
          'creditorName': 'Friend B',
          'amount': 30,
          'settledAmount': 0
        },
      ],
    });

void main() {
  setUpAll(initTestEnv);

  test('reminders use actual creditor and remaining debt, not whole bill total',
      () {
    final entries = paymentReminders([
      legacy('partial', paidAmount: 15),
      legacy('paid', paid: true),
      legacy('not-mine', creator: 'fa'),
      ledger(),
    ], 'payment-reminder-me', 'fa');
    expect(
        entries.map((entry) => entry.bill.id).toSet(), {'partial', 'ledger'});
    final partial = entries.firstWhere((entry) => entry.bill.id == 'partial');
    expect(partial.originalAmount, 40);
    expect(partial.remainingAmount, 25);
    expect(
        entries
            .firstWhere((entry) => entry.bill.id == 'ledger')
            .remainingAmount,
        40);
    expect(
        paymentReminders(
            [ledger(creditor: 'other')], 'payment-reminder-me', 'fa'),
        isEmpty);
    expect(paymentReminders([ledger(settled: 50)], 'payment-reminder-me', 'fa'),
        isEmpty);
    expect(
        paymentReminders(
            [legacy('x')], 'payment-reminder-me', 'payment-reminder-me'),
        isEmpty);
  });

  test('combined body keeps bill details and separate currency totals', () {
    final body = paymentReminderBody(
        paymentReminders([
          legacy('partial', paidAmount: 15),
          legacy('second'),
          legacy('rupees', currency: 'PKR'),
        ], 'payment-reminder-me', 'fa'),
        'Me Myself');
    expect(body, contains('3 unsettled bills'));
    expect(body, contains('PKR 40.00; USD 65.00'));
    expect(body, contains('Dinner partial'));
    expect(body, contains('Date: Nov 11, 2026'));
    expect(body, contains('Group: Weekend'));
    expect(body, contains('Bill total: USD 100.00'));
    expect(body, contains('Your share: USD 40.00'));
    expect(body, contains('Already repaid to Me Myself: USD 15.00'));
    expect(body, contains('Still owed to Me Myself: USD 25.00'));
    expect(body, contains('Bill ID: rupees'));
  });

  test('bill recipients skip paid people and combine debts to multiple payers',
      () {
    final bill = multiPayerBill();
    final targets = billReminderDebts(bill, 'payment-reminder-me');
    expect(targets.keys.toSet(), {'fa', 'fc'});
    expect(targets['fa']!.length, 2);
    expect(targets.containsKey('fb'), isFalse,
        reason:
            'The payment ledger is settled even if the share has no paid flag');
    expect(billReminderDebts(bill, 'fa'), isEmpty);
    final payerTargets = billReminderDebts(bill, 'fb');
    expect(payerTargets.keys.toSet(), {'fa', 'fc'});
    expect(payerTargets['fa']!.single.creditorUid, 'fb');
    final body = billReminderBody(bill, targets['fa']!, 'Me Myself');
    expect(body, contains('Remaining to repay: USD 55.00'));
    expect(body, contains('Still owed to Me Myself: USD 35.00'));
    expect(body, contains('Still owed to Friend B: USD 20.00'));
    expect(body, contains('Already repaid to Me Myself: USD 15.00'));
  });

  test(
      'delivery guard respects paid flags, partial amounts and ledger settlements',
      () {
    expect(hasUnpaidBillDebt(legacy('paid', paid: true), 'fa'), isFalse);
    expect(hasUnpaidBillDebt(legacy('partial', paidAmount: 15), 'fa'), isTrue);
    expect(hasUnpaidBillDebt(legacy('paid', paidAmount: 40), 'fa'), isFalse);
    expect(hasUnpaidBillDebt(legacy('owner'), 'payment-reminder-me'), isFalse);
    expect(hasUnpaidBillDebt(multiPayerBill(), 'fb'), isFalse);
    expect(hasUnpaidBillDebt(multiPayerBill(), 'fa'), isTrue);
  });

  group('queued reminders', () {
    late LocalDatabase db;
    late AppRepository repo;
    setUp(() async {
      await LocalDatabase.deleteForUid('payment-reminder-me');
      db = await LocalDatabase.open('payment-reminder-me');
      repo = AppRepository(
          db: db,
          remote: FirestoreService(),
          secure: SecureStorageService(),
          myUid: 'payment-reminder-me');
      await db.upsertUser('payment-reminder-me', meUser.toProfileMap());
      await repo.applyRemoteBill(legacy('partial', paidAmount: 15));
      await repo.applyRemoteBill(legacy('paid', paid: true));
      await repo.applyRemoteBill(legacy('not-mine', creator: 'fa'));
      await repo.applyRemoteBill(ledger());
    });
    tearDown(() async {
      repo.dispose();
      await LocalDatabase.deleteForUid('payment-reminder-me');
    });

    test('Remind all queues one notification with every eligible bill',
        () async {
      var syncs = 0;
      repo.requestSync = () => syncs++;
      expect(await repo.sendPaymentReminder(personUid: 'fa'), 2);
      final outbox = await db.peekOutbox();
      expect(outbox.length, 1);
      expect(outbox.single['type'], 'notify');
      final payload = outbox.single['payload'] as Map;
      expect(payload['toUid'], 'fa');
      expect(payload['type'], 'reminder');
      expect(payload['billId'], isNull);
      expect(payload['body'], contains('Dinner partial'));
      expect(payload['body'], contains('Hotel'));
      expect(payload['body'], isNot(contains('Dinner paid')));
      expect(payload['body'], isNot(contains('Dinner not-mine')));
      expect(syncs, 1);
    });

    test('single reminder includes only selected bill and its destination',
        () async {
      expect(await repo.sendPaymentReminder(personUid: 'fa', billId: 'partial'),
          1);
      final payload = (await db.peekOutbox()).single['payload'] as Map;
      expect(payload['billId'], 'partial');
      expect(payload['body'], contains('Still owed to Me Myself: USD 25.00'));
      expect(payload['body'], isNot(contains('Hotel')));
    });

    test('rechecks settlements before queueing and skips invalid requests',
        () async {
      await repo.applyRemoteBill(legacy('partial', paid: true));
      expect(await repo.sendPaymentReminder(personUid: 'fa', billId: 'partial'),
          0);
      expect(
          await repo.sendPaymentReminder(personUid: 'fa', billId: 'not-mine'),
          0);
      expect(await repo.sendPaymentReminder(personUid: 'fa', billId: 'missing'),
          0);
      expect(
          await repo.sendPaymentReminder(personUid: 'payment-reminder-me'), 0);
      expect(await db.peekOutbox(), isEmpty);
    });

    test(
        'bill action queues one notification per unpaid person, never paid people',
        () async {
      await repo.applyRemoteBill(multiPayerBill());
      var syncs = 0;
      repo.requestSync = () => syncs++;
      expect(await repo.sendBillReminders('multi'), 2);
      final outbox = await db.peekOutbox();
      expect(outbox.length, 2);
      final payloads = outbox.map((row) => row['payload'] as Map).toList();
      expect(payloads.map((payload) => payload['toUid']).toSet(), {'fa', 'fc'});
      expect(payloads.every((payload) => payload['billId'] == 'multi'), isTrue);
      expect(
          payloads.every((payload) => payload['type'] == 'reminder'), isTrue);
      expect(payloads.firstWhere((p) => p['toUid'] == 'fa')['body'],
          contains('Remaining to repay: USD 55.00'));
      expect(syncs, 1);
    });

    test('legacy bill action uses remaining shares and skips new settlements',
        () async {
      expect(await repo.sendBillReminders('paid'), 0);
      expect(await repo.sendBillReminders('missing'), 0);
      expect(await repo.sendBillReminders('not-mine'), 0);
      await repo.applyRemoteBill(legacy('partial', paid: true));
      expect(await repo.sendBillReminders('partial'), 0);
      expect(await db.peekOutbox(), isEmpty);
      await repo.applyRemoteBill(legacy('partial', paidAmount: 15));
      expect(await repo.sendBillReminders('partial'), 1);
      final payload = (await db.peekOutbox()).single['payload'] as Map;
      expect(payload['toUid'], 'fa');
      expect(payload['body'], contains('Remaining to repay: USD 25.00'));
    });
  });
}
