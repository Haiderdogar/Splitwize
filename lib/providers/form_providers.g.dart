// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'form_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the in-progress state of the Google sign-in button.

@ProviderFor(SignIn)
const signInProvider = SignInProvider._();

/// Holds the in-progress state of the Google sign-in button.
final class SignInProvider extends $NotifierProvider<SignIn, bool> {
  /// Holds the in-progress state of the Google sign-in button.
  const SignInProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'signInProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$signInHash();

  @$internal
  @override
  SignIn create() => SignIn();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$signInHash() => r'f96c57e4c6c77389e3d7fdcaa8c199d75a1c8383';

/// Holds the in-progress state of the Google sign-in button.

abstract class _$SignIn extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<bool, bool>, bool, Object?, Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(CreateBillForm)
const createBillFormProvider = CreateBillFormProvider._();

final class CreateBillFormProvider
    extends $NotifierProvider<CreateBillForm, CreateBillFormState> {
  const CreateBillFormProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'createBillFormProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$createBillFormHash();

  @$internal
  @override
  CreateBillForm create() => CreateBillForm();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CreateBillFormState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CreateBillFormState>(value),
    );
  }
}

String _$createBillFormHash() => r'6827fe7b83a1cbc6317395e378bc08bbd8a61414';

abstract class _$CreateBillForm extends $Notifier<CreateBillFormState> {
  CreateBillFormState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<CreateBillFormState, CreateBillFormState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<CreateBillFormState, CreateBillFormState>,
        CreateBillFormState,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

/// The currency a new bill will be created in, for display while the
/// form is filled: the selected group's currency, or my default
/// currency for friend bills. Mirrors the resolution in
/// [CreateBillForm.submit].

@ProviderFor(billFormCurrency)
const billFormCurrencyProvider = BillFormCurrencyProvider._();

/// The currency a new bill will be created in, for display while the
/// form is filled: the selected group's currency, or my default
/// currency for friend bills. Mirrors the resolution in
/// [CreateBillForm.submit].

final class BillFormCurrencyProvider
    extends $FunctionalProvider<String, String, String> with $Provider<String> {
  /// The currency a new bill will be created in, for display while the
  /// form is filled: the selected group's currency, or my default
  /// currency for friend bills. Mirrors the resolution in
  /// [CreateBillForm.submit].
  const BillFormCurrencyProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'billFormCurrencyProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$billFormCurrencyHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return billFormCurrency(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$billFormCurrencyHash() => r'b3f64fb83d48e62901d36ae752964bd51e1c3e7b';

/// People available to split with: group members, or me + my connections.

@ProviderFor(createBillMembers)
const createBillMembersProvider = CreateBillMembersProvider._();

/// People available to split with: group members, or me + my connections.

final class CreateBillMembersProvider extends $FunctionalProvider<
        AsyncValue<List<AppUser>>, List<AppUser>, FutureOr<List<AppUser>>>
    with $FutureModifier<List<AppUser>>, $FutureProvider<List<AppUser>> {
  /// People available to split with: group members, or me + my connections.
  const CreateBillMembersProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'createBillMembersProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$createBillMembersHash();

  @$internal
  @override
  $FutureProviderElement<List<AppUser>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<AppUser>> create(Ref ref) {
    return createBillMembers(ref);
  }
}

String _$createBillMembersHash() => r'87fecd40b7481ffd25b035d9731004160a477be2';

@ProviderFor(CreateGroupForm)
const createGroupFormProvider = CreateGroupFormProvider._();

final class CreateGroupFormProvider
    extends $NotifierProvider<CreateGroupForm, CreateGroupFormState> {
  const CreateGroupFormProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'createGroupFormProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$createGroupFormHash();

  @$internal
  @override
  CreateGroupForm create() => CreateGroupForm();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CreateGroupFormState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CreateGroupFormState>(value),
    );
  }
}

String _$createGroupFormHash() => r'c2863b3a9f7270d63c24aee739353d350d4bae62';

abstract class _$CreateGroupForm extends $Notifier<CreateGroupFormState> {
  CreateGroupFormState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<CreateGroupFormState, CreateGroupFormState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<CreateGroupFormState, CreateGroupFormState>,
        CreateGroupFormState,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(AddFriend)
const addFriendProvider = AddFriendProvider._();

final class AddFriendProvider
    extends $NotifierProvider<AddFriend, AddFriendState> {
  const AddFriendProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'addFriendProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$addFriendHash();

  @$internal
  @override
  AddFriend create() => AddFriend();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AddFriendState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AddFriendState>(value),
    );
  }
}

String _$addFriendHash() => r'138bed0def276524a95f4ab86ab78b854481dd70';

abstract class _$AddFriend extends $Notifier<AddFriendState> {
  AddFriendState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AddFriendState, AddFriendState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AddFriendState, AddFriendState>,
        AddFriendState,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

/// Uids ticked inside the "invite to group" dialog.

@ProviderFor(GroupInviteSelection)
const groupInviteSelectionProvider = GroupInviteSelectionProvider._();

/// Uids ticked inside the "invite to group" dialog.
final class GroupInviteSelectionProvider
    extends $NotifierProvider<GroupInviteSelection, Set<String>> {
  /// Uids ticked inside the "invite to group" dialog.
  const GroupInviteSelectionProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'groupInviteSelectionProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$groupInviteSelectionHash();

  @$internal
  @override
  GroupInviteSelection create() => GroupInviteSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$groupInviteSelectionHash() =>
    r'9f74e5729f9baa42b333c9ff9b82ae6713d787f7';

/// Uids ticked inside the "invite to group" dialog.

abstract class _$GroupInviteSelection extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<Set<String>, Set<String>>, Set<String>, Object?, Object?>;
    element.handleValue(ref, created);
  }
}

/// Drives the 3-page onboarding: owns the [PageController] (so the
/// screen itself can stay a StatelessWidget) and the current page
/// index used for the dots, background tint and button labels.

@ProviderFor(OnboardingFlow)
const onboardingFlowProvider = OnboardingFlowProvider._();

/// Drives the 3-page onboarding: owns the [PageController] (so the
/// screen itself can stay a StatelessWidget) and the current page
/// index used for the dots, background tint and button labels.
final class OnboardingFlowProvider
    extends $NotifierProvider<OnboardingFlow, OnboardingFlowState> {
  /// Drives the 3-page onboarding: owns the [PageController] (so the
  /// screen itself can stay a StatelessWidget) and the current page
  /// index used for the dots, background tint and button labels.
  const OnboardingFlowProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'onboardingFlowProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$onboardingFlowHash();

  @$internal
  @override
  OnboardingFlow create() => OnboardingFlow();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OnboardingFlowState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OnboardingFlowState>(value),
    );
  }
}

String _$onboardingFlowHash() => r'4087559db55ab4fe123a682df608c7b5abf87cbf';

/// Drives the 3-page onboarding: owns the [PageController] (so the
/// screen itself can stay a StatelessWidget) and the current page
/// index used for the dots, background tint and button labels.

abstract class _$OnboardingFlow extends $Notifier<OnboardingFlowState> {
  OnboardingFlowState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<OnboardingFlowState, OnboardingFlowState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<OnboardingFlowState, OnboardingFlowState>,
        OnboardingFlowState,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
