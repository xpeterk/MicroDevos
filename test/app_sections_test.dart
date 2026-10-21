import 'package:flutter_test/flutter_test.dart';
import 'package:micro_devos/domain/content/rich_document.dart';
import 'package:micro_devos/domain/parsing/notion_devo_parser.dart';

void main() {
  const card = '''
**At a Glance**
Come near before you feel ready.

[Wednesday edition](https://microdevos.substack.com/p/sample)

## 8 · Come Near Before You Feel Ready

Some of us wait to pray until we feel worthy of the conversation.

## App Sections

### Come Before You Feel Worthy
Summary: The throne of grace is for people who still need mercy.
Verse: Hebrews 4:16 — "Let us therefore come boldly unto the throne of grace."
Tags: prayer, trust
Minutes: 2

Mercy meets the person who **comes** before they feel ready.

### Ask for the Next Hour
Summary: Wisdom for this hour is given without a scolding.
Verse: James 1:5 — "If any of you lack wisdom, let him ask of God."
Tags: prayer, hope
Minutes: 1

Ask for the wisdom the next hour needs.
''';

  test('app sections are stripped from the body and kept as blocks', () {
    final devos = NotionDevoParser.parse(card);
    expect(devos, hasLength(1));
    final devo = devos.single;
    expect(devo.sections, hasLength(2));
    expect(devo.bodyMd.contains('App Sections'), isFalse);
    expect(devo.bodyMd.contains('###'), isFalse);
    expect(devo.bodyMd.contains('Come Before You Feel Worthy'), isFalse);
    final plain = parseContent(devo.bodyMd)
        .map((block) => block.plainText)
        .join('\n');
    expect(plain, contains('wait to pray'));

    final first = devo.sections.first;
    expect(first.position, 1);
    expect(first.title, 'Come Before You Feel Worthy');
    expect(
      first.summary,
      'The throne of grace is for people who still need mercy.',
    );
    expect(first.verseRef, 'Hebrews 4:16');
    expect(first.verseText, contains('come boldly'));
    expect(first.minutes, 2);
    expect(first.tags, ['prayer', 'trust']);
    final body = parseContent(first.body);
    expect(body.single.runs.first.text, 'Mercy meets the person who ');
    expect(body.single.runs[1].bold, isTrue);
    expect(body.single.runs[1].text, 'comes');
    expect(first.body.contains('**'), isFalse);

    expect(devo.sections[1].position, 2);
    expect(devo.sections[1].minutes, 1);
    expect(devo.sections[1].tags, ['prayer', 'hope']);
  });

  test('a devotion with no app sections stays a single body', () {
    const plain = '''
**At a Glance**
The day can shake.

[Wednesday edition](https://microdevos.substack.com/p/sample)

## 1 · A Refuge That Does Not Move

The refuge does not relocate when the headlines do.
''';
    final devos = NotionDevoParser.parse(plain);
    expect(devos.single.sections, isEmpty);
    final text = parseContent(devos.single.bodyMd)
        .map((block) => block.plainText)
        .join('\n');
    expect(text, contains('does not relocate'));
    expect(devos.single.bodyMd.contains('App Sections'), isFalse);
  });
}
