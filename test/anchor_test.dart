import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_devos/domain/models/devo.dart';
import 'package:micro_devos/domain/models/devo_note.dart';
import 'package:micro_devos/features/browse/passage.dart';

void main() {
  const sentence = 'Being still is not the same as having nothing to do.';

  test('whitespace and punctuation are not anchors', () {
    expect(isUsableAnchor(null), isFalse);
    expect(isUsableAnchor(''), isFalse);
    expect(isUsableAnchor('   '), isFalse);
    expect(isUsableAnchor('.'), isFalse);
    expect(isUsableAnchor('...'), isFalse);
    expect(isUsableAnchor('—'), isFalse);
    expect(isUsableAnchor('…'), isFalse);
    expect(isUsableAnchor(sentence), isTrue);
  });

  test('a period does not locate or highlight a passage', () {
    final devo = Devo(
      id: 'fri-1',
      title: 'A Refuge That Does Not Move',
      hook: 'The day can shake.',
      bodyMd: '$sentence It is knowing who is God.',
      takeaway: 'Sit for one quiet minute.',
      verseText: 'God is our refuge.',
      verseRef: 'Psalm 46:1',
      scriptures: const [],
      editionDate: DateTime(2026, 10, 16),
      position: 1,
      status: 'published',
      tags: const ['courage'],
    );

    expect(locatePassage(devo, '.'), isNull);
    expect(locatePassage(devo, ' . '), isNull);
    expect(locatePassage(devo, sentence)?.section, 'body');

    final plain = highlightSpans(
      source: devo.bodyMd,
      style: const TextStyle(),
      anchors: const ['.'],
    );
    expect(plain, hasLength(1));
    expect((plain.single as TextSpan).text, devo.bodyMd);

    final marked = highlightSpans(
      source: devo.bodyMd,
      style: const TextStyle(),
      anchors: const [sentence],
    );
    expect(marked, hasLength(3));
    expect((marked[1] as TextSpan).text, sentence);
    expect((marked[1] as TextSpan).style?.backgroundColor, highlightColor);
  });
}
