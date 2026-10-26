// Pure unit tests: model serialization round-trips (through the
// exact JSON encoding the local database uses), date parsing,
// money formatting, and small model helpers.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:splitwize/data/local_database.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/utils/money.dart';

void main() {
  group('dateFrom', () {
    test('accepts Timestamp, int, String, DateTime and null', () {
      final dt = DateTime(2026, 1, 2, 3, 4, 5);
      expect(dateFrom(Timestamp.fromDate(dt)), dt);
      expect(dateFrom(dt.millisecondsSinceEpoch), dt);
      expect(dateFrom(dt.toIso8601String()), dt);
      expect(dateFrom(dt), dt);
      expect(dateFrom(null), isNull);
      expect(dateFrom('not a date'), isNull);
      expect(dateFrom(3.5), isNull);
    });
  });

  group('Bill serialization round-trip (as stored in SQLite)', () {
    test('all fields survive toMap -> encode -> decode -> fromMap', () {
      final paidAt = DateTime(2026, 2, 3, 12, 30);
      final created = DateTime(2026, 2, 1, 9, 0);
      final bill = Bill(
        id: 'b1',
        title: 'Dinner & drinks',
        subtotal: 5000,
        tipPercent: 15,
        total: 5750,
        splitType: 'percentage',
        createdBy: 'me',
        createdByName: 'Me Myself',
        groupId: 'g1',
        groupName: 'Trip',
        participantIds: const ['me', 'fa'],
        splits: [
          BillSplit(
            uid: 'me',
            displayName: 'Me Myself',
            amount: 2875,
            percent: 50,
            paid: true,
            paidAt: paidAt,
          ),
          const BillSplit(uid: 'fa', displayName: 'Friend A', amount: 2875),
        ],
        createdAt: created,
        updatedAt: created,
        receiptImageUrl: 'https://example.com/r.jpg',
        currency: 'PKR',
      );
      final restored = Bill.fromMap(
          'b1',
          LocalDatabase.decode(LocalDatabase.encode(
            bill.toMap(),
          )));
      expect(restored.title, bill.title);
      expect(restored.total, 5750);
      expect(restored.currency, 'PKR');
      expect(restored.groupName, 'Trip');
      expect(restored.receiptImageUrl, 'https://example.com/r.jpg');
      expect(restored.createdAt, created);
      expect(restored.splits.length, 2);
      expect(restored.splits.first.paid, isTrue);
      expect(restored.splits.first.paidAt, paidAt);
      expect(restored.splits.first.percent, 50);
      expect(restored.fullySettled, isFalse);
      expect(restored.paidCount, 1);
      expect(restored.outstanding, 2875);
      expect(restored.myShare('fa'), 2875);
      expect(restored.myShare('nobody'), 0);
      expect(restored.splitTypeLabel, 'Percentage');
    });

    test('jsonify converts nested Timestamps inside split lists', () {
      final out = LocalDatabase.jsonify({
        'splits': [
          {'paidAt': Timestamp.fromDate(DateTime(2026, 1, 1))},
        ],
      });
      final splits = out['splits'] as List;
      expect((splits.first as Map)['paidAt'], isA<int>());
    });
  });

  group('AppUser', () {
    test('currencyCode falls back to USD and currency is omitted when unset',
        () {
      const u = AppUser(uid: 'x', displayName: 'X', email: 'X@Example.COM');
      expect(u.currencyCode, 'USD');
      expect(u.toProfileMap().containsKey('currency'), isFalse);
      // Emails are normalized at write time (friend search relies on it).
      expect(u.toProfileMap()['email'], 'x@example.com');

      final withCur = u.copyWith(currency: 'AED');
      expect(withCur.currencyCode, 'AED');
      expect(withCur.toProfileMap()['currency'], 'AED');
    });

    test('initials come from first + last name parts', () {
      expect(
        const AppUser(uid: 'x', displayName: 'Ali Haider', email: '').initials,
        'AH',
      );
      expect(
        const AppUser(uid: 'x', displayName: 'Madonna', email: '').initials,
        'M',
      );
      expect(
        const AppUser(uid: 'x', displayName: '  ', email: '').initials,
        '?',
      );
    });
  });

  group('money', () {
    test('symbols and labels resolve for known currencies', () {
      expect(currencySymbol('USD'), '\$');
      expect(currencySymbol('PKR'), '₨'); // rupee sign, per currency_picker
      expect(currencySymbol('EUR'), '€');
      expect(currencyLabel('PKR'), contains('PKR'));
    });

    test('unknown codes fall back to the code itself', () {
      expect(currencySymbol('XXX'), 'XXX');
      expect(currencyLabel('XXX'), 'XXX');
    });

    test('formatMoney renders two decimals with the symbol', () {
      expect(formatMoney(1234.5, 'USD'), contains('1,234.50'));
      expect(formatMoney(100, 'PKR'), startsWith('₨'));
      expect(formatMoney(0), contains('0.00'));
    });
  });
}
