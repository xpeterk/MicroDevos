import '../../domain/enrichment/tagging_provider.dart';

/// Matches catalog slugs that appear as whole words. No network.
class KeywordTaggingProvider implements TaggingProvider {
  const KeywordTaggingProvider();

  static const seedSlugs = [
    'courage',
    'anxiety',
    'fear',
    'hope',
    'peace',
    'gratitude',
    'grief',
    'trust',
    'prayer',
    'rest',
    'scripture',
    'waiting',
    'perseverance',
    'identity',
    'work',
    'family',
  ];

  @override
  String get name => 'keyword';

  @override
  List<String> suggestTags(String text, {required List<String> catalogSlugs}) {
    return [
      for (final slug in catalogSlugs)
        if (_containsWord(text, slug)) slug,
    ];
  }

  bool _containsWord(String text, String slug) {
    return RegExp('\\b${RegExp.escape(slug)}\\b', caseSensitive: false).hasMatch(text);
  }
}
