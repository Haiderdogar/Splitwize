import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../utils/payment_reminder.dart';

class BillReminderAction extends ConsumerStatefulWidget {
  const BillReminderAction({super.key, required this.billId});
  final String billId;

  @override
  ConsumerState<BillReminderAction> createState() => _BillReminderActionState();
}

class _BillReminderActionState extends ConsumerState<BillReminderAction> {
  bool _sending = false;

  Future<void> _remind() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final repo = await ref.read(appRepositoryProvider.future);
      final count = await repo.sendBillReminders(widget.billId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(count == 0
            ? 'No unpaid people to remind on this bill.'
            : 'Reminders queued for $count unpaid '
                '${count == 1 ? 'person' : 'people'}.'),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not queue reminders. Please try again.'),
      ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final billAsync = ref.watch(billProvider(widget.billId));
    final bill = billAsync.value;
    final uid = ref.watch(currentUidProvider) ?? '';
    if (billAsync.isLoading ||
        billAsync.hasError ||
        bill == null ||
        billReminderDebts(bill, uid).isEmpty) {
      return const SizedBox.shrink();
    }
    return TextButton(
      onPressed: _sending ? null : _remind,
      child: Text(_sending ? 'Sending...' : 'Remind'),
    );
  }
}
