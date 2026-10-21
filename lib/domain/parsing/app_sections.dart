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
