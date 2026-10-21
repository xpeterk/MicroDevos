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

/// Takeaway when the devotion has one, otherwise the hook.
String threeSecondSummary(Devo devo) {
  final takeaway = devo.takeaway.trim();
  if (takeaway.isNotEmpty) return takeaway;
  return devo.hook.trim();
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
    super.key,
  });

  final Devo devo;
  final int total;
  final String? tagLabel;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final bool hero;
  final int burstToken;

  @override
  Widget build(BuildContext context) {
    final frame = bannerFrameFor(devo.position);
    final banner = GestureDetector(
      key: Key('banner-${devo.id}'),
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: SizedBox(
        height: 236,
        width: double.infinity,
        child: _Frame(
          devo: devo,
          total: total,
          frame: frame,
          tagLabel: tagLabel,
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
              const Spacer(),
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
              const SizedBox(height: 10),
              _SummaryPill(text: threeSecondSummary(devo), onDark: true),
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
              const Spacer(),
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
              const SizedBox(height: 10),
              _SummaryPill(text: threeSecondSummary(devo), onDark: true),
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
      decoration: const BoxDecoration(color: Color(0xFFF2C94C)),
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
                  ink: const Color(0xFF2A2418),
                ),
                const Spacer(),
                Text(
                  kicker,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontStyle: FontStyle.italic,
                    fontSize: 18,
                    height: 1,
                    color: Color(0xFF2A2418),
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
                    color: Color(0xFFB42318),
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
                      color: Color(0xFF2A2418),
                    ),
                  ),
                const SizedBox(height: 8),
                _SummaryPill(
                  text: threeSecondSummary(devo),
                  onDark: true,
                  fill: const Color(0xFF241B4B),
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
            const Spacer(),
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
            const SizedBox(height: 8),
            _SummaryPill(text: threeSecondSummary(devo), onDark: true),
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
                    ink: const Color(0xFF2A2420),
                  ),
                  const Spacer(),
                  Text(
                    devo.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'DM Serif Display',
                      fontSize: 26,
                      height: 1.05,
                      color: Color(0xFF2A2420),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SummaryPill(
                    text: threeSecondSummary(devo),
                    onDark: true,
                    fill: const Color(0xFF1E3A5F),
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
              ink: const Color(0xFF3A2A1C),
            ),
            const Spacer(),
            Text(
              devo.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Caveat',
                fontSize: 34,
                height: 1,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF8F3EA),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF6E7C8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                threeSecondSummary(devo),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Caveat',
                  fontSize: 18,
                  height: 1.15,
                  color: Color(0xFF3A2A1C),
                ),
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
              ink: const Color(0xFF6E645C),
              accent: const Color(0xFF8C6239),
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: const Color(0xFFE4D8C8)),
            const Spacer(),
            Text(
              devo.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 30,
                height: 1.05,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2A2420),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              threeSecondSummary(devo),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 14,
                height: 1.3,
                fontStyle: FontStyle.italic,
                color: Color(0xFF6E645C),
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
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        devo.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Abril Fatface',
                          fontSize: 28,
                          height: 1.02,
                          color: Color(0xFFF4EEE6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SummaryPill(
                        text: threeSecondSummary(devo),
                        onDark: true,
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
    final label = 'DEVO ${devo.position} OF $count';
    return Row(
      children: [
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
              color: onDark ? Colors.white : const Color(0xFF2A2420),
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
                    accent ??
                    (onDark ? Colors.white : ink ?? const Color(0xFF2A2420)),
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.text, required this.onDark, this.fill});

  final String text;
  final bool onDark;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final background =
        fill ?? (onDark ? const Color(0xE614110E) : const Color(0xFFF4EEE6));
    final foreground = onDark || fill != null
        ? Colors.white
        : const Color(0xFF2A2420);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '3 SEC',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: Color(0xFF2A2420),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.sans,
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
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
