import 'dart:convert';

import '../../domain/models/devo.dart';
import '../../domain/models/tag.dart';

class SampleCatalog {
  const SampleCatalog({required this.devos, required this.tags});

  final List<Devo> devos;
  final List<Tag> tags;

  factory SampleCatalog.parse(String devosJson, String tagsJson) {
    final devoList = (jsonDecode(devosJson) as List<dynamic>)
        .whereType<Map>()
        .map((item) => Devo.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final tagList = (jsonDecode(tagsJson) as List<dynamic>)
        .whereType<Map>()
        .map((item) => Tag.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return SampleCatalog(devos: devoList, tags: tagList);
  }

  Tag? tagBySlug(String slug) {
    for (final tag in tags) {
      if (tag.slug == slug) return tag;
    }
    return null;
  }
}
