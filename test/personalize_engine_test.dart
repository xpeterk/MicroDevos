import 'package:flutter_test/flutter_test.dart';
import 'package:micro_devos/domain/models/scripture_quote.dart';
import 'package:micro_devos/domain/personalize/guardrails.dart';
import 'package:micro_devos/domain/personalize/personalize_engine.dart';
import 'package:micro_devos/domain/personalize/style_catalog.dart';

void main() {
  final clock = DateTime.utc(2026, 10, 18);

  GenerateRequest request({
    String styleKey = 'purpose',
    bool regenerate = false,
  }) {
    return GenerateRequest(
      verseMode: false,
      topic: 'Trusting God at a new job',
      verseRefs: const [],
      styleKey: styleKey,
      ageRange: '30–44',
      lifeSituations: const ['Work'],
      regenerate: regenerate,
    );
  }

  PersonalizeEngine engine({
    int weekly = 5,
    double monthly = 25,
    GenerationProvider? provider,
  }) {
    return PersonalizeEngine(
      config: GenerationCapConfig(
        weeklyGenerationCap: weekly,
        monthlySpendCeilingUsd: monthly,
      ),
      clock: () => clock,
      provider: provider,
    );
  }

  test('weekly cap blocks the next generation', () async {
    final local = engine();
    local.seedWeekUsage(5);
    final result = await local.generate(request());
    expect(result, isA<GenerateBlocked>());
    expect((result as GenerateBlocked).cap.reason, 'Weekly cap reached');
    expect(result.cap.left, 0);
  });

  test('monthly spend ceiling blocks generation', () async {
    final local = engine();
    local.seedMonthSpend(25);
    final result = await local.generate(request());
    expect(result, isA<GenerateBlocked>());
    expect(
      (result as GenerateBlocked).cap.reason,
      'Monthly spend ceiling reached',
    );
  });

  test(
    'cache hit reuses the devo and does not spend another generation',
    () async {
      final local = engine();
      final first = await local.generate(request());
      expect(first, isA<GenerateOk>());
      final created = (first as GenerateOk).devo;
      expect(first.cacheHit, isFalse);
      expect(local.capSnapshot().usedThisWeek, 1);

      final second = await local.generate(request());
      expect(second, isA<GenerateOk>());
      final reused = (second as GenerateOk).devo;
      expect(second.cacheHit, isTrue);
      expect(reused.id, created.id);
      expect(reused.reuseCount, 1);
      expect(local.capSnapshot().usedThisWeek, 1);
    },
  );

  test('regenerate misses the cache and counts against the cap', () async {
    final local = engine();
    await local.generate(request());
    final again = await local.generate(request(regenerate: true));
    expect(again, isA<GenerateOk>());
    expect((again as GenerateOk).cacheHit, isFalse);
    expect(local.capSnapshot().usedThisWeek, 2);
  });

  test('verse mode stays inside the chosen references', () async {
    final local = engine();
    final result = await local.generate(
      const GenerateRequest(
        verseMode: true,
        topic: '',
        verseRefs: ['Phil 4:6-7', 'Ps 23:1'],
        styleKey: 'purpose',
      ),
    );
    expect(result, isA<GenerateOk>());
    final devo = (result as GenerateOk).devo;
    expect(devo.verseRef, 'Phil 4:6-7');
    expect(devo.scriptures.map((quote) => quote.reference), [
      'Phil 4:6-7',
      'Ps 23:1',
    ]);
    expect(devo.helpNote, isNull);
  });

  test('a missing or unrelated scripture reference is rejected', () async {
    final local = engine(provider: _FixedProvider(_unrelated));
    final result = await local.generate(request());
    expect(result, isA<GenerateRejected>());
    expect((result as GenerateRejected).reason, scriptureAnchorReason);
    expect(local.capSnapshot().usedThisWeek, 0);

    final missing = await engine(provider: _FixedProvider(_missingQuotes))
        .generate(request());
    expect(missing, isA<GenerateRejected>());

    final verse = await engine(provider: _FixedProvider(_topicDraft)).generate(
      const GenerateRequest(
        verseMode: true,
        topic: '',
        verseRefs: ['John 3:16'],
        styleKey: 'purpose',
      ),
    );
    expect(verse, isA<GenerateRejected>());
  });

  test('the help note follows the configured triggers', () async {
    final local = engine();
    final anxiety = await local.generate(
      const GenerateRequest(
        verseMode: false,
        topic: 'Anxiety before Monday',
        verseRefs: [],
        styleKey: 'purpose',
      ),
    );
    expect((anxiety as GenerateOk).devo.helpNote, defaultHelpNoteText);

    final grief = await local.generate(
      const GenerateRequest(
        verseMode: false,
        topic: 'A long week',
        verseRefs: [],
        styleKey: 'purpose',
        lifeSituations: ['Grief'],
      ),
    );
    expect((grief as GenerateOk).devo.helpNote, defaultHelpNoteText);

    final job = await local.generate(request());
    expect((job as GenerateOk).devo.helpNote, isNull);
    expect(defaultHelpNoteTriggers, [
      'health',
      'illness',
      'grief',
      'depression',
      'anxiety',
      'abuse',
      'self-harm',
    ]);
  });

  test('style labels name no person', () {
    const approved = [
      'Purpose & practical living',
      'Good news & invitation',
      'Healing & faith',
      'Grace & the Spirit',
      'Bible on the go',
    ];
    final styles = [
      for (final style in styleCatalog)
        if (style.kind == 'style') style.label,
    ];
    expect(styles, approved);

    final person = RegExp(r'\b[A-Z][a-z]+ [A-Z][a-z]+\b');
    const banned = ['Spurgeon', 'Murray', 'Meyer', 'Henry'];
    for (final label in styles) {
      expect(person.hasMatch(label), isFalse, reason: label);
      for (final name in banned) {
        expect(label.contains(name), isFalse, reason: label);
      }
    }

    final classics = {
      for (final style in styleCatalog)
        if (style.isClassic) style.label,
    };
    expect(classics, {
      'C. H. Spurgeon',
      'Andrew Murray',
      'F. B. Meyer',
      'Matthew Henry',
    });
  });
}

class _FixedProvider implements GenerationProvider {
  const _FixedProvider(this.draft);

  final GenerationDraft draft;

  @override
  String get name => 'fixed';

  @override
  GenerationDraft generate(GenerateRequest request) => draft;
}

const _topicDraft = GenerationDraft(
  title: 'Steady Ground on a First Morning',
  hook: 'Lorem ipsum placeholder hook for a new beginning.',
  sections: ['Placeholder section.', 'Second placeholder section.'],
  takeaway:
      'Placeholder takeaway: dolor sit amet, one short line of encouragement.',
  verseText: 'Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God.',
  verseRef: 'Phil 4:6',
  scriptures: [
    ScriptureQuote(
      reference: 'Philippians 4:6',
      text: 'Be careful for nothing.',
    ),
    ScriptureQuote(reference: 'Psalm 23:1', text: 'The LORD is my shepherd.'),
  ],
);

const _unrelated = GenerationDraft(
  title: 'Steady Ground on a First Morning',
  hook: 'Lorem ipsum placeholder hook for a new beginning.',
  sections: ['Placeholder section.', 'Second placeholder section.'],
  takeaway:
      'Placeholder takeaway: dolor sit amet, one short line of encouragement.',
  verseText: 'For God so loved the world.',
  verseRef: 'John 3:16',
  scriptures: [
    ScriptureQuote(
      reference: 'Philippians 4:6',
      text: 'Be careful for nothing.',
    ),
    ScriptureQuote(reference: 'Psalm 23:1', text: 'The LORD is my shepherd.'),
  ],
);

const _missingQuotes = GenerationDraft(
  title: 'Steady Ground on a First Morning',
  hook: 'Lorem ipsum placeholder hook for a new beginning.',
  sections: ['Placeholder section.', 'Second placeholder section.'],
  takeaway:
      'Placeholder takeaway: dolor sit amet, one short line of encouragement.',
  verseText: 'Be careful for nothing.',
  verseRef: 'Phil 4:6',
  scriptures: [
    ScriptureQuote(
      reference: 'Philippians 4:6',
      text: 'Be careful for nothing.',
    ),
  ],
);
