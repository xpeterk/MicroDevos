import '../../domain/enrichment/embedding_provider.dart';
import '../../domain/enrichment/tagging_provider.dart';

/// Deterministic embedding double for tests. It records the text and returns
/// the vector it was given. It does not open a socket.
class FakeEmbeddingProvider implements EmbeddingProvider {
  FakeEmbeddingProvider({List<double>? vector})
    : vector = vector ?? const [0.2, 0.4, 0.6, 0.8];

  final List<double> vector;
  final List<String> calls = [];

  @override
  String get name => 'fake';

  @override
  bool get isConfigured => true;

  @override
  Future<List<double>?> embed(String text) async {
    calls.add(text);
    return vector;
  }
}

/// Tagging double that returns a fixed list and records the text it saw.
class FakeTaggingProvider implements TaggingProvider {
  FakeTaggingProvider(this.tags);

  final List<String> tags;
  final List<String> calls = [];

  @override
  String get name => 'fake';

  @override
  List<String> suggestTags(String text, {required List<String> catalogSlugs}) {
    calls.add(text);
    return [
      for (final tag in tags)
        if (catalogSlugs.contains(tag)) tag,
    ];
  }
}
