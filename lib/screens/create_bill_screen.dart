import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../providers/form_providers.dart';
import '../utils/split_math.dart';
import '../utils/current_user_identity.dart';
import '../widgets/split_bar.dart';
import '../widgets/state_widgets.dart';
import 'bills_tab.dart' show currencySymbol, formatMoney;

/// Add a group expense with selected members and equal/percentage/custom shares.
///
/// State lives in [CreateBillForm]; only the widgets that display changing
/// state are wrapped in [Consumer] — fields just call the notifier.
class CreateBillScreen extends ConsumerStatefulWidget {
  const CreateBillScreen({super.key, this.initialGroupId});
  final String? initialGroupId;

  @override
  ConsumerState<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends ConsumerState<CreateBillScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialGroupId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(createBillFormProvider.notifier)
            .setGroup(widget.initialGroupId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New expense')),
      // Slivers so the (potentially long) member list below builds
      // lazily via SliverList.builder; the form sections ride in two
      // fixed box slivers around it.
      body: const CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TitleField(),
                  SizedBox(height: 12),
                  _SubtotalField(),
                  SizedBox(height: 16),
                  _GroupPicker(),
                  SizedBox(height: 12),
                  _ReceiptSection(),
                  SizedBox(height: 10),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: _MembersSection(),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SplitAndSubmitSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _TitleField extends StatelessWidget {
  const _TitleField();

  @override
  Widget build(BuildContext context) {
    // Writes only — never rebuilds on keystrokes.
    return Consumer(
      builder: (context, ref, _) => TextField(
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Title',
          hintText: 'Dinner at Butt Karahi',
          border: OutlineInputBorder(),
        ),
        onChanged: (v) => ref.read(createBillFormProvider.notifier).setTitle(v),
      ),
    );
  }
}

class _SubtotalField extends StatelessWidget {
  const _SubtotalField();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        // The amount is entered in the bill's currency (the group's
        // currency, or my default) — show its symbol in the field.
        final symbol = currencySymbol(ref.watch(billFormCurrencyProvider));
        return TextField(
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          // Hero amount: the bill's total is the first thing the eye
          // lands on, big and centered, not one more small field.
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontFeatures: [const ui.FontFeature.tabularFigures()],
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            labelText: 'Bill amount',
            prefixText: '$symbol ',
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) =>
              ref.read(createBillFormProvider.notifier).setSubtotal(v),
        );
      },
    );
  }
}

class _GroupPicker extends ConsumerWidget {
  const _GroupPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(myGroupsProvider);
    final groupId =
        ref.watch(createBillFormProvider.select((s) => s.groupId));
    return groupsAsync.when(
      loading: () => DropdownButtonFormField<String>(
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Group',
          hintText: 'Choose a group',
          border: OutlineInputBorder(),
        ),
        items: const [],
        onChanged: null,
      ),
      error: (e, _) => LoadError.compact(
        message: 'Could not load groups',
        onRetry: () {
          ref.invalidate(appRepositoryProvider);
          ref.invalidate(myGroupsProvider);
        },
      ),
      data: (groups) => DropdownButtonFormField<String>(
        key: ValueKey(groupId),
        isExpanded: true,
        initialValue: groupId,
        decoration: InputDecoration(
          labelText: 'Group',
          hintText: 'Choose a group',
          helperText: groups.isEmpty ? 'Create a group to split expenses.' : null,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final group in groups)
            DropdownMenuItem<String>(
              value: group.id,
              child: Text(group.name, maxLines: 1,
                overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: groups.isEmpty
            ? null
            : ref.read(createBillFormProvider.notifier).setGroup,
      ),
    );
  }
}

class _MembersSection extends ConsumerWidget {
  const _MembersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Do not load or display participants before choosing a group.
    final groupId = ref.watch(createBillFormProvider.select((s) => s.groupId));
    if (groupId == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    ref.listen(createBillMembersProvider, (_, next) {
      next.whenData((members) =>
          ref.read(createBillFormProvider.notifier).autoSelect(members));
    });
    final membersAsync = ref.watch(createBillMembersProvider);
    final myUid = ref.watch(currentUidProvider);

    return membersAsync.when(
      loading: () => const SliverToBoxAdapter(child: ShimmerRows(count: 3)),
      error: (e, _) => SliverToBoxAdapter(
        child: LoadError.compact(
          message: 'Could not load group members',
          onRetry: () {
            ref.invalidate(appRepositoryProvider);
            ref.invalidate(createBillMembersProvider);
          },
        ),
      ),
      data: (members) {
        if (members.length < 2) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Add another member to this group to split an expense.'),
            ),
          );
        }
        return SliverList.builder(
          itemCount: members.length + 1,
          itemBuilder: (itemContext, index) {
            if (index == 0) {
              return _MemberSelectionHeader(members: members);
            }
            final member = members[index - 1];
            return _MemberRow(
              member: member,
              isMe: member.uid == myUid,
            );
          },
        );
      },
    );
  }
}

class _MemberSelectionHeader extends ConsumerWidget {
  const _MemberSelectionHeader({required this.members});

  final List<AppUser> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(createBillFormProvider.select((s) => s.selected));
    final selectedCount =
        members.where((member) => selected.contains(member.uid)).length;
    final allSelected = selectedCount == members.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                'Participants  ·  $selectedCount of ${members.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: () => ref.read(createBillFormProvider.notifier)
                  .selectAllMembers(members, !allSelected),
              child: Text(allSelected ? 'Clear others' : 'Select all'),
            ),
          ]),
          if (selectedCount < 2)
            Text(
              'Select at least one other member.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}

/// One member row. It watches ONLY its own slice of form state —
/// whether this member is selected, the split type, and the bill
/// currency — so ticking one person, or typing a percent for them,
/// rebuilds this row alone. The other rows' checkboxes and amount
/// fields are untouched (they used to rebuild on every tick, since
/// the whole list watched the whole selection set).
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isMe,
  });

  final AppUser member;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final selected = ref.watch(createBillFormProvider
            .select((s) => s.selected.contains(member.uid)));
        final splitType =
            ref.watch(createBillFormProvider.select((s) => s.splitType));
        final currencyCode = ref.watch(billFormCurrencyProvider);
        final google = ref.watch(authStateChangesProvider).value;
        final identity = resolveCurrentUserIdentity(
          cached: ref.watch(currentAppUserProvider).value,
          googleName: google?.displayName,
          googleEmail: google?.email,
        );
        final notifier = ref.read(createBillFormProvider.notifier);
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Checkbox(
                  value: selected,
                  // The creator is always included.
                  onChanged: isMe
                      ? null
                      : (v) => notifier.toggleMember(member.uid, v ?? false),
                ),
                CircleAvatar(child: Text(isMe ? identity.initials : member.initials)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMe ? '${identity.name} (you)' : member.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (isMe && identity.email.isNotEmpty)
                        Text(identity.email, maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (selected && splitType == 'percentage')
                  SizedBox(
                    width: 90,
                    child: TextField(
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        suffixText: '%',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onChanged: (v) => notifier.setPercent(member.uid, v),
                    ),
                  ),
                if (selected && splitType == 'custom')
                  SizedBox(
                    width: 110,
                    child: TextField(
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixText: '${currencySymbol(currencyCode)} ',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                      onChanged: (v) => notifier.setAmount(member.uid, v),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Hide split options until a group has been selected.
class _SplitAndSubmitSection extends ConsumerWidget {
  const _SplitAndSubmitSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupId = ref.watch(createBillFormProvider.select((s) => s.groupId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (groupId != null) ...[
          if (ref.watch(createBillFormProvider.select(
            (state) => state.selected.length >= 2,
          ))) ...[
            const _SectionTitle('Who paid the bill?'),
            const _PaymentSection(),
            const SizedBox(height: 16),
          ],
          const _SectionTitle('Split method'),
          const _SplitTypeSection(),
          const SizedBox(height: 20),
        ],
        const _CreateButton(),
      ],
    );
  }
}

/// Merchant contributions are separate from the share each person owes.
/// Selecting a payer never marks a participant as having settled a debt.
class _PaymentSection extends ConsumerWidget {
  const _PaymentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(createBillFormProvider);
    final members = ref.watch(createBillMembersProvider).value ?? const <AppUser>[];
    final selected = members.where((m) => form.selected.contains(m.uid)).toList();
    final notifier = ref.read(createBillFormProvider.notifier);
    final currency = ref.watch(billFormCurrencyProvider);
    final symbol = currencySymbol(currency);
    final myUid = ref.watch(currentUidProvider);
    final google = ref.watch(authStateChangesProvider).value;
    final identity = resolveCurrentUserIdentity(
      cached: ref.watch(currentAppUserProvider).value,
      googleName: google?.displayName,
      googleEmail: google?.email,
    );

    final paidCents = form.paymentMode == 'single'
        ? (form.payerUid == null ? 0 : (form.total * 100).round())
        : selected.fold<int>(0, (sum, member) {
            final value = double.tryParse(
                (form.payments[member.uid] ?? '').replaceAll(',', '.')) ?? 0;
            return sum + (value.isFinite && value >= 0
                ? (value * 100).round() : 0);
          });
    final totalCents = (form.total * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 8, runSpacing: 6, children: [
          ChoiceChip(
            label: const Text('One person paid'),
            selected: form.paymentMode == 'single',
            onSelected: (chosen) {
              if (chosen) notifier.setPaymentMode('single');
            },
          ),
          ChoiceChip(
            label: const Text('Multiple people paid'),
            selected: form.paymentMode == 'multiple',
            onSelected: (chosen) {
              if (chosen) notifier.setPaymentMode('multiple');
            },
          ),
        ]),
        const SizedBox(height: 10),
        if (form.paymentMode == 'single')
          DropdownButtonFormField<String>(
            key: ValueKey('payer-${form.payerUid}-${form.selected.length}'),
            isExpanded: true,
            initialValue: form.payerUid,
            decoration: const InputDecoration(
              labelText: 'Paid by (required)',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final member in selected)
                DropdownMenuItem<String>(
                  value: member.uid,
                  child: Text(member.uid == myUid
                      ? '${identity.name} (you)' : member.displayName,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: notifier.setPayer,
          )
        else ...[
          for (final member in selected)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  child: Text(member.uid == myUid
                      ? '${identity.name} (you)' : member.displayName,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 135,
                  child: TextField(
                    key: ValueKey('merchant-payment-${member.uid}'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Paid',
                      prefixText: '$symbol ',
                      hintText: '0',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) =>
                        notifier.setMerchantPayment(member.uid, v),
                  ),
                ),
              ]),
            ),
          Text(
            'Paid: ${formatMoney(paidCents / 100, currency)} '
            '/ ${formatMoney(form.total, currency)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: paidCents == totalCents
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'Their payments will be compared with their split shares to '
          'calculate who reimburses whom.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _SplitTypeSection extends StatelessWidget {
  const _SplitTypeSection();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final splitType =
            ref.watch(createBillFormProvider.select((s) => s.splitType));
        final selectedCount =
            ref.watch(createBillFormProvider.select((s) => s.selected.length));
        final selected =
            ref.watch(createBillFormProvider.select((s) => s.selected));
        final percents =
            ref.watch(createBillFormProvider.select((s) => s.percents));
        final amounts =
            ref.watch(createBillFormProvider.select((s) => s.amounts));
        final total = ref.watch(createBillFormProvider.select((s) => s.total));
        final currency = ref.watch(billFormCurrencyProvider);
        final notifier = ref.read(createBillFormProvider.notifier);
        final remainder = unallocatedRemainder(
          splitType: splitType,
          selected: selected,
          percents: percents,
          amounts: amounts,
          total: total,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              // Segments share the available width equally, so the
              // control fits any screen width.
              expandedInsets: EdgeInsets.zero,
              segments: const [
                ButtonSegment(
                    value: 'equal',
                    label: Text('Equal'),
                    icon: Icon(Icons.balance)),
                ButtonSegment(
                    value: 'percentage',
                    label: Text('Percent'),
                    icon: Icon(Icons.percent)),
                ButtonSegment(
                    value: 'custom',
                    label: Text('Custom'),
                    icon: Icon(Icons.edit)),
              ],
              selected: {splitType},
              onSelectionChanged: (s) => notifier.setSplitType(s.first),
            ),
            const SizedBox(height: 8),
            if (splitType == 'equal' && selectedCount >= 2)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Each of the $selectedCount selected pays ${formatMoney(total / selectedCount, currency)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            // Live split preview: the motif bar, updating as shares
            // are typed, plus what's left to allocate for percentage
            // and custom splits (equal splits are always exact).
            if (selectedCount >= 2 && total > 0) ...[
              const SizedBox(height: 12),
              SplitBar(
                  segments: _previewSegments(
                splitType: splitType,
                selected: selected,
                percents: percents,
                amounts: amounts,
              )),
              if (remainder != null) ...[
                const SizedBox(height: 8),
                Text(
                  _remainderText(
                    splitType: splitType,
                    remainder: remainder,
                    currency: currency,
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: remainder < -0.01
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final ready = ref.watch(createBillFormProvider.select(
            (s) => s.groupId != null &&
                s.selected.length >= 2 &&
                (s.paymentMode == 'multiple' ||
                    (s.payerUid != null && s.selected.contains(s.payerUid)))));
        final saving =
            ref.watch(createBillFormProvider.select((s) => s.saving));
        return FilledButton.icon(
          onPressed: saving || !ready
              ? null
              : () async {
                  final err =
                      await ref.read(createBillFormProvider.notifier).submit();
                  if (!context.mounted) return;
                  if (err == null) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Bill created — everyone was notified.')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(err)),
                    );
                  }
                },
          icon: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('Create & notify everyone'),
          ),
        );
      },
    );
  }
}

/// Optional receipt photo picker. Only this section reacts to the
/// receipt state; picking/compression live in [CreateBillForm].
class _ReceiptSection extends StatelessWidget {
  const _ReceiptSection();

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;
    final error =
        await ref.read(createBillFormProvider.notifier).pickReceipt(source);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final state = ref.watch(createBillFormProvider
            .select((s) => (path: s.receiptPath, busy: s.receiptBusy)));
        final path = state.path;
        if (path == null) {
          return OutlinedButton.icon(
            onPressed: state.busy ? null : () => _pick(context, ref),
            icon: state.busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_outlined),
            label: const Text('Add receipt photo'),
          );
        }
        return Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(path),
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Receipt attached')),
            TextButton(
              onPressed: state.busy ? null : () => _pick(context, ref),
              child: const Text('Change'),
            ),
            IconButton(
              onPressed: () =>
                  ref.read(createBillFormProvider.notifier).removeReceipt(),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove photo',
            ),
          ],
        );
      },
    );
  }
}

/// Live split-bar segments for the form's current state: equal shares
/// for equal splits, entered percents/amounts otherwise (unparseable
/// entries count as zero; the bar hides them).
List<SplitSegment> _previewSegments({
  required String splitType,
  required Set<String> selected,
  required Map<String, String> percents,
  required Map<String, String> amounts,
}) {
  double parse(String? v) =>
      double.tryParse((v ?? '').replaceAll(',', '.')) ?? 0;
  final uids = selected.toList();
  return [
    for (var i = 0; i < uids.length; i++)
      SplitSegment(
        value: switch (splitType) {
          'percentage' => parse(percents[uids[i]]),
          'custom' => parse(amounts[uids[i]]),
          _ => 1,
        },
        color: splitHues[i % splitHues.length],
      ),
  ];
}

/// Remainder line for percentage/custom splits: what's left, what's
/// over, or fully allocated. Thresholds match submit-time validation
/// (0.01 percent points, exact whole cents).
String _remainderText({
  required String splitType,
  required double remainder,
  required String currency,
}) {
  if (splitType == 'percentage') {
    if (remainder.abs() < 0.01) {
      return 'Fully allocated';
    }
    if (remainder > 0) {
      return '${remainder.toStringAsFixed(1)}% left to allocate';
    }
    return 'Over by ${(-remainder).toStringAsFixed(1)}%';
  }
  if (remainder.abs() < 0.005) {
    return 'Fully allocated';
  }
  if (remainder > 0) {
    return '${formatMoney(remainder, currency)} left to allocate';
  }
  return 'Over by ${formatMoney(-remainder, currency)}';
}
