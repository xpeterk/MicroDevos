import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/bible/verse_provider.dart';
import '../../domain/models/devo.dart';
import '../../domain/models/user_preferences.dart';
import '../../shared/widgets/reading_widgets.dart';
import '../browse/share_sheet.dart';

class DevoDetailScreen extends ConsumerWidget {
  const DevoDetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devo = ref.watch(devoByIdProvider(id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('DEVOTION'),
        actions: [
          devo.maybeWhen(
            data: (value) => value == null
                ? const SizedBox.shrink()
                : _DetailActions(devo: value),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: devo.when(
        loading: () => const LoadingView(),
        error: (error, _) => StatusMessage(
          title: 'This devotion could not be opened',
          body: 'Try again in a moment.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(devoByIdProvider(id)),
        ),
        data: (value) {
          if (value == null) {
            return const StatusMessage(
              title: 'Devotion not found',
              body:
                  'It may have moved, or this sample set does not include it.',
            );
          }
          return _Detail(devo: value);
        },
      ),
    );
  }
}

class _DetailActions extends ConsumerWidget {
  const _DetailActions({required this.devo});

  final Devo devo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider).value ?? const <String>{};
    final saved = favorites.contains(devo.id);
    return Row(
      children: [
        IconButton(
          tooltip: saved ? 'Remove from saved' : 'Save',
          onPressed: () => ref.read(favoritesProvider.notifier).toggle(devo.id),
          icon: Icon(saved ? Icons.favorite : Icons.favorite_border),
        ),
        IconButton(
          tooltip: 'Share',
          onPressed: () => openShareSheet(context, devo),
          icon: const Icon(Icons.ios_share),
        ),
      ],
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.devo});

  final Devo devo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences =
        ref.watch(preferencesProvider).value ?? UserPreferences.initial();
    final catalog = ref.watch(verseCatalogProvider);
    final scheme = Theme.of(context).colorScheme;
    return ReadingWidth(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
        children: [
          Text(
            DateFormat('EEEE, MMMM d').format(devo.editionDate),
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontFamily: AppTheme.sans, color: scheme.primary),
          ),
          const SizedBox(height: 18),
          const Eyebrow('At a Glance'),
          const SizedBox(height: 8),
          Text(
            devo.hook,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Container(width: 36, height: 2, color: scheme.secondary),
          const SizedBox(height: 18),
          Text(devo.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          DevoBody(markdown: devo.bodyMd),
          TakeawayBlock(text: devo.takeaway),
          const SizedBox(height: 22),
          ScriptureList(quotes: devo.scriptures),
          const SizedBox(height: 8),
          catalog.when(
            loading: () =>
                VerseCard(text: devo.verseText, reference: devo.verseRef),
            error: (_, _) =>
                VerseCard(text: devo.verseText, reference: devo.verseRef),
            data: (verseCatalog) => _ResolvedVerse(
              catalog: verseCatalog,
              devo: devo,
              preferences: preferences,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResolvedVerse extends StatelessWidget {
  const _ResolvedVerse({
    required this.catalog,
    required this.devo,
    required this.preferences,
  });

  final VerseCatalog catalog;
  final Devo devo;
  final UserPreferences preferences;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResolvedVerse>(
      future: catalog.resolve(
        reference: devo.verseRef,
        fallbackText: devo.verseText,
        selection: preferences.bibleVersions,
      ),
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved == null) {
          return VerseCard(text: devo.verseText, reference: devo.verseRef);
        }
        final reference = resolved.version == null
            ? devo.verseRef
            : '${devo.verseRef} · ${resolved.version!.shortLabel}';
        return VerseCard(
          text: resolved.text,
          reference: reference,
          note: resolved.note,
        );
      },
    );
  }
}
