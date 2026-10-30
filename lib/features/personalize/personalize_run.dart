import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/generated_devo.dart';
import '../../domain/personalize/personalize_engine.dart';
import '../../domain/personalize/style_catalog.dart';
import '../../shared/widgets/reading_widgets.dart';
import '../browse/banner.dart';
import '../browse/feed_snack.dart';
import '../devo/one_minute_section.dart';
import '../devo/section_detail.dart';
import 'personalize_state.dart';

class PersonalizeWritingScreen extends ConsumerWidget {
  const PersonalizeWritingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(personalizeRunProvider);
    final request = run.request;
    final cap = ref.watch(personalizeEngineProvider).capSnapshot();
    final style = request == null ? null : styleByKey(request.styleKey);
    final contextBits = [
      if (request?.ageRange != null) request!.ageRange!,
      ...?request?.lifeSituations,
    ];

    if (run.blockedReason != null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  run.blockedReason!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'The weekly cap and the monthly spend ceiling are not decided yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: AppTheme.sans),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () =>
                      ref.read(personalizeRunProvider.notifier).dismiss(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      key: const Key('personalize-writing'),
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE4DDD2), width: 14),
                ),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFB7C9BC), Color(0xFF7E9A88)],
                    ),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Writing your devo...',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Usually under 20 seconds. You can leave this screen. A saved devotion stays on this phone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.sans,
                  fontSize: 15,
                  height: 1.35,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (request != null && request.promptLabel.isNotEmpty)
                    _InfoChip(label: request.promptLabel, filled: true),
                  if (style != null)
                    _InfoChip(
                      label: style.isClassic
                          ? style.label
                          : '${style.label} style',
                    ),
                  if (contextBits.isNotEmpty)
                    _InfoChip(label: contextBits.join(' · ')),
                ],
              ),
              const SizedBox(height: 22),
              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(6)),
                child: LinearProgressIndicator(
                  value: 0.62,
                  minHeight: 6,
                  backgroundColor: Color(0xFFE4DDD2),
                  color: AppColors.olive,
                ),
              ),
              const Spacer(),
              _CapCard(cap: cap),
            ],
          ),
        ),
      ),
    );
  }
}

class PersonalizeResult extends ConsumerStatefulWidget {
  const PersonalizeResult({super.key});

  @override
  ConsumerState<PersonalizeResult> createState() => _PersonalizeResultState();
}

class _PersonalizeResultState extends ConsumerState<PersonalizeResult> {
  var _liked = false;
  final _expandedSections = <int>{};

  void _toggleSection(int position) {
    setState(() {
      if (_expandedSections.contains(position)) {
        _expandedSections.remove(position);
      } else {
        _expandedSections.add(position);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final devo = ref.watch(personalizeRunProvider).devo;
    if (devo == null) return const SizedBox.shrink();
    final fullDevo = devo.toDevo();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final banner = devo.isClassic
        ? 'Personalized · Adapted from ${devo.styleLabel} · public domain'
        : 'Personalized · ${devo.styleLabel} style · “${devo.promptLabel}”';

    final sections = fullDevo.sections;
    final minutes = sections.fold<int>(0, (sum, s) => sum + s.minutes);

    final cardBg = isDark ? const Color(0xFF2C2926) : const Color(0xFFFFFFFF);
    final cardBorder = isDark ? const Color(0xFF4A453E) : const Color(0xFFB9AE97);
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

    return ListView(
      key: const Key('personalize-result'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
          child: Row(
            children: [
              const _Avatar(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personalized · today',
                      style: TextStyle(
                        fontFamily: AppTheme.sans,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      'For You',
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
                tooltip: 'More',
                onPressed: () {},
                icon: const Icon(Icons.more_horiz),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Container(
            key: const Key('personalize-banner-chip'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.oliveSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: AppColors.olive,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    banner,
                    style: const TextStyle(
                      fontFamily: AppTheme.sans,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.olive,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 112,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: bannerPalettes[
                          minePaletteOrder[
                            devo.styleKey.hashCode % minePaletteOrder.length
                          ]
                        ],
                      ),
                    ),
                  ),
                  const Positioned(right: -20, top: 10, child: _Bubble(size: 120)),
                  const Positioned(
                    left: -30,
                    bottom: -10,
                    child: _Bubble(size: 140),
                  ),
                  Positioned(
                    right: 24,
                    top: 28,
                    child: Icon(
                      Icons.sell_outlined,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  const Positioned(top: 12, right: 12, child: _ImagePill()),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 16,
                    child: Text(
                      devo.title,
                      style: const TextStyle(
                        fontFamily: AppTheme.serif,
                        fontSize: 26,
                        height: 1.05,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${sections.length} ${sections.length == 1 ? 'section' : 'sections'} · $minutes min · ${fullDevo.verseRef}',
                  style: TextStyle(
                    fontFamily: AppTheme.sans,
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                key: const Key('heart-generated'),
                tooltip: _liked ? 'Liked' : 'Like',
                onPressed: () => setState(() => _liked = !_liked),
                icon: Icon(
                  _liked ? Icons.favorite : Icons.favorite_border,
                  color: _liked ? scheme.primary : scheme.onSurface,
                ),
              ),
              IconButton(
                key: const Key('share-generated'),
                tooltip: 'Share',
                onPressed: () => _share(context, devo),
                icon: const Icon(Icons.ios_share),
              ),
              IconButton(
                key: const Key('note-generated'),
                tooltip: 'Note',
                onPressed: () => showFeedSnack(
                  context,
                  'Notes on a new devo stay on this phone.',
                ),
                icon: const Icon(Icons.sticky_note_2_outlined),
              ),
            ],
          ),
        ),
        OneMinuteSection(devo: fullDevo),
        if (fullDevo.hook.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Text(
              fullDevo.hook,
              style: TextStyle(
                fontFamily: AppTheme.serif,
                fontSize: 17,
                height: 1.35,
                color: AppColors.summaryInk(Theme.of(context).brightness),
              ),
            ),
          ),
        const SizedBox(height: 8),
        for (var index = 0; index < sections.length; index++) ...[
          if (index > 0)
            Center(
              child: Container(
                width: 1.5,
                height: 14,
                color: const Color(0xFFB9AE97).withValues(alpha: 0.4),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cardBorder, width: 1),
                boxShadow: [cardShadow],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      key: Key('section-bullet-${sections[index].id}'),
                      onTap: () => _toggleSection(sections[index].position),
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
                                    plainSectionTitle(sections[index].title),
                                    style: TextStyle(
                                      fontFamily: AppTheme.sans,
                                      fontSize: 15,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                      color: titleColor,
                                    ),
                                  ),
                                  if (sections[index].summary.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      sections[index].summary,
                                      style: TextStyle(
                                        fontFamily: AppTheme.sans,
                                        fontSize: 15,
                                        height: 1.35,
                                        color: AppColors.summaryInk(
                                          isDark ? Brightness.dark : Brightness.light,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _expandedSections.contains(sections[index].position)
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 18,
                              color: chevronColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_expandedSections.contains(sections[index].position))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DevoBody(markdown: sections[index].body),
                            if (sections[index].verseText.isNotEmpty ||
                                sections[index].verseRef.isNotEmpty)
                              Container(
                                key: Key('section-verse-box-${sections[index].id}'),
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF262320)
                                      : const Color(0xFFF6EFDF),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF4A453E)
                                        : const Color(0xFFE8DDC4),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (sections[index].verseText.isNotEmpty)
                                      Text(
                                        sections[index].verseText,
                                        style: TextStyle(
                                          fontFamily: AppTheme.serif,
                                          fontStyle: FontStyle.italic,
                                          fontSize: 16,
                                          height: 1.45,
                                          color: isDark
                                              ? const Color(0xFFE8E2D5)
                                              : const Color(0xFF2C241E),
                                        ),
                                      ),
                                    if (sections[index].verseText.isNotEmpty &&
                                        sections[index].verseRef.isNotEmpty)
                                      const SizedBox(height: 10),
                                    if (sections[index].verseRef.isNotEmpty)
                                      Text(
                                        sections[index].verseRef.startsWith('—') ||
                                                sections[index].verseRef.startsWith('\u2014')
                                            ? sections[index].verseRef
                                            : '— ${sections[index].verseRef}',
                                        key: Key('section-ref-${sections[index].id}'),
                                        style: TextStyle(
                                          fontFamily: AppTheme.sans,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? const Color(0xFFD4B36A)
                                              : const Color(0xFF8A6A2F),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (fullDevo.prayer.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              devoPrayerLine(fullDevo.prayer) ?? fullDevo.prayer,
              key: const Key('devo-prayer'),
              style: TextStyle(
                fontFamily: AppTheme.serif,
                fontSize: 17,
                height: 1.4,
                color: scheme.onSurface,
              ),
            ),
          ),
        if (devo.helpNote != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              devo.helpNote!,
              key: const Key('help-note'),
              style: TextStyle(
                fontFamily: AppTheme.sans,
                fontSize: 13,
                height: 1.35,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('save-to-mine'),
                      onPressed: () async {
                        await ref.read(mineProvider.notifier).save(devo);
                        if (!context.mounted) return;
                        showFeedSnack(context, 'Saved on this phone');
                      },
                      icon: const Icon(Icons.bookmark_border),
                      label: const Text('Save'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('regenerate'),
                      onPressed: () => ref
                          .read(personalizeRunProvider.notifier)
                          .regenerate(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Regenerate'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    ref.read(personalizeRunProvider.notifier).dismiss(),
                child: const Text('Back to feed'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _share(BuildContext context, GeneratedDevo devo) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: '${devo.title}\n\n${devo.hook}\n\n${devo.verseText}'),
      );
    } catch (_) {
      if (!context.mounted) return;
      showFeedSnack(context, 'Sharing is not available on this device.');
    }
  }
}

class _CapCard extends StatelessWidget {
  const _CapCard({required this.cap});

  final CapSnapshot cap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${cap.left} of ${cap.weeklyCap} left this week',
                key: const Key('cap-label'),
                style: TextStyle(
                  fontFamily: AppTheme.sans,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E0A4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'EXAMPLE CAP',
                  style: TextStyle(
                    fontFamily: AppTheme.sans,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: AppColors.chipInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < cap.weeklyCap; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: i < cap.left
                          ? AppColors.olive
                          : const Color(0xFFE4DDD2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Resets Monday. Limit and pricing not decided yet.',
            style: TextStyle(
              fontFamily: AppTheme.sans,
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.filled = false});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? scheme.primaryContainer : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: filled ? null : Border.all(color: scheme.outline),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.sans,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: filled ? scheme.primary : scheme.onSurface,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
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
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.14),
      ),
    );
  }
}

class _ImagePill extends StatelessWidget {
  const _ImagePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'IMAGE PLACEHOLDER',
        style: TextStyle(
          fontFamily: AppTheme.sans,
          fontSize: 10,
          letterSpacing: 0.6,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class MineTile extends StatelessWidget {
  const MineTile({required this.devo, required this.index, super.key});

  final GeneratedDevo devo;
  final int index;

  @override
  Widget build(BuildContext context) {
    final paletteIndex = minePaletteOrder[index % minePaletteOrder.length];
    final colors = bannerPalettes[paletteIndex];
    return ClipRRect(
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
              top: 10,
              right: 10,
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Text(
                devo.title,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.serif,
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Palette order for personalized tiles.
/// the approved art: plum, sand, blue, olive.
const minePaletteOrder = [2, 4, 0, 1];
