import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/devo.dart';

const bannerPalettes = <List<Color>>[
  [Color(0xFF9BB0D0), Color(0xFF5E759C)],
  [Color(0xFF9BB5A4), Color(0xFF5E7D6A)],
  [Color(0xFFC5A9C4), Color(0xFF8E6F8C)],
  [Color(0xFFCDB98A), Color(0xFF9A8454)],
  [Color(0xFFE0B197), Color(0xFFB07A62)],
  [Color(0xFF8FA0B8), Color(0xFF5C6E88)],
  [Color(0xFFB7A6C8), Color(0xFF6E5E86)],
  [Color(0xFFD7A898), Color(0xFFA86B58)],
];

List<Color> paletteFor(Devo devo) {
  final index = (devo.position - 1).clamp(0, bannerPalettes.length - 1);
  return bannerPalettes[index];
}

class DevoBanner extends StatelessWidget {
  const DevoBanner({
    required this.devo,
    this.onDoubleTap,
    this.burstToken = 0,
    this.showTitle = true,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });

  final Devo devo;
  final VoidCallback? onDoubleTap;
  final int burstToken;
  final bool showTitle;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = paletteFor(devo);
    final imageUrl = devo.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    return GestureDetector(
      key: Key('banner-${devo.id}'),
      onDoubleTap: onDoubleTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  semanticLabel: _bannerLabel(devo),
                  errorBuilder: (context, error, stackTrace) =>
                      _PlaceholderArt(colors: colors),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return _PlaceholderArt(colors: colors);
                  },
                )
              else ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors,
                    ),
                  ),
                ),
                const Positioned(right: -30, top: 40, child: _Bubble(size: 180)),
                const Positioned(
                  left: -40,
                  bottom: 20,
                  child: _Bubble(size: 220),
                ),
                const Positioned(right: 36, bottom: 90, child: _Bubble(size: 70)),
                Positioned(
                  right: 28,
                  top: 72,
                  child: Icon(
                    Icons.sell_outlined,
                    size: 86,
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                const Positioned(top: 16, right: 16, child: _PlaceholderPill()),
              ],
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x99000000)],
                    stops: [0.55, 1],
                  ),
                ),
              ),
              if (showTitle)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 22,
                  child: Text(
                    devo.title,
                    style: const TextStyle(
                      fontFamily: AppTheme.serif,
                      fontSize: 32,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              HeartBurst(token: burstToken),
            ],
          ),
        ),
      ),
    );
  }
}

String _bannerLabel(Devo devo) {
  final alt = devo.imageAlt?.trim();
  if (alt != null && alt.isNotEmpty) return alt;
  return devo.title;
}

class _PlaceholderArt extends StatelessWidget {
  const _PlaceholderArt({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
        ),
        const Positioned(right: -30, top: 40, child: _Bubble(size: 180)),
        const Positioned(left: -40, bottom: 20, child: _Bubble(size: 220)),
        const Positioned(right: 36, bottom: 90, child: _Bubble(size: 70)),
        Positioned(
          right: 28,
          top: 72,
          child: Icon(
            Icons.sell_outlined,
            size: 86,
            color: Colors.white.withValues(alpha: 0.28),
          ),
        ),
        const Positioned(top: 16, right: 16, child: _PlaceholderPill()),
      ],
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

class _PlaceholderPill extends StatelessWidget {
  const _PlaceholderPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'IMAGE PLACEHOLDER',
        style: TextStyle(
          fontFamily: AppTheme.sans,
          fontSize: 10,
          letterSpacing: 0.8,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class HeartBurst extends StatefulWidget {
  const HeartBurst({required this.token, super.key});

  final int token;

  @override
  State<HeartBurst> createState() => _HeartBurstState();
}

class _HeartBurstState extends State<HeartBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didUpdateWidget(HeartBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.token != oldWidget.token && widget.token > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        if (t == 0 || t == 1) return const SizedBox.shrink();
        final scale = 0.4 + (t < 0.45 ? t / 0.45 : 1) * 0.8;
        final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
        return IgnorePointer(
          child: Opacity(
            opacity: opacity.clamp(0, 1),
            child: Transform.scale(
              scale: scale,
              child: const Center(
                child: Icon(
                  Icons.favorite,
                  key: Key('heart-burst'),
                  size: 96,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class StoryCircle extends StatelessWidget {
  const StoryCircle({required this.devo, required this.label, super.key});

  final Devo devo;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = paletteFor(devo);
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: colors),
              border: Border.all(color: colors.last, width: 2),
            ),
            child: Text(
              '${devo.position}',
              style: const TextStyle(
                fontFamily: AppTheme.serif,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.sans,
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
