import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../widgets/group_invitation_card.dart';
import '../widgets/state_widgets.dart';
import 'group_detail_screen.dart';

class GroupInvitationScreen extends ConsumerStatefulWidget {
  const GroupInvitationScreen({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<GroupInvitationScreen> createState() =>
      _GroupInvitationScreenState();
}

class _GroupInvitationScreenState extends ConsumerState<GroupInvitationScreen> {
  bool _loading = true;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final sync = await ref.read(syncServiceProvider.future);
      await sync.refreshGroupInvitation(widget.groupId);
      if (mounted) ref.invalidate(groupProvider(widget.groupId));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncGroup = ref.watch(groupProvider(widget.groupId));
    final uid = ref.watch(currentUidProvider) ?? '';
    final group = asyncGroup.value;
    if (!_loading &&
        !_failed &&
        group != null &&
        !group.deleted &&
        group.members.contains(uid)) {
      return GroupDetailScreen(groupId: widget.groupId);
    }
    return Scaffold(
      appBar: AppBar(
          title: const Text('Incoming group invitation',
              maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: _loading || asyncGroup.isLoading
          ? const ShimmerDetail()
          : _failed || asyncGroup.hasError
              ? LoadError(
                  message: 'Could not load this invitation.', onRetry: _refresh)
              : group == null || group.deleted || !group.invited.contains(uid)
                  ? const Center(
                      child: Text('This invitation is no longer available.'))
                  : ListView(padding: const EdgeInsets.all(16), children: [
                      GroupInvitationCard(group: group, recipientUid: uid),
                    ]),
    );
  }
}
