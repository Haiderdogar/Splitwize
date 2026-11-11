import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'core_providers.dart';
import 'data_providers.dart';

typedef OutgoingGroupInvitation = ({BillGroup group, String recipientUid});

final outgoingGroupInvitesProvider =
    Provider.autoDispose<AsyncValue<List<OutgoingGroupInvitation>>>((ref) {
  final uid = ref.watch(currentUidProvider);
  return ref.watch(myGroupsProvider).whenData((groups) => [
        for (final group in groups.where((group) => !group.deleted))
          for (final recipient in group.invited)
            if (!group.members.contains(recipient) &&
                (group.invitations[recipient]?.from.uid ?? group.createdBy) ==
                    uid)
              (group: group, recipientUid: recipient),
      ]);
});
