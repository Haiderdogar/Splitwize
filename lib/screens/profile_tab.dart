import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../utils/current_user_identity.dart';
import '../widgets/state_widgets.dart';
import '../widgets/studio_ui.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  Future<void> _editName(BuildContext context, String name) async {
    final saved = await showDialog<bool>(
        context: context, builder: (_) => _EditNameDialog(initialName: name));
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your name has been updated.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentAppUserProvider);
    final google = ref.watch(authStateChangesProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profile.when(
        loading: () => const ShimmerList(count: 2),
        error: (error, stack) => LoadError(
            message: 'Could not load your profile.',
            onRetry: () {
              ref.invalidate(appRepositoryProvider);
              ref.invalidate(currentAppUserProvider);
            }),
        data: (user) {
          final identity = resolveCurrentUserIdentity(
              cached: user,
              googleName: google?.displayName,
              googleEmail: google?.email);
          final photo = user?.photoUrl?.trim().isNotEmpty == true
              ? user!.photoUrl!.trim()
              : google?.photoURL?.trim() ?? '';
          final uid = ref.watch(currentUidProvider) ?? user?.uid ?? '';
          return SafeArea(
              child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Center(
                  child: photo.isEmpty
                      ? PersonMark(initials: identity.initials, size: 88)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.network(photo,
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                              semanticLabel: 'Your profile picture',
                              errorBuilder: (context, error, stack) =>
                                  PersonMark(
                                      initials: identity.initials, size: 88)))),
              const SizedBox(height: 20),
              const SectionHeading('Personal details'),
              SoftPanel(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Name',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 6),
                          Text(identity.name,
                              style: Theme.of(context).textTheme.titleMedium),
                        ])),
                    IconButton(
                        tooltip: 'Edit name',
                        onPressed: uid.isEmpty
                            ? null
                            : () => _editName(context, identity.name),
                        icon: const Icon(Icons.edit_outlined)),
                  ])),
              const SizedBox(height: 16),
              TextFormField(
                key: ValueKey('profile-email-${identity.email}'),
                initialValue: identity.email,
                readOnly: true,
                showCursor: false,
                maxLines: null,
                decoration: const InputDecoration(
                    labelText: 'Email',
                    helperText: 'Email cannot be edited.',
                    helperMaxLines: 2,
                    suffixIcon: Icon(Icons.lock_outline_rounded)),
              ),
            ],
          ));
        },
      ),
    );
  }
}

class _EditNameDialog extends ConsumerStatefulWidget {
  const _EditNameDialog({required this.initialName});
  final String initialName;
  @override
  ConsumerState<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends ConsumerState<_EditNameDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final name = _name.text.trim();
    if (name == widget.initialName.trim()) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = await ref.read(appRepositoryProvider.future);
      await repo.setMyDisplayName(name);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save your name. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Edit name'),
        content: SingleChildScrollView(
            child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                  key: const ValueKey('profile-name-input'),
                  controller: _name,
                  autofocus: true,
                  enabled: !_saving,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.isEmpty) return 'Enter your name.';
                    if (name.length > 100) {
                      return 'Use 100 characters or fewer.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _save()),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
            ],
          ),
        )),
        actions: [
          TextButton(
              onPressed:
                  _saving ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save')),
        ],
      );
}
