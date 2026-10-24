import '../content/rich_document.dart';
import '../models/scripture_quote.dart';
import 'app_sections.dart';

/// Metadata from a Micro Devos Cards row. The page body still has to be parsed.
class NotionCardMeta {
  const NotionCardMeta({
    this.title = '',
    this.status,
    this.editionDate,
    this.stars,
    this.sourceUrl,
    this.notionPageId,
  });

  final String title;
  final String? status;
  final String? editionDate;
  final int? stars;
  final String? sourceUrl;
  final String? notionPageId;
}

class ImportDecision {
  const ImportDecision._(this.shouldImport, this.reason);

  const ImportDecision.import() : this._(true, null);

  const ImportDecision.skip(String reason) : this._(false, reason);

  final bool shouldImport;
  final String? reason;
}

class ParsedDevo {
  const ParsedDevo({
    required this.title,
    required this.hook,
    required this.bodyMd,
    required this.takeaway,
    required this.verseText,
    required this.verseRef,
    required this.scriptures,
    required this.position,
    this.sourceUrl,
    this.editionDate,
    this.editionUrl,
    this.stars,
    this.status,
    this.notionPageId,
    this.sections = const [],
    this.teaser = '',
    this.prayer = '',
  });

  final String title;
  final String hook;
  final String bodyMd;
  final String takeaway;
  final String verseText;
  final String verseRef;
  final List<ScriptureQuote> scriptures;
  final String? sourceUrl;
  final String? editionDate;
  final String? editionUrl;
  final int position;
  final int? stars;
  final String? status;
  final String? notionPageId;
  final List<ParsedAppSection> sections;
  final String teaser;
  final String prayer;

  Map<String, dynamic> toJson() => {
    'title': title,
    'hook': hook,
    'body_md': bodyMd,
    'takeaway': takeaway,
    'verse_text': verseText,
    'verse_ref': verseRef,
    'scriptures': scriptures.map((quote) => quote.toJson()).toList(),
    'source_url': sourceUrl,
    'edition_date': editionDate,
    'edition_url': editionUrl,
    'position': position,
    'stars': stars,
    'status': status,
    'notion_page_id': notionPageId,
    'teaser': teaser,
    'prayer': prayer,
  };
}

/// Turns a Micro Devos card body into devotion fields.
///
/// The importer converts Notion blocks into this markdown shape first:
/// headings, `**bold**`, `> quotes`, and `:::callout` blocks for the verse box.
class NotionDevoParser {
  static final _numberedHeading = RegExp(
    r'^##\s+(\d+)\s*[·•|\-–—]\s+(.+?)\s*$',
    multiLine: true,
  );

  static final _substackLink = RegExp(
    r'\[([^\]]*)\]\((https?:\/\/[^)\s]*substack\.com[^)\s]*)\)',
  );

  static final _anyLink = RegExp(r'\[([^\]]*)\]\((https?:\/\/[^)\s]+)\)');

  static final _verseRef = RegExp(
    r'((?:[1-3]\s)?(?:[A-Z][A-Za-z]+\.?\s+){1,3}\d+:\d+(?:-\d+)?)',
  );

  static final _versionSuffix = RegExp(
    r'\s+(?:ESV|NIV|KJV|NLT|NKJV|CSB|NASB)\s*$',
  );

  static ImportDecision decide({
    required String? status,
    required String title,
    required String markdown,
  }) {
    final normalizedStatus = (status ?? '').trim().toLowerCase();
    if (normalizedStatus == 'ideas' || normalizedStatus == 'ai-ideas') {
      return ImportDecision.skip('status is $status');
    }
    final normalizedTitle = title.trim().toLowerCase();
    if (normalizedTitle == 'prompt' ||
        normalizedTitle.startsWith('prompt ') ||
        normalizedTitle.startsWith('prompt:')) {
      return const ImportDecision.skip('non-devo page');
    }
    if (editionUrlFrom(markdown) == null) {
      return const ImportDecision.skip('no edition link');
    }
    if (!_numberedHeading.hasMatch(markdown)) {
      return const ImportDecision.skip('no numbered devotion heading');
    }
    return const ImportDecision.import();
  }

  static String? editionUrlFrom(String markdown) {
    for (final line in markdown.split('\n')) {
      final lower = line.toLowerCase();
      final mentionsEdition = lower.contains('edition');
      for (final match in _substackLink.allMatches(line)) {
        final text = (match.group(1) ?? '').toLowerCase();
        if (mentionsEdition || text.contains('micro devos')) {
          return _withoutFragment(match.group(2)!);
        }
      }
    }
    return null;
  }

  static List<ParsedDevo> parse(String markdown, {NotionCardMeta? meta}) {
    final card = meta ?? const NotionCardMeta();
    final text = markdown.replaceAll('\r\n', '\n').trim();
    final editionUrl = editionUrlFrom(text) ?? _firstSubstack(text);
    final sourceUrl = _sourceUrl(text) ?? card.sourceUrl;
    final headings = _numberedHeading.allMatches(text).toList();
    if (headings.isEmpty) return const [];

    final preamble = text.substring(0, headings.first.start);
    final hook = _hookFrom(preamble);
    final glanceScriptures = _glanceScriptures(preamble);

    final devos = <ParsedDevo>[];
    for (var index = 0; index < headings.length; index++) {
      final heading = headings[index];
      final start = heading.end;
      final end = index + 1 < headings.length
          ? headings[index + 1].start
          : text.length;
      final section = text.substring(start, end).trim();
      final parsed = _parseSection(section);
      final scriptures = [...glanceScriptures, ...parsed.scriptures];
      devos.add(
        ParsedDevo(
          title: _stripLeadingSymbols(heading.group(2)!.trim()),
          hook: hook,
          bodyMd: parsed.body,
          takeaway: parsed.takeaway,
          verseText: parsed.verseText,
          verseRef: parsed.verseRef,
          scriptures: _uniqueScriptures(scriptures),
          sourceUrl: sourceUrl,
          editionDate: card.editionDate,
          editionUrl: editionUrl,
          position: int.parse(heading.group(1)!),
          stars: card.stars,
          status: card.status,
          notionPageId: card.notionPageId,
          sections: parsed.sections,
          teaser: parsed.teaser,
          prayer: parsed.prayer,
        ),
      );
    }
    return devos;
  }

  static int? starsFromLabel(String? label) {
    if (label == null || label.isEmpty) return null;
    final count = '★'.allMatches(label).length;
    if (count == 0) return null;
    return count.clamp(1, 3);
  }

  static String _hookFrom(String preamble) {
    final lines = preamble.split('\n');
    for (final line in lines) {
      final bold = RegExp(r'\*\*(.+?)\*\*').firstMatch(line);
      if (bold == null) continue;
      final value = bold.group(1)!.trim();
      if (value.toLowerCase().startsWith('at a glance')) continue;
      return _stripLeadingSymbols(value);
    }
    return '';
  }

  static List<ScriptureQuote> _glanceScriptures(String preamble) {
    final quotes = <ScriptureQuote>[];
    for (final raw in preamble.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('**')) {
        continue;
      }
      final match = RegExp(
        r'^((?:[1-3]\s)?(?:[A-Z][A-Za-z]+\.?\s+){1,3}\d+:\d+(?:-\d+)?)\s*:\s+(.+)$',
      ).firstMatch(line);
      if (match == null) continue;
      quotes.add(
        ScriptureQuote(
          reference: _cleanRef(match.group(1)!),
          text: match.group(2)!.trim(),
        ),
      );
    }
    return quotes;
  }

  static _Section _parseSection(String section) {
    final prayer = _prayerFrom(section);
    final appSplit = splitAppSections(section);
    final inline = appSplit.sections.isEmpty
        ? splitInlineSections(appSplit.prose)
        : const AppSectionSplit(prose: '', sections: []);
    final sections = appSplit.sections.isNotEmpty
        ? appSplit.sections
        : inline.sections;
    final usingInline = appSplit.sections.isEmpty && inline.sections.isNotEmpty;
    section = usingInline ? inline.prose : appSplit.prose;
    final lead = usingInline ? _leadFrom(section) : null;
    if (lead != null) {
      section = section.replaceFirst(lead.raw, '').trim();
    }
    final callout = RegExp(r':::callout\s*\n([\s\S]*?)\n:::')
        .firstMatch(section);
    final verse = callout == null
        ? const _Verse('', '')
        : _verseFromCallout(callout.group(1)!);
    var body = section;
    if (callout != null) {
      body = body.replaceRange(callout.start, callout.end, '');
    }

    final lines = body.split('\n');
    final kept = <String>[];
    final quoteLines = <String>[];
    String? sticky;
    String? todayStep;
    String? lastBold;
    final quoteBuffer = <String>[];

    void flushQuote() {
      if (quoteBuffer.isEmpty) return;
      quoteLines.add(quoteBuffer.join(' ').trim());
      quoteBuffer.clear();
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      final trimmed = line.trim();
      if (trimmed.startsWith('>')) {
        quoteBuffer.add(trimmed.replaceFirst(RegExp(r'^>\s?'), ''));
        continue;
      }
      flushQuote();
      if (trimmed.isEmpty) {
        kept.add('');
        continue;
      }
      if (_isSourceOrEdition(trimmed) || trimmed == '---') continue;
      if (RegExp(r'^Share card\s*:', caseSensitive: false).hasMatch(trimmed)) {
        continue;
      }
      if (trimmed.startsWith('🙏') || _plain(trimmed).startsWith('🙏')) {
        continue;
      }

      final stickyMatch = RegExp(
        r'^\*\*Sticky lesson:\*\*\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(trimmed);
      final stickyWrapped = RegExp(
        r'^\*\*Sticky lesson:\s*(.+?)\*\*$',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (stickyMatch != null || stickyWrapped != null) {
        sticky = (stickyMatch?.group(1) ?? stickyWrapped!.group(1))!.trim();
        continue;
      }

      if (todayStep == null && RegExp(r'^Today\b').hasMatch(trimmed)) {
        todayStep = _plain(trimmed);
        continue;
      }

      if (RegExp(r'^\*\*[^*].+\*\*$').hasMatch(trimmed)) {
        lastBold = _plain(trimmed);
      }
      kept.add(trimmed);
    }
    flushQuote();

    var takeaway = sticky ?? todayStep ?? '';
    if (lead != null && lead.banner.isNotEmpty) {
      takeaway = lead.banner;
    } else if (takeaway.isEmpty && lastBold != null) {
      takeaway = lastBold;
      final boldLine = '**$lastBold**';
      final index = kept.lastIndexWhere(
        (line) => line == boldLine || _plain(line) == lastBold,
      );
      if (index >= 0) kept.removeAt(index);
    } else if (lastBold != null && sticky == null && todayStep != null) {
      // The closing bold line stays in the reflection when a "Today" step exists.
    }

    final scriptures = quoteLines
        .map(_scriptureFromQuote)
        .whereType<ScriptureQuote>()
        .toList();
    if (verse.reference.isNotEmpty &&
        verse.text.isNotEmpty &&
        scriptures.every((quote) => quote.reference != verse.reference)) {
      scriptures.add(
        ScriptureQuote(reference: verse.reference, text: verse.text),
      );
    }

    final teaser = lead == null ? '' : _distinctTeaser(lead.teaser, takeaway);
    return _Section(
      body: encodeContent(markdownToBlocks(_collapse(kept.join('\n')))),
      takeaway: takeaway,
      verseText: verse.text,
      verseRef: verse.reference,
      scriptures: scriptures,
      sections: sections,
      teaser: teaser,
      prayer: prayer,
    );
  }

  static String _prayerFrom(String section) {
    for (final raw in section.split('\n')) {
      final trimmed = raw.trim();
      final plain = _plain(trimmed);
      if (!trimmed.startsWith('🙏') && !plain.startsWith('🙏')) continue;
      return plain
          .replaceFirst(RegExp(r'^🙏\s*'), '')
          .replaceFirst(RegExp(r'^Today:\s*', caseSensitive: false), '')
          .trim();
    }
    return '';
  }

  static _Lead? _leadFrom(String prose) {
    for (final raw in prose.split('\n')) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final bold = RegExp(r'\*\*(.+?)\*\*').firstMatch(trimmed);
      final italic = RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)')
          .firstMatch(trimmed);
      if (bold == null && italic == null) return null;
      return _Lead(
        raw: trimmed,
        banner: bold?.group(1)?.trim() ?? '',
        teaser: italic?.group(1)?.trim() ?? '',
      );
    }
    return null;
  }

  static String _distinctTeaser(String teaser, String banner) {
    final value = teaser.trim();
    if (value.isEmpty || value == banner.trim()) return '';
    return value;
  }

  static _Verse _verseFromCallout(String callout) {
    final lines = callout
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    var reference = '';
    final textLines = <String>[];
    for (final line in lines) {
      final plain = _plain(line);
      final heading = _stripLeadingSymbols(plain);
      if (heading.toUpperCase().startsWith('VERSE')) {
        final ref = _verseRef.firstMatch(heading);
        if (ref != null) reference = _cleanRef(ref.group(1)!);
        continue;
      }
      final ref = _trailingRef(plain);
      if (ref != null) {
        reference = reference.isEmpty ? ref.reference : reference;
        if (ref.text.isNotEmpty) textLines.add(ref.text);
      } else {
        textLines.add(_unwrapQuotes(plain));
      }
    }
    return _Verse(textLines.join(' ').trim(), reference);
  }

  static ScriptureQuote? _scriptureFromQuote(String quote) {
    final plain = _unwrapQuotes(_plain(quote));
    final trailing = _trailingRef(plain);
    if (trailing == null) return null;
    return ScriptureQuote(reference: trailing.reference, text: trailing.text);
  }

  static _SplitRef? _trailingRef(String line) {
    final match = RegExp(
      r'^(.*?)(?:\s+[—–-]\s*|\s+)((?:[1-3]\s)?(?:[A-Z][A-Za-z]+\.?\s+){1,3}\d+:\d+(?:-\d+)?)(?:\s+(?:ESV|NIV|KJV|NLT|NKJV|CSB|NASB))?\s*$',
    ).firstMatch(line.trim());
    if (match == null) return null;
    final text = _unwrapQuotes(match.group(1)!.trim());
    if (text.isEmpty) return null;
    return _SplitRef(text, _cleanRef(match.group(2)!));
  }

  static bool _isSourceOrEdition(String line) {
    final lower = line.toLowerCase();
    if (lower.startsWith('**source:') || lower.startsWith('source:')) {
      return true;
    }
    if (lower.startsWith('edition:') || lower.startsWith('**edition:')) {
      return true;
    }
    return false;
  }

  static String? _sourceUrl(String markdown) {
    for (final line in markdown.split('\n')) {
      if (!line.toLowerCase().contains('source')) continue;
      final match = _anyLink.firstMatch(line);
      if (match != null) return match.group(2);
    }
    return null;
  }

  static String? _firstSubstack(String markdown) {
    final match = _substackLink.firstMatch(markdown);
    if (match == null) return null;
    return _withoutFragment(match.group(2)!);
  }

  static String _withoutFragment(String url) {
    final hash = url.indexOf('#');
    if (hash < 0) return url;
    return url.substring(0, hash);
  }

  static String _cleanRef(String reference) {
    return reference
        .replaceAll(_versionSuffix, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _plain(String line) {
    return line
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (match) => match.group(1)!)
        .replaceAllMapped(
          RegExp(r'(?<!\*)\*(.+?)\*(?!\*)'),
          (match) => match.group(1)!,
        )
        .trim();
  }

  static String _unwrapQuotes(String value) {
    var text = value.trim();
    const wrappers = ['"', "'", '“', '”', '‘', '’'];
    while (text.isNotEmpty && wrappers.contains(text[0])) {
      text = text.substring(1).trimLeft();
    }
    while (text.isNotEmpty && wrappers.contains(text[text.length - 1])) {
      text = text.substring(0, text.length - 1).trimRight();
    }
    return text.trim();
  }

  static String _stripLeadingSymbols(String input) {
    return input
        .replaceFirst(RegExp(r"^[^\p{L}\p{N}]+", unicode: true), '')
        .trim();
  }

  static String _collapse(String value) {
    return value.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  static List<ScriptureQuote> _uniqueScriptures(List<ScriptureQuote> quotes) {
    final seen = <String>{};
    final unique = <ScriptureQuote>[];
    for (final quote in quotes) {
      final key = '${quote.reference}|${quote.text}';
      if (seen.add(key)) unique.add(quote);
    }
    return unique;
  }
}

class _Section {
  const _Section({
    required this.body,
    required this.takeaway,
    required this.verseText,
    required this.verseRef,
    required this.scriptures,
    this.sections = const [],
    this.teaser = '',
    this.prayer = '',
  });

  final String body;
  final String takeaway;
  final String verseText;
  final String verseRef;
  final List<ScriptureQuote> scriptures;
  final List<ParsedAppSection> sections;
  final String teaser;
  final String prayer;
}

class _Lead {
  const _Lead({required this.raw, required this.banner, required this.teaser});

  final String raw;
  final String banner;
  final String teaser;
}

class _Verse {
  const _Verse(this.text, this.reference);

  final String text;
  final String reference;
}

class _SplitRef {
  const _SplitRef(this.text, this.reference);

  final String text;
  final String reference;
}
