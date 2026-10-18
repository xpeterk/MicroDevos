import '../../domain/models/bible_version.dart';

class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.esvApiKey,
    required this.apiBibleKey,
    required this.apiBibleIds,
  });

  factory AppConfig.fromEnvironment() {
    return AppConfig(
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      esvApiKey: const String.fromEnvironment('ESV_API_KEY'),
      apiBibleKey: const String.fromEnvironment('API_BIBLE_KEY'),
      apiBibleIds: {
        BibleVersion.niv: const String.fromEnvironment('API_BIBLE_ID_NIV'),
        BibleVersion.nlt: const String.fromEnvironment('API_BIBLE_ID_NLT'),
        BibleVersion.nkjv: const String.fromEnvironment('API_BIBLE_ID_NKJV'),
        BibleVersion.csb: const String.fromEnvironment('API_BIBLE_ID_CSB'),
        BibleVersion.nasb: const String.fromEnvironment('API_BIBLE_ID_NASB'),
      },
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String esvApiKey;
  final String apiBibleKey;
  final Map<BibleVersion, String> apiBibleIds;

  bool get useSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  String bibleIdFor(BibleVersion version) => apiBibleIds[version] ?? '';
}
