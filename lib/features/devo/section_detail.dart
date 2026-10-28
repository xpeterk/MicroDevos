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
import 'one_minute_section.dart';

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
            OneMinuteSection(devo: devo),
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
            const SizedBox(height: 8),
            for (var index = 0; index < sections.length; index++) ...[
              if (index > 0) const _FlowConnector(),
              KeyedSubtree(
                key: sections[index].id == widget.initialSectionId
                    ? _focusKey
                    : null,
                child: _SectionBlock(
                  devo: devo,
                  section: sections[index],
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
    return const SizedBox(
      key: Key('flow-connector'),
      height: 10,
    );
  }
}

class _SectionBlock extends ConsumerWidget {
  const _SectionBlock({
    required this.devo,
    required this.section,
    required this.expanded,
    required this.liked,
    required this.noted,
    required this.onToggle,
  });

  final Devo devo;
  final DevoSection section;
  final bool expanded;
  final bool liked;
  final bool noted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final caption =
        'Part ${section.position} · ${section.title} — ${devo.title}';
    final summary = section.summary.trim();
    final refText = section.verseRef.trim();
    final verseText = section.verseText.trim();
    final imageUrl = section.imageUrl?.trim() ?? '';

    final cardBg = isDark ? const Color(0xFF2C2926) : const Color(0xFFFFFFFF);
    final borderColor = isDark ? const Color(0xFF4A453E) : const Color(0xFFB9AE97);
    final cardShadow = isDark
        ? const BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.6),
            offset: Offset(0, 2),
            blurRadius: 8,
          )
        : const BoxShadow(
            color: Color.fromRGBO(70, 55, 25, 0.18),
            offset: Offset(0, 2),
            blurRadius: 8,
          );
    final titleColor = isDark ? const Color(0xFFF6F0E2) : const Color(0xFF1F1B16);
    final chevronColor = isDark ? const Color(0xFFC4BBA8) : const Color(0xFF6B5F4B);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [cardShadow],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (expanded && imageUrl.isNotEmpty)
                _SectionStrip(
                  id: section.id,
                  url: imageUrl,
                  alt: section.imageAlt?.trim() ?? '',
                ),
              InkWell(
                key: Key('section-bullet-${section.id}'),
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plainSectionTitle(section.title),
                              style: TextStyle(
                                fontFamily: AppTheme.sans,
                                fontSize: 15,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                                color: titleColor,
                              ),
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
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: chevronColor,
                      ),
                    ],
                  ),
                ),
              ),
            if (expanded) ...[
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DevoBody(markdown: section.body),
                    if (verseText.isNotEmpty || refText.isNotEmpty)
                      _SectionVerseBox(
                        sectionId: section.id,
                        text: verseText,
                        reference: refText,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
}

class _SectionVerseBox extends StatelessWidget {
  const _SectionVerseBox({
    required this.sectionId,
    required this.text,
    required this.reference,
  });

  final String sectionId;
  final String text;
  final String reference;

  @override
  Widget build(BuildContext context) {
    final hasText = text.isNotEmpty;
    final hasRef = reference.isNotEmpty;
    if (!hasText && !hasRef) return const SizedBox.shrink();

    final formattedRef =
        reference.startsWith('—') || reference.startsWith('\u2014')
            ? reference
            : '— $reference';

    return Container(
      key: Key('section-verse-box-$sectionId'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6EFDF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DDC4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasText)
            Text(
              text,
              style: const TextStyle(
                fontFamily: AppTheme.serif,
                fontStyle: FontStyle.italic,
                fontSize: 16,
                height: 1.45,
                color: Color(0xFF2C241E),
              ),
            ),
          if (hasText && hasRef) const SizedBox(height: 10),
          if (hasRef)
            Text(
              formattedRef,
              key: Key('section-ref-$sectionId'),
              style: const TextStyle(
                fontFamily: AppTheme.sans,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A6A2F),
              ),
            ),
        ],
      ),
    );
  }
}

/// Half-height section banner, about 1200×315, cover-cropped to the card width.
const sectionBannerAspect = 1200 / 315;

class _SectionStrip extends StatefulWidget {
  const _SectionStrip({required this.id, required this.url, required this.alt});

  final String id;
  final String url;
  final String alt;

  @override
  State<_SectionStrip> createState() => _SectionStripState();
}

class _SectionStripState extends State<_SectionStrip> {
  var _failed = false;

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    final label = widget.alt.isEmpty ? null : widget.alt;
    final asset = widget.url.startsWith('assets/');
    final image = asset
        ? Image.asset(
            widget.url,
            fit: BoxFit.cover,
            width: double.infinity,
            semanticLabel: label,
            errorBuilder: _hide,
          )
        : Image.network(
            widget.url,
            fit: BoxFit.cover,
            width: double.infinity,
            semanticLabel: label,
            errorBuilder: _hide,
          );
    return AspectRatio(
      key: Key('section-strip-${widget.id}'),
      aspectRatio: sectionBannerAspect,
      child: image,
    );
  }

  Widget _hide(BuildContext context, Object error, StackTrace? stack) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_failed) setState(() => _failed = true);
    });
    return const SizedBox.shrink();
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
