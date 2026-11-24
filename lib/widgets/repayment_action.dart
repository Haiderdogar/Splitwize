import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../utils/money.dart';

/// Asks for confirmation, then marks everything I owe this person in the
/// balance's currency as paid. No money moves through Splitwize.
Future<void> recordRepayment(
    BuildContext context, WidgetRef ref, FriendBalance b) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Record repayment?'),
      content: Text(
        'You owe ${b.displayName} ${formatMoney(b.iOweThem, b.currency)}. '
        'They owe you ${formatMoney(b.owesMe, b.currency)}. '
        'The net balance is ${formatMoney(b.net.abs(), b.currency)}.\n\n'
        'This will mark your full ${formatMoney(b.iOweThem, b.currency)} '
        'outstanding debt to this person as paid, not just the net amount. '
        'No money is transferred by Splitwize.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Mark my debt paid'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    final repo = await ref.read(appRepositoryProvider.future);
    final count = await repo.settleUpWithFriend(b.uid, currency: b.currency);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Settled $count share${count == 1 ? '' : 's'} with ${b.displayName}.')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not settle up: $e')),
      );
    }
  }
}
