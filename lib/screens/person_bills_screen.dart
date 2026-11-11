import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../utils/person_bills.dart';
import '../utils/payment_reminder.dart';
import '../widgets/bill_list_tile.dart';
import '../widgets/state_widgets.dart';
import '../widgets/studio_ui.dart';

enum _SettlementFilter { unsettled, settled }

class PersonBillsScreen extends ConsumerStatefulWidget {
  const PersonBillsScreen({
    super.key,
    required this.personUid,
    required this.personName,
  });

  final String personUid;
  final String personName;

  @override
  ConsumerState<PersonBillsScreen> createState() => _PersonBillsScreenState();
}

class _PersonBillsScreenState extends ConsumerState<PersonBillsScreen> {
  _SettlementFilter _filter = _SettlementFilter.unsettled;
  bool _sendingReminder = false;

  Future<void> _remind() async {
    if (_sendingReminder) return;
    setState(() => _sendingReminder = true);
    try {
      final repo = await ref.read(appRepositoryProvider.future);
      final count = await repo.sendPaymentReminder(personUid: widget.personUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(count == 0
            ? 'No outstanding amount owed to you for these bills.'
            : 'Reminder queued for ${widget.personName} '
                '($count ${count == 1 ? 'bill' : 'bills'}).'),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not queue reminder. Please try again.'),
      ));
    } finally {
      if (mounted) setState(() => _sendingReminder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider) ?? '';
    final billsAsync = ref.watch(myBillsProvider);
    final shared =
        billsWithPerson(billsAsync.value ?? const [], uid, widget.personUid);
    final showSettled = _filter == _SettlementFilter.settled;
    final canRemind =
        paymentReminders(shared, uid, widget.personUid).isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.personName,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (!showSettled &&
              !billsAsync.isLoading &&
              !billsAsync.hasError &&
              shared.any((bill) => !bill.fullySettled))
            TextButton(
              onPressed: _sendingReminder || !canRemind ? null : _remind,
              child: const Text('Remind all'),
            ),
        ],
      ),
      body: SafeArea(
        child: billsAsync.when(
          loading: () => const ShimmerList(),
          error: (error, stack) => LoadError(
            message: 'Could not load your shared bills.',
            onRetry: () {
              ref.invalidate(appRepositoryProvider);
              ref.invalidate(myBillsProvider);
            },
          ),
          data: (_) {
            final settledCount =
                shared.where((bill) => bill.fullySettled).length;
            final unsettledCount = shared.length - settledCount;
            final visible = shared
                .where((bill) => bill.fullySettled == showSettled)
                .toList();
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              itemCount: visible.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeading(
                        'Shared bills',
                        subtitle: '${shared.length} '
                            '${shared.length == 1 ? 'bill' : 'bills'} with ${widget.personName}',
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final filter in _SettlementFilter.values)
                              ChoiceChip(
                                label: Text(
                                    filter == _SettlementFilter.unsettled
                                        ? 'Unsettled ($unsettledCount)'
                                        : 'Settled ($settledCount)'),
                                selected: _filter == filter,
                                onSelected: (_) =>
                                    setState(() => _filter = filter),
                              ),
                          ],
                        ),
                      ),
                      if (!showSettled && visible.isNotEmpty)
                        const Text(
                            'Reminders request only amounts owed to you.'),
                      if (shared.isEmpty)
                        const InlineEmpty(
                          icon: Icons.receipt_long_outlined,
                          title: 'No shared bills',
                          message:
                              'Bills you share with this person will appear here.',
                        ),
                      if (shared.isNotEmpty && visible.isEmpty)
                        InlineEmpty(
                          icon: Icons.receipt_long_outlined,
                          title: showSettled
                              ? 'No settled bills'
                              : 'No unsettled bills',
                          message: showSettled
                              ? 'Settled bills with this person will appear here.'
                              : 'All your shared bills with this person are settled.',
                        ),
                    ],
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BillListTile(bill: visible[index - 1], uid: uid),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
