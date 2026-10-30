import 'devo.dart';
import 'devo_section.dart';
import 'scripture_quote.dart';

class GeneratedDevo {
  const GeneratedDevo({
    required this.id,
    required this.title,
    required this.hook,
    required this.sections,
    required this.takeaway,
    required this.verseText,
    required this.verseRef,
    required this.scriptures,
    required this.styleKey,
    required this.styleLabel,
    required this.styleKind,
    required this.promptLabel,
    required this.reuseCount,
    this.structuredSections = const [],
    this.oneMinuteText,
    this.oneMinuteVerseRef,
    this.oneMinuteVerseText,
    this.oneMinuteToday,
    this.prayer,
    this.helpNote,
  });

  final String id;
  final String title;
  final String hook;
  final List<String> sections;
  final List<DevoSection> structuredSections;
  final String takeaway;
  final String verseText;
  final String verseRef;
  final List<ScriptureQuote> scriptures;
  final String styleKey;
  final String styleLabel;
  final String styleKind;
  final String promptLabel;
  final int reuseCount;
  final String? helpNote;
  final String? oneMinuteText;
  final String? oneMinuteVerseRef;
  final String? oneMinuteVerseText;
  final String? oneMinuteToday;
  final String? prayer;

  bool get isClassic => styleKind == 'classic';

  bool get hasOneMinute =>
      oneMinuteText != null && oneMinuteText!.trim().isNotEmpty;

  String get bodyMd {
    if (structuredSections.isNotEmpty) {
      return structuredSections.map((s) => '### ${s.title}\n\n${s.body}').join('\n\n');
    }
    return sections.join('\n\n');
  }

  Devo toDevo() {
    final secs = structuredSections.isNotEmpty
        ? structuredSections
        : [
            for (var i = 0; i < sections.length; i++)
              DevoSection(
                id: '$id-s${i + 1}',
                devoId: id,
                position: i + 1,
                title: 'Part ${i + 1}',
                summary: '',
                minutes: 1,
                verseRef: i == 0 ? verseRef : '',
                verseText: i == 0 ? verseText : '',
                body: sections[i],
                tags: const [],
              ),
          ];

    return Devo(
      id: id,
      title: title,
      hook: hook,
      bodyMd: bodyMd,
      takeaway: takeaway,
      verseText: verseText,
      verseRef: verseRef,
      scriptures: scriptures,
      editionDate: DateTime.now(),
      position: 1,
      status: 'published',
      tags: const ['for-you', 'personalized'],
      sections: secs,
      oneMinuteText: oneMinuteText,
      oneMinuteVerseRef: oneMinuteVerseRef ?? verseRef,
      oneMinuteVerseText: oneMinuteVerseText ?? verseText,
      oneMinuteToday: oneMinuteToday,
      prayer: prayer ?? '',
    );
  }

  GeneratedDevo copyWith({int? reuseCount}) {
    return GeneratedDevo(
      id: id,
      title: title,
      hook: hook,
      sections: sections,
      structuredSections: structuredSections,
      takeaway: takeaway,
      verseText: verseText,
      verseRef: verseRef,
      scriptures: scriptures,
      styleKey: styleKey,
      styleLabel: styleLabel,
      styleKind: styleKind,
      promptLabel: promptLabel,
      helpNote: helpNote,
      oneMinuteText: oneMinuteText,
      oneMinuteVerseRef: oneMinuteVerseRef,
      oneMinuteVerseText: oneMinuteVerseText,
      oneMinuteToday: oneMinuteToday,
      prayer: prayer,
      reuseCount: reuseCount ?? this.reuseCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'hook': hook,
    'sections': sections,
    'structured_sections': structuredSections.map((s) => s.toJson()).toList(),
    'takeaway': takeaway,
    'verse_text': verseText,
    'verse_ref': verseRef,
    'scriptures': scriptures.map((quote) => quote.toJson()).toList(),
    'style_key': styleKey,
    'style_label': styleLabel,
    'style_kind': styleKind,
    'prompt_label': promptLabel,
    'reuse_count': reuseCount,
    'help_note': helpNote,
    'one_minute_text': oneMinuteText,
    'one_minute_verse_ref': oneMinuteVerseRef,
    'one_minute_verse_text': oneMinuteVerseText,
    'one_minute_today': oneMinuteToday,
    'prayer': prayer,
  };

  factory GeneratedDevo.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List<dynamic>? ?? const [];
    final List<String> stringSections = [];
    final List<DevoSection> parsedSections = [];

    final rawStructured = json['structured_sections'] as List<dynamic>?;
    if (rawStructured != null && rawStructured.isNotEmpty) {
      for (final item in rawStructured) {
        if (item is Map) {
          parsedSections.add(
            DevoSection.fromJson(
              Map<String, dynamic>.from(item),
              devoId: json['id'] as String? ?? '',
            ),
          );
        }
      }
    }

    for (var i = 0; i < rawSections.length; i++) {
      final item = rawSections[i];
      if (item is Map) {
        final sec = DevoSection.fromJson(
          Map<String, dynamic>.from(item),
          devoId: json['id'] as String? ?? '',
        );
        parsedSections.add(sec);
        stringSections.add(sec.body);
      } else {
        stringSections.add(item.toString());
      }
    }

    return GeneratedDevo(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      hook: json['hook'] as String? ?? '',
      sections: stringSections,
      structuredSections: parsedSections,
      takeaway: json['takeaway'] as String? ?? '',
      verseText: json['verse_text'] as String? ?? '',
      verseRef: json['verse_ref'] as String? ?? '',
      scriptures: (json['scriptures'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => ScriptureQuote.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      styleKey: json['style_key'] as String? ?? '',
      styleLabel: json['style_label'] as String? ?? '',
      styleKind: json['style_kind'] as String? ?? 'style',
      promptLabel: json['prompt_label'] as String? ?? '',
      reuseCount: json['reuse_count'] as int? ?? 0,
      helpNote: (json['help_note'] as String?)?.trim().isNotEmpty == true
          ? (json['help_note'] as String).trim()
          : null,
      oneMinuteText: json['one_minute_text'] as String?,
      oneMinuteVerseRef: json['one_minute_verse_ref'] as String?,
      oneMinuteVerseText: json['one_minute_verse_text'] as String?,
      oneMinuteToday: json['one_minute_today'] as String?,
      prayer: json['prayer'] as String?,
    );
  }
}
