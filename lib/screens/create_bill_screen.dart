import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../providers/form_providers.dart';
import '../widgets/state_widgets.dart';
import 'bills_tab.dart' show currencySymbol, formatMoney;

/// Create a bill: title, amount + tip, pick a group (or friends),
/// choose who it splits between, then equal / percentage / custom shares.
///
/// State lives in [CreateBillForm]; only the widgets that display changing
/// state are wrapped in [Consumer] — fields just call the notifier.
class CreateBillScreen extends StatelessWidget {
  const CreateBillScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Split a bill')),
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
                  _SectionTitle('Bill'),
                  _TitleField(),
                  SizedBox(height: 12),
                  _SubtotalField(),
                  SizedBox(height: 12),
                  _TipSection(),
                  SizedBox(height: 8),
                  _SectionTitle('Receipt (optional)'),
                  _ReceiptSection(),
                  SizedBox(height: 8),
                  _SectionTitle('Who is splitting?'),
                  _GroupPicker(),
                  SizedBox(height: 8),
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
                  _SectionTitle('How to split?'),
                  _SplitTypeSection(),
                  SizedBox(height: 24),
                  _CreateButton(),
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

class _TipSection extends StatelessWidget {
  const _TipSection();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final tip =
            ref.watch(createBillFormProvider.select((s) => s.tipPercent));
        final total = ref.watch(createBillFormProvider.select((s) => s.total));
        final currency = ref.watch(billFormCurrencyProvider);
        final notifier = ref.read(createBillFormProvider.notifier);
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tip'),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    '${tip.toStringAsFixed(0)}%  •  Total ${formatMoney(total, currency)}',
                    textAlign: TextAlign.end,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [0, 10, 15, 18, 20].map((p) {
                return ChoiceChip(
                  label: Text('$p%'),
                  selected: tip == p.toDouble(),
                  onSelected: (_) => notifier.setTip(p.toDouble()),
                );
              }).toList(),
            ),
            Slider(
              value: tip,
              min: 0,
              max: 30,
              divisions: 30,
              label: '${tip.toStringAsFixed(0)}%',
              onChanged: notifier.setTip,
            ),
          ],
        );
      },
    );
  }
}

class _GroupPicker extends StatelessWidget {
  const _GroupPicker();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final groupsAsync = ref.watch(myGroupsProvider);
        final groupId =
            ref.watch(createBillFormProvider.select((s) => s.groupId));
        return groupsAsync.when(
          loading: () => DropdownButtonFormField<String?>(
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Group (optional)',
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
          data: (groups) => DropdownButtonFormField<String?>(
            // Take the field's width and ellipsize long group names
            // instead of overflowing the form.
            isExpanded: true,
            initialValue: groupId,
            decoration: const InputDecoration(
              labelText: 'Group (optional)',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('No group — pick friends'),
              ),
              ...groups.map((g) => DropdownMenuItem<String?>(
                    value: g.id,
                    child: Text(g.name),
                  )),
            ],
            onChanged: (v) =>
                ref.read(createBillFormProvider.notifier).setGroup(v),
          ),
        );
      },
    );
  }
}

class _MembersSection extends StatelessWidget {
  const _MembersSection();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        // Side-effect only: pre-select members when the list first loads.
        ref.listen(createBillMembersProvider, (_, next) {
          next.whenData((members) =>
              ref.read(createBillFormProvider.notifier).autoSelect(members));
        });
        // Only the member list itself is watched here. Selection
        // state is NOT watched at this level: each row watches only
        // its own membership (see [_MemberRow]), so ticking one
        // person rebuilds that one row — not the whole list. (The
        // old version watched the whole `selected` set here, so
        // every tick rebuilt every row, including the percent /
        // custom amount fields of people you weren't touching.)
        final membersAsync = ref.watch(createBillMembersProvider);
        final myUid = ref.watch(currentUidProvider);

        return membersAsync.when(
          loading: () => const SliverToBoxAdapter(child: ShimmerRows(count: 3)),
          error: (e, _) => SliverToBoxAdapter(
            child: LoadError.compact(
              message: 'Could not load people',
              onRetry: () {
                ref.invalidate(appRepositoryProvider);
                ref.invalidate(createBillMembersProvider);
              },
            ),
          ),
          data: (members) {
            if (members.isEmpty) {
              return const SliverToBoxAdapter(
                child: Text('No one to split with yet — add friends first.'),
              );
            }
            return SliverList.builder(
              itemCount: members.length,
              itemBuilder: (itemContext, i) {
                final m = members[i];
                return _MemberRow(
                  member: m,
                  isMe: m.uid == myUid,
                );
              },
            );
          },
        );
      },
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
                CircleAvatar(child: Text(member.initials)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isMe ? '${member.displayName} (you)' : member.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
        final total = ref.watch(createBillFormProvider.select((s) => s.total));
        final currency = ref.watch(billFormCurrencyProvider);
        final notifier = ref.read(createBillFormProvider.notifier);
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
            if (splitType == 'equal' && selectedCount > 0)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Each of the $selectedCount selected pays ${formatMoney(total / selectedCount, currency)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
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
        final saving =
            ref.watch(createBillFormProvider.select((s) => s.saving));
        return FilledButton.icon(
          onPressed: saving
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
