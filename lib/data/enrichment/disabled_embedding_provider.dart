import '../../domain/enrichment/embedding_provider.dart';

/// Leaves `embedding` null. This is the provider the app uses.
class DisabledEmbeddingProvider implements EmbeddingProvider {
  const DisabledEmbeddingProvider();

  @override
  String get name => 'disabled';

  @override
  bool get isConfigured => false;

  @override
  Future<List<double>?> embed(String text) async => null;
}
