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

  testWidgets('a section devotion opens the summary and expands in place', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(await buildSampleApp(themeMode: 'light'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final router = GoRouter.of(tester.element(find.byType(TodayScreen)));
    router.push('/devo/fri-1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('IN THIS DEVO'), findsNothing);
    expect(
      find.textContaining(
        'Being still is not the same as having nothing to do.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('back-to-feed')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    router.push('/devo/fri-8');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('section-meta')), findsOneWidget);
    expect(find.text('3 sections · 5 min · Hebrews 4:16'), findsOneWidget);
    expect(find.text('IN THIS DEVO'), findsOneWidget);
    expect(find.text('Come Before You Feel Worthy'), findsOneWidget);
    expect(find.text('Ask for the Next Hour'), findsOneWidget);
    expect(find.text('Mercy Meets You There'), findsOneWidget);
    expect(
      find.textContaining('Some of us wait to pray until we feel worthy'),
      findsNothing,
    );
    await _capture(tester, 'section-summary');

    await tester.tap(find.byKey(const Key('section-bullet-fri-8-s1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('PART 1 OF 3', skipOffstage: false));
    await tester.pump();
    expect(find.text('PART 1 OF 3'), findsOneWidget);
    expect(
      find.textContaining(
        'Mercy meets the person who comes before they feel ready.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('come boldly'), findsWidgets);
    expect(find.byKey(const Key('section-heart-fri-8-s1')), findsOneWidget);
    expect(find.byKey(const Key('section-note-fri-8-s1')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'section-expanded');

    final scroll = tester
        .stateList<ScrollableState>(
          find.descendant(
            of: find.byKey(const Key('section-detail-scroll')),
            matching: find.byType(Scrollable),
          ),
        )
        .firstWhere((state) => state.position.axis == Axis.vertical);
    scroll.position.jumpTo(420);
    await tester.pump();
    expect(find.byKey(const Key('jump-summary')), findsOneWidget);
    expect(find.byKey(const Key('section-progress')), findsOneWidget);
    await tester.tap(find.byKey(const Key('jump-summary')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('IN THIS DEVO'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('section-heart-fri-8-s1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('section-heart-fri-8-s1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('section-note-fri-8-s1')));
    await tester.pump();
    expect(find.byKey(const Key('note-section-caption')), findsOneWidget);
    expect(
      find.textContaining('Part 1 · Come Before You Feel Worthy'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('note-body')),
      'A private line for this section.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('note-done')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Note saved · Saved › Notes'), findsOneWidget);
    for (final element in tester.elementList(find.byType(Scaffold))) {
      ScaffoldMessenger.of(element).hideCurrentSnackBar();
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const Key('back-to-feed')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('section-meta')), findsNothing);
    expect(find.text('Feed'), findsOneWidget);

    router.push('/devo/fri-8');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Feed'), findsOneWidget);

    await tester.tap(find.text('Saved'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Come Before You Feel Worthy'), findsOneWidget);
    expect(
      find.text('Part 1 of Come Near Before You Feel Ready'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('saved-notes')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Part 1 of Come Near Before You Feel Ready'),
      findsWidgets,
    );
    expect(find.text('A private line for this section.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'saved-sections');
  });
}

Future<void> _capture(WidgetTester tester, String name) async {
  await expectLater(
    find.byKey(const Key('screen-capture')),
    matchesGoldenFile('goldens/$name.png'),
  );
  final bytes = File('test/goldens/$name.png').readAsBytesSync();
  final artifact = File('/opt/cursor/artifacts/$name.png');
  artifact.parent.createSync(recursive: true);
  artifact.writeAsBytesSync(bytes);
}
