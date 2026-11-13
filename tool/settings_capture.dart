// Run: flutter test --no-pub tool/settings_capture.dart.
// Recreates Settings and branding review images from local fixture data.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/providers/core_providers.dart';
import 'package:splitwize/providers/monetization_providers.dart';
import 'package:splitwize/screens/home_shell.dart';
import 'package:splitwize/screens/settings_screen.dart';
import 'package:splitwize/theme.dart';
import 'package:splitwize/widgets/app_drawer.dart';

import '../test/responsive_overflow_test.dart' as fixture;

class _Appearance extends ThemeModeSetting {
  @override
  Future<AppTheme> build() async => AppTheme.system;

  @override
  Future<void> setMode(AppTheme mode) async {
    state = AsyncData(mode);
  }
}

class _Subscription extends AdFreeStatus {
  @override
  Future<bool> build() async => false;
}

void main() {
  setUpAll(() async {
    await fixture.loadRoboto();
    var sdkDirectory = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 5; i++) {
      sdkDirectory = sdkDirectory.parent;
    }
    final bytes = await File('${sdkDirectory.path}/bin/cache/artifacts/'
            'material_fonts/materialicons-regular.otf')
        .readAsBytes();
    await (FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.view(bytes.buffer))))
        .load();
  });

  testWidgets('capture Settings and app branding', (tester) async {
    addTearDown(tester.view.reset);
    final boundaryKey = GlobalKey();

    Future<void> pumpScreen(Widget screen, {
      ThemeMode mode = ThemeMode.light,
      Size size = const Size(390, 844),
      double textScale = 1,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...fixture.testOverrides(),
          notificationAuthorizationStatusProvider
              .overrideWith((ref) async => AuthorizationStatus.authorized),
          themeModeSettingProvider.overrideWith(_Appearance.new),
          adFreeStatusProvider.overrideWith(_Subscription.new),
        ],
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: splitwizeLightTheme,
            darkTheme: splitwizeDarkTheme,
            themeMode: mode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: screen,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.runAsync(() => precacheImage(
        const AssetImage('assets/icon/app_icon.png'),
        tester.element(find.byType(MaterialApp)),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> capture(String name) => tester.runAsync(() async {
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final screenshot = await boundary.toImage(pixelRatio: 2);
      final bytes = (await screenshot.toByteData(format: ui.ImageByteFormat.png))!;
      await Directory('docs').create(recursive: true);
      await File('docs/$name.png').writeAsBytes(bytes.buffer.asUint8List());
      screenshot.dispose();
    });

    await pumpScreen(const SettingsScreen());
    await capture('settings-after');
    await tester.scrollUntilVisible(find.text('Log out'), 300);
    await tester.pumpAndSettle();
    await capture('settings-after-bottom');
    await tester.scrollUntilVisible(find.text('Appearance'), -250);
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await capture('settings-after-appearance');

    await pumpScreen(const SettingsScreen(), mode: ThemeMode.dark);
    await capture('settings-after-dark');
    await pumpScreen(const SettingsScreen(),
        size: const Size(320, 700), textScale: 1.4);
    await capture('settings-after-small');
    await tester.scrollUntilVisible(find.text('Log out'), 250);
    await tester.pumpAndSettle();
    await capture('settings-after-small-bottom');

    await pumpScreen(const SettingsScreen(),
        size: const Size(320, 568), textScale: 2);
    await capture('settings-after-large-text');
    await tester.scrollUntilVisible(find.text('Log out'), 250);
    await tester.pumpAndSettle();
    await capture('settings-after-large-text-bottom');

    await pumpScreen(const HomeShell());
    await capture('home-branding');
    splitwizeScaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
    await capture('drawer-branding');

    await pumpScreen(const HomeShell(), mode: ThemeMode.dark);
    splitwizeScaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
    await capture('drawer-branding-dark');
    expect(tester.takeException(), isNull);
  });
}
