import 'package:currency_picker/currency_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../providers/form_providers.dart';
import '../widgets/state_widgets.dart';
import 'bills_tab.dart' show currencyLabel;

/// Currencies pinned to the top of the picker, in code order.
const _favoriteCurrencies = ['PKR', 'USD', 'EUR', 'GBP', 'AED', 'SAR', 'INR'];

/// Picks the group's currency: defaults to my default currency
/// (Profile → settings), changeable here. The picker needs a
/// BuildContext, so it lives in the widget layer and just calls the
/// form notifier.
class _CurrencyField extends StatelessWidget {
  const _CurrencyField();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final picked =
            ref.watch(createGroupFormProvider.select((s) => s.currency));
        final code = picked ??
            ref.watch(currentAppUserProvider).value?.currencyCode ??
            'USD';
        return Card(
          child: ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: const Text('Group currency'),
            subtitle: Text(currencyLabel(code)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showCurrencyPicker(
              context: context,
              showFlag: true,
              favorite: _favoriteCurrencies,
              onSelect: (c) => ref
                  .read(createGroupFormProvider.notifier)
                  .setCurrency(c.code),
            ),
          ),
        );
      },
    );
  }
}

/// One friend row in the invite checklist. Watches only its own
/// tick, so ticking one friend does not rebuild the other rows.
class _FriendCheckRow extends StatelessWidget {
  const _FriendCheckRow({required this.friend});

  final AppUser friend;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final checked = ref.watch(createGroupFormProvider
            .select((s) => s.selected.contains(friend.uid)));
        final notifier = ref.read(createGroupFormProvider.notifier);
        return CheckboxListTile(
          value: checked,
          onChanged: (v) => notifier.toggle(friend.uid, v ?? false),
          secondary: CircleAvatar(child: Text(friend.initials)),
          title: Text(friend.displayName),
          subtitle: Text(friend.email),
        );
      },
    );
  }
}

/// Create a group and invite friends (only people you're connected with).
class CreateGroupScreen extends StatelessWidget {
  const CreateGroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New group')),
      // Slivers so the friends checklist builds lazily via
      // SliverList.builder; the fixed form sections ride in box slivers.
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Writes only — never rebuilds on keystrokes.
                  Consumer(
                    builder: (context, ref, _) => TextField(
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Group name',
                        hintText: 'Weekend trip, Flatmates…',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) =>
                          ref.read(createGroupFormProvider.notifier).setName(v),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _CurrencyField(),
                  const SizedBox(height: 16),
                  Text(
                    'Invite friends (they join after accepting)',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          // Only the checklist reacts to connection state. Selection
          // is NOT watched here: each row watches only its own tick
          // (see [_FriendCheckRow]), so ticking one friend rebuilds
          // that one row instead of the whole checklist.
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: Consumer(
              builder: (context, ref, _) {
                final connsAsync = ref.watch(connectionsProvider);
                return connsAsync.when(
                  loading: () =>
                      const SliverToBoxAdapter(child: ShimmerRows(count: 3)),
                  error: (e, _) => SliverToBoxAdapter(
                    child: LoadError.compact(
                      message: 'Could not load friends',
                      onRetry: () {
                        ref.invalidate(appRepositoryProvider);
                        ref.invalidate(connectionsProvider);
                      },
                    ),
                  ),
                  data: (conns) {
                    if (conns.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                              'No connected friends yet. Add friends from the Friends tab first.'),
                        ),
                      );
                    }
                    return SliverList.builder(
                      itemCount: conns.length,
                      itemBuilder: (itemContext, i) =>
                          _FriendCheckRow(friend: conns[i]),
                    );
                  },
                );
              },
            ),
          ),
          // Only the button reacts to the saving state.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            sliver: SliverToBoxAdapter(
              child: Consumer(
                builder: (context, ref, _) {
                  final saving = ref
                      .watch(createGroupFormProvider.select((s) => s.saving));
                  return FilledButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            final err = await ref
                                .read(createGroupFormProvider.notifier)
                                .submit();
                            if (!context.mounted) return;
                            if (err == null) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Group created — invites sent.')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(err)),
                              );
                            }
                          },
                    icon: const Icon(Icons.group_add),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Create group & send invites'),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
