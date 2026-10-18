import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/providers.dart';
import 'core/startup.dart';
import 'data/bible/bundled_kjv_verse_provider.dart';
import 'data/sample/sample_catalog.dart';

Future<void> main() async {
  await prepareFramework();
  final config = AppConfig.fromEnvironment();
  final preferences = await SharedPreferences.getInstance();
  final devosJson = await rootBundle.loadString('assets/sample/devos.json');
  final tagsJson = await rootBundle.loadString('assets/sample/tags.json');
  final kjvJson = await rootBundle.loadString('assets/bible/kjv.json');
  final catalog = SampleCatalog.parse(devosJson, tagsJson);
  final kjv = KjvBundle.parse(kjvJson);
  final client = await openSupabaseClient(config);

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        sharedPreferencesProvider.overrideWithValue(preferences),
        supabaseClientProvider.overrideWithValue(client),
        sampleCatalogProvider.overrideWith((ref) async => catalog),
        kjvBundleProvider.overrideWith((ref) async => kjv),
      ],
      child: const MicroDevosApp(),
    ),
  );
}
