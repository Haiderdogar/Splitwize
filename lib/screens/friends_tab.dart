import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../providers/form_providers.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_notification_button.dart';
import '../widgets/studio_ui.dart';
import '../widgets/state_widgets.dart';

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const SplitwizeMenuButton(),
        title: const Text('Friends'),
        actions: const [AppNotificationButton(), SizedBox(width: 5)],
      ),
      // Connected friends only; requests have their own tab.
      body: CustomScrollView(
        slivers: [
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverToBoxAdapter(child: _ConnectedHeader()),
          ),
          // Search only becomes visible for longer friend lists.
          SliverToBoxAdapter(child: Consumer(
            builder: (context, ref, _) {
              final count = ref.watch(connectionsProvider)
                  .value?.length ?? 0;
              if (count < 8) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search friends',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              );
            },
          )),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: _Connections(query: _query),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'friends-add-friend',
        tooltip: 'Add friend',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _AddFriendDialog(),
        ),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add friend'),
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

class _ConnectedHeader extends StatelessWidget {
  const _ConnectedHeader();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final count =
            ref.watch(connectionsProvider.select((v) => v.value?.length ?? 0));
        return _SectionHeader('Connected', count: count);
      },
    );
  }
}

/// Empty-state row for a user's connections list.
class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.icon, required this.title,
    required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => SoftPanel(
    padding: const EdgeInsets.all(13),
    child: Row(children: [
      PersonMark(initials: '', icon: icon, size: 44),
      const SizedBox(width: 12),
      Expanded(child: Column(
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
  const _Connections({required this.query});

  final String query;

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
            final lower = query.trim().toLowerCase();
            final visible = [
              for (final friend in friends)
                if (lower.isEmpty ||
                    friend.displayName.toLowerCase().contains(lower) ||
                    friend.email.toLowerCase().contains(lower))
                  friend,
            ]..sort((a, b) => a.displayName.toLowerCase()
                .compareTo(b.displayName.toLowerCase()));
            if (visible.isEmpty) {
              return const SliverToBoxAdapter(
                child: _EmptyRow(
                  icon: Icons.people_outline,
                  title: lower.isEmpty ? 'No friends yet' : 'No matches',
                  subtitle: lower.isEmpty
                      ? 'Invite friends to start splitting bills together.'
                      : 'Try a different name or email.',
                ),
              );
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
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text(
                      f.email,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'More options for ${f.displayName}',
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (choice) {
                        if (choice == 'remove') {
                          _confirmRemove(context, ref, myUid, f);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove friend'),
                        ),
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
class _AddFriendDialog extends StatefulWidget {
  const _AddFriendDialog();

  @override
  State<_AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<_AddFriendDialog> {
  String? _sendError;
  bool _sending = false;

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
                onChanged: (v) {
                  ref.read(addFriendProvider.notifier).setEmail(v);
                  if (_sendError != null) setState(() => _sendError = null);
                },
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
            if (_sendError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_sendError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
              onPressed: _sending ? null : () async {
                setState(() { _sending = true; _sendError = null; });
                final name = ref.read(addFriendProvider).found?.displayName ??
                    'your friend';
                final err = await notifier.sendInvite();
                if (!mounted) return;
                if (err != null) {
                  setState(() { _sending = false; _sendError = err; });
                  return; // Keep the dialog and the searched email for retry.
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invite sent to $name.')),
                );
                Navigator.of(context).pop();
              },
              child: Text(_sending ? 'Sending...' : 'Send invite'),
            );
          },
        ),
      ],
    );
  }
}
