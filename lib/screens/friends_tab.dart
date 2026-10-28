import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../providers/form_providers.dart';
import '../widgets/state_widgets.dart';

class FriendsTab extends StatelessWidget {
  const FriendsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            tooltip: 'Add friend',
            icon: const Icon(Icons.person_add),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const _AddFriendDialog(),
            ),
          ),
        ],
      ),
      // Slivers + builder lists: request/friend cards are built
      // lazily, only for what's on screen.
      body: const CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
            sliver: SliverToBoxAdapter(child: _InviteHeroCard()),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(12, 20, 12, 0),
            sliver: SliverToBoxAdapter(child: _RequestsHeader()),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            sliver: _IncomingRequests(),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
            sliver: _OutgoingRequests(),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(12, 20, 12, 0),
            sliver: SliverToBoxAdapter(child: _ConnectedHeader()),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            sliver: _Connections(),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
      ),
    );
  }
}

/// The invite hero: a tonal card that leads the screen, with the same
/// invite dialog behind its button as the app-bar action.
class _InviteHeroCard extends StatelessWidget {
  const _InviteHeroCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invite friends',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Split bills with people you trust. They get an invite to join Splitwize.',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Scales down (never overflows) on narrow screens
                  // and at large text scales.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: FilledButton.icon(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => const _AddFriendDialog(),
                        ),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Invite by email'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people,
                size: 32,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small muted section header with an optional pending-count pill.
/// The count watches only the list lengths, so it never rebuilds on
/// unrelated state changes.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, {this.count});

  final String text;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          if (count != null && count! > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
        ],
      ),
    );
  }
}

class _RequestsHeader extends StatelessWidget {
  const _RequestsHeader();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final incoming = ref.watch(
            incomingRequestsProvider.select((v) => v.value?.length ?? 0));
        final outgoing = ref.watch(
            outgoingRequestsProvider.select((v) => v.value?.length ?? 0));
        return _SectionHeader('Requests', count: incoming + outgoing);
      },
    );
  }
}

class _ConnectedHeader extends StatelessWidget {
  const _ConnectedHeader();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final count = ref.watch(
            connectionsProvider.select((v) => v.value?.length ?? 0));
        return _SectionHeader('Connected', count: count);
      },
    );
  }
}

/// Compact empty row used by every section: an icon in a tonal circle
/// plus a title and a muted explanation, inside a standard card.
class _EmptyRow extends StatelessWidget {
  const _EmptyRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: scheme.outline),
        ),
        title: Text(title, style: text.titleSmall),
        subtitle: Text(
          subtitle,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _IncomingRequests extends StatelessWidget {
  const _IncomingRequests();

  @override
  Widget build(BuildContext context) {
    // Only this section reacts to incoming-request state.
    return Consumer(
      builder: (context, ref, _) {
        final reqsAsync = ref.watch(incomingRequestsProvider);
        return reqsAsync.when(
          loading: () => const SliverToBoxAdapter(child: ShimmerRows(count: 2)),
          error: (e, _) => SliverToBoxAdapter(
            child: LoadError.compact(
              message: 'Could not load requests',
              onRetry: () {
                ref.invalidate(appRepositoryProvider);
                ref.invalidate(incomingRequestsProvider);
              },
            ),
          ),
          data: (reqs) {
            if (reqs.isEmpty) {
              return const SliverToBoxAdapter(
                child: _EmptyRow(
                  icon: Icons.inbox_outlined,
                  title: 'No incoming requests',
                  subtitle: 'Invites from friends will appear here.',
                ),
              );
            }
            return SliverList.builder(
              itemCount: reqs.length,
              itemBuilder: (itemContext, i) {
                final r = reqs[i];
                return _IncomingCard(
                  request: r,
                  onAccept: () => runGuarded(
                    context,
                    () async => (await ref.read(appRepositoryProvider.future))
                        .acceptConnectionRequest(r),
                    errorLabel: 'Could not accept request',
                  ),
                  onDecline: () => runGuarded(
                    context,
                    () async => (await ref.read(appRepositoryProvider.future))
                        .declineConnectionRequest(r.id),
                    errorLabel: 'Could not decline request',
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _OutgoingRequests extends StatelessWidget {
  const _OutgoingRequests();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final reqsAsync = ref.watch(outgoingRequestsProvider);
        return reqsAsync.when(
          loading: () => const SliverToBoxAdapter(child: ShimmerRows(count: 1)),
          error: (e, _) => SliverToBoxAdapter(
            child: LoadError.compact(
              message: 'Could not load requests',
              onRetry: () {
                ref.invalidate(appRepositoryProvider);
                ref.invalidate(outgoingRequestsProvider);
              },
            ),
          ),
          data: (reqs) {
            if (reqs.isEmpty) {
              return const SliverToBoxAdapter(
                child: _EmptyRow(
                  icon: Icons.send_outlined,
                  title: 'No outgoing requests',
                  subtitle: 'Invites you send will appear here.',
                ),
              );
            }
            return SliverList.builder(
              itemCount: reqs.length,
              itemBuilder: (itemContext, i) {
                final r = reqs[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        r.toName.isEmpty ? '?' : r.toName[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(r.toName,
                        style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text(
                      'Waiting for response',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    trailing: TextButton(
                      onPressed: () => runGuarded(
                        context,
                        () async =>
                            (await ref.read(appRepositoryProvider.future))
                                .cancelConnectionRequest(r.id),
                        errorLabel: 'Could not cancel request',
                      ),
                      child: const Text('Cancel'),
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
}

class _Connections extends StatelessWidget {
  const _Connections();

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
            if (friends.isEmpty) {
              return const SliverToBoxAdapter(
                child: _EmptyRow(
                  icon: Icons.people_outline,
                  title: 'No friends yet',
                  subtitle: 'Invite friends to start splitting bills together.',
                ),
              );
            }
            return SliverList.builder(
              itemCount: friends.length,
              itemBuilder: (itemContext, i) {
                final f = friends[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        f.initials,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(f.displayName,
                        style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text(
                      f.email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.person_remove_outlined),
                      onPressed: () => _confirmRemove(context, ref, myUid, f),
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

class _IncomingCard extends StatelessWidget {
  const _IncomingCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final ConnectionRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        // Name on top, actions on their own row: side-by-side
        // buttons squeeze the name out at large text scales.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.primary,
                  child: Text(
                    request.fromName.isEmpty
                        ? '?'
                        : request.fromName[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.fromName,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        'wants to connect with you',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDecline,
                  child: const Text('Decline'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onAccept,
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
                Navigator.of(context).pop();
                final name = ref.read(addFriendProvider).found?.displayName ??
                    'your friend';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err ?? 'Invite sent to $name.')),
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
