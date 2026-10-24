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
            SizedBox(key: _listKey),
            if (devoTeaser(devo) != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  devoTeaser(devo)!,
                  key: const Key('devo-teaser'),
                  style: TextStyle(
                    fontFamily: AppTheme.serif,
                    fontSize: 18,
                    height: 1.4,
                    color: AppColors.summaryInk(Theme.of(context).brightness),
                  ),
                ),
              ),
            for (var index = 0; index < sections.length; index++) ...[
              if (index > 0) const _FlowConnector(),
              KeyedSubtree(
                key: sections[index].id == widget.initialSectionId
                    ? _focusKey
                    : null,
                child: _SectionBlock(
                  devo: devo,
                  section: sections[index],
                  count: sections.length,
                  expanded: _expanded.contains(sections[index].position),
                  liked: liked.any(
                    (item) => item.sectionId == sections[index].id,
                  ),
                  noted: notes.any(
                    (note) => note.sectionId == sections[index].id,
                  ),
                  onToggle: () => _toggle(sections[index].position),
                ),
              ),
            ],
            if (devoPrayerLine(devo.prayer) != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Text(
                  devoPrayerLine(devo.prayer)!,
                  key: const Key('devo-prayer'),
                  style: TextStyle(
                    fontFamily: AppTheme.serif,
                    fontSize: 17,
                    height: 1.4,
                    color: scheme.onSurface,
                  ),
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
                      backgroundColor: AppColors.lessonNavy,
                      foregroundColor: AppColors.lessonGold,
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
                  backgroundColor: AppColors.body,
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
                    ? AppColors.lessonNavy
                    : const Color(0xFFD9D0C4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}

class _FlowConnector extends StatelessWidget {
  const _FlowConnector();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      key: const Key('flow-connector'),
      height: 18,
      child: Padding(
        padding: const EdgeInsets.only(left: 28),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 2,
            height: 18,
            child: ColoredBox(
              color: dark ? const Color(0xFF3A342E) : const Color(0xFFD9D0C4),
            ),
          ),
        ),
      ),
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
    final brightness = Theme.of(context).brightness;
    final caption =
        'Part ${section.position} · ${section.title} — ${devo.title}';
    final summary = section.summary.trim();
    final refText = section.verseRef.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              key: Key('section-bullet-${section.id}'),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  plainSectionTitle(section.title),
                                  style: TextStyle(
                                    fontFamily: AppTheme.sans,
                                    fontSize: 16,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '${section.minutes} min',
                                  style: TextStyle(
                                    fontFamily: AppTheme.sans,
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Icon(
                                expanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                          if (summary.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              summary,
                              style: TextStyle(
                                fontFamily: AppTheme.sans,
                                fontSize: 15,
                                height: 1.35,
                                color: AppColors.summaryInk(brightness),
                              ),
                            ),
                          ],
                          if (refText.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              refText,
                              key: Key('section-ref-${section.id}'),
                              style: TextStyle(
                                fontFamily: AppTheme.sans,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.readingRef(brightness),
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
            if (expanded) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: StyleBanner(
                  devo: devo,
                  total: count,
                  hero: false,
                  bannerKey: 'section-banner-${section.id}',
                  pillLabel: '',
                  titleOverride: plainSectionTitle(section.title),
                  summaryOverride: section.summary,
                  tagLabel: section.tags.isEmpty ? null : section.tags.first,
                ),
              ),
              if (section.verseText.trim().isNotEmpty || refText.isNotEmpty)
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
                              backgroundColor: AppColors.chipFill,
                              side: BorderSide.none,
                              labelStyle: const TextStyle(
                                fontFamily: AppTheme.sans,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppColors.chipInk,
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
                        color: noted
                            ? AppColors.notedMark(brightness)
                            : scheme.onSurface,
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

/// Drops a leading number or a Problem / Action / Result label from a title.
String plainSectionTitle(String title) {
  final original = title.trim();
  var text = original.replaceFirst(RegExp(r'^\d+\s*[.·•)\-–—]\s*'), '');
  text = text.replaceFirst(
    RegExp(r'^(?:problem|action|result)\s*[·:•\-–—]\s*', caseSensitive: false),
    '',
  );
  final plain = text.trim();
  return plain.isEmpty ? original : plain;
}

/// Teaser under the title. Hidden when it repeats the banner sentence.
String? devoTeaser(Devo devo) {
  final teaser = devo.teaser.trim();
  if (teaser.isEmpty) return null;
  final banner = bannerSummary(devo);
  if (banner.isNotEmpty && teaser == banner) return null;
  return teaser;
}

/// Prayer line. A leading Today label is dropped, and the line starts with 🙏.
String? devoPrayerLine(String prayer) {
  var text = prayer.trim();
  if (text.isEmpty) return null;
  text = text.replaceFirst(RegExp(r'^🙏\s*'), '');
  text = text.replaceAll('**', '');
  text = text.replaceFirst(RegExp(r'^Today:\s*', caseSensitive: false), '');
  text = text.trim();
  if (text.isEmpty) return null;
  return '🙏 $text';
}
