import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/devo.dart';
import '../../domain/models/devo_section.dart';
import '../../shared/widgets/reading_widgets.dart';
import '../browse/browse_state.dart';
import '../browse/note_pane.dart';
import '../browse/style_banner.dart';

/// Summary of a devotion that has sections. Bullets expand in place.
class SectionDetail extends ConsumerStatefulWidget {
  const SectionDetail({
    required this.devo,
    required this.dayCount,
    this.initialSectionId,
    super.key,
  });

  final Devo devo;
  final int dayCount;
  final String? initialSectionId;

  @override
  ConsumerState<SectionDetail> createState() => _SectionDetailState();
}

class _SectionDetailState extends ConsumerState<SectionDetail> {
  final _scroll = ScrollController();
  final _listKey = GlobalKey();
  final _focusKey = GlobalKey();
  final _expanded = <int>{};
  var _showSummary = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    final initial = widget.initialSectionId;
    if (initial != null) {
      for (final section in widget.devo.sections) {
        if (section.id == initial) _expanded.add(section.position);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _focusKey.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(target, alignment: 0.15);
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scroll.hasClients && _scroll.offset > 140;
    if (show != _showSummary) setState(() => _showSummary = show);
  }

  void _toggle(int position) {
    setState(() {
      if (_expanded.contains(position)) {
        _expanded.remove(position);
      } else {
        _expanded.add(position);
      }
    });
  }

  Future<void> _jumpToSummary() async {
    final target = _listKey.currentContext;
    if (target == null) {
      if (_scroll.hasClients) {
        await _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: 0.02,
    );
  }

  @override
  Widget build(BuildContext context) {
    final devo = widget.devo;
    final sections = [...devo.sections]
      ..sort((a, b) => a.position.compareTo(b.position));
    final minutes = sections.fold<int>(
      0,
      (sum, section) => sum + section.minutes,
    );
    final draft = ref.watch(noteDraftProvider);
    final openDraft = draft != null && draft.devoId == devo.id ? draft : null;
    final noting = openDraft != null;
    final scheme = Theme.of(context).colorScheme;
    final liked =
        ref.watch(sectionFavoritesProvider).value ?? const <SectionFavorite>[];
    final notes = ref.watch(notesProvider).value ?? const [];

    return Stack(
      children: [
        ListView(
          key: const Key('section-detail-scroll'),
          controller: _scroll,
          padding: EdgeInsets.only(bottom: noting ? 280 : 108),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: StyleBanner(
                devo: devo,
                total: widget.dayCount,
                hero: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Text(
                devo.title,
                key: const Key('section-devo-title'),
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 32,
                  height: 1.05,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                '${sections.length} ${sections.length == 1 ? 'section' : 'sections'} · $minutes min · ${devo.verseRef}',
                key: const Key('section-meta'),
                style: TextStyle(
                  fontFamily: AppTheme.sans,
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              key: _listKey,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
              child: Text(
                'IN THIS DEVO',
                style: TextStyle(
                  fontFamily: AppTheme.sans,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final section in sections)
              KeyedSubtree(
                key: section.id == widget.initialSectionId ? _focusKey : null,
                child: _SectionBlock(
                  devo: devo,
                  section: section,
                  count: sections.length,
                  expanded: _expanded.contains(section.position),
                  liked: liked.any((item) => item.sectionId == section.id),
                  noted: notes.any((note) => note.sectionId == section.id),
                  onToggle: () => _toggle(section.position),
                ),
              ),
          ],
        ),
        if (_showSummary && !noting)
          Positioned(
            key: const Key('summary-bar'),
            top: 8,
            left: 16,
            right: 16,
            child: Column(
              children: [
                _ProgressBar(count: sections.length, filled: _expanded.length),
                const SizedBox(height: 8),
                Center(
                  child: FilledButton.icon(
                    key: const Key('jump-summary'),
                    onPressed: _jumpToSummary,
                    icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                    label: const Text('Summary'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF241B4B),
                      foregroundColor: const Color(0xFFF2C94C),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(
                        fontFamily: AppTheme.sans,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ],
            ),
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
            child: Center(
              child: FilledButton.icon(
                key: const Key('back-to-feed'),
                onPressed: () => context.pop(),
                icon: const Icon(Icons.keyboard_arrow_down),
                label: const Text('Back to feed'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2A2420),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(
                    fontFamily: AppTheme.sans,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.count, required this.filled});

  final int count;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final total = count <= 0 ? 1 : count;
    return Row(
      key: const Key('section-progress'),
      children: [
        for (var index = 0; index < total; index++)
          Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(left: index == 0 ? 0 : 4),
              decoration: BoxDecoration(
                color: index < filled
                    ? const Color(0xFF241B4B)
                    : const Color(0xFFD9D0C4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionBlock extends ConsumerWidget {
  const _SectionBlock({
    required this.devo,
    required this.section,
    required this.count,
    required this.expanded,
    required this.liked,
    required this.noted,
    required this.onToggle,
  });

  final Devo devo;
  final DevoSection section;
  final int count;
  final bool expanded;
  final bool liked;
  final bool noted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final caption =
        'Part ${section.position} · ${section.title} — ${devo.title}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: const Color(0xFFFFFCF8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE4D8C8)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              key: Key('section-bullet-${section.id}'),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFF241B4B),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${section.position}',
                        style: const TextStyle(
                          fontFamily: AppTheme.sans,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.title,
                            style: const TextStyle(
                              fontFamily: AppTheme.sans,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2A2420),
                            ),
                          ),
                          if (section.summary.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              section.summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTheme.sans,
                                fontSize: 14,
                                height: 1.3,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${section.minutes} min',
                      style: TextStyle(
                        fontFamily: AppTheme.sans,
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: StyleBanner(
                  devo: devo,
                  total: count,
                  hero: false,
                  bannerKey: 'section-banner-${section.id}',
                  pillLabel: 'PART ${section.position} OF $count',
                  titleOverride: section.title,
                  summaryOverride: section.summary,
                  tagLabel: section.tags.isEmpty ? null : section.tags.first,
                ),
              ),
              if (section.verseText.trim().isNotEmpty ||
                  section.verseRef.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: VerseCard(
                    text: section.verseText,
                    reference: section.verseRef,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final slug in section.tags)
                            Chip(
                              key: Key('section-tag-${section.id}-$slug'),
                              label: Text(slug.toUpperCase()),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: const Color(0xFFF3E6C8),
                              labelStyle: const TextStyle(
                                fontFamily: AppTheme.sans,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: Key('section-heart-${section.id}'),
                      tooltip: liked ? 'Remove from saved' : 'Save section',
                      onPressed: () => ref
                          .read(sectionFavoritesProvider.notifier)
                          .toggle(devo.id, section.id),
                      icon: Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        color: liked ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                    IconButton(
                      key: Key('section-note-${section.id}'),
                      tooltip: 'Note',
                      onPressed: () => ref
                          .read(noteDraftProvider.notifier)
                          .openNew(
                            devo.id,
                            sectionId: section.id,
                            caption: caption,
                          ),
                      icon: Icon(
                        Icons.sticky_note_2_outlined,
                        color: noted ? AppColors.line : scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: DevoBody(markdown: section.body),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
