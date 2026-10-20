import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/edition_date_format.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/sample/sample_catalog.dart';
import '../../domain/models/devo.dart';
import '../../domain/models/devo_note.dart';
import '../../shared/widgets/reading_widgets.dart';
import 'banner.dart';
import 'browse_state.dart';
import 'feed_snack.dart';
import 'filter_sheet.dart';
import 'passage.dart';
import 'share_sheet.dart';

class FeedView extends ConsumerWidget {
  const FeedView({
    required this.devos,
    required this.edition,
    required this.isFallback,
    super.key,
  });

  final List<Devo> devos;
  final DateTime? edition;
  final bool isFallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(browseFilterProvider);
    final liked = ref.watch(favoritesProvider).value ?? const <String>{};
    final notes = ref.watch(notesProvider).value ?? const <DevoNote>[];
    final noted = {for (final note in notes) note.targetId};
    final visible = applyBrowseFilter(
      devos: devos,
      filter: filter,
      likedIds: liked,
      notedIds: noted,
    );
    final catalog = ref.watch(tagCatalogProvider).asData?.value;
    final kicker = edition == null
        ? 'TODAY'
        : 'TODAY · ${formatEditionDate(edition!, 'EEE, MMM d').toUpperCase()} · ${devos.length} DEVOS';

    return CenteredColumn(
      child: CustomScrollView(
        key: const Key('feed-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kicker,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontFamily: AppTheme.sans,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (isFallback && edition != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Showing ${formatEditionDate(edition!, 'EEEE, MMMM d')}, the latest weekday edition.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: AppTheme.sans,
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                itemCount: devos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final devo = devos[index];
                  final label = _label(catalog, devo);
                  return GestureDetector(
                    key: Key('story-${devo.id}'),
                    onTap: () => context.push('/story/${devo.id}'),
                    child: StoryCircle(devo: devo, label: label),
                  );
                },
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterBarDelegate(catalog: catalog),
          ),
          if (visible.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nothing matches these filters.',
                  style: TextStyle(fontFamily: AppTheme.serif, fontSize: 18),
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Column(
                children: [
                  for (final devo in visible)
                    FeedPost(
                      devo: devo,
                      total: devos.length,
                      label: _label(catalog, devo),
                      catalog: catalog,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _label(SampleCatalog? catalog, Devo devo) {
  if (devo.tags.isEmpty) return 'Devotion';
  return catalog?.tagBySlug(devo.tags.first)?.label ?? devo.tags.first;
}

class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  _FilterBarDelegate({required this.catalog});

  final SampleCatalog? catalog;

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      key: const Key('feed-filter-bar'),
      color: Theme.of(context).colorScheme.surface,
      child: const FilterBar(),
    );
  }

  @override
  bool shouldRebuild(_FilterBarDelegate oldDelegate) => true;
}

class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(browseFilterProvider);
    final catalog = ref.watch(tagCatalogProvider).asData?.value;
    final scheme = Theme.of(context).colorScheme;
    String labelOf(String slug) => catalog?.tagBySlug(slug)?.label ?? slug;

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 4),
          _ToggleChip(
            key: const Key('liked-filter'),
            icon: Icons.favorite_border,
            label: 'Liked',
            selected: filter.onlyLiked,
            onTap: () => ref.read(browseFilterProvider.notifier).toggleLiked(),
          ),
          const SizedBox(width: 2),
          _ToggleChip(
            key: const Key('notes-filter'),
            icon: Icons.sticky_note_2_outlined,
            label: 'Notes',
            selected: filter.onlyNotes,
            onTap: () => ref.read(browseFilterProvider.notifier).toggleNotes(),
          ),
          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            color: scheme.outline,
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const Key('filter-chip-scroller'),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final slug in filter.tags)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _FilterTagChip(
                        chipKey: Key('chip-$slug'),
                        label: labelOf(slug),
                        onDeleted: () => ref
                            .read(browseFilterProvider.notifier)
                            .removeTag(slug),
                        deleteKey: Key('chip-delete-$slug'),
                      ),
                    ),
                  for (final slug in filter.interests)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _FilterTagChip(
                        chipKey: Key('interest-chip-$slug'),
                        label: labelOf(slug),
                        onDeleted: () => ref
                            .read(browseFilterProvider.notifier)
                            .removeInterest(slug),
                      ),
                    ),
                  if (filter.ageRange != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _FilterTagChip(
                        label: filter.ageRange!,
                        onDeleted: () => ref
                            .read(browseFilterProvider.notifier)
                            .setAge(null),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (filter.hasChips)
            TextButton(
              key: const Key('clear-filters'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                minimumSize: const Size(0, 36),
              ),
              onPressed: () =>
                  ref.read(browseFilterProvider.notifier).clearChips(),
              child: const Text('Clear'),
            ),
          IconButton(
            key: const Key('filter-button'),
            tooltip: 'Filters',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            onPressed: () => openFilterSheet(context),
            icon: Badge(
              isLabelVisible: filter.activeCount > 0,
              backgroundColor: scheme.primary,
              textColor: scheme.onPrimary,
              label: Text(
                '${filter.activeCount}',
                key: const Key('filter-count'),
              ),
              child: const Icon(Icons.tune),
            ),
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = selected
        ? scheme.primaryContainer
        : scheme.surfaceContainerLowest;
    return Material(
      color: background,
      shape: StadiumBorder(side: BorderSide(color: scheme.outline)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 7, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: scheme.primary),
              const SizedBox(width: 3),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTheme.sans,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterTagChip extends StatelessWidget {
  const _FilterTagChip({
    required this.label,
    required this.onDeleted,
    this.chipKey,
    this.deleteKey,
  });

  final Key? chipKey;
  final Key? deleteKey;
  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      key: chipKey,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.only(left: 4, right: 2),
      labelPadding: const EdgeInsets.only(left: 2, right: 0),
      label: Text(
        label,
        style: const TextStyle(fontFamily: AppTheme.sans, fontSize: 13),
      ),
      onDeleted: onDeleted,
      deleteIcon: Icon(Icons.close, key: deleteKey, size: 16),
    );
  }
}

class FeedPost extends ConsumerStatefulWidget {
  const FeedPost({
    required this.devo,
    required this.total,
    required this.label,
    required this.catalog,
    super.key,
  });

  final Devo devo;
  final int total;
  final String label;
  final SampleCatalog? catalog;

  @override
  ConsumerState<FeedPost> createState() => _FeedPostState();
}

class _FeedPostState extends ConsumerState<FeedPost> {
  var _burst = 0;

  @override
  Widget build(BuildContext context) {
    final devo = widget.devo;
    final depth = ref.watch(postDepthProvider)[devo.id] ?? PostDepth.collapsed;
    final liked =
        ref.watch(favoritesProvider).value?.contains(devo.id) ?? false;
    final notes = [
      for (final note in ref.watch(notesProvider).value ?? const <DevoNote>[])
        if (note.targetId == devo.id) note,
    ];
    final draft = ref.watch(noteDraftProvider);
    final scheme = Theme.of(context).colorScheme;

    List<String> anchors(String section) {
      final found = <String>[];
      if (draft != null &&
          draft.devoId == devo.id &&
          draft.section == section &&
          draft.hasAnchor) {
        found.add(draft.anchorText!);
      }
      for (final note in notes) {
        if (note.section == section && note.hasAnchor) {
          found.add(note.anchorText!);
        }
      }
      return found;
    }

    List<DevoNote> beside(String? section, String source) {
      return [
        for (final note in notes)
          if (note.section == section &&
              draft?.noteId != note.id &&
              (section == null ||
                  (isUsableAnchor(note.anchorText) &&
                      source.contains(note.anchorText!))))
            note,
      ];
    }

    void openNote(DevoNote note) {
      ref.read(noteDraftProvider.notifier).openExisting(note);
    }

    return Padding(
      key: Key('post-${devo.id}'),
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const _Avatar(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatEditionDate(devo.editionDate, 'EEE, MMM d'),
                        style: const TextStyle(
                          fontFamily: AppTheme.sans,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontFamily: AppTheme.sans,
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Open',
                  onPressed: () => context.push('/devo/${devo.id}'),
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
          ),
          DevoBanner(
            devo: devo,
            burstToken: _burst,
            onDoubleTap: () {
              setState(() => _burst += 1);
              toggleLike(context, ref, devo.id);
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 16, 0),
            child: Row(
              children: [
                IconButton(
                  key: Key('heart-${devo.id}'),
                  tooltip: liked ? 'Remove from saved' : 'Save',
                  onPressed: () => toggleLike(context, ref, devo.id),
                  icon: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? scheme.primary : scheme.onSurface,
                  ),
                ),
                IconButton(
                  key: Key('share-button-${devo.id}'),
                  tooltip: 'Share',
                  onPressed: () => openShareSheet(context, devo),
                  icon: const Icon(Icons.ios_share),
                ),
                IconButton(
                  key: Key('note-button-${devo.id}'),
                  tooltip: 'Note',
                  onPressed: () =>
                      ref.read(noteDraftProvider.notifier).openNew(devo.id),
                  icon: Badge(
                    isLabelVisible: notes.isNotEmpty,
                    label: Text('${notes.length}'),
                    child: Icon(
                      Icons.sticky_note_2_outlined,
                      color: notes.isEmpty ? scheme.onSurface : AppColors.line,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${devo.position} of ${widget.total}',
                  style: TextStyle(
                    fontFamily: AppTheme.sans,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (depth == PostDepth.collapsed)
                  _WithNotes(
                    notes: beside(null, ''),
                    onOpen: openNote,
                    child: Text.rich(
                      TextSpan(
                        style: Theme.of(context).textTheme.bodyLarge,
                        children: [
                          ...highlightSpans(
                            source: devo.hook,
                            style: Theme.of(context).textTheme.bodyLarge,
                            anchors: anchors('hook'),
                          ),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: GestureDetector(
                              key: Key('more-${devo.id}'),
                              onTap: () => ref
                                  .read(postDepthProvider.notifier)
                                  .setDepth(devo.id, PostDepth.summary),
                              child: Text(
                                ' … more',
                                style: TextStyle(
                                  fontFamily: AppTheme.serif,
                                  fontSize: 18,
                                  color: scheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SelectionArea(
                    magnifierConfiguration: TextMagnifierConfiguration.disabled,
                    onSelectionChanged: (content) {
                      ref
                          .read(passageSelectionProvider.notifier)
                          .setText(content?.plainText);
                    },
                    contextMenuBuilder: (context, selectableRegionState) {
                      return const SizedBox.shrink();
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _WithNotes(
                          notes: beside('hook', devo.hook),
                          onOpen: openNote,
                          child: Text.rich(
                            TextSpan(
                              children: highlightSpans(
                                source: devo.hook,
                                style: Theme.of(context).textTheme.bodyLarge,
                                anchors: anchors('hook'),
                              ),
                            ),
                          ),
                        ),
                        if (depth == PostDepth.summary) ...[
                          const SizedBox(height: 12),
                          const _DashDivider(),
                          const SizedBox(height: 12),
                          _SummaryBlock(devo: devo, anchors: anchors),
                          TextButton(
                            key: Key('read-full-${devo.id}'),
                            onPressed: () => ref
                                .read(postDepthProvider.notifier)
                                .setDepth(devo.id, PostDepth.full),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Read the full devo'),
                                Icon(Icons.expand_more),
                              ],
                            ),
                          ),
                        ],
                        if (depth == PostDepth.full)
                          _FullBlock(
                            devo: devo,
                            anchors: anchors,
                            beside: beside,
                            onOpen: openNote,
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: [
                    for (final slug in devo.tags)
                      TextButton(
                        key: Key('hashtag-${devo.id}-$slug'),
                        onPressed: () => ref
                            .read(browseFilterProvider.notifier)
                            .addTag(slug),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        child: Text(
                          '#${widget.catalog?.tagBySlug(slug)?.label ?? slug}',
                          style: TextStyle(
                            fontFamily: AppTheme.sans,
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBlock extends ConsumerWidget {
  const _SummaryBlock({required this.devo, required this.anchors});

  final Devo devo;
  final List<String> Function(String section) anchors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final verseColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.nightVerse
        : AppColors.verse;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timer_outlined, size: 16, color: scheme.primary),
            const SizedBox(width: 6),
            Text(
              '5-SECOND DEVO',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontFamily: AppTheme.sans,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: highlightSpans(
              source: devo.takeaway,
              style: Theme.of(context).textTheme.headlineSmall,
              anchors: anchors('takeaway'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: verseColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VERSE',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontFamily: AppTheme.sans,
                  letterSpacing: 1,
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  children: highlightSpans(
                    source: devo.verseText,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(fontStyle: FontStyle.italic),
                    anchors: anchors('verse'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                devo.verseRef,
                style: TextStyle(
                  fontFamily: AppTheme.sans,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FullBlock extends ConsumerWidget {
  const _FullBlock({
    required this.devo,
    required this.anchors,
    required this.beside,
    required this.onOpen,
  });

  final Devo devo;
  final List<String> Function(String section) anchors;
  final List<DevoNote> Function(String? section, String source) beside;
  final void Function(DevoNote note) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final paragraphs = devo.bodyMd
        .trim()
        .split(RegExp(r'\n\s*\n'))
        .where((part) => part.trim().isNotEmpty);
    final bodyStyle = Theme.of(context).textTheme.bodyLarge;
    final claimed = <String>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(devo.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        for (final paragraph in paragraphs) ...[
          _WithNotes(
            notes: [
              for (final note in beside('body', paragraph))
                if (claimed.add(note.id)) note,
            ],
            onOpen: onOpen,
            child: Text.rich(
              TextSpan(
                children: highlightSpans(
                  source: paragraph.trim(),
                  style: bodyStyle,
                  anchors: anchors('body'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (final quote in devo.scriptures) ...[
          Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: scheme.primary, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: highlightSpans(
                      source: quote.text,
                      style: bodyStyle?.copyWith(fontStyle: FontStyle.italic),
                      anchors: anchors('scripture'),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  quote.reference,
                  style: TextStyle(
                    fontFamily: AppTheme.sans,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '→  NEXT STEP',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontFamily: AppTheme.sans,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  children: highlightSpans(
                    source: devo.takeaway,
                    style: bodyStyle,
                    anchors: anchors('takeaway'),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          devo.hook,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        TextButton(
          key: Key('show-less-${devo.id}'),
          onPressed: () => ref
              .read(postDepthProvider.notifier)
              .setDepth(devo.id, PostDepth.collapsed),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [Text('Show less'), Icon(Icons.expand_less)],
          ),
        ),
      ],
    );
  }
}

class _WithNotes extends StatelessWidget {
  const _WithNotes({
    required this.child,
    required this.notes,
    required this.onOpen,
  });

  final Widget child;
  final List<DevoNote> notes;
  final void Function(DevoNote note) onOpen;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return child;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: child),
        const SizedBox(width: 8),
        Column(
          children: [
            for (final note in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                  key: Key('postit-${note.id}'),
                  onTap: () => onOpen(note),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8E7A2),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.sticky_note_2,
                      size: 18,
                      color: Color(0xFF8A6A20),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DashDivider extends StatelessWidget {
  const _DashDivider();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 10).floor().clamp(1, 80);
        return Row(
          children: [
            for (var i = 0; i < count; i++)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 1,
                  color: color,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.olive,
        shape: BoxShape.circle,
      ),
      child: const Text(
        'md',
        style: TextStyle(
          fontFamily: AppTheme.sans,
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
