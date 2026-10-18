import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_devos/core/providers.dart';
import 'package:micro_devos/core/startup.dart';
import 'package:micro_devos/domain/models/devo_note.dart';
import 'package:micro_devos/features/browse/browse_state.dart';
import 'package:micro_devos/features/today/today_screen.dart';

import 'support/load_fonts.dart';
import 'support/sample_app.dart';
import 'support/select_sentence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final originalErrorWidget = ErrorWidget.builder;

  setUpAll(() async {
    await prepareFramework();
    await loadAppFonts();
  });

  tearDownAll(() {
    ErrorWidget.builder = originalErrorWidget;
  });

  testWidgets('approved feed mockups at 390x844 light', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildSampleApp(themeMode: 'light', favoriteIds: const []),
    );
    await _settle(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TodayScreen)),
    );
    container.read(browseFilterProvider.notifier).addTag('courage');
    container.read(browseFilterProvider.notifier).addTag('peace');
    await tester.pump();
    await _top(tester);
    await _capture(tester, 'build-IG1');

    await _tap(tester, const Key('more-fri-1'));
    await _show(tester, find.text('5-SECOND DEVO'));
    await _capture(tester, 'build-IG2');

    await _tap(tester, const Key('read-full-fri-1'));
    await _show(tester, find.text('Show less'));
    await _capture(tester, 'build-IG3');

    await _top(tester);
    await _doubleTap(tester, const Key('banner-fri-1'));
    await tester.pump(const Duration(milliseconds: 180));
    await _capture(tester, 'build-IG4');
    await tester.pump(const Duration(milliseconds: 800));
    _hideSnack(tester);
    await tester.pump(const Duration(milliseconds: 400));

    await _top(tester);
    await _tap(tester, const Key('story-fri-2'));
    await _capture(tester, 'build-IG5');
    await _tap(tester, const Key('story-close'));

    for (final id in ['fri-2', 'fri-3', 'fri-4', 'fri-5', 'fri-6']) {
      await container.read(favoritesProvider.notifier).toggle(id);
    }
    await tester.tap(find.text('Saved'));
    await _settle(tester);
    expect(find.text('A Refuge That Does Not Move'), findsWidgets);
    await _capture(tester, 'build-IG6');

    await tester.tap(find.text('Today'));
    await _settle(tester);
    await _top(tester);
    await _tap(tester, const Key('share-button-fri-1'));
    await _capture(tester, 'build-IG7');
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await _tap(tester, const Key('filter-button'));
    await tester.pump(const Duration(milliseconds: 300));
    await _capture(tester, 'build-IG8');
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    container.read(browseFilterProvider.notifier).removeTag('peace');
    await tester.pump();
    await _tap(tester, const Key('note-button-fri-1'));
    await tester.enterText(
      find.byKey(const Key('note-body')),
      'Sit quietly before I answer.',
    );
    await tester.pump();
    await selectSentence(tester, anchorSentence);
    expect(find.byKey(const Key('anchor-note')), findsOneWidget);
    await _capture(tester, 'build-N5');

    await tester.tap(find.byKey(const Key('anchor-note')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('anchor-preview'))).data,
      '“$anchorSentence”',
    );
    await _capture(tester, 'build-N1');

    await tester.tap(find.byKey(const Key('note-done')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _show(tester, find.textContaining('The refuge does not relocate'));
    await _capture(tester, 'build-N2');
    _hideSnack(tester);
    await tester.pump(const Duration(milliseconds: 400));

    await _tap(tester, const Key('show-less-fri-1'));
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('note-button-fri-1'))),
      alignment: 0.2,
    );
    await tester.pump();
    await _capture(tester, 'build-N3');

    final now = DateTime.utc(2026, 10, 16, 15);
    await container
        .read(notesProvider.notifier)
        .save(
          DevoNote(
            id: '',
            devoId: 'fri-2',
            body: 'Write the fear in one sentence tonight.',
            anchorText: 'Fear talks loudly.',
            anchorStart: 0,
            anchorEnd: 18,
            section: 'hook',
            createdAt: now,
            updatedAt: now.subtract(const Duration(hours: 2)),
          ),
        );
    await container
        .read(notesProvider.notifier)
        .save(
          DevoNote(
            id: '',
            devoId: 'fri-3',
            body: 'Leave the list with Him before bed.',
            createdAt: now,
            updatedAt: now.subtract(const Duration(hours: 4)),
          ),
        );
    await tester.pump();
    await tester.tap(find.text('Saved'));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('saved-notes')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sit quietly before I answer.'), findsOneWidget);
    await _capture(tester, 'build-N4');

    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 90)));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void _hideSnack(WidgetTester tester) {
  ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
      .hideCurrentSnackBar();
}

Future<void> _top(WidgetTester tester) async {
  for (final state in tester.stateList<ScrollableState>(
    find.byType(Scrollable),
  )) {
    if (state.position.axis == Axis.vertical && state.position.pixels > 0) {
      state.position.jumpTo(0);
    }
  }
  await tester.pump();
}

Future<void> _show(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.35);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  _hideSnack(tester);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  final finder = find.byKey(key);
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _doubleTap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.4);
  await tester.pump();
  final center = tester.getCenter(finder);
  await tester.tapAt(center);
  await tester.pump(const Duration(milliseconds: 40));
  await tester.tapAt(center);
  await tester.pump();
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
  expect(bytes.length, greaterThan(8000), reason: '$name png is too small');
  expect(bytes[0], 0x89);
  expect(bytes[1], 0x50);
}
