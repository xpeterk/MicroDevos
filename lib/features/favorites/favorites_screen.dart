import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/edition_date_format.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/devo.dart';
import '../../domain/models/devo_note.dart';
import '../../domain/models/devo_section.dart';
import '../../domain/models/generated_devo.dart';
import '../../shared/widgets/reading_widgets.dart';
import '../browse/banner.dart';
import '../browse/browse_state.dart';
import '../browse/feed_snack.dart';
import '../personalize/personalize_state.dart';

enum SavedItemKind { devo, mine, section }

class SavedItem {
  const SavedItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.verseRef,
    required this.editionDate,
    required this.colors,
    required this.route,
    required this.onUnsave,
    this.rawTags = const [],
    this.sectionId,
  });

  final String id;
  final SavedItemKind kind;
  final String title;
  final String subtitle;
  final String tag;
  final String verseRef;
  final DateTime editionDate;
  final List<Color> colors;
  final String route;
  final Future<void> Function() onUnsave;
  final List<String> rawTags;
  final String? sectionId;
}

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  var _grid = true;
  String? _tag;

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    final notes = ref.watch(notesProvider);
    final mine = ref.watch(mineProvider);
    final segment = ref.watch(savedSegmentProvider);

    if (favorites.isLoading || notes.isLoading || mine.isLoading) {
      return const LoadingView();
    }
    if (favorites.hasError) {
      return StatusMessage(
        title: 'Saved devotions could not be opened',
        body: 'They are stored on this phone. Try again.',
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(favoritesProvider),
      );
    }

    final favoriteIds = (favorites.value ?? const <String>{}).toList()..sort();
    final noteList = notes.value ?? const <DevoNote>[];
    final mineList = mine.value ?? const <GeneratedDevo>[];
    final sectionFavs =
        ref.watch(sectionFavoritesProvider).value ?? const <SectionFavorite>[];

    final mineIdSet = {for (final m in mineList) m.id};

    final allItems = <SavedItem>[];

    // 1. Personalized devotions
    for (final m in mineList) {
      final full = m.toDevo();
      final colors =
          bannerPalettes[m.styleKey.hashCode.abs() % bannerPalettes.length];
      allItems.add(
        SavedItem(
          id: m.id,
          kind: SavedItemKind.mine,
          title: m.title,
          subtitle: full.hook.isNotEmpty ? full.hook : m.promptLabel,
          tag: 'FOR YOU',
          verseRef: full.verseRef,
          editionDate: full.editionDate,
          colors: colors,
          route: '/devo/${m.id}',
          onUnsave: () => ref.read(mineProvider.notifier).remove(m.id),
        ),
      );
    }

    // 2. Regular favorited devotions (skip if already in mine)
    for (final id in favoriteIds) {
      if (mineIdSet.contains(id)) continue;
      final devo = ref.watch(devoByIdProvider(id)).asData?.value;
      if (devo == null) continue;
      final colors = paletteFor(devo);
      final primaryTag = devo.tags.isNotEmpty ? devo.tags.first.toUpperCase() : 'DEVOTION';
      allItems.add(
        SavedItem(
          id: devo.id,
          kind: SavedItemKind.devo,
          title: devo.title,
          subtitle: devo.hook,
          tag: primaryTag,
          verseRef: devo.verseRef,
          editionDate: devo.editionDate,
          colors: colors,
          route: '/devo/${devo.id}',
          onUnsave: () => ref.read(favoritesProvider.notifier).toggle(devo.id),
          rawTags: devo.tags,
        ),
      );
    }

    // 3. Saved sections
    for (final saved in sectionFavs) {
      final parent =
          ref.watch(devoByIdProvider(saved.devoId)).asData?.value;
      final section = parent?.sections
          .where((item) => item.id == saved.sectionId)
          .firstOrNull;
      final title = section?.title ?? 'Saved section';
      final part = section == null
          ? 'Part of ${parent?.title ?? 'a devo'}'
          : 'Part ${section.position} of ${parent?.title ?? 'a devo'}';
      final colors = parent != null
          ? paletteFor(parent)
          : const [Color(0xFFCDB98A), Color(0xFF9A8454)];

      allItems.add(
        SavedItem(
          id: saved.sectionId,
          kind: SavedItemKind.section,
          title: title,
          subtitle: part,
          tag: 'SECTION',
          verseRef: section?.verseRef ?? '',
          editionDate: parent?.editionDate ?? DateTime.now(),
          colors: colors,
          route: '/devo/${saved.devoId}?section=${saved.sectionId}',
          onUnsave: () => ref
              .read(sectionFavoritesProvider.notifier)
              .toggle(saved.devoId, saved.sectionId),
          sectionId: saved.sectionId,
        ),
      );
    }

    // Sort items by date descending
    allItems.sort((a, b) => b.editionDate.compareTo(a.editionDate));

    // Tags for filtering
    final hasForYou = allItems.any((item) => item.kind == SavedItemKind.mine);
    final hasSections =
        allItems.any((item) => item.kind == SavedItemKind.section);
    final devoTags = <String>{
      for (final item in allItems)
        if (item.kind == SavedItemKind.devo) ...item.rawTags,
    };
    final catalog = ref.watch(tagCatalogProvider).asData?.value;

    final shown = _tag == null
        ? allItems
        : allItems.where((item) {
            if (_tag == 'for-you') return item.kind == SavedItemKind.mine;
            if (_tag == 'sections') return item.kind == SavedItemKind.section;
            return item.rawTags.contains(_tag);
          }).toList();

    final totalCount = allItems.length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SegmentSwitch(segment: segment),
                const SizedBox(height: 16),
                if (segment == SavedSegment.liked) ...[
                  Text(
                    totalCount == 0
                        ? 'Nothing saved yet'
                        : '$totalCount liked ${totalCount == 1 ? 'devo' : 'devos'}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: AppTheme.sans,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    totalCount == 0
                        ? 'Nothing saved yet. Double-tap or ♥ any devo to keep it here.'
                        : 'Double-tap or ♥ any devo to keep it here.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: AppTheme.sans,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        key: const Key('saved-grid'),
                        tooltip: 'Grid',
                        onPressed: () => setState(() => _grid = true),
                        icon: Icon(
                          Icons.grid_view,
                          color: _grid
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      IconButton(
                        key: const Key('saved-list'),
                        tooltip: 'List',
                        onPressed: () => setState(() => _grid = false),
                        icon: Icon(
                          Icons.reorder,
                          color: !_grid
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        FilterChip(
                          key: const Key('saved-tag-all'),
                          label: const Text('All'),
                          selected: _tag == null,
                          onSelected: (_) => setState(() => _tag = null),
                        ),
                        if (hasForYou)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: FilterChip(
                              key: const Key('saved-tag-for-you'),
                              label: const Text('For You'),
                              selected: _tag == 'for-you',
                              onSelected: (_) =>
                                  setState(() => _tag = _tag == 'for-you' ? null : 'for-you'),
                            ),
                          ),
                        if (hasSections)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: FilterChip(
                              key: const Key('saved-tag-sections'),
                              label: const Text('Sections'),
                              selected: _tag == 'sections',
                              onSelected: (_) =>
                                  setState(() => _tag = _tag == 'sections' ? null : 'sections'),
                            ),
                          ),
                        for (final slug in devoTags)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: FilterChip(
                              key: Key('saved-tag-$slug'),
                              label: Text(
                                catalog?.tagBySlug(slug)?.label ?? slug,
                              ),
                              selected: _tag == slug,
                              onSelected: (_) =>
                                  setState(() => _tag = _tag == slug ? null : slug),
                            ),
                          ),
                      ],
                    ),
                  ),
                ] else if (segment == SavedSegment.notes) ...[
                  Text(
                    noteList.isEmpty
                        ? 'No notes yet'
                        : '${_groups(noteList).length} ${_groups(noteList).length == 1 ? 'devo' : 'devos'} with notes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: AppTheme.sans,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    noteList.isEmpty
                        ? 'Tap the post-it on a devotion. Notes stay private.'
                        : 'Newest first. Tap a note to open it on its passage.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: AppTheme.sans,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (segment == SavedSegment.liked && shown.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Center(
                child: Text(
                  totalCount == 0
                      ? 'No devotions saved yet'
                      : 'No saved items match this filter',
                  style: TextStyle(
                    fontFamily: AppTheme.sans,
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
        else if (segment == SavedSegment.liked && _grid)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _SavedGridCard(item: shown[index]),
                childCount: shown.length,
              ),
            ),
          )
        else if (segment == SavedSegment.liked)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _SavedListRow(item: shown[index]),
                childCount: shown.length,
              ),
            ),
          )
        else if (segment == SavedSegment.notes)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final group = _groups(noteList)[index];
                return _NoteGroupCard(notes: group);
              }, childCount: _groups(noteList).length),
            ),
          ),
      ],
    );
  }
}

class _SegmentSwitch extends ConsumerWidget {
  const _SegmentSwitch({required this.segment});

  final SavedSegment segment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.nightRaised
            : AppColors.paperDeep,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          _SegmentButton(
            key: const Key('saved-liked'),
            label: 'Favorites',
            icon: Icons.favorite,
            selected: segment == SavedSegment.liked,
            onTap: () => ref
                .read(savedSegmentProvider.notifier)
                .show(SavedSegment.liked),
          ),
          _SegmentButton(
            key: const Key('saved-notes'),
            label: 'Notes',
            icon: Icons.sticky_note_2_outlined,
            selected: segment == SavedSegment.notes,
            onTap: () => ref
                .read(savedSegmentProvider.notifier)
                .show(SavedSegment.notes),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: selected ? scheme.surfaceContainerLowest : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTheme.sans,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedGridCard extends StatelessWidget {
  const _SavedGridCard({required this.item});

  final SavedItem item;

  @override
  Widget build(BuildContext context) {
    Widget card = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(item.route),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: item.colors,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 10,
                right: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.tag,
                        style: const TextStyle(
                          fontFamily: AppTheme.sans,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      key: Key('unsave-${item.id}'),
                      tooltip: 'Remove from Saved',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.favorite,
                        color: Color(0xFFE53935),
                        size: 20,
                      ),
                      onPressed: () async {
                        await item.onUnsave();
                        if (context.mounted) {
                          showFeedSnack(context, 'Removed from Saved');
                        }
                      },
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.serif,
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      key: item.sectionId != null
                          ? Key('saved-section-parent-${item.sectionId}')
                          : null,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.sans,
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 12,
                      ),
                    ),
                    if (item.verseRef.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.verseRef,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.sans,
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (item.sectionId != null) {
      return KeyedSubtree(
        key: Key('saved-section-${item.sectionId}'),
        child: card,
      );
    }
    return card;
  }
}

class _SavedListRow extends StatelessWidget {
  const _SavedListRow({required this.item});

  final SavedItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final IconData leadingIcon;
    switch (item.kind) {
      case SavedItemKind.mine:
        leadingIcon = Icons.auto_awesome;
        break;
      case SavedItemKind.section:
        leadingIcon = Icons.bookmark;
        break;
      case SavedItemKind.devo:
        leadingIcon = Icons.menu_book;
        break;
    }

    Widget row = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.nightRaised : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push(item.route),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: item.colors,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        leadingIcon,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.tag,
                        style: TextStyle(
                          fontFamily: AppTheme.sans,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.serif,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        key: item.sectionId != null
                            ? Key('saved-section-parent-${item.sectionId}')
                            : null,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.sans,
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: Key('unsave-list-${item.id}'),
                  tooltip: 'Remove from Saved',
                  icon: const Icon(
                    Icons.favorite,
                    color: Color(0xFFE53935),
                    size: 22,
                  ),
                  onPressed: () async {
                    await item.onUnsave();
                    if (context.mounted) {
                      showFeedSnack(context, 'Removed from Saved');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (item.sectionId != null) {
      return KeyedSubtree(
        key: Key('saved-section-${item.sectionId}'),
        child: row,
      );
    }
    return row;
  }
}

class _NoteGroupCard extends ConsumerWidget {
  const _NoteGroupCard({required this.notes});

  final List<DevoNote> notes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = notes.first.targetId;
    final devo = ref.watch(devoByIdProvider(target)).asData?.value;
    final scheme = Theme.of(context).colorScheme;
    final when = devo == null
        ? ''
        : formatEditionDate(devo.editionDate, 'EEE, MMM d').toUpperCase();
    final countLabel = notes.length == 1 ? '1 NOTE' : '${notes.length} NOTES';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (devo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56,
                height: 56,
                child: DevoBanner(devo: devo, showTitle: false),
              ),
            )
          else
            const SizedBox(width: 56, height: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$when · $countLabel',
                  style: TextStyle(
                    fontFamily: AppTheme.sans,
                    fontSize: 11,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
                Text(
                  devo?.title ?? 'Devotion',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: AppTheme.serif,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final note in notes) ...[
                  const SizedBox(height: 8),
                  if (note.sectionId != null)
                    Text(
                      _sectionNoteLabel(devo, note),
                      key: Key('saved-note-section-${note.id}'),
                      style: TextStyle(
                        fontFamily: AppTheme.sans,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    )
                  else if (note.hasAnchor)
                    Text(
                      '“${note.anchorText}”',
                      style: TextStyle(
                        fontFamily: AppTheme.serif,
                        fontStyle: FontStyle.italic,
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  else
                    Text(
                      'Note on the whole devo',
                      style: TextStyle(
                        fontFamily: AppTheme.sans,
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    key: Key('saved-note-${note.id}'),
                    onTap: () => _open(ref, context, note),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.noteFill,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        note.body,
                        style: const TextStyle(
                          fontFamily: AppTheme.serif,
                          fontSize: 15,
                          color: AppColors.body,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _open(WidgetRef ref, BuildContext context, DevoNote note) {
    ref.read(noteDraftProvider.notifier).openExisting(note);
    final devoId = note.devoId;
    if (devoId == null) return;
    final section = note.sectionId;
    if (section == null) {
      context.push('/devo/$devoId');
    } else {
      context.push('/devo/$devoId?section=$section');
    }
  }
}

String _sectionNoteLabel(Devo? devo, DevoNote note) {
  final section = devo?.sections
      .where((item) => item.id == note.sectionId)
      .firstOrNull;
  if (section == null) {
    return 'Part of ${devo?.title ?? 'this devo'}';
  }
  return 'Part ${section.position} of ${devo?.title ?? 'this devo'}';
}

List<List<DevoNote>> _groups(List<DevoNote> notes) {
  final ordered = [...notes]
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  final groups = <String, List<DevoNote>>{};
  final order = <String>[];
  for (final note in ordered) {
    final key = note.targetId;
    if (!groups.containsKey(key)) order.add(key);
    groups.putIfAbsent(key, () => []).add(note);
  }
  return [for (final key in order) groups[key]!];
}
