import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:micro_devos/core/notifications/reminder_time.dart';
import 'package:micro_devos/data/sample/memory_repositories.dart';
import 'package:micro_devos/data/sample/sample_catalog.dart';
import 'package:micro_devos/data/sample/sample_devo_repository.dart';
import 'package:micro_devos/data/supabase/supabase_mappers.dart';
import 'package:micro_devos/domain/devo_order.dart';
import 'package:micro_devos/domain/edition_calendar.dart';
import 'package:micro_devos/domain/models/devo.dart';
import 'package:micro_devos/domain/models/user_preferences.dart';

void main() {
  late SampleDevoRepository repository;

  setUp(() {
    final catalog = SampleCatalog.parse(
      File('assets/sample/devos.json').readAsStringSync(),
      File('assets/sample/tags.json').readAsStringSync(),
    );
    repository = SampleDevoRepository(catalog);
  });

  test('each sample weekday has eight devotions in order', () async {
    final friday = await repository.devosForDate(DateTime(2026, 10, 16));
    final thursday = await repository.devosForDate(DateTime(2026, 10, 15));
    expect(friday, hasLength(8));
    expect(thursday, hasLength(8));
    expect(friday.map((devo) => devo.position), [1, 2, 3, 4, 5, 6, 7, 8]);
    final reversed = [...friday.reversed];
    expect(devosInReadingOrder(reversed).map((devo) => devo.position), [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
    ]);
    expect(
      friday.every((devo) => devo.hook.isNotEmpty && devo.takeaway.isNotEmpty),
      isTrue,
    );
    expect(friday.every((devo) => devo.verseText.isNotEmpty), isTrue);
    expect(await repository.devosForDate(DateTime(2026, 10, 18)), isEmpty);
  });

  test('search is case insensitive and can be limited to a date', () async {
    final shepherd = await repository.search(text: 'SHEPHERD');
    expect(shepherd.map((devo) => devo.id), ['fri-4']);
    final fridayRest = await repository.search(
      text: 'rest',
      date: DateTime(2026, 10, 16),
    );
    expect(fridayRest, isEmpty);
    final thursdayLaden = await repository.search(
      text: 'HEAVY laden',
      date: DateTime(2026, 10, 15),
    );
    expect(thursdayLaden.single.id, 'thu-1');
  });

  test('lookup, dates, and share text stay free of a byline', () async {
    final devo = await repository.devoById('fri-1');
    expect(devo, isNotNull);
    expect(devo!.title, 'A Refuge That Does Not Move');
    expect(devo.toShareText(), contains('At a Glance'));
    expect(devo.toShareText(), contains('Micro Devos'));
    expect(devo.toShareText().toLowerCase(), isNot(contains('by ')));
    final dates = await repository.editionDates();
    expect(dates, [DateTime(2026, 10, 16), DateTime(2026, 10, 15)]);
    expect(await repository.devoById('missing'), isNull);
  });

  test(
    'sunday opens the latest weekday edition unless the reader picks a date',
    () {
      final editions = [DateTime(2026, 10, 16), DateTime(2026, 10, 15)];
      final sunday = DateTime(2026, 10, 18, 9);
      final resolved = resolveEditionDate(
        today: sunday,
        editions: editions,
        selected: null,
      );
      expect(resolved, DateTime(2026, 10, 16));
      expect(
        editionIsFallback(
          today: sunday,
          edition: resolved!,
          readerChoseDate: false,
        ),
        isTrue,
      );
      final chosen = resolveEditionDate(
        today: sunday,
        editions: editions,
        selected: DateTime(2026, 10, 15, 22),
      );
      expect(chosen, DateTime(2026, 10, 15));
      expect(
        editionIsFallback(
          today: sunday,
          edition: chosen!,
          readerChoseDate: true,
        ),
        isFalse,
      );
    },
  );

  test('today opens 2026-10-19 when that edition exists, even if the list is oldest first', () {
    final editions = [
      DateTime(2026, 10, 15),
      DateTime(2026, 10, 16),
      DateTime(2026, 10, 19),
    ];
    final mondayNight = DateTime(2026, 10, 19, 21);
    final monday = resolveEditionDate(
      today: mondayNight,
      editions: editions,
      selected: null,
    );
    expect(monday, DateTime(2026, 10, 19));
    expect(
      editionIsFallback(
        today: mondayNight,
        edition: monday!,
        readerChoseDate: false,
      ),
      isFalse,
    );

    final tuesday = DateTime(2026, 10, 20, 9);
    final resolved = resolveEditionDate(
      today: tuesday,
      editions: editions,
      selected: null,
    );
    expect(resolved, DateTime(2026, 10, 19));
    expect(
      editionIsFallback(
        today: tuesday,
        edition: resolved!,
        readerChoseDate: false,
      ),
      isTrue,
    );
  });

  test('edition dates ignore a timezone suffix and archive or read rows stay visible', () {
    expect(parseDateOnly('2026-10-19'), DateTime(2026, 10, 19));
    expect(parseDateOnly('2026-10-19T00:00:00.000Z'), DateTime(2026, 10, 19));
    expect(parseDateOnly('2026-10-19 00:00:00.000Z'), DateTime(2026, 10, 19));
    expect(isReaderDevoStatus('archive'), isTrue);
    expect(isReaderDevoStatus('Read'), isTrue);
    expect(isReaderDevoStatus('unread'), isTrue);
    expect(isReaderDevoStatus('published'), isTrue);
    expect(isReaderDevoStatus('Ideas'), isFalse);
    expect(isReaderDevoStatus('AI-Ideas'), isFalse);
    expect(readerDevoStatuses, containsAll(['archive', 'read']));
  });

  test('a reminder moves to tomorrow once the chosen time has passed', () {
    final morning = DateTime(2026, 10, 16, 7);
    expect(nextReminder(morning, 7, 30), DateTime(2026, 10, 16, 7, 30));
    final evening = DateTime(2026, 10, 16, 8);
    expect(nextReminder(evening, 7, 30), DateTime(2026, 10, 17, 7, 30));
  });

  test('local favorites and preferences round trip in memory', () async {
    final favorites = MemoryFavoritesRepository();
    await favorites.setFavorite('fri-1', true);
    await favorites.setFavorite('fri-2', true);
    await favorites.setFavorite('fri-2', false);
    expect(await favorites.load(), {'fri-1'});

    final preferences = MemoryPreferencesRepository();
    final initial = await preferences.load();
    expect(initial.notifyTimeLabel, '07:30');
    expect(initial.notificationsEnabled, isFalse);
    await preferences.save(
      initial.copyWith(
        tagSlugs: {'hope', 'prayer'},
        notificationsEnabled: true,
        notifyHour: 6,
        notifyMinute: 15,
        lifeSituations: ['caregiver'],
      ),
    );
    final saved = await preferences.load();
    expect(saved.tagSlugs, {'hope', 'prayer'});
    expect(saved.notifyTimeLabel, '06:15');
    expect(saved.lifeSituations, ['caregiver']);
    final again = UserPreferences.fromJson(saved.toJson());
    expect(again.bibleVersions.reading.id, 'kjv');
    expect(again.notificationsEnabled, isTrue);
  });

  test('supabase rows map tags and favorite ids', () {
    final devo = devoFromRow({
      'id': 'abc',
      'title': 'Held',
      'hook': 'A hook',
      'body_md': 'A body',
      'takeaway': 'A step',
      'verse_text': 'Text',
      'verse_ref': 'Psalm 46:1',
      'scriptures': [
        {'reference': 'Psalm 46:1', 'text': 'God is our refuge.'},
      ],
      'edition_date': '2026-10-16',
      'position': 1,
      'status': 'published',
      'devo_tags': [
        {
          'tags': {'slug': 'courage', 'label': 'Courage'},
        },
      ],
    });
    expect(devo.tags, ['courage']);
    expect(devo.scriptures.single.reference, 'Psalm 46:1');
    expect(
      favoriteIdsFromRows([
        {'devo_id': 'fri-1'},
        {'devo_id': null},
        {'generated_devo_id': 'g1'},
      ]),
      {'fri-1'},
    );
  });
}
