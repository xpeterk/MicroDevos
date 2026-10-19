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
  });

  final String id;
  final String title;
  final String hook;
  final List<String> sections;
  final String takeaway;
  final String verseText;
  final String verseRef;
  final List<ScriptureQuote> scriptures;
  final String styleKey;
  final String styleLabel;
  final String styleKind;
  final String promptLabel;
  final int reuseCount;

  bool get isClassic => styleKind == 'classic';

  String get bodyMd => sections.join('\n\n');

  GeneratedDevo copyWith({int? reuseCount}) {
    return GeneratedDevo(
      id: id,
      title: title,
      hook: hook,
      sections: sections,
      takeaway: takeaway,
      verseText: verseText,
      verseRef: verseRef,
      scriptures: scriptures,
      styleKey: styleKey,
      styleLabel: styleLabel,
      styleKind: styleKind,
      promptLabel: promptLabel,
      reuseCount: reuseCount ?? this.reuseCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'hook': hook,
    'sections': sections,
    'takeaway': takeaway,
    'verse_text': verseText,
    'verse_ref': verseRef,
    'scriptures': scriptures.map((quote) => quote.toJson()).toList(),
    'style_key': styleKey,
    'style_label': styleLabel,
    'style_kind': styleKind,
    'prompt_label': promptLabel,
    'reuse_count': reuseCount,
  };

  factory GeneratedDevo.fromJson(Map<String, dynamic> json) {
    return GeneratedDevo(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      hook: json['hook'] as String? ?? '',
      sections: (json['sections'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
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
    );
  }
}
