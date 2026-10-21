import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/edition_date_format.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/devo.dart';
import '../../domain/models/devo_note.dart';
import '../../domain/models/devo_section.dart';
import '../../shared/widgets/reading_widgets.dart';
import '../browse/banner.dart';
import '../browse/browse_state.dart';

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
    final segment = ref.watch(savedSegmentProvider);
    if (favorites.isLoading || notes.isLoading) {
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
    final ids = (favorites.value ?? const <String>{}).toList()..sort();
    final noteList = notes.value ?? const <DevoNote>[];
    final sectionFavs =
        ref.watch(sectionFavoritesProvider).value ?? const <SectionFavorite>[];
    final likedDevos =
        [for (final id in ids) ?ref.watch(devoByIdProvider(id)).asData?.value]
          ..sort((a, b) {
            final byDate = b.editionDate.compareTo(a.editionDate);
            if (byDate != 0) return byDate;
            return a.position.compareTo(b.position);
          });
    final shown = _tag == null
        ? likedDevos
        : likedDevos.where((devo) => devo.tags.contains(_tag)).toList();
    final tagSlugs = <String>{for (final devo in likedDevos) ...devo.tags};
    final catalog = ref.watch(tagCatalogProvider).asData?.value;

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
                    ids.isEmpty
                        ? 'Nothing saved yet'
                        : '${ids.length} liked ${ids.length == 1 ? 'devo' : 'devos'}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: AppTheme.sans,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ids.isEmpty
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
                        for (final slug in tagSlugs)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: FilterChip(
                              key: Key('saved-tag-$slug'),
                              label: Text(
                                catalog?.tagBySlug(slug)?.label ?? slug,
                              ),
                              selected: _tag == slug,
                              onSelected: (_) => setState(() => _tag = slug),
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
        if (segment == SavedSegment.liked && sectionFavs.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final saved = sectionFavs[index];
                final parent = ref
                    .watch(devoByIdProvider(saved.devoId))
                    .asData
                    ?.value;
                final section = parent?.sections
                    .where((item) => item.id == saved.sectionId)
                    .firstOrNull;
                return _SavedSectionRow(
                  devo: parent,
                  section: section,
                  sectionId: saved.sectionId,
                  devoId: saved.devoId,
                );
              }, childCount: sectionFavs.length),
            ),
          ),
        if (segment == SavedSegment.liked && shown.isEmpty)
          const SliverToBoxAdapter(child: SizedBox(height: 24))
        else if (segment == SavedSegment.liked && _grid)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _LikedTile(devo: shown[index]),
                childCount: shown.length,
              ),
            ),
          )
        else if (segment == SavedSegment.liked)
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final devo = shown[index];
              return ListTile(
                onTap: () => context.push('/devo/${devo.id}'),
                title: Text(devo.title),
                subtitle: Text(devo.hook, maxLines: 2),
              );
            }, childCount: shown.length),
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

class _LikedTile extends StatelessWidget {
  const _LikedTile({required this.devo});

  final Devo devo;

  @override
  Widget build(BuildContext context) {
    final colors = paletteFor(devo);
    return GestureDetector(
      onTap: () => context.push('/devo/${devo.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                top: 8,
                left: 8,
                child: Icon(Icons.favorite, color: Colors.white, size: 14),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.sell_outlined,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 14,
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  devo.title,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.serif,
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                        color: const Color(0xFFF8E7A2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        note.body,
                        style: const TextStyle(
                          fontFamily: AppTheme.serif,
                          fontSize: 15,
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

class _SavedSectionRow extends StatelessWidget {
  const _SavedSectionRow({
    required this.devo,
    required this.section,
    required this.sectionId,
    required this.devoId,
  });

  final Devo? devo;
  final DevoSection? section;
  final String sectionId;
  final String devoId;

  @override
  Widget build(BuildContext context) {
    final title = section?.title ?? 'Saved section';
    final part = section == null
        ? 'Part of ${devo?.title ?? 'a devo'}'
        : 'Part ${section!.position} of ${devo?.title ?? 'a devo'}';
    return ListTile(
      key: Key('saved-section-$sectionId'),
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      onTap: () => context.push('/devo/$devoId?section=$sectionId'),
      leading: Container(
        width: 56,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF2C94C),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: AppTheme.sans,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        part,
        key: Key('saved-section-parent-$sectionId'),
        style: const TextStyle(fontFamily: AppTheme.sans, fontSize: 13),
      ),
      trailing: section == null || section!.verseRef.isEmpty
          ? null
          : Text(
              section!.verseRef,
              style: const TextStyle(fontFamily: AppTheme.sans, fontSize: 12),
            ),
    );
  }
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
