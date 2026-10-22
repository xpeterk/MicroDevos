import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/devo.dart';
import 'banner.dart';
import 'feed_snack.dart';

Future<void> openShareSheet(BuildContext context, Devo devo) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => ShareSheet(devo: devo),
  );
}

class ShareSheet extends StatefulWidget {
  const ShareSheet({required this.devo, super.key});

  final Devo devo;

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  final _cardKey = GlobalKey();

  String get _link =>
      widget.devo.editionUrl ?? 'https://microdevos.substack.com';

  Future<void> _share({required bool withLink}) async {
    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    try {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null || !mounted) return;
      final file = XFile.fromData(
        data.buffer.asUint8List(),
        mimeType: 'image/png',
        name: 'micro-devo.png',
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          text: withLink ? _link : null,
          subject: widget.devo.title,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showFeedSnack(context, 'Sharing is not available on this device.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outline,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Row(
            children: [
              Text(
                'Share devo',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            'Sends this image card with a link to the devo.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: AppTheme.sans,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: _ShareCard(cardKey: _cardKey, devo: widget.devo),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShareAction(
                label: 'Messages',
                color: const Color(0xFF3E8F62),
                icon: Icons.chat_bubble_rounded,
                filled: true,
                onTap: () => _share(withLink: true),
              ),
              _ShareAction(
                label: 'Copy link',
                icon: Icons.link,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: _link));
                  if (!context.mounted) return;
                  showFeedSnack(context, 'Link copied');
                },
              ),
              _ShareAction(
                label: 'Save image',
                icon: Icons.download_rounded,
                onTap: () => _share(withLink: false),
              ),
              _ShareAction(
                label: 'More',
                icon: Icons.more_horiz,
                onTap: () => _share(withLink: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.cardKey, required this.devo});

  final GlobalKey cardKey;
  final Devo devo;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: cardKey,
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            DevoBanner(
              devo: devo,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              transform: Matrix4.translationValues(0, -28, 0),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: AppColors.verse,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    devo.verseText,
                    style: const TextStyle(
                      fontFamily: AppTheme.serif,
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                      height: 1.35,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    devo.verseRef,
                    style: const TextStyle(
                      fontFamily: AppTheme.sans,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.verseRef,
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -16),
              child: const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Wordmark(),
                    SizedBox(width: 8),
                    Text(
                      'MICRO DEVOS',
                      style: TextStyle(
                        fontFamily: AppTheme.sans,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: AppColors.olive,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.olive,
        shape: BoxShape.circle,
      ),
      child: const Text(
        'md',
        style: TextStyle(
          fontFamily: AppTheme.sans,
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ShareAction extends StatelessWidget {
  const _ShareAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: filled
                  ? (color ?? scheme.primary)
                  : scheme.surfaceContainerLowest,
              child: Icon(
                icon,
                color: filled ? Colors.white : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontFamily: AppTheme.sans, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
