import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/data_providers.dart';
import 'studio_ui.dart';

class InvitationPersonDetails extends ConsumerWidget {
  const InvitationPersonDetails({super.key, required this.person});
  final AppUser person;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cached = ref.watch(appUserProvider(person.uid)).value;
    final name = cached != null &&
            cached.displayName.trim().isNotEmpty &&
            cached.displayName.toLowerCase() != 'friend'
        ? cached.displayName
        : person.displayName;
    final email =
        cached?.email.trim().isNotEmpty == true ? cached!.email : person.email;
    final display = person.copyWith(
        displayName: name,
        email: email,
        photoUrl: cached?.photoUrl ?? person.photoUrl);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (display.photoUrl?.isNotEmpty == true)
        ClipOval(
            child: Image.network(display.photoUrl!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                semanticLabel: '${display.displayName} profile picture',
                errorBuilder: (context, error, stack) =>
                    PersonMark(initials: display.initials)))
      else
        PersonMark(initials: display.initials),
      const SizedBox(width: 12),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(display.displayName,
            style: Theme.of(context).textTheme.titleMedium),
        Text(display.email.isEmpty ? 'Email unavailable' : display.email,
            style: Theme.of(context).textTheme.bodySmall),
      ])),
    ]);
  }
}
