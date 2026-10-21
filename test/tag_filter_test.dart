import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:micro_devos/core/startup.dart';
import 'package:micro_devos/data/sample/sample_catalog.dart';
import 'package:micro_devos/features/browse/browse_state.dart';
import 'package:micro_devos/features/browse/filter_sheet.dart';
import 'package:micro_devos/features/today/today_screen.dart';

import 'support/load_fonts.dart';
import 'support/sample_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SampleCatalog catalog;

  setUpAll(() async {
    await prepareFramework();
    await loadAppFonts();
    catalog = SampleCatalog.parse(
      File('assets/sample/devos.json').readAsStringSync(),
      File('assets/sample/tags.json').readAsStringSync(),
    );
  });

  String parentOf(String slug) {
    return catalog.tags.firstWhere((tag) => tag.slug == slug).parentSlug ?? '';
  }

  test('a parent filter matches a section tagged with its child', () {
    final filters = catalog.tags.where((tag) => tag.isFilter).toList();
    expect(filters, hasLength(20));
    expect(catalog.tags.where((tag) => tag.parentSlug != null), hasLength(54));
    expect(parentOf('humility'), 'grace-holiness');
    expect(parentOf('servanthood'), 'grace-holiness');
    expect(parentOf('church'), 'church-community');
    expect(parentOf('communion'), 'church-community');
    expect(parentOf('worship'), 'church-community');
    expect(parentOf('justice'), 'love-kindness');
    expect(parentOf('gospel'), 'gospel-faith');
    expect(parentOf('small-things'), 'work');
    expect(parentOf('faith'), 'trust');

    final matched = applyBrowseFilter(
      devos: catalog.devos,
      filter: const BrowseFilter(interests: {'grace-holiness'}),
      likedIds: const {},
      notedIds: const {},
      catalog: catalog.tags,
    );
    expect(matched.map((devo) => devo.id), ['fri-8']);
    expect(
      matched.single.sections
          .expand((section) => section.tags)
          .contains('humility'),
      isTrue,
    );
  });

  testWidgets('the filter sheet lists parent topics and matches a child', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(await buildSampleApp(themeMode: 'light'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const Key('filter-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final grace = find.byKey(const ValueKey('filter-tag-grace-holiness'));
    final sheetScroll = find.descendant(
      of: find.byType(FilterSheet),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(grace, 240, scrollable: sheetScroll);
    await tester.pump();
    expect(find.text('Humility', skipOffstage: false), findsNothing);
    expect(grace, findsOneWidget);
    expect(find.text('Grace & Holiness'), findsWidgets);
    for (final slug in _filterSlugs) {
      expect(
        find.byKey(ValueKey('filter-tag-$slug'), skipOffstage: false),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
    await _capture(tester, 'filter-sheet');

    await tester.tap(grace);
    await tester.pump();
    expect(find.text('Show 1 devos'), findsOneWidget);
    await tester.tap(find.byKey(const Key('show-devos')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('banner-fri-8')), findsOneWidget);
    expect(find.byKey(const Key('banner-fri-1')), findsNothing);

    final router = GoRouter.of(tester.element(find.byType(TodayScreen)));
    router.push('/devo/fri-8');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final bullet = find.byKey(
      const Key('section-bullet-fri-8-s3'),
      skipOffstage: false,
    );
    await tester.ensureVisible(bullet);
    await tester.pump();
    await tester.tap(bullet);
    await tester.pump();
    expect(
      find.byKey(
        const Key('section-tag-fri-8-s3-humility'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(find.text('HUMILITY', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _filterSlugs = [
  'courage',
  'anxiety',
  'fear',
  'hope',
  'peace',
  'gratitude',
  'grief',
  'trust',
  'prayer',
  'rest',
  'scripture',
  'waiting',
  'perseverance',
  'identity',
  'work',
  'family',
  'gospel-faith',
  'love-kindness',
  'church-community',
  'grace-holiness',
];

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
