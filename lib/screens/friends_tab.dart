import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../providers/form_providers.dart';
import '../theme.dart';
import '../utils/money.dart';
import '../widgets/app_drawer.dart';
import '../widgets/balance_totals.dart';
import '../widgets/invitation_button.dart';
import '../widgets/repayment_action.dart';
import '../widgets/studio_ui.dart';
import '../widgets/state_widgets.dart';
import 'person_bills_screen.dart';
import 'request_screens.dart';

class FriendsTab extends ConsumerStatefulWidget {
  const FriendsTab({super.key});

  @override
  ConsumerState<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends ConsumerState<FriendsTab>
    with WidgetsBindingObserver {
  String _query = '';
  bool _refreshing = false;
  String? _refreshError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && ref.read(tabIndexProvider) == 2) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (_refreshing || !mounted) return;
    setState(() {
      _refreshing = true;
      _refreshError = null;
    });
    try {
      final sync = await ref.read(syncServiceProvider.future);
      await sync.refreshConnections();
    } catch (_) {
      if (mounted) {
        setState(() => _refreshError =
            'Could not refresh friends. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tabIndexProvider, (previous, next) {
      if (next == 2 && previous != 2) _refresh();
    });
    return Scaffold(
      appBar: AppBar(
        leading: const SplitwizeMenuButton(),
        title: const Text('Friends'),
        actions: const [
          _FriendInvitationsAction(),
          SizedBox(width: 8),
        ],
      ),
      // Connected friends. The list refreshes on open, on return to the tab,
      // on app resume and by pulling down, so there is no refresh button.
      body: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Consumer(builder: (context, ref, _) {
                  final count =
                      ref.watch(connectionsProvider).value?.length ?? 0;
                  if (count <= 8 && _query.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search friends by name or email',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  );
                }),
              ),
              if (_refreshError != null)
                SliverToBoxAdapter(
                    child: LoadError.compact(
                        message: _refreshError!, onRetry: _refresh)),
              // What you owe and are owed, per currency, above the people.
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: BalanceTotals(topPadding: 12),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                sliver: _Connections(
                    query: _query,
                    refreshing: _refreshing,
                    refreshFailed: _refreshError != null),
              ),
              // Leave enough scroll space for the add-friend button.
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          )),
      floatingActionButton: FloatingActionButton(
        heroTag: 'friends-add-friend',
        tooltip: 'Add friend',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _AddFriendDialog(),
        ),
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
    );
  }
}

/// App-bar shortcut to friend invitations; the counter totals incoming and
/// outgoing invitations.
class _FriendInvitationsAction extends ConsumerWidget {
  const _FriendInvitationsAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(incomingRequestsProvider).value?.length ?? 0;
    final outgoing = ref.watch(outgoingRequestsProvider).value?.length ?? 0;
    return InvitationButton(
      count: incoming + outgoing,
      tooltip: 'Friend invitations',
      onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FriendRequestsScreen())),
    );
  }
}

/// Empty-state row for a user's connections list.
class _EmptyRow extends StatelessWidget {
  const _EmptyRow(
      {required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => SoftPanel(
        padding: const EdgeInsets.all(13),
        child: Row(children: [
          PersonMark(initials: '', icon: icon, size: 44),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          )),
        ]),
      );
}

/// One person in the list: a friend, and/or someone I share a balance with.
class _PersonRow {
  const _PersonRow({
    required this.uid,
    required this.name,
    required this.initials,
    required this.friend,
    required this.balances,
  });

  final String uid;
  final String name;
  final String initials;

  /// Null when this person is not one of my friends but still owes me or is
  /// owed by me.
  final AppUser? friend;

  /// One entry per currency; empty when nothing is outstanding.
  final List<FriendBalance> balances;
}

class _Connections extends StatelessWidget {
  const _Connections(
      {required this.query,
      required this.refreshing,
      required this.refreshFailed});
  final String query;
  final bool refreshing;
  final bool refreshFailed;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final connsAsync = ref.watch(connectionsProvider);
        final myUid = ref.watch(currentUidProvider) ?? '';
        return connsAsync.when(
          loading: () => const SliverToBoxAdapter(child: ShimmerRows(count: 3)),
          error: (e, _) => SliverToBoxAdapter(
            child: LoadError.compact(
              message: 'Could not load friends',
              onRetry: () {
                ref.invalidate(appRepositoryProvider);
                ref.invalidate(connectionsProvider);
              },
            ),
          ),
          data: (friends) {
            final balances = ref.watch(balancesProvider);
            final rows = _rows(friends, balances);
            final keyword = query.trim().toLowerCase();
            final visible = keyword.isEmpty
                ? rows
                : rows
                    .where((row) =>
                        row.name.toLowerCase().contains(keyword) ||
                        (row.friend?.email.toLowerCase().contains(keyword) ??
                            false))
                    .toList();
            if (rows.isEmpty) {
              if (refreshing) {
                return const SliverToBoxAdapter(child: ShimmerRows(count: 3));
              }
              if (refreshFailed) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return const SliverToBoxAdapter(
                child: _EmptyRow(
                  icon: Icons.people_outline,
                  title: 'No friends yet',
                  subtitle: 'Invite friends to start splitting bills together.',
                ),
              );
            }
            if (visible.isEmpty) {
              return const SliverToBoxAdapter(
                  child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No friends match your search.'),
              ));
            }
            return SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (itemContext, i) =>
                  _personCard(itemContext, ref, myUid, visible[i]),
            );
          },
        );
      },
    );
  }

  /// Friends plus anyone else I share an unpaid balance with (for example a
  /// group member who is not a friend), so no balance is ever hidden. People
  /// with a balance come first, largest first; the rest keep their order.
  List<_PersonRow> _rows(List<AppUser> friends, List<FriendBalance> balances) {
    final friendsByUid = {for (final friend in friends) friend.uid: friend};
    final byUid = <String, List<FriendBalance>>{};
    for (final balance in balances) {
      (byUid[balance.uid] ??= <FriendBalance>[]).add(balance);
    }
    return [
      for (final entry in byUid.entries)
        _PersonRow(
          uid: entry.key,
          name: friendsByUid[entry.key]?.displayName ??
              entry.value.first.displayName,
          initials:
              friendsByUid[entry.key]?.initials ?? entry.value.first.initials,
          friend: friendsByUid[entry.key],
          balances: entry.value,
        ),
      for (final friend in friends)
        if (!byUid.containsKey(friend.uid))
          _PersonRow(
            uid: friend.uid,
            name: friend.displayName,
            initials: friend.initials,
            friend: friend,
            balances: const [],
          ),
    ];
  }

  Widget _personCard(
      BuildContext context, WidgetRef ref, String myUid, _PersonRow row) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasBalance = row.balances.isNotEmpty;
    final friend = row.friend;
    final lineStyle =
        theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700);
    final repayments = [
      for (final b in row.balances)
        if (b.iOweThem > 0.005) b,
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasBalance
            ? () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PersonBillsScreen(
                    personUid: row.uid,
                    personName: row.name,
                  ),
                ))
            : null,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, friend == null ? 16 : 4, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PersonMark(initials: row.initials),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        if (!hasBalance)
                          Text(
                            friend == null || friend.email.isEmpty
                                ? 'Email unavailable'
                                : friend.email,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        for (final b in row.balances) ...[
                          if (b.owesMe > 0.005)
                            Text(
                                'Owes you ${formatMoney(b.owesMe, b.currency)}',
                                style:
                                    lineStyle?.copyWith(color: scheme.owed)),
                          if (b.iOweThem > 0.005)
                            Text(
                                'You owe ${formatMoney(b.iOweThem, b.currency)}',
                                style: lineStyle?.copyWith(color: scheme.owe)),
                        ],
                      ]),
                ),
              ),
              if (friend != null)
                PopupMenuButton<String>(
                  tooltip: 'Friend options',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (action) {
                    if (action == 'remove') {
                      _confirmRemove(context, ref, myUid, friend);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'remove', child: Text('Remove friend')),
                  ],
                ),
            ]),
            if (repayments.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(0, 10, friend == null ? 0 : 12, 0),
                child: Wrap(spacing: 8, runSpacing: 6, children: [
                  for (final b in repayments)
                    FilledButton.tonalIcon(
                      onPressed: () => recordRepayment(context, ref, b),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(row.balances.length > 1
                          ? 'Record repayment (${b.currency})'
                          : 'Record repayment'),
                    ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
      BuildContext context, WidgetRef ref, String myUid, AppUser friend) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text('Remove ${friend.displayName} from your connections?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await runGuarded(
        context,
        () async => (await ref.read(appRepositoryProvider.future))
            .removeConnection(friend.uid),
        errorLabel: 'Could not remove friend',
      );
    }
  }
}

/// Add-friend dialog driven by [AddFriend] — no StatefulWidget needed.
class _AddFriendDialog extends StatelessWidget {
  const _AddFriendDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add friend'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Enter your friend\'s email. They must have signed in to Splitwize at least once.'),
            const SizedBox(height: 12),
            // Writes only.
            Consumer(
              builder: (context, ref, _) => TextField(
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    ref.read(addFriendProvider.notifier).setEmail(v),
              ),
            ),
            // Only the result area reacts to search state — and
            // only to the search fields, not the typed email. The
            // old version watched the whole form state, so every
            // keystroke in the email field rebuilt this area (and
            // the button below) even though nothing it shows had
            // changed.
            Consumer(
              builder: (context, ref, _) {
                final view = ref.watch(addFriendProvider.select((s) => (
                      searching: s.searching,
                      error: s.error,
                      found: s.found,
                    )));
                if (view.searching) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: CircularProgressIndicator(),
                  );
                }
                if (view.error != null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(view.error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  );
                }
                final found = view.found;
                if (found != null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ListTile(
                      leading: CircleAvatar(child: Text(found.initials)),
                      title: Text(found.displayName),
                      subtitle: Text(found.email),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        // Only the action button reacts to search state — and only
        // to searching / whether someone was found, not to the
        // typed email, so keystrokes do not rebuild it.
        Consumer(
          builder: (context, ref, _) {
            final view = ref.watch(addFriendProvider.select((s) => (
                  searching: s.searching,
                  hasFound: s.found != null,
                )));
            final notifier = ref.read(addFriendProvider.notifier);
            if (!view.hasFound) {
              return FilledButton(
                onPressed: view.searching ? null : () => notifier.search(),
                child: const Text('Search'),
              );
            }
            return FilledButton(
              onPressed: () async {
                final err = await notifier.sendInvite();
                if (!context.mounted) return;
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err)),
                  );
                  return;
                }
                final name = ref.read(addFriendProvider).found?.displayName ??
                    'your friend';
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invite sent to $name.')),
                );
              },
              child: const Text('Send invite'),
            );
          },
        ),
      ],
    );
  }
}
