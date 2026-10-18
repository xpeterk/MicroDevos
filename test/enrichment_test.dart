import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_devos/core/providers.dart';
import 'package:micro_devos/data/enrichment/disabled_embedding_provider.dart';
import 'package:micro_devos/data/enrichment/fake_enrichment.dart';
import 'package:micro_devos/data/enrichment/keyword_tagging_provider.dart';

void main() {
  test('the app embedding provider is disabled and returns null', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = container.read(embeddingProvider);
    expect(provider, isA<DisabledEmbeddingProvider>());
    expect(provider.isConfigured, isFalse);
    expect(await provider.embed('God is our refuge'), isNull);
  });

  test('the fake embedding provider records text and returns its vector', () async {
    final fake = FakeEmbeddingProvider(vector: const [1, 0, 0, 1]);
    final vector = await fake.embed('A refuge that does not move');
    expect(fake.calls, ['A refuge that does not move']);
    expect(vector, [1, 0, 0, 1]);
    expect(fake.isConfigured, isTrue);
  });

  test('keyword tagging matches catalog words and the fake respects the catalog', () {
    const keyword = KeywordTaggingProvider();
    final suggested = keyword.suggestTags(
      'When fear is loud, peace is still a prayer.',
      catalogSlugs: KeywordTaggingProvider.seedSlugs,
    );
    expect(suggested, ['fear', 'peace', 'prayer']);

    final fake = FakeTaggingProvider(['hope', 'not-a-tag']);
    expect(
      fake.suggestTags('anything', catalogSlugs: KeywordTaggingProvider.seedSlugs),
      ['hope'],
    );
    expect(fake.calls, ['anything']);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(taggingProvider).name, 'keyword');
  });
}
