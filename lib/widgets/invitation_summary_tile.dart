import 'package:flutter/material.dart';

import '../models/models.dart';
import 'invitation_person_details.dart';

/// A short invitation summary that opens the selected invitation's details.
class InvitationSummaryTile extends StatelessWidget {
  const InvitationSummaryTile({
    super.key,
    required this.person,
    required this.incoming,
    required this.onTap,
    this.groupName,
  });

  final AppUser person;
  final bool incoming;
  final VoidCallback onTap;
  final String? groupName;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (groupName != null) ...[
                  Text('Group: $groupName',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                ],
                Text(incoming ? 'Invited by' : 'Invitation sent to',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: InvitationPersonDetails(person: person)),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ]),
              ],
            ),
          ),
        ),
      );
}
