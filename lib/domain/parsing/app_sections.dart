import '../content/rich_document.dart';
import '../models/devo_section.dart';

/// A devotion section parsed from the optional `## App Sections` block.
class ParsedAppSection {
  const ParsedAppSection({
    required this.position,
    required this.title,
    required this.summary,
    required this.minutes,
    required this.verseRef,
    required this.verseText,
    required this.body,
    required this.tags,
  });

  final int position;
  final String title;
  final String summary;
  final int minutes;
  final String verseRef;
  final String verseText;

  /// JSON block document, same shape as `body_md`.
  final String body;
  final List<String> tags;

  DevoSection toSection({required String devoId, String? id}) {
    return DevoSection(
      id: id ?? '$devoId-$position',
      devoId: devoId,
      position: position,
      title: title,
      summary: summary,
      minutes: minutes,
      verseRef: verseRef,
      verseText: verseText,
      body: body,
      tags: tags,
    );
  }
}

class AppSectionSplit {
  const AppSectionSplit({required this.prose, required this.sections});

  final String prose;
  final List<ParsedAppSection> sections;
}

final _appSectionsHeading = RegExp(r'^##\s+App Sections\s*$', multiLine: true);

/// Removes a trailing `## App Sections` block and parses its `###` parts.
/// Text with no such heading comes back unchanged and with no sections.
AppSectionSplit splitAppSections(String section) {
  final match = _appSectionsHeading.firstMatch(section);
  if (match == null) {
    return AppSectionSplit(prose: section, sections: const []);
  }
  final prose = section.substring(0, match.start).trim();
  final rest = section.substring(match.end).trim();
  return AppSectionSplit(prose: prose, sections: parseAppSectionBlock(rest));
}

List<ParsedAppSection> parseAppSectionBlock(String block) {
  final chunks = block.split(RegExp(r'\n(?=###\s+)'));
  final sections = <ParsedAppSection>[];
  for (final chunk in chunks) {
    final trimmed = chunk.trim();
    if (!trimmed.startsWith('###')) continue;
    final lines = trimmed.split('\n');
    final title = lines.first.replaceFirst(RegExp(r'^###\s+'), '').trim();
    if (title.isEmpty) continue;
    final parsed = _parseFields(lines.skip(1).toList());
    sections.add(
      ParsedAppSection(
        position: sections.length + 1,
        title: title,
        summary: parsed.summary,
        minutes: parsed.minutes,
        verseRef: parsed.verseRef,
        verseText: parsed.verseText,
        body: encodeContent(markdownToBlocks(parsed.body)),
        tags: parsed.tags,
      ),
    );
  }
  return sections;
}

class _Fields {
  const _Fields({
    required this.summary,
    required this.minutes,
    required this.verseRef,
    required this.verseText,
    required this.body,
    required this.tags,
  });

  final String summary;
  final int minutes;
  final String verseRef;
  final String verseText;
  final String body;
  final List<String> tags;
}

_Fields _parseFields(List<String> lines) {
  var summary = '';
  var minutes = 1;
  var verseRef = '';
  var verseText = '';
  final tags = <String>[];
  final body = <String>[];
  var started = false;
  for (final raw in lines) {
    final trimmed = raw.trim();
    if (!started) {
      if (trimmed.isEmpty) continue;
      final summaryMatch = RegExp(
        r'^Summary:\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (summaryMatch != null) {
        summary = summaryMatch.group(1)!.trim();
        continue;
      }
      final verseMatch = RegExp(
        '^Verse:\\s*(.+?)\\s*[—–-]\\s*[“"]([^”"]+)[”"]\\s*\$',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (verseMatch != null) {
        verseRef = verseMatch.group(1)!.trim();
        verseText = verseMatch.group(2)!.trim();
        continue;
      }
      final tagsMatch = RegExp(
        r'^Tags:\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (tagsMatch != null) {
        tags
          ..clear()
          ..addAll(_tagSlugs(tagsMatch.group(1)!));
        continue;
      }
      final minutesMatch = RegExp(
        r'^Minutes:\s*(\d+)',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (minutesMatch != null) {
        final value = int.tryParse(minutesMatch.group(1)!) ?? 1;
        minutes = value < 1 ? 1 : value;
        continue;
      }
      started = true;
    }
    body.add(raw);
  }
  return _Fields(
    summary: summary,
    minutes: minutes,
    verseRef: verseRef,
    verseText: verseText,
    body: body.join('\n').trim(),
    tags: tags,
  );
}

final _inlineHeading = RegExp(r'^###\s+\S', multiLine: true);

/// Turns v6 `###` headings into sections.
///
/// A v6 devotion puts the banner sentence and the teaser on one line, then
/// the section headings. Older cards use `###` as body headings, and those
/// stay in the prose. A trailing prayer, closing line, verse callout, or
/// share card is left out of the last section.
AppSectionSplit splitInlineSections(String prose) {
  final heading = _inlineHeading.firstMatch(prose);
  if (heading == null) {
    return AppSectionSplit(prose: prose, sections: const []);
  }
  final intro = prose.substring(0, heading.start).trim();
  if (!_introHasV6Lead(intro)) {
    return AppSectionSplit(prose: prose, sections: const []);
  }
  final chunks = prose.substring(heading.start).split(RegExp(r'\n(?=###\s+)'));
  final sections = <ParsedAppSection>[];
  for (var index = 0; index < chunks.length; index++) {
    final chunk = chunks[index].trim();
    if (!chunk.startsWith('###')) continue;
    final lines = chunk.split('\n');
    final title = lines.first.replaceFirst(RegExp(r'^###\s+'), '').trim();
    if (title.isEmpty) continue;
    final bodyLines = index == chunks.length - 1
        ? _withoutTrailer(lines.skip(1).toList())
        : lines.skip(1).toList();
    final body = bodyLines.join('\n').trim();
    final verse = _verseFromBody(body);
    sections.add(
      ParsedAppSection(
        position: sections.length + 1,
        title: title,
        summary: '',
        minutes: 1,
        verseRef: verse.$1,
        verseText: verse.$2,
        body: encodeContent(markdownToBlocks(body)),
        tags: const [],
      ),
    );
  }
  if (sections.isEmpty) {
    return AppSectionSplit(prose: prose, sections: const []);
  }
  return AppSectionSplit(prose: intro, sections: sections);
}

/// Banner bold and italic teaser share one line in the v6 format.
bool _introHasV6Lead(String intro) {
  final bold = RegExp(r'\*\*(.+?)\*\*');
  final italic = RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)');
  for (final raw in intro.split('\n')) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) continue;
    if (bold.hasMatch(trimmed) && italic.hasMatch(trimmed)) return true;
  }
  return false;
}

List<String> _withoutTrailer(List<String> lines) {
  final kept = <String>[];
  for (final line in lines) {
    if (_isTrailer(line)) break;
    kept.add(line);
  }
  return kept;
}

bool _isTrailer(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return false;
  final plain = trimmed.replaceAll('**', '').trim();
  if (plain.startsWith('🙏')) return true;
  if (RegExp(r'^Today\b', caseSensitive: false).hasMatch(plain)) return true;
  if (RegExp(r'^Share card\s*:', caseSensitive: false).hasMatch(plain)) {
    return true;
  }
  if (RegExp(r'^Source\s*:', caseSensitive: false).hasMatch(plain)) return true;
  if (RegExp(r'^Edition\s*:', caseSensitive: false).hasMatch(plain)) {
    return true;
  }
  if (trimmed.startsWith(':::')) return true;
  if (RegExp(r'^\*\*[^*].+\*\*$').hasMatch(trimmed)) return true;
  return false;
}

(String, String) _verseFromBody(String body) {
  final quote = RegExp(
    r'^>\s*(.+)$',
    multiLine: true,
  ).firstMatch(body)?.group(1)?.trim();
  if (quote == null || quote.isEmpty) return ('', '');
  final match = RegExp(
    r'^(.*?)(?:\s+[—–-]\s*|\s+)((?:[1-3]\s)?(?:[A-Z][A-Za-z]+\.?\s+){1,3}\d+:\d+(?:-\d+)?)(?:\s+(?:ESV|NIV|KJV|NLT|NKJV|CSB|NASB))?\s*$',
  ).firstMatch(quote);
  if (match == null) return ('', '');
  return (match.group(2)!.trim(), match.group(1)!.trim());
}

List<String> _tagSlugs(String raw) {
  final slugs = <String>[];
  for (final part in raw.split(',')) {
    final slug = part
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isNotEmpty) slugs.add(slug);
  }
  return slugs;
}
