import 'package:flutter_test/flutter_test.dart';
import 'package:micro_devos/domain/content/rich_document.dart';

void main() {
  test('markdown and json keep every notion annotation and block', () {
    const markdown = '''
# Known on every road

God is **near**, *present*, ++faithful++, ~~finished~~, and `refuge`.

Read [Psalm 46](https://example.com/psalm).

- Sit still
- Speak the verse

1. First
2. Second

> You are never out of sight.

:::callout
God knows the way home.
:::

---
''';

    final encoded = encodeContent(markdownToBlocks(markdown));
    final blocks = parseContent(encoded);
    expect(blocks.map((block) => block.kind), [
      ContentKind.heading,
      ContentKind.paragraph,
      ContentKind.paragraph,
      ContentKind.bullet,
      ContentKind.bullet,
      ContentKind.number,
      ContentKind.number,
      ContentKind.quote,
      ContentKind.callout,
      ContentKind.divider,
    ]);
    expect(blocks.first.plainText, 'Known on every road');
    expect(blocks.first.level, 1);
    expect(blocks[5].index, 1);
    expect(blocks[6].index, 2);

    final styled = blocks[1].runs;
    expect(styled.firstWhere((run) => run.text == 'near').bold, isTrue);
    expect(styled.firstWhere((run) => run.text == 'present').italic, isTrue);
    expect(
      styled.firstWhere((run) => run.text == 'faithful').underline,
      isTrue,
    );
    expect(styled.firstWhere((run) => run.text == 'finished').strike, isTrue);
    expect(styled.firstWhere((run) => run.text == 'refuge').code, isTrue);

    final link = blocks[2].runs.firstWhere((run) => run.text == 'Psalm 46');
    expect(link.link, 'https://example.com/psalm');
    expect(link.underline, isTrue);

    expect(encoded, isNot(contains('**')));
    expect(encoded, isNot(contains('###')));
    expect(encoded, isNot(contains(':::')));
    expect(encoded, isNot(contains('++')));
    expect(encoded, isNot(contains('~~')));

    expect(parseContent(markdown).map((block) => block.kind), [
      for (final block in blocks) block.kind,
    ]);
  });

  test('an unclosed marker stays as text', () {
    final runs = parseInlines('keep *this open');
    expect(runs.single.text, 'keep *this open');
  });

  test('broken json falls through to markdown', () {
    final blocks = parseContent('{not json\n\nHello **there**.');
    expect(blocks.last.plainText, contains('there'));
    expect(blocks.last.runs.any((run) => run.bold), isTrue);
  });
}
