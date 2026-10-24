import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/devo.dart';
import 'banner.dart';

/// The eight app-built banner frames, one per devotion number.
enum BannerFrame {
  photoScrim,
  duotone,
  typePoster,
  outlinedScripture,
  splitImage,
  handLettered,
  minimal,
  collage,
}

BannerFrame bannerFrameFor(int position) {
  final slot = position <= 0 ? 0 : (position - 1) % BannerFrame.values.length;
  return BannerFrame.values[slot];
}

String bannerFrameLabel(BannerFrame frame) {
  return switch (frame) {
    BannerFrame.photoScrim => 'Photo + scrim',
    BannerFrame.duotone => 'Duotone image',
    BannerFrame.typePoster => 'Type poster',
    BannerFrame.outlinedScripture => 'Outlined scripture',
    BannerFrame.splitImage => 'Split image',
    BannerFrame.handLettered => 'Hand-lettered',
    BannerFrame.minimal => 'Minimal editorial',
    BannerFrame.collage => 'Collage + stamp',
  };
}

/// Height of every feed banner. Tall enough for a title plus three sentences.
const double kStyleBannerHeight = 348;

/// Takeaway when the devotion has one, otherwise the hook.
/// At most three complete sentences, with nothing added and nothing cut mid-sentence.
String bannerSummary(Devo devo) {
  final takeaway = devo.takeaway.trim();
  final source = takeaway.isNotEmpty ? takeaway : devo.hook.trim();
  return clipToSentences(source, 3);
}

/// Keeps the first [maxSentences] sentence endings.
/// A passage with fewer endings is returned whole.
String clipToSentences(String text, int maxSentences) {
  final trimmed = text.trim();
  if (trimmed.isEmpty || maxSentences <= 0) return '';
  final terminator = RegExp('[.!?]+');
  var kept = 0;
  for (final match in terminator.allMatches(trimmed)) {
    if (_skipsSentenceBreak(trimmed, match)) continue;
    kept++;
    if (kept == maxSentences) {
      return trimmed.substring(0, match.end).trim();
    }
  }
  return trimmed;
}

bool _skipsSentenceBreak(String text, RegExpMatch match) {
  final token = match.group(0)!;
  if (token.contains('.')) {
    final before = match.start > 0 ? text[match.start - 1] : '';
    final after = match.end < text.length ? text[match.end] : '';
    if (_isDigit(before) && _isDigit(after)) return true;
  }
  if (token != '.') return false;
  final word = RegExp(r'[A-Za-z]+$').firstMatch(text.substring(0, match.start));
  if (word == null) return false;
  final letters = word.group(0)!;
  if (letters.length == 1) return true;
  const abbreviations = {
    'mr',
    'mrs',
    'ms',
    'dr',
    'st',
    'sr',
    'jr',
    'ps',
    'rev',
    'vs',
  };
  return abbreviations.contains(letters.toLowerCase());
}

bool _isDigit(String char) =>
    char.length == 1 && char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;

/// A section banner reuses the parent devotion's frame with its own title.
Devo bannerDisplayDevo(Devo devo, {String? title, String? summary}) {
  if (title == null && summary == null) return devo;
  return Devo(
    id: devo.id,
    title: title ?? devo.title,
    hook: summary == null ? devo.hook : '',
    bodyMd: devo.bodyMd,
    takeaway: summary ?? devo.takeaway,
    verseText: devo.verseText,
    verseRef: devo.verseRef,
    scriptures: devo.scriptures,
    editionDate: devo.editionDate,
    position: devo.position,
    status: devo.status,
    tags: devo.tags,
    sections: devo.sections,
    sourceUrl: devo.sourceUrl,
    editionUrl: devo.editionUrl,
    stars: devo.stars,
    notionPageId: devo.notionPageId,
    imageUrl: devo.imageUrl,
    imageAlt: devo.imageAlt,
    teaser: devo.teaser,
    prayer: devo.prayer,
  );
}

class BannerScope extends InheritedWidget {
  const BannerScope({required this.pillLabel, required super.child, super.key});

  final String? pillLabel;

  static BannerScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<BannerScope>();
  }

  @override
  bool updateShouldNotify(BannerScope oldWidget) =>
      pillLabel != oldWidget.pillLabel;
}

class StyleBanner extends StatelessWidget {
  const StyleBanner({
    required this.devo,
    required this.total,
    this.tagLabel,
    this.onTap,
    this.onDoubleTap,
    this.hero = true,
    this.burstToken = 0,
    this.titleOverride,
    this.summaryOverride,
    this.pillLabel,
    this.bannerKey,
    super.key,
  });

  final Devo devo;
  final int total;
  final String? tagLabel;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final bool hero;
  final int burstToken;
  final String? titleOverride;
  final String? summaryOverride;
  final String? pillLabel;
  final String? bannerKey;

  @override
  Widget build(BuildContext context) {
    final shown = bannerDisplayDevo(
      devo,
      title: titleOverride,
      summary: summaryOverride,
    );
    final frame = bannerFrameFor(shown.position);
    final banner = GestureDetector(
      key: Key(bannerKey ?? 'banner-${devo.id}'),
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: SizedBox(
        height: kStyleBannerHeight,
        width: double.infinity,
        child: BannerScope(
          pillLabel: pillLabel,
          child: _Frame(
            devo: shown,
            total: total,
            frame: frame,
            tagLabel: tagLabel,
          ),
        ),
      ),
    );
    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          banner,
          if (burstToken > 0)
            Positioned.fill(child: HeartBurst(token: burstToken)),
        ],
      ),
    );
    if (!hero) return clipped;
    return Hero(tag: 'banner-${devo.id}', child: clipped);
  }
}

class _Frame extends StatelessWidget {
  const _Frame({
    required this.devo,
    required this.total,
    required this.frame,
    required this.tagLabel,
  });

  final Devo devo;
  final int total;
  final BannerFrame frame;
  final String? tagLabel;

  @override
  Widget build(BuildContext context) {
    return switch (frame) {
      BannerFrame.photoScrim => _PhotoScrim(
        devo: devo,
        total: total,
        tag: tagLabel,
      ),
      BannerFrame.duotone => _Duotone(devo: devo, total: total, tag: tagLabel),
      BannerFrame.typePoster => _TypePoster(
        devo: devo,
        total: total,
        tag: tagLabel,
      ),
      BannerFrame.outlinedScripture => _OutlinedScripture(
        devo: devo,
        total: total,
        tag: tagLabel,
      ),
      BannerFrame.splitImage => _SplitImage(
        devo: devo,
        total: total,
        tag: tagLabel,
      ),
      BannerFrame.handLettered => _HandLettered(
        devo: devo,
        total: total,
        tag: tagLabel,
      ),
      BannerFrame.minimal => _Minimal(devo: devo, total: total, tag: tagLabel),
      BannerFrame.collage => _Collage(devo: devo, total: total, tag: tagLabel),
    };
  }
}

class _PhotoScrim extends StatelessWidget {
  const _PhotoScrim({
    required this.devo,
    required this.total,
    required this.tag,
  });

  final Devo devo;
  final int total;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _ArtPhoto(
          devo: devo,
          fallback: const [Color(0xFF6E8CA8), Color(0xFF24384A)],
          scrim: true,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopRow(devo: devo, total: total, tag: tag, onDark: true),
              Expanded(
                child: _ScaleDown(
                  children: [
                    Text(
                      devo.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 28,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    _SummaryPlate(
                      text: bannerSummary(devo),
                      fill: const Color(0xE614110E),
                      style: const TextStyle(
                        fontFamily: AppTheme.sans,
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Duotone extends StatelessWidget {
  const _Duotone({required this.devo, required this.total, required this.tag});

  final Devo devo;
  final int total;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _ArtPhoto(
          devo: devo,
          fallback: const [Color(0xFF1C4E55), Color(0xFF0E2C31)],
          duotone: const Color(0xFF1F6A62),
          scrim: true,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopRow(devo: devo, total: total, tag: tag, onDark: true),
              Expanded(
                child: _ScaleDown(
                  children: [
                    Text(
                      devo.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 28,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    _SummaryPlate(
                      text: bannerSummary(devo),
                      fill: const Color(0xE614110E),
                      style: const TextStyle(
                        fontFamily: AppTheme.sans,
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TypePoster extends StatelessWidget {
  const _TypePoster({
    required this.devo,
    required this.total,
    required this.tag,
  });

  final Devo devo;
  final int total;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final words = devo.title.split(RegExp(r'\s+'));
    final kicker = words.length > 2 ? words.first : 'The';
    final headline = words.length > 2
        ? words.sublist(1, math.min(words.length, 4)).join(' ')
        : devo.title;
    final rest = words.length > 4 ? words.sublist(4).join(' ') : '';
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.posterGold),
      child: Stack(
        children: [
          const Positioned(right: -20, top: -30, child: _Sunburst()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopRow(
                  devo: devo,
                  total: total,
                  tag: tag,
                  onDark: false,
                  ink: AppColors.posterInk,
                ),
                Expanded(
                  child: _ScaleDown(
                    children: [
                      Text(
                        kicker,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Playfair Display',
                          fontStyle: FontStyle.italic,
                          fontSize: 18,
                          height: 1,
                          color: AppColors.posterInk,
                        ),
                      ),
                      Text(
                        headline.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Bebas Neue',
                          fontSize: 34,
                          height: 0.9,
                          letterSpacing: 0.4,
                          color: AppColors.posterRed,
                        ),
                      ),
                      if (rest.isNotEmpty)
                        Text(
                          rest,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Caveat',
                            fontSize: 22,
                            height: 1,
                            color: AppColors.posterInk,
                          ),
                        ),
                      _SummaryPlate(
                        text: bannerSummary(devo),
                        fill: const Color(0xFF241B4B),
                        style: const TextStyle(
                          fontFamily: AppTheme.sans,
                          fontSize: 15,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
    );
  }
}

class _OutlinedScripture extends StatelessWidget {
  const _OutlinedScripture({
    required this.devo,
    required this.total,
    required this.tag,
  });

  final Devo devo;
  final int total;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final reference = _compactReference(devo.verseRef);
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF2C241C)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopRow(devo: devo, total: total, tag: tag, onDark: true),
            Expanded(
              child: _ScaleDown(
                children: [
                  Text(
                    reference,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 42,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 1.2
                        ..color = const Color(0xFFE7A07A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    devo.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF4EEE6),
                    ),
                  ),
                  _SummaryPlate(
                    text: bannerSummary(devo),
                    fill: const Color(0xE614110E),
                    style: const TextStyle(
                      fontFamily: AppTheme.sans,
                      fontSize: 15,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitImage extends StatelessWidget {
  const _SplitImage({
    required this.devo,
    required this.total,
    required this.tag,
  });

  final Devo devo;
  final int total;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF7F1E8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: _ArtPhoto(
              devo: devo,
              fallback: const [Color(0xFF7FA36A), Color(0xFF2F4A32)],
            ),
          ),
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopRow(
                    devo: devo,
                    total: total,
                    tag: tag,
                    onDark: false,
                    ink: AppColors.body,
                  ),
                  Expanded(
                    child: _ScaleDown(
                      children: [
                        Text(
                          devo.title,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'DM Serif Display',
                            fontSize: 24,
                            height: 1.05,
                            color: AppColors.body,
                          ),
                        ),
                        _SummaryPlate(
                          text: bannerSummary(devo),
                          fill: const Color(0xFF1E3A5F),
                          style: const TextStyle(
                            fontFamily: AppTheme.sans,
                            fontSize: 14,
                            height: 1.28,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HandLettered extends StatelessWidget {
  const _HandLettered({
    required this.devo,
    required this.total,
    required this.tag,
  });

  final Devo devo;
  final int total;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _KraftPainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopRow(
              devo: devo,
              total: total,
              tag: tag,
              onDark: false,
              ink: AppColors.kraftInk,
            ),
            Expanded(
              child: _ScaleDown(
                children: [
                  Text(
                    devo.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Caveat',
                      fontSize: 34,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: AppColors.kraftInk,
                    ),
                  ),
                  _SummaryPlate(
                    text: bannerSummary(devo),
                    fill: const Color(0xFFF6E7C8),
                    radius: 12,
                    style: const TextStyle(
                      fontFamily: 'Caveat',
                      fontSize: 20,
                      height: 1.15,
                      color: AppColors.kraftInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Minimal extends StatelessWidget {
  const _Minimal({required this.devo, required this.total, required this.tag});

  final Devo devo;
  final int total;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFFFFCF8)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopRow(
              devo: devo,
              total: total,
              tag: tag,
              onDark: false,
              ink: AppColors.meta,
              accent: const Color(0xFF8C6239),
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: const Color(0xFFE4D8C8)),
            Expanded(
              child: _ScaleDown(
                children: [
                  Text(
                    devo.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 30,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                      color: AppColors.body,
                    ),
                  ),
                  _SummaryPlate(
                    text: bannerSummary(devo),
                    style: const TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 16,
                      height: 1.3,
                      fontStyle: FontStyle.italic,
                      color: AppColors.summary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Collage extends StatelessWidget {
  const _Collage({required this.devo, required this.total, required this.tag});

  final Devo devo;
  final int total;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF2C4A34)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopRow(devo: devo, total: total, tag: tag, onDark: true),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _ScaleDown(
                      children: [
                        Text(
                          devo.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Abril Fatface',
                            fontSize: 26,
                            height: 1.02,
                            color: Color(0xFFF4EEE6),
                          ),
                        ),
                        _SummaryPlate(
                          text: bannerSummary(devo),
                          fill: const Color(0xE614110E),
                          style: const TextStyle(
                            fontFamily: AppTheme.sans,
                            fontSize: 14,
                            height: 1.28,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 92,
                    height: 108,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Transform.rotate(
                          angle: -0.08,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _ArtPhoto(
                              devo: devo,
                              fallback: const [
                                Color(0xFFD7A24A),
                                Color(0xFF8C4E2A),
                              ],
                            ),
                          ),
                        ),
                        const Positioned(right: -6, top: -8, child: _Stamp()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtPhoto extends StatelessWidget {
  const _ArtPhoto({
    required this.devo,
    required this.fallback,
    this.duotone,
    this.scrim = false,
  });

  final Devo devo;
  final List<Color> fallback;
  final Color? duotone;
  final bool scrim;

  @override
  Widget build(BuildContext context) {
    final url = devo.imageUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;
    Widget art = hasUrl
        ? Image.network(
            url,
            key: ValueKey('banner-photo-$url'),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            semanticLabel: (devo.imageAlt?.trim().isNotEmpty ?? false)
                ? devo.imageAlt!.trim()
                : devo.title,
            errorBuilder: (_, _, _) => _FallbackArt(colors: fallback),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _FallbackArt(colors: fallback);
            },
          )
        : _FallbackArt(colors: fallback);
    if (duotone != null) {
      art = ColorFiltered(
        colorFilter: ColorFilter.mode(duotone!, BlendMode.color),
        child: art,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        art,
        if (scrim)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x33000000), Color(0xCC14110E)],
              ),
            ),
          ),
      ],
    );
  }
}

class _FallbackArt extends StatelessWidget {
  const _FallbackArt({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.devo,
    required this.total,
    required this.tag,
    required this.onDark,
    this.ink,
    this.accent,
  });

  final Devo devo;
  final int total;
  final String? tag;
  final bool onDark;
  final Color? ink;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final count = total <= 0 ? devo.position : total;
    final label =
        BannerScope.maybeOf(context)?.pillLabel ??
        'DEVO ${devo.position} OF $count';
    return Row(
      children: [
        if (label.trim().isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: onDark ? const Color(0xFF241B4B) : const Color(0xFFF4EEE6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.sans,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: onDark ? Colors.white : AppColors.body,
              ),
            ),
          ),
        const Spacer(),
        if (tag != null && tag!.trim().isNotEmpty)
          Flexible(
            child: Text(
              tag!.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: AppTheme.sans,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color:
                    accent ?? (onDark ? Colors.white : ink ?? AppColors.body),
              ),
            ),
          ),
      ],
    );
  }
}

/// Pins a title and its summary to the bottom of the banner and shrinks
/// the block, rather than clipping a sentence, when the copy is long.
class _ScaleDown extends StatelessWidget {
  const _ScaleDown({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.bottomLeft,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        );
      },
    );
  }
}

class _SummaryPlate extends StatelessWidget {
  const _SummaryPlate({
    required this.text,
    required this.style,
    this.fill,
    this.radius = 14,
  });

  final String text;
  final TextStyle style;
  final Color? fill;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final label = Text(text, style: style);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: fill == null
          ? label
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: label,
            ),
    );
  }
}

class _Sunburst extends StatelessWidget {
  const _Sunburst();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(size: Size(140, 140), painter: _SunburstPainter());
  }
}

class _SunburstPainter extends CustomPainter {
  const _SunburstPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = const Color(0xFFE0A82E);
    final path = Path();
    const rays = 18;
    final outer = size.width / 2;
    final inner = outer * 0.28;
    for (var i = 0; i < rays; i++) {
      final a0 = (i / rays) * math.pi * 2;
      final a1 = ((i + 0.45) / rays) * math.pi * 2;
      path.moveTo(center.dx, center.dy);
      path.lineTo(
        center.dx + math.cos(a0) * outer,
        center.dy + math.sin(a0) * outer,
      );
      path.lineTo(
        center.dx + math.cos(a1) * inner,
        center.dy + math.sin(a1) * inner,
      );
      path.close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _KraftPainter extends CustomPainter {
  const _KraftPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFC4A574),
    );
    final line = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 1;
    for (var y = 28.0; y < size.height; y += 14) {
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Stamp extends StatelessWidget {
  const _Stamp();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.18,
      child: Container(
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE7C98A), width: 2),
          color: const Color(0x332A2418),
        ),
        child: const Text(
          'LEGACY',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.sans,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: Color(0xFFE7C98A),
          ),
        ),
      ),
    );
  }
}

String _compactReference(String reference) {
  const shorts = {
    'Genesis': 'GEN',
    'Exodus': 'EX',
    'Psalm': 'PS',
    'Psalms': 'PS',
    'Proverbs': 'PROV',
    'Isaiah': 'ISA',
    'Matthew': 'MATT',
    'Mark': 'MK',
    'Luke': 'LK',
    'John': 'JN',
    'Acts': 'ACTS',
    'Romans': 'ROM',
    'Hebrews': 'HEB',
    'James': 'JAS',
    'Revelation': 'REV',
  };
  final match = RegExp(r'^((?:[1-3]\s)?[A-Za-z]+)\s+(.+)$')
      .firstMatch(reference.trim());
  if (match == null) return reference.toUpperCase();
  final book = match.group(1)!;
  final rest = match.group(2)!;
  final short = shorts[book] ?? book.toUpperCase();
  return '$short $rest'.toUpperCase();
}
