import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/app_repository.dart';
import '../models/models.dart';
import '../utils/money.dart';
import 'core_providers.dart';
import 'data_providers.dart';

part 'form_providers.g.dart';

// ---------------------------------------------------------------------------
// Sign in
// ---------------------------------------------------------------------------

/// Holds the in-progress state of the Google sign-in button.
@riverpod
class SignIn extends _$SignIn {
  @override
  bool build() => false;

  /// Returns null on success, an error message otherwise.
  Future<String?> signIn() async {
    state = true;
    try {
      final user = await ref.read(authServiceProvider).signInWithGoogle();
      if (user != null) {
        await ref.read(notificationServiceProvider).init(user.uid);
      }
      return null;
    } catch (e) {
      return 'Sign-in failed: $e';
    } finally {
      state = false;
    }
  }
}

// ---------------------------------------------------------------------------
// Create bill form
// ---------------------------------------------------------------------------

class CreateBillFormState {
  final String title;
  final String subtotal; // raw text from the field
  final double tipPercent;
  final String? groupId;
  final Set<String> selected; // uids to split between
  final String splitType; // equal | percentage | custom
  final Map<String, String> percents; // uid -> raw text
  final Map<String, String> amounts; // uid -> raw text
  final bool saving;
  final String? selectionInitializedFor; // groupId (or 'friends') or null

  /// Local path of the compressed receipt photo (optional), stored in the
  /// app documents folder until SyncService uploads it to Firebase Storage.
  final String? receiptPath;

  /// True while the camera/gallery picker or compression is running.
  final bool receiptBusy;

  const CreateBillFormState({
    this.title = '',
    this.subtotal = '',
    this.tipPercent = 15,
    this.groupId,
    this.selected = const {},
    this.splitType = 'equal',
    this.percents = const {},
    this.amounts = const {},
    this.saving = false,
    this.selectionInitializedFor,
    this.receiptPath,
    this.receiptBusy = false,
  });

  double get subtotalValue =>
      double.tryParse(subtotal.replaceAll(',', '.')) ?? 0;

  double get total => subtotalValue * (1 + tipPercent / 100);

  CreateBillFormState copyWith({
    String? title,
    String? subtotal,
    double? tipPercent,
    Set<String>? selected,
    String? splitType,
    Map<String, String>? percents,
    Map<String, String>? amounts,
    bool? saving,
    String? selectionInitializedFor,
    String? receiptPath,
    bool clearReceipt = false,
    bool? receiptBusy,
  }) {
    return CreateBillFormState(
      title: title ?? this.title,
      subtotal: subtotal ?? this.subtotal,
      tipPercent: tipPercent ?? this.tipPercent,
      groupId: groupId,
      selected: selected ?? this.selected,
      splitType: splitType ?? this.splitType,
      percents: percents ?? this.percents,
      amounts: amounts ?? this.amounts,
      saving: saving ?? this.saving,
      selectionInitializedFor:
          selectionInitializedFor ?? this.selectionInitializedFor,
      receiptPath: clearReceipt ? null : (receiptPath ?? this.receiptPath),
      receiptBusy: receiptBusy ?? this.receiptBusy,
    );
  }
}

@riverpod
class CreateBillForm extends _$CreateBillForm {
  @override
  CreateBillFormState build() => const CreateBillFormState();

  void setTitle(String v) => state = state.copyWith(title: v);

  void setSubtotal(String v) => state = state.copyWith(subtotal: v);

  void setTip(double v) => state = state.copyWith(tipPercent: v);

  void setSplitType(String v) => state = state.copyWith(splitType: v);

  /// Switching groups resets the selection; the UI re-runs [autoSelect]
  /// when the new member list arrives. (The receipt photo is kept —
  /// it belongs to the bill, not the group.)
  void setGroup(String? id) {
    state = CreateBillFormState(
      title: state.title,
      subtotal: state.subtotal,
      tipPercent: state.tipPercent,
      groupId: id,
      splitType: state.splitType,
      receiptPath: state.receiptPath,
    );
  }

  void toggleMember(String uid, bool selected) {
    final next = Set<String>.of(state.selected);
    if (selected) {
      next.add(uid);
    } else {
      next.remove(uid);
    }
    state = state.copyWith(selected: next);
  }

  void setPercent(String uid, String v) {
    final next = Map<String, String>.of(state.percents)..[uid] = v;
    state = state.copyWith(percents: next);
  }

  void setAmount(String uid, String v) {
    final next = Map<String, String>.of(state.amounts)..[uid] = v;
    state = state.copyWith(amounts: next);
  }

  /// Picks a receipt photo from the gallery or camera, compresses it
  /// (max 1280px, JPEG quality 70 — typically 150–300 KB instead of
  /// several MB) and stores it in the app documents folder until sync
  /// uploads it. Returns null on success/cancel, an error otherwise.
  Future<String?> pickReceipt(ImageSource source) async {
    if (state.receiptBusy) return null;
    state = state.copyWith(receiptBusy: true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (picked == null) return null; // user cancelled
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'receipts'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final target = p.join(
        dir.path,
        'receipt_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      final compressed = await FlutterImageCompress.compressAndGetFile(
        picked.path,
        target,
        minWidth: 1280,
        minHeight: 1280,
        quality: 70,
        format: CompressFormat.jpeg,
      );
      final path = compressed?.path ?? picked.path;
      final old = state.receiptPath;
      if (old != null && old != path) {
        try {
          await File(old).delete();
        } catch (_) {}
      }
      state = state.copyWith(receiptPath: path);
      return null;
    } catch (e) {
      return 'Could not attach photo: $e';
    } finally {
      state = state.copyWith(receiptBusy: false);
    }
  }

  /// Removes the attached receipt photo (and its temp file).
  Future<void> removeReceipt() async {
    final path = state.receiptPath;
    state = state.copyWith(clearReceipt: true);
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  /// Pre-selects members the first time a member list loads for the current
  /// group choice: everyone in group mode, just me in friends mode.
  /// Called from the UI via `ref.listen`; never clobbers manual choices.
  void autoSelect(List<AppUser> members) {
    final key = state.groupId ?? '__friends__';
    if (state.selectionInitializedFor == key || members.isEmpty) return;
    final uid = ref.read(currentUidProvider);
    final selected = state.groupId != null
        ? members.map((m) => m.uid).toSet()
        : members.where((m) => m.uid == uid).map((m) => m.uid).toSet();
    state = state.copyWith(
      selected: selected,
      selectionInitializedFor: key,
    );
  }

  /// Validates and creates the bill. Returns null on success, an error
  /// message otherwise.
  Future<String?> submit() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return 'Not signed in.';
    final members =
        ref.read(createBillMembersProvider).value ?? const <AppUser>[];
    final selectedMembers =
        members.where((m) => state.selected.contains(m.uid)).toList();

    if (state.title.trim().isEmpty) return 'Give the bill a title.';
    if (state.subtotalValue <= 0) return 'Enter the bill amount.';
    if (selectedMembers.isEmpty) return 'Select at least one person.';

    late final AppRepository repo;
    late final AppUser me;
    // The bill's currency: the group's currency when splitting in a
    // group, otherwise my default currency (Profile → settings).
    var currency = 'USD';
    String? groupName;
    try {
      repo = await ref.read(appRepositoryProvider.future);
      final profile = await repo.getUser(uid);
      if (profile == null) return 'Profile not found.';
      me = profile;
      currency = me.currencyCode;
      if (state.groupId != null) {
        final groups = await ref.read(myGroupsProvider.future);
        for (final g in groups) {
          if (g.id == state.groupId) {
            groupName = g.name;
            currency = g.currency;
          }
        }
      }
    } catch (e) {
      return 'Could not create bill: $e';
    }

    final total = state.total;
    final splits = <BillSplit>[];

    if (state.splitType == 'equal') {
      // Whole cents so shares always add up exactly.
      final totalCents = (total * 100).round();
      final base = totalCents ~/ selectedMembers.length;
      final remainder = totalCents % selectedMembers.length;
      for (var i = 0; i < selectedMembers.length; i++) {
        splits.add(BillSplit(
          uid: selectedMembers[i].uid,
          displayName: selectedMembers[i].displayName,
          amount: (base + (i < remainder ? 1 : 0)) / 100,
        ));
      }
    } else if (state.splitType == 'percentage') {
      double sum = 0;
      final pcts = <String, double>{};
      for (final m in selectedMembers) {
        final p =
            double.tryParse((state.percents[m.uid] ?? '').replaceAll(',', '.'));
        if (p == null || p < 0) {
          return 'Enter a valid percentage for ${m.displayName}.';
        }
        pcts[m.uid] = p;
        sum += p;
      }
      if ((sum - 100).abs() > 0.01) {
        return 'Percentages add up to ${sum.toStringAsFixed(1)}% — they must total 100%.';
      }
      for (final m in selectedMembers) {
        splits.add(BillSplit(
          uid: m.uid,
          displayName: m.displayName,
          amount: (total * pcts[m.uid]! / 100 * 100).round() / 100,
          percent: pcts[m.uid],
        ));
      }
    } else {
      double sum = 0;
      final amts = <String, double>{};
      for (final m in selectedMembers) {
        final a =
            double.tryParse((state.amounts[m.uid] ?? '').replaceAll(',', '.'));
        if (a == null || a < 0) {
          return 'Enter a valid amount for ${m.displayName}.';
        }
        amts[m.uid] = a;
        sum += a;
      }
      if ((sum - total).abs() > 0.02) {
        return 'Custom amounts total ${formatMoney(sum, currency)} but the bill is ${formatMoney(total, currency)}.';
      }
      for (final m in selectedMembers) {
        splits.add(BillSplit(
          uid: m.uid,
          displayName: m.displayName,
          amount: (amts[m.uid]! * 100).round() / 100,
        ));
      }
    }

    state = state.copyWith(saving: true);
    try {
      // Local-first: the bill is created in SQLite instantly (works
      // offline) and queued for Firestore sync in the background.
      await repo.createBill(
        title: state.title.trim(),
        subtotal: (state.subtotalValue * 100).round() / 100,
        tipPercent: state.tipPercent,
        creator: me,
        groupId: state.groupId,
        groupName: groupName,
        splitType: state.splitType,
        splits: splits,
        receiptLocalPath: state.receiptPath,
        currency: currency,
      );
      return null;
    } catch (e) {
      return 'Could not create bill: $e';
    } finally {
      state = state.copyWith(saving: false);
    }
  }
}

/// The currency a new bill will be created in, for display while the
/// form is filled: the selected group's currency, or my default
/// currency for friend bills. Mirrors the resolution in
/// [CreateBillForm.submit].
@riverpod
String billFormCurrency(Ref ref) {
  final uid = ref.watch(currentUidProvider);
  final groupId = ref.watch(createBillFormProvider.select((s) => s.groupId));
  if (groupId != null) {
    final groups = ref.watch(myGroupsProvider).value ?? const <BillGroup>[];
    for (final g in groups) {
      if (g.id == groupId) return g.currency;
    }
  }
  if (uid == null) return 'USD';
  return ref.watch(currentAppUserProvider).value?.currencyCode ?? 'USD';
}

/// People available to split with: group members, or me + my connections.
@riverpod
Future<List<AppUser>> createBillMembers(Ref ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const [];
  final groupId = ref.watch(createBillFormProvider.select((s) => s.groupId));
  if (groupId != null) {
    return ref.watch(groupMembersProvider(groupId).future);
  }
  final repo = await ref.watch(appRepositoryProvider.future);
  final me = await repo.getUser(uid);
  final conns = await repo.fetchConnections();
  return [if (me != null) me, ...conns];
}

// ---------------------------------------------------------------------------
// Create group form
// ---------------------------------------------------------------------------

class CreateGroupFormState {
  final String name;
  final Set<String> selected;
  final bool saving;

  /// The group's currency (ISO code). Null means "use my default" —
  /// resolved at submit time.
  final String? currency;

  const CreateGroupFormState({
    this.name = '',
    this.selected = const {},
    this.saving = false,
    this.currency,
  });

  CreateGroupFormState copyWith({
    String? name,
    Set<String>? selected,
    bool? saving,
    String? currency,
  }) {
    return CreateGroupFormState(
      name: name ?? this.name,
      selected: selected ?? this.selected,
      saving: saving ?? this.saving,
      currency: currency ?? this.currency,
    );
  }
}

@riverpod
class CreateGroupForm extends _$CreateGroupForm {
  @override
  CreateGroupFormState build() => const CreateGroupFormState();

  void setName(String v) => state = state.copyWith(name: v);

  /// The currency picked for the group (see the currency picker row on
  /// the create-group screen). Null = fall back to my default.
  void setCurrency(String code) => state = state.copyWith(currency: code);

  void toggle(String uid, bool selected) {
    final next = Set<String>.of(state.selected);
    if (selected) {
      next.add(uid);
    } else {
      next.remove(uid);
    }
    state = state.copyWith(selected: next);
  }

  /// Returns null on success, an error message otherwise.
  Future<String?> submit() async {
    final name = state.name.trim();
    if (name.isEmpty) return 'Give the group a name.';
    final uid = ref.read(currentUidProvider);
    if (uid == null) return 'Not signed in.';
    state = state.copyWith(saving: true);
    try {
      final repo = await ref.read(appRepositoryProvider.future);
      final me = await repo.getUser(uid);
      if (me == null) return 'Profile not found.';
      final connections = await ref.read(connectionsProvider.future);
      final invitees =
          connections.where((c) => state.selected.contains(c.uid)).toList();
      // Created locally (works offline); invites are queued behind it.
      final groupId = await repo.createGroup(
        name: name,
        creator: me,
        invitees: invitees,
        currency: state.currency ?? me.currencyCode,
      );
      for (final u in invitees) {
        await repo.sendNotification(
          toUid: u.uid,
          title: 'Group invite',
          body: '${me.displayName} invited you to join "$name".',
          type: 'group_invite',
          groupId: groupId,
        );
      }
      return null;
    } catch (e) {
      return 'Could not create group: $e';
    } finally {
      state = state.copyWith(saving: false);
    }
  }
}

// ---------------------------------------------------------------------------
// Add friend dialog
// ---------------------------------------------------------------------------

class AddFriendState {
  final String email;
  final bool searching;
  final AppUser? found;
  final String? error;

  const AddFriendState({
    this.email = '',
    this.searching = false,
    this.found,
    this.error,
  });

  AddFriendState copyWith({
    String? email,
    bool? searching,
    AppUser? found,
    String? error,
  }) {
    return AddFriendState(
      email: email ?? this.email,
      searching: searching ?? this.searching,
      found: found,
      error: error,
    );
  }
}

@riverpod
class AddFriend extends _$AddFriend {
  @override
  AddFriendState build() => const AddFriendState();

  void setEmail(String v) =>
      state = state.copyWith(email: v, found: null, error: null);

  Future<void> search() async {
    final email = state.email.trim();
    if (email.isEmpty) return;
    final myEmail = ref.read(firebaseAuthProvider).currentUser?.email ?? '';
    if (email.toLowerCase() == myEmail.toLowerCase()) {
      state = state.copyWith(error: 'That is your own email.');
      return;
    }
    state = state.copyWith(searching: true, error: null, found: null);
    try {
      // Needs the network; fails gracefully offline.
      final repo = await ref.read(appRepositoryProvider.future);
      final user = await repo.getUserByEmail(email);
      state = state.copyWith(
        searching: false,
        found: user,
        error: user == null ? 'No Splitwize account found for $email.' : null,
      );
    } catch (e) {
      state = state.copyWith(searching: false, error: 'Search failed: $e');
    }
  }

  /// Returns null on success, an error message otherwise.
  Future<String?> sendInvite() async {
    final found = state.found;
    final uid = ref.read(currentUidProvider);
    if (found == null || uid == null) return 'Nothing to send.';
    try {
      final repo = await ref.read(appRepositoryProvider.future);
      final me = await repo.getUser(uid);
      if (me == null) return 'Profile not found.';
      // Queued locally — the request is visible immediately and sent
      // to Firestore when the device is back online.
      await repo.sendConnectionRequest(from: me, to: found);
      await repo.sendNotification(
        toUid: found.uid,
        title: 'New friend request',
        body: '${me.displayName} wants to connect with you on Splitwize.',
        type: 'friend_request',
      );
      return null;
    } catch (e) {
      return 'Could not send invite: $e';
    }
  }
}

// ---------------------------------------------------------------------------
// Group invite dialog selection
// ---------------------------------------------------------------------------

/// Uids ticked inside the "invite to group" dialog.
@riverpod
class GroupInviteSelection extends _$GroupInviteSelection {
  @override
  Set<String> build() => {};

  void toggle(String uid, bool selected) {
    final next = Set<String>.of(state);
    if (selected) {
      next.add(uid);
    } else {
      next.remove(uid);
    }
    state = next;
  }

  void clear() => state = {};
}

// ---------------------------------------------------------------------------
// Onboarding flow (shown once per install)
// ---------------------------------------------------------------------------

class OnboardingFlowState {
  final int page;

  const OnboardingFlowState({this.page = 0});

  OnboardingFlowState copyWith({int? page}) =>
      OnboardingFlowState(page: page ?? this.page);
}

/// Drives the 3-page onboarding: owns the [PageController] (so the
/// screen itself can stay a StatelessWidget) and the current page
/// index used for the dots, background tint and button labels.
@riverpod
class OnboardingFlow extends _$OnboardingFlow {
  late final PageController _controller;

  PageController get controller => _controller;

  @override
  OnboardingFlowState build() {
    _controller = PageController();
    ref.onDispose(_controller.dispose);
    return const OnboardingFlowState();
  }

  void onPageChanged(int index) => state = state.copyWith(page: index);

  void next() => _controller.animateToPage(
        state.page + 1,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );

  void previous() => _controller.animateToPage(
        state.page - 1,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
}
