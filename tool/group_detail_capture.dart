// Run with flutter test --no-pub tool/group_detail_capture.dart.
// Saves review screenshots in docs/ with in-memory data, real fonts and themes.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/models/models.dart';
import 'package:splitwize/providers/core_providers.dart';
import 'package:splitwize/providers/data_providers.dart';
import 'package:splitwize/screens/group_detail_screen.dart';
import 'package:splitwize/theme.dart';

import '../test/responsive_overflow_test.dart' as fixture;

const _previewGroup = BillGroup(
  id: 'g1',
  name: 'Weekend in the hills',
  createdBy: 'me',
  members: ['me', 'f1', 'f2'],
  invited: ['f9'],
  currency: 'PKR',
);

Bill _expense(String id, String title, double total, String creator,
        List<bool> paid, DateTime date) =>
    Bill.fromMap(id, {
      ...fixture.testBill.toMap(),
      'title': title,
      'total': total,
      'subtotal': total,
      'tipPercent': 0,
      'splitType': 'equal',
      'createdBy': creator,
      'createdByName': creator == 'me' ? 'Ali Haider' : 'Hamza Malik',
      'createdAt': date,
      'splits': [
        for (var i = 0; i < 3; i++)
          {
            'uid': ['me', 'f1', 'f2'][i],
            'displayName': ['Ali Haider', 'Sara Ahmed', 'Hamza Malik'][i],
            'amount': total / 3,
            'paid': paid[i],
          },
      ],
    });

final _previewBills = [
  _expense('dinner', 'Dinner at Monal', 8400, 'me', [true, false, true],
      DateTime(2026, 11, 13)),
  _expense('stay', 'Stay in Nathiagali', 36000, 'f2', [false, true, true],
      DateTime(2026, 11, 12)),
  _expense('fuel', 'Road trip fuel', 6000, 'me', [true, true, true],
      DateTime(2026, 11, 11)),
];

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

  testWidgets('capture redesigned group details', (tester) async {
    addTearDown(tester.view.reset);
    final boundaryKey = GlobalKey();
    Future<void> pumpScreen({
      Size size = const Size(390, 844),
      double textScale = 1,
      ThemeMode themeMode = ThemeMode.light,
      bool stress = false,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUidProvider.overrideWith((ref) => 'me'),
          currentAppUserProvider.overrideWith((ref) => Stream.value(fixture.me)),
          authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
          groupProvider.overrideWith((ref, id) => Stream.value(
              stress ? fixture.testGroup : _previewGroup)),
          groupBillsProvider.overrideWith((ref, id) => Stream.value(
              stress ? [fixture.testBill] : _previewBills)),
          groupMembersProvider.overrideWith((ref, id) async => [
            fixture.me,
            stress
                ? fixture.longNameFriend
                : const AppUser(uid: 'f1', displayName: 'Sara Ahmed',
                    email: 'sara@example.com'),
            fixture.friend2,
          ]),
          invitedUsersProvider.overrideWith((ref, id) async => [fixture.invitedUser]),
          connectionsProvider.overrideWith((ref) => Stream.value([fixture.friend2])),
        ],
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: splitwizeLightTheme,
            darkTheme: splitwizeDarkTheme,
            themeMode: themeMode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: const GroupDetailScreen(groupId: 'g1'),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> capture(String suffix) => tester.runAsync(() async {
          final boundary = boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          await Directory('docs').create(recursive: true);
          await File('docs/group-detail-after$suffix.png')
              .writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });

    Future<void> openTab(String title, String key) async {
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -450));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(title));
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.byKey(PageStorageKey(key)), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await pumpScreen();
    await capture('');
    await openTab('Balances', 'group-balances-g1');
    await capture('-balances');
    await openTab('Members', 'group-members-g1');
    await capture('-members');
    await tester.tap(find.byTooltip('Group settings'));
    await tester.pumpAndSettle();
    await capture('-settings');

    await pumpScreen(themeMode: ThemeMode.dark);
    await capture('-dark');
    await pumpScreen(size: const Size(320, 700), textScale: 1.4, stress: true);
    await openTab('Balances', 'group-balances-g1');
    await capture('-small-balances');
    expect(tester.takeException(), isNull);
  });
}
