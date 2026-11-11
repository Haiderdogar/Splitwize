import 'package:intl/intl.dart';

import '../models/models.dart';
import 'money.dart';
import 'person_bills.dart';

class BillReminder {
  const BillReminder({
    required this.bill,
    required this.personUid,
    required this.originalAmount,
    required this.remainingAmount,
  });

  final Bill bill;
  final String personUid;
  final double originalAmount;
  final double remainingAmount;
}

/// A recorder can remind all unpaid people; other creditors can remind people
/// who owe them. Paid debts and the sender are never recipients.
Map<String, List<BillDebt>> billReminderDebts(Bill bill, String senderUid) {
  if (bill.deleted || bill.fullySettled || senderUid.isEmpty) return {};
  final debts = bill.hasPaymentLedger
      ? bill.paymentDebts
      : [
          for (final split in bill.splits)
            BillDebt(
                id: '${split.uid}|${bill.createdBy}',
                debtorUid: split.uid,
                debtorName: split.displayName,
                creditorUid: bill.createdBy,
                creditorName: bill.createdByName,
                amount: split.amount,
                settledAmount: split.settledAmount),
        ];
  final targets = <String, List<BillDebt>>{};
  for (final debt in debts) {
    if (debt.isSettled ||
        debt.debtorUid.isEmpty ||
        debt.debtorUid == senderUid ||
        debt.debtorUid == debt.creditorUid) {
      continue;
    }
    if (bill.createdBy != senderUid && debt.creditorUid != senderUid) continue;
    (targets[debt.debtorUid] ??= []).add(debt);
  }
  return targets;
}

/// Rechecked against the server bill before creating a queued reminder's inbox
/// entry, so a payment recorded on another device while offline is respected.
bool hasUnpaidBillDebt(Bill bill, String personUid) {
  if (bill.deleted || personUid.isEmpty) return false;
  if (bill.hasPaymentLedger) {
    return bill.paymentDebts.any((debt) =>
        debt.debtorUid == personUid &&
        debt.creditorUid != personUid &&
        !debt.isSettled);
  }
  return bill.createdBy != personUid &&
      bill.splits.any((split) => split.uid == personUid && !split.isFullyPaid);
}

String billReminderBody(Bill bill, List<BillDebt> debts, String senderName) {
  String money(double amount) =>
      '${bill.currency} ${formatMoneyNumber(amount, bill.currency)}';
  final remaining = debts.fold(0.0, (sum, debt) => sum + debt.remainingAmount);
  final body = StringBuffer('$senderName reminds you about "${bill.title}".\n');
  if (bill.createdAt != null) {
    body.writeln('Date: ${DateFormat.yMMMd().format(bill.createdAt!)}');
  }
  body.writeln('Group: ${bill.groupName ?? 'Personal expense'}');
  body.writeln('Bill total: ${money(bill.total)}');
  body.writeln('Your share: ${money(bill.myShare(debts.first.debtorUid))}');
  body.writeln('Remaining to repay: ${money(remaining)}');
  for (final debt in debts) {
    final creditor =
        debt.creditorName.trim().isEmpty ? 'the payer' : debt.creditorName;
    body.writeln('\nOriginally owed to $creditor: ${money(debt.amount)}');
    body.writeln(
        'Already repaid to $creditor: ${money(debt.amount - debt.remainingAmount)}');
    body.writeln('Still owed to $creditor: ${money(debt.remainingAmount)}');
  }
  body.write('Bill ID: ${bill.id}');
  return body.toString();
}

/// Only debts from this person to the sender can be requested for payment.
/// Legacy bills owe the recorder; payment-ledger bills name the creditor.
List<BillReminder> paymentReminders(
    List<Bill> bills, String senderUid, String personUid) {
  final reminders = <BillReminder>[];
  for (final bill in billsWithPerson(bills, senderUid, personUid)) {
    if (bill.fullySettled) continue;
    double original = 0;
    double remaining = 0;
    if (bill.hasPaymentLedger) {
      for (final debt in bill.paymentDebts) {
        if (debt.debtorUid == personUid && debt.creditorUid == senderUid) {
          original += debt.amount;
          remaining += debt.remainingAmount;
        }
      }
    } else if (bill.createdBy == senderUid) {
      for (final split in bill.splits) {
        if (split.uid == personUid) {
          original += split.amount;
          remaining += split.remainingAmount;
        }
      }
    }
    if (remaining < 0.005) continue;
    reminders.add(BillReminder(
      bill: bill,
      personUid: personUid,
      originalAmount: (original * 100).round() / 100,
      remainingAmount: (remaining * 100).round() / 100,
    ));
  }
  return reminders;
}

/// Full detail stays in the inbox even when the device push needs shortening.
String paymentReminderBody(List<BillReminder> reminders, String senderName) {
  String money(double amount, String currency) =>
      '$currency ${formatMoneyNumber(amount, currency)}';
  final totals = <String, double>{};
  for (final entry in reminders) {
    totals.update(entry.bill.currency, (value) => value + entry.remainingAmount,
        ifAbsent: () => entry.remainingAmount);
  }
  final currencies = totals.keys.toList()..sort();
  final body = StringBuffer(
    '$senderName reminds you about ${reminders.length} unsettled '
    '${reminders.length == 1 ? 'bill' : 'bills'}.\n'
    'Total owed to $senderName: '
    '${currencies.map((code) => money(totals[code]!, code)).join('; ')}.\n',
  );
  for (var index = 0; index < reminders.length; index++) {
    final entry = reminders[index];
    final bill = entry.bill;
    body.writeln('\n${index + 1}. ${bill.title}');
    if (bill.createdAt != null) {
      body.writeln('Date: ${DateFormat.yMMMd().format(bill.createdAt!)}');
    }
    body.writeln('Group: ${bill.groupName ?? 'Personal expense'}');
    body.writeln('Bill total: ${money(bill.total, bill.currency)}');
    body.writeln(
        'Your share: ${money(bill.myShare(entry.personUid), bill.currency)}');
    body.writeln('Originally owed to $senderName: '
        '${money(entry.originalAmount, bill.currency)}');
    body.writeln('Already repaid to $senderName: '
        '${money(entry.originalAmount - entry.remainingAmount, bill.currency)}');
    body.writeln('Still owed to $senderName: '
        '${money(entry.remainingAmount, bill.currency)}');
    body.writeln('Bill ID: ${bill.id}');
  }
  return body.toString().trimRight();
}
