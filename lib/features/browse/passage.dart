import 'package:flutter/material.dart';

import '../../domain/models/devo.dart';
import '../../domain/models/devo_note.dart';

class PassageSpot {
  const PassageSpot({required this.section, required this.start});

  final String section;
  final int start;
}

/// Finds [text] in the devotion. Body wins over a repeated word in the hook.
PassageSpot? locatePassage(Devo devo, String text) {
  final needle = text.trim();
  if (!isUsableAnchor(needle)) return null;
  final sources = <String, String>{
    'body': devo.bodyMd,
    'scripture': devo.scriptures.map((quote) => quote.text).join('\n'),
    'verse': devo.verseText,
    'takeaway': devo.takeaway,
    'hook': devo.hook,
  };
  for (final entry in sources.entries) {
    final start = entry.value.indexOf(needle);
    if (start >= 0) return PassageSpot(section: entry.key, start: start);
  }
  return null;
}

const highlightColor = Color(0xFFF6E38A);

List<InlineSpan> highlightSpans({
  required String source,
  required TextStyle? style,
  required List<String> anchors,
}) {
  String? anchor;
  for (final item in anchors) {
    if (isUsableAnchor(item) && source.contains(item)) {
      anchor = item;
      break;
    }
  }
  if (anchor == null) return [TextSpan(text: source, style: style)];
  final start = source.indexOf(anchor);
  final marked =
      style?.copyWith(backgroundColor: highlightColor) ??
      const TextStyle(backgroundColor: highlightColor);
  return [
    TextSpan(text: source.substring(0, start), style: style),
    TextSpan(
      text: source.substring(start, start + anchor.length),
      style: marked,
    ),
    TextSpan(text: source.substring(start + anchor.length), style: style),
  ];
}
