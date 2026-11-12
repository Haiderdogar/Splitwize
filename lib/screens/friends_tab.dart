import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../providers/form_providers.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_notification_button.dart';
import '../widgets/invitation_button.dart';
import '../widgets/studio_ui.dart';
import '../widgets/state_widgets.dart';
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
    if (state == AppLifecycleState.resumed && ref.read(tabIndexProvider) == 3) {
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
      if (next == 3 && previous != 3) _refresh();
    });
    return Scaffold(
      appBar: AppBar(
        leading: const SplitwizeMenuButton(),
        title: const Text('Friends'),
        actions: [
          IconButton(
              tooltip: 'Refresh friends',
              onPressed: _refreshing ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded)),
          const AppNotificationButton(),
          const SizedBox(width: 5),
        ],
      ),
      // Connected friends, with invitations opened from the section header.
      body: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                sliver: SliverToBoxAdapter(child: _ConnectedHeader()),
              ),
              SliverToBoxAdapter(
                child: Consumer(builder: (context, ref, _) {
                  final count =
                      ref.watch(connectionsProvider).value?.length ?? 0;
                  if (count <= 8 && _query.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
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

/// Small muted section header with an optional pending-count pill.
/// The count watches only the list lengths, so it never rebuilds on
/// unrelated state changes.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, {this.count, this.trailing});

  final String text;
  final int? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  text,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                if (count != null && count! > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onPrimaryContainer,
                          ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _ConnectedHeader extends StatelessWidget {
  const _ConnectedHeader();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final count =
            ref.watch(connectionsProvider.select((v) => v.value?.length ?? 0));
        final incoming = ref.watch(incomingRequestsProvider).value?.length ?? 0;
        final outgoing =
            ref.watch(outgoingRequestsProvider).value?.length ?? 0;
        return _SectionHeader(
          'Connected',
          count: count,
          trailing: InvitationButton(
            count: incoming + outgoing,
            tooltip: 'Friend invitations',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const FriendRequestsScreen())),
          ),
        );
      },
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
            final keyword = query.trim().toLowerCase();
            final visible = keyword.isEmpty
                ? friends
                : friends
                    .where((friend) =>
                        friend.displayName.toLowerCase().contains(keyword) ||
                        friend.email.toLowerCase().contains(keyword))
                    .toList();
            if (friends.isEmpty) {
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
              itemBuilder: (itemContext, i) {
                final f = visible[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    leading: PersonMark(initials: f.initials),
                    title: Text(f.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text(
                      f.email.isEmpty ? 'Email unavailable' : f.email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Friend options',
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (action) {
                        if (action == 'remove') {
                          _confirmRemove(context, ref, myUid, f);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'remove', child: Text('Remove friend')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
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
