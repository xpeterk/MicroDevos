import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:micro_devos/domain/content/rich_document.dart';
import 'package:micro_devos/domain/parsing/notion_devo_parser.dart';

void main() {
  String load(String name) =>
      File('test/fixtures/notion/$name').readAsStringSync();

  test('parses a current card into hook, scriptures, takeaway, and verse', () {
    final meta = const NotionCardMeta(
      title: "Only God's Opinion of You Matters",
      status: 'Archive',
      editionDate: '2026-10-14',
      stars: 3,
      notionPageId: 'page-4',
    );
    final markdown = load('newer.md');
    expect(
      NotionDevoParser.decide(
        status: meta.status,
        title: meta.title,
        markdown: markdown,
      ).shouldImport,
      isTrue,
    );

    final devos = NotionDevoParser.parse(markdown, meta: meta);
    expect(devos, hasLength(1));
    final devo = devos.single;
    expect(devo.position, 4);
    expect(devo.title, "Only God's Opinion of You Matters");
    expect(devo.hook, "IDENTITY: Only God's opinion of you sticks.");
    expect(
      devo.takeaway,
      'Today, write one sentence about who God says you are.',
    );
    expect(devo.verseRef, 'Matthew 5:14');
    expect(
      devo.verseText,
      'Ye are the light of the world. A city that is set on an hill cannot be hid.',
    );
    expect(devo.scriptures.map((quote) => quote.reference), [
      'Matthew 5:14',
      'Romans 12:2',
    ]);
    expect(
      devo.editionUrl,
      'https://microdevos.substack.com/p/micro-devos-wednesday-october-14-2026',
    );
    expect(devo.sourceUrl, 'https://example.com/source');
    expect(devo.editionDate, '2026-10-14');
    expect(devo.stars, 3);
    expect(devo.status, 'Archive');
    expect(devo.notionPageId, 'page-4');
    final blocks = parseContent(devo.bodyMd);
    expect(
      blocks.any(
        (block) =>
            block.kind == ContentKind.heading && block.plainText == 'Pressure',
      ),
      isTrue,
    );
    expect(
      blocks.map((block) => block.plainText).join('\n'),
      contains("God's opinion of you is still the one that sticks."),
    );
    expect(devo.bodyMd, isNot(contains('###')));
    expect(devo.bodyMd, isNot(contains('**')));
    expect(devo.bodyMd, isNot(contains('Today, write')));
    expect(devo.bodyMd, isNot(contains('VERSE')));
    expect(devo.bodyMd, isNot(contains('substack.com')));
    expect(devo.sections, isEmpty);
    expect(devo.teaser, isEmpty);
    expect(devo.prayer, isEmpty);
  });

  test('parses an older card with a sticky lesson and a glance line', () {
    final markdown = load('older.md');
    final devos = NotionDevoParser.parse(
      markdown,
      meta: const NotionCardMeta(editionDate: '2026-10-01', stars: 2),
    );
    expect(devos, hasLength(1));
    final devo = devos.single;
    expect(devo.position, 6);
    expect(devo.title, 'Even as the Enemy Blasts, God Builds');
    expect(
      devo.hook,
      'Rumors tried to stop the wall — he denied the lie, prayed, and kept building',
    );
    expect(
      devo.takeaway,
      'when rumors try to pull you off the wall, deny the lie, pray, and finish the work.',
    );
    expect(devo.verseRef, 'Nehemiah 6:9');
    expect(devo.verseText, contains('strengthen my hands'));
    expect(devo.scriptures.first.reference, 'Nehemiah 6:9');
    expect(devo.scriptures.first.text, contains('intimidate the builders'));
    expect(devo.bodyMd, contains("Sanballat's favorite weapon was rumor."));
    expect(devo.bodyMd, isNot(contains('Sticky lesson')));
    expect(
      devo.editionUrl,
      'https://microdevos.substack.com/p/micro-devos-thursday-october-1-2026',
    );
    expect(devo.sourceUrl, 'https://example.com/nehemiah');
  });

  test('parses two numbered devotions from one body', () {
    final devos = NotionDevoParser.parse(load('two.md'));
    expect(devos.map((devo) => devo.position), [1, 2]);
    expect(devos.map((devo) => devo.title), ['First Light', 'Second Light']);
    expect(
      devos.every(
        (devo) => devo.hook == 'Two short stops on the same morning.',
      ),
      isTrue,
    );
    expect(devos[0].verseRef, 'Psalm 46:1');
    expect(devos[1].verseRef, 'Psalm 119:105');
    expect(
      devos[0].editionUrl,
      'https://microdevotionals.substack.com/p/micro-devos-friday',
    );
    expect(devos[1].bodyMd, isNot(contains('First Light')));
  });

  test('skips ideas, prompts, and cards without an edition link', () {
    final body = load('newer.md');
    expect(
      NotionDevoParser.decide(
        status: 'Ideas',
        title: 'A real title',
        markdown: body,
      ).reason,
      contains('status'),
    );
    expect(
      NotionDevoParser.decide(
        status: 'AI-Ideas',
        title: 'A real title',
        markdown: body,
      ).reason,
      contains('status'),
    );
    expect(
      NotionDevoParser.decide(
        status: 'Archive',
        title: 'Prompt',
        markdown: load('skips.md'),
      ).reason,
      'non-devo page',
    );
    expect(
      NotionDevoParser.decide(
        status: 'Unread',
        title: 'Half written',
        markdown: '## 1 · Half written\n\nNo edition yet.',
      ).reason,
      'no edition link',
    );
    expect(
      NotionDevoParser.decide(
        status: 'Read',
        title: 'Notes',
        markdown: 'Edition: [Micro Devos](https://microdevos.substack.com/p/x)\n\nNo heading.',
      ).reason,
      'no numbered devotion heading',
    );
  });

  test(
    'parses the verse-box card: position, takeaway, emoji callout, edition',
    () {
      final markdown = File('tools/notion-import/fixtures/verse-box.md')
          .readAsStringSync();
      const meta = NotionCardMeta(
        title: 'A Refuge That Does Not Move',
        status: 'Archive',
        editionDate: '2026-10-16',
        stars: 3,
        sourceUrl: 'https://example.com/refuge',
        notionPageId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
      );
      expect(
        NotionDevoParser.decide(
          status: meta.status,
          title: meta.title,
          markdown: markdown,
        ).shouldImport,
        isTrue,
      );
      final devo = NotionDevoParser.parse(markdown, meta: meta).single;
      expect(devo.position, 3);
      expect(devo.title, 'A Refuge That Does Not Move');
      expect(devo.hook, 'A refuge is a person, and he is already here.');
      expect(
        devo.takeaway,
        'Today, say the verse once before the next hard conversation.',
      );
      expect(devo.verseRef, 'Psalm 46:1');
      expect(devo.verseText, contains('refuge and strength'));
      expect(
        devo.editionUrl,
        'https://microdevos.substack.com/p/micro-devos-friday-october-16-2026',
      );
      expect(devo.editionDate, '2026-10-16');
      expect(devo.stars, 3);
      expect(devo.status, 'Archive');
      expect(devo.notionPageId, meta.notionPageId);
      expect(devo.sourceUrl, 'https://example.com/refuge');
      expect(devo.bodyMd, isNot(contains('VERSE')));
      expect(devo.bodyMd, isNot(contains('📖')));
    },
  );

  test(
    'parses a v6 card into three plain sections, a teaser, and a prayer',
    () {
      final devo = NotionDevoParser.parse(load('v6.md')).single;
      expect(devo.hook, 'HEART: A short glance line.');
      expect(devo.takeaway, 'The banner sentence stands on its own.');
      expect(
        devo.teaser,
        'The teaser tells the story without repeating that sentence.',
      );
      expect(devo.prayer, 'Offer one real help to a friend who has not asked.');
      expect(devo.sections.map((section) => section.title), [
        'The Weight Nobody Named',
        'He Stepped Forward',
        'The Load Was Shared',
      ]);
      expect(devo.sections.first.verseRef, 'Gal 6:2');
      expect(devo.sections.first.verseText, contains('Carry each other'));
      final stored = [
        devo.bodyMd,
        ...devo.sections.map((section) => section.body),
      ].join('\n');
      expect(stored, isNot(contains('closing line')));
      expect(stored, isNot(contains('Share card')));
      expect(stored, isNot(contains('VERSE')));
      expect(stored, isNot(contains('Today')));
      expect(devo.teaser, isNot(devo.takeaway));
    },
  );

  test('a v6 lead with four headings keeps all four sections', () {
    const card = '''
## At a Glance
**HEART: Four stops.**
Edition: [Micro Devos](https://microdevos.substack.com/p/four)

## 1 · Four Parts
**The banner is this sentence.** *The teaser is a different sentence.*
### One
First.
### Two
Second.
### Three
Third.
### Four
Fourth.
''';
    final devo = NotionDevoParser.parse(card).single;
    expect(devo.sections, hasLength(4));
    expect(devo.sections.map((section) => section.title), [
      'One',
      'Two',
      'Three',
      'Four',
    ]);
  });

  test('counts star labels', () {
    expect(NotionDevoParser.starsFromLabel('★'), 1);
    expect(NotionDevoParser.starsFromLabel('★★'), 2);
    expect(NotionDevoParser.starsFromLabel('★★★'), 3);
    expect(NotionDevoParser.starsFromLabel(null), isNull);
  });
}
