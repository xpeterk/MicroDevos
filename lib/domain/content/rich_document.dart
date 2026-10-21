import 'dart:convert';

/// One styled slice of a sentence. Flags come from Notion annotations.
class RichRun {
  const RichRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.code = false,
    this.link,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final bool code;
  final String? link;

  Map<String, dynamic> toJson() => {
    'text': text,
    if (bold) 'bold': true,
    if (italic) 'italic': true,
    if (underline) 'underline': true,
    if (strike) 'strike': true,
    if (code) 'code': true,
    if (link != null) 'link': link,
  };

  factory RichRun.fromJson(Map<String, dynamic> json) {
    return RichRun(
      text: json['text'] as String? ?? '',
      bold: json['bold'] == true,
      italic: json['italic'] == true,
      underline: json['underline'] == true,
      strike: json['strike'] == true,
      code: json['code'] == true,
      link: json['link'] as String?,
    );
  }
}

enum ContentKind { paragraph, heading, bullet, number, quote, callout, divider }

/// A block the devotion body can paint without showing markdown markers.
class ContentBlock {
  const ContentBlock({
    required this.kind,
    this.runs = const [],
    this.level = 2,
    this.index,
  });

  final ContentKind kind;
  final List<RichRun> runs;
  final int level;
  final int? index;

  String get plainText => runs.map((run) => run.text).join();

  Map<String, dynamic> toJson() => {
    'type': kind.name,
    if (kind != ContentKind.divider)
      'runs': runs.map((run) => run.toJson()).toList(),
    if (kind == ContentKind.heading) 'level': level,
    if (index != null) 'index': index,
  };

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'paragraph';
    final kind = ContentKind.values.firstWhere(
      (value) => value.name == type,
      orElse: () => ContentKind.paragraph,
    );
    final runs = (json['runs'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => RichRun.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return ContentBlock(
      kind: kind,
      runs: runs,
      level: json['level'] as int? ?? 2,
      index: json['index'] as int?,
    );
  }
}

String encodeContent(List<ContentBlock> blocks) {
  return jsonEncode({
    'v': 1,
    'blocks': blocks.map((block) => block.toJson()).toList(),
  });
}

/// Structured JSON from the importer, or legacy markdown from older rows.
List<ContentBlock> parseContent(String source) {
  final trimmed = source.trim();
  if (trimmed.startsWith('{')) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map && decoded['blocks'] is List) {
        return [
          for (final item in decoded['blocks'] as List)
            if (item is Map)
              ContentBlock.fromJson(Map<String, dynamic>.from(item)),
        ];
      }
    } on FormatException {
      // Fall through to the markdown reader.
    }
  }
  return markdownToBlocks(source);
}

List<ContentBlock> markdownToBlocks(String markdown) {
  final lines = markdown.replaceAll('\r\n', '\n').split('\n');
  final blocks = <ContentBlock>[];
  var index = 0;
  var number = 0;
  while (index < lines.length) {
    final line = lines[index];
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      index += 1;
      number = 0;
      continue;
    }
    if (trimmed == '---') {
      blocks.add(const ContentBlock(kind: ContentKind.divider));
      index += 1;
      continue;
    }
    if (trimmed == ':::callout') {
      final body = <String>[];
      index += 1;
      while (index < lines.length && lines[index].trim() != ':::') {
        body.add(lines[index]);
        index += 1;
      }
      if (index < lines.length) index += 1;
      blocks.add(
        ContentBlock(
          kind: ContentKind.callout,
          runs: parseInlines(body.join(' ').trim()),
        ),
      );
      continue;
    }
    final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(trimmed);
    if (heading != null) {
      blocks.add(
        ContentBlock(
          kind: ContentKind.heading,
          level: heading.group(1)!.length,
          runs: parseInlines(heading.group(2)!.trim()),
        ),
      );
      index += 1;
      number = 0;
      continue;
    }
    if (trimmed.startsWith('> ')) {
      final quote = <String>[trimmed.substring(2)];
      index += 1;
      while (index < lines.length && lines[index].trim().startsWith('> ')) {
        quote.add(lines[index].trim().substring(2));
        index += 1;
      }
      blocks.add(
        ContentBlock(
          kind: ContentKind.quote,
          runs: parseInlines(quote.join(' ')),
        ),
      );
      number = 0;
      continue;
    }
    final bullet = RegExp(r'^[-*]\s+(.*)$').firstMatch(trimmed);
    if (bullet != null) {
      blocks.add(
        ContentBlock(
          kind: ContentKind.bullet,
          runs: parseInlines(bullet.group(1)!.trim()),
        ),
      );
      index += 1;
      number = 0;
      continue;
    }
    final numbered = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
    if (numbered != null) {
      number += 1;
      blocks.add(
        ContentBlock(
          kind: ContentKind.number,
          index: number,
          runs: parseInlines(numbered.group(2)!.trim()),
        ),
      );
      index += 1;
      continue;
    }
    final paragraph = <String>[trimmed];
    index += 1;
    while (index < lines.length && !_isBlockStart(lines[index])) {
      final next = lines[index].trim();
      if (next.isEmpty) break;
      paragraph.add(next);
      index += 1;
    }
    blocks.add(
      ContentBlock(
        kind: ContentKind.paragraph,
        runs: parseInlines(paragraph.join(' ')),
      ),
    );
    number = 0;
  }
  return blocks;
}

bool _isBlockStart(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return true;
  if (trimmed == '---' || trimmed == ':::callout' || trimmed == ':::') {
    return true;
  }
  if (trimmed.startsWith('> ')) return true;
  if (RegExp(r'^#{1,3}\s+').hasMatch(trimmed)) return true;
  if (RegExp(r'^[-*]\s+').hasMatch(trimmed)) return true;
  if (RegExp(r'^\d+\.\s+').hasMatch(trimmed)) return true;
  return false;
}

/// Reads inline markers. Unclosed markers stay as text so nothing is dropped.
List<RichRun> parseInlines(String input) {
  final runs = <RichRun>[];
  void add(
    String text, {
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool strike = false,
    bool code = false,
    String? link,
  }) {
    if (text.isEmpty) return;
    runs.add(
      RichRun(
        text: text,
        bold: bold,
        italic: italic,
        underline: underline,
        strike: strike,
        code: code,
        link: link,
      ),
    );
  }

  var index = 0;
  final buffer = StringBuffer();
  void flush() {
    add(buffer.toString());
    buffer.clear();
  }

  while (index < input.length) {
    final rest = input.substring(index);
    if (rest.startsWith('**')) {
      final end = input.indexOf('**', index + 2);
      if (end > index) {
        flush();
        for (final run in parseInlines(input.substring(index + 2, end))) {
          runs.add(
            RichRun(
              text: run.text,
              bold: true,
              italic: run.italic,
              underline: run.underline,
              strike: run.strike,
              code: run.code,
              link: run.link,
            ),
          );
        }
        index = end + 2;
        continue;
      }
    }
    if (rest.startsWith('++')) {
      final end = input.indexOf('++', index + 2);
      if (end > index) {
        flush();
        for (final run in parseInlines(input.substring(index + 2, end))) {
          runs.add(
            RichRun(
              text: run.text,
              bold: run.bold,
              italic: run.italic,
              underline: true,
              strike: run.strike,
              code: run.code,
              link: run.link,
            ),
          );
        }
        index = end + 2;
        continue;
      }
    }
    if (rest.startsWith('~~')) {
      final end = input.indexOf('~~', index + 2);
      if (end > index) {
        flush();
        for (final run in parseInlines(input.substring(index + 2, end))) {
          runs.add(
            RichRun(
              text: run.text,
              bold: run.bold,
              italic: run.italic,
              underline: run.underline,
              strike: true,
              code: run.code,
              link: run.link,
            ),
          );
        }
        index = end + 2;
        continue;
      }
    }
    if (rest.startsWith('`')) {
      final end = input.indexOf('`', index + 1);
      if (end > index) {
        flush();
        add(input.substring(index + 1, end), code: true);
        index = end + 1;
        continue;
      }
    }
    if (rest.startsWith('[')) {
      final close = input.indexOf('](', index + 1);
      if (close > index) {
        final urlEnd = input.indexOf(')', close + 2);
        if (urlEnd > close) {
          flush();
          final label = input.substring(index + 1, close);
          final url = input.substring(close + 2, urlEnd);
          for (final run in parseInlines(label)) {
            runs.add(
              RichRun(
                text: run.text,
                bold: run.bold,
                italic: run.italic,
                underline: true,
                strike: run.strike,
                code: run.code,
                link: url,
              ),
            );
          }
          index = urlEnd + 1;
          continue;
        }
      }
    }
    if (rest.startsWith('*')) {
      final end = input.indexOf('*', index + 1);
      if (end > index && !input.startsWith('**', index)) {
        flush();
        for (final run in parseInlines(input.substring(index + 1, end))) {
          runs.add(
            RichRun(
              text: run.text,
              bold: run.bold,
              italic: true,
              underline: run.underline,
              strike: run.strike,
              code: run.code,
              link: run.link,
            ),
          );
        }
        index = end + 1;
        continue;
      }
    }
    buffer.write(input[index]);
    index += 1;
  }
  flush();
  return runs;
}
