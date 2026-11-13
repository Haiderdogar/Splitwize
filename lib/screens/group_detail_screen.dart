import 'package:currency_picker/currency_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../utils/money.dart';
import '../widgets/group_invitation_card.dart';
import '../widgets/state_widgets.dart';
import 'create_bill_screen.dart';
import 'group_detail/group_balances.dart';
import 'group_detail/group_expenses.dart';
import 'group_detail/group_members.dart';
import 'group_detail/group_overview.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({required this.groupId, super.key});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupProvider(groupId));
    final uid = ref.watch(currentUidProvider) ?? '';
    final group = groupAsync.value;
    final isMember =
        group != null && !group.deleted && group.members.contains(uid);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group details'),
        actions: [
          if (isMember)
            IconButton(
              tooltip: 'Group settings',
              onPressed: () => _showSettings(context, group),
              icon: const Icon(Icons.tune_rounded),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: groupAsync.when(
        loading: () => const ShimmerDetail(),
        error: (_, __) => LoadError(
          message: 'Could not load this group.',
          onRetry: () {
            ref.invalidate(appRepositoryProvider);
            ref.invalidate(groupProvider(groupId));
          },
        ),
        data: (group) {
          if (group == null || group.deleted) {
            return const Center(child: Text('Group not found.'));
          }
          // Accept the invitation before reading any group expense data.
          if (!group.members.contains(uid)) {
            if (!group.invited.contains(uid)) {
              return const Center(
                  child: Text('Join this group to view its details.'));
            }
            return ListView(padding: const EdgeInsets.all(20), children: [
              const Text('Incoming group invitation'),
              const SizedBox(height: 12),
              GroupInvitationCard(group: group, recipientUid: uid),
            ]);
          }
          return _GroupBody(group: group);
        },
      ),
    );
  }

  void _showSettings(BuildContext context, BillGroup group) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Group settings',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Consumer(builder: (context, ref, _) {
                final current =
                    ref.watch(groupProvider(group.id)).value ?? group;
                return _GroupCurrencyButton(group: current, expanded: true);
              }),
              const SizedBox(height: 12),
              Text(
                  'The group currency is used for new expenses. '
                  'Existing expenses keep their original currency.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupBody extends StatefulWidget {
  const _GroupBody({required this.group});
  final BillGroup group;

  @override
  State<_GroupBody> createState() => _GroupBodyState();
}

class _GroupBodyState extends State<_GroupBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(children: [
            Expanded(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(Icons.groups_rounded,
                                    size: 28, color: scheme.onPrimaryContainer),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(group.name,
                                      style: theme.textTheme.headlineSmall),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${group.members.length} '
                                      '${group.members.length == 1 ? 'member' : 'members'}'
                                      '${group.invited.isEmpty ? '' : ' · ${group.invited.length} invited'}',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              color: scheme.onSurfaceVariant)),
                                ],
                              )),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _GroupCurrencyButton(group: group),
                          const SizedBox(height: 12),
                          GroupOverview(
                              group: group,
                              onBalances: () => _tabs.animateTo(1)),
                        ],
                      ),
                    ),
                  ),
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                        context),
                    sliver: SliverPersistentHeader(
                      pinned: true,
                      delegate: _GroupTabHeader(
                        controller: _tabs,
                        background: scheme.surface,
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabs,
                  children: [
                    GroupExpensesTab(group: group),
                    Builder(
                      builder: (context) => CustomScrollView(
                        key: PageStorageKey('group-balances-${group.id}'),
                        slivers: [
                          SliverOverlapInjector(
                              handle: NestedScrollView
                                  .sliverOverlapAbsorberHandleFor(context)),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                            sliver: GroupBalancesSection(groupId: group.id),
                          ),
                        ],
                      ),
                    ),
                    GroupMembersTab(group: group),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          CreateBillScreen(initialGroupId: group.id))),
                  icon: const Icon(Icons.add_rounded, size: 22),
                  label: const Text('Add expense'),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _GroupTabHeader extends SliverPersistentHeaderDelegate {
  const _GroupTabHeader({required this.controller, required this.background});
  final TabController controller;
  final Color background;

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: maxExtent,
      child: Material(
        color: background,
        child: LayoutBuilder(builder: (context, constraints) {
          final scrollable = constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(14) > 18;
          return TabBar(
            controller: controller,
            isScrollable: scrollable,
            tabAlignment: scrollable ? TabAlignment.start : TabAlignment.fill,
            labelPadding: const EdgeInsets.symmetric(horizontal: 20),
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: 'Expenses'),
              Tab(text: 'Balances'),
              Tab(text: 'Members'),
            ],
          );
        }),
      ),
    );
  }

  @override
  bool shouldRebuild(_GroupTabHeader oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.background != background;
}

class _GroupCurrencyButton extends ConsumerWidget {
  const _GroupCurrencyButton({required this.group, this.expanded = false});
  final BillGroup group;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        minimumSize: const Size(48, 48),
      ),
      onPressed: () => showCurrencyPicker(
        context: context,
        showFlag: true,
        favorite: const ['PKR', 'USD', 'EUR', 'GBP', 'AED', 'SAR', 'INR'],
        onSelect: (currency) async {
          try {
            final repo = await ref.read(appRepositoryProvider.future);
            await repo.setGroupCurrency(group.id, currency.code);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Group currency changed to ${currency.code}. '
                      'New expenses will use it.')));
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content:
                      Text('Could not change currency. Please try again.')));
            }
          }
        },
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          const Icon(Icons.payments_outlined, size: 18),
          const SizedBox(width: 8),
          Flexible(
              child: Text(
                  expanded ? currencyLabel(group.currency) : 'Group currency')),
          const SizedBox(width: 8),
          Text(group.currency,
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more_rounded, size: 18),
        ],
      ),
    );
  }
}
