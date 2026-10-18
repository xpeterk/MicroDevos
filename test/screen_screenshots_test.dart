import 'dart:io';

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

  testWidgets('sample screens paint text at phone size in light and dark', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(await buildSampleApp(themeMode: 'light'));
    await _showToday(tester, 'light');
    await _showArchive(tester, 'light');
    await _showFavorites(tester, 'light');
    await _showSettings(tester, 'light');

    await tester.tap(find.text('Dark'));
    await _settle(tester);
    await _capture(tester, 'micro-devos-settings-dark');

    await tester.pageBack();
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.wb_sunny_outlined));
    await _showToday(tester, 'dark');
    await _showArchive(tester, 'dark');
    await _showFavorites(tester, 'dark');

    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));
}

Future<void> _setPhoneSize(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _showToday(WidgetTester tester, String theme) async {
  await _settle(tester);
  expect(find.text('A Refuge That Does Not Move'), findsWidgets);
  expect(find.textContaining('could not'), findsNothing);
  expect(find.textContaining('OCT 16'), findsOneWidget);
  expect(find.textContaining('8 DEVOS'), findsOneWidget);
  await _capture(tester, 'micro-devos-today-$theme');
}

Future<void> _showArchive(WidgetTester tester, String theme) async {
  await tester.tap(find.byIcon(Icons.calendar_month_outlined));
  await _settle(tester);
  expect(
    find.text('Search the devotions, or browse by edition date.'),
    findsOneWidget,
  );
  expect(find.text('Oct 16'), findsOneWidget);
  await _capture(tester, 'micro-devos-archive-$theme');
}

Future<void> _showFavorites(WidgetTester tester, String theme) async {
  await tester.tap(find.text('Saved'));
  await _settle(tester);
  expect(find.textContaining('liked devo'), findsWidgets);
  expect(find.text('A Refuge That Does Not Move'), findsWidgets);
  await _capture(tester, 'micro-devos-favorites-$theme');
}

Future<void> _showSettings(WidgetTester tester, String theme) async {
  await tester.tap(find.byTooltip('Settings'));
  await _settle(tester);
  expect(find.text('Settings'), findsOneWidget);
  expect(find.text('BIBLE VERSION'), findsOneWidget);
  await _capture(tester, 'micro-devos-settings-$theme');
  await tester.scrollUntilVisible(find.textContaining('bundled sample'), 400);
  expect(
    find.textContaining('You are reading the bundled sample.'),
    findsOneWidget,
  );
  await tester.scrollUntilVisible(find.text('APPEARANCE'), -400);
  await _settle(tester);
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
