import 'devo_section.dart';
import 'scripture_quote.dart';

class Devo {
  const Devo({
    required this.id,
    required this.title,
    required this.hook,
    required this.bodyMd,
    required this.takeaway,
    required this.verseText,
    required this.verseRef,
    required this.scriptures,
    required this.editionDate,
    required this.position,
    required this.status,
    required this.tags,
    this.sections = const [],
    this.sourceUrl,
    this.editionUrl,
    this.stars,
    this.notionPageId,
    this.imageUrl,
    this.imageAlt,
    this.teaser = '',
    this.prayer = '',
  });

  final String id;
  final String title;
  final String hook;
  final String bodyMd;
  final String takeaway;
  final String verseText;
  final String verseRef;
  final List<ScriptureQuote> scriptures;
  final String? sourceUrl;
  final DateTime editionDate;
  final String? editionUrl;
  final int position;
  final int? stars;
  final String status;
  final String? notionPageId;
  final List<String> tags;

  /// Empty means the full devotion is the body, as it was before sections.
  final List<DevoSection> sections;

  /// Optional banner. Null means the feed paints a placeholder.
  final String? imageUrl;

  /// Alt text for [imageUrl]. Null when no banner was matched.
  final String? imageAlt;

  /// Summary under the title. Empty when the card has none.
  final String teaser;

  /// Prayer sentence, without a Today label. Empty when the card has none.
  final String prayer;

  String get dateKey => dateKeyOf(editionDate);

  Devo copyWith({List<DevoSection>? sections}) {
    return Devo(
      id: id,
      title: title,
      hook: hook,
      bodyMd: bodyMd,
      takeaway: takeaway,
      verseText: verseText,
      verseRef: verseRef,
      scriptures: scriptures,
      editionDate: editionDate,
      position: position,
      status: status,
      tags: tags,
      sections: sections ?? this.sections,
      sourceUrl: sourceUrl,
      editionUrl: editionUrl,
      stars: stars,
      notionPageId: notionPageId,
      imageUrl: imageUrl,
      imageAlt: imageAlt,
      teaser: teaser,
      prayer: prayer,
    );
  }

  String toShareText() {
    return [
      title,
      '',
      'At a Glance',
      hook,
      '',
      takeaway,
      '',
      verseText,
      '— $verseRef',
      '',
      'Micro Devos',
    ].join('\n');
  }

  factory Devo.fromJson(Map<String, dynamic> json) {
    final scriptures = (json['scriptures'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => ScriptureQuote.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return Devo(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      hook: json['hook'] as String? ?? '',
      bodyMd: json['body_md'] as String? ?? '',
      takeaway: json['takeaway'] as String? ?? '',
      verseText: json['verse_text'] as String? ?? '',
      verseRef: json['verse_ref'] as String? ?? '',
      scriptures: scriptures,
      sourceUrl: json['source_url'] as String?,
      editionDate: parseDateOnly(json['edition_date'] as String),
      editionUrl: json['edition_url'] as String?,
      position: json['position'] as int? ?? 0,
      stars: json['stars'] as int?,
      status: json['status'] as String? ?? 'published',
      notionPageId: json['notion_page_id'] as String?,
      imageUrl: json['image_url'] as String?,
      imageAlt: json['image_alt'] as String?,
      teaser: json['teaser'] as String? ?? '',
      prayer: json['prayer'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      sections: (json['sections'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => DevoSection.fromJson(
              Map<String, dynamic>.from(item),
              devoId: json['id'] as String? ?? '',
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'hook': hook,
    'body_md': bodyMd,
    'takeaway': takeaway,
    'verse_text': verseText,
    'verse_ref': verseRef,
    'scriptures': scriptures.map((quote) => quote.toJson()).toList(),
    'source_url': sourceUrl,
    'edition_date': dateKey,
    'edition_url': editionUrl,
    'position': position,
    'stars': stars,
    'status': status,
    'notion_page_id': notionPageId,
    'image_url': imageUrl,
    'image_alt': imageAlt,
    'teaser': teaser,
    'prayer': prayer,
    'tags': tags,
    'sections': sections.map((section) => section.toJson()).toList(),
  };
}

DateTime parseDateOnly(String iso) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso.trim());
  if (match == null) {
    throw FormatException('Not a calendar date: $iso');
  }
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

String dateKeyOf(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

bool isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
