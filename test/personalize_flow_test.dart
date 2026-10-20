import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_devos/core/providers.dart';
import 'package:micro_devos/core/startup.dart';
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

  testWidgets('personalize steps, swipe gate, and chip contrast', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(await buildSampleApp(themeMode: 'light'));
    await _settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TodayScreen)),
    );

    await tester.tap(find.byKey(const Key('create-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('personalize-sheet')), findsOneWidget);
    expect(container.read(personalizeFormProvider).step, 0);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('personalize-next')))
          .onPressed,
      isNull,
    );

    _expectChipContrast(tester, const Key('topic-suggestion-Anxiety'));
    _expectChipContrast(tester, const Key('personalize-topic'));
    await _shot(tester, 'personalize-step-what');

    await tester.tap(find.byKey(const Key('step-style')));
    await tester.pump();
    expect(container.read(personalizeFormProvider).step, 0);

    await _swipe(tester, -320);
    expect(container.read(personalizeFormProvider).step, 0);
    expect(find.text('Next: pick a style'), findsOneWidget);

    await tester.tap(find.byKey(const Key('topic-suggestion-New job')));
    await tester.pump();
    expect(container.read(personalizeFormProvider).suggestion, 'New job');
    expect(container.read(personalizeFormProvider).canContinue, isTrue);
    _expectChipContrast(tester, const Key('topic-suggestion-New job'));
    _expectChipContrast(tester, const Key('topic-suggestion-Anxiety'));

    await tester.tap(find.byKey(const Key('step-style')));
    await tester.pump();
    expect(container.read(personalizeFormProvider).step, 1);
    expect(find.byKey(const Key('style-purpose')), findsOneWidget);
    _expectChipContrast(tester, const Key('style-purpose'));
    _expectChipContrast(tester, const Key('style-healing'));
    await _shot(tester, 'personalize-step-style');

    await tester.tap(find.byKey(const Key('style-healing')));
    await tester.pump();
    expect(container.read(personalizeFormProvider).styleKey, 'healing');
    _expectChipContrast(tester, const Key('style-healing'));

    await _swipe(tester, 320);
    expect(container.read(personalizeFormProvider).step, 0);

    await _swipe(tester, -320);
    expect(container.read(personalizeFormProvider).step, 1);

    await tester.tap(find.byKey(const Key('personalize-next-for-whom')));
    await tester.pump();
    expect(container.read(personalizeFormProvider).step, 2);
    expect(find.text('Generate'), findsOneWidget);

    await tester.tap(find.byKey(const Key('age-Teen')));
    await tester.tap(find.byKey(const Key('life-Work')));
    await tester.pump();
    expect(container.read(personalizeFormProvider).ageRange, 'Teen');
    expect(
      container.read(personalizeFormProvider).lifeSituations,
      contains('Work'),
    );
    _expectChipContrast(tester, const Key('age-Teen'));
    _expectChipContrast(tester, const Key('life-Parenting'));
    await _shot(tester, 'personalize-step-for-whom');

    await tester.tap(find.byKey(const Key('step-what')));
    await tester.pump();
    expect(container.read(personalizeFormProvider).step, 0);
    await tester.tap(find.byKey(const Key('step-for-whom')));
    await tester.pump();
    expect(container.read(personalizeFormProvider).step, 2);

    await _swipe(tester, -320);
    expect(container.read(personalizeFormProvider).step, 2);
    await _swipe(tester, 320);
    expect(container.read(personalizeFormProvider).step, 1);
    await _swipe(tester, -320);
    expect(container.read(personalizeFormProvider).step, 2);

    await tester.tap(find.byKey(const Key('personalize-generate')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byKey(const Key('personalize-writing')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pump();
    expect(find.byKey(const Key('personalize-result')), findsOneWidget);
    expect(find.text('Steady Ground on a First Morning'), findsOneWidget);

    await tester.tap(find.byKey(const Key('personalize-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    await tester.pump();
    await _openSheet(tester);
    await _shot(tester, 'personalize-chips-dark');
    _expectChipContrast(tester, const Key('topic-suggestion-Anxiety'));
    _expectChipContrast(tester, const Key('personalize-topic'));
    await tester.tap(find.byKey(const Key('topic-suggestion-Patience')));
    await tester.pump();
    _expectChipContrast(tester, const Key('topic-suggestion-Patience'));
    _expectChipContrast(tester, const Key('topic-suggestion-Anxiety'));
    await tester.tap(find.byKey(const Key('personalize-next')));
    await tester.pump();
    _expectChipContrast(tester, const Key('style-purpose'));
    _expectChipContrast(tester, const Key('style-invitation'));
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await container.read(themeModeProvider.notifier).setMode(ThemeMode.system);
    await tester.pump();
    await _openSheet(tester);
    _expectChipContrast(tester, const Key('topic-suggestion-Grief'));
    _expectChipContrast(tester, const Key('personalize-verse'));
    await tester.tap(find.byKey(const Key('topic-suggestion-Grief')));
    await tester.pump();
    _expectChipContrast(tester, const Key('topic-suggestion-Grief'));
    await tester.tap(find.byKey(const Key('personalize-next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('personalize-next-for-whom')));
    await tester.pump();
    _expectChipContrast(tester, const Key('age-65+'));
    await tester.tap(find.byKey(const Key('age-65+')));
    await tester.pump();
    _expectChipContrast(tester, const Key('age-65+'));
    _expectChipContrast(tester, const Key('life-Student'));

    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 60)));
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('create-button')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byKey(const Key('personalize-sheet')), findsOneWidget);
}

Future<void> _swipe(WidgetTester tester, double dx) async {
  await tester.drag(find.byKey(const Key('personalize-pager')), Offset(dx, 0));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 200));
}

void _expectChipContrast(WidgetTester tester, Key key) {
  final material = tester.widget<Material>(
    find.descendant(of: find.byKey(key), matching: find.byType(Material)).first,
  );
  final text = tester.widget<Text>(
    find.descendant(of: find.byKey(key), matching: find.byType(Text)).first,
  );
  final background = material.color;
  final foreground = text.style?.color;
  expect(background, isNotNull, reason: '$key has no fill');
  expect(foreground, isNotNull, reason: '$key label has no color');
  expect(
    background!.a,
    greaterThan(0.99),
    reason: '$key fill should be opaque',
  );
  final ratio = _contrast(foreground!, background);
  expect(
    ratio,
    greaterThanOrEqualTo(4.5),
    reason: '$key contrast $ratio is below WCAG AA',
  );
}

double _contrast(Color foreground, Color background) {
  final lighter = math.max(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  final darker = math.min(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  return (lighter + 0.05) / (darker + 0.05);
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('screen-capture')),
  );
  final image = await tester.runAsync(
    () => boundary.toImage(pixelRatio: 1),
  );
  final data = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  final bytes = data!.buffer.asUint8List();
  final artifact = File('/opt/cursor/artifacts/$name.png');
  artifact.parent.createSync(recursive: true);
  artifact.writeAsBytesSync(bytes);
  expect(bytes.length, greaterThan(8000), reason: '$name png is too small');
  expect(bytes[0], 0x89);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
