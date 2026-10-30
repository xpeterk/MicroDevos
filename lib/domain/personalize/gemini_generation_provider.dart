import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/devo_section.dart';
import '../models/scripture_quote.dart';
import 'personalize_engine.dart';
import 'style_catalog.dart';

/// Calls the Gemini API to generate rich Christian devotionals
/// with the 1-minute micro devo, 3 sections, and prayer.
class GeminiGenerationProvider implements GenerationProvider {
  const GeminiGenerationProvider({
    required this.apiKey,
    this.model = 'gemini-2.5-flash',
    this.client,
  });

  final String apiKey;
  final String model;
  final http.Client? client;

  @override
  String get name => 'gemini';

  @override
  Future<GenerationDraft> generate(GenerateRequest request) async {
    final httpClient = client ?? http.Client();
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    final style = styleByKey(request.styleKey);
    final styleDesc =
        style != null ? '${style.label} (${style.blurb})' : request.styleKey;
    final contextBits = [
      if (request.ageRange != null && request.ageRange!.isNotEmpty)
        'Age: ${request.ageRange}',
      if (request.lifeSituations.isNotEmpty)
        'Life context: ${request.lifeSituations.join(", ")}',
      if (request.bibleVersion != null && request.bibleVersion!.isNotEmpty)
        'Translation: ${request.bibleVersion}',
    ];

    final promptBuilder = StringBuffer();
    if (request.verseMode && request.verseRefs.isNotEmpty) {
      promptBuilder.writeln(
        'Topic/Scripture to focus on: ${request.verseRefs.join(", ")}',
      );
    } else {
      promptBuilder.writeln('Devotional topic: ${request.topic}');
      if (request.verseRefs.isNotEmpty) {
        promptBuilder.writeln('Anchor verses: ${request.verseRefs.join(", ")}');
      }
    }
    promptBuilder.writeln('Writing style: $styleDesc');
    if (contextBits.isNotEmpty) {
      promptBuilder.writeln('Reader context: ${contextBits.join("; ")}');
    }

    promptBuilder.writeln('''
Write a rich, orthodox, warm, biblically grounded Christian micro-devotional tailored to this reader.
Format requirements:
1. "title": Engaging, evocative title (under 8 words).
2. "hook": One memorable hook sentence ("At a Glance") capturing the core theme.
3. "takeaway": One concise sentence takeaway.
4. "verse_ref": Primary Scripture reference (e.g. "Philippians 4:6-7").
5. "verse_text": The full Scripture text for the reference.
6. "one_minute_text": Exactly one paragraph of ~140 to 160 words summarizing the whole devotion clearly and compellingly for a quick 1-minute read.
7. "one_minute_today": A practical action/prayer takeaway sentence (e.g. "Pray for patience today, and deliberately listen before replying.").
8. "one_minute_verse_ref": Scripture reference for the 1-minute devotion (e.g. "Philippians 4:6").
9. "one_minute_verse_text": The Scripture text for that reference.
10. "sections": An array of exactly 3 sequential sections that walk through the devotion. Each section MUST have:
    - "title": Plain title without numbering (e.g. "The Noise in the Room", "Trusting in the Storm").
    - "summary": 1 short sentence summarizing this section.
    - "minutes": Integer reading time (1 or 2).
    - "verse_ref": A Scripture reference supporting this section.
    - "verse_text": The full verse text for this section.
    - "body": 1-2 rich, thoughtful paragraphs of reflection (using plain text or standard markdown).
11. "prayer": A warm, heartfelt closing prayer sentence starting with prayer or praise.
12. "scriptures": An array of exactly 2 ScriptureQuote objects with "reference" and "text" (one of them must be the primary verse_ref).

Return strictly a valid JSON object matching these keys.
''');

    try {
      final response = await httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': promptBuilder.toString()}
              ]
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'temperature': 0.7,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final rawJson = parts[0]['text'] as String?;
            if (rawJson != null && rawJson.trim().isNotEmpty) {
              final parsed = jsonDecode(rawJson) as Map<String, dynamic>;
              return _draftFromParsed(parsed, request);
            }
          }
        }
      }
    } catch (_) {
      // Fall through to fallback
    }

    return const FakeGenerationProvider().generate(request);
  }

  GenerationDraft _draftFromParsed(
    Map<String, dynamic> json,
    GenerateRequest request,
  ) {
    final title = json['title'] as String? ?? 'A Refuge in Every Season';
    final hook = json['hook'] as String? ?? 'God meets us in our deepest need.';
    final takeaway = json['takeaway'] as String? ?? 'Trust the Lord with all your heart.';
    final primaryRef = json['verse_ref'] as String? ??
        (request.verseMode && request.verseRefs.isNotEmpty
            ? request.verseRefs.first
            : 'Philippians 4:6-7');
    final primaryText = json['verse_text'] as String? ??
        'Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God.';

    final oneMin = json['one_minute_text'] as String?;
    final oneMinToday = json['one_minute_today'] as String?;
    final oneMinRef = json['one_minute_verse_ref'] as String? ?? primaryRef;
    final oneMinText = json['one_minute_verse_text'] as String? ?? primaryText;
    final prayer = json['prayer'] as String?;

    final rawSections = json['sections'] as List<dynamic>? ?? const [];
    final List<DevoSection> structured = [];
    final List<String> stringBodies = [];

    for (var i = 0; i < rawSections.length; i++) {
      final s = rawSections[i];
      if (s is Map) {
        final secTitle = s['title'] as String? ?? 'Part ${i + 1}';
        final secSummary = s['summary'] as String? ?? '';
        final secMinutes = (s['minutes'] as num?)?.toInt() ?? 1;
        final secVRef = s['verse_ref'] as String? ?? primaryRef;
        final secVText = s['verse_text'] as String? ?? primaryText;
        final secBody = s['body'] as String? ?? '';

        structured.add(
          DevoSection(
            id: 's${i + 1}',
            devoId: 'gen',
            position: i + 1,
            title: secTitle,
            summary: secSummary,
            minutes: secMinutes,
            verseRef: secVRef,
            verseText: secVText,
            body: secBody,
            tags: const [],
          ),
        );
        stringBodies.add(secBody);
      }
    }

    // Build at least 2 scriptures for the safety review
    final rawScriptures = (json['scriptures'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((m) => ScriptureQuote.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    List<ScriptureQuote> quotes = rawScriptures;
    if (quotes.length < 2) {
      final secondRef = structured.length > 1 && structured[1].verseRef.isNotEmpty
          ? structured[1].verseRef
          : (request.verseRefs.length > 1 ? request.verseRefs[1] : 'Psalm 23:1');
      final secondText = structured.length > 1 && structured[1].verseText.isNotEmpty
          ? structured[1].verseText
          : 'The LORD is my shepherd; I shall not want.';
      quotes = [
        ScriptureQuote(reference: primaryRef, text: primaryText),
        ScriptureQuote(reference: secondRef, text: secondText),
      ];
    }

    return GenerationDraft(
      title: title,
      hook: hook,
      sections: stringBodies,
      structuredSections: structured,
      takeaway: takeaway,
      verseText: primaryText,
      verseRef: primaryRef,
      oneMinuteText: oneMin,
      oneMinuteToday: oneMinToday,
      oneMinuteVerseRef: oneMinRef,
      oneMinuteVerseText: oneMinText,
      prayer: prayer,
      scriptures: quotes,
    );
  }
}
