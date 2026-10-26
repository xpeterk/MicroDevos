import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_devos/core/providers.dart';
import 'package:micro_devos/core/startup.dart';
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

  testWidgets('feed expands, likes, filters, and keeps a private note', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      await buildSampleApp(themeMode: 'light', favoriteIds: const []),
    );
    await _settle(tester);
    expect(find.text('A Refuge That Does Not Move'), findsOneWidget);
    expect(find.byKey(const Key('feed-filter-bar')), findsOneWidget);
    expect(find.byKey(const Key('story-fri-1')), findsNothing);
    expect(find.text('Archive'), findsNothing);
    expect(find.textContaining('FRI, OCT 16'), findsOneWidget);
    expect(find.text('3 SEC'), findsNothing);
    expect(
      find.textContaining('Pray the heaviest item on your mind'),
      findsWidgets,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('post-fri-1')).first).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('post-fri-2')).first).dy),
    );
    for (final label in const [
      'PHOTO + SCRIM',
      'DUOTONE IMAGE',
      'TYPE POSTER',
      'OUTLINED SCRIPTURE',
      'SPLIT IMAGE',
      'HAND-LETTERED',
      'MINIMAL EDITORIAL',
      'COLLAGE + STAMP',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    final devos = ProviderScope.containerOf(
      tester.element(find.byType(TodayScreen)),
    ).read(todayProvider).requireValue.devos;
    expect(devos.first.id, 'fri-1');
    expect(devos.take(8).map((devo) => devo.position), [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
    ]);
    expect(devos[8].id, 'thu-1');
    expect(devos[8].editionDate.isBefore(devos.first.editionDate), isTrue);

    await _tap(tester, const Key('heart-fri-1'));
    expect(find.text('Liked · added to Saved'), findsOneWidget);
    await _tap(tester, const Key('heart-fri-1'));
    expect(find.text('Removed from Saved'), findsOneWidget);

    await _doubleTap(tester, const Key('banner-fri-1'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byKey(const Key('heart-burst')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Liked · added to Saved'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));

    await _tap(tester, const Key('hashtag-fri-1-courage'));
    expect(find.byKey(const Key('chip-courage')), findsOneWidget);
    _expectChipWhole(tester, 'courage');
    await _tap(tester, const Key('hashtag-fri-1-trust'));
    expect(find.byKey(const Key('chip-trust')), findsOneWidget);
    _expectChipWhole(tester, 'courage');
    _expectChipWhole(tester, 'trust');
    expect(
      tester.widget<Text>(find.byKey(const Key('filter-count'))).data,
      '2',
    );

    await _tap(tester, const Key('chip-delete-courage'));
    expect(find.byKey(const Key('chip-courage')), findsNothing);
    expect(find.byKey(const Key('chip-trust')), findsOneWidget);

    await _tap(tester, const Key('clear-filters'));
    expect(find.byKey(const Key('chip-trust')), findsNothing);
    expect(find.byKey(const Key('filter-count')), findsNothing);

    await _tap(tester, const Key('liked-filter'));
    expect(find.text('The Right Hand You Cannot See'), findsNothing);
    expect(find.text('A Refuge That Does Not Move'), findsOneWidget);
    await _tap(tester, const Key('liked-filter'));
    expect(find.text('The Right Hand You Cannot See'), findsOneWidget);

    await _tap(tester, const Key('note-button-fri-1'));
    expect(find.byKey(const Key('devo-detail')), findsOneWidget);
    expect(find.textContaining('The refuge does not relocate'), findsOneWidget);
    expect(find.byKey(const Key('note-editor')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('note-body')),
      'Sit quietly before I answer.',
    );
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('note-body')))
          .controller
          ?.text,
      'Sit quietly before I answer.',
    );

    await selectSentence(tester, anchorSentence);
    expect(find.byKey(const Key('anchor-note')), findsOneWidget);
    await tester.tap(find.byKey(const Key('anchor-note')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('anchor-preview'))).data,
      '“$anchorSentence”',
    );

    await tester.tap(find.byKey(const Key('note-done')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('note-editor')), findsNothing);
    expect(find.text('Note saved · Saved › Notes'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await _tap(tester, const Key('back-to-feed'));
    expect(find.byKey(const Key('devo-detail')), findsNothing);
    final postit = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && key.value.startsWith('postit-');
    });
    expect(postit, findsOneWidget);

    await Scrollable.ensureVisible(tester.element(postit), alignment: 0.4);
    await tester.pump();
    await tester.tap(postit);
    await tester.pump();
    expect(find.byKey(const Key('note-editor')), findsOneWidget);
    expect(find.text('Sit quietly before I answer.'), findsOneWidget);
    expect(find.byKey(const Key('anchor-preview')), findsOneWidget);

    await tester.tap(find.byKey(const Key('note-done')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await _tap(tester, const Key('back-to-feed'));

    await tester.tap(find.text('Saved'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('saved-notes')));
    await tester.pump();
    expect(find.text('Sit quietly before I answer.'), findsOneWidget);
    expect(find.text('A Refuge That Does Not Move'), findsWidgets);
    expect(find.textContaining('with notes'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 60)));
}

void _expectChipWhole(WidgetTester tester, String slug) {
  final chip = tester.getRect(find.byKey(Key('chip-$slug')));
  final delete = tester.getRect(find.byKey(Key('chip-delete-$slug')));
  final scroller = tester.getRect(
    find.byKey(const Key('filter-chip-scroller')),
  );
  final clear = tester.getRect(find.byKey(const Key('clear-filters')));
  final filter = tester.getRect(find.byKey(const Key('filter-button')));
  expect(chip.left, greaterThanOrEqualTo(scroller.left - 0.5));
  expect(chip.right, lessThanOrEqualTo(scroller.right + 0.5));
  expect(delete.right, lessThanOrEqualTo(scroller.right + 0.5));
  expect(delete.width, greaterThan(8));
  expect(clear.left, greaterThanOrEqualTo(scroller.right - 0.5));
  expect(clear.right, lessThanOrEqualTo(filter.left + 0.5));
}

Future<void> _doubleTap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
  final center = tester.getCenter(finder);
  await tester.tapAt(center);
  await tester.pump(const Duration(milliseconds: 40));
  await tester.tapAt(center);
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _tap(WidgetTester tester, Key key) async {
  for (final element in tester.elementList(find.byType(Scaffold))) {
    ScaffoldMessenger.of(element).hideCurrentSnackBar();
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  final finder = find.byKey(key);
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
  await tester.tap(finder, warnIfMissed: true);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
