import 'package:flutter_test/flutter_test.dart';
import 'package:micro_devos/data/bible/api_bible_verse_provider.dart';
import 'package:micro_devos/data/bible/bundled_kjv_verse_provider.dart';
import 'package:micro_devos/data/bible/esv_verse_provider.dart';
import 'package:micro_devos/domain/bible/verse_provider.dart';
import 'package:micro_devos/domain/bible/verse_reference.dart';
import 'package:micro_devos/domain/models/bible_version.dart';

void main() {
  test('ESV and NIV are the featured checkboxes; the rest live with them in settings', () {
    expect(BibleVersion.featured, [BibleVersion.esv, BibleVersion.niv]);
    expect(BibleVersion.additional, containsAll([
      BibleVersion.kjv,
      BibleVersion.nlt,
      BibleVersion.nkjv,
      BibleVersion.csb,
      BibleVersion.nasb,
    ]));
    expect(BibleVersion.featured, isNot(contains(BibleVersion.kjv)));
  });

  test('the default reading translation is bundled KJV', () {
    final selection = BibleVersionSelection.initial();
    expect(selection.reading, BibleVersion.kjv);
    expect(selection.enabled, {BibleVersion.kjv});
    expect(selection.toStoredList(), ['kjv']);
  });

  test('checking a translation makes it the reading one and stores it first', () {
    final selection = BibleVersionSelection.initial().toggle(BibleVersion.esv);
    expect(selection.enabled, {BibleVersion.kjv, BibleVersion.esv});
    expect(selection.reading, BibleVersion.esv);
    expect(selection.toStoredList(), ['esv', 'kjv']);
  });

  test('the last translation cannot be turned off', () {
    final only = BibleVersionSelection.initial();
    expect(only.canDisable(BibleVersion.kjv), isFalse);
    expect(only.toggle(BibleVersion.kjv).enabled, {BibleVersion.kjv});

    final both = only.toggle(BibleVersion.niv);
    final backToKjv = both.toggle(BibleVersion.niv);
    expect(backToKjv.reading, BibleVersion.kjv);
    expect(backToKjv.canDisable(BibleVersion.kjv), isFalse);
  });

  test('turning off the reading translation falls back in display order', () {
    final selection = BibleVersionSelection.initial()
        .toggle(BibleVersion.nasb)
        .toggle(BibleVersion.esv)
        .toggle(BibleVersion.esv);
    expect(selection.reading, BibleVersion.kjv);
    expect(selection.enabled, {BibleVersion.kjv, BibleVersion.nasb});
  });

  test('a stored list ignores unknown ids and keeps the first as the reading translation', () {
    final selection = BibleVersionSelection.fromStored(['nope', 'NIV', 'esv']);
    expect(selection.reading, BibleVersion.niv);
    expect(selection.enabled, {BibleVersion.niv, BibleVersion.esv});
    expect(BibleVersionSelection.fromStored(const []).reading, BibleVersion.kjv);
    expect(
      BibleVersionSelection.fromStored(['kjv', 'csb']).withReading(BibleVersion.csb).reading,
      BibleVersion.csb,
    );
  });

  test('verse references accept common abbreviations', () {
    expect(VerseReference.normalize('Matt 5:14'), 'matthew 5:14');
    expect(VerseReference.normalize('Ps. 23:1'), 'psalm 23:1');
    expect(VerseReference.normalize('2 Cor 12:9'), '2 corinthians 12:9');
    expect(VerseReference.normalize('Romans 12:2 ESV'), 'romans 12:2');
  });

  test('the KJV bundle supplies sample verses and a joined range', () {
    final bundle = KjvBundle.parse('''
{
  "Matthew 11:28": "Come unto me.",
  "Matthew 11:29": "Take my yoke upon you."
}
''');
    final provider = BundledKjvVerseProvider(bundle);
    expect(provider.isConfigured, isTrue);
    expect(bundle.lookup('Matt 11:28'), 'Come unto me.');
    expect(bundle.lookup('Matthew 11:28-29'), 'Come unto me. Take my yoke upon you.');
  });

  test('ESV and API.Bible stay quiet without keys', () async {
    final esv = EsvVerseProvider(apiKey: '');
    final niv = ApiBibleVerseProvider(
      version: BibleVersion.niv,
      apiKey: null,
      bibleId: null,
    );
    expect(esv.isConfigured, isFalse);
    expect(niv.isConfigured, isFalse);
    expect(await esv.getVerse('John 1:1'), isNull);
    expect(await niv.getVerse('John 1:1'), isNull);

    final catalog = VerseCatalog({
      BibleVersion.kjv: BundledKjvVerseProvider(
        KjvBundle.parse('{"John 1:1": "In the beginning was the Word."}'),
      ),
      BibleVersion.esv: esv,
    });
    final resolved = await catalog.resolve(
      reference: 'John 1:1',
      fallbackText: 'edition text',
      selection: BibleVersionSelection.initial().toggle(BibleVersion.esv),
    );
    expect(resolved.version, BibleVersion.kjv);
    expect(resolved.text, 'In the beginning was the Word.');
    expect(resolved.note, contains('ESV'));
  });
}
