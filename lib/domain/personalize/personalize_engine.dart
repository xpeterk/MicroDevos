import '../models/generated_devo.dart';
import '../models/scripture_quote.dart';
import 'guardrails.dart';
import 'style_catalog.dart';

/// Placeholder defaults. The weekly cap and the monthly spend ceiling
/// are not decided.
class GenerationCapConfig {
  const GenerationCapConfig({
    this.weeklyGenerationCap = 5,
    this.monthlySpendCeilingUsd = 25,
  });

  final int weeklyGenerationCap;
  final double monthlySpendCeilingUsd;
}

class GenerateRequest {
  const GenerateRequest({
    required this.verseMode,
    required this.topic,
    required this.verseRefs,
    required this.styleKey,
    this.ageRange,
    this.lifeSituations = const [],
    this.bibleVersion,
    this.regenerate = false,
  });

  final bool verseMode;
  final String topic;
  final List<String> verseRefs;
  final String styleKey;
  final String? ageRange;
  final List<String> lifeSituations;
  final String? bibleVersion;
  final bool regenerate;

  GenerateRequest copyWith({bool? regenerate}) {
    return GenerateRequest(
      verseMode: verseMode,
      topic: topic,
      verseRefs: verseRefs,
      styleKey: styleKey,
      ageRange: ageRange,
      lifeSituations: lifeSituations,
      bibleVersion: bibleVersion,
      regenerate: regenerate ?? this.regenerate,
    );
  }

  String get promptLabel {
    if (verseMode) return verseRefs.join(', ');
    return topic.trim();
  }
}

class CapSnapshot {
  const CapSnapshot({
    required this.usedThisWeek,
    required this.weeklyCap,
    required this.monthSpendUsd,
    required this.monthlyCeilingUsd,
    required this.allowed,
    this.reason,
  });

  final int usedThisWeek;
  final int weeklyCap;
  final double monthSpendUsd;
  final double monthlyCeilingUsd;
  final bool allowed;
  final String? reason;

  int get left => (weeklyCap - usedThisWeek).clamp(0, weeklyCap);
}

class GenerateOk {
  const GenerateOk({
    required this.devo,
    required this.cacheHit,
    required this.cap,
  });

  final GeneratedDevo devo;
  final bool cacheHit;
  final CapSnapshot cap;
}

class GenerateBlocked {
  const GenerateBlocked({required this.cap});

  final CapSnapshot cap;
}

class GenerateRejected {
  const GenerateRejected({required this.reason});

  final String reason;
}

/// Local stand-in for generate-devo. No network and no model call.
class PersonalizeEngine {
  PersonalizeEngine({
    required this.config,
    required this.clock,
    this.helpNotes = const HelpNoteConfig(),
    GenerationProvider? provider,
    SafetyChecker? safety,
  }) : _provider = provider ?? const FakeGenerationProvider(),
       _safety = safety ?? const ScriptureAnchorChecker();

  final GenerationCapConfig config;
  final DateTime Function() clock;
  final HelpNoteConfig helpNotes;
  final GenerationProvider _provider;
  final SafetyChecker _safety;

  final Map<String, int> _generationsByDay = {};
  final Map<String, double> _spendByMonth = {};
  final Map<String, GeneratedDevo> _cache = {};

  DateTime get now => clock();

  void seedWeekUsage(int count) {
    _generationsByDay[_dayKey(now)] = count;
  }

  void seedMonthSpend(double usd) {
    _spendByMonth[_monthKey(now)] = usd;
  }

  CapSnapshot capSnapshot() {
    final used = _usedThisWeek(now);
    final spend = _spendByMonth[_monthKey(now)] ?? 0;
    String? reason;
    if (used >= config.weeklyGenerationCap) {
      reason = 'Weekly cap reached';
    } else if (spend >= config.monthlySpendCeilingUsd) {
      reason = 'Monthly spend ceiling reached';
    }
    return CapSnapshot(
      usedThisWeek: used,
      weeklyCap: config.weeklyGenerationCap,
      monthSpendUsd: spend,
      monthlyCeilingUsd: config.monthlySpendCeilingUsd,
      allowed: reason == null,
      reason: reason,
    );
  }

  Future<Object> generate(GenerateRequest request) async {
    final cap = capSnapshot();
    if (!cap.allowed) return GenerateBlocked(cap: cap);

    final key = cacheKey(request);
    if (!request.regenerate) {
      final cached = _cache[key];
      if (cached != null) {
        final reused = cached.copyWith(reuseCount: cached.reuseCount + 1);
        _cache[key] = reused;
        return GenerateOk(devo: reused, cacheHit: true, cap: cap);
      }
    }

    final draft = _provider.generate(request);
    final GenerationDraft reviewed;
    try {
      reviewed = await _safety.review(draft, request);
    } on ScriptureAnchorException catch (error) {
      return GenerateRejected(reason: error.reason);
    }
    final style = styleByKey(request.styleKey);
    final devo = GeneratedDevo(
      id: 'gen-$key',
      title: reviewed.title,
      hook: reviewed.hook,
      sections: reviewed.sections,
      takeaway: reviewed.takeaway,
      verseText: reviewed.verseText,
      verseRef: reviewed.verseRef,
      scriptures: reviewed.scriptures,
      styleKey: request.styleKey,
      styleLabel: style?.label ?? request.styleKey,
      styleKind: style?.kind ?? 'style',
      promptLabel: request.promptLabel,
      helpNote: helpNoteFor(
        topic: request.topic,
        lifeSituations: request.lifeSituations,
        config: helpNotes,
      ),
      reuseCount: 0,
    );
    _cache[key] = devo;
    final day = _dayKey(now);
    _generationsByDay[day] = (_generationsByDay[day] ?? 0) + 1;
    final month = _monthKey(now);
    _spendByMonth[month] = (_spendByMonth[month] ?? 0) + reviewed.costUsd;
    return GenerateOk(devo: devo, cacheHit: false, cap: capSnapshot());
  }

  int _usedThisWeek(DateTime clock) {
    final start = _weekStart(clock);
    final end = DateTime.utc(clock.year, clock.month, clock.day);
    var used = 0;
    for (final entry in _generationsByDay.entries) {
      final day = DateTime.parse(entry.key);
      if (!day.isBefore(start) && !day.isAfter(end)) used += entry.value;
    }
    return used;
  }
}

String cacheKey(GenerateRequest request) {
  return '${profileHash(request)}::${topicKey(request)}::${request.styleKey}::${request.bibleVersion ?? ''}';
}

String profileHash(GenerateRequest request) {
  final life = [...request.lifeSituations]..sort();
  return '${request.ageRange ?? ''}|${life.join(',')}';
}

String topicKey(GenerateRequest request) {
  if (request.verseMode) {
    final refs = request.verseRefs.map((ref) => ref.trim().toLowerCase());
    return 'verse:${refs.join('|')}';
  }
  return 'topic:${request.topic.trim().toLowerCase()}';
}

DateTime _weekStart(DateTime clock) {
  final day = DateTime.utc(clock.year, clock.month, clock.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

String _dayKey(DateTime clock) {
  final day = DateTime.utc(clock.year, clock.month, clock.day);
  return day.toIso8601String().split('T').first;
}

String _monthKey(DateTime clock) {
  final month = clock.month.toString().padLeft(2, '0');
  return '${clock.year}-$month';
}

class GenerationDraft {
  const GenerationDraft({
    required this.title,
    required this.hook,
    required this.sections,
    required this.takeaway,
    required this.verseText,
    required this.verseRef,
    required this.scriptures,
    this.costUsd = 0,
    this.tokensIn = 0,
    this.tokensOut = 0,
    this.embedding,
  });

  final String title;
  final String hook;
  final List<String> sections;
  final String takeaway;
  final String verseText;
  final String verseRef;
  final List<ScriptureQuote> scriptures;
  final double costUsd;
  final int tokensIn;
  final int tokensOut;
  final List<double>? embedding;
}

abstract class GenerationProvider {
  String get name;
  GenerationDraft generate(GenerateRequest request);
}

/// Deterministic placeholder. Does not call a model.
class FakeGenerationProvider implements GenerationProvider {
  const FakeGenerationProvider();

  @override
  String get name => 'fake';

  @override
  GenerationDraft generate(GenerateRequest request) {
    if (request.verseMode && request.verseRefs.isNotEmpty) {
      final first = request.verseRefs.first;
      final second = request.verseRefs.length > 1
          ? request.verseRefs[1]
          : first;
      return GenerationDraft(
        title: 'Steady Ground on a First Morning',
        hook: 'Lorem ipsum placeholder hook for a new beginning.',
        sections: const [
          'Placeholder section. A real provider will write this reflection later.',
          'Second placeholder section. No model was called.',
        ],
        takeaway: 'Placeholder takeaway: dolor sit amet, one short line of encouragement.',
        verseText: _placeholderVerse(first),
        verseRef: first,
        scriptures: [
          ScriptureQuote(reference: first, text: _placeholderVerse(first)),
          ScriptureQuote(reference: second, text: _placeholderVerse(second)),
        ],
      );
    }
    return const GenerationDraft(
      title: 'Steady Ground on a First Morning',
      hook: 'Lorem ipsum placeholder hook for a new beginning.',
      sections: [
        'Placeholder section. A real provider will write this reflection later.',
        'Second placeholder section. No model was called.',
      ],
      takeaway: 'Placeholder takeaway: dolor sit amet, one short line of encouragement.',
      verseText: 'Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God.',
      verseRef: 'Phil 4:6',
      scriptures: [
        ScriptureQuote(
          reference: 'Philippians 4:6',
          text: 'Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God.',
        ),
        ScriptureQuote(
          reference: 'Psalm 23:1',
          text: 'The LORD is my shepherd; I shall not want.',
        ),
      ],
    );
  }
}

String _placeholderVerse(String reference) {
  final key = reference.trim().toLowerCase();
  if (key.startsWith('phil')) {
    return 'Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God.';
  }
  if (key.startsWith('ps')) {
    return 'The LORD is my shepherd; I shall not want.';
  }
  return 'Placeholder verse text.';
}

abstract class SafetyChecker {
  Future<GenerationDraft> review(
    GenerationDraft draft,
    GenerateRequest request,
  );
}

/// Rejects a draft whose Scripture refs are missing or unrelated.
/// No other theology rule is applied.
class ScriptureAnchorChecker implements SafetyChecker {
  const ScriptureAnchorChecker();

  @override
  Future<GenerationDraft> review(
    GenerationDraft draft,
    GenerateRequest request,
  ) async {
    final reason = scriptureAnchorFailure(
      verseMode: request.verseMode,
      chosenRefs: request.verseRefs,
      verseText: draft.verseText,
      verseRef: draft.verseRef,
      scriptures: draft.scriptures,
    );
    if (reason != null) throw ScriptureAnchorException(reason);
    return draft;
  }
}

class ScriptureAnchorException implements Exception {
  const ScriptureAnchorException(this.reason);

  final String reason;

  @override
  String toString() => reason;
}
