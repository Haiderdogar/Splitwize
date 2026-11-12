import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:splitwize/providers/core_providers.dart';
import 'package:splitwize/providers/onboarding_motion_provider.dart';
import 'package:splitwize/screens/onboarding_screen.dart';
import 'package:splitwize/services/secure_storage_service.dart';
import 'package:splitwize/theme.dart';

class _OnboardingStorage extends Fake implements SecureStorageService {
  bool seen = false;
  int writes = 0;

  @override
  Future<bool> isOnboardingSeen() async => seen;

  @override
  Future<void> markOnboardingSeen() async {
    writes++;
    seen = true;
  }
}

Future<void> _pumpOnboarding(
  WidgetTester tester, {
  _OnboardingStorage? storage,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool dark = false,
  bool reducedMotion = false,
  bool gateCompletion = false,
  bool tickerEnabled = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        secureStorageServiceProvider
            .overrideWith((ref) => storage ?? _OnboardingStorage()),
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
          child: gateCompletion
              ? Consumer(
                  builder: (context, ref, child) =>
                      ref.watch(onboardingSeenProvider).value == true
                          ? const Scaffold(body: Text('Ready to sign in'))
                          : const OnboardingScreen(),
                )
              : const OnboardingScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.text('Continue'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
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

void main() {
  setUpAll(_loadAppFont);

  testWidgets('Continue, Back and swiping keep onboarding navigation in sync',
      (tester) async {
    addTearDown(tester.view.reset);
    await _pumpOnboarding(tester);
    expect(find.text('Good times.\nFair shares.'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);

    await _continue(tester);
    expect(find.text('Less chasing.\nMore living.'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Good times.\nFair shares.'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-340, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Less chasing.\nMore living.'), findsOneWidget);

    await _continue(tester);
    expect(find.text('Go anywhere.\nStay in sync.'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Page indicators navigate directly and announce current page',
      (tester) async {
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    try {
      await _pumpOnboarding(tester);
      expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Go to page 3'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('Get started'), findsOneWidget);
      expect(find.bySemanticsLabel('Page 3 of 3'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Go to page 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Skip persists onboarding completion and exits the flow',
      (tester) async {
    addTearDown(tester.view.reset);
    final storage = _OnboardingStorage();
    await _pumpOnboarding(tester, storage: storage, gateCompletion: true);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(storage.seen, isTrue);
    expect(storage.writes, 1);
    expect(find.text('Ready to sign in'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Get started persists completion after the final page',
      (tester) async {
    addTearDown(tester.view.reset);
    final storage = _OnboardingStorage();
    await _pumpOnboarding(tester, storage: storage, gateCompletion: true);
    await _continue(tester);
    await _continue(tester);

    expect(storage.seen, isFalse);
    await tester.tap(find.text('Get started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(storage.seen, isTrue);
    expect(storage.writes, 1);
    expect(find.text('Ready to sign in'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced motion stops recurring animation on every page',
      (tester) async {
    addTearDown(tester.view.reset);
    await _pumpOnboarding(tester, reducedMotion: true);
    for (var page = 0; page < 3; page++) {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
      if (page < 2) await _continue(tester);
    }
  });

  testWidgets('Illustrations pause in the background and resume in foreground',
      (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(() => tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    await _pumpOnboarding(tester);
    final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingScreen)));
    final animation = container.read(onboardingMotionProvider).animation;
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

  testWidgets('TickerMode suspends illustration animation when route is hidden',
      (tester) async {
    addTearDown(tester.view.reset);
    await _pumpOnboarding(tester, tickerEnabled: false);
    var container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingScreen)));
    expect(container.read(onboardingMotionProvider).animation.isAnimating,
        isFalse);
    await tester.pumpAndSettle();

    await _pumpOnboarding(tester);
    container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingScreen)));
    expect(
        container.read(onboardingMotionProvider).animation.isAnimating, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  const viewports = <({String name, Size size, double scale})>[
    (name: 'regular phone', size: Size(390, 844), scale: 1),
    (name: 'narrow phone', size: Size(320, 568), scale: 1),
    (name: 'large text', size: Size(320, 568), scale: 2),
    (name: 'landscape', size: Size(640, 360), scale: 1.6),
    (name: 'tablet', size: Size(1024, 768), scale: 2),
  ];

  for (final viewport in viewports) {
    for (final dark in [false, true]) {
      testWidgets(
          'All pages fit ${viewport.name} in ${dark ? 'dark' : 'light'} mode',
          (tester) async {
        addTearDown(tester.view.reset);
        await _pumpOnboarding(
          tester,
          size: viewport.size,
          textScale: viewport.scale,
          dark: dark,
        );
        for (var page = 0; page < 3; page++) {
          expect(tester.takeException(), isNull,
              reason: 'Page ${page + 1} must fit without overflow');
          final action = find.text(page < 2 ? 'Continue' : 'Get started');
          expect(action.hitTestable(), findsOneWidget,
              reason: 'Primary action must remain reachable');
          if (page < 2) await _continue(tester);
        }
      });
    }
  }
}
