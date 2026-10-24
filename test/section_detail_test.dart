import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:micro_devos/core/startup.dart';
import 'package:micro_devos/domain/models/devo.dart';
import 'package:micro_devos/domain/models/devo_section.dart';
import 'package:micro_devos/features/devo/section_detail.dart';
import 'package:micro_devos/features/today/today_screen.dart';

import 'support/load_fonts.dart';
import 'support/sample_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('plain titles drop numbers and role labels', () {
    expect(
      plainSectionTitle('1 · Come Before You Feel Worthy'),
      'Come Before You Feel Worthy',
    );
    expect(plainSectionTitle('Problem · Name the Peace'), 'Name the Peace');
    expect(plainSectionTitle('Action: Stay on Purpose'), 'Stay on Purpose');
    expect(
      plainSectionTitle('Result — Let the Heart Settle'),
      'Let the Heart Settle',
    );
    expect(
      plainSectionTitle('Come Before You Feel Worthy'),
      'Come Before You Feel Worthy',
    );
    expect(plainSectionTitle('Problem'), 'Problem');
  });

  test('a section image is optional', () {
    final withImage = DevoSection.fromJson({
      'id': 's1',
      'title': 'Come Before You Feel Worthy',
      'image_url': 'assets/sample/section_banner.jpg',
      'image_alt': 'Warm light along a quiet street at dusk',
    });
    expect(withImage.imageUrl, 'assets/sample/section_banner.jpg');
    expect(withImage.imageAlt, 'Warm light along a quiet street at dusk');
    final plain = DevoSection.fromJson({'id': 's2', 'title': 'Ask'});
    expect(plain.imageUrl, isNull);
    expect(plain.imageAlt, isNull);
    expect(plain.copyWith(tags: const ['hope']).imageUrl, isNull);
  });

  test('the prayer line starts with the emoji and drops Today', () {
    expect(
      devoPrayerLine('Today: Ask for mercy for this hour.'),
      '🙏 Ask for mercy for this hour.',
    );
    expect(
      devoPrayerLine('🙏 **Today:** Offer one real help.'),
      '🙏 Offer one real help.',
    );
    expect(devoPrayerLine(''), isNull);
    final devo = Devo(
      id: 'x',
      title: 'Title',
      hook: 'Hook sentence.',
      bodyMd: '',
      takeaway: 'The banner sentence.',
      verseText: '',
      verseRef: 'John 1:1',
      scriptures: const [],
      editionDate: DateTime(2026, 10, 16),
      position: 1,
      status: 'published',
      tags: const [],
      teaser: 'The banner sentence.',
    );
    expect(devoTeaser(devo), isNull);
  });

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
    expect(find.text('IN THIS DEVO'), findsNothing);
    expect(find.byKey(const Key('todays-lesson')), findsNothing);
    expect(find.textContaining("TODAY'S LESSON"), findsNothing);
    expect(find.textContaining('Next in the flow'), findsNothing);
    expect(find.textContaining('PART'), findsNothing);
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsNothing);
    expect(find.text('3'), findsNothing);
    expect(find.byKey(const Key('devo-teaser')), findsOneWidget);
    expect(
      find.text(
        'Mercy meets the person who comes before they feel worthy of the conversation.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Pray before you feel ready. Ask for mercy and for the wisdom the next hour needs.',
      ),
      findsWidgets,
    );
    final prayer = tester.widget<Text>(
      find.byKey(const Key('devo-prayer'), skipOffstage: false),
    );
    expect(prayer.data, startsWith('🙏'));
    expect(prayer.data, isNot(contains('Today:')));
    expect(find.textContaining('Today:'), findsNothing);
    expect(find.text('Hebrews 4:16'), findsNothing);
    expect(find.text('James 1:5'), findsNothing);
    expect(find.byKey(const Key('section-strip-fri-8-s1')), findsNothing);
    expect(
      find.byKey(const Key('section-strip-fri-8-s2'), skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(const Key('section-strip-fri-8-s3'), skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(const Key('flow-connector'), skipOffstage: false),
      findsNWidgets(2),
    );
    expect(find.text('Come Before You Feel Worthy'), findsOneWidget);
    expect(find.text('Ask for the Next Hour'), findsOneWidget);
    expect(
      find.text('Mercy Meets You There', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining('Some of us wait to pray until we feel worthy'),
      findsNothing,
    );
    await _capture(tester, 'section-summary');

    await tester.tap(find.byKey(const Key('section-bullet-fri-8-s1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('PART'), findsNothing);
    expect(find.byKey(const Key('section-strip-fri-8-s1')), findsOneWidget);
    expect(find.byKey(const Key('section-ref-fri-8-s1')), findsOneWidget);
    expect(find.text('Hebrews 4:16'), findsOneWidget);
    expect(
      find.byKey(const Key('section-strip-fri-8-s2'), skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(const Key('section-strip-fri-8-s3'), skipOffstage: false),
      findsNothing,
    );
    expect(
      find.textContaining(
        'Mercy meets the person who comes before they feel ready.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('come boldly'), findsNothing);
    expect(find.byKey(const Key('section-heart-fri-8-s1')), findsOneWidget);
    expect(find.byKey(const Key('section-note-fri-8-s1')), findsOneWidget);
    expect(find.textContaining('Next in the flow'), findsNothing);
    expect(find.textContaining('Share card'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(
      find.textContaining(
        'Mercy meets the person who comes before they feel ready.',
      ),
    );
    await tester.pump();
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
    expect(find.byKey(const Key('devo-teaser')), findsOneWidget);
    expect(find.text('Come Before You Feel Worthy'), findsWidgets);

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

    router.push('/devo/fri-7');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('4 sections · 6 min · John 14:27'), findsOneWidget);
    expect(
      find.text('The Noise in the Room', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Name the Peace', skipOffstage: false), findsOneWidget);
    expect(find.text('Stay on Purpose', skipOffstage: false), findsOneWidget);
    expect(
      find.text('Let the Heart Settle', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.textContaining('Problem'), findsNothing);
    expect(find.textContaining('Action'), findsNothing);
    expect(find.textContaining('Result'), findsNothing);
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsNothing);
    expect(find.text('3'), findsNothing);
    expect(find.text('4'), findsNothing);
    expect(
      find.byKey(const Key('flow-connector'), skipOffstage: false),
      findsNWidgets(3),
    );
    expect(find.byKey(const Key('todays-lesson')), findsNothing);
    expect(find.textContaining('Next in the flow'), findsNothing);
    expect(find.byKey(const Key('devo-prayer')), findsNothing);
    expect(
      find.byKey(const Key('section-strip-fri-7-s1'), skipOffstage: false),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
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
