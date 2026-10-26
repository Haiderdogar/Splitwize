import 'dart:io';

import 'package:splitwize/providers/monetization_providers.dart';
import 'package:splitwize/widgets/paywall_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdFreeStatus extends AdFreeStatus {
  _FakeAdFreeStatus(this._value);
  final bool _value;

  @override
  Future<bool> build() async => _value;
}

Future<void> loadRoboto() async {
  var root = Platform.environment['FLUTTER_ROOT'];
  if (root == null || root.isEmpty) {
    var dir = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 5; i++) {
      dir = dir.parent;
    }
    root = dir.path;
  }
  final fontsDir = '$root/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    final bytes = await File('$fontsDir/Roboto-$weight.ttf').readAsBytes();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(loadRoboto);

  Future<void> pumpSheet(
    WidgetTester tester, {
    required bool isAdFree,
    required Size size,
    required double textScale,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adFreeStatusProvider.overrideWith(() => _FakeAdFreeStatus(isAdFree)),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const Scaffold(body: PaywallSheet()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
      'paywall fits the smallest phone at 2x text and shows '
      'both plans', (tester) async {
    await pumpSheet(
      tester,
      isAdFree: false,
      size: const Size(320, 568),
      textScale: 2.0,
    );
    expect(find.text('Splitwize Ad-Free'), findsOneWidget);
    expect(find.text('\$0.99/month'), findsOneWidget);
    expect(find.text('\$7/year'), findsOneWidget);
    expect(find.text('Subscribe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the Monthly plan flips the selection', (tester) async {
    await pumpSheet(
      tester,
      isAdFree: false,
      size: const Size(360, 800),
      textScale: 1.0,
    );
    final container =
        ProviderScope.containerOf(tester.element(find.byType(PaywallSheet)));
    expect(container.read(paywallPlanProvider), isTrue);
    await tester.tap(find.text('Monthly'));
    await tester.pump();
    expect(container.read(paywallPlanProvider), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paywall for an Ad-Free user shows the active state',
      (tester) async {
    await pumpSheet(
      tester,
      isAdFree: true,
      size: const Size(320, 568),
      textScale: 2.0,
    );
    expect(find.textContaining('Ad-Free is active'), findsOneWidget);
    expect(find.text('Subscribe'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
