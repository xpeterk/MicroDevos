/// Suggests catalog tags for a devotion.
///
/// Implementations in this milestone stay on the device. They do not call a model.
abstract class TaggingProvider {
  String get name;

  List<String> suggestTags(String text, {required List<String> catalogSlugs});
}
