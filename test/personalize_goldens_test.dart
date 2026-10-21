import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_devos/core/providers.dart';
import 'package:micro_devos/core/startup.dart';
import 'package:micro_devos/domain/models/bible_version.dart';
import 'package:micro_devos/features/personalize/personalize_state.dart';
import 'package:micro_devos/features/today/today_screen.dart';

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

  testWidgets('personalize mockups PZ1 through PZ6c', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(await buildSampleApp(themeMode: 'light'));
    await _settle(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TodayScreen)),
    );
    container.read(showCreateHintProvider.notifier).show();
    await tester.pump();
    expect(find.byKey(const Key('create-hint')), findsOneWidget);
    expect(find.text('A Refuge That Does Not Move'), findsWidgets);
    await _capture(tester, 'build-PZ1');
    container.read(showCreateHintProvider.notifier).hide();
    await tester.pump();

    await tester.tap(find.byKey(const Key('create-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('personalize-sheet')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('topic-field')),
      'Trusting God at a new job',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('topic-suggestion-New job')));
    await tester.pump();
    await _capture(tester, 'build-PZ2');

    final prefs = container.read(preferencesProvider).requireValue;
    await container
        .read(preferencesProvider.notifier)
        .updatePreferences(
          prefs.copyWith(
            bibleVersions: const BibleVersionSelection(
              enabled: {BibleVersion.esv, BibleVersion.kjv},
              readingVersion: BibleVersion.esv,
            ),
          ),
        );
    await tester.tap(find.byKey(const Key('personalize-verse')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('verse-field')), 'Phil 4:6-7');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.enterText(find.byKey(const Key('verse-field')), 'Ps 23:1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.byKey(const Key('verse-preview')), findsOneWidget);
    expect(find.text('ESV'), findsOneWidget);
    await _capture(tester, 'build-PZ3');

    await tester.tap(find.byKey(const Key('personalize-topic')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('personalize-next')));
    await tester.pump();
    expect(find.byKey(const Key('style-purpose')), findsOneWidget);
    await _capture(tester, 'build-PZ4');

    container.read(personalizeEngineProvider).seedWeekUsage(2);
    await tester.tap(find.byKey(const Key('personalize-next-for-whom')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('age-30–44')));
    await tester.tap(find.byKey(const Key('life-Work')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('personalize-generate')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byKey(const Key('personalize-writing')), findsOneWidget);
    expect(find.text('3 of 5 left this week'), findsOneWidget);
    await _capture(tester, 'build-PZ5');

    await tester.pump(const Duration(milliseconds: 550));
    await tester.pump();
    expect(find.byKey(const Key('personalize-result')), findsOneWidget);
    expect(find.text('Steady Ground on a First Morning'), findsOneWidget);
    expect(find.byKey(const Key('help-note')), findsNothing);
    await _capture(tester, 'build-PZ6');

    await tester.tap(find.byKey(const Key('personalize-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('create-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
      find.byKey(const Key('topic-field')),
      'Trusting God at a new job',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('personalize-next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('style-spurgeon')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('personalize-next-for-whom')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('personalize-generate')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    expect(find.textContaining('Adapted from C. H. Spurgeon'), findsOneWidget);
    await _capture(tester, 'build-PZ6c');

    await tester.scrollUntilVisible(find.byKey(const Key('save-to-mine')), 80);
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-to-mine')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    _hideSnack(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Saved on this phone'), findsOneWidget);
    await _capture(tester, 'build-PZ6b');
    _hideSnack(tester);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('personalize-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Feed'));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('create-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byKey(const Key('topic-field')), 'Anxiety');
    await tester.pump();
    await tester.tap(find.byKey(const Key('personalize-next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('personalize-next-for-whom')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('personalize-generate')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    expect(find.byKey(const Key('help-note')), findsOneWidget);
    expect(find.textContaining('call or text 988 any time.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('help-note')));
    await tester.pump();
    await _capture(tester, 'build-PZ6-help');

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
