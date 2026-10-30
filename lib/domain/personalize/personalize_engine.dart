import 'dart:async';

import '../models/devo_section.dart';
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

    final draft = await _provider.generate(request);
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
      structuredSections: reviewed.structuredSections,
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
      oneMinuteText: reviewed.oneMinuteText,
      oneMinuteVerseRef: reviewed.oneMinuteVerseRef,
      oneMinuteVerseText: reviewed.oneMinuteVerseText,
      oneMinuteToday: reviewed.oneMinuteToday,
      prayer: reviewed.prayer,
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
      final day = DateTime.parse('${entry.key}T00:00:00Z');
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
    this.structuredSections = const [],
    this.oneMinuteText,
    this.oneMinuteVerseRef,
    this.oneMinuteVerseText,
    this.oneMinuteToday,
    this.prayer,
    this.costUsd = 0,
    this.tokensIn = 0,
    this.tokensOut = 0,
    this.embedding,
  });

  final String title;
  final String hook;
  final List<String> sections;
  final List<DevoSection> structuredSections;
  final String takeaway;
  final String verseText;
  final String verseRef;
  final List<ScriptureQuote> scriptures;
  final String? oneMinuteText;
  final String? oneMinuteVerseRef;
  final String? oneMinuteVerseText;
  final String? oneMinuteToday;
  final String? prayer;
  final double costUsd;
  final int tokensIn;
  final int tokensOut;
  final List<double>? embedding;
}

abstract class GenerationProvider {
  String get name;
  FutureOr<GenerationDraft> generate(GenerateRequest request);
}

/// Fallback provider that generates real devotionals with the full modern format.
class FakeGenerationProvider implements GenerationProvider {
  const FakeGenerationProvider();

  @override
  String get name => 'fake';

  @override
  GenerationDraft generate(GenerateRequest request) {
    final vRef = request.verseMode && request.verseRefs.isNotEmpty
        ? request.verseRefs.first
        : 'Philippians 4:6-7';
    final vText = _placeholderVerse(vRef);
    final secondRef = request.verseMode && request.verseRefs.length > 1
        ? request.verseRefs[1]
        : 'Psalm 23:1';
    final secondText = _placeholderVerse(secondRef);

    const oneMin =
        'When uncertainty rises, fear is quick to narrate the worst outcomes. Yet Scripture invites us into a steadfast peace that is not rooted in circumstances, but in the character of our heavenly Father. In every trial, God remains an unwavering refuge. When we bring our anxieties to Him in prayer, He guards our hearts with peace that surpasses human understanding. Entrust your steps to Him today, for His faithfulness endures through every storm.';

    const pText =
        '🙏 Heavenly Father, anchor my heart in Your unfailing love today and grant me Your surpassing peace in every uncertainty. Amen.';

    final secs = [
      DevoSection(
        id: 's1',
        devoId: 'fake',
        position: 1,
        title: 'Naming the Uncertainty',
        summary: 'Facing fear with an open heart before God.',
        minutes: 1,
        verseRef: vRef,
        verseText: vText,
        body:
            'We often hesitate to bring our worries into prayer until we think we have them sorted out. But God welcomes us as we are, inviting us to lay every concern before His throne of grace.',
        tags: const ['peace', 'trust'],
      ),
      DevoSection(
        id: 's2',
        devoId: 'fake',
        position: 2,
        title: 'The Peace That Guards',
        summary: 'God’s peace stands as a vigilant guardian over the restless soul.',
        minutes: 1,
        verseRef: 'Isaiah 26:3',
        verseText:
            'You will keep in perfect peace those whose minds are steadfast, because they trust in you.',
        body:
            'The peace of God does not merely soothe; it acts as a fortress around our thoughts. In Christ Jesus, we are held securely even when the ground around us shakes.',
        tags: const ['prayer', 'comfort'],
      ),
      DevoSection(
        id: 's3',
        devoId: 'fake',
        position: 3,
        title: 'Walking in Quiet Confidence',
        summary: 'Stepping forward one moment at a time in obedience and faith.',
        minutes: 1,
        verseRef: secondRef,
        verseText: secondText,
        body:
            'Faith does not require knowing what next year holds; it only asks that we trust the One who holds tomorrow. Lay your anxieties down and walk forward in His light.',
        tags: const ['faith', 'hope'],
      ),
    ];

    return GenerationDraft(
      title: 'Steady Ground on a First Morning',
      hook: 'When life feels unsteady, God’s peace remains our immovable anchor.',
      sections: [for (final s in secs) s.body],
      structuredSections: secs,
      takeaway: 'Before reacting to worry, pause and present your requests to God with thanksgiving.',
      verseText: vText,
      verseRef: vRef,
      oneMinuteText: oneMin,
      oneMinuteToday: 'Take one quiet minute to name your deepest worry and surrender it to God.',
      oneMinuteVerseRef: vRef,
      oneMinuteVerseText: vText,
      prayer: pText,
      scriptures: [
        ScriptureQuote(reference: vRef, text: vText),
        ScriptureQuote(reference: secondRef, text: secondText),
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
