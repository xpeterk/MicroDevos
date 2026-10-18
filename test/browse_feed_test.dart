import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_devos/core/startup.dart';

import 'support/load_fonts.dart';
import 'support/sample_app.dart';

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
    expect(find.byKey(const Key('story-fri-1')), findsOneWidget);

    await _tap(tester, const Key('more-fri-1'));
    expect(find.text('5-SECOND DEVO'), findsOneWidget);
    expect(find.byKey(const Key('read-full-fri-1')), findsOneWidget);

    await _tap(tester, const Key('read-full-fri-1'));
    expect(find.textContaining('NEXT STEP'), findsOneWidget);
    expect(find.text('Show less'), findsOneWidget);

    await _tap(tester, const Key('show-less-fri-1'));
    expect(find.textContaining('NEXT STEP'), findsNothing);
    expect(find.byKey(const Key('more-fri-1')), findsOneWidget);

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
    await _tap(tester, const Key('hashtag-fri-1-trust'));
    expect(find.byKey(const Key('chip-trust')), findsOneWidget);
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

    expect(find.textContaining('NEXT STEP'), findsNothing);
    await _tap(tester, const Key('more-fri-1'));
    await _tap(tester, const Key('read-full-fri-1'));
    expect(find.textContaining('The refuge does not relocate'), findsOneWidget);

    await _tap(tester, const Key('note-button-fri-1'));
    expect(find.byKey(const Key('note-editor')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('note-body')),
      'Sit quietly before I answer.',
    );
    await tester.pump();

    final passage = find.textContaining('The refuge does not relocate');
    await Scrollable.ensureVisible(tester.element(passage), alignment: 0.4);
    await tester.pump();
    await tester.longPress(passage);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('anchor-note')), findsOneWidget);
    await tester.tap(find.byKey(const Key('anchor-note')));
    await tester.pump();
    expect(find.byKey(const Key('anchor-preview')), findsOneWidget);

    await tester.tap(find.byKey(const Key('note-done')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('note-editor')), findsNothing);
    expect(find.text('Note saved · Saved › Notes'), findsOneWidget);
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
  final scaffold = tester.element(find.byType(Scaffold).first);
  ScaffoldMessenger.of(scaffold).hideCurrentSnackBar();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  final finder = find.byKey(key);
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
  await tester.tap(finder, warnIfMissed: true);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
