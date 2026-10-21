import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:micro_devos/core/startup.dart';
import 'package:micro_devos/features/today/today_screen.dart';

import 'support/load_fonts.dart';
import 'support/sample_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await prepareFramework();
    await loadAppFonts();
  });

  testWidgets('a banner opens the devotion and back returns to the same spot', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(await buildSampleApp(themeMode: 'light'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Archive'), findsNothing);
    expect(find.textContaining('FRI, OCT 16'), findsOneWidget);
    expect(find.textContaining('8 DEVOS'), findsWidgets);

    await expectLater(
      find.byKey(const Key('screen-capture')),
      matchesGoldenFile('goldens/feed.png'),
    );
    _copyGolden('feed');

    GoRouter.of(tester.element(find.byType(TodayScreen))).push('/devo/fri-3');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('devo-detail')), findsOneWidget);
    expect(find.text('Back to feed'), findsOneWidget);
    expect(find.text('THE LIST WITH'), findsWidgets);
    expect(find.textContaining('Prayer is not a performance of calm.'), findsOneWidget);
    expect(
      tester.widgetList<Hero>(find.byType(Hero, skipOffstage: false)).where((
        hero,
      ) {
        return hero.tag == 'banner-fri-3';
      }).length,
      2,
    );
    expect(find.byKey(const Key('newsletter-image')), findsNothing);

    await expectLater(
      find.byKey(const Key('screen-capture')),
      matchesGoldenFile('goldens/full-devo.png'),
    );
    _copyGolden('full-devo');

    await tester.tap(find.byKey(const Key('back-to-feed')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('devo-detail')), findsNothing);

    final scroll = _feedScroll(tester);
    expect(scroll.position.axis, Axis.vertical);
    scroll.position.jumpTo(720);
    await tester.pump();
    final parked = scroll.position.pixels;
    expect(parked, greaterThan(100));

    GoRouter.of(tester.element(find.byType(TodayScreen))).push('/devo/fri-1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('devo-detail')), findsNothing);
    expect(_feedPixels(tester), parked);
    expect(tester.takeException(), isNull);
  });
}

ScrollableState _feedScroll(WidgetTester tester) {
  return tester
      .stateList<ScrollableState>(
        find.descendant(
          of: find.byKey(const Key('feed-scroll')),
          matching: find.byType(Scrollable),
        ),
      )
      .firstWhere((state) => state.position.axis == Axis.vertical);
}

double _feedPixels(WidgetTester tester) => _feedScroll(tester).position.pixels;

void _copyGolden(String name) {
  final bytes = File('test/goldens/$name.png').readAsBytesSync();
  final artifact = File('/opt/cursor/artifacts/$name.png');
  artifact.parent.createSync(recursive: true);
  artifact.writeAsBytesSync(bytes);
}
