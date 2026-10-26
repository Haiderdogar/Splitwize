import 'package:currency_picker/currency_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          // Only the checklist reacts to connection/selection state.
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: Consumer(
              builder: (context, ref, _) {
                final connsAsync = ref.watch(connectionsProvider);
                final selected = ref
                    .watch(createGroupFormProvider.select((s) => s.selected));
                final notifier = ref.read(createGroupFormProvider.notifier);
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
                      itemBuilder: (itemContext, i) {
                        final c = conns[i];
                        return CheckboxListTile(
                          value: selected.contains(c.uid),
                          onChanged: (v) => notifier.toggle(c.uid, v ?? false),
                          secondary: CircleAvatar(child: Text(c.initials)),
                          title: Text(c.displayName),
                          subtitle: Text(c.email),
                        );
                      },
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
