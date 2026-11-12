import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:splitwize/providers/form_providers.dart';
import 'package:splitwize/providers/sign_in_motion_provider.dart';
import 'package:splitwize/screens/sign_in_screen.dart';
import 'package:splitwize/theme.dart';

class _ControlledSignIn extends SignIn {
  final result = Completer<String?>();
  int calls = 0;

  @override
  bool build() => false;

  @override
  Future<String?> signIn() async {
    calls++;
    state = true;
    try {
      return await result.future;
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

Future<void> _loadAppFont() async {
  var flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null || flutterRoot.isEmpty) {
    var directory = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 5; i++) {
      directory = directory.parent;
    }
    flutterRoot = directory.path;
  }
  final loader = FontLoader('Roboto');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    final bytes = await File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-$weight.ttf',
    ).readAsBytes();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

Future<void> _pumpSignIn(
  WidgetTester tester, {
  _ControlledSignIn? signIn,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool dark = false,
  bool reducedMotion = false,
  bool tickerEnabled = true,
  Duration entryElapsed = const Duration(milliseconds: 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        signInProvider.overrideWith(() => signIn ?? _ControlledSignIn()),
      ],
      child: MaterialApp(
        theme: splitwizeLightTheme,
        darkTheme: splitwizeDarkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reducedMotion,
          ),
          child: child!,
        ),
        home: TickerMode(
          enabled: tickerEnabled,
          child: const SignInScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  if (entryElapsed > Duration.zero) await tester.pump(entryElapsed);
}

Finder _googleButton() =>
    find.widgetWithText(FilledButton, 'Sign in with Google');

void main() {
  setUpAll(_loadAppFont);

  testWidgets('Sign-in becomes interactive only after its hidden reveal delay',
      (tester) async {
    addTearDown(tester.view.reset);
    final signIn = _ControlledSignIn();
    await _pumpSignIn(tester, signIn: signIn, entryElapsed: Duration.zero);
    await tester.pump(const Duration(milliseconds: 200));

    final buttonFocus =
        Focus.of(tester.element(find.text('Sign in with Google')));
    expect(_googleButton().hitTestable(), findsNothing);
    expect(buttonFocus.canRequestFocus, isFalse);
    buttonFocus.requestFocus();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(buttonFocus.hasFocus, isFalse);

    await tester.tapAt(tester.getCenter(_googleButton()));
    await tester.pump();
    expect(signIn.calls, 0,
        reason: 'An invisible action must not start Google sign-in');

    await tester.pump(const Duration(milliseconds: 1200));
    expect(_googleButton().hitTestable(), findsOneWidget);
    expect(buttonFocus.canRequestFocus, isTrue);
    buttonFocus.requestFocus();
    await tester.pump();
    expect(buttonFocus.hasFocus, isTrue);
    await tester.tap(_googleButton());
    await tester.pump();
    expect(signIn.calls, 1);
    signIn.result.complete(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Google sign-in disables repeat taps while awaiting the result',
      (tester) async {
    addTearDown(tester.view.reset);
    final signIn = _ControlledSignIn();
    await _pumpSignIn(tester, signIn: signIn);
    expect(find.text('Share the moments.\nNot the maths.'), findsOneWidget);
    expect(
      find.text('An account is created automatically on first sign-in.'),
      findsOneWidget,
    );
    await tester.ensureVisible(_googleButton());
    await tester.tap(_googleButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(signIn.calls, 1);
    expect(find.text('Signing you in...'), findsOneWidget);
    final busyButton = find.widgetWithText(FilledButton, 'Signing you in...');
    expect(tester.widget<FilledButton>(busyButton).onPressed, isNull);

    await tester.tap(busyButton);
    await tester.pump(const Duration(milliseconds: 200));
    expect(signIn.calls, 1);
    signIn.result.complete(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.widget<FilledButton>(_googleButton()).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Sign-in errors appear in a SnackBar and the button becomes usable',
      (tester) async {
    addTearDown(tester.view.reset);
    final signIn = _ControlledSignIn();
    await _pumpSignIn(tester, signIn: signIn);
    await tester.ensureVisible(_googleButton());
    await tester.tap(_googleButton());
    await tester.pump();
    signIn.result.complete('Sign-in failed: Please try again.');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Sign-in failed: Please try again.'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.widget<FilledButton>(_googleButton()).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancelling Google sign-in restores the action without an error',
      (tester) async {
    addTearDown(tester.view.reset);
    final signIn = _ControlledSignIn();
    await _pumpSignIn(tester, signIn: signIn);
    await tester.ensureVisible(_googleButton());
    await tester.tap(_googleButton());
    await tester.pump();
    signIn.result.complete(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.widget<FilledButton>(_googleButton()).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A sign-in result arriving after navigation does not show errors',
      (tester) async {
    addTearDown(tester.view.reset);
    final signIn = _ControlledSignIn();
    await _pumpSignIn(tester, signIn: signIn);
    await tester.ensureVisible(_googleButton());
    await tester.tap(_googleButton());
    await tester.pump();

    // AuthFlow replaces this route when Firebase reports a signed-in user,
    // potentially before the provider's pending future completes.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    signIn.result.complete('Sign-in failed: returned after navigation.');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(signIn.calls, 1);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced motion renders the sign-in illustration at rest',
      (tester) async {
    addTearDown(tester.view.reset);
    await _pumpSignIn(tester, reducedMotion: true);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
    final container =
        ProviderScope.containerOf(tester.element(find.byType(SignInScreen)));
    expect(container.read(signInMotionProvider).animation.isAnimating, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sign-in illustration pauses in background and resumes on return',
      (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(() => tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    await _pumpSignIn(tester);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(SignInScreen)));
    final animation = container.read(signInMotionProvider).animation;
    expect(animation.isAnimating, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final pausedValue = animation.value;
    await tester.pump(const Duration(milliseconds: 500));
    expect(animation.isAnimating, isFalse);
    expect(animation.value, pausedValue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(animation.isAnimating, isTrue);
    expect(animation.value, isNot(pausedValue));
    expect(tester.takeException(), isNull);
  });

  testWidgets('TickerMode hides sign-in motion and leaving disposes its ticker',
      (tester) async {
    addTearDown(tester.view.reset);
    await _pumpSignIn(tester, tickerEnabled: false);
    var container =
        ProviderScope.containerOf(tester.element(find.byType(SignInScreen)));
    expect(container.read(signInMotionProvider).animation.isAnimating, isFalse);
    await tester.pumpAndSettle();

    await _pumpSignIn(tester);
    container =
        ProviderScope.containerOf(tester.element(find.byType(SignInScreen)));
    expect(container.read(signInMotionProvider).animation.isAnimating, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  const sizes = <({String name, Size size})>[
    (name: 'narrow phone', size: Size(320, 568)),
    (name: 'regular phone', size: Size(390, 844)),
    (name: 'landscape', size: Size(640, 360)),
    (name: 'tablet', size: Size(1024, 768)),
  ];

  for (final viewport in sizes) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets(
            'Sign-in fits ${viewport.name} at ${scale}x in ${dark ? 'dark' : 'light'} mode',
            (tester) async {
          addTearDown(tester.view.reset);
          await _pumpSignIn(
            tester,
            size: viewport.size,
            textScale: scale,
            dark: dark,
          );
          expect(tester.takeException(), isNull,
              reason: 'The screen must render without overflow');
          await tester.ensureVisible(_googleButton());
          await tester.pump(const Duration(milliseconds: 300));
          expect(_googleButton().hitTestable(), findsOneWidget,
              reason: 'The sign-in action must remain reachable');
          expect(
              tester.getSize(_googleButton()).height, greaterThanOrEqualTo(48));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
