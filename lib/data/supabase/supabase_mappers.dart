import '../../domain/models/devo.dart';
import '../../domain/models/scripture_quote.dart';

Devo devoFromRow(Map<String, dynamic> row) {
  final scriptures = (row['scriptures'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((item) => ScriptureQuote.fromJson(Map<String, dynamic>.from(item)))
      .toList();
  return Devo(
    id: row['id'].toString(),
    title: row['title'] as String? ?? '',
    hook: row['hook'] as String? ?? '',
    bodyMd: row['body_md'] as String? ?? '',
    takeaway: row['takeaway'] as String? ?? '',
    verseText: row['verse_text'] as String? ?? '',
    verseRef: row['verse_ref'] as String? ?? '',
    scriptures: scriptures,
    sourceUrl: row['source_url'] as String?,
    editionDate: parseDateOnly(row['edition_date'].toString()),
    editionUrl: row['edition_url'] as String?,
    position: row['position'] as int? ?? 0,
    stars: row['stars'] as int?,
    status: row['status'] as String? ?? '',
    notionPageId: row['notion_page_id'] as String?,
    imageUrl: row['image_url'] as String?,
    imageAlt: row['image_alt'] as String?,
    tags: tagsFromJoin(row['devo_tags']),
  );
}

List<String> tagsFromJoin(Object? value) {
  if (value is! List) return const [];
  final slugs = <String>[];
  for (final item in value) {
    if (item is! Map) continue;
    final tag = item['tags'];
    if (tag is Map && tag['slug'] is String) {
      slugs.add(tag['slug'] as String);
    }
  }
  return slugs;
}

Set<String> favoriteIdsFromRows(List<Map<String, dynamic>> rows) {
  return rows
      .map((row) => row['devo_id'])
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet();
}
