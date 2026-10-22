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
import 'browse_state.dart';
import 'feed_snack.dart';
import 'filter_sheet.dart';
import 'share_sheet.dart';
import 'style_banner.dart';

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
    final catalog = ref.watch(tagCatalogProvider).asData?.value;
    final visible = applyBrowseFilter(
      devos: devos,
      filter: filter,
      likedIds: liked,
      notedIds: noted,
      catalog: catalog?.tags ?? const [],
    );

    return CenteredColumn(
      child: CustomScrollView(
        key: const Key('feed-scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                devos.isEmpty
                    ? 'FEED'
                    : '${devos.length} ${devos.length == 1 ? 'devo' : 'devos'}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontFamily: AppTheme.sans,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
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
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final group = _dayGroups(visible)[index];
                final newest =
                    edition != null &&
                    isSameDate(group.first.editionDate, edition!);
                final count = group.length;
                final date = formatEditionDate(
                  group.first.editionDate,
                  'EEE, MMM d',
                ).toUpperCase();
                final heading = newest
                    ? 'TODAY · $date · $count DEVOS'
                    : '$date · $count DEVOS';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(
                        heading,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontFamily: AppTheme.sans,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                    if (newest && isFallback)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Text(
                          'Showing ${formatEditionDate(group.first.editionDate, 'EEEE, MMMM d')}, the latest weekday edition.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontFamily: AppTheme.sans,
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    for (final devo in group)
                      FeedPost(
                        devo: devo,
                        total: count,
                        label: _label(catalog, devo),
                        catalog: catalog,
                      ),
                  ],
                );
              }, childCount: _dayGroups(visible).length),
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

List<List<Devo>> _dayGroups(List<Devo> devos) {
  final groups = <List<Devo>>[];
  for (final devo in devos) {
    if (groups.isEmpty ||
        !isSameDate(groups.last.first.editionDate, devo.editionDate)) {
      groups.add([devo]);
    } else {
      groups.last.add(devo);
    }
  }
  return groups;
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
    final scheme = Theme.of(context).colorScheme;
    final liked = (ref.watch(favoritesProvider).value ?? const <String>{})
        .contains(devo.id);
    final notes = [
      for (final note in ref.watch(notesProvider).value ?? const <DevoNote>[])
        if (note.targetId == devo.id) note,
    ];
    final frame = bannerFrameLabel(bannerFrameFor(devo.position));

    return Padding(
      key: Key('post-${devo.id}'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StyleBanner(
            devo: devo,
            total: widget.total,
            tagLabel: widget.label == 'Devotion' ? null : widget.label,
            burstToken: _burst,
            onTap: () => context.push('/devo/${devo.id}'),
            onDoubleTap: () {
              setState(() => _burst += 1);
              toggleLike(context, ref, devo.id);
            },
          ),
          const SizedBox(height: 8),
          Row(
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
                onPressed: () {
                  ref.read(noteDraftProvider.notifier).openNew(devo.id);
                  context.push('/devo/${devo.id}');
                },
                icon: Icon(
                  Icons.sticky_note_2_outlined,
                  color: notes.isEmpty
                      ? scheme.onSurface
                      : AppColors.notedMark(Theme.of(context).brightness),
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  devo.verseRef,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.sans,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.readingRef(Theme.of(context).brightness),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  frame.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: AppTheme.sans,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 4,
            children: [
              for (final slug in devo.tags)
                TextButton(
                  key: Key('hashtag-${devo.id}-$slug'),
                  onPressed: () =>
                      ref.read(browseFilterProvider.notifier).addTag(slug),
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
          if (notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final note in notes)
                    GestureDetector(
                      key: Key('postit-${note.id}'),
                      onTap: () {
                        ref.read(noteDraftProvider.notifier).openExisting(note);
                        context.push('/devo/${devo.id}');
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.noteFill,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.sticky_note_2,
                          size: 18,
                          color: AppColors.noteInk,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
