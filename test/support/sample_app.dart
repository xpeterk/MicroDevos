import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:micro_devos/app.dart';
import 'package:micro_devos/core/config/app_config.dart';
import 'package:micro_devos/core/notifications/reminder_service.dart';
import 'package:micro_devos/core/providers.dart';
import 'package:micro_devos/data/bible/bundled_kjv_verse_provider.dart';
import 'package:micro_devos/data/sample/sample_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sampleClock = DateTime(2026, 10, 18);

/// The app as a release build with no dart-defines: sample catalog, no
/// Supabase client, reminders stubbed, clock fixed on Sunday 18 Oct 2026
/// so Today resolves to the Friday 16 Oct edition.
Future<Widget> buildSampleApp({
  required String themeMode,
  List<String> favoriteIds = const ['fri-1'],
}) async {
  SharedPreferences.setMockInitialValues({
    'theme_mode': themeMode,
    'favorite_devo_ids': favoriteIds,
  });
  final preferences = await SharedPreferences.getInstance();
  final catalog = SampleCatalog.parse(
    await _load('assets/sample/devos.json'),
    await _load('assets/sample/tags.json'),
  );
  final kjv = KjvBundle.parse(await _load('assets/bible/kjv.json'));
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(const AppConfig.offline()),
      sharedPreferencesProvider.overrideWithValue(preferences),
      supabaseClientProvider.overrideWithValue(null),
      sampleCatalogProvider.overrideWith((ref) async => catalog),
      kjvBundleProvider.overrideWith((ref) async => kjv),
      clockProvider.overrideWithValue(() => sampleClock),
      reminderServiceProvider.overrideWithValue(NoopReminderService()),
    ],
    child: const RepaintBoundary(
      key: Key('screen-capture'),
      child: MicroDevosApp(),
    ),
  );
}

Future<String> _load(String asset) => rootBundle.loadString(asset);
