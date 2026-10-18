/// Turns devotion text into a vector for later recommendation work.
///
/// The app ships a disabled implementation. A test double lives next to it.
/// Neither one calls a model or the network.
abstract class EmbeddingProvider {
  String get name;

  bool get isConfigured;

  /// Null means "leave the embedding column empty."
  Future<List<double>?> embed(String text);
}
