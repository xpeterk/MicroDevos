/// One stand-alone part of a devotion. [body] is the same JSON block
/// document stored in `devos.body_md`.
class DevoSection {
  const DevoSection({
    required this.id,
    required this.devoId,
    required this.position,
    required this.title,
    required this.summary,
    required this.minutes,
    required this.verseRef,
    required this.verseText,
    required this.body,
    this.tags = const [],
    this.imageUrl,
    this.imageAlt,
  });

  final String id;
  final String devoId;
  final int position;
  final String title;
  final String summary;
  final int minutes;
  final String verseRef;
  final String verseText;
  final String body;
  final List<String> tags;

  /// Half-height banner shown only while this section is expanded. Null means no strip.
  final String? imageUrl;

  /// Alt text for [imageUrl].
  final String? imageAlt;

  factory DevoSection.fromJson(
    Map<String, dynamic> json, {
    String devoId = '',
  }) {
    final tags = json['tags'];
    return DevoSection(
      id: json['id']?.toString() ?? '',
      devoId: json['devo_id']?.toString() ?? devoId,
      position: json['position'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      minutes: json['minutes'] as int? ?? 1,
      verseRef: json['verse_ref'] as String? ?? '',
      verseText: json['verse_text'] as String? ?? '',
      body: json['body'] as String? ?? '',
      tags: tags is List ? tags.whereType<String>().toList() : const <String>[],
      imageUrl: json['image_url'] as String?,
      imageAlt: json['image_alt'] as String?,
    );
  }

  DevoSection copyWith({List<String>? tags}) {
    return DevoSection(
      id: id,
      devoId: devoId,
      position: position,
      title: title,
      summary: summary,
      minutes: minutes,
      verseRef: verseRef,
      verseText: verseText,
      body: body,
      tags: tags ?? this.tags,
      imageUrl: imageUrl,
      imageAlt: imageAlt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'devo_id': devoId,
    'position': position,
    'title': title,
    'summary': summary,
    'minutes': minutes,
    'verse_ref': verseRef,
    'verse_text': verseText,
    'body': body,
    'tags': tags,
    'image_url': imageUrl,
    'image_alt': imageAlt,
  };
}

class SectionFavorite {
  const SectionFavorite({required this.devoId, required this.sectionId});

  final String devoId;
  final String sectionId;

  Map<String, dynamic> toJson() => {'devo_id': devoId, 'section_id': sectionId};

  factory SectionFavorite.fromJson(Map<String, dynamic> json) {
    return SectionFavorite(
      devoId: json['devo_id']?.toString() ?? '',
      sectionId: json['section_id']?.toString() ?? '',
    );
  }
}
