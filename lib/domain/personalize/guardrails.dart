import '../bible/verse_reference.dart';
import '../models/scripture_quote.dart';

const scriptureAnchorReason = 'Scripture refs are missing or unrelated';

/// Placeholder copy. Wording and triggers are pending final approval.
const defaultHelpNoteText =
    "If you're struggling, please reach out to a pastor, a trusted friend, or a doctor. In the US, call or text 988 any time.";

/// Topics that show [defaultHelpNoteText]. Pending final approval.
const defaultHelpNoteTriggers = <String>[
  'health',
  'illness',
  'grief',
  'depression',
  'anxiety',
  'abuse',
  'self-harm',
];

class HelpNoteConfig {
  const HelpNoteConfig({
    this.helpNote = defaultHelpNoteText,
    this.triggers = defaultHelpNoteTriggers,
  });

  final String helpNote;
  final List<String> triggers;
}

/// Verse mode must cite only the reader's chosen verses.
/// Topic mode must cite two quotes, and the callout must be one of those quotes.
/// This is the only safety rule.
String? scriptureAnchorFailure({
  required bool verseMode,
  required List<String> chosenRefs,
  required String verseText,
  required String verseRef,
  required List<ScriptureQuote> scriptures,
}) {
  final callout = _parseRef(verseRef);
  final quotes = [for (final quote in scriptures) _parseRef(quote.reference)];
  final quoteRefs = [for (final quote in quotes) ?quote];
  final structureOk =
      verseText.trim().isNotEmpty &&
      callout != null &&
      scriptures.length == 2 &&
      quotes.every((quote) => quote != null) &&
      scriptures.every((quote) => quote.text.trim().isNotEmpty);
  if (!structureOk) return scriptureAnchorReason;

  if (verseMode) {
    final chosen = [for (final ref in chosenRefs) ?_parseRef(ref)];
    if (chosen.isEmpty || chosen.length != chosenRefs.length) {
      return scriptureAnchorReason;
    }
    final cited = [callout, ...quoteRefs];
    final grounded = cited.every(
      (ref) => chosen.any((anchor) => _overlaps(ref, anchor)),
    );
    if (!grounded) return scriptureAnchorReason;
    return null;
  }

  final calloutMatchesQuote = quoteRefs.any(
    (quote) => _overlaps(callout, quote),
  );
  if (!calloutMatchesQuote) return scriptureAnchorReason;
  return null;
}

String? helpNoteFor({
  required String topic,
  required List<String> lifeSituations,
  HelpNoteConfig config = const HelpNoteConfig(),
}) {
  if (config.helpNote.trim().isEmpty || config.triggers.isEmpty) return null;
  final haystack = _fold('$topic ${lifeSituations.join(' ')}');
  for (final trigger in config.triggers) {
    final needle = _fold(trigger);
    if (needle.isEmpty) continue;
    if (RegExp('\\b${RegExp.escape(needle)}\\b').hasMatch(haystack)) {
      return config.helpNote;
    }
  }
  return null;
}

_ParsedRef? _parseRef(String raw) {
  final normalized = VerseReference.normalize(raw);
  final match = RegExp(r'^(.*)\s+(\d+):(\d+)(?:-(\d+))?$')
      .firstMatch(normalized);
  if (match == null) return null;
  final start = int.tryParse(match.group(3)!);
  final end = int.tryParse(match.group(4) ?? match.group(3)!);
  final chapter = int.tryParse(match.group(2)!);
  if (start == null || end == null || chapter == null || end < start) {
    return null;
  }
  final book = match.group(1)!.trim();
  if (book.isEmpty) return null;
  return _ParsedRef(book, chapter, start, end);
}

bool _overlaps(_ParsedRef a, _ParsedRef b) {
  return a.book == b.book &&
      a.chapter == b.chapter &&
      a.start <= b.end &&
      b.start <= a.end;
}

String _fold(String value) => value.toLowerCase().replaceAll('-', ' ');

class _ParsedRef {
  const _ParsedRef(this.book, this.chapter, this.start, this.end);

  final String book;
  final int chapter;
  final int start;
  final int end;
}
