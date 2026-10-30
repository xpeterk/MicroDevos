import '../../domain/models/bible_version.dart';

class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.esvApiKey,
    required this.apiBibleKey,
    required this.apiBibleIds,
    this.geminiApiKey = '',
  });

  /// No keys. Repositories stay on the bundled sample catalog.
  const AppConfig.offline()
    : supabaseUrl = '',
      supabaseAnonKey = '',
      esvApiKey = '',
      apiBibleKey = '',
      geminiApiKey = '',
      apiBibleIds = const {};

  factory AppConfig.fromEnvironment() {
    return AppConfig(
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL').trim(),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY').trim(),
      esvApiKey: const String.fromEnvironment('ESV_API_KEY').trim(),
      apiBibleKey: const String.fromEnvironment('API_BIBLE_KEY').trim(),
      geminiApiKey: const String.fromEnvironment('GEMINI_API_KEY').trim(),
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
  final String geminiApiKey;
  final Map<BibleVersion, String> apiBibleIds;

  /// True only for an http(s) URL with a host and a non-empty anon key.
  ///
  /// Empty defines, whitespace, and a bare host never reach Supabase
  /// initialization. That call runs before the first Flutter frame; a throw
  /// there leaves the Android launch window up.
  bool get useSupabase {
    if (supabaseAnonKey.trim().isEmpty) return false;
    final uri = Uri.tryParse(supabaseUrl.trim());
    if (uri == null || uri.host.isEmpty) return false;
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'https' || scheme == 'http';
  }

  String bibleIdFor(BibleVersion version) => apiBibleIds[version] ?? '';
}
