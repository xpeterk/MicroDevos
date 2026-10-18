import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:micro_devos/core/config/app_config.dart';
import 'package:micro_devos/core/format/edition_date_format.dart';
import 'package:micro_devos/core/startup.dart';
import 'package:micro_devos/core/theme/app_theme.dart';
import 'package:micro_devos/domain/models/bible_version.dart';

import 'support/sample_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('empty environment stays on sample data', () async {
    final config = AppConfig.fromEnvironment();
    expect(config.supabaseUrl, isEmpty);
    expect(config.supabaseAnonKey, isEmpty);
    expect(config.useSupabase, isFalse);
    expect(await openSupabaseClient(config), isNull);
    expect(await openSupabaseClient(const AppConfig.offline()), isNull);
  });

  test('blank, whitespace, and host-only URLs do not initialize Supabase', () {
    expect(const AppConfig.offline().useSupabase, isFalse);
    expect(_config(url: '', key: '').useSupabase, isFalse);
    expect(_config(url: '   ', key: 'anon').useSupabase, isFalse);
    expect(
      _config(url: 'https://example.supabase.co', key: '  ').useSupabase,
      isFalse,
    );
    expect(
      _config(url: 'example.supabase.co', key: 'anon').useSupabase,
      isFalse,
    );
    expect(
      _config(url: 'https://example.supabase.co', key: 'anon').useSupabase,
      isTrue,
    );
    expect(
      _config(url: 'http://127.0.0.1:54321', key: 'anon').useSupabase,
      isTrue,
    );
  });

  test(
    'DateFormat throws in a fresh isolate until locale data is loaded',
    () async {
      final message = await Isolate.run(probeUninitializedDateFormat);
      expect(message, contains('Locale data has not been initialized'));
    },
  );

  test('edition labels stay readable when intl data is missing', () {
    expect(formatEditionDate(DateTime(2026, 10, 16), 'EEEE'), 'Friday');
    expect(
      formatEditionDate(DateTime(2026, 10, 16), 'MMMM d, y'),
      'October 16, 2026',
    );
    expect(formatEditionDate(DateTime(2026, 10, 16), 'MMM d'), 'Oct 16');
    expect(
      formatEditionDate(DateTime(2026, 10, 16), 'EEEE, MMMM d'),
      'Friday, October 16',
    );
  });

  test('prepareFramework loads the symbols Today formats with', () async {
    await prepareFramework();
    expect(DateFormat('EEEE').format(DateTime(2026, 10, 16)), 'Friday');
    expect(
      DateFormat('MMMM d, y').format(DateTime(2026, 10, 16)),
      'October 16, 2026',
    );
  });

  testWidgets('a build failure paints copy on paper', (tester) async {
    final previous = ErrorWidget.builder;
    try {
      await prepareFramework();
      await tester.pumpWidget(const MaterialApp(home: _ExplodingScreen()));
      expect(tester.takeException(), isNotNull);
      expect(
        find.textContaining('This screen could not be drawn.'),
        findsOneWidget,
      );
      final box = tester.widget<ColoredBox>(
        find.byKey(const Key('readable-error')),
      );
      expect(box.color, AppColors.paper);
    } finally {
      ErrorWidget.builder = previous;
    }
  });

  testWidgets(
    'no keys render Friday sample devotions, not an error or empty shell',
    (tester) async {
      final previous = ErrorWidget.builder;
      try {
        await prepareFramework();
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(await buildSampleApp(themeMode: 'light'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('The devotions could not be loaded'), findsNothing);
        expect(find.text('This screen could not be drawn.'), findsNothing);
        expect(find.text('A Refuge That Does Not Move'), findsOneWidget);
        expect(find.textContaining('OCT 16'), findsOneWidget);
        expect(find.textContaining('8 DEVOS'), findsOneWidget);
        expect(
          find.textContaining('Showing Friday, October 16'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        ErrorWidget.builder = previous;
      }
    },
  );
}

AppConfig _config({required String url, required String key}) {
  return AppConfig(
    supabaseUrl: url,
    supabaseAnonKey: key,
    esvApiKey: '',
    apiBibleKey: '',
    apiBibleIds: const {BibleVersion.niv: ''},
  );
}

String probeUninitializedDateFormat() {
  try {
    DateFormat('EEEE', 'fr_FR').format(DateTime(2026, 10, 16));
    return 'formatted';
  } on Object catch (error) {
    return error.toString();
  }
}

class _ExplodingScreen extends StatelessWidget {
  const _ExplodingScreen();

  @override
  Widget build(BuildContext context) {
    throw StateError('boom');
  }
}
