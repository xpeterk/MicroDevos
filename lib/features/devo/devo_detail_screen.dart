import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/bible/verse_provider.dart';
import '../../domain/models/devo.dart';
import '../../domain/models/user_preferences.dart';
import '../../shared/widgets/reading_widgets.dart';
import '../browse/banner.dart';
import '../browse/browse_state.dart';
import '../browse/feed_snack.dart';
import '../browse/note_pane.dart';
import '../browse/style_banner.dart';
import 'one_minute_section.dart';
import 'section_detail.dart';

/// The newsletter picture is the header inside the full devotion, except on
/// the photo and duotone frames, which already show that picture large.
bool showsNewsletterImage(Devo devo) {
  final url = devo.imageUrl?.trim();
  if (url == null || url.isEmpty) return false;
  final frame = bannerFrameFor(devo.position);
  return frame != BannerFrame.photoScrim && frame != BannerFrame.duotone;
}

class DevoDetailScreen extends ConsumerWidget {
  const DevoDetailScreen({required this.id, this.initialSectionId, super.key});

  final String id;
  final String? initialSectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devo = ref.watch(devoByIdProvider(id));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final devoScreenBg = isDark ? const Color(0xFF0A0908) : const Color(0xFFE6DFD0);
    return Scaffold(
      key: const Key('devo-detail'),
      backgroundColor: devoScreenBg,
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
          if (value.sections.isEmpty) return _Detail(devo: value);
          final dayCount =
              ref
                  .watch(todayProvider)
                  .asData
                  ?.value
                  .devos
                  .where(
                    (item) => isSameDate(item.editionDate, value.editionDate),
                  )
                  .length ??
              8;
          return SectionDetail(
            devo: value,
            dayCount: dayCount,
            initialSectionId: initialSectionId,
          );
        },
      ),
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
    final wholeFavorites =
        ref.watch(favoritesProvider).value ?? const <String>{};
    final isWholeLiked = wholeFavorites.contains(devo.id);
    final draft = ref.watch(noteDraftProvider);
    final selection = ref.watch(passageSelectionProvider);
    final openDraft = draft != null && draft.devoId == devo.id ? draft : null;
    final noting = openDraft != null;
    final scheme = Theme.of(context).colorScheme;
    final imageUrl = devo.imageUrl?.trim() ?? '';
    final showNewsletter = showsNewsletterImage(devo);
    final dayCount =
        ref
            .watch(todayProvider)
            .asData
            ?.value
            .devos
            .where((item) => isSameDate(item.editionDate, devo.editionDate))
            .length ??
        8;

    return Stack(
      children: [
        ReadingWidth(
          child: ListView(
            key: const Key('devo-detail-scroll'),
            padding: EdgeInsets.only(bottom: noting ? 280 : 108),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: StyleBanner(devo: devo, total: dayCount, hero: true),
              ),
              OneMinuteSection(devo: devo),
              if (showNewsletter)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: UncroppedNetworkImage(
                      key: const Key('newsletter-image'),
                      imageUrl: imageUrl,
                      semanticLabel: (devo.imageAlt?.trim().isNotEmpty ?? false)
                          ? devo.imageAlt!.trim()
                          : devo.title,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('EEEE, MMMM d').format(devo.editionDate),
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontFamily: AppTheme.sans,
                            color: scheme.primary,
                          ),
                        ),
                        IconButton(
                          key: Key('devo-favorite-${devo.id}'),
                          tooltip: isWholeLiked
                              ? 'Remove from Saved'
                              : 'Save full devotional',
                          icon: Icon(
                            isWholeLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: isWholeLiked
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          onPressed: () async {
                            await ref
                                .read(favoritesProvider.notifier)
                                .toggle(devo.id);
                            if (context.mounted) {
                              showFeedSnack(
                                context,
                                isWholeLiked
                                    ? 'Removed devotional from Saved'
                                    : 'Saved full devotional',
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    catalog.when(
                      loading: () => VerseCard(
                        text: devo.verseText,
                        reference: devo.verseRef,
                      ),
                      error: (_, _) => VerseCard(
                        text: devo.verseText,
                        reference: devo.verseRef,
                      ),
                      data: (verseCatalog) => _ResolvedVerse(
                        catalog: verseCatalog,
                        devo: devo,
                        preferences: preferences,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SelectionArea(
                      magnifierConfiguration:
                          TextMagnifierConfiguration.disabled,
                      onSelectionChanged: (content) {
                        ref
                            .read(passageSelectionProvider.notifier)
                            .setText(content?.plainText);
                      },
                      contextMenuBuilder: (context, selectableRegionState) {
                        return const SizedBox.shrink();
                      },
                      child: DevoBody(markdown: devo.bodyMd),
                    ),
                    if (devo.takeaway.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TakeawayBlock(text: devo.takeaway),
                    ],
                    const SizedBox(height: 22),
                    ScriptureList(quotes: devo.scriptures),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (noting && selection != null)
          Positioned(
            key: const Key('anchor-toolbar-slot'),
            top: 8,
            left: 12,
            right: 12,
            child: Center(child: AnchorToolbar(devoId: devo.id)),
          ),
        if (openDraft != null)
          Positioned(
            key: const Key('note-pane-slot'),
            left: 0,
            right: 0,
            bottom: 0,
            child: NotePane(key: ValueKey(openDraft.session)),
          ),
        if (!noting)
          Positioned(
            key: const Key('back-pill-slot'),
            left: 0,
            right: 0,
            bottom: 18,
            child: Center(child: _BackPill(onPressed: () => context.pop())),
          ),
      ],
    );
  }
}

class _BackPill extends StatelessWidget {
  const _BackPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const Key('back-to-feed'),
      onPressed: onPressed,
      icon: const Icon(Icons.keyboard_arrow_down),
      label: const Text('Back to feed'),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF2A2420),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(
          fontFamily: AppTheme.sans,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        shape: const StadiumBorder(),
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
