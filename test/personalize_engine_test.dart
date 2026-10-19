import 'package:flutter_test/flutter_test.dart';
import 'package:micro_devos/domain/personalize/personalize_engine.dart';
import 'package:micro_devos/domain/personalize/style_catalog.dart';

void main() {
  final clock = DateTime.utc(2026, 10, 18);

  GenerateRequest request({String styleKey = 'purpose', bool regenerate = false}) {
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

  PersonalizeEngine engine({int weekly = 5, double monthly = 25}) {
    return PersonalizeEngine(
      config: GenerationCapConfig(
        weeklyGenerationCap: weekly,
        monthlySpendCeilingUsd: monthly,
      ),
      clock: () => clock,
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
    expect((result as GenerateBlocked).cap.reason, 'Monthly spend ceiling reached');
  });

  test('cache hit reuses the devo and does not spend another generation', () async {
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
  });

  test('regenerate misses the cache and counts against the cap', () async {
    final local = engine();
    await local.generate(request());
    final again = await local.generate(request(regenerate: true));
    expect(again, isA<GenerateOk>());
    expect((again as GenerateOk).cacheHit, isFalse);
    expect(local.capSnapshot().usedThisWeek, 2);
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
